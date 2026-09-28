#!/usr/bin/env python3
"""Generate the user manual's reference tables from each action.yml, and check its examples.

action.yml is the single source for per-input and per-output facts (#178, decision 5). This
script copies them into the manual, between markers:

    <!-- BEGIN GENERATED: <block> ... -->
    ...
    <!-- END GENERATED -->

  inputs, outputs  in each chapter, docs/user/actions/<action>.md
  actions          the action table in docs/user/README.md
  signpost         the whole of <action>/README.md, once the action has a chapter

Usage:

  python3 scripts/generate-docs.py            rewrite every generated block
  python3 scripts/generate-docs.py --check    print the diff and fail if a block is out of date
  python3 scripts/generate-docs.py --check-examples [--actionlint PATH]

--check-examples reads every yaml block in docs/user and every workflow in templates/:

  - each yaml block in docs/user must parse;
  - each `uses: quantecon/actions/<action>@<ref>` step may pass only inputs that <action>/action.yml
    declares, and must pass every required one;
  - each complete workflow (one with both `on:` and `jobs:`) must set `permissions:`, at the top
    or on every job; a block with `jobs:` but no `on:` is refused, being neither complete nor a
    fragment;
  - with --actionlint, each complete workflow must pass actionlint. Doc blocks are fed to it with
    their Markdown path and line numbers, so its messages point into the chapter.

Steps commented out in a template are not checked: only what YAML parses is.

Needs PyYAML (scripts/requirements.txt).
"""

import argparse
import difflib
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
MANUAL = ROOT / "docs" / "user"
CHAPTERS = MANUAL / "actions"
INDEX = MANUAL / "README.md"
TEMPLATES = ROOT / "templates"
REPO_URL = "https://github.com/QuantEcon/actions"

# The order the manual lists the actions in, which is the order a lecture repo meets them.
# A new action goes here too; the script refuses to guess where.
ORDER = [
    "setup-environment",
    "build-lectures",
    "build-jupyter-cache",
    "restore-jupyter-cache",
    "preview-netlify",
    "preview-cloudflare",
    "publish-gh-pages",
    "deploy-cloudflare",
]

BEGIN = re.compile(r"^<!-- BEGIN GENERATED: ([a-z]+)\b.*-->\s*$")
END = re.compile(r"^<!-- END GENERATED -->\s*$")
FENCE = re.compile(r"^( *)(`{3,}|~{3,})(.*)$")
CODE_SPAN = re.compile(r"(`+)(?:[^`]|(?!\1)`)*?\1")
OWN_STEP = re.compile(r"^quantecon/actions/([^@\s]+)@(\S+)$", re.IGNORECASE)

errors = []


def rel(path):
    return path.relative_to(ROOT).as_posix()


def error(path, line, message):
    errors.append((rel(path), line, message))


def report_errors():
    in_actions = os.environ.get("GITHUB_ACTIONS") == "true"
    for path, line, message in errors:
        if in_actions:
            where = f"file={path},line={line}" if line else f"file={path}"
            message = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print(f"::error {where}::{message}")
        else:
            print(f"{path}:{line or 1}: {message}", file=sys.stderr)


# --------------------------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------------------------


class Action:
    def __init__(self, name):
        self.name = name
        self.path = ROOT / name / "action.yml"
        with open(self.path, encoding="utf-8") as f:
            meta = yaml.safe_load(f)
        self.title = meta.get("name") or name
        self.description = meta.get("description") or ""
        self.inputs = meta.get("inputs") or {}
        self.outputs = meta.get("outputs") or {}
        self.chapter = CHAPTERS / f"{name}.md"
        self.readme = ROOT / name / "README.md"

    def required(self):
        return {k for k, v in self.inputs.items() if str((v or {}).get("required", "")).lower() == "true"}


def load_actions():
    found = sorted(p.parent.name for p in ROOT.glob("*/action.yml"))
    for name in found:
        if name not in ORDER:
            where = rel(Path(__file__))
            error(ROOT / name / "action.yml", 0, f"{name} is not in ORDER in {where}, so the manual cannot place it")
    for name in ORDER:
        if name not in found:
            error(Path(__file__), 0, f"ORDER names {name}, which has no action.yml")
    return [Action(name) for name in ORDER if name in found]


# --------------------------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------------------------


