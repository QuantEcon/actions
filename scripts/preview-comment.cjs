// The pull request comment that preview-netlify and preview-cloudflare post,
// in one place for both (#153) and for any later preview action (#145): the
// pending one a placeholder posts as soon as a pull request is pushed, and
// the ready one the deploy puts in its place. Each action finds this file
// from $GITHUB_ACTION_PATH in a bash step and loads it from its
// actions/github-script step:
//
//   await require(process.env.PREVIEW_COMMENT_SCRIPT).run({ github, context, core });
//
// Everything about the deploy reaches it through that step's env, never
// through the script body: file paths and URLs come from the pull request, and
// interpolating them into a script would let them run as code.
'use strict';

// One entry per provider, named by the step's PROVIDER. The headings are the
// comment's first visible line, after a deploy and before one, and the key
// names its hidden marker. previewUrl is where the deploy will put the alias
// (pr-<number>) of the site (Netlify's site name, Cloudflare's project name),
// which the placeholder links to before there is a deploy to ask; for
// Cloudflare it is the URL the action's deploy step builds too.
const PROVIDERS = {
  netlify: {
    heading: '## 📖 Netlify Preview Ready!',
    pendingHeading: '## ⏳ Netlify Preview Building…',
    previewUrl: (alias, site) => `https://${alias}--${site}.netlify.app`,
  },
  cloudflare: {
    heading: '## ☁️ Cloudflare Preview Ready!',
    pendingHeading: '## ⏳ Cloudflare Preview Building…',
    previewUrl: (alias, site) => `https://${alias}.${site}.pages.dev`,
  },
};

// The step's PREVIEW_STATE: `ready` after a deploy, the default, or `pending`
// for the placeholder, before one.
const STATES = ['ready', 'pending'];

// The author of every comment posted with a job's GITHUB_TOKEN, the only token
// the actions comment with.
const BOT_LOGIN = 'github-actions[bot]';

// The comment's first line. GitHub does not render it, and the action finds
// its comment again by it.
function marker(provider) {
  return `<!-- quantecon-preview:${provider} -->`;
}

function commitLink({ owner, repo, commitSha }) {
  return `https://github.com/${owner}/${repo}/commit/${commitSha}`;
}

// The comment's body: the marker, then the comment. A ready one is exactly as
// the actions rendered it before the marker was added. A pending one has the
// pending heading, and says what its links show until the deploy.
function render({ provider, pending = false, deployUrl, deploymentUrl, changedFiles, lecturesDir, stripLecturesDir, commitSha, owner, repo, workflow, runId }) {
  const shortSha = commitSha.substring(0, 7);
  const commitUrl = commitLink({ owner, repo, commitSha });
  const { heading, pendingHeading } = PROVIDERS[provider];

  let comment = `${marker(provider)}\n`;
  comment += `${pending ? pendingHeading : heading}\n\n`;
  comment += `**Preview URL:** ${deployUrl}\n\n`;
  comment += `**Commit:** [\`${shortSha}\`](${commitUrl})\n\n`;
  if (pending) {
    comment += `This commit is still building. Until its deploy finishes, these links show the last push that was deployed, or nothing if none has been yet. This comment is updated then; if the build fails, the workflow run below says why.\n\n`;
  }

  // Add direct links to changed lecture pages
  if (changedFiles && changedFiles.trim() && lecturesDir) {
    const files = changedFiles.split('\n').filter(f => f.trim());
    if (files.length > 0) {
      comment += `### 📚 Changed Lectures\n\n`;
      for (const file of files) {
        const cleanFile = file.trim();
        if (cleanFile) {
          // Determine URL path based on _toc.yml location
          // If _toc.yml is in lectures-dir, strip the dir (JB builds relative to it)
          // If _toc.yml is at root, keep the dir (JB preserves structure)
          let filePath;
          if (stripLecturesDir) {
            filePath = cleanFile.replace(`${lecturesDir}/`, '').replace('.md', '');
          } else {
            filePath = cleanFile.replace('.md', '');
          }
          const displayName = filePath.split('/').pop();  // Just filename for display
          const pageUrl = `${deployUrl}/${filePath}.html`;
          comment += `- [${displayName}](${pageUrl})\n`;
        }
      }
      comment += '\n';
    }
  }

  // Add build info
  comment += `---\n`;
  comment += `<details><summary>Build Info</summary>\n\n`;
  comment += `- **Workflow:** [${workflow}](https://github.com/${owner}/${repo}/actions/runs/${runId})\n`;
  // Cloudflare's preview URL above is the branch alias, which follows the
  // newest deployment. Name the immutable one here too, so a reviewer who
  // needs to look at exactly this commit still has a link that will not move
  // under them when the next push lands.
  if (deploymentUrl) {
    comment += `- **This deployment:** ${deploymentUrl} (pinned to \`${shortSha}\`; the URL above always tracks the latest push)\n`;
  }
  comment += `</details>\n`;
  return comment;
}

