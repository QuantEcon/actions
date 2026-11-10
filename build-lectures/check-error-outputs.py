"""Report error outputs in the notebooks a Jupyter Book build executed (#247).

An exception raised while IPython displays output (a figure that fails to draw,
say) is printed as an `error` output, but the kernel reports the cell as
successful. nbclient raises only on the reply status, and myst-nb renders the
traceback without a warning, so `-W` never fires and the page is published with
the traceback on it. (ipykernel 7.3.0 fails a cell whose last value cannot be
displayed, but not output shown through display(), which is how figures are.)

This reads the notebooks myst-nb wrote, outputs included, to
<output-dir>/_build/jupyter_execute/, and reports every error output that
nothing allows. A notebook it cannot read is reported too, since it went
unchecked.

A cell that raised leaves an error output too. -W fails the build that
executes its page, but the check still meets it after a build without -W, and
after a build that read no page because an earlier build in the job had (#300).
The two are told apart by the code cells after it: nbclient stops at a cell
that raises, so none of them ran, while after a display-time error the next
one runs.

Allowed, as nbclient and myst-nb allow an exception that a cell raises:
  - a cell tagged `raises-exception`;
  - a notebook whose `mystnb` metadata sets `execution_allow_errors`;
  - a book whose _config.yml sets `execute.allow_errors`, or
    `sphinx.config.nb_execution_allow_errors`.

Usage: check-error-outputs.py <fail|warn> <source-dir> <output-dir>

Exits 1 in `fail` mode when it reports anything, an unreadable notebook
included. Standard library only, apart
from PyYAML for _config.yml, which jupyter-book depends on.
"""

import json
import os
import re
import secrets
import sys
from pathlib import Path

# The suffixes a notebook's source can have under source-dir. A notebook in
# jupyter_execute with none of them is left over from an earlier build (a
# restored build cache keeps the notebooks of lectures since removed).
SOURCE_SUFFIXES = (".md", ".ipynb", ".myst", ".py", ".Rmd")
CODE_CELL_FENCE = re.compile(r"^\s*(`{3,}|~{3,})\s*\{code-cell\}")
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
TRACEBACK_LINES = 200
# For each cause(): the end of the annotation, and the summary table's word.
CAUSES = {
    "displayed": ("The kernel reported this cell as successful, so -W did not catch it, "
                  "and the page shows the traceback.", "raised while displaying"),
    "raised": ("The cell raised, and the notebook stopped there: the page shows the "
               "traceback, and no output for the cells after it.", "raised"),
    None: ("The page shows the traceback.", "unknown: no later cell was to run"),
}


def escape_data(text):
    """Escape a workflow command's message, so it stays on one line."""
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape_data(text).replace(":", "%3A").replace(",", "%2C")


def escape_cell(text):
    """Make text safe for one cell of a Markdown table in the step summary."""
    text = " ".join(text.split())
    if len(text) > 200:
        text = text[:197] + "..."
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("|", "\\|")


def book_allows_errors(source_dir):
    """Whether _config.yml allows errors book-wide, and a note if it can't tell."""
    config = source_dir / "_config.yml"
    if not config.is_file():
        return False, None
    try:
        import yaml
    except ImportError:
        return False, f"PyYAML is not installed, so {config} was not read for execute.allow_errors"
    try:
        data = yaml.safe_load(config.read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError) as exc:
        return False, f"{config} could not be read for execute.allow_errors: {exc}"
    execute = data.get("execute") or {}
    sphinx_config = (data.get("sphinx") or {}).get("config") or {}
    return bool(execute.get("allow_errors") or sphinx_config.get("nb_execution_allow_errors")), None


def find_source(source_dir, docname):
    for suffix in SOURCE_SUFFIXES:
        path = source_dir / (docname + suffix)
        if path.is_file():
            return path
    return None


def code_cell_lines(source):
    """The line of each code cell's {code-cell} fence, for a MyST Markdown source.

    None for any other format. The caller uses the lines only when there is one
    fence per code cell in the notebook, so a fence quoted inside another block
    gives no line rather than a wrong one.
    """
    if source.suffix not in (".md", ".myst"):
        return None
    try:
        lines = source.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return None
    return [n + 1 for n, line in enumerate(lines) if CODE_CELL_FENCE.match(line)]


def cause(code_cells, ordinal):
    """Whether the code cell at ordinal raised, or raised while displaying.

    "raised" when no code cell after it ran, "displayed" when one did, and None
    when no code cell after it was to run, so nothing shows either way: the
    last code cell, or one followed only by cells tagged skip-execution, which
    never run.
    """
    later = [c for c in code_cells[ordinal + 1:]
             if "skip-execution" not in (c.get("metadata") or {}).get("tags", [])]
    if not later:
        return None
    if any(c.get("execution_count") is not None for c in later):
        return "displayed"
    return "raised"


def set_count(count):
    """The action's error-output-count output."""
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(f"count={count}\n")


