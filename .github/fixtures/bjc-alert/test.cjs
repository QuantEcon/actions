// The bjc-alert harness job (#229, #238). It runs build-jupyter-cache's
// failure alert on its own, read from its action.yml: the github-script body
// of the create-failure-issue step against a stand-in for the GitHub API,
// called as actions/github-script calls it, and the bash step after it that
// verifies the alert. No harness job can file a real issue: that needs
// issues: write, and would open one here on every run. Its promises:
//
//   - the issue gives a command for each failed builder, and only for those,
//     that builds the given source-dir into ./_build as the action did, with
//     build-lectures' own flags and --path-output . (#229), then -n when
//     nitpick is 'true' and extra-args as build-lectures splits it (#97);
//   - each build is given the nitpick and extra-args the alert reads, and
//     their defaults are build-lectures' own, which the cases take (#97);
//   - a later failure comments on the newest open issue that carries the
//     first of issue-labels, and never on a pull request that carries it,
//     however many newer ones do: with only pull requests labelled, it files
//     a new issue (#238);
//   - the verification step passes on the URL the alert gave, and fails when
//     there is none or it is not an issue's, naming a pull request's as one
//     (#238); it reads only the URL's end, so an owner or a repository
//     named pull or issues changes nothing.
//
// Usage: node test.cjs STEPS_JSON, where STEPS_JSON holds the alert step, the
// verification step, the failure-issue-url output's value, and the flags the
// builds are given (the harness job writes it with PyYAML).
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const CONTEXT = {
  owner: 'QuantEcon',
  repo: 'lecture-harness',
  runId: 1234567890,
  eventName: 'schedule',
  sha: '0123456789abcdef0123456789abcdef01234567',
};
const SERVER = 'https://github.com';
const SOURCE_DIR = 'harness/lectures';
const LABELS = 'build-failure,automated';
const issueUrl = n => `${SERVER}/${CONTEXT.owner}/${CONTEXT.repo}/issues/${n}`;
const pullUrl = n => `${SERVER}/${CONTEXT.owner}/${CONTEXT.repo}/pull/${n}`;

// What build-lectures runs for each builder with build-jupyter-cache's
// inputs: output-dir '.', its default, and nitpick 'true' and extra-args
// '-W --keep-going', their defaults (build-lectures/action.yml, the "Build
// Command" it prints). Written out, not read from the script, since they are
// what a maintainer is told to run.
const REPRO = {
  jupyter: `jb build ${SOURCE_DIR} --path-output . --builder=custom --custom-builder=jupyter -n -W --keep-going`,
  pdflatex: `jb build ${SOURCE_DIR} --path-output . --builder pdflatex -n -W --keep-going`,
  html: `jb build ${SOURCE_DIR} --path-output . -n -W --keep-going`,
};

// The alert step's env for a run whose html build failed, as the steps
// before it would set it.
const FAILED = {
  SOURCE_DIR, ISSUE_LABELS: LABELS, ISSUE_ASSIGNEES: '',
  JUPYTER_STATUS: 'skipped', PDFLATEX_STATUS: 'skipped', HTML_STATUS: 'failure',
  FAILURE_PHASE: 'build', ARTIFACT_UPLOADED: 'true', UPLOAD_FAILURE_REPORTS: 'true',
  NITPICK: 'true', EXTRA_ARGS: '-W --keep-going',
};

