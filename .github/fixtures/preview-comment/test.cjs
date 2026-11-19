// The preview-comment harness job (#153). It runs each preview action's own
// steps, read from its action.yml: the input check, as bash, and the comment
// steps against a stand-in for the GitHub API, that is the bash step that
// finds scripts/preview-comment.cjs, then the github-script body, called as
// actions/github-script calls it. Its promises:
//
//   - each deploy's comment renders exactly as it did before the script was
//     shared: the GOLDEN *.md files here are the bodies that the two inline
//     scripts of v0.14.0 rendered for the GOLDEN inputs below, run through
//     runSteps, and the shared script must render the hidden marker line and
//     then exactly that. preview-workers (#145) came after, so its WORKERS
//     fixtures were rendered by the shared script and read by eye;
//   - the action updates its own comment however many come before it, and
//     never anyone else's (finding M2 of the 2026-10-06 review);
//   - with placeholder: 'true', it posts the PENDING comment, *-pending*.md,
//     with the lectures the pull request changed by the rules of
//     scripts/detect-changed-lectures.sh, and the deploy's comment then
//     replaces that one in place, while the placeholder never replaces the
//     deploy's comment for its own commit;
//   - the input check refuses a deploy without its secrets or build-dir, a
//     placeholder without a valid site name, and a line break in build-dir,
//     lectures-dir, project-name, worker-name or account-subdomain (#267),
//     and never sees a secret; preview-workers' refuses a Worker name or
//     subdomain that is not a hostname label, and an alias that does not
//     fit in one with the Worker's name;
//   - with comment-key (#336), the comment has the key in its marker and
//     headings, the KEYED fixtures, and each key, and the comment with none,
//     keeps a comment of its own on one pull request, never taking another's;
//     the input check refuses a key that is not lowercase words joined by
//     dashes, at most 28 characters, on every event;
//   - with toc-file (#336), the placeholder lists the files of
//     ../preview-toc/changes.tsv that each site's toc names, as
//     ../preview-toc/<site>.tsv lists them, which is also what
//     preview-change-detection asserts of the deploy's change detection, and
//     links each at its page; a toc it cannot read, or that names no page, is
//     a warning, and the comment lists no lectures; the input check refuses a
//     toc-file that is not a plain path from the repository root.
//
// Usage: node test.cjs STEPS_JSON, where STEPS_JSON maps each action's
// directory to its `check-inputs`, `comment-script` and `comment` steps and
// every step's condition (the harness job writes it with PyYAML).
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const BOT = 'github-actions[bot]';
// The markers are a contract with every comment already posted: change one
// and each open pull request gets a second comment. So they are written out
// here, not read from the script.
const MARKER = {
  'preview-netlify': '<!-- quantecon-preview:netlify -->',
  'preview-cloudflare': '<!-- quantecon-preview:cloudflare -->',
  'preview-workers': '<!-- quantecon-preview:workers -->',
};
const CONTEXT = {
  owner: 'QuantEcon',
  repo: 'lecture-harness',
  number: 5,
  workflow: 'Build Project [using jupyter-book]',
  runId: 1234567890,
};
const SHA = '0123456789abcdef0123456789abcdef01234567';
const OLD_SHA = 'fedcba9876543210fedcba9876543210fedcba98';
const NETLIFY_URL = 'https://pr-5--harness-site.netlify.app';
const CLOUDFLARE_URL = 'https://pr-5.harness-project.pages.dev';
const WORKERS_URL = 'https://pr-5-harness-worker.harness-sub.workers.dev';
const TWO_LECTURES = 'lectures/aiyagari.md\nlectures/mccall_model.md';

// A keyed comment's marker: the provider's, with `:<key>` before its end.
const keyedMarker = (action, key) => MARKER[action].replace(/ -->$/, `:${key} -->`);

// toc-file's fixtures, shared with preview-change-detection: two sites' tocs,
// copied from QuantEcon/lectures, a pull request's files as the API lists
// them, and what each site's toc must list from them, as [file, page].
const TOC_FIXTURES = path.join(__dirname, '..', 'preview-toc');
const DP_TOC = 'sites/dp/_toc.yml';
const JAX_TOC = 'sites/jax/_toc.yml';
const tocText = file => fs.readFileSync(path.join(TOC_FIXTURES, file), 'utf8');
const TOCS = { [DP_TOC]: tocText(DP_TOC), [JAX_TOC]: tocText(JAX_TOC) };
const TOC_PR_FILES = tocText('changes.tsv').split('\n').filter(l => l && !l.startsWith('#')).map(l => {
  const [status, filename, previous] = l.split('\t');
  return previous ? { filename, status, previous_filename: previous } : { filename, status };
});
const tocListed = site => tocText(`${site}.tsv`).split('\n').filter(l => l).map(l => l.split('\t'));
const DP_LISTED = tocListed('dp');

// Each one is a fixture, <name>.md: the step env the action would pass, as
// the deploy and change detection would set it.
const GOLDEN = [
  {
    name: 'netlify-lectures', action: 'preview-netlify',
    env: { DEPLOY_URL: NETLIFY_URL, CHANGED_FILES: TWO_LECTURES, LECTURES_DIR: 'lectures', STRIP_LECTURES_DIR: 'true', COMMIT_SHA: SHA },
  },
  {
    // _toc.yml at the repository root, so the links keep lectures/.
    name: 'netlify-root-toc', action: 'preview-netlify',
    env: { DEPLOY_URL: NETLIFY_URL, CHANGED_FILES: 'lectures/sub/nested.md', LECTURES_DIR: 'lectures', STRIP_LECTURES_DIR: 'false', COMMIT_SHA: SHA },
  },
  {
    // lectures-dir: '', so change detection did not run.
    name: 'netlify-no-detection', action: 'preview-netlify',
    env: { DEPLOY_URL: NETLIFY_URL, CHANGED_FILES: '', LECTURES_DIR: '', STRIP_LECTURES_DIR: '', COMMIT_SHA: SHA },
  },
  {
    name: 'cloudflare-lectures', action: 'preview-cloudflare',
    env: { DEPLOY_URL: CLOUDFLARE_URL, DEPLOYMENT_URL: 'https://1a2b3c4d.harness-project.pages.dev', CHANGED_FILES: TWO_LECTURES, LECTURES_DIR: 'lectures', STRIP_LECTURES_DIR: 'true', COMMIT_SHA: SHA },
  },
  {
    // No lecture changed, and wrangler named no per-deployment URL.
    name: 'cloudflare-no-deployment-url', action: 'preview-cloudflare',
    env: { DEPLOY_URL: CLOUDFLARE_URL, DEPLOYMENT_URL: '', CHANGED_FILES: '', LECTURES_DIR: 'lectures', STRIP_LECTURES_DIR: 'true', COMMIT_SHA: SHA },
  },
];

// preview-workers' deploy comments, <name>.md, rendered by the shared script
// and read by eye: the same inputs as the Cloudflare ones above, on a Worker.
const WORKERS = [
  {
    name: 'workers-lectures', action: 'preview-workers',
    env: { DEPLOY_URL: WORKERS_URL, DEPLOYMENT_URL: 'https://1a2b3c4d-harness-worker.harness-sub.workers.dev', CHANGED_FILES: TWO_LECTURES, LECTURES_DIR: 'lectures', STRIP_LECTURES_DIR: 'true', COMMIT_SHA: SHA },
  },
  {
    // No lecture changed, and wrangler's record named no version URL.
    name: 'workers-no-deployment-url', action: 'preview-workers',
    env: { DEPLOY_URL: WORKERS_URL, DEPLOYMENT_URL: '', CHANGED_FILES: '', LECTURES_DIR: 'lectures', STRIP_LECTURES_DIR: 'true', COMMIT_SHA: SHA },
  },
];

// The pull request's files, as the REST API lists them, for the
// placeholder's change detection. Each line is one of the rules of
// scripts/detect-changed-lectures.sh: what is listed, and what is not.
const FILES = [
  ...Array.from({ length: 150 }, (_, i) => ({ filename: `data/file${String(i).padStart(3, '0')}.csv`, status: 'added' })),
  { filename: 'README.md', status: 'modified' },                         // not under lectures-dir
  { filename: 'lectures/aiyagari.md', status: 'modified' },              // listed
  { filename: 'lectures/new_one.md', status: 'added' },                  // listed
  { filename: 'lectures/renamed_to.md', status: 'renamed', previous_filename: 'lectures/renamed_from.md' },  // listed, new path
  { filename: 'lectures/gone.md', status: 'removed' },                   // removed
  { filename: 'lectures/intro.md', status: 'modified' },                 // the intro
  { filename: 'lectures/_static/notes.md', status: 'added' },            // starts with _ within lectures-dir
  { filename: 'lectures/_toc.yml', status: 'modified' },                 // not .md, and _
  { filename: 'lectures/sub/nested.md', status: 'added' },               // listed, nested
  { filename: 'lectures/sub/_draft.md', status: 'added' },               // listed: only the first level's _ counts
  { filename: 'lectures/data.csv', status: 'added' },                    // not .md
  { filename: 'lectures-old/stale.md', status: 'modified' },             // another directory
  { filename: 'other/lectures/x.md', status: 'modified' },               // lectures-dir is from the root
  { filename: 'lectures/copied.md', status: 'copied' },                  // listed: git without -C says A
  { filename: 'lectures/mode_only.md', status: 'changed' },              // listed: git says M
  { filename: 'lectures/same.md', status: 'unchanged' },                 // not changed
];
const LISTED = ['lectures/aiyagari.md', 'lectures/copied.md', 'lectures/mode_only.md', 'lectures/new_one.md',
  'lectures/renamed_to.md', 'lectures/sub/_draft.md', 'lectures/sub/nested.md'];