def code(value):
    ticks = "``" if "`" in value else "`"
    pad = " " if value.startswith("`") or value.endswith("`") else ""
    return f"{ticks}{pad}{value}{pad}{ticks}"


def prose(text, source, where):
    """action.yml text as one line of Markdown, refusing what GitHub or the publisher would eat."""
    text = " ".join(str(text).split())
    outside_code = CODE_SPAN.sub("", text)
    if "${{" in outside_code:
        error(source, 0, f"{where}: the manual keeps ${{{{ … }}}} inside backticks")
    if "<" in outside_code:
        error(source, 0, f"{where}: put <…> in backticks, or GitHub renders it as an HTML tag and drops it")
    return text


def cell(text, source, where):
    return prose(text, source, where).replace("|", "\\|")


def default(spec, required):
    if spec.get("default") is None:
        # GitHub passes '' for an optional input with no default.
        return "none" if required else "`''`"
    value = spec["default"]
    if isinstance(value, bool):
        value = "true" if value else "false"
    value = str(value)
    return code(value) if value else "`''`"


def inputs_table(action):
    if not action.inputs:
        return "This action has no inputs."
    rows = ["| Input | Required | Default | Description |", "|---|---|---|---|"]
    required = action.required()
    for name, spec in action.inputs.items():
        spec = spec or {}
        rows.append(
            f"| `{name}` | {'yes' if name in required else 'no'} | {default(spec, name in required)} | "
            f"{cell(spec.get('description', ''), action.path, f'input {name}')} |"
        )
    return "\n".join(rows)


def outputs_table(action):
    if not action.outputs:
        return "This action has no outputs."
    rows = ["| Output | Description |", "|---|---|"]
    for name, spec in action.outputs.items():
        rows.append(f"| `{name}` | {cell((spec or {}).get('description', ''), action.path, f'output {name}')} |")
    return "\n".join(rows)


def actions_table(actions):
    rows = ["| Action | What it does |", "|---|---|"]
    for action in actions:
        if action.chapter.is_file():
            link = f"actions/{action.name}.md"
        else:
            # No chapter yet (#190): its README is still the reference.
            link = f"{REPO_URL}/tree/main/{action.name}"
        rows.append(f"| [`{action.name}`]({link}) | {cell(action.description, action.path, 'description')} |")
    return "\n".join(rows)


def signpost(action):
    return "\n".join(
        [
            f"# {action.title}",
            "",
            prose(action.description, action.path, "description"),
            "",
            f"How to set it up, and every input and output: [the `{action.name}` chapter of the user manual]"
            f"(../docs/user/actions/{action.name}.md).",
            "",
            "Every action: [the user manual](../docs/user/README.md).",
        ]
    )


def begin_line(block, source):
    if block == "signpost":
        return (
            f"<!-- BEGIN GENERATED: signpost. scripts/generate-docs.py writes this whole file from {source}: "
            "edit that, or the chapter, instead. -->"
        )
    return (
        f"<!-- BEGIN GENERATED: {block}. scripts/generate-docs.py writes this from {source}: "
        "edit that, not this. -->"
    )


def wrap(block, source, body):
    return [begin_line(block, source), "", *body.split("\n"), "", "<!-- END GENERATED -->"]


def fill(path, blocks, source):
    """Return path's text with each named block regenerated, or None if its markers are unusable."""
    lines = path.read_text(encoding="utf-8").split("\n")
    out, seen, i = [], [], 0
    while i < len(lines):
        m = BEGIN.match(lines[i])
        if END.match(lines[i]):
            error(path, i + 1, "END GENERATED with no BEGIN GENERATED before it")
            return None
        if not m:
            out.append(lines[i])
            i += 1
            continue
        name, start = m.group(1), i
        if name not in blocks:
            error(path, i + 1, f"unknown generated block '{name}'; this file takes {', '.join(sorted(blocks))}")
            return None
        if name in seen:
            error(path, i + 1, f"a second '{name}' block")
            return None
        i += 1
        while i < len(lines) and not END.match(lines[i]):
            if BEGIN.match(lines[i]):
                error(path, i + 1, f"BEGIN GENERATED inside the '{name}' block that starts on line {start + 1}")
                return None
            i += 1
        if i == len(lines):
            error(path, start + 1, f"the '{name}' block has no END GENERATED")
            return None
        seen.append(name)
        out.extend(wrap(name, source, blocks[name]))
        i += 1
    for name in sorted(set(blocks) - set(seen)):
        error(path, 0, f"no '{name}' block: add a BEGIN GENERATED: {name} / END GENERATED pair where it belongs")
    return "\n".join(out) if set(seen) == set(blocks) else None