// Each case sets the three builders' statuses, and names the builders whose
// commands the issue must give, in the order it gives them. A case that sets
// the flags gives those commands too, written out as above.
const EVERY_BUILD_FAILED = { JUPYTER_STATUS: 'failure', PDFLATEX_STATUS: 'failure', HTML_STATUS: 'failure' };
const REPRO_CASES = [
  { name: 'every builder failed: a command for each',
    status: { JUPYTER_STATUS: 'failure', PDFLATEX_STATUS: 'failure', HTML_STATUS: 'failure' }, want: ['jupyter', 'pdflatex', 'html'] },
  { name: 'html failed, jupyter passed and pdflatex was not asked for: its command alone',
    status: { JUPYTER_STATUS: 'success', PDFLATEX_STATUS: 'skipped', HTML_STATUS: 'failure' }, want: ['html'] },
  { name: 'pdflatex failed and html passed: its command alone',
    status: { JUPYTER_STATUS: 'skipped', PDFLATEX_STATUS: 'failure', HTML_STATUS: 'success' }, want: ['pdflatex'] },
  { name: "nitpick 'false': no -n for any builder",
    status: { ...EVERY_BUILD_FAILED, NITPICK: 'false' }, want: ['jupyter', 'pdflatex', 'html'],
    repro: {
      jupyter: `jb build ${SOURCE_DIR} --path-output . --builder=custom --custom-builder=jupyter -W --keep-going`,
      pdflatex: `jb build ${SOURCE_DIR} --path-output . --builder pdflatex -W --keep-going`,
      html: `jb build ${SOURCE_DIR} --path-output . -W --keep-going`,
    } },
  { name: 'extra-args over two lines, with runs of spaces: one argument after another, as build-lectures splits them',
    status: { ...EVERY_BUILD_FAILED, PDFLATEX_STATUS: 'skipped', EXTRA_ARGS: '  -W   --keep-going\n--all ' }, want: ['jupyter', 'html'],
    repro: {
      jupyter: `jb build ${SOURCE_DIR} --path-output . --builder=custom --custom-builder=jupyter -n -W --keep-going --all`,
      html: `jb build ${SOURCE_DIR} --path-output . -n -W --keep-going --all`,
    } },
  { name: "extra-args '' and nitpick 'false': the builder's own flags alone",
    status: { ...EVERY_BUILD_FAILED, NITPICK: 'false', EXTRA_ARGS: '' }, want: ['jupyter', 'pdflatex', 'html'],
    repro: {
      jupyter: `jb build ${SOURCE_DIR} --path-output . --builder=custom --custom-builder=jupyter`,
      pdflatex: `jb build ${SOURCE_DIR} --path-output . --builder pdflatex`,
      html: `jb build ${SOURCE_DIR} --path-output .`,
    } },
];

// The repository's issues and pull requests, in the Issues API's shape, which
// gives a pull request a pull_request key and a /pull/ URL. Newest first, as
// listForRepo lists them unless asked otherwise.
const issue = (number, labels, state = 'open') =>
  ({ number, state, labels: labels.map(name => ({ name })), html_url: issueUrl(number) });
const pull = (number, labels, state = 'open') =>
  ({ ...issue(number, labels, state), html_url: pullUrl(number), pull_request: { html_url: pullUrl(number) } });

// Each case runs the alert with `items` in the repository, and expects one
// write: a comment on the item numbered `comment`, or a new issue numbered
// `create`, one more than the highest number there.
const LOOKUP = [
  { name: 'nothing open carries the first label: files a new issue, with the labels and assignees',
    env: { ISSUE_ASSIGNEES: 'maintainer-a, maintainer-b' },
    items: [pull(9, ['automated']), issue(8, ['automated']), issue(7, ['build-failure', 'automated'], 'closed')],
    want: { create: 10 } },
  { name: 'an open issue carries it: comments there',
    items: [issue(4, ['build-failure', 'automated'])], want: { comment: 4 } },
  { name: 'two open issues carry it: comments on the newer',
    items: [issue(5, ['build-failure']), issue(2, ['build-failure'])], want: { comment: 5 } },
  { name: 'only a pull request carries it: files a new issue, and leaves the pull request alone',
    items: [pull(6, ['build-failure'])], want: { create: 7 } },
  { name: 'a newer pull request and an older issue carry it: comments on the issue',
    items: [pull(12, ['build-failure', 'automated']), issue(11, ['build-failure', 'automated'])], want: { comment: 11 } },
  { name: 'an issue after 40 newer pull requests that carry it, past the first 30: comments on the issue',
    items: [...Array.from({ length: 40 }, (_, i) => pull(100 - i, ['build-failure'])), issue(3, ['build-failure'])],
    want: { comment: 3 } },
  { name: 'issue-labels empty: files a new issue, without looking',
    env: { ISSUE_LABELS: '' }, items: [issue(4, ['build-failure'])], want: { create: 5 }, looks: 0 },
];