const TWO_FILES = [{ filename: 'lectures/mccall_model.md', status: 'modified' }, { filename: 'lectures/aiyagari.md', status: 'added' }];

// The placeholder's fixtures, <name>.md, rendered by this script and read by
// eye: the step env with placeholder: 'true', and what the API holds.
const PENDING = [
  {
    name: 'netlify-pending', action: 'preview-netlify',
    env: { PREVIEW_STATE: 'pending', PREVIEW_ALIAS: 'pr-5', PREVIEW_SITE: 'harness-site', LECTURES_DIR: 'lectures', COMMIT_SHA: SHA },
    api: { files: TWO_FILES, contents: ['lectures/_toc.yml'] },
  },
  {
    // No _toc.yml in lectures-dir, so the links keep it.
    name: 'netlify-pending-root-toc', action: 'preview-netlify',
    env: { PREVIEW_STATE: 'pending', PREVIEW_ALIAS: 'pr-5', PREVIEW_SITE: 'harness-site', LECTURES_DIR: 'lectures', COMMIT_SHA: SHA },
    api: { files: [{ filename: 'lectures/sub/nested.md', status: 'added' }], contents: ['_toc.yml'] },
  },
  {
    name: 'netlify-pending-no-detection', action: 'preview-netlify',
    env: { PREVIEW_STATE: 'pending', PREVIEW_ALIAS: 'pr-5', PREVIEW_SITE: 'harness-site', LECTURES_DIR: '', COMMIT_SHA: SHA },
    api: { files: TWO_FILES, contents: ['lectures/_toc.yml'] },
  },
  {
    name: 'cloudflare-pending', action: 'preview-cloudflare',
    env: { PREVIEW_STATE: 'pending', PREVIEW_ALIAS: 'pr-5', PREVIEW_SITE: 'harness-project', LECTURES_DIR: 'lectures', COMMIT_SHA: SHA },
    api: { files: TWO_FILES, contents: ['lectures/_toc.yml'] },
  },
  {
    // The site is <worker>.<subdomain>, as the input check writes it.
    name: 'workers-pending', action: 'preview-workers',
    env: { PREVIEW_STATE: 'pending', PREVIEW_ALIAS: 'pr-5', PREVIEW_SITE: 'harness-worker.harness-sub', LECTURES_DIR: 'lectures', COMMIT_SHA: SHA },
    api: { files: TWO_FILES, contents: ['lectures/_toc.yml'] },
  },
];

// comment-key's and toc-file's fixtures (#336), <name>.md, rendered by the
// shared script and read by eye: the deploy's comments, and the
// placeholder's.
const KEYED = [
  {
    // As change detection sets it from dp's toc: a pool lecture, a renamed
    // one and a page of the site's own, each at its page.
    name: 'netlify-keyed-toc', action: 'preview-netlify',
    env: { DEPLOY_URL: NETLIFY_URL, COMMENT_KEY: 'dp', CHANGED_FILES: DP_LISTED.map(([f]) => f).join('\n'), CHANGED_PAGES: DP_LISTED.map(([, p]) => p).join('\n'),
      LECTURES_DIR: 'lectures', TOC_FILE: DP_TOC, STRIP_LECTURES_DIR: 'false', COMMIT_SHA: SHA },
  },
  {
    // toc-file alone: the heading and marker with no key.
    name: 'netlify-toc', action: 'preview-netlify',
    env: { DEPLOY_URL: NETLIFY_URL, CHANGED_FILES: DP_LISTED.map(([f]) => f).join('\n'), CHANGED_PAGES: DP_LISTED.map(([, p]) => p).join('\n'),
      LECTURES_DIR: 'lectures', TOC_FILE: DP_TOC, STRIP_LECTURES_DIR: 'false', COMMIT_SHA: SHA },
  },
  {
    // comment-key alone: the lectures as without one.
    name: 'cloudflare-keyed', action: 'preview-cloudflare',
    env: { DEPLOY_URL: CLOUDFLARE_URL, COMMENT_KEY: 'dp', DEPLOYMENT_URL: 'https://1a2b3c4d.harness-project.pages.dev', CHANGED_FILES: TWO_LECTURES, LECTURES_DIR: 'lectures', STRIP_LECTURES_DIR: 'true', COMMIT_SHA: SHA },
  },
  {
    name: 'workers-keyed', action: 'preview-workers',
    env: { DEPLOY_URL: WORKERS_URL, COMMENT_KEY: 'dp', DEPLOYMENT_URL: 'https://1a2b3c4d-harness-worker.harness-sub.workers.dev', CHANGED_FILES: TWO_LECTURES, LECTURES_DIR: 'lectures', STRIP_LECTURES_DIR: 'true', COMMIT_SHA: SHA },
  },
];
const KEYED_PENDING = [
  {
    name: 'netlify-pending-keyed-toc', action: 'preview-netlify',
    env: { PREVIEW_STATE: 'pending', PREVIEW_ALIAS: 'pr-5', PREVIEW_SITE: 'harness-site', COMMENT_KEY: 'dp', LECTURES_DIR: 'lectures', TOC_FILE: DP_TOC, COMMIT_SHA: SHA },
    api: { files: TOC_PR_FILES, tocs: TOCS },
  },
  {
    // The other site on the same pull request, on another provider.
    name: 'cloudflare-pending-keyed-toc', action: 'preview-cloudflare',
    env: { PREVIEW_STATE: 'pending', PREVIEW_ALIAS: 'pr-5', PREVIEW_SITE: 'harness-project', COMMENT_KEY: 'jax', LECTURES_DIR: 'lectures', TOC_FILE: JAX_TOC, COMMIT_SHA: SHA },
    api: { files: TOC_PR_FILES, tocs: TOCS },
  },
  {
    // A toc that is not at the head: no lectures.
    name: 'netlify-pending-keyed', action: 'preview-netlify',
    env: { PREVIEW_STATE: 'pending', PREVIEW_ALIAS: 'pr-5', PREVIEW_SITE: 'harness-site', COMMENT_KEY: 'dp', LECTURES_DIR: 'lectures', TOC_FILE: 'sites/gone/_toc.yml', COMMIT_SHA: SHA },
    api: { files: TOC_PR_FILES, tocs: TOCS },
  },
];

const golden = name => [...GOLDEN, ...WORKERS, ...PENDING, ...KEYED, ...KEYED_PENDING].find(g => g.name === name);
const fixture = name => fs.readFileSync(path.join(__dirname, `${name}.md`), 'utf8');

// Comments, in the API's shape. Ids are positions, from 1.
const person = body => ({ user: { login: 'a-reviewer', type: 'User' }, body });
const bot = body => ({ user: { login: BOT, type: 'Bot' }, body });
const people = n => Array.from({ length: n }, (_, i) => person(`Review comment ${i + 1}`));
// A comment as v0.14.0 posted it, with no marker, and as the script posts it,
// after its key's marker when it has one.
const before = name => fixture(name);
const after = name => {
  const g = golden(name);
  return `${g.env.COMMENT_KEY ? keyedMarker(g.action, g.env.COMMENT_KEY) : MARKER[g.action]}\n${fixture(name)}`;
};
// The same, for an earlier push.
const earlier = body => body.split(SHA).join(OLD_SHA).split(SHA.substring(0, 7)).join(OLD_SHA.substring(0, 7));
// A keyed comment with another key, in its marker and its heading.
const rekey = (body, from, to) => body.replace(`:${from} -->\n`, `:${to} -->\n`).replace(` (${from})\n`, ` (${to})\n`);

