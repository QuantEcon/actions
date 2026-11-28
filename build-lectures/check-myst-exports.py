"""After a mystmd build of the PDF or the notebooks that exits 0, check what it wrote (#337).

`myst build --pdf` and `myst build --ipynb` exit 0 when they find no export of
their kind to build ("No file exports with kind ... found"), and when an
export fails: the CLI logs the failure and carries on (#337's check, at the
QuantEcon/mystmd fork's 39cda14). So the exit status says nothing about
whether a file was written.

After the exports, myst writes _build/logs/myst.build.json in the folder it
ran in, listing each export it collected, before it ran, with its output
path, whether or not it then succeeded. `--pdf` collects the pdf, pdf+tex and
typst formats, and `--ipynb` the ipynb format. So this checks that the log
was written by this build, that it lists at least one export of the
builder's formats, and that each one's output was written by this build: a
file newer than STAMP, which the action made just before the build.

    python check-myst-exports.py SOURCE_DIR BUILDER STAMP

SOURCE_DIR is the folder myst ran in, BUILDER is pdflatex or jupyter, and
the status is 1 when the check fails, with an ::error:: for each reason.
"""

import json
import os
import sys

# The formats each builder's flag collects (myst-cli's getAllowedExportFormats).
FORMATS = {
    "pdflatex": ("pdf", "pdf+tex", "typst"),
    "jupyter": ("ipynb",),
}
FLAG = {"pdflatex": "--pdf", "jupyter": "--ipynb"}
# What to declare, in myst.yml's project exports or a page's frontmatter.
DECLARE = {
    "pdflatex": "an entry with format: pdf (or typst)",
    "jupyter": "an entry with format: ipynb",
}


def escape_data(text):
    """Text as a workflow command's data: %, CR and LF written as %25, %0D and %0A."""
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def error(message):
    print(f"::error::{escape_data(message)}")


def newer(path, stamp_ns):
    try:
        return os.stat(path).st_mtime_ns > stamp_ns
    except OSError:
        return False


def main():
    source_dir, builder, stamp = sys.argv[1:4]
    flag = FLAG[builder]
    stamp_ns = os.stat(stamp).st_mtime_ns
    log = os.path.join(source_dir, "_build", "logs", "myst.build.json")
    if not newer(log, stamp_ns):
        error(
            f"myst build {flag} exited 0, but this build wrote no {log}, so what it "
            "exported cannot be checked. The build step's log says what myst did."
        )
        return 1
    try:
        with open(log, encoding="utf-8") as f:
            exports = json.load(f).get("exports") or []
    except (OSError, ValueError, AttributeError) as e:
        error(f"myst build {flag} exited 0, but {log} cannot be read: {e}")
        return 1

    wanted = [e for e in exports if isinstance(e, dict) and e.get("format") in FORMATS[builder]]
    if not wanted:
        error(
            f"myst build {flag} exited 0, but found no export of its kind to build, so "
            f"it built nothing. List {DECLARE[builder]} under exports: in "
            f"{os.path.join(source_dir, 'myst.yml')}, or in a page's frontmatter."
        )
        return 1

    missing = []
    for export in wanted:
        output = export.get("output") or ""
        if output and not os.path.isabs(output):
            output = os.path.join(source_dir, output)
        if not output or not newer(output, stamp_ns):
            missing.append(output or f"(an export of {export.get('$file') or 'the project'} with no output)")
    if missing:
        error(
            f"myst build {flag} exited 0, but {len(missing)} of its {len(wanted)} "
            "export(s) wrote nothing in this build: myst logs a failed export and "
            "carries on, and the build step's log says why. Not written: "
            + ", ".join(missing)
        )
        return 1

    print(f"myst build {flag} wrote all {len(wanted)} export(s) it listed:")
    for export in wanted:
        print(f"  {export.get('format')}: {export.get('output')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