// The verification step's cases: its env, the exit status wanted, and a
// pattern its output must match.
const VERIFY = [
  { name: "an issue's URL: passes",
    env: { ALERT_OUTCOME: 'success', ISSUE_URL: issueUrl(10), FAILURE_PHASE: 'build' }, rc: 0,
    out: /^✅ failure issue filed: https:\/\/github\.com\/QuantEcon\/lecture-harness\/issues\/10$/m },
  { name: "an issue's URL in a repository named pull, of an owner named pull: passes",
    env: { ALERT_OUTCOME: 'success', ISSUE_URL: `${SERVER}/pull/pull/issues/10`, FAILURE_PHASE: 'build' }, rc: 0,
    out: /^✅ failure issue filed: https:\/\/github\.com\/pull\/pull\/issues\/10$/m },
  { name: "a pull request's URL: fails",
    env: { ALERT_OUTCOME: 'success', ISSUE_URL: pullUrl(5), FAILURE_PHASE: 'build' }, rc: 1,
    out: /^::error::[^\n]*a pull request, not an issue: https:\/\/github\.com\/QuantEcon\/lecture-harness\/pull\/5\. /m },
  { name: "a pull request's URL in a repository named issues: fails",
    env: { ALERT_OUTCOME: 'success', ISSUE_URL: `${SERVER}/QuantEcon/issues/pull/5`, FAILURE_PHASE: 'build' }, rc: 1,
    out: /^::error::[^\n]*a pull request, not an issue: https:\/\/github\.com\/QuantEcon\/issues\/pull\/5\. /m },
  { name: "a URL that is neither an issue's nor a pull request's: fails",
    env: { ALERT_OUTCOME: 'success', ISSUE_URL: `${SERVER}/QuantEcon/lecture-harness/discussions/5`, FAILURE_PHASE: 'build' }, rc: 1,
    out: /^::error::[^\n]*the alert step's URL is not an issue's: https:\/\/github\.com\/QuantEcon\/lecture-harness\/discussions\/5\.$/m },
  { name: 'no URL: fails',
    env: { ALERT_OUTCOME: 'success', ISSUE_URL: '', FAILURE_PHASE: 'build' }, rc: 1,
    out: /^::error::create-issue-on-failure is enabled but no failure issue was filed \(alert step outcome=\[success\], issue url=\[\]/m },
  { name: 'the alert step failed: fails',
    env: { ALERT_OUTCOME: 'failure', ISSUE_URL: '', FAILURE_PHASE: 'setup' }, rc: 1,
    out: /^::error::create-issue-on-failure is enabled but no failure issue was filed \(alert step outcome=\[failure\]/m },
];

// What the action's steps must say, where the cases above take a value for
// granted: the expressions behind each env value the cases fill in, the
// output the caller reads, and the condition both steps run under.
const ALERTED = "always() && steps.status.outputs.all-passed != 'true' && inputs.create-issue-on-failure == 'true'";
const WIRING = {
  output: '${{ steps.create-failure-issue.outputs.issue-url }}',
  alert: {
    SOURCE_DIR: '${{ inputs.source-dir }}',
    ISSUE_LABELS: '${{ inputs.issue-labels }}',
    ISSUE_ASSIGNEES: '${{ inputs.issue-assignees }}',
    JUPYTER_STATUS: '${{ steps.verify-builds.outputs.jupyter-status }}',
    PDFLATEX_STATUS: '${{ steps.verify-builds.outputs.pdflatex-status }}',
    HTML_STATUS: '${{ steps.verify-builds.outputs.html-status }}',
    FAILURE_PHASE: '${{ steps.status.outputs.phase }}',
    ARTIFACT_UPLOADED: "${{ steps.upload-artifact.outputs.artifact-id != '' }}",
    UPLOAD_FAILURE_REPORTS: '${{ inputs.upload-failure-reports }}',
    NITPICK: '${{ inputs.nitpick }}',
    EXTRA_ARGS: '${{ inputs.extra-args }}',
  },
  verify: {
    ALERT_OUTCOME: '${{ steps.create-failure-issue.outcome }}',
    ISSUE_URL: '${{ steps.create-failure-issue.outputs.issue-url }}',
    FAILURE_PHASE: '${{ steps.status.outputs.phase }}',
  },
};

// What each build-lectures step must be given, which the alert's commands
// take for granted (#97).
const BUILD_FLAGS = { nitpick: '${{ inputs.nitpick }}', 'extra-args': '${{ inputs.extra-args }}' };

// A stand-in for the Octokit client actions/github-script passes as `github`.
// listForRepo filters by state and labels and serves one page, 30 items
// unless per_page says otherwise (at most 100), as the REST API does.
// createComment takes any number in the repository, a pull request's too, as
// the API does. `fail` makes the named call fail with that status.
function stubGitHub(items, fail = {}) {
  const writes = [];
  const looks = [];
  const checkTarget = (op, p) => {
    if (p.owner !== CONTEXT.owner || p.repo !== CONTEXT.repo) {
      throw new Error(`${op} called for ${p.owner}/${p.repo}, not ${CONTEXT.owner}/${CONTEXT.repo}`);
    }
    if (fail.op === op) throw Object.assign(new Error(`stand-in ${op} failure`), { status: fail.status });
  };
  const issues = {
    listForRepo: async p => {
      checkTarget('listForRepo', p);
      looks.push(p);
      // The cases list the items newest first.
      if ((p.sort && p.sort !== 'created') || (p.direction && p.direction !== 'desc')) {
        throw new Error(`listForRepo asked for sort [${p.sort}] and direction [${p.direction}], which the stand-in does not serve`);
      }
      const state = p.state || 'open';
      const wanted = (p.labels || '').split(',').filter(Boolean);
      const found = items.filter(i => (state === 'all' || i.state === state)
        && wanted.every(l => i.labels.some(x => x.name === l)));
      const size = Math.min(p.per_page || 30, 100);
      const n = p.page || 1;
      return { data: structuredClone(found.slice((n - 1) * size, n * size)) };
    },
    createComment: async p => {
      checkTarget('createComment', p);
      const target = items.find(i => i.number === p.issue_number);
      if (!target) throw Object.assign(new Error('Not Found'), { status: 404 });
      writes.push({ op: 'comment', number: p.issue_number, body: p.body });
      return { data: { id: 1, html_url: `${target.html_url}#issuecomment-1` } };
    },
    create: async p => {
      checkTarget('create', p);
      const number = Math.max(0, ...items.map(i => i.number)) + 1;
      writes.push({ op: 'create', number, title: p.title, body: p.body, labels: p.labels, assignees: p.assignees });
      return { data: issue(number, p.labels || []) };
    },
  };
  return { github: { rest: { issues } }, writes, looks };
}

const stubCore = () => {
  const log = [];
  const outputs = {};
  const say = level => msg => log.push(`${level}: ${msg}`);
  return {
    log, outputs,
    core: {
      info: say('info'), notice: say('notice'), warning: say('warning'), error: say('error'), debug: () => {},
      setFailed: say('failed'), setOutput: (key, value) => { outputs[key] = String(value); },
    },
  };
};

const EXPRESSION = /\$\{\{/;
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

// Run the alert step as actions/github-script would, with `values` for its
// env's expressions, in a repository that holds `items`.
async function runAlert(steps, values, items, fail = {}) {
  const a = steps.alert;
  if (!/^actions\/github-script@/.test(a.uses)) throw new Error(`the alert step uses [${a.uses}]`);
  if (a.with['github-token'] !== '${{ github.token }}') throw new Error(`the alert step's github-token is [${a.with['github-token']}]`);
  for (const key of Object.keys(values)) {
    if (!(key in a.env)) throw new Error(`the alert step does not pass ${key}`);
  }
  const env = { GITHUB_SERVER_URL: SERVER, GITHUB_REF_NAME: 'main' };
  for (const [key, value] of Object.entries(a.env)) {
    env[key] = EXPRESSION.test(String(value)) ? values[key] ?? '' : String(value);
  }

  const { github, writes, looks } = stubGitHub(items, fail);
  const { core, log, outputs } = stubCore();
  const context = {
    repo: { owner: CONTEXT.owner, repo: CONTEXT.repo },
    runId: CONTEXT.runId,
    eventName: CONTEXT.eventName,
    sha: CONTEXT.sha,
    payload: {},
  };
  const saved = { ...process.env };
  Object.assign(process.env, env);
  let error;
  try {
    await new AsyncFunction('require', 'github', 'context', 'core', a.with.script)(require, github, context, core);
  } catch (e) {
    // actions/github-script fails the step on this.
    error = e;
  } finally {
    for (const key of Object.keys(env)) {
      if (key in saved) process.env[key] = saved[key]; else delete process.env[key];
    }
  }
  return { writes, looks, log, outputs, error };
}

// Run the verification step as `shell: bash` runs it, with `env` added;
// return its status and output.
function runVerify(steps, env) {
  const v = steps.verify;
  if (v.shell !== 'bash') throw new Error(`the verification step's shell is [${v.shell}], not bash`);
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'bjc-alert-'));
  try {
    const script = path.join(tmp, 'step.sh');
    const summary = path.join(tmp, 'summary');
    fs.writeFileSync(script, v.run);
    fs.writeFileSync(summary, '');
    const r = spawnSync('bash', ['--noprofile', '--norc', '-eo', 'pipefail', script], {
      env: { ...process.env, ...env, GITHUB_ACTION_PATH: steps.dir, GITHUB_STEP_SUMMARY: summary },
      encoding: 'utf8',
    });
    return { status: r.status, out: r.stdout + r.stderr };
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

const describe = writes => `[${writes.map(w => `${w.op} ${w.number}`).join(', ')}]`;

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
    if (error) throw new Error(`the step failed: ${error.message}; log: [${log.join(' | ')}]`);
    if (writes.length !== 1) throw new Error(`expected one write, got ${describe(writes)}; log: [${log.join(' | ')}]`);
    return writes[0];
  };

  await check("the alert's steps and output are wired as the cases assume", async () => {
    const problems = [];
    if (steps.output !== WIRING.output) problems.push(`failure-issue-url is [${steps.output}], not [${WIRING.output}]`);
    for (const [step, want] of [['alert', WIRING.alert], ['verify', WIRING.verify]]) {
      const env = steps[step].env;
      for (const key of new Set([...Object.keys(want), ...Object.keys(env)])) {
        if (env[key] !== want[key]) problems.push(`${step} env ${key} is [${env[key]}], not [${want[key]}]`);
      }
      if (steps[step].if !== ALERTED) problems.push(`${step}'s if is [${steps[step].if}], not [${ALERTED}]`);
    }
    if (problems.length) throw new Error(problems.join('; '));
  });

  await check("each build is given the nitpick and extra-args the alert reads, with build-lectures' defaults, which the cases take", async () => {
    const problems = [];
    const { builds, defaults } = steps.flags;
    const names = Object.keys(builds).sort().join(',');
    if (names !== 'html,jupyter,pdflatex') problems.push(`the steps that run build-lectures build [${names}], not [html,jupyter,pdflatex]`);
    for (const [builder, given] of Object.entries(builds)) {
      for (const [key, want] of Object.entries(BUILD_FLAGS)) {
        if (given[key] !== want) problems.push(`the ${builder} build's ${key} is [${given[key]}], not [${want}]`);
      }
    }
    for (const [key, env] of [['nitpick', 'NITPICK'], ['extra-args', 'EXTRA_ARGS']]) {
      const theirs = steps.flags['build-lectures'][key];
      if (defaults[key] !== theirs) problems.push(`${key} defaults to [${defaults[key]}], not to build-lectures' [${theirs}]`);
      if (defaults[key] !== FAILED[env]) problems.push(`${key} defaults to [${defaults[key]}], not to the [${FAILED[env]}] the cases take`);
    }
    if (problems.length) throw new Error(problems.join('; '));
  });

  for (const t of REPRO_CASES) {
    await check(`the issue's commands to reproduce, ${t.name}`, async () => {
      const w = oneWrite(await runAlert(steps, { ...FAILED, ...t.status }, []));
      const block = w.body.match(/^3\. Reproduce locally:\n\n {3}```bash\n([\s\S]*?)\n {3}```$/m);
      if (!block) throw new Error(`the issue has no "Reproduce locally" block; body: [${w.body}]`);
      const got = block[1].split('\n').map(l => l.replace(/^ {3}/, ''));
      const want = t.want.map(b => (t.repro || REPRO)[b]);
      if (got.join('\n') !== want.join('\n')) {
        throw new Error(`expected [${want.join(' | ')}], got [${got.join(' | ')}]`);
      }
    });
  }

  for (const t of LOOKUP) {
    await check(`the alert, ${t.name}, and the verification step passes on its URL`, async () => {
      const result = await runAlert(steps, { ...FAILED, ...t.env }, t.items);
      const w = oneWrite(result);
      const got = `${w.op} ${w.number}`;
      const want = 'create' in t.want ? `create ${t.want.create}` : `comment ${t.want.comment}`;
      if (got !== want) throw new Error(`expected ${want}, got ${got}; log: [${result.log.join(' | ')}]`);
      if (!w.body.startsWith('## 🔴 Jupyter Cache Build Failed\n')) throw new Error(`the report does not start with its heading: [${w.body.slice(0, 80)}]`);

      const looks = t.looks ?? 1;
      if (result.looks.length !== looks) throw new Error(`expected ${looks} lookup, got ${result.looks.length}`);
      const first = (t.env?.ISSUE_LABELS ?? LABELS).split(',')[0];
      for (const p of result.looks) {
        if (p.state !== 'open' || p.labels !== first) throw new Error(`looked up state [${p.state}] and labels [${p.labels}], not [open] and [${first}]`);
      }

      if (w.op === 'create') {
        const labels = (t.env?.ISSUE_LABELS ?? LABELS).split(',').map(s => s.trim()).filter(Boolean);
        if (JSON.stringify(w.labels) !== JSON.stringify(labels)) throw new Error(`the new issue's labels are ${JSON.stringify(w.labels)}, not ${JSON.stringify(labels)}`);
        const assignees = (t.env?.ISSUE_ASSIGNEES ?? '').split(',').map(s => s.trim()).filter(Boolean);
        if (JSON.stringify(w.assignees ?? []) !== JSON.stringify(assignees)) throw new Error(`the new issue's assignees are ${JSON.stringify(w.assignees)}, not ${JSON.stringify(assignees)}`);
        if (!/^🔴 Cache Build Failed - \d{4}-\d{2}-\d{2}$/.test(w.title)) throw new Error(`the new issue's title is [${w.title}]`);
      }

      const url = issueUrl('create' in t.want ? t.want.create : t.want.comment);
      if (result.outputs['issue-url'] !== url) throw new Error(`issue-url is [${result.outputs['issue-url']}], not [${url}]`);
      const r = runVerify(steps, { ALERT_OUTCOME: 'success', ISSUE_URL: result.outputs['issue-url'], FAILURE_PHASE: 'build' });
      if (r.status !== 0) throw new Error(`the verification step exited ${r.status} on [${result.outputs['issue-url']}]: [${r.out}]`);
    });
  }

  await check('the alert, without issues: write: names the permission, fails the step, and writes nothing', async () => {
    const { writes, log, error, outputs } = await runAlert(steps, FAILED, [], { op: 'create', status: 403 });
    if (!error) throw new Error('the step did not fail');
    if (!log.some(l => /^error: Could not file the failure issue: the token lacks issue permissions\. Add `issues: write`/.test(l))) {
      throw new Error(`no error naming the permission; log: [${log.join(' | ')}]`);
    }
    if (writes.length) throw new Error(`expected no write, got ${describe(writes)}`);
    if ('issue-url' in outputs) throw new Error(`issue-url is set, to [${outputs['issue-url']}]`);
  });

  for (const t of VERIFY) {
    await check(`the verification step, ${t.name}`, async () => {
      const r = runVerify(steps, t.env);
      if (r.status !== t.rc) throw new Error(`exited ${r.status}, not ${t.rc}; output: [${r.out}]`);
      if (!t.out.test(r.out)) throw new Error(`output [${r.out}] does not match ${t.out}`);
    });
  }

  const want = 2 + REPRO_CASES.length + LOOKUP.length + 1 + VERIFY.length;
  if (n !== want) {
    console.log(`::error::expected ${want} cases, ran ${n}`);
    process.exit(1);
  }
  if (bad) process.exit(1);
  console.log(`✅ build-jupyter-cache's failure alert gives a command for each failed build that builds where the action does, comments on an open issue and never on a pull request, and its verification step refuses a pull request's URL (${n} cases)`);
}

main().catch(e => {
  console.log(`::error::${e.stack || e}`);
  process.exit(1);
});