// Each case runs one action with one golden's env on a pull request that
// already has `comments`, and expects one write: a new comment (`create`) or
// an update of the comment at position `update`, with that golden's body; or,
// with `expect: 'none'`, no write at all. A function, because the comments are
// built from the fixtures.
const lookupCases = () => [
  { name: 'no comments yet: posts one', golden: 'netlify-lectures', comments: [], expect: 'create' },
  { name: 'its comment, found by the marker', golden: 'netlify-lectures',
    comments: [...people(2), bot(after('netlify-lectures')), ...people(2)], expect: { update: 3 } },
  { name: 'its comment from before the marker, found by the heading', golden: 'netlify-lectures',
    comments: [person('Thanks!'), bot(before('netlify-lectures')), person('Pushed a fix.')], expect: { update: 2 } },
  // M2: one unpaginated listComments returns the first 30.
  { name: 'its comment after 150 others, past the first page', golden: 'netlify-lectures',
    comments: [...people(150), bot(before('netlify-lectures')), ...people(10)], expect: { update: 151 } },
  { name: 'its comment after 120 others, past the first page', golden: 'cloudflare-lectures',
    comments: [...people(120), bot(before('cloudflare-lectures'))], expect: { update: 121 } },
  // M2: the match accepted any author's comment.
  { name: 'a person quoting the comment, before its own: updates its own', golden: 'netlify-lectures',
    comments: [person(`> ${before('netlify-lectures').split('\n').join('\n> ')}\nWhy is this link broken?`),
      person(after('netlify-lectures')), bot(after('netlify-lectures'))], expect: { update: 3 } },
  { name: "a person's comment that starts with the heading, and none of its own: posts one", golden: 'netlify-lectures',
    comments: [person(before('netlify-lectures'))], expect: 'create' },
  { name: "another app's comment with the heading: posts one", golden: 'netlify-lectures',
    comments: [{ user: { login: 'netlify[bot]', type: 'Bot' }, body: before('netlify-lectures') }], expect: 'create' },
  { name: 'a bot comment that only mentions the heading: posts one', golden: 'netlify-lectures',
    comments: [bot(`A summary of this run.\n\n${before('netlify-lectures')}`)], expect: 'create' },
  { name: 'a bot comment that only mentions the marker: posts one', golden: 'netlify-lectures',
    comments: [bot(`A summary of this run.\n\n${after('netlify-lectures')}`)], expect: 'create' },
  { name: "the other preview action's comments only: posts one", golden: 'netlify-lectures',
    comments: [bot(before('cloudflare-lectures')), bot(after('cloudflare-lectures'))], expect: 'create' },
  { name: 'several of its comments, from the bug: updates the newest', golden: 'netlify-lectures',
    comments: [...people(35), bot(before('netlify-lectures')), ...people(5), bot(before('netlify-lectures')), person('ok')],
    expect: { update: 42 } },

  // The placeholder and the deploy share one comment.
  { name: "the deploy: replaces the placeholder's comment in place", golden: 'netlify-lectures',
    comments: [person('Thanks!'), bot(after('netlify-pending')), person('Looking now.')], expect: { update: 2 } },
  { name: "the deploy: replaces the placeholder's comment in place", golden: 'cloudflare-lectures',
    comments: [bot(after('cloudflare-pending'))], expect: { update: 1 } },
  { name: "the placeholder: replaces the deploy's comment for an earlier push", golden: 'netlify-pending',
    comments: [person('Thanks!'), bot(earlier(after('netlify-lectures')))], expect: { update: 2 } },
  { name: "the placeholder: replaces a comment from before the marker, for an earlier push", golden: 'cloudflare-pending',
    comments: [bot(earlier(before('cloudflare-lectures')))], expect: { update: 1 } },
  { name: 'the placeholder, re-run: updates its own pending comment', golden: 'netlify-pending',
    comments: [bot(after('netlify-pending'))], expect: { update: 1 } },
  { name: "the placeholder, after this push's deploy: leaves the deploy's comment", golden: 'netlify-pending',
    comments: [bot(after('netlify-lectures'))], expect: 'none' },
  { name: "the placeholder, after this push's deploy: leaves a comment from before the marker", golden: 'cloudflare-pending',
    comments: [bot(before('cloudflare-lectures'))], expect: 'none' },
  { name: "the placeholder: a person's comment quoting this push's deploy is not its own", golden: 'netlify-pending',
    comments: [person(after('netlify-lectures')), bot(earlier(after('netlify-lectures')))], expect: { update: 2 } },

  // preview-workers keeps a comment of its own beside preview-cloudflare's,
  // whose heading starts the same way, so a repository moving from one to
  // the other, or running both, never has one written over by the other.
  { name: "the deploy: replaces the placeholder's comment in place", golden: 'workers-lectures',
    comments: [person('Thanks!'), bot(after('workers-pending'))], expect: { update: 2 } },
  { name: "the placeholder, after this push's deploy: leaves the deploy's comment", golden: 'workers-pending',
    comments: [bot(after('workers-lectures'))], expect: 'none' },
  { name: "preview-cloudflare's comments only, with and without the marker: posts one", golden: 'workers-lectures',
    comments: [bot(before('cloudflare-lectures')), bot(after('cloudflare-lectures'))], expect: 'create' },
  { name: "preview-workers' comment only: posts one", golden: 'cloudflare-lectures',
    comments: [bot(before('workers-lectures')), bot(after('workers-lectures'))], expect: 'create' },

  // comment-key (#336): each key, and the comment with none, keeps its own.
  { name: 'keyed, beside the comment with no key: posts its own', golden: 'netlify-keyed-toc',
    comments: [bot(after('netlify-lectures'))], expect: 'create' },
  { name: 'keyed, beside a comment from before the marker: posts its own', golden: 'netlify-keyed-toc',
    comments: [bot(before('netlify-lectures'))], expect: 'create' },
  { name: 'keyed: updates its own, after the one with no key', golden: 'netlify-keyed-toc',
    comments: [bot(after('netlify-lectures')), person('Thanks!'), bot(earlier(after('netlify-keyed-toc')))], expect: { update: 3 } },
  { name: 'no key, beside a keyed comment: posts its own', golden: 'netlify-lectures',
    comments: [bot(after('netlify-keyed-toc'))], expect: 'create' },
  { name: 'no key: updates its own, not the keyed one after it', golden: 'netlify-lectures',
    comments: [bot(earlier(after('netlify-lectures'))), bot(after('netlify-keyed-toc'))], expect: { update: 1 } },
  { name: "keyed dp, beside dp-2's comment: posts its own", golden: 'netlify-keyed-toc',
    comments: [bot(rekey(after('netlify-keyed-toc'), 'dp', 'dp-2'))], expect: 'create' },
  { name: "keyed dp, beside d's comment: posts its own", golden: 'netlify-keyed-toc',
    comments: [bot(rekey(after('netlify-keyed-toc'), 'dp', 'd'))], expect: 'create' },
  { name: 'keyed: a comment with its heading and no marker is not its own', golden: 'netlify-keyed-toc',
    comments: [bot(before('netlify-keyed-toc'))], expect: 'create' },
  { name: "keyed, the deploy: replaces its placeholder's comment in place", golden: 'netlify-keyed-toc',
    comments: [bot(after('netlify-lectures')), bot(after('netlify-pending-keyed-toc'))], expect: { update: 2 } },
  { name: "keyed, the placeholder, after this push's keyed deploy: leaves the deploy's comment", golden: 'netlify-pending-keyed-toc',
    comments: [bot(after('netlify-keyed-toc'))], expect: 'none' },
  { name: "keyed, the placeholder, after this push's deploy with no key: posts its own", golden: 'netlify-pending-keyed-toc',
    comments: [bot(after('netlify-lectures'))], expect: 'create' },
  { name: "no key, the placeholder, after this push's keyed deploy: posts its own", golden: 'netlify-pending',
    comments: [bot(after('netlify-keyed-toc'))], expect: 'create' },
  { name: 'two keys on one provider: each updates its own', golden: 'cloudflare-pending-keyed-toc',
    comments: [bot(after('cloudflare-keyed')), bot(earlier(after('cloudflare-pending-keyed-toc')))], expect: { update: 2 } },
  { name: "the same key on preview-cloudflare: posts its own", golden: 'workers-keyed',
    comments: [bot(after('cloudflare-keyed'))], expect: 'create' },
];

