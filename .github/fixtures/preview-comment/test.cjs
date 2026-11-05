// The preview-comment harness job (#153). It runs each preview action's own
// comment steps, read from its action.yml, against a stand-in for the GitHub
// API: the bash step that finds scripts/preview-comment.cjs, then the
// github-script body, called as actions/github-script calls it. Two promises:
//
//   - each action's comment renders exactly as it did before the script was
//     shared: the *.md files here are the bodies that the two inline scripts
//     of v0.14.0 rendered for the GOLDEN inputs below, run through runSteps,
//     and the shared script must render the hidden marker line and then
//     exactly that;
//   - the action updates its own comment however many come before it, and
//     never anyone else's (finding M2 of the 2026-10-06 review).
//
// Usage: node test.cjs STEPS_JSON, where STEPS_JSON maps each action's
// directory to its `comment-script` and `comment` steps (the harness job
// writes it with PyYAML).
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

const golden = name => GOLDEN.find(g => g.name === name);
const fixture = name => fs.readFileSync(path.join(__dirname, `${name}.md`), 'utf8');

// Comments, in the API's shape. Ids are positions, from 1.
const person = body => ({ user: { login: 'a-reviewer', type: 'User' }, body });
const bot = body => ({ user: { login: BOT, type: 'Bot' }, body });
const people = n => Array.from({ length: n }, (_, i) => person(`Review comment ${i + 1}`));
// A comment as v0.14.0 posted it, with no marker, and as the script posts it.
const before = name => fixture(name);
const after = name => `${MARKER[golden(name).action]}\n${fixture(name)}`;

// Each case runs one action with one golden's env on a pull request that
// already has `comments`, and expects one write: a new comment (`create`) or
// an update of the comment at position `update`. A function, because the
// comments are built from the fixtures.
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
];

// A stand-in for the Octokit client actions/github-script passes as `github`.
// listComments serves one page, 30 comments unless per_page says otherwise
// (at most 100), as the REST API does; paginate fetches every page.
function stubGitHub(comments) {
  const stored = comments.map((c, i) => ({ id: i + 1, ...c }));
  const writes = [];
  const checkTarget = (op, p) => {
    if (p.owner !== CONTEXT.owner || p.repo !== CONTEXT.repo) {
      throw new Error(`${op} called for ${p.owner}/${p.repo}, not ${CONTEXT.owner}/${CONTEXT.repo}`);
    }
  };
  const checkIssue = (op, p) => {
    checkTarget(op, p);
    if (p.issue_number !== CONTEXT.number) throw new Error(`${op} called for issue ${p.issue_number}, not ${CONTEXT.number}`);
  };
  const issues = {
    listComments: async p => {
      checkIssue('listComments', p);
      const size = Math.min(p.per_page || 30, 100);
      const page = p.page || 1;
      return { data: structuredClone(stored.slice((page - 1) * size, page * size)) };
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
  const paginate = async (method, params) => {
    const size = Math.min(params.per_page || 30, 100);
    const all = [];
    for (let page = 1; ; page++) {
      const { data } = await method({ ...params, page });
      all.push(...data);
      if (data.length < size) return all;
    }
  };
  return { github: { rest: { issues }, paginate }, writes };
}

const stubCore = () => {
  const log = [];
  const say = level => msg => log.push(`${level}: ${msg}`);
  return { log, core: { info: say('info'), notice: say('notice'), warning: say('warning'), error: say('error'), debug: () => {}, setFailed: say('failed') } };
};

const EXPRESSION = /\$\{\{/;
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

// Run an action's two comment steps as the runner would on a pull request,
// with `values` for the step env's expressions.
async function runSteps(steps, action, values, comments) {
  const s = steps[action];
  if (!s) throw new Error(`no steps read for ${action}`);

  // The bash step, as `shell: bash` runs it, in the action's directory.
  if (s.resolve.shell !== 'bash') throw new Error(`${action}: the comment-script step's shell is [${s.resolve.shell}], not bash`);
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'preview-comment-'));
  let found;
  try {
    const script = path.join(tmp, 'step.sh');
    const output = path.join(tmp, 'output');
    fs.writeFileSync(script, s.resolve.run);
    fs.writeFileSync(output, '');
    const r = spawnSync('bash', ['--noprofile', '--norc', '-eo', 'pipefail', script], {
      env: { ...process.env, GITHUB_ACTION_PATH: s.dir, GITHUB_OUTPUT: output },
      encoding: 'utf8',
    });
    if (r.status !== 0) throw new Error(`${action}: the comment-script step exited ${r.status}: ${r.stdout}${r.stderr}`);
    found = fs.readFileSync(output, 'utf8').match(/^path=(.*)$/m);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
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
    else if (EXPRESSION.test(String(value))) env[key] = values[key] ?? '';
    else env[key] = String(value);
  }

  const { github, writes } = stubGitHub(comments);
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
  return { writes, log, error };
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
  const oneWrite = ({ writes, log, error }) => {
    if (error) throw new Error(`the step failed: ${error.message}`);
    if (writes.length !== 1) throw new Error(`expected one write, got ${writes.length}: [${writes.map(w => w.op + (w.id ? ` ${w.id}` : '')).join(', ')}]; log: [${log.join(' | ')}]`);
    return writes[0];
  };

  for (const g of GOLDEN) {
    await check(`${g.action}: renders ${g.name}.md, after the marker`, async () => {
      const w = oneWrite(await runSteps(steps, g.action, g.env, []));
      if (w.op !== 'create') throw new Error(`expected a new comment, got ${w.op} ${w.id}`);
      const want = after(g.name);
      if (w.body !== want) throw new Error(difference(want, w.body));
    });
  }

  const lookup = lookupCases();
  for (const t of lookup) {
    const g = golden(t.golden);
    await check(`${g.action}: ${t.name}`, async () => {
      const result = await runSteps(steps, g.action, g.env, t.comments);
      const w = oneWrite(result);
      const got = w.op === 'create' ? 'create' : `update ${w.id}`;
      const want = t.expect === 'create' ? 'create' : `update ${t.expect.update}`;
      if (got !== want) throw new Error(`expected ${want}, got ${got}; log: [${result.log.join(' | ')}]`);
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

  const want = GOLDEN.length + lookup.length + 1;
  if (n !== want) {
    console.log(`::error::expected ${want} cases, ran ${n}`);
    process.exit(1);
  }
  if (bad) process.exit(1);
  console.log(`✅ each preview action renders its comment as before, after its marker, and updates only its own comment, however many come before it (${n} cases)`);
}

// For rendering the fixtures with an older action.yml's steps.
module.exports = { GOLDEN, runSteps };

if (require.main === module) {
  main().catch(e => {
    console.log(`::error::${e.stack || e}`);
    process.exit(1);
  });
}
