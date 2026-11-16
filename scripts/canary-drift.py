#!/usr/bin/env python3
"""Compare the canary's workflows with templates/ at v0 (#310).

canary-watch.yml's drift job runs it. Each workflow that
.github/canary-drift.yml lists is read from the canary's default branch, and
the template of the same name from templates/ at the commit v0 points to,
and the two are compared as YAML: comments, key order and the order of a
list of steps are not compared. A difference the declarations do not list
is drift. So is a listed one that no longer differs, since it would hide a
later change there, and a listed value that the canary no longer holds.

  scripts/canary-drift.py [--compare-versions] [--canary-ref REF]
  scripts/canary-drift.py --self-test

It prints one markdown list item per workflow, a ✅ or a 🔴, and exits 1
if any is red. A bad declarations file or argument exits 2.

A path joins keys with dots, and names an item of a list of mappings, a
step or a cron, by its `name`, or its `id`, or its `uses`, or else its
index, in brackets: `jobs.build.steps[Restore execution cache].with.save-cache`.
A declared path covers itself and everything under it.

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
REPO_RE = re.compile(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+')
FILE_RE = re.compile(r'[A-Za-z0-9_.-]+\.ya?ml')
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


def norm_uses(value, compare_versions):
    """An action's `uses`, without its version unless it is ours."""
    if compare_versions or not isinstance(value, str) or '@' not in value:
        return value
    if value.startswith(('./', 'docker://')):
        return value
    head = value.split('@', 1)[0]
    if head.lower().startswith('quantecon/actions/'):
        return value
    return head + '@*'


def item_key(item, index, compare_versions):
    for k in ('name', 'id'):
        if isinstance(item.get(k), str):
            return item[k]
    if isinstance(item.get('uses'), str):
        return norm_uses(item['uses'], compare_versions)
    return str(index)


def flatten(node, compare_versions, path=''):
    """A document as {path: leaf value}."""
    if isinstance(node, dict) and node:
        out = {}
        for k, v in node.items():
            k = 'on' if k is True else str(k)   # YAML 1.1 reads `on` as true
            out.update(flatten(v, compare_versions, f'{path}.{k}' if path else k))
        return out
    if isinstance(node, list) and node and all(isinstance(x, dict) for x in node):
        out, seen = {}, {}
        for i, v in enumerate(node):
            key = item_key(v, i, compare_versions)
            seen[key] = seen.get(key, 0) + 1
            if seen[key] > 1:
                key = f'{key} #{seen[key]}'
            out.update(flatten(v, compare_versions, f'{path}[{key}]'))
        return out
    if path.rsplit('.', 1)[-1] == 'uses':
        node = norm_uses(node, compare_versions)
    return {path: node}


def covers(declared, path):
    return path == declared or path.startswith(declared + '.') or path.startswith(declared + '[')


def show(value):
    if value is MISSING:
        return 'absent'
    text = json.dumps(value, ensure_ascii=False).replace('`', "'")
    if len(text) > SHOWN:
        text = text[:SHOWN] + '…'
    return f'`{text}`'


def load_workflow(text, where):
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise Unread(f'{where} is not YAML ({str(e).splitlines()[0]})') from None
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


def compare(name, template_text, canary_text, entries, at, compare_versions):
    """One finding line for one workflow, and whether it is red."""
    where = f'`templates/{name}` at {at}'
    try:
        t = flatten(load_workflow(template_text, where), compare_versions)
        c = flatten(load_workflow(canary_text, f"the canary's `{name}`"), compare_versions)
    except Unread as e:
        return f'- 🔴 `{name}`: {e}.', True
    diffs = sorted(p for p in set(t) | set(c) if t.get(p, MISSING) != c.get(p, MISSING))
    problems, used = [], set()
    for p in diffs:
        covering = [e for e in entries if covers(e['path'], p)]
        if not covering:
            if p not in t:
                problems.append(f'`{p}` is only in the canary, as {show(c[p])}')
            elif p not in c:
                problems.append(f'`{p}` is only in the template, as {show(t[p])}')
            else:
                problems.append(f'`{p}` is {show(c[p])} here and {show(t[p])} in the template')
            continue
        for e in covering:
            used.add(e['path'])
            if e['path'] == p and 'value' in e and c.get(p, MISSING) != e['value']:
                problems.append(f'`{p}` is {show(c.get(p, MISSING))} here, where the declarations give {show(e["value"])}')
    for e in entries:
        if e['path'] not in used:
            problems.append(f'the declarations list `{e["path"]}`, which no longer differs')
    if not problems:
        if not diffs:
            return f'- ✅ `{name}` matches {where}.', False
        n = len(entries)
        return f'- ✅ `{name}` matches {where}, apart from {n} declared difference{"" if n == 1 else "s"}.', False
    more = f'; and {len(problems) - LISTED} more' if len(problems) > LISTED else ''
    return (f'- 🔴 `{name}` has drifted from {where}: ' + '; '.join(problems[:LISTED]) + more
            + f". Realign the canary's copy, or bring `{DECLARATIONS_NAME}` in step with it."), True