// The input check's cases, one action each: `env` is the step's env, `rc` the
// exit status wanted, and `out` a pattern its output must match (or `quiet`,
// no output at all).
const NETLIFY_SET = { HAVE_TOKEN: 'true', HAVE_SITE_ID: 'true', HAVE_BUILD_DIR: 'true' };
const NETLIFY_NONE = { HAVE_TOKEN: 'false', HAVE_SITE_ID: 'false', HAVE_BUILD_DIR: 'false' };
const CLOUDFLARE_SET = { HAVE_TOKEN: 'true', HAVE_ACCOUNT_ID: 'true', HAVE_BUILD_DIR: 'true' };
const CLOUDFLARE_NONE = { HAVE_TOKEN: 'false', HAVE_ACCOUNT_ID: 'false', HAVE_BUILD_DIR: 'false' };
// preview-workers: a pull request from the repository itself, which deploys to
// pr-5, and what its check writes for the comment and the deploy step. A case
// with `output` must write exactly that to GITHUB_OUTPUT.
const WORKERS_DEPLOY = {
  PLACEHOLDER: 'false', DEPLOY: 'true', ALIAS: 'pr-5', WORKER_NAME: 'harness-worker', ACCOUNT_SUBDOMAIN: 'harness-sub',
  DISPATCH_ALIAS: '', BUILD_DIR: '_build/html', LECTURES_DIR: 'lectures',
};
const WORKERS_SET = CLOUDFLARE_SET;
const WORKERS_NONE = CLOUDFLARE_NONE;
const WORKERS_OUTPUT = 'subdomain=harness-sub\nsite=harness-worker.harness-sub\n';
const CHECKS = [
  { name: 'a deploy with every input, as every caller passes them', action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET }, rc: 0, out: 'quiet' },
  { name: 'a deploy without its token', action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET, HAVE_TOKEN: 'false' }, rc: 1,
    out: /^::error::A deploy needs netlify-auth-token, netlify-site-id and build-dir, and this run has no netlify-auth-token\. /m },
  { name: 'a deploy without its site ID', action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET, HAVE_SITE_ID: 'false' }, rc: 1,
    out: /this run has no netlify-site-id\. / },
  { name: 'a deploy without build-dir', action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET, HAVE_BUILD_DIR: 'false' }, rc: 1,
    out: /this run has no build-dir\. / },
  { name: 'a deploy without any of the three', action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_NONE }, rc: 1,
    out: /this run has no netlify-auth-token netlify-site-id build-dir\. / },
  { name: "a fork's pull request, which deploys nothing and has no secrets", action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'false', SITE_NAME: '', ...NETLIFY_NONE }, rc: 0, out: 'quiet' },
  { name: 'the placeholder, with a site name and no secrets', action: 'preview-netlify',
    env: { PLACEHOLDER: 'true', DEPLOY: 'true', SITE_NAME: 'harness-site', ...NETLIFY_NONE }, rc: 0, out: 'quiet' },
  { name: 'the placeholder, given the secrets it does not use', action: 'preview-netlify',
    env: { PLACEHOLDER: 'true', DEPLOY: 'true', SITE_NAME: 'harness-site', ...NETLIFY_SET }, rc: 0,
    out: /^::warning::netlify-auth-token is not used with placeholder: 'true'\..*\n::warning::netlify-site-id is not used/m },
  { name: 'the placeholder, without a site name', action: 'preview-netlify',
    env: { PLACEHOLDER: 'true', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_NONE }, rc: 1,
    out: /^::error::placeholder: 'true' needs netlify-site-name, .*; it is \[\]$/m },
  { name: 'the placeholder, with a site name that is not one', action: 'preview-netlify',
    env: { PLACEHOLDER: 'true', DEPLOY: 'true', SITE_NAME: 'Harness_Site', ...NETLIFY_NONE }, rc: 1,
    out: /it is \[Harness_Site\]$/m },
  { name: 'the placeholder, with a bad site name on a run that deploys nothing', action: 'preview-netlify',
    env: { PLACEHOLDER: 'true', DEPLOY: 'false', SITE_NAME: 'harness-site-', ...NETLIFY_NONE }, rc: 1,
    out: /it is \[harness-site-\]$/m },
  { name: 'placeholder neither true nor false', action: 'preview-netlify',
    env: { PLACEHOLDER: 'yes', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET }, rc: 1,
    out: /^::error::placeholder is \[yes\], not 'true' or 'false'$/m },
  { name: 'placeholder with a line break, escaped into one annotation', action: 'preview-netlify',
    env: { PLACEHOLDER: 'true\n::warning::injected', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET }, rc: 1,
    out: /^::error::placeholder is \[true%0A::warning::injected\], not 'true' or 'false'\n?$/ },
  { name: 'a deploy with build-dir and lectures-dir, each on one line', action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET, BUILD_DIR: '_build/html', LECTURES_DIR: 'lectures' },
    rc: 0, out: 'quiet' },
  { name: 'lectures-dir with a line break, refused before anything else and escaped', action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET, BUILD_DIR: '_build/html', LECTURES_DIR: 'lectures\n::warning::injected' },
    rc: 1, out: /^::error::lectures-dir must be a single line, got 'lectures%0A::warning::injected'\n?$/ },
  { name: "build-dir with a line break, on a fork's run that deploys nothing", action: 'preview-netlify',
    env: { PLACEHOLDER: 'false', DEPLOY: 'false', SITE_NAME: '', ...NETLIFY_NONE, BUILD_DIR: '_build/html\r\n' },
    rc: 1, out: /^::error::build-dir must be a single line, got '_build\/html%0D%0A'\n?$/ },
  { name: 'a deploy with every input, as every caller passes them', action: 'preview-cloudflare',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', ...CLOUDFLARE_SET }, rc: 0, out: 'quiet' },
  { name: 'a deploy without its account ID', action: 'preview-cloudflare',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', ...CLOUDFLARE_SET, HAVE_ACCOUNT_ID: 'false' }, rc: 1,
    out: /^::error::A deploy needs cloudflare-api-token, cloudflare-account-id and build-dir, and this run has no cloudflare-account-id\. /m },
  { name: 'a deploy without any of the three', action: 'preview-cloudflare',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', ...CLOUDFLARE_NONE }, rc: 1,
    out: /this run has no cloudflare-api-token cloudflare-account-id build-dir\. / },
  { name: "a fork's pull request, which deploys nothing and has no secrets", action: 'preview-cloudflare',
    env: { PLACEHOLDER: 'false', DEPLOY: 'false', ...CLOUDFLARE_NONE }, rc: 0, out: 'quiet' },
  { name: 'the placeholder, with no secrets', action: 'preview-cloudflare',
    env: { PLACEHOLDER: 'true', DEPLOY: 'true', ...CLOUDFLARE_NONE }, rc: 0, out: 'quiet' },
  { name: 'the placeholder, given the token it does not use', action: 'preview-cloudflare',
    env: { PLACEHOLDER: 'true', DEPLOY: 'true', ...CLOUDFLARE_NONE, HAVE_TOKEN: 'true' }, rc: 0,
    out: /^::warning::cloudflare-api-token is not used with placeholder: 'true'\. [^\n]*\n?$/ },
  { name: 'placeholder neither true nor false', action: 'preview-cloudflare',
    env: { PLACEHOLDER: 'True', DEPLOY: 'true', ...CLOUDFLARE_SET }, rc: 1,
    out: /^::error::placeholder is \[True\], not 'true' or 'false'$/m },
  { name: 'project-name with a line break, refused before anything else and escaped', action: 'preview-cloudflare',
    env: { PLACEHOLDER: 'false', DEPLOY: 'true', ...CLOUDFLARE_SET, PROJECT_NAME: 'harness\n::warning::injected', BUILD_DIR: '_build/html' },
    rc: 1, out: /^::error::project-name must be a single line, got 'harness%0A::warning::injected'\n?$/ },
  { name: 'a deploy with every input, as every caller passes them', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET }, rc: 0, out: 'quiet', output: WORKERS_OUTPUT },
  { name: 'a deploy without its token', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, HAVE_TOKEN: 'false' }, rc: 1,
    out: /^::error::A deploy needs cloudflare-api-token, cloudflare-account-id and build-dir, and this run has no cloudflare-api-token\. /m },
  { name: 'a deploy without any of the three', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_NONE }, rc: 1,
    out: /this run has no cloudflare-api-token cloudflare-account-id build-dir\. / },
  { name: "a fork's pull request, which deploys nothing and has no secrets", action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, DEPLOY: 'false', ALIAS: '', ...WORKERS_NONE }, rc: 0, out: 'quiet', output: WORKERS_OUTPUT },
  { name: 'the placeholder, with no secrets', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, PLACEHOLDER: 'true', ...WORKERS_NONE }, rc: 0, out: 'quiet', output: WORKERS_OUTPUT },
  { name: 'the placeholder, given the account ID it does not use', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, PLACEHOLDER: 'true', ...WORKERS_NONE, HAVE_ACCOUNT_ID: 'true' }, rc: 0,
    out: /^::warning::cloudflare-account-id is not used with placeholder: 'true'\. [^\n]*\n?$/ },
  { name: 'placeholder neither true nor false', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, PLACEHOLDER: 'yes' }, rc: 1,
    out: /^::error::placeholder is \[yes\], not 'true' or 'false'$/m },
  { name: 'account-subdomain given as its workers.dev address', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, ACCOUNT_SUBDOMAIN: 'harness-sub.workers.dev' }, rc: 0, out: 'quiet', output: WORKERS_OUTPUT },
  { name: 'account-subdomain given as a URL, in capitals', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, ACCOUNT_SUBDOMAIN: 'https://Harness-Sub.workers.dev/' }, rc: 0, out: 'quiet', output: WORKERS_OUTPUT },
  { name: 'account-subdomain that is not one label', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, ACCOUNT_SUBDOMAIN: 'harness.sub' }, rc: 1,
    out: /^::error::account-subdomain \[harness\.sub\] is not a workers\.dev subdomain; /m },
  { name: 'account-subdomain empty, on a placeholder', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, PLACEHOLDER: 'true', ...WORKERS_NONE, ACCOUNT_SUBDOMAIN: '' }, rc: 1,
    out: /^::error::account-subdomain \[\] is not a workers\.dev subdomain; /m },
  { name: "worker-name with a capital and an underscore, on a fork's run that deploys nothing", action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, DEPLOY: 'false', ALIAS: '', ...WORKERS_NONE, WORKER_NAME: 'Harness_Worker' }, rc: 1,
    out: /^::error::worker-name \[Harness_Worker\] is not a valid workers\.dev hostname label /m },
  { name: 'worker-name ending with a dash', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, WORKER_NAME: 'harness-worker-' }, rc: 1,
    out: /^::error::worker-name \[harness-worker-\] is not a valid/m },
  { name: 'worker-name empty', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, WORKER_NAME: '' }, rc: 1,
    out: /^::error::worker-name \[\] is not a valid/m },
  { name: 'worker-name of 54 characters, on pull request 99999: fits', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, ALIAS: 'pr-99999', WORKER_NAME: 'w'.repeat(54) }, rc: 0, out: 'quiet',
    output: `subdomain=harness-sub\nsite=${'w'.repeat(54)}.harness-sub\n` },
  { name: 'worker-name of 55 characters, on pull request 99999: too long', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, ALIAS: 'pr-99999', WORKER_NAME: 'w'.repeat(55) }, rc: 1,
    out: /^::error::worker-name \[w{55}\] is too long for this preview: \[pr-99999-w{55}\] must fit in one 63-character hostname label\.$/m },
  { name: 'the same, for the placeholder', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, PLACEHOLDER: 'true', ...WORKERS_NONE, ALIAS: 'pr-99999', WORKER_NAME: 'w'.repeat(55) }, rc: 1,
    out: /is too long for this preview: \[pr-99999-w{55}\]/ },
  { name: "the same, on a fork's run that deploys nothing", action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, DEPLOY: 'false', ALIAS: '', ...WORKERS_NONE, WORKER_NAME: 'w'.repeat(55) }, rc: 0, out: 'quiet' },
  { name: 'a dispatch-alias of 28 characters with a worker-name of 34: fits', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, DISPATCH_ALIAS: 'dispatch-abcdefghijklmnopqrs', WORKER_NAME: 'w'.repeat(34) }, rc: 0, out: 'quiet' },
  { name: 'a dispatch-alias of 28 characters with a worker-name of 35, on a pull request: too long', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, DISPATCH_ALIAS: 'dispatch-abcdefghijklmnopqrs', WORKER_NAME: 'w'.repeat(35) }, rc: 1,
    out: /^::error::dispatch-alias \[dispatch-abcdefghijklmnopqrs\] is too long for this Worker: \[dispatch-abcdefghijklmnopqrs-w{35}\] must fit in one 63-character hostname label\.$/m },
  { name: 'worker-name with a line break, refused before anything else and escaped', action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, ...WORKERS_SET, WORKER_NAME: 'harness-worker\n::warning::injected' }, rc: 1,
    out: /^::error::worker-name must be a single line, got 'harness-worker%0A::warning::injected'\n?$/ },
  { name: "account-subdomain with a line break, on a fork's run that deploys nothing", action: 'preview-workers',
    env: { ...WORKERS_DEPLOY, DEPLOY: 'false', ALIAS: '', ...WORKERS_NONE, ACCOUNT_SUBDOMAIN: 'harness-sub\r\n' }, rc: 1,
    out: /^::error::account-subdomain must be a single line, got 'harness-sub%0D%0A'\n?$/ },
  ...keyAndTocChecks(),
];