// The action's own comments on the pull request, oldest first. All of its
// comments are read, not only the first page of 30, and only the bot's count:
// a person's comment that quotes the heading or the marker is never edited
// (finding M2 of the 2026-10-06 review). Its own starts with the marker, or,
// from before the marker was added, with the heading; a bot comment that has
// either further down, quoted by another workflow, is not taken.
async function findComments({ github, owner, repo, issueNumber, provider }) {
  const comments = await github.paginate(github.rest.issues.listComments, {
    owner,
    repo,
    issue_number: issueNumber,
    per_page: 100,
  });
  const { heading } = PROVIDERS[provider];
  return comments.filter(c =>
    c.user && c.user.login === BOT_LOGIN && typeof c.body === 'string'
    && (c.body.startsWith(marker(provider)) || c.body.startsWith(heading)));
}

// The lectures a pull request added or modified, for the placeholder, which
// has no checkout: from the REST API's list of the pull request's files, which
// compares from the merge base as scripts/detect-changed-lectures.sh does, and
// by that script's rules. A renamed lecture counts as added, under its new
// path; a removed one is not listed; nor is <lectures-dir>/intro.md, nor a
// path whose first part under lectures-dir starts with `_`, such as
// <lectures-dir>/_static/notes.md. Only that first part counts, as in the
// script: <lectures-dir>/sub/_draft.md is listed. `strip` says whether
// _toc.yml is in lectures-dir at the pull request's head, as the script's
// strip-lectures-dir does. A failure is a warning, with no lectures listed,
// since the links are worth less than the comment.
async function changedLectures({ github, core, owner, repo, pullNumber, commitSha, lecturesDir }) {
  if (!lecturesDir) return { files: [], strip: false };
  let listed;
  try {
    listed = await github.paginate(github.rest.pulls.listFiles, { owner, repo, pull_number: pullNumber, per_page: 100 });
  } catch (e) {
    core.warning(`Could not list the pull request's files, so no changed lectures are listed: ${e.message}`);
    return { files: [], strip: false };
  }
  // "Responses include a maximum of 3000 files."
  if (listed.length >= 3000) {
    core.warning("The pull request's file list reached the API's 3,000-file cap, so some changed lectures may not be listed");
  }
  const files = listed
    .filter(f => ['added', 'modified', 'renamed', 'copied', 'changed'].includes(f.status))
    .map(f => f.filename)
    .filter(f => f.startsWith(`${lecturesDir}/`) && f.endsWith('.md')
      && !f.startsWith(`${lecturesDir}/_`) && f !== `${lecturesDir}/intro.md`)
    .sort();
  let strip;
  try {
    await github.rest.repos.getContent({ owner, repo, path: `${lecturesDir}/_toc.yml`, ref: commitSha });
    strip = true;
  } catch (e) {
    if (e.status !== 404) {
      core.warning(`Could not look for ${lecturesDir}/_toc.yml, so no changed lectures are listed: ${e.message}`);
      return { files: [], strip: false };
    }
    strip = false;
  }
  for (const f of files) core.info(`✓ Changed: ${f}`);
  return { files, strip };
}