def generate(actions):
    """Map each generated file to the text it should have."""
    wanted = {}
    names = {a.name for a in actions}
    for chapter in sorted(CHAPTERS.glob("*.md")) if CHAPTERS.is_dir() else []:
        if chapter.stem not in names:
            message = f"{rel(CHAPTERS)} holds one chapter per action, and there is no {chapter.stem}/action.yml"
            error(chapter, 0, message)
    missing = []
    for action in actions:
        source = f"{action.name}/action.yml"
        if action.chapter.is_file():
            text = fill(action.chapter, {"inputs": inputs_table(action), "outputs": outputs_table(action)}, source)
            if text is not None:
                wanted[action.chapter] = text
            wanted[action.readme] = "\n".join(wrap("signpost", source, signpost(action))) + "\n"
        else:
            missing.append(action.name)
            if action.readme.is_file() and "BEGIN GENERATED: signpost" in action.readme.read_text(encoding="utf-8"):
                error(action.readme, 1, f"a generated signpost, but {rel(action.chapter)} does not exist")
    if INDEX.is_file():
        text = fill(INDEX, {"actions": actions_table(actions)}, "each action.yml")
        if text is not None:
            wanted[INDEX] = text
    else:
        error(INDEX, 0, "the manual's index is missing")
    if missing:
        # #190 makes this an error, once every action has its chapter.
        print(f"no chapter yet, so the README is still the reference: {', '.join(missing)}")
    return wanted


def drift(wanted, check):
    stale = 0
    for path, text in wanted.items():
        current = path.read_text(encoding="utf-8") if path.is_file() else ""
        if current == text:
            continue
        stale += 1
        if check:
            sys.stdout.writelines(
                difflib.unified_diff(
                    current.splitlines(keepends=True),
                    text.splitlines(keepends=True),
                    f"a/{rel(path)}",
                    f"b/{rel(path)}",
                )
            )
            error(path, 0, "out of date with action.yml: run python3 scripts/generate-docs.py and commit the result")
        else:
            path.write_text(text, encoding="utf-8")
            print(f"updated {rel(path)}")
    if check and not errors:
        print(f"generated docs are current ({len(wanted)} files)")


# --------------------------------------------------------------------------------------------
# Examples
# --------------------------------------------------------------------------------------------


def yaml_blocks(path):
    """Yield (fence line, text) for each ```yaml block of a Markdown file."""
    lines = path.read_text(encoding="utf-8").split("\n")
    i = 0
    while i < len(lines):
        m = FENCE.match(lines[i])
        if not m or (m.group(2)[0] == "`" and "`" in m.group(3)):
            i += 1
            continue
        indent, fence, info = len(m.group(1)), m.group(2), m.group(3).strip()
        start, body = i + 1, []
        i += 1
        while i < len(lines):
            close = re.match(r"^ *(`{3,}|~{3,}) *$", lines[i])
            if close and close.group(1)[0] == fence[0] and len(close.group(1)) >= len(fence):
                break
            line = lines[i]
            body.append(line[min(indent, len(line) - len(line.lstrip(" "))):])
            i += 1
        i += 1
        if info.split()[:1] in (["yaml"], ["yml"]):
            yield start, "\n".join(body)


def keys(node):
    return {k.value: (k, v) for k, v in node.value if isinstance(k, yaml.ScalarNode)}


def mappings(node, seen=None):
    seen = set() if seen is None else seen
    if id(node) in seen:
        return
    seen.add(id(node))
    if isinstance(node, yaml.MappingNode):
        yield node
        for _, value in node.value:
            yield from mappings(value, seen)
    elif isinstance(node, yaml.SequenceNode):
        for value in node.value:
            yield from mappings(value, seen)