// comment-key's and toc-file's input checks (#336), the same in each action:
// from a deploy with every other input set, and on a fork's run, which
// deploys nothing but is checked all the same.
function keyAndTocChecks() {
  const base = {
    'preview-netlify': [{ PLACEHOLDER: 'false', DEPLOY: 'true', SITE_NAME: '', ...NETLIFY_SET, BUILD_DIR: '_build/html', LECTURES_DIR: 'lectures' },
      { PLACEHOLDER: 'false', DEPLOY: 'false', SITE_NAME: '', ...NETLIFY_NONE, LECTURES_DIR: 'lectures' }],
    'preview-cloudflare': [{ PLACEHOLDER: 'false', DEPLOY: 'true', ...CLOUDFLARE_SET, PROJECT_NAME: 'harness-project', BUILD_DIR: '_build/html', LECTURES_DIR: 'lectures' },
      { PLACEHOLDER: 'false', DEPLOY: 'false', ...CLOUDFLARE_NONE, PROJECT_NAME: 'harness-project', LECTURES_DIR: 'lectures' }],
    'preview-workers': [{ ...WORKERS_DEPLOY, ...WORKERS_SET },
      { ...WORKERS_DEPLOY, DEPLOY: 'false', ALIAS: '', ...WORKERS_NONE }],
  };
  const cases = [];
  for (const [action, [deploy, fork]] of Object.entries(base)) {
    const output = action === 'preview-workers' ? { output: WORKERS_OUTPUT } : {};
    const ok = (name, env) => cases.push({ name, action, env: { ...deploy, ...env }, rc: 0, out: 'quiet', ...output });
    const refused = (name, env, out, from = deploy) => cases.push({ name, action, env: { ...from, ...env }, rc: 1, out });
    ok('comment-key and toc-file, as a site in a matrix passes them', { COMMENT_KEY: 'dp', TOC_FILE: DP_TOC });
    ok('comment-key of 28 characters', { COMMENT_KEY: `${'a'.repeat(13)}-${'b'.repeat(14)}` });
    ok('toc-file in lectures-dir, or at the root', { TOC_FILE: 'lectures/_toc.yml' });
    for (const key of ['a'.repeat(29), 'DP', 'dp_2', '-dp', 'dp-', 'dp--2', 'dp 2']) {
      refused(`comment-key [${key}]`, { COMMENT_KEY: key },
        new RegExp(`^::error::comment-key is \\[${key}\\], not lowercase letters and digits in words joined by single dashes, at most 28 characters\\n?$`));
    }
    refused("a bad comment-key on a fork's run that deploys nothing", { COMMENT_KEY: 'DP' }, /^::error::comment-key is \[DP\], /, fork);
    refused('comment-key with a line break, refused before anything else and escaped', { COMMENT_KEY: 'dp\n::warning::injected' },
      /^::error::comment-key must be a single line, got 'dp%0A::warning::injected'\n?$/);
    for (const toc of ['/sites/dp/_toc.yml', '../_toc.yml', 'sites/../_toc.yml', './sites/dp/_toc.yml', 'sites/./dp/_toc.yml', 'sites//dp/_toc.yml', 'sites/dp/']) {
      refused(`toc-file [${toc}]`, { TOC_FILE: toc },
        new RegExp(`^::error::toc-file is \\[${toc.replace(/\./g, '\\.')}\\], not a path from the repository root such as sites/dp/_toc\\.yml: `));
    }
    refused("a bad toc-file on a fork's run that deploys nothing", { TOC_FILE: '../_toc.yml' }, /^::error::toc-file is \[\.\.\/_toc\.yml\], /, fork);
    refused('toc-file with a line break, refused before anything else and escaped', { TOC_FILE: 'sites/dp/_toc.yml\r\n' },
      /^::error::toc-file must be a single line, got 'sites\/dp\/_toc\.yml%0D%0A'\n?$/);
    cases.push({ name: "toc-file with lectures-dir: ''", action, env: { ...deploy, TOC_FILE: DP_TOC, LECTURES_DIR: '' }, rc: 0,
      out: /^::warning::toc-file is not used with lectures-dir: '', which turns change detection off\.\n?$/, ...output });
  }
  return cases;
}