def main():
    mode, source_dir, output_dir = sys.argv[1:4]
    source_dir = Path(source_dir)
    execute_dir = Path(output_dir) / "_build" / "jupyter_execute"
    level = "error" if mode == "fail" else "warning"

    if not execute_dir.is_dir():
        print(f"No executed notebooks to check: {execute_dir} does not exist.")
        set_count(0)
        return 0

    allowed_book_wide, note = book_allows_errors(source_dir)
    if note:
        print(f"::notice::{escape_data(note)}")

    checked = stale = allowed = 0
    hits = []
    unreadable = []
    for notebook_path in sorted(execute_dir.rglob("*.ipynb")):
        docname = notebook_path.relative_to(execute_dir).with_suffix("").as_posix()
        source = find_source(source_dir, docname)
        if source is None:
            stale += 1
            continue
        # Unread is unchecked, so with fail it fails the step: a notebook this
        # cannot read must not pass as one with no error outputs.
        try:
            notebook = json.loads(notebook_path.read_text(encoding="utf-8"))
            if not isinstance(notebook, dict):
                raise ValueError("not a JSON object")
        except (OSError, ValueError) as exc:
            unreadable.append((source, f"{notebook_path} could not be read, so it was not checked for error outputs: {exc}"))
            continue
        checked += 1
        mystnb = (notebook.get("metadata") or {}).get("mystnb") or {}
        allowed_here = allowed_book_wide or bool(mystnb.get("execution_allow_errors"))

        code_cells = [c for c in notebook.get("cells", []) if c.get("cell_type") == "code"]
        starts = code_cell_lines(source)
        if starts is not None and len(starts) != len(code_cells):
            starts = None

        for ordinal, cell in enumerate(code_cells):
            errors = [o for o in cell.get("outputs", []) if o.get("output_type") == "error"]
            if not errors:
                continue
            if allowed_here or "raises-exception" in (cell.get("metadata") or {}).get("tags", []):
                allowed += len(errors)
                continue
            how = cause(code_cells, ordinal)
            for output in errors:
                hits.append({
                    "source": source,
                    "line": starts[ordinal] if starts else None,
                    "cell": ordinal + 1,
                    "count": cell.get("execution_count"),
                    "cause": how,
                    "error": f"{output.get('ename', 'Error')}: {output.get('evalue', '')}",
                    "traceback": ANSI.sub("", "\n".join(output.get("traceback") or [])),
                })

    print(f"Checked {checked} executed notebook(s) in {execute_dir}: "
          f"{len(hits)} error output(s) reported, {allowed} allowed, "
          f"{stale} notebook(s) skipped with no source under {source_dir}, "
          f"{len(unreadable)} could not be read.")
    set_count(len(hits))
    if not hits and not unreadable:
        return 0

    for source, message in unreadable:
        print(f"::{level} file={escape_property(str(source))}::{escape_data(message)}")

    token = "error-outputs-" + secrets.token_hex(8)
    for hit in hits:
        where = f"code cell {hit['cell']}"
        if hit["count"] is not None:
            where += f" (In [{hit['count']}])"
        props = f"file={escape_property(str(hit['source']))}"
        if hit["line"]:
            props += f",line={hit['line']}"
        message = f"{hit['source']}, {where}: {hit['error']}. {CAUSES[hit['cause']][0]}"
        print(f"::{level} {props}::{escape_data(message)}")
        # The traceback is the notebook's own text: stop-commands keeps it from
        # being read as workflow commands.
        print(f"::group::{escape_data(str(hit['source']))}, {where}")
        print(f"::stop-commands::{token}")
        lines = hit["traceback"].splitlines() or [hit["error"]]
        print("\n".join(lines[-TRACEBACK_LINES:]))
        print(f"::{token}::")
        print("::endgroup::")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        verdict = ("❌ The build fails on" if mode == "fail" else "⚠️ The build passes, with a warning, despite")
        rows = []
        if hits:
            rows += [
                f"### {verdict} {len(hits)} error output(s) in the executed notebooks",
                "",
                "Each is a traceback that the page shows. An exception raised while output was "
                "displayed, such as a figure that failed to draw, leaves the cell successful to the "
                "kernel, so `-W` cannot catch it. A cell that raised fails a `-W` build that executes "
                "its page: it reaches this check when `extra-args` has no `-W`, or when an earlier "
                "build in the job read the page and this one read none. Fix the cell, or tag it "
                "`raises-exception` if the error is meant to be shown.",
                "",
                "| Document | Cell | Error | Cause |",
                "|---|---|---|---|",
            ]
            for hit in hits:
                cell = f"{hit['cell']}" + (f" (line {hit['line']})" if hit["line"] else "")
                rows.append(f"| `{hit['source']}` | {cell} | {escape_cell(hit['error'])} "
                            f"| {CAUSES[hit['cause']][1]} |")
            rows.append("")
        if unreadable:
            rows += [f"### {verdict} {len(unreadable)} executed notebook(s) that could not be read", ""]
            rows += [f"- `{source}`: {escape_cell(message)}" for source, message in unreadable]
            rows.append("")
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write("\n".join(rows) + "\n")

    return 1 if mode == "fail" else 0


if __name__ == "__main__":
    sys.exit(main())