// Whether a comment is already the deploy's for this commit, which the
// placeholder must not put back to pending: a re-run of its job alone would
// otherwise do that after the deploy.
function isReadyFor(comment, { provider, owner, repo, commitSha }) {
  const { heading } = PROVIDERS[provider];
  const ready = comment.body.startsWith(`${marker(provider)}\n${heading}\n`) || comment.body.startsWith(heading);
  return ready && comment.body.includes(`(${commitLink({ owner, repo, commitSha })})`);
}

async function run({ github, context, core }) {
  const env = process.env;
  const provider = env.PROVIDER || '';
  if (!Object.hasOwn(PROVIDERS, provider)) {
    throw new Error(`preview-comment: PROVIDER is [${provider}], not one of: ${Object.keys(PROVIDERS).join(', ')}`);
  }
  const state = env.PREVIEW_STATE || 'ready';
  if (!STATES.includes(state)) {
    throw new Error(`preview-comment: PREVIEW_STATE is [${state}], not one of: ${STATES.join(', ')}`);
  }
  const pending = state === 'pending';
  const { owner, repo } = context.repo;
  const issueNumber = context.issue.number;
  const commitSha = env.COMMIT_SHA || '';
  const lecturesDir = env.LECTURES_DIR || '';

  // The deploy hands over its URL and what its change detection found in the
  // checkout. The placeholder has neither a deploy nor a checkout, so it
  // builds the URL and asks the API.
  let deployUrl = env.DEPLOY_URL || '';
  let changedFiles = env.CHANGED_FILES || '';
  let stripLecturesDir = env.STRIP_LECTURES_DIR === 'true';
  if (pending) {
    const alias = env.PREVIEW_ALIAS || '';
    const site = env.PREVIEW_SITE || '';
    if (!alias || !site) {
      throw new Error(`preview-comment: a pending comment needs PREVIEW_ALIAS and PREVIEW_SITE, got [${alias}] and [${site}]`);
    }
    deployUrl = PROVIDERS[provider].previewUrl(alias, site);
    const found = await changedLectures({ github, core, owner, repo, pullNumber: issueNumber, commitSha, lecturesDir });
    changedFiles = found.files.join('\n');
    stripLecturesDir = found.strip;
  }

  const body = render({
    provider,
    pending,
    deployUrl,
    deploymentUrl: pending ? '' : env.DEPLOYMENT_URL || '',
    changedFiles,
    lecturesDir,
    stripLecturesDir,
    commitSha,
    owner,
    repo,
    workflow: context.workflow,
    runId: context.runId,
  });

  const mine = await findComments({ github, owner, repo, issueNumber, provider });
  const newest = mine[mine.length - 1];
  if (pending && newest && isReadyFor(newest, { provider, owner, repo, commitSha })) {
    core.info(`Comment ${newest.id} already has this commit's deployed preview, so it is left as it is`);
    return;
  }
  if (mine.length === 0) {
    await github.rest.issues.createComment({ owner, repo, issue_number: issueNumber, body });
    core.info('Created new comment');
    return;
  }
  // There is more than one where an earlier version missed its comment and
  // posted another. The newest is nearest the end of the conversation, so it
  // is the one kept current.
  const existing = mine[mine.length - 1];
  await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body });
  core.info(`Updated existing comment ${existing.id}`);
  if (mine.length > 1) {
    core.info(`Found ${mine.length} of this action's comments on the pull request; updated only the newest`);
  }
}

module.exports = { PROVIDERS, STATES, BOT_LOGIN, marker, render, findComments, changedLectures, run };
