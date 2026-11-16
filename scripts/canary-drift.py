#!/usr/bin/env python3
"""Compare the canary's workflows with templates/ at v0 (#310).

canary-watch.yml's drift job runs it. Each workflow that
.github/canary-drift.yml lists is read from the canary's default branch, and
the template of the same name from templates/ at the commit v0 points to,
and the two are compared as YAML: comments and key order are not compared,
but the order of the steps, or other list items, that both have is. A
difference the declarations do not list is drift. So is a listed one that
no longer differs, since it would hide a later change there, and a listed
value that the canary no longer holds. And every quantecon/actions action
the canary runs must run at @v0, declared or not.

  scripts/canary-drift.py [--compare-versions] [--canary-ref REF]
  scripts/canary-drift.py --self-test

It prints one markdown list item per workflow, a ✅ or a 🔴, then one that
names the commit v0 was read at, and exits 1 if any is red. A bad
declarations file or argument exits 2. The commit is kept out of the red
lines, which the watcher's report hashes, so a red that persists across a v0
move is not reported again.

A path joins keys with dots, and names an item of a list of mappings, a
step or a cron, by its `name`, or its `id`, or its `uses`, or else its
index, in brackets: `jobs.build.steps[Restore execution cache].with.save-cache`.
A declared path covers itself and everything under it, except an `if`,
`continue-on-error` or `permissions` key below it, which a declaration
covers only by naming it or by giving a value that holds it: a declared
step that is switched off or allowed to fail, or a declared job given more
permissions, is still drift. A declared value, a mapping or list included,
must equal what the canary holds at its path.

The version after the `@` of an action outside quantecon/actions is not
compared unless --compare-versions is given: the canary's Dependabot moves
those pins, and the templates' move only with a release.

Environment:
  GH_TOKEN        any token: both repositories are public
  CANARY_REPO     the canary, as owner/name
  TEMPLATES_REPO  the repository whose templates/ it follows, as owner/name
"""
import json
import os
import re
import subprocess
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
DECLARATIONS = os.path.join(HERE, '..', '.github', 'canary-drift.yml')
DECLARATIONS_NAME = '.github/canary-drift.yml'
WATCH_WORKFLOW = os.path.join(HERE, '..', '.github', 'workflows', 'canary-watch.yml')
REPO_RE = re.compile(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+')
FILE_RE = re.compile(r'[A-Za-z0-9_.-]+\.ya?ml')
OURS_RE = re.compile(r'quantecon/actions(/|@|$)', re.I)
SCHEDULE_RE = re.compile(r"github\.event\.schedule\s*(==|!=)\s*'([^']*)'")
GUARDED = ('if', 'continue-on-error', 'permissions')
MISSING = object()
SHOWN = 60     # the most characters of a value a finding shows
LISTED = 8     # the most problems a finding lists


def annotate(level, message):
    """One workflow command, with its data escaped as the runner reads it."""
    data = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print(f'::{level}::{data}', file=sys.stderr)


class Refused(Exception):
    """A bad declarations file or argument: exit 2."""


class Unread(Exception):
    """A file or ref that could not be read."""


def disp(text):
    """Text for a finding: one line, with no backtick to end its code span.
    A step's name could otherwise put a line of its own in the log, which
    the runner would read as a workflow command."""
    return ''.join(ch if ch.isprintable() else f'\\u{ord(ch):04x}' for ch in str(text).replace('`', "'"))


def code(path):
    return f'`{disp(path)}`'


def show(value):
    if value is MISSING:
        return 'absent'
    text = json.dumps(value, ensure_ascii=False, default=str)
    if len(text) > SHOWN:
        text = text[:SHOWN] + '…'
    return f'`{disp(text)}`'


def same(a, b):
    """Equal, and of the same types: YAML's `true` is not its `1`."""
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return type(a) is type(b) and a == b


def norm_uses(value, compare_versions):
    """An action's `uses`, without its version unless it is ours."""
    if compare_versions or not isinstance(value, str) or '@' not in value:
        return value
    if value.startswith(('./', 'docker://')) or OURS_RE.match(value):
        return value
    return value.split('@', 1)[0] + '@*'


def item_key(item, index, compare_versions):
    for k in ('name', 'id'):
        if isinstance(item.get(k), str):
            return item[k]
    if isinstance(item.get('uses'), str):
        return norm_uses(item['uses'], compare_versions)
    return str(index)


def render(segs, rest=False):
    """A path's text, from its segments, each ('key', k) or ('item', key).
    With rest, the text of segments that follow another path."""
    out = ''
    for kind, name in segs:
        if kind == 'item':
            out += f'[{name}]'
        else:
            out += f'.{name}' if out or rest else name
    return out


def depth(declared, segs):
    """How many of segs a declared path names, when it names them or a parent of them."""
    for n in range(len(segs), 0, -1):
        if render(segs[:n]) == declared:
            return n
    return None


def covers(entry, segs):
    n = depth(entry['path'], segs)
    if n is None:
        return False
    return 'value' in entry or not any(kind == 'key' and name in GUARDED for kind, name in segs[n:])


class Flat:
    """A workflow as {path: leaf value}, with each leaf's segments, and the
    item keys of each list of mappings, in order, as {path: (segments, keys)}."""

    def __init__(self, node, compare_versions):
        self.leaves, self.segs, self.lists = {}, {}, {}
        self._walk(node, (), compare_versions)

    def _walk(self, node, segs, cv):
        if isinstance(node, dict) and node:
            for k, v in node.items():
                k = 'on' if k is True else str(k)   # YAML 1.1 reads `on` as true
                self._walk(v, segs + (('key', k),), cv)
        elif isinstance(node, list) and node and all(isinstance(x, dict) for x in node):
            keys, seen = [], {}
            for i, v in enumerate(node):
                key = item_key(v, i, cv)
                seen[key] = seen.get(key, 0) + 1
                if seen[key] > 1:
                    key = f'{key} #{seen[key]}'
                keys.append(key)
                self._walk(v, segs + (('item', key),), cv)
            self.lists[render(segs)] = (segs, keys)
        else:
            if segs[-1:] == (('key', 'uses'),):
                node = norm_uses(node, cv)
            path = render(segs)
            self.leaves[path], self.segs[path] = node, segs

    def under(self, declared):
        """The leaves at or under a declared path, keyed by the rest of their path."""
        out = {}
        for path, segs in self.segs.items():
            n = depth(declared, segs)
            if n is not None:
                out[render(segs[n:], rest=True)] = self.leaves[path]
        return out


def held(leaves):
    """What under() found, as a finding shows it."""
    if not leaves:
        return MISSING
    return leaves[''] if list(leaves) == [''] else {k.removeprefix('.'): v for k, v in leaves.items()}


def unpinned(flat):
    """The quantecon/actions actions that do not run at @v0, as {path: uses}."""
    return {p: v for p, v in flat.leaves.items()
            if flat.segs[p][-1:] == (('key', 'uses'),) and isinstance(v, str)
            and OURS_RE.match(v) and v.partition('@')[2] != 'v0'}


def load_workflow(text, where):
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise Unread(f'{where} is not YAML ({disp(str(e).splitlines()[0])})') from None
    if not isinstance(doc, dict):
        raise Unread(f'{where} is not a workflow')
    return doc


def load_declarations(text):
    """{workflow file: [entry]}, each entry a path, a why, and maybe a value."""
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise Refused(f'{DECLARATIONS_NAME} is not YAML: {e}') from None
    if not isinstance(doc, dict) or not doc:
        raise Refused(f'{DECLARATIONS_NAME} must map each workflow file to a list of entries')
    out = {}
    for name, entries in doc.items():
        if not isinstance(name, str) or not FILE_RE.fullmatch(name):
            raise Refused(f'{DECLARATIONS_NAME}: [{name}] is not a workflow file name')
        entries = [] if entries is None else entries
        if not isinstance(entries, list):
            raise Refused(f'{DECLARATIONS_NAME}: {name} must be a list of entries')
        paths = set()
        for e in entries:
            if (not isinstance(e, dict) or set(e) - {'path', 'why', 'value'}
                    or not isinstance(e.get('path'), str) or not e['path'].strip()
                    or not isinstance(e.get('why'), str) or not e['why'].strip()):
                raise Refused(f'{DECLARATIONS_NAME}: {name}: each entry gives a path and a why, '
                              f'and may give a value, and nothing else: {e!r}')
            if e['path'] in paths:
                raise Refused(f'{DECLARATIONS_NAME}: {name}: [{e["path"]}] is listed twice')
            paths.add(e['path'])
        out[name] = entries
    return out


def compare(name, template_text, canary_text, entries, compare_versions):
    """One finding line for one workflow, and whether it is red."""
    where = f'`templates/{name}` at `v0`'
    try:
        t = Flat(load_workflow(template_text, where), compare_versions)
        c = Flat(load_workflow(canary_text, f"the canary's `{name}`"), compare_versions)
    except Unread as e:
        return f'- 🔴 `{name}`: {e}.', True
    problems, used = [], set()

    def covered(segs):
        found = [e['path'] for e in entries if covers(e, segs)]
        used.update(found)
        return found

    pins = unpinned(c)
    for p, v in sorted(pins.items()):
        problems.append(f'{code(p)} runs {show(v)}, where the canary runs every `quantecon/actions` action at `@v0`')
    for p in sorted(set(t.leaves) | set(c.leaves)):
        a, b = t.leaves.get(p, MISSING), c.leaves.get(p, MISSING)
        if same(a, b) or covered(c.segs[p] if p in c.segs else t.segs[p]) or p in pins:
            continue
        if a is MISSING:
            problems.append(f'{code(p)} is only in the canary, as {show(b)}')
        elif b is MISSING:
            problems.append(f'{code(p)} is only in the template, as {show(a)}')
        else:
            problems.append(f'{code(p)} is {show(b)} here and {show(a)} in the template')
    for p in sorted(set(t.lists) & set(c.lists)):
        segs, tk = t.lists[p]
        ck = c.lists[p][1]
        both = set(tk) & set(ck)
        tk, ck = [k for k in tk if k in both], [k for k in ck if k in both]
        if tk == ck or covered(segs):
            continue
        i = next(i for i, (x, y) in enumerate(zip(ck, tk)) if x != y)
        problems.append(f'{code(p)} has {show(ck[i])} before {show(tk[i])} here, and after it in the template')
    for e in entries:
        if 'value' not in e:
            continue
        want = Flat(e['value'], compare_versions)
        want = {render(s, rest=True): want.leaves[p] for p, s in want.segs.items()}
        got = c.under(e['path'])
        if want.keys() != got.keys() or not all(same(want[k], got[k]) for k in want):
            problems.append(f'{code(e["path"])} is {show(held(got))} here, where the declarations give {show(e["value"])}')
    for e in entries:
        if e['path'] not in used:
            problems.append(f'the declarations list {code(e["path"])}, which no longer differs')
    if not problems:
        if not used:
            return f'- ✅ `{name}` matches {where}.', False
        n = len(entries)
        return f'- ✅ `{name}` matches {where}, apart from {n} declared difference{"" if n == 1 else "s"}.', False
    more = f'; and {len(problems) - LISTED} more' if len(problems) > LISTED else ''
    return (f'- 🔴 `{name}` has drifted from {where}: ' + '; '.join(problems[:LISTED]) + more
            + f". Realign the canary's copy, or bring `{DECLARATIONS_NAME}` in step with it."), True


def check(declarations, read_template, read_canary, compare_versions):
    """The finding lines, and whether any is red."""
    lines, red = [], False
    for name, entries in declarations.items():
        try:
            template = read_template(name)
        except Unread as e:
            lines.append(f'- 🔴 `{name}`: `templates/{name}` at `v0` could not be read ({e}).')
            red = True
            continue
        try:
            canary = read_canary(name)
        except Unread as e:
            lines.append(f"- 🔴 `{name}`: the canary's copy could not be read ({e}).")
            red = True
            continue
        line, bad = compare(name, template, canary, entries, compare_versions)
        lines.append(line)
        red = red or bad
    return lines, red


def read_at(v0, canary_ref):
    """The line that names what was read, outside the red lines' hash."""
    ref = f'`{disp(canary_ref)}`' if canary_ref else 'its default branch'
    return f"- `v0` was read at {v0[:7]}, and the canary's workflows at {ref}."


def schedule_filters(text):
    """Problems with the jobs' filters on github.event.schedule in a
    workflow: one that runs a job only on a named cron, which an edit to that
    cron alone would turn off, and one that names a cron on.schedule does
    not have."""
    doc = load_workflow(text, 'the workflow')
    on = doc.get('on', doc.get(True))
    schedule = on.get('schedule') if isinstance(on, dict) else None
    crons = {s.get('cron') for s in schedule or [] if isinstance(s, dict)}
    problems = []
    for job, spec in (doc.get('jobs') or {}).items():
        cond = spec.get('if', '') if isinstance(spec, dict) else ''
        for op, cron in SCHEDULE_RE.findall(str(cond)):
            if op == '==':
                problems.append(f"job {job} runs on a schedule only when it is '{cron}', so editing that cron "
                                "alone would turn the job off: skip a cron with != instead")
            if cron not in crons:
                problems.append(f"job {job} names the schedule '{cron}', which on.schedule does not have")
    return problems


def gh(*args):
    r = subprocess.run(['gh', *args], capture_output=True, text=True)
    if r.returncode != 0:
        last = (r.stderr.strip().splitlines() or ['gh failed'])[-1]
        raise Unread(disp(last.removeprefix('gh: ')))
    return r.stdout


def raw(repo, path, ref):
    return gh('api', '-H', 'Accept: application/vnd.github.raw',
              f'repos/{repo}/contents/{path}' + (f'?ref={ref}' if ref else ''))


def main(argv):
    compare_versions, canary_ref, args = False, '', list(argv)
    while args:
        a = args.pop(0)
        if a == '--compare-versions':
            compare_versions = True
        elif a == '--canary-ref' and args:
            canary_ref = args.pop(0)
        else:
            raise Refused(f'usage: scripts/canary-drift.py [--compare-versions] [--canary-ref REF] | --self-test; got [{a}]')
    canary, templates = os.environ.get('CANARY_REPO', ''), os.environ.get('TEMPLATES_REPO', '')
    for var, value in (('CANARY_REPO', canary), ('TEMPLATES_REPO', templates)):
        if not REPO_RE.fullmatch(value):
            raise Refused(f'{var} [{value}] is not owner/name')
    with open(DECLARATIONS) as f:
        declarations = load_declarations(f.read())
    try:
        v0 = gh('api', f'repos/{templates}/commits/v0', '--jq', '.sha').strip()
    except Unread as e:
        print(f'- 🔴 The drift check could not find `v0` in {templates} ({e}).')
        return 1
    if not re.fullmatch(r'[0-9a-f]{40}', v0):
        print(f'- 🔴 The drift check could not find `v0` in {templates} (it read [{disp(v0)}]).')
        return 1
    lines, red = check(declarations,
                       lambda name: raw(templates, f'templates/{name}', v0),
                       lambda name: raw(canary, f'.github/workflows/{name}', canary_ref),
                       compare_versions)
    print('\n'.join(lines + [read_at(v0, canary_ref)]))
    return 1 if red else 0


def self_test():
    failures = []

    def expect(name, got, want):
        if got != want:
            failures.append(f'{name}: got [{got}], expected [{want}]')

    template = '''
on:
  pull_request:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: full
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          fetch-depth: 1
      - name: Build
        uses: quantecon/actions/build-lectures@v0
        with:
          builder: html
'''
    exact = '- ✅ `ci.yml` matches `templates/ci.yml` at `v0`.'

    def declared(n):
        return f'- ✅ `ci.yml` matches `templates/ci.yml` at `v0`, apart from {n} declared difference{"" if n == 1 else "s"}.'

    def run(canary, entries=(), compare_versions=False, t=template):
        return compare('ci.yml', t, canary, list(entries), compare_versions)

    def red(name, result, *parts):
        line, bad = result
        expect(f'{name}: red', bad, True)
        for part in parts:
            if part not in line:
                failures.append(f'{name}: [{line}] has no [{part}]')

    def green(name, result, want):
        expect(name, result, (want, False))

    green('identical', run(template), exact)
    green('comments and key order are not compared',
          run('''# a comment
jobs:
  build:
    steps:
      - uses: actions/checkout@v7
        with: {fetch-depth: 1}
        name: Checkout
      - name: Build
        with: {builder: html}   # a comment
        uses: quantecon/actions/build-lectures@v0
    container: {image: full}
    runs-on: ubuntu-latest
on:
  pull_request:
    branches: [main]
'''), exact)
    lean = template.replace('image: full', 'image: lean')
    red('an undeclared change', run(lean),
        '- 🔴 `ci.yml` has drifted from `templates/ci.yml` at `v0`: ',
        '`jobs.build.container.image` is `"lean"` here and `"full"` in the template',
        "Realign the canary's copy, or bring `.github/canary-drift.yml` in step with it.")
    image = {'path': 'jobs.build.container.image', 'why': 'the lean image'}
    green('a declared change', run(lean, [image]), declared(1))
    green('a declared value held', run(lean, [dict(image, value='lean')]), declared(1))
    red('a declared value not held', run(lean, [dict(image, value='other')]),
        '`jobs.build.container.image` is `"lean"` here, where the declarations give `"other"`')
    red('a declaration that no longer differs', run(template, [image]),
        'the declarations list `jobs.build.container.image`, which no longer differs')
    container = {'path': 'jobs.build.container', 'why': 'the lean image'}
    green('a declared mapping value held', run(lean, [dict(container, value={'image': 'lean'})]), declared(1))
    red('a declared mapping value not held', run(lean, [dict(container, value={'image': 'other'})]),
        '`jobs.build.container` is `{"image": "lean"}` here, where the declarations give `{"image": "other"}`')
    red('a declared mapping value with a key the canary lacks',
        run(lean, [dict(container, value={'image': 'lean', 'options': '--user 0'})]),
        '`jobs.build.container` is `{"image": "lean"}` here, where the declarations give')
    added = template.replace('      - name: Build\n', '      - name: Marker\n        run: echo x\n      - name: Build\n')
    red('a step only in the canary', run(added),
        '`jobs.build.steps[Marker].run` is only in the canary, as `"echo x"`')
    marker = {'path': 'jobs.build.steps[Marker]', 'why': 'a marker'}
    green('a step declared by its name covers everything under it', run(added, [marker]), declared(1))
    green('a prefix covers only whole keys',
          run(lean, [{'path': 'jobs.build.container', 'why': 'x'}]), declared(1))
    red('a prefix does not cover a longer key name',
        run(lean, [{'path': 'jobs.build.contain', 'why': 'x'}]),
        '`jobs.build.container.image` is `"lean"` here',
        'the declarations list `jobs.build.contain`, which no longer differs')
    any_branch = template.replace('  pull_request:\n    branches: [main]\n', '  pull_request:\n  workflow_dispatch:\n')
    green('`on` is read as a key, and a removed key and its parent are covered',
          run(any_branch, [{'path': 'on.pull_request', 'why': 'any branch'},
                           {'path': 'on.workflow_dispatch', 'why': 'by hand'}]), declared(2))
    red('a key only in the template', run(any_branch, [{'path': 'on.workflow_dispatch', 'why': 'by hand'}]),
        '`on.pull_request.branches` is only in the template, as `["main"]`',
        '`on.pull_request` is only in the canary, as `null`')
    red("YAML's true is not its 1", run(template.replace('fetch-depth: 1', 'fetch-depth: true')),
        '`jobs.build.steps[Checkout].with.fetch-depth` is `true` here and `1` in the template')

    # Step order: the steps both have run in the same order.
    swapped = '''
on:
  pull_request:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: full
    steps:
      - name: Build
        uses: quantecon/actions/build-lectures@v0
        with:
          builder: html
      - name: Checkout
        uses: actions/checkout@v7
        with:
          fetch-depth: 1
'''
    red('steps in another order', run(swapped),
        '`jobs.build.steps` has `"Build"` before `"Checkout"` here, and after it in the template')
    green('steps in another order, declared', run(swapped, [{'path': 'jobs.build.steps', 'why': 'x'}]), declared(1))
    green('a step only in the canary leaves the order of the rest', run(added, [marker]), declared(1))

    # quantecon/actions runs at @v0, declared or not.
    red("quantecon/actions' version is always compared",
        run(template.replace('build-lectures@v0', 'build-lectures@v0.20.1')),
        '`jobs.build.steps[Build].uses` runs `"quantecon/actions/build-lectures@v0.20.1"`, '
        'where the canary runs every `quantecon/actions` action at `@v0`')
    cloudflare = template.replace('      - name: Build\n', '      - name: Cloudflare\n'
                                  '        uses: quantecon/actions/preview-cloudflare@v0\n      - name: Build\n')
    step = {'path': 'jobs.build.steps[Cloudflare]', 'why': 'both previews'}
    green('a declared step at @v0', run(cloudflare, [step]), declared(1))
    red('a declared step that does not run @v0', run(cloudflare.replace('cloudflare@v0', 'cloudflare@main'), [step]),
        '`jobs.build.steps[Cloudflare].uses` runs `"quantecon/actions/preview-cloudflare@main"`')
    red('a declared job that does not run @v0',
        run(cloudflare.replace('cloudflare@v0', 'cloudflare@v0.17.0'), [{'path': 'jobs.build', 'why': 'x'}]),
        '`jobs.build.steps[Cloudflare].uses` runs `"quantecon/actions/preview-cloudflare@v0.17.0"`')
    red('a declared step with no version',
        run(cloudflare.replace('cloudflare@v0', 'cloudflare'), [step]),
        '`jobs.build.steps[Cloudflare].uses` runs `"quantecon/actions/preview-cloudflare"`')

    # A declaration covers if, continue-on-error and permissions only by naming them.
    for key, value in (('if', 'false'), ('continue-on-error', 'true')):
        off = cloudflare.replace('        uses: quantecon/actions/preview-cloudflare@v0\n',
                                 f'        uses: quantecon/actions/preview-cloudflare@v0\n        {key}: {value}\n')
        red(f'a declared step with {key}', run(off, [step]),
            f'`jobs.build.steps[Cloudflare].{key}` is only in the canary, as `{value}`')
        green(f'a declared step with {key}, named', run(off, [step, {'path': f'jobs.build.steps[Cloudflare].{key}', 'why': 'x'}]),
              declared(2))
        green(f'a declared step with {key}, in its value',
              run(off, [{'path': 'jobs.build.steps[Cloudflare]', 'why': 'x',
                         'value': {'name': 'Cloudflare', 'uses': 'quantecon/actions/preview-cloudflare@v0', key: yaml.safe_load(value)}}]),
              declared(1))
    wide = cloudflare.replace('    runs-on: ubuntu-latest\n', '    runs-on: ubuntu-latest\n    permissions: write-all\n')
    red('a declared job with permissions', run(wide, [{'path': 'jobs.build', 'why': 'x'}]),
        '`jobs.build.permissions` is only in the canary, as `"write-all"`')
    red('a declared job with nested permissions',
        run(cloudflare.replace('    runs-on: ubuntu-latest\n', '    runs-on: ubuntu-latest\n    permissions:\n      contents: write\n'),
            [{'path': 'jobs.build', 'why': 'x'}]),
        '`jobs.build.permissions.contents` is only in the canary, as `"write"`')
    green('a declared job with permissions, named and held',
          run(wide, [{'path': 'jobs.build', 'why': 'x'}, {'path': 'jobs.build.permissions', 'why': 'y', 'value': 'write-all'}]),
          declared(2))

    bumped = template.replace('actions/checkout@v7', 'actions/checkout@v8')
    green("a third-party action's version is not compared", run(bumped), exact)
    red('with --compare-versions it is', run(bumped, compare_versions=True),
        '`jobs.build.steps[Checkout].uses` is `"actions/checkout@v8"` here and `"actions/checkout@v7"` in the template')
    unnamed = template.replace('      - name: Checkout\n        uses: actions/checkout@v7\n', '      - uses: actions/checkout@v7\n')
    green("a step with no name is keyed by its uses, without a third-party version",
          run(unnamed.replace('checkout@v7', 'checkout@v9'), t=unnamed), exact)
    long = template.replace('builder: html', 'builder: ' + 'x' * 80)
    red('a long value is cut short', run(long), '`"' + 'x' * (SHOWN - 1) + '…`')
    red('the canary is not YAML', run('on: [unclosed'), "- 🔴 `ci.yml`: the canary's `ci.yml` is not YAML (")
    red('the canary is not a workflow', run('- a list'), "- 🔴 `ci.yml`: the canary's `ci.yml` is not a workflow.")
    many = template + ''.join(f'  job{i}:\n    runs-on: x\n' for i in range(12))
    red('at most LISTED problems are listed', run(many), '; and 4 more.')
    sly = template.replace('      - name: Build\n', '      - name: "x\\n::warning::y `z`"\n        run: echo\n      - name: Build\n')
    line, _ = run(sly)
    expect('a step name with a line break stays on one line', '\n' in line or '\r' in line, False)
    red('a step name is shown escaped', (line, True), "steps[x\\u000a::warning::y 'z'].run")

    # check(): each listed file, and one that cannot be read.
    def reader(files):
        def read(name):
            if name not in files:
                raise Unread('Not Found (HTTP 404)')
            return files[name]
        return read
    decl = {'ci.yml': [], 'cache.yml': []}
    lines, bad = check(decl, reader({'ci.yml': template, 'cache.yml': template}), reader({'ci.yml': template}), False)
    expect('check: a canary file that cannot be read', (lines, bad), ([
        exact,
        "- 🔴 `cache.yml`: the canary's copy could not be read (Not Found (HTTP 404)).",
    ], True))
    lines, bad = check({'restore.yml': []}, reader({}), reader({'restore.yml': template}), False)
    expect('check: a template that cannot be read', (lines, bad), (
        ['- 🔴 `restore.yml`: `templates/restore.yml` at `v0` could not be read (Not Found (HTTP 404)).'], True))
    expect('the commit v0 was read at is on a line of its own',
           (read_at('f7e98be' + '0' * 33, ''), read_at('a' * 40, 'afd76d2')),
           ("- `v0` was read at f7e98be, and the canary's workflows at its default branch.",
            "- `v0` was read at aaaaaaa, and the canary's workflows at `afd76d2`."))

    # load_declarations(): what it refuses.
    for name, text in [
        ('not a mapping', '- ci.yml'),
        ('empty', ''),
        ('a bad file name', '"../ci.yml": []'),
        ('not a list', 'ci.yml: {path: x, why: y}'),
        ('no why', 'ci.yml: [{path: x}]'),
        ('an empty why', 'ci.yml: [{path: x, why: " "}]'),
        ('an unknown key', 'ci.yml: [{path: x, why: y, note: z}]'),
        ('a path twice', 'ci.yml: [{path: x, why: y}, {path: x, why: z}]'),
    ]:
        try:
            load_declarations(text)
            failures.append(f'load_declarations accepted {name}: [{text}]')
        except Refused:
            pass
    expect('load_declarations: an empty list', load_declarations('restore.yml:\n'), {'restore.yml': []})

    # The repository's own declarations file loads.
    try:
        with open(DECLARATIONS) as f:
            real = load_declarations(f.read())
        expect('the declarations list the four workflows', sorted(real),
               ['cache.yml', 'ci.yml', 'publish.yml', 'restore.yml'])
    except (OSError, Refused) as e:
        failures.append(f'{DECLARATIONS_NAME}: {e}')

    # schedule_filters(): canary-watch.yml runs its jobs on every cron it has.
    watch = "on:\n  schedule:\n    - cron: '30 6 * * *'\njobs:\n  drift:\n    if: {}\n    runs-on: x\n"
    expect('a job with no filter', schedule_filters(watch.format("github.event_name != 'push'")), [])
    expect('a skip filter on a cron it has', schedule_filters(watch.format("github.event.schedule != '30 6 * * *'")), [])
    got = schedule_filters(watch.format("github.event_name != 'schedule' || github.event.schedule == '30 6 * * *'"))
    expect('a filter that runs a job on one cron only', len(got) == 1 and "only when it is '30 6 * * *'" in got[0], True)
    got = schedule_filters(watch.format("github.event.schedule != '45 6 * * 1'"))
    expect('a filter on a cron the workflow does not have', got,
           ["job drift names the schedule '45 6 * * 1', which on.schedule does not have"])
    try:
        with open(WATCH_WORKFLOW) as f:
            expect('canary-watch.yml runs each job on every cron it has', schedule_filters(f.read()), [])
    except (OSError, Unread) as e:
        failures.append(f'canary-watch.yml: {e}')

    for f in failures:
        annotate('error', f'self-test: {f}')
    if failures:
        annotate('error', f'canary-drift self-test: {len(failures)} case(s) failed')
        return 1
    print('canary-drift self-test passed')
    return 0


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['--self-test']:
            sys.exit(self_test())
        sys.exit(main(sys.argv[1:]))
    except Refused as e:
        annotate('error', str(e))
        sys.exit(2)
