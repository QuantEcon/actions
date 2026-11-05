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
//     then exactly that;
//   - the action updates its own comment however many come before it, and
//     never anyone else's (finding M2 of the 2026-10-06 review);
//   - with placeholder: 'true', it posts the PENDING comment, *-pending*.md,
//     with the lectures the pull request changed by the rules of
//     scripts/detect-changed-lectures.sh, and the deploy's comment then
//     replaces that one in place, while the placeholder never replaces the
//     deploy's comment for its own commit;
//   - the input check refuses a deploy without its secrets or build-dir, and
//     a placeholder without a valid site name, and never sees a secret.
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
const TWO_LECTURES = 'lectures/aiyagari.md\nlectures/mccall_model.md';

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
];

const golden = name => GOLDEN.find(g => g.name === name) || PENDING.find(g => g.name === name);
const fixture = name => fs.readFileSync(path.join(__dirname, `${name}.md`), 'utf8');

// Comments, in the API's shape. Ids are positions, from 1.
const person = body => ({ user: { login: 'a-reviewer', type: 'User' }, body });
const bot = body => ({ user: { login: BOT, type: 'Bot' }, body });
const people = n => Array.from({ length: n }, (_, i) => person(`Review comment ${i + 1}`));
// A comment as v0.14.0 posted it, with no marker, and as the script posts it.
const before = name => fixture(name);
const after = name => `${MARKER[golden(name).action]}\n${fixture(name)}`;
// The same, for an earlier push.
const earlier = body => body.split(SHA).join(OLD_SHA).split(SHA.substring(0, 7)).join(OLD_SHA.substring(0, 7));

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
];

// The input check's cases, one action each: `env` is the step's env, `rc` the
// exit status wanted, and `out` a pattern its output must match (or `quiet`,
// no output at all).
const NETLIFY_SET = { HAVE_TOKEN: 'true', HAVE_SITE_ID: 'true', HAVE_BUILD_DIR: 'true' };
const NETLIFY_NONE = { HAVE_TOKEN: 'false', HAVE_SITE_ID: 'false', HAVE_BUILD_DIR: 'false' };
const CLOUDFLARE_SET = { HAVE_TOKEN: 'true', HAVE_ACCOUNT_ID: 'true', HAVE_BUILD_DIR: 'true' };
const CLOUDFLARE_NONE = { HAVE_TOKEN: 'false', HAVE_ACCOUNT_ID: 'false', HAVE_BUILD_DIR: 'false' };
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
];

// What each action's steps must say, where the cases above take a value for
// granted: the expressions behind the env that test cases fill in, and the
// conditions that keep the placeholder from installing or deploying.
const WIRING = {
  common: {
    comment: {
      PREVIEW_COMMENT_SCRIPT: '${{ steps.comment-script.outputs.path }}',
      PREVIEW_STATE: "${{ inputs.placeholder == 'true' && 'pending' || 'ready' }}",
      PREVIEW_ALIAS: '${{ steps.decide.outputs.alias }}',
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
    },
  },
  'preview-cloudflare': {
    comment: { PREVIEW_SITE: '${{ inputs.project-name }}' },
    check: {
      PLACEHOLDER: '${{ inputs.placeholder }}', DEPLOY: '${{ steps.decide.outputs.deploy }}',
      HAVE_TOKEN: "${{ inputs.cloudflare-api-token != '' }}", HAVE_ACCOUNT_ID: "${{ inputs.cloudflare-account-id != '' }}", HAVE_BUILD_DIR: "${{ inputs.build-dir != '' }}",
    },
  },
};

// A stand-in for the Octokit client actions/github-script passes as `github`.
// listComments and listFiles serve one page, 30 items unless per_page says
// otherwise (at most 100), as the REST API does; paginate fetches every page.
// getContent finds only the paths in `api.contents`, and answers 404 for
// any other, as the API does; `api.fail` makes the named call fail.
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

  for (const action of ['preview-netlify', 'preview-cloudflare']) {
    await check(`${action}: its steps' conditions and env are wired as the cases assume`, async () => {
      const s = steps[action];
      const problems = [];
      for (const [key, want] of Object.entries({ ...WIRING.common.comment, ...WIRING[action].comment })) {
        if (s.comment.env[key] !== want) problems.push(`comment env ${key} is [${s.comment.env[key]}], not [${want}]`);
      }
      for (const [id, want] of Object.entries(WIRING.common.if)) {
        if (s.if[id] !== want) problems.push(`step ${id}'s if is [${s.if[id]}], not [${want}]`);
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
    });
  }

  for (const g of GOLDEN) {
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

  const want = 2 + CHECKS.length + GOLDEN.length + PENDING.length + 3 + lookup.length + 3;
  if (n !== want) {
    console.log(`::error::expected ${want} cases, ran ${n}`);
    process.exit(1);
  }
  if (bad) process.exit(1);
  console.log(`✅ each preview action renders its comment as before, after its marker, posts the placeholder's and hands it to the deploy's, and updates only its own comment, however many come before it (${n} cases)`);
}

// For rendering the fixtures with an older action.yml's steps.
module.exports = { GOLDEN, PENDING, runSteps };

if (require.main === module) {
  main().catch(e => {
    console.log(`::error::${e.stack || e}`);
    process.exit(1);
  });
}
