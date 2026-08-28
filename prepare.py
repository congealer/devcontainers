#!/usr/bin/env python3
"""Bump template versions ahead of a release.

Pick the templates, pick a level for each, and the new version is written into
devcontainer-template.json and the docs regenerated. It stops there: the version
is what decides whether 'make release' uploads anything, so the diff is left to
be read and committed rather than done for you.
"""

import json
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path

try:
    import questionary
except ImportError:
    sys.exit("questionary is not installed - rebuild the dev container")

ROOT = Path(__file__).resolve().parent


def metadata(template):
    return ROOT / "src" / template / "devcontainer-template.json"


def current_version(template):
    return json.loads(metadata(template).read_text())["version"]


def candidates(version):
    """The version each level would produce, in the order they are offered."""
    major, minor, patch = (int(part) for part in version.split("."))
    return OrderedDict(
        major=f"{major + 1}.0.0",
        minor=f"{major}.{minor + 1}.0",
        patch=f"{major}.{minor}.{patch + 1}",
    )


def git(*args):
    done = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=False
    )
    return done.stdout.strip()


def state(template, version):
    """Whether the template has moved on since its version was last set.

    The commit that introduced the current version string is the mark: anything
    touching the template after it is work the published version does not carry.
    'make prepare' writes the version and leaves the commit to you, so a version
    that is not in the history at all is its own answer.
    """
    if git("status", "--porcelain", "--", f"src/{template}"):
        return "bumped, uncommitted"

    mark = git(
        "log", "-1", "--format=%H",
        "-S", f'"version": "{version}"',
        "--", f"src/{template}/devcontainer-template.json",
    )
    if not mark:
        return "version never committed"

    if git("log", "--oneline", f"{mark}..HEAD", "--", f"src/{template}"):
        return "changed"
    return ""


def write_version(template, version):
    """Rewrite the version alone, leaving the rest of the file's order intact."""
    path = metadata(template)
    data = json.loads(path.read_text(), object_pairs_hook=OrderedDict)
    data["version"] = version
    path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n")


def main():
    templates = sorted(d.name for d in (ROOT / "src").iterdir() if d.is_dir())
    if not templates:
        sys.exit("no templates under src/")

    # Pre-checked is the point: the ones carrying changes are the ones that
    # have to go up, and a release that misses one is the failure worth avoiding.
    choices = []
    for t in templates:
        version = current_version(t)
        note = state(t, version)
        choices.append(
            questionary.Choice(
                f"{t}  ({version})" + (f"  - {note}" if note else ""),
                value=t,
                checked=note == "changed",
            )
        )

    chosen = questionary.checkbox("Templates to bump", choices=choices).ask()
    if not chosen:
        sys.exit("nothing picked")

    # Asked per template rather than once: a release usually carries a different
    # kind of change to each one.
    picked = OrderedDict()
    for template in chosen:
        current = current_version(template)
        options = candidates(current)
        version = questionary.select(
            f"{template} is {current}",
            choices=[
                questionary.Choice(f"{level}  {v}", value=v)
                for level, v in options.items()
            ],
        ).ask()
        if version is None:
            sys.exit("nothing picked")
        picked[template] = (current, version)

    print()
    for template, (current, version) in picked.items():
        write_version(template, version)
        print(f"  {template}  {current} -> {version}")

    # The generated README carries the description and the options rather than
    # the version, so this usually reports nothing. It runs anyway, because
    # publishing with the docs out of step is the thing worth avoiding.
    subprocess.run(["make", "docs"], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)

    print()
    subprocess.run(["git", "--no-pager", "diff", "--stat"], cwd=ROOT, check=True)
    print("\nNothing is committed. Read the diff, then commit and 'make release'.")


if __name__ == "__main__":
    main()
