#!/usr/bin/env python3
"""Lint this repository's shell with shellcheck: each action's run: scripts, and scripts/*.sh.

actionlint lints the run: scripts of a workflow but never reads an action.yml (#100, review M5).
This script does, for every */action.yml:

  - a run: script may hold no ${{ }} expression. GitHub writes the expression's value into the
    script's text before the shell reads it, so a value with a quote or a $( ) in it runs as code.
    Pass it through the step's env: and read "$NAME" instead (AGENTS.md). A script that holds one
    is not shellchecked until it is gone;
  - a run: script whose shell: is bash or sh must pass shellcheck at --severity=warning. Each
    finding is reported at its line in action.yml.

The run: scripts in .github/workflows/*.yml are held to the first rule too. actionlint already
shellchecks them. Then every scripts/*.sh must pass shellcheck at the same severity, as its
shebang's dialect. containers/ is left out: a change there rebuilds both images.

Usage:

  python3 scripts/lint-shell.py [--shellcheck PATH]

A finding that is wrong for one command takes `# shellcheck disable=SC<code> # <reason>` on the
line just before it, in a run: script as in a file. shellcheck runs with --norc, so no
.shellcheckrc changes what it reports. Another shellcheck version can report differently: the
script prints the one it ran.

Needs PyYAML (scripts/requirements.txt) and shellcheck.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SEVERITY = "warning"
EXPRESSION = re.compile(r"\$\{\{")

findings = []  # (path, line, column, message)


def rel(path):
    return path.relative_to(ROOT).as_posix()


def report():
    in_actions = os.environ.get("GITHUB_ACTIONS") == "true"
    for path, line, column, message in findings:
        where = f"{path}:{line}:{column}"
        if in_actions:
            text = f"{where}: {message}".replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print(f"::error file={path},line={line},col={column}::{text}")
        else:
            print(f"{where}: {message}", file=sys.stderr)


def mapping(node):
    return {k.value: v for k, v in node.value} if isinstance(node, yaml.MappingNode) else {}


class Script:
    """One run: script, and where its text sits in action.yml."""

    def __init__(self, path, node, text):
        self.path = path
        self.text = node.value
        mark = node.start_mark
        if node.style == "|":
            # A literal block starts on the line after its | indicator, at the block's indent:
            # what the file's line holds before the block's own text of that line. Read from
            # the block's first non-blank line, which a blank or empty block does not have.
            self.first_line = mark.line + 2
            lines = node.value.split("\n")
            k = next((i for i, s in enumerate(lines) if s.strip()), None)
            if k is None:
                self.indent = 0
            else:
                self.indent = len(text.splitlines()[mark.line + 1 + k]) - len(lines[k])
            self.exact = True
        else:
            # A plain scalar on one line maps exactly. A quoted or folded one does not, since
            # quotes, escapes and folding move the text, so its findings are reported at its start.
            self.first_line = mark.line + 1
            self.indent = mark.column
            self.exact = node.style is None and "\n" not in node.value.rstrip("\n")

    def where(self, line, column):
        if not self.exact:
            return self.first_line, self.indent + 1
        return self.first_line + line - 1, self.indent + column


def expressions(script):
    """Record a finding for each ${{ in a run: script, and return how many there were."""
    hits = [m.start() for m in EXPRESSION.finditer(script.text)]
    for offset in hits:
        line = script.text.count("\n", 0, offset) + 1
        column = offset - (script.text.rfind("\n", 0, offset) + 1) + 1
        findings.append((rel(script.path), *script.where(line, column),
                         "a ${{ }} expression in a run: script. Pass the value through "
                         "the step's env: and read it as \"$NAME\" (AGENTS.md)."))
    return len(hits)


def workflow_scripts():
    """Check each workflow's run: scripts for ${{ }} alone: actionlint shellchecks them."""
    files = sorted((ROOT / ".github" / "workflows").glob("*.yml"))
    count = 0
    for path in files:
        text = path.read_text(encoding="utf-8")
        for job in mapping(mapping(yaml.compose(text)).get("jobs")).values():
            steps = mapping(job).get("steps")
            for step in steps.value if isinstance(steps, yaml.SequenceNode) else []:
                node = mapping(step).get("run")
                if node is not None:
                    expressions(Script(path, node, text))
                    count += 1
    return files, count


def action_scripts():
    """Each linted run: script, by dialect. Records findings for expressions and bad shells."""
    by_dialect = {"bash": [], "sh": []}
    files = sorted(ROOT.glob("*/action.yml"))
    for path in files:
        text = path.read_text(encoding="utf-8")
        runs = mapping(mapping(yaml.compose(text)).get("runs"))
        steps = runs.get("steps")
        if not isinstance(steps, yaml.SequenceNode):
            continue
        for step in steps.value:
            fields = mapping(step)
            node = fields.get("run")
            if node is None:
                continue
            script = Script(path, node, text)
            hits = expressions(script)
            shell = fields.get("shell")
            words = shell.value.split() if isinstance(shell, yaml.ScalarNode) else []
            dialect = words[0] if words else None
            if dialect not in by_dialect:
                line, column = script.where(1, 1)
                findings.append((rel(path), line, column,
                                 f"a run: step with shell: [{dialect or ''}], which this check "
                                 "cannot lint, so it would go unchecked. Use bash, and keep other "
                                 "code in a file that bash runs, as build-lectures does with "
                                 "check-error-outputs.py."))
            elif not hits:
                by_dialect[dialect].append(script)
    return files, by_dialect


def shellcheck(command, dialect, paths):
    """shellcheck's json1 comments for the given files, as one run."""
    args = [command, "--norc", f"--severity={SEVERITY}", "--format=json1"]
    if dialect:
        args.append(f"--shell={dialect}")
    run = subprocess.run(args + [str(p) for p in paths], capture_output=True, text=True, cwd=ROOT)
    if run.returncode not in (0, 1):
        sys.exit(f"shellcheck failed (exit {run.returncode}): {run.stderr.strip()}")
    return json.loads(run.stdout)["comments"]


def message(comment):
    return f"SC{comment['code']} ({comment['level']}): {comment['message']}"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--shellcheck", default="shellcheck", metavar="PATH",
                        help="the shellcheck to run (default: the one on PATH)")
    args = parser.parse_args()
    sys.stdout.reconfigure(line_buffering=True)

    try:
        version = subprocess.run([args.shellcheck, "--version"], capture_output=True, text=True,
                                 check=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        sys.exit(f"cannot run shellcheck [{args.shellcheck}]: {e}")
    version = re.search(r"^version: (\S+)", version, re.MULTILINE)
    print(f"shellcheck {version.group(1) if version else '(unknown version)'}, --severity={SEVERITY}")

    files, by_dialect = action_scripts()
    count = sum(len(s) for s in by_dialect.values())
    with tempfile.TemporaryDirectory() as tmp:
        for dialect, scripts in by_dialect.items():
            if not scripts:
                continue
            temps = {}
            for i, script in enumerate(scripts):
                temp = Path(tmp) / f"{dialect}-{i:03d}.sh"
                temp.write_text(script.text, encoding="utf-8")
                temps[str(temp)] = script
            for comment in shellcheck(args.shellcheck, dialect, temps):
                script = temps[comment["file"]]
                findings.append((rel(script.path), *script.where(comment["line"], comment["column"]),
                                 message(comment)))
    print(f"checked {count} run: scripts in {len(files)} action.yml files")

    files, count = workflow_scripts()
    print(f"checked {count} run: scripts in {len(files)} workflows for ${{{{ }}}}")

    scripts = sorted(ROOT.glob("scripts/*.sh"))
    for comment in shellcheck(args.shellcheck, None, [rel(p) for p in scripts]) if scripts else []:
        findings.append((comment["file"], comment["line"], comment["column"], message(comment)))
    print(f"checked {len(scripts)} scripts/*.sh")

    if findings:
        findings.sort()
        report()
        print(f"{len(findings)} findings")
        sys.exit(1)
    print("clean")


if __name__ == "__main__":
    main()
