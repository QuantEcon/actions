// The pull request comment that preview-netlify, preview-cloudflare and
// preview-workers post, in one place for all three (#153, #145): the
// pending one a placeholder posts as soon as a pull request is pushed, and
// the ready one the deploy puts in its place. Each action finds this file
// from $GITHUB_ACTION_PATH in a bash step and loads it from its
// actions/github-script step:
//
//   await require(process.env.PREVIEW_COMMENT_SCRIPT).run({ github, context, core });
//
// scripts/detect-changed-lectures.sh runs it with node as well, for the
// changed lectures a toc-file names (#336), so the deploy and the placeholder
// list them with one toc reader (at the end of this file).
//
// Everything about the deploy reaches it through that step's env, never
// through the script body: file paths and URLs come from the pull request, and
// interpolating them into a script would let them run as code.
'use strict';

const fs = require('node:fs');
const path = require('node:path');

// One entry per provider, named by the step's PROVIDER. The headings are the
// comment's first visible line, after a deploy and before one, and the key
// names its hidden marker, so no provider's heading may begin with another's.
// previewUrl is where the deploy will put the alias (pr-<number>) of the site
// (Netlify's site name, Cloudflare's project name, or <worker>.<subdomain> for
// a Worker), which the placeholder links to before there is a deploy to ask;
// for both Cloudflare actions it is the URL the deploy step builds too.
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
  workers: {
    heading: '## ☁️ Cloudflare Workers Preview Ready!',
    pendingHeading: '## ⏳ Cloudflare Workers Preview Building…',
    previewUrl: (alias, site) => `https://${alias}-${site}.workers.dev`,
  },
};

// The step's PREVIEW_STATE: `ready` after a deploy, the default, or `pending`
// for the placeholder, before one.
const STATES = ['ready', 'pending'];

// The author of every comment posted with a job's GITHUB_TOKEN, the only token
// the actions comment with.
const BOT_LOGIN = 'github-actions[bot]';

// The step's COMMENT_KEY, the action's comment-key input (#336): empty, or
// lowercase words joined by single dashes, at most 28 characters, as the
// action's input check has already required. It goes into the marker, an
// HTML comment, so nothing else is let through.
const KEY_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const KEY_MAX = 28;

// The comment's first line. GitHub does not render it, and the action finds
// its comment again by it. A comment-key makes it the key's own, so several
// previews on one provider each keep a comment on the pull request.
function marker(provider, key = '') {
  return key ? `<!-- quantecon-preview:${provider}:${key} -->` : `<!-- quantecon-preview:${provider} -->`;
}

// The provider's two headings, with the comment-key after each.
function headings(provider, key = '') {
  const { heading, pendingHeading } = PROVIDERS[provider];
  const suffix = key ? ` (${key})` : '';
  return { heading: heading + suffix, pendingHeading: pendingHeading + suffix };
}

function commitLink({ owner, repo, commitSha }) {
  return `https://github.com/${owner}/${repo}/commit/${commitSha}`;
}