// What each action's steps must say, where the cases above take a value for
// granted: the expressions behind the env that test cases fill in, and the
// conditions that keep the placeholder from installing or deploying.
const WIRING = {
  common: {
    comment: {
      PREVIEW_COMMENT_SCRIPT: '${{ steps.comment-script.outputs.path }}',
      PREVIEW_STATE: "${{ inputs.placeholder == 'true' && 'pending' || 'ready' }}",
      PREVIEW_ALIAS: '${{ steps.decide.outputs.alias }}',
      COMMENT_KEY: '${{ inputs.comment-key }}',
      TOC_FILE: '${{ inputs.toc-file }}',
      CHANGED_FILES: '${{ steps.detect-changes.outputs.changed-files }}',
      CHANGED_PAGES: '${{ steps.detect-changes.outputs.changed-pages }}',
      LECTURES_DIR: '${{ inputs.lectures-dir }}',
    },
    // The deploy's change detection, which reads toc-file from the checkout.
    detect: {
      LECTURES_DIR: '${{ inputs.lectures-dir }}',
      TOC_FILE: '${{ inputs.toc-file }}',
    },
    if: {
      'detect-changes': "steps.decide.outputs.deploy == 'true' && inputs.placeholder != 'true' && inputs.lectures-dir != '' && github.event_name == 'pull_request'",
      'install-cli': "steps.decide.outputs.deploy == 'true' && inputs.placeholder != 'true'",
      deploy: "steps.decide.outputs.deploy == 'true' && inputs.placeholder != 'true'",
      'comment-script': "steps.decide.outputs.deploy == 'true' && github.event_name == 'pull_request' && (inputs.placeholder == 'true' || steps.deploy.outputs.deploy-url != '')",
      comment: "steps.decide.outputs.deploy == 'true' && github.event_name == 'pull_request' && (inputs.placeholder == 'true' || steps.deploy.outputs.deploy-url != '')",
      'check-inputs': '',
    },
  },
  'preview-netlify': {
    comment: { PREVIEW_SITE: '${{ inputs.netlify-site-name }}' },
    check: {
      PLACEHOLDER: '${{ inputs.placeholder }}', DEPLOY: '${{ steps.decide.outputs.deploy }}', SITE_NAME: '${{ inputs.netlify-site-name }}',
      HAVE_TOKEN: "${{ inputs.netlify-auth-token != '' }}", HAVE_SITE_ID: "${{ inputs.netlify-site-id != '' }}", HAVE_BUILD_DIR: "${{ inputs.build-dir != '' }}",
      BUILD_DIR: '${{ inputs.build-dir }}', LECTURES_DIR: '${{ inputs.lectures-dir }}',
      TOC_FILE: '${{ inputs.toc-file }}', COMMENT_KEY: '${{ inputs.comment-key }}',
    },
  },
  'preview-cloudflare': {
    comment: { PREVIEW_SITE: '${{ inputs.project-name }}' },
    check: {
      PLACEHOLDER: '${{ inputs.placeholder }}', DEPLOY: '${{ steps.decide.outputs.deploy }}',
      HAVE_TOKEN: "${{ inputs.cloudflare-api-token != '' }}", HAVE_ACCOUNT_ID: "${{ inputs.cloudflare-account-id != '' }}", HAVE_BUILD_DIR: "${{ inputs.build-dir != '' }}",
      PROJECT_NAME: '${{ inputs.project-name }}', BUILD_DIR: '${{ inputs.build-dir }}', LECTURES_DIR: '${{ inputs.lectures-dir }}',
      TOC_FILE: '${{ inputs.toc-file }}', COMMENT_KEY: '${{ inputs.comment-key }}',
    },
  },
  'preview-workers': {
    comment: { PREVIEW_SITE: '${{ steps.check-inputs.outputs.site }}' },
    check: {
      PLACEHOLDER: '${{ inputs.placeholder }}', DEPLOY: '${{ steps.decide.outputs.deploy }}', ALIAS: '${{ steps.decide.outputs.alias }}',
      HAVE_TOKEN: "${{ inputs.cloudflare-api-token != '' }}", HAVE_ACCOUNT_ID: "${{ inputs.cloudflare-account-id != '' }}", HAVE_BUILD_DIR: "${{ inputs.build-dir != '' }}",
      WORKER_NAME: '${{ inputs.worker-name }}', ACCOUNT_SUBDOMAIN: '${{ inputs.account-subdomain }}', DISPATCH_ALIAS: '${{ inputs.dispatch-alias }}',
      BUILD_DIR: '${{ inputs.build-dir }}', LECTURES_DIR: '${{ inputs.lectures-dir }}',
      TOC_FILE: '${{ inputs.toc-file }}', COMMENT_KEY: '${{ inputs.comment-key }}',
    },
  },
};

// A stand-in for the Octokit client actions/github-script passes as `github`.
// listComments and listFiles serve one page, 30 items unless per_page says
// otherwise (at most 100), as the REST API does; paginate fetches every page.
// getContent finds only the paths in `api.contents`, and those in `api.tocs`
// with their text, base64-encoded as the API sends a file, and answers 404
// for any other, as the API does; `api.fail` makes the named call fail.
function stubGitHub(comments, api = {}) {
  const stored = comments.map((c, i) => ({ id: i + 1, ...c }));
  const writes = [];
  const calls = [];
  const checkTarget = (op, p) => {
    if (p.owner !== CONTEXT.owner || p.repo !== CONTEXT.repo) {
      throw new Error(`${op} called for ${p.owner}/${p.repo}, not ${CONTEXT.owner}/${CONTEXT.repo}`);
    }
  };
  const checkIssue = (op, p) => {
    checkTarget(op, p);
    if (p.issue_number !== CONTEXT.number) throw new Error(`${op} called for issue ${p.issue_number}, not ${CONTEXT.number}`);
  };
  const page = (items, p) => {
    const size = Math.min(p.per_page || 30, 100);
    const n = p.page || 1;
    return { data: structuredClone(items.slice((n - 1) * size, n * size)) };
  };
  const failing = op => {
    if (api.fail === op) throw Object.assign(new Error(`stand-in ${op} failure`), { status: 500 });
  };
  const issues = {
    listComments: async p => {
      checkIssue('listComments', p);
      return page(stored, p);
    },
    createComment: async p => {
      checkIssue('createComment', p);
      writes.push({ op: 'create', body: p.body });
      return { data: { id: stored.length + 1 } };
    },
    updateComment: async p => {
      checkTarget('updateComment', p);
      writes.push({ op: 'update', id: p.comment_id, body: p.body });
      return { data: { id: p.comment_id } };
    },
  };
  const pulls = {
    listFiles: async p => {
      calls.push('listFiles');
      checkTarget('listFiles', p);
      if (p.pull_number !== CONTEXT.number) throw new Error(`listFiles called for pull request ${p.pull_number}, not ${CONTEXT.number}`);
      failing('listFiles');
      return page(api.files || [], p);
    },
  };
  const repos = {
    getContent: async p => {
      calls.push(`getContent ${p.path}@${p.ref}`);
      checkTarget('getContent', p);
      if (p.ref !== SHA) throw new Error(`getContent called at ${p.ref}, not the pull request's head`);
      failing('getContent');
      if ((api.contents || []).includes(p.path)) return { data: { type: 'file', path: p.path } };
      if (api.tocs && Object.hasOwn(api.tocs, p.path)) {
        return { data: { type: 'file', path: p.path, encoding: 'base64', content: Buffer.from(api.tocs[p.path]).toString('base64') } };
      }
      throw Object.assign(new Error('Not Found'), { status: 404 });
    },
  };
  const paginate = async (method, params) => {
    const size = Math.min(params.per_page || 30, 100);
    const all = [];
    for (let n = 1; ; n++) {
      const { data } = await method({ ...params, page: n });
      all.push(...data);
      if (data.length < size) return all;
    }
  };
  return { github: { rest: { issues, pulls, repos }, paginate }, writes, calls };
}

const stubCore = () => {
  const log = [];
  const say = level => msg => log.push(`${level}: ${msg}`);
  return { log, core: { info: say('info'), notice: say('notice'), warning: say('warning'), error: say('error'), debug: () => {}, setFailed: say('failed') } };
};

