// The pull request comment that preview-netlify and preview-cloudflare post
// after a deploy, in one place for both (#153) and for any later preview
// action (#145). Each action finds this file from $GITHUB_ACTION_PATH in a
// bash step and loads it from its actions/github-script step:
//
//   await require(process.env.PREVIEW_COMMENT_SCRIPT).run({ github, context, core });
//
// Everything about the deploy reaches it through that step's env, never
// through the script body: file paths and URLs come from the pull request, and
// interpolating them into a script would let them run as code.
'use strict';

// One entry per provider, named by the step's PROVIDER. The heading is the
// comment's first visible line, and the key names its hidden marker.
const PROVIDERS = {
  netlify: { heading: '## 📖 Netlify Preview Ready!' },
  cloudflare: { heading: '## ☁️ Cloudflare Preview Ready!' },
};

// The author of every comment posted with a job's GITHUB_TOKEN, the only token
// the actions comment with.
const BOT_LOGIN = 'github-actions[bot]';

// The comment's first line. GitHub does not render it, and the action finds
// its comment again by it.
function marker(provider) {
  return `<!-- quantecon-preview:${provider} -->`;
}

// The comment's body: the marker, then the comment exactly as the actions
// rendered it before the marker was added.
function render({ provider, deployUrl, deploymentUrl, changedFiles, lecturesDir, stripLecturesDir, commitSha, owner, repo, workflow, runId }) {
  const shortSha = commitSha.substring(0, 7);
  const commitUrl = `https://github.com/${owner}/${repo}/commit/${commitSha}`;

  let comment = `${marker(provider)}\n`;
  comment += `${PROVIDERS[provider].heading}\n\n`;
  comment += `**Preview URL:** ${deployUrl}\n\n`;
  comment += `**Commit:** [\`${shortSha}\`](${commitUrl})\n\n`;

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

async function run({ github, context, core }) {
  const env = process.env;
  const provider = env.PROVIDER || '';
  if (!Object.hasOwn(PROVIDERS, provider)) {
    throw new Error(`preview-comment: PROVIDER is [${provider}], not one of: ${Object.keys(PROVIDERS).join(', ')}`);
  }
  const { owner, repo } = context.repo;
  const issueNumber = context.issue.number;

  const body = render({
    provider,
    deployUrl: env.DEPLOY_URL || '',
    deploymentUrl: env.DEPLOYMENT_URL || '',
    changedFiles: env.CHANGED_FILES || '',
    lecturesDir: env.LECTURES_DIR || '',
    stripLecturesDir: env.STRIP_LECTURES_DIR === 'true',
    commitSha: env.COMMIT_SHA || '',
    owner,
    repo,
    workflow: context.workflow,
    runId: context.runId,
  });

  const mine = await findComments({ github, owner, repo, issueNumber, provider });
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

module.exports = { PROVIDERS, BOT_LOGIN, marker, render, findComments, run };