def check_steps(root, path, offset, actions):
    steps = 0
    for node in mappings(root):
        uses = keys(node).get("uses")
        if not uses or not isinstance(uses[1], yaml.ScalarNode):
            continue
        ref, line = uses[1].value, offset + uses[1].start_mark.line + 1
        if not ref.lower().startswith("quantecon/actions/"):
            continue
        steps += 1
        m = OWN_STEP.match(ref)
        if not m:
            error(path, line, f"cannot read [{ref}]: expected quantecon/actions/<action>@<ref>")
            continue
        action = actions.get(m.group(1))
        if action is None:
            error(path, line, f"{ref}: there is no {m.group(1)}/action.yml in this repository")
            continue
        supplied = {}
        with_ = keys(node).get("with")
        if with_:
            if not isinstance(with_[1], yaml.MappingNode):
                error(path, offset + with_[1].start_mark.line + 1, f"{ref}: with: is not a mapping")
                continue
            supplied = keys(with_[1])
        for name, (key, _) in supplied.items():
            if name not in action.inputs:
                error(
                    path,
                    offset + key.start_mark.line + 1,
                    f"{action.name} has no input '{name}' (it takes: {', '.join(action.inputs) or 'none'})",
                )
        for name in sorted(action.required() - set(supplied)):
            error(path, line, f"{action.name} requires input '{name}', and this step does not pass it")
    return steps


def check_workflow(root, path, offset):
    """True if root is a complete workflow; checks its permissions: blocks."""
    if not isinstance(root, yaml.MappingNode):
        return False
    top = keys(root)
    if "jobs" not in top:
        return False
    line = offset + root.start_mark.line + 1
    if "on" not in top:
        error(path, line, "has jobs: but no on:. Make it a complete workflow, or cut it down to the steps")
        return False
    if "permissions" in top:
        return True
    jobs = top["jobs"][1]
    if not isinstance(jobs, yaml.MappingNode):
        return True
    for name, (key, job) in keys(jobs).items():
        if not (isinstance(job, yaml.MappingNode) and "permissions" in keys(job)):
            line = offset + key.start_mark.line + 1
            error(path, line, f"job '{name}' has no permissions: block, and the workflow sets none")
    return True


def check_examples(actions, actionlint):
    by_name = {a.name: a for a in actions}
    workflows = []  # (path, offset, text)
    steps = 0

    sources = [(p, 0, p.read_text(encoding="utf-8")) for p in sorted(TEMPLATES.glob("*.yml"))]
    for doc in sorted(MANUAL.rglob("*.md")) if MANUAL.is_dir() else []:
        sources += [(doc, start, text) for start, text in yaml_blocks(doc)]

    for path, offset, text in sources:
        try:
            roots = [r for r in yaml.compose_all(text) if r is not None]
        except yaml.YAMLError as e:
            mark = getattr(e, "problem_mark", None)
            line = offset + (mark.line + 1 if mark else 1)
            error(path, line, f"does not parse as YAML: {getattr(e, 'problem', None) or e}")
            continue
        complete = False
        for root in roots:
            steps += check_steps(root, path, offset, by_name)
            complete = check_workflow(root, path, offset) or complete
        if complete:
            workflows.append((path, offset, text))
        elif path.parent == TEMPLATES:
            error(path, 1, "a template must be a complete workflow, with on: and jobs:")

    print(f"checked {steps} quantecon/actions steps and {len(workflows)} complete workflows")

    if not actionlint:
        print("actionlint not run (no --actionlint)")
        return
    failed = 0
    for path, offset, text in workflows:
        # Padding keeps actionlint's line numbers equal to the Markdown file's.
        run = subprocess.run(
            [actionlint, "-stdin-filename", rel(path), "-"],
            input="\n" * offset + text,
            text=True,
            cwd=ROOT,
        )
        if run.returncode != 0:
            failed += 1
            error(path, offset + 1 if offset else 0, "actionlint reports problems in this workflow (see the log above)")
    if not failed:
        print(f"actionlint: {len(workflows)} workflows clean")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="fail, with the diff, if a generated block is stale")
    parser.add_argument("--check-examples", action="store_true", help="check the examples in docs/user and templates/")
    parser.add_argument("--actionlint", metavar="PATH", help="with --check-examples, lint complete workflows with it")
    args = parser.parse_args()
    if args.actionlint and not args.check_examples:
        parser.error("--actionlint needs --check-examples")

    actions = load_actions()
    if args.check or not args.check_examples:
        drift(generate(actions), args.check)
    if args.check_examples:
        check_examples(actions, args.actionlint)

    if errors:
        report_errors()
        print(f"{len(errors)} problem(s)", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