def check(declarations, read_template, read_canary, at, compare_versions):
    """The finding lines, and whether any is red."""
    lines, red = [], False
    for name, entries in declarations.items():
        try:
            template = read_template(name)
        except Unread as e:
            lines.append(f'- 🔴 `{name}`: `templates/{name}` at {at} could not be read ({e}).')
            red = True
            continue
        try:
            canary = read_canary(name)
        except Unread as e:
            lines.append(f"- 🔴 `{name}`: the canary's copy could not be read ({e}).")
            red = True
            continue
        line, bad = compare(name, template, canary, entries, at, compare_versions)
        lines.append(line)
        red = red or bad
    return lines, red


def gh(*args):
    r = subprocess.run(['gh', *args], capture_output=True, text=True)
    if r.returncode != 0:
        last = (r.stderr.strip().splitlines() or ['gh failed'])[-1]
        raise Unread(last.removeprefix('gh: '))
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
        print(f'- 🔴 The drift check could not find `v0` in {templates} (it read [{v0}]).')
        return 1
    lines, red = check(declarations,
                       lambda name: raw(templates, f'templates/{name}', v0),
                       lambda name: raw(canary, f'.github/workflows/{name}', canary_ref),
                       f'`v0` ({v0[:7]})', compare_versions)
    print('\n'.join(lines))
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
      - name: Build
        uses: quantecon/actions/build-lectures@v0
        with:
          builder: html
'''

    def run(canary, entries=(), compare_versions=False, t=template):
        return compare('ci.yml', t, canary, list(entries), '`v0` (abc1234)', compare_versions)

    def red(name, result, *parts):
        line, bad = result
        expect(f'{name}: red', bad, True)
        for part in parts:
            if part not in line:
                failures.append(f'{name}: [{line}] has no [{part}]')

    def green(name, result, want):
        expect(name, result, (want, False))

    green('identical', run(template), '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234).')
    green('comments, key order and step order are not compared',
          run('''# a comment
jobs:
  build:
    steps:
      - name: Build
        with: {builder: html}   # a comment
        uses: quantecon/actions/build-lectures@v0
      - uses: actions/checkout@v7
        name: Checkout
    container: {image: full}
    runs-on: ubuntu-latest
on:
  pull_request:
    branches: [main]