// The comment's body: the marker, then the comment. A ready one is exactly as
// the actions rendered it before the marker was added. A pending one has the
// pending heading, and says what its links show until the deploy. A
// comment-key is in the marker and both headings, and with toc-file each link
// is a page the toc names, from changedPages.
function render({ provider, commentKey = '', pending = false, deployUrl, deploymentUrl, changedFiles, changedPages = '', lecturesDir, tocFile = '', stripLecturesDir, commitSha, owner, repo, workflow, runId }) {
  const shortSha = commitSha.substring(0, 7);
  const commitUrl = commitLink({ owner, repo, commitSha });
  const { heading, pendingHeading } = headings(provider, commentKey);

  let comment = `${marker(provider, commentKey)}\n`;
  comment += `${pending ? pendingHeading : heading}\n\n`;
  comment += `**Preview URL:** ${deployUrl}\n\n`;
  comment += `**Commit:** [\`${shortSha}\`](${commitUrl})\n\n`;
  if (pending) {
    comment += `This commit is still building. Until its deploy finishes, these links show the last push that was deployed, or nothing if none has been yet. This comment is updated then; if the build fails, the workflow run below says why.\n\n`;
  }

  // Add direct links to changed lecture pages
  let pages = [];
  if (tocFile && lecturesDir) {
    // The toc's pages, which change detection matched to the files.
    pages = changedPages.split('\n').map(p => p.trim()).filter(p => p);
  } else if (changedFiles && changedFiles.trim() && lecturesDir) {
    pages = changedFiles.split('\n').map(f => f.trim()).filter(f => f).map(cleanFile => {
      // Determine URL path based on _toc.yml location
      // If _toc.yml is in lectures-dir, strip the dir (JB builds relative to it)
      // If _toc.yml is at root, keep the dir (JB preserves structure)
      if (stripLecturesDir) {
        return cleanFile.replace(`${lecturesDir}/`, '').replace('.md', '');
      }
      return cleanFile.replace('.md', '');
    });
  }
  if (pages.length > 0) {
    comment += `### 📚 Changed Lectures\n\n`;
    for (const filePath of pages) {
      const displayName = filePath.split('/').pop();  // Just filename for display
      const pageUrl = `${deployUrl}/${filePath}.html`;
      comment += `- [${displayName}](${pageUrl})\n`;
    }
    comment += '\n';
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
// either further down, quoted by another workflow, is not taken. With a
// comment-key only the key's marker counts: a comment with the heading alone
// predates keys, so it is the unkeyed preview's. The marker is matched whole,
// so neither form, nor one key and a longer one (dp, dp-2), takes the other's.
async function findComments({ github, owner, repo, issueNumber, provider, key = '' }) {
  const comments = await github.paginate(github.rest.issues.listComments, {
    owner,
    repo,
    issue_number: issueNumber,
    per_page: 100,
  });
  const { heading } = PROVIDERS[provider];
  return comments.filter(c =>
    c.user && c.user.login === BOT_LOGIN && typeof c.body === 'string'
    && (c.body.startsWith(marker(provider, key)) || (!key && c.body.startsWith(heading))));
}

// A _toc.yml's pages, for toc-file (#336): every `file:` entry, one to a
// line as Jupyter Book's tocs have them, with its quotes, a trailing `.md`
// and a trailing comment taken off. The `root:` page is left out, as
// <lectures-dir>/intro.md is without a toc. A line that is commented out is
// not read, nor is a `glob:` or `url:` entry, nor YAML's one-line `[...]`
// and `{...}` forms. It is not a YAML parser: the placeholder runs in
// actions/github-script, which has none, and the deploy's change detection
// runs this same function, so the two lists cannot differ.
function readToc(text) {
  let root = '';
  const pages = [];
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*(?:-\s+)?(root|file)\s*:\s*(.*)$/);
    if (!m) continue;
    let value = m[2].replace(/\s+#.*$/, '').trim();
    const quoted = value.match(/^(['"])(.*)\1$/);
    if (quoted) value = quoted[2];
    value = value.replace(/\.md$/, '');
    if (!value) continue;
    if (m[1] === 'root') root = value;
    else if (!pages.includes(value)) pages.push(value);
  }
  return { root, pages: pages.filter(p => p !== root) };
}

// The changed files that are pages of toc-file's toc, each with its page,
// which is also its link. A `.md` in the toc's own folder is the page at its
// path there, as for a book built from that folder, or a site's own pages
// kept beside its toc; any other `.md` in lecturesDir is the page at its path
// in lecturesDir, as for a site built from a pool of lectures. Each is listed
// when the toc names its page. So a toc at the repository root reads
// lectures/a.md as the page lectures/a, never as a. `problem` is set, and
// nothing is listed, when the toc names no page.
function tocSelect(files, { lecturesDir, tocFile, text }) {
  const { pages } = readToc(text);
  if (pages.length === 0) {
    return { found: [], problem: `toc-file ${tocFile} names no page, so no changed lectures are listed` };
  }
  const named = new Set(pages);
  const tocDir = path.posix.dirname(tocFile);
  const tocPrefix = tocDir === '.' ? '' : `${tocDir}/`;
  const found = [];
  for (const file of files) {
    if (!file.endsWith('.md')) continue;
    let prefix;
    if (file.startsWith(tocPrefix)) prefix = tocPrefix;
    else if (file.startsWith(`${lecturesDir}/`)) prefix = `${lecturesDir}/`;
    else continue;
    const page = file.slice(prefix.length, -'.md'.length);
    if (named.has(page)) found.push({ file, page });
  }
  return { found };
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
// strip-lectures-dir does. With toc-file, the toc is read at the head instead,
// and the files it names are listed by tocSelect, with their pages, as the
// script lists them. A failure is a warning, with no lectures listed, since
// the links are worth less than the comment.
async function changedLectures({ github, core, owner, repo, pullNumber, commitSha, lecturesDir, tocFile = '' }) {
  const none = { files: [], pages: [], strip: false };
  if (!lecturesDir) return none;
  let listed;
  try {
    listed = await github.paginate(github.rest.pulls.listFiles, { owner, repo, pull_number: pullNumber, per_page: 100 });
  } catch (e) {
    core.warning(`Could not list the pull request's files, so no changed lectures are listed: ${e.message}`);
    return none;
  }
  // "Responses include a maximum of 3000 files."
  if (listed.length >= 3000) {
    core.warning("The pull request's file list reached the API's 3,000-file cap, so some changed lectures may not be listed");
  }
  const changed = listed
    .filter(f => ['added', 'modified', 'renamed', 'copied', 'changed'].includes(f.status))
    .map(f => f.filename)
    .sort();
  if (tocFile) {
    let text;
    try {
      const { data } = await github.rest.repos.getContent({ owner, repo, path: tocFile, ref: commitSha });
      if (Array.isArray(data) || data.type !== 'file' || data.encoding !== 'base64') {
        throw new Error('the API did not return it as a file');
      }
      text = Buffer.from(data.content, 'base64').toString('utf8');
    } catch (e) {
      core.warning(`Could not read toc-file ${tocFile} at the pull request's head, so no changed lectures are listed: ${e.message}`);
      return none;
    }
    const { found, problem } = tocSelect(changed, { lecturesDir, tocFile, text });
    if (problem) {
      core.warning(problem);
      return none;
    }
    for (const f of found) core.info(`✓ Changed: ${f.file}`);
    return { files: found.map(f => f.file), pages: found.map(f => f.page), strip: false };
  }
  const files = changed
    .filter(f => f.startsWith(`${lecturesDir}/`) && f.endsWith('.md')
      && !f.startsWith(`${lecturesDir}/_`) && f !== `${lecturesDir}/intro.md`);
  let strip;
  try {
    await github.rest.repos.getContent({ owner, repo, path: `${lecturesDir}/_toc.yml`, ref: commitSha });
    strip = true;
  } catch (e) {
    if (e.status !== 404) {
      core.warning(`Could not look for ${lecturesDir}/_toc.yml, so no changed lectures are listed: ${e.message}`);
      return none;
    }
    strip = false;
  }
  for (const f of files) core.info(`✓ Changed: ${f}`);
  return { files, pages: [], strip };
}

// Whether a comment is already the deploy's for this commit, which the
// placeholder must not put back to pending: a re-run of its job alone would
// otherwise do that after the deploy.
function isReadyFor(comment, { provider, key = '', owner, repo, commitSha }) {
  const { heading } = headings(provider, key);
  const ready = comment.body.startsWith(`${marker(provider, key)}\n${heading}\n`) || (!key && comment.body.startsWith(heading));
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
  const commentKey = env.COMMENT_KEY || '';
  if (commentKey && !(KEY_PATTERN.test(commentKey) && commentKey.length <= KEY_MAX)) {
    throw new Error(`preview-comment: COMMENT_KEY is [${commentKey}], not lowercase letters and digits in words joined by single dashes, at most ${KEY_MAX} characters`);
  }
  const pending = state === 'pending';
  const { owner, repo } = context.repo;
  const issueNumber = context.issue.number;
  const commitSha = env.COMMIT_SHA || '';
  const lecturesDir = env.LECTURES_DIR || '';
  // lectures-dir: '' turns change detection off, toc-file with it.
  const tocFile = lecturesDir ? env.TOC_FILE || '' : '';

  // The deploy hands over its URL and what its change detection found in the
  // checkout. The placeholder has neither a deploy nor a checkout, so it
  // builds the URL and asks the API.
  let deployUrl = env.DEPLOY_URL || '';
  let changedFiles = env.CHANGED_FILES || '';
  let changedPages = env.CHANGED_PAGES || '';
  let stripLecturesDir = env.STRIP_LECTURES_DIR === 'true';
  if (pending) {
    const alias = env.PREVIEW_ALIAS || '';
    const site = env.PREVIEW_SITE || '';
    if (!alias || !site) {
      throw new Error(`preview-comment: a pending comment needs PREVIEW_ALIAS and PREVIEW_SITE, got [${alias}] and [${site}]`);
    }
    deployUrl = PROVIDERS[provider].previewUrl(alias, site);
    const found = await changedLectures({ github, core, owner, repo, pullNumber: issueNumber, commitSha, lecturesDir, tocFile });
    changedFiles = found.files.join('\n');
    changedPages = found.pages.join('\n');
    stripLecturesDir = found.strip;
  }

  const body = render({
    provider,
    commentKey,
    pending,
    deployUrl,
    deploymentUrl: pending ? '' : env.DEPLOYMENT_URL || '',
    changedFiles,
    changedPages,
    lecturesDir,
    tocFile,
    stripLecturesDir,
    commitSha,
    owner,
    repo,
    workflow: context.workflow,
    runId: context.runId,
  });

  const mine = await findComments({ github, owner, repo, issueNumber, provider, key: commentKey });
  const newest = mine[mine.length - 1];
  if (pending && newest && isReadyFor(newest, { provider, key: commentKey, owner, repo, commitSha })) {
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

module.exports = { PROVIDERS, STATES, BOT_LOGIN, marker, headings, render, findComments, readToc, tocSelect, changedLectures, run };

// For scripts/detect-changed-lectures.sh, which has the checkout but no
// JavaScript of its own, so that the deploy's list comes from tocSelect too:
//
//   node preview-comment.cjs toc-select < files
//
// with TOC_FILE and LECTURES_DIR in the environment, and the pull request's
// added and modified files on stdin, one to a line. It reads the toc from
// the working directory, which is the checkout, and prints each file the toc
// names and its page, separated by a tab. A toc it cannot read, or one that
// names no page, exits 2 with the warning on stderr.
function tocSelectCommand() {
  const tocFile = process.env.TOC_FILE || '';
  const lecturesDir = process.env.LECTURES_DIR || '';
  let text;
  try {
    text = fs.readFileSync(tocFile, 'utf8');
  } catch (e) {
    console.error(`Could not read toc-file ${tocFile} in the checkout, so no changed lectures are listed: ${e.message}`);
    return 2;
  }
  const files = fs.readFileSync(0, 'utf8').split('\n').filter(f => f);
  const { found, problem } = tocSelect(files, { lecturesDir, tocFile, text });
  if (problem) {
    console.error(problem);
    return 2;
  }
  for (const f of found) process.stdout.write(`${f.file}\t${f.page}\n`);
  return 0;
}

if (require.main === module) {
  if (process.argv[2] === 'toc-select') {
    process.exitCode = tocSelectCommand();
  } else {
    console.error('usage: node preview-comment.cjs toc-select < files');
    process.exitCode = 64;
  }
}