const EXPRESSION = /\$\{\{/;
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

// Run a bash step as `shell: bash` runs it, in the action's directory, with
// `env` added; return its status, output and GITHUB_OUTPUT.
function runBash(dir, run, env) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'preview-comment-'));
  try {
    const script = path.join(tmp, 'step.sh');
    const output = path.join(tmp, 'output');
    fs.writeFileSync(script, run);
    fs.writeFileSync(output, '');
    const r = spawnSync('bash', ['--noprofile', '--norc', '-eo', 'pipefail', script], {
      env: { ...process.env, ...env, GITHUB_ACTION_PATH: dir, GITHUB_OUTPUT: output },
      encoding: 'utf8',
    });
    return { status: r.status, stdout: r.stdout, stderr: r.stderr, output: fs.readFileSync(output, 'utf8') };
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

// Run an action's two comment steps as the runner would on a pull request,
// with `values` for the step env's expressions, on a pull request with
// `comments` and, for the placeholder, the files and contents in `api`.
async function runSteps(steps, action, values, comments, api = {}) {
  const s = steps[action];
  if (!s) throw new Error(`no steps read for ${action}`);

  if (s.resolve.shell !== 'bash') throw new Error(`${action}: the comment-script step's shell is [${s.resolve.shell}], not bash`);
  const r = runBash(s.dir, s.resolve.run, {});
  if (r.status !== 0) throw new Error(`${action}: the comment-script step exited ${r.status}: ${r.stdout}${r.stderr}`);
  const found = r.output.match(/^path=(.*)$/m);
  if (!found) throw new Error(`${action}: the comment-script step wrote no path output`);

  // The github-script step.
  const c = s.comment;
  if (!/^actions\/github-script@/.test(c.uses)) throw new Error(`${action}: the comment step uses [${c.uses}]`);
  if (c.with['github-token'] !== '${{ github.token }}') throw new Error(`${action}: the comment step's github-token is [${c.with['github-token']}]`);
  if (c.env.PREVIEW_COMMENT_SCRIPT !== '${{ steps.comment-script.outputs.path }}') {
    throw new Error(`${action}: PREVIEW_COMMENT_SCRIPT is [${c.env.PREVIEW_COMMENT_SCRIPT}], not the comment-script step's path`);
  }
  for (const key of Object.keys(values)) {
    if (!(key in c.env)) throw new Error(`${action}: the comment step does not pass ${key}`);
  }
  const env = {};
  for (const [key, value] of Object.entries(c.env)) {
    if (key === 'PREVIEW_COMMENT_SCRIPT') env[key] = found[1];
    // What its expression gives without placeholder: 'true' (WIRING).
    else if (key === 'PREVIEW_STATE' && !(key in values)) env[key] = 'ready';
    else if (EXPRESSION.test(String(value))) env[key] = values[key] ?? '';
    else env[key] = String(value);
  }

  const { github, writes, calls } = stubGitHub(comments, api);
  const { core, log } = stubCore();
  const context = {
    repo: { owner: CONTEXT.owner, repo: CONTEXT.repo },
    issue: { owner: CONTEXT.owner, repo: CONTEXT.repo, number: CONTEXT.number },
    workflow: CONTEXT.workflow,
    runId: CONTEXT.runId,
    eventName: 'pull_request',
    payload: {},
  };
  const saved = { ...process.env };
  Object.assign(process.env, env);
  let error;
  try {
    await new AsyncFunction('require', 'github', 'context', 'core', c.with.script)(require, github, context, core);
  } catch (e) {
    // actions/github-script fails the step on this.
    error = e;
  } finally {
    for (const key of Object.keys(env)) {
      if (key in saved) process.env[key] = saved[key]; else delete process.env[key];
    }
  }
  return { writes, log, error, calls };
}

// Where two bodies first differ, with a line either side.
function difference(want, got) {
  const w = want.split('\n'), g = got.split('\n');
  let i = 0;
  while (i < Math.max(w.length, g.length) && w[i] === g[i]) i++;
  const show = lines => lines.slice(Math.max(0, i - 1), i + 2).map(l => `    ${JSON.stringify(l)}`).join('\n');
  return `first difference at line ${i + 1}; expected:\n${show(w)}\n  got:\n${show(g)}`;
}

async function main() {
  const steps = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  let n = 0, bad = 0;
  const check = async (name, fn) => {
    n++;
    try {
      await fn();
      console.log(`✓ ${name}`);
    } catch (e) {
      bad++;
      console.log(`::error::${name}: ${String(e.message).replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A')}`);
    }
  };
  const writesOf = ({ writes, log, error }) => {
    if (error) throw new Error(`the step failed: ${error.message}`);
    return { writes, log };
  };
  const oneWrite = result => {
    const { writes, log } = writesOf(result);
    if (writes.length !== 1) throw new Error(`expected one write, got ${writes.length}: [${writes.map(w => w.op + (w.id ? ` ${w.id}` : '')).join(', ')}]; log: [${log.join(' | ')}]`);
    return writes[0];
  };
  const runGolden = (g, comments) => runSteps(steps, g.action, g.env, comments, g.api);

  for (const action of ['preview-netlify', 'preview-cloudflare', 'preview-workers']) {
    await check(`${action}: its steps' conditions and env are wired as the cases assume`, async () => {
      const s = steps[action];
      const problems = [];
      for (const [key, want] of Object.entries({ ...WIRING.common.comment, ...WIRING[action].comment })) {
        if (s.comment.env[key] !== want) problems.push(`comment env ${key} is [${s.comment.env[key]}], not [${want}]`);
      }
      for (const [id, want] of Object.entries(WIRING.common.if)) {
        if (s.if[id] !== want) problems.push(`step ${id}'s if is [${s.if[id]}], not [${want}]`);
      }
      for (const [key, want] of Object.entries(WIRING.common.detect)) {
        if (s.detect.env[key] !== want) problems.push(`detect-changes env ${key} is [${s.detect.env[key]}], not [${want}]`);
      }
      const want = WIRING[action].check;
      for (const key of new Set([...Object.keys(want), ...Object.keys(s.check.env)])) {
        if (s.check.env[key] !== want[key]) problems.push(`check-inputs env ${key} is [${s.check.env[key]}], not [${want[key]}]`);
      }
      if (problems.length) throw new Error(problems.join('; '));
    });
  }

  for (const t of CHECKS) {
    await check(`${t.action}: the input check, ${t.name}`, async () => {
      const s = steps[t.action];
      if (s.check.shell !== 'bash') throw new Error(`the check-inputs step's shell is [${s.check.shell}], not bash`);
      const r = runBash(s.dir, s.check.run, t.env);
      const out = r.stdout + r.stderr;
      if (r.status !== t.rc) throw new Error(`exited ${r.status}, not ${t.rc}; output: [${out}]`);
      if (t.out === 'quiet' ? out !== '' : !t.out.test(out)) throw new Error(`output [${out}] does not match ${t.out}`);
      if (t.output !== undefined && r.output !== t.output) throw new Error(`GITHUB_OUTPUT holds ${JSON.stringify(r.output)}, not ${JSON.stringify(t.output)}`);
    });
  }

  for (const g of [...GOLDEN, ...WORKERS]) {
    await check(`${g.action}: renders ${g.name}.md, after the marker`, async () => {
      const result = await runGolden(g, []);
      const w = oneWrite(result);
      if (w.op !== 'create') throw new Error(`expected a new comment, got ${w.op} ${w.id}`);
      const want = after(g.name);
      if (w.body !== want) throw new Error(difference(want, w.body));
      if (result.calls.length) throw new Error(`the deploy's comment asked the API for [${result.calls.join(', ')}], which change detection gives it`);
    });
  }

  for (const g of PENDING) {
    await check(`${g.action}: the placeholder renders ${g.name}.md, after the marker`, async () => {
      const w = oneWrite(await runGolden(g, []));
      if (w.op !== 'create') throw new Error(`expected a new comment, got ${w.op} ${w.id}`);
      const want = after(g.name);
      if (w.body !== want) throw new Error(difference(want, w.body));
    });
  }

  await check('preview-netlify: the placeholder lists the changed lectures by change detection\'s rules, from every page', async () => {
    const g = golden('netlify-pending');
    const { log } = writesOf(await runSteps(steps, g.action, g.env, [], { files: FILES, contents: ['lectures/_toc.yml'] }));
    const listed = log.filter(l => l.startsWith('info: ✓ Changed: ')).map(l => l.slice('info: ✓ Changed: '.length));
    if (listed.join('\n') !== LISTED.join('\n')) throw new Error(`listed [${listed.join(', ')}], not [${LISTED.join(', ')}]`);
  });

  for (const op of ['listFiles', 'getContent']) {
    await check(`preview-netlify: the placeholder, when ${op} fails: warns, and posts the comment with no lectures`, async () => {
      const g = golden('netlify-pending');
      const result = await runSteps(steps, g.action, g.env, [], { files: TWO_FILES, contents: ['lectures/_toc.yml'], fail: op });
      const w = oneWrite(result);
      if (!result.log.some(l => /^warning: Could not .*so no changed lectures are listed: stand-in/.test(l))) {
        throw new Error(`no warning; log: [${result.log.join(' | ')}]`);
      }
      if (w.body !== after('netlify-pending-no-detection')) throw new Error(difference(after('netlify-pending-no-detection'), w.body));
    });
  }

  // comment-key and toc-file (#336).
  for (const g of KEYED) {
    await check(`${g.action}: renders ${g.name}.md, after its marker`, async () => {
      const result = await runGolden(g, []);
      const w = oneWrite(result);
      if (w.op !== 'create') throw new Error(`expected a new comment, got ${w.op} ${w.id}`);
      if (w.body !== after(g.name)) throw new Error(difference(after(g.name), w.body));
      if (result.calls.length) throw new Error(`the deploy's comment asked the API for [${result.calls.join(', ')}], which change detection gives it`);
    });
  }

  for (const g of KEYED_PENDING) {
    await check(`${g.action}: the placeholder renders ${g.name}.md, after its marker`, async () => {
      const w = oneWrite(await runGolden(g, []));
      if (w.op !== 'create') throw new Error(`expected a new comment, got ${w.op} ${w.id}`);
      if (w.body !== after(g.name)) throw new Error(difference(after(g.name), w.body));
    });
  }

  for (const [site, name] of [['dp', 'netlify-pending-keyed-toc'], ['jax', 'cloudflare-pending-keyed-toc']]) {
    await check(`the placeholder lists what ${site}'s toc names, as preview-toc/${site}.tsv, with no warning`, async () => {
      const g = golden(name);
      const { log } = writesOf(await runGolden(g, []));
      const listed = log.filter(l => l.startsWith('info: ✓ Changed: ')).map(l => l.slice('info: ✓ Changed: '.length));
      const want = tocListed(site).map(([f]) => f);
      if (listed.join('\n') !== want.join('\n')) throw new Error(`listed [${listed.join(', ')}], not [${want.join(', ')}]`);
      if (log.some(l => l.startsWith('warning:'))) throw new Error(`a warning; log: [${log.join(' | ')}]`);
    });
  }

  // A toc it cannot use is a warning, and the comment lists no lectures, as
  // netlify-pending-keyed.md, whose toc is not at the head.
  const tocProblems = [
    { name: 'not at the head', env: {}, api: {}, warning: /^warning: Could not read toc-file sites\/gone\/_toc\.yml at the pull request's head, so no changed lectures are listed: Not Found$/ },
    { name: 'when getContent fails', env: { TOC_FILE: DP_TOC }, api: { fail: 'getContent' },
      warning: /^warning: Could not read toc-file sites\/dp\/_toc\.yml at the pull request's head, so no changed lectures are listed: stand-in getContent failure$/ },
    { name: 'that names no page but its root', env: { TOC_FILE: DP_TOC }, api: { tocs: { [DP_TOC]: 'format: jb-book\nroot: intro\n' } },
      warning: /^warning: toc-file sites\/dp\/_toc\.yml names no page, so no changed lectures are listed$/ },
  ];
  for (const t of tocProblems) {
    await check(`preview-netlify: the placeholder, with a toc ${t.name}: warns, and posts the comment with no lectures`, async () => {
      const g = golden('netlify-pending-keyed');
      const result = await runSteps(steps, g.action, { ...g.env, ...t.env }, [], { ...g.api, ...t.api });
      const w = oneWrite(result);
      if (!result.log.some(l => t.warning.test(l))) throw new Error(`no warning matching ${t.warning}; log: [${result.log.join(' | ')}]`);
      if (w.body !== after('netlify-pending-keyed')) throw new Error(difference(after('netlify-pending-keyed'), w.body));
    });
  }

  await check("preview-netlify: the placeholder, when the toc names none of the pull request's files: lists none, with no warning", async () => {
    const g = golden('netlify-pending-keyed-toc');
    const result = await runSteps(steps, g.action, g.env, [], { ...g.api, files: [{ filename: 'README.md', status: 'modified' }] });
    const w = oneWrite(result);
    if (result.log.some(l => l.startsWith('warning:'))) throw new Error(`a warning; log: [${result.log.join(' | ')}]`);
    if (w.body !== after('netlify-pending-keyed')) throw new Error(difference(after('netlify-pending-keyed'), w.body));
  });

  // The toc reader on its own, for the forms QuantEcon/lectures' tocs do not
  // use, and a toc in lectures-dir or at the root, as other repositories keep
  // it.
  const script = require(path.join(steps['preview-netlify'].dir, '..', 'scripts', 'preview-comment.cjs'));
  const readerCases = [
    { name: 'quotes, a .md, nested sections and CRLF line ends', text: "format: jb-book\r\nroot: 'intro.md'\r\nchapters:\r\n- file: \"a.md\"\r\n  sections:\r\n  - file: sub/b\r\n- file: 'c'  # a comment\r\n",
      pages: ['a', 'sub/b', 'c'] },
    { name: 'no glob, url or title entry, nor a line commented out', text: 'root: intro\nchapters:\n- glob: extra/*\n- url: https://example.com\n  title: Example\n#- file: off\n  # - file: off2\n- file: on\n',
      pages: ['on'] },
    { name: 'not the root, even where an entry names it again', text: 'root: intro\nchapters:\n- file: intro\n- file: a\n- file: a\n', pages: ['a'] },
  ];
  for (const t of readerCases) {
    await check(`the toc reader: ${t.name}`, async () => {
      const { pages } = script.readToc(t.text);
      if (pages.join(',') !== t.pages.join(',')) throw new Error(`read [${pages.join(', ')}], not [${t.pages.join(', ')}]`);
    });
  }
  const selectCases = [
    { name: 'a toc in lectures-dir links each page without the folder', tocFile: 'lectures/_toc.yml', text: 'root: intro\nchapters:\n- file: a\n- file: sub/b\n',
      files: ['lectures/a.md', 'lectures/c.md', 'lectures/sub/b.md', 'other/a.md'], found: [['lectures/a.md', 'a'], ['lectures/sub/b.md', 'sub/b']] },
    { name: 'a toc at the root keeps lectures-dir in the page, as its site does', tocFile: '_toc.yml', text: 'root: intro\nchapters:\n- file: lectures/a\n',
      files: ['lectures/a.md', 'lectures/b.md'], found: [['lectures/a.md', 'lectures/a']] },
    { name: 'a toc at the root that names a and lectures/a gives each file its own page', tocFile: '_toc.yml', text: 'root: intro\nchapters:\n- file: a\n- file: lectures/a\n',
      files: ['a.md', 'lectures/a.md'], found: [['a.md', 'a'], ['lectures/a.md', 'lectures/a']] },
    { name: 'a toc at the root that names only a does not take lectures/a.md for it', tocFile: '_toc.yml', text: 'root: intro\nchapters:\n- file: a\n',
      files: ['lectures/a.md'], found: [] },
  ];
  for (const t of selectCases) {
    await check(`toc-file's choice: ${t.name}`, async () => {
      const { found, problem } = script.tocSelect(t.files, { lecturesDir: 'lectures', tocFile: t.tocFile, text: t.text });
      const got = (found || []).map(f => `${f.file}=${f.page}`).join(', ');
      const want = t.found.map(([f, p]) => `${f}=${p}`).join(', ');
      if (problem || got !== want) throw new Error(`chose [${got}]${problem ? ` (${problem})` : ''}, not [${want}]`);
    });
  }

  await check('a COMMENT_KEY the input check would refuse fails the step, and writes nothing', async () => {
    const g = golden('netlify-keyed-toc');
    const { writes, error } = await runSteps(steps, g.action, { ...g.env, COMMENT_KEY: 'dp -->' }, []);
    if (!error || !/COMMENT_KEY is \[dp -->\]/.test(error.message)) throw new Error(`expected an error naming COMMENT_KEY [dp -->], got [${error ? error.message : 'none'}]`);
    if (writes.length) throw new Error(`expected no write, got ${writes.length}`);
  });

  const lookup = lookupCases();
  for (const t of lookup) {
    const g = golden(t.golden);
    await check(`${g.action}: ${t.name}`, async () => {
      const result = await runGolden(g, t.comments);
      const { writes, log } = writesOf(result);
      if (t.expect === 'none') {
        if (writes.length) throw new Error(`expected no write, got [${writes.map(w => w.op + (w.id ? ` ${w.id}` : '')).join(', ')}]`);
        if (!log.some(l => /already has this commit's deployed preview/.test(l))) throw new Error(`no log line saying why; log: [${log.join(' | ')}]`);
        return;
      }
      const w = oneWrite(result);
      const got = w.op === 'create' ? 'create' : `update ${w.id}`;
      const want = t.expect === 'create' ? 'create' : `update ${t.expect.update}`;
      if (got !== want) throw new Error(`expected ${want}, got ${got}; log: [${log.join(' | ')}]`);
      if (w.body !== after(t.golden)) throw new Error(difference(after(t.golden), w.body));
    });
  }

  await check('an unknown PROVIDER fails the step, and writes nothing', async () => {
    const s = structuredClone(steps);
    s['preview-netlify'].comment.env.PROVIDER = 'netlifi';
    const { writes, error } = await runSteps(s, 'preview-netlify', golden('netlify-lectures').env, []);
    if (!error || !/PROVIDER is \[netlifi\]/.test(error.message)) throw new Error(`expected an error naming PROVIDER [netlifi], got [${error ? error.message : 'none'}]`);
    if (writes.length) throw new Error(`expected no write, got ${writes.length}`);
  });

  await check('an unknown PREVIEW_STATE fails the step, and writes nothing', async () => {
    const g = golden('netlify-pending');
    const { writes, error } = await runSteps(steps, g.action, { ...g.env, PREVIEW_STATE: 'building' }, [], g.api);
    if (!error || !/PREVIEW_STATE is \[building\]/.test(error.message)) throw new Error(`expected an error naming PREVIEW_STATE [building], got [${error ? error.message : 'none'}]`);
    if (writes.length) throw new Error(`expected no write, got ${writes.length}`);
  });

  await check('the placeholder without a site fails the step, and writes nothing', async () => {
    const g = golden('cloudflare-pending');
    const { writes, error } = await runSteps(steps, g.action, { ...g.env, PREVIEW_SITE: '' }, [], g.api);
    if (!error || !/needs PREVIEW_ALIAS and PREVIEW_SITE/.test(error.message)) throw new Error(`expected an error naming PREVIEW_SITE, got [${error ? error.message : 'none'}]`);
    if (writes.length) throw new Error(`expected no write, got ${writes.length}`);
  });

  const want = 3 + CHECKS.length + GOLDEN.length + WORKERS.length + PENDING.length + 3
    + KEYED.length + KEYED_PENDING.length + 2 + tocProblems.length + 1 + readerCases.length + selectCases.length + 1
    + lookup.length + 3;
  if (n !== want) {
    console.log(`::error::expected ${want} cases, ran ${n}`);
    process.exit(1);
  }
  if (bad) process.exit(1);
  console.log(`✅ each preview action renders its comment as before, after its marker, posts the placeholder's and hands it to the deploy's, and updates only its own comment, however many come before it (${n} cases)`);
}

// For rendering the fixtures with an older action.yml's steps.
module.exports = { GOLDEN, WORKERS, PENDING, KEYED, KEYED_PENDING, runSteps };

if (require.main === module) {
  main().catch(e => {
    console.log(`::error::${e.stack || e}`);
    process.exit(1);
  });
}