'''), '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234).')
    lean = template.replace('image: full', 'image: lean')
    red('an undeclared change', run(lean),
        '- 🔴 `ci.yml` has drifted from `templates/ci.yml` at `v0` (abc1234): ',
        '`jobs.build.container.image` is `"lean"` here and `"full"` in the template',
        "Realign the canary's copy, or bring `.github/canary-drift.yml` in step with it.")
    image = {'path': 'jobs.build.container.image', 'why': 'the lean image'}
    green('a declared change', run(lean, [image]),
          '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234), apart from 1 declared difference.')
    green('a declared value held', run(lean, [dict(image, value='lean')]),
          '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234), apart from 1 declared difference.')
    red('a declared value not held', run(lean, [dict(image, value='other')]),
        '`jobs.build.container.image` is `"lean"` here, where the declarations give `"other"`')
    red('a declaration that no longer differs', run(template, [image]),
        'the declarations list `jobs.build.container.image`, which no longer differs')
    added = template.replace('      - name: Build\n', '      - name: Marker\n        run: echo x\n      - name: Build\n')
    red('a step only in the canary', run(added),
        '`jobs.build.steps[Marker].run` is only in the canary, as `"echo x"`')
    green('a step declared by its name covers everything under it',
          run(added, [{'path': 'jobs.build.steps[Marker]', 'why': 'a marker'}]),
          '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234), apart from 1 declared difference.')
    green('a prefix covers only whole keys',
          run(lean, [{'path': 'jobs.build.container', 'why': 'x'}]),
          '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234), apart from 1 declared difference.')
    red('a prefix does not cover a longer key name',
        run(lean, [{'path': 'jobs.build.contain', 'why': 'x'}]),
        '`jobs.build.container.image` is `"lean"` here',
        'the declarations list `jobs.build.contain`, which no longer differs')
    any_branch = template.replace('  pull_request:\n    branches: [main]\n', '  pull_request:\n  workflow_dispatch:\n')
    green('`on` is read as a key, and a removed key and its parent are covered',
          run(any_branch, [{'path': 'on.pull_request', 'why': 'any branch'},
                           {'path': 'on.workflow_dispatch', 'why': 'by hand'}]),
          '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234), apart from 2 declared differences.')
    red('a key only in the template', run(any_branch, [{'path': 'on.workflow_dispatch', 'why': 'by hand'}]),
        '`on.pull_request.branches` is only in the template, as `["main"]`',
        '`on.pull_request` is only in the canary, as `null`')
    bumped = template.replace('actions/checkout@v7', 'actions/checkout@v8')
    green("a third-party action's version is not compared", run(bumped),
          '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234).')
    red('with --compare-versions it is', run(bumped, compare_versions=True),
        '`jobs.build.steps[Checkout].uses` is `"actions/checkout@v8"` here and `"actions/checkout@v7"` in the template')
    red("quantecon/actions' version is always compared",
        run(template.replace('build-lectures@v0', 'build-lectures@v0.20.1')),
        '`jobs.build.steps[Build].uses` is `"quantecon/actions/build-lectures@v0.20.1"` here')
    unnamed = template.replace('      - name: Checkout\n        uses: actions/checkout@v7\n', '      - uses: actions/checkout@v7\n')
    green("a step with no name is keyed by its uses, without a third-party version",
          run(unnamed.replace('checkout@v7', 'checkout@v9'), t=unnamed),
          '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234).')
    long = template.replace('builder: html', 'builder: ' + 'x' * 80)
    red('a long value is cut short', run(long), '`"' + 'x' * (SHOWN - 1) + '…`')
    red('the canary is not YAML', run('on: [unclosed'), "- 🔴 `ci.yml`: the canary's `ci.yml` is not YAML (")
    red('the canary is not a workflow', run('- a list'), "- 🔴 `ci.yml`: the canary's `ci.yml` is not a workflow.")
    many = template + ''.join(f'  job{i}:\n    runs-on: x\n' for i in range(12))
    red('at most LISTED problems are listed', run(many), '; and 4 more.')

    # check(): each listed file, and one that cannot be read.
    def reader(files):
        def read(name):
            if name not in files:
                raise Unread('Not Found (HTTP 404)')
            return files[name]
        return read
    decl = {'ci.yml': [], 'cache.yml': []}
    lines, bad = check(decl, reader({'ci.yml': template, 'cache.yml': template}),
                       reader({'ci.yml': template}), '`v0` (abc1234)', False)
    expect('check: a canary file that cannot be read', (lines, bad), ([
        '- ✅ `ci.yml` matches `templates/ci.yml` at `v0` (abc1234).',
        "- 🔴 `cache.yml`: the canary's copy could not be read (Not Found (HTTP 404)).",
    ], True))
    lines, bad = check({'restore.yml': []}, reader({}), reader({'restore.yml': template}), '`v0` (abc1234)', False)
    expect('check: a template that cannot be read', (lines, bad), (
        ['- 🔴 `restore.yml`: `templates/restore.yml` at `v0` (abc1234) could not be read (Not Found (HTTP 404)).'], True))

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
