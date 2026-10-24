#!/usr/bin/env python3
"""Fails when a macOS build links anything but the system and itself.

Every Mach-O file of an unpacked build - the libraries and ffprobe - may
load only what every Mac carries (/usr/lib, /System) and the build's own
libraries by @rpath, and must name itself by @rpath too. A path into
the build machine - the stage prefix, Homebrew - works on the runner and
nowhere else, which is the failure this exists to catch before a player
ships it. Each file must also be built for arm64 and no newer macOS than
the player supports.

Usage: check_links.py <directory>
"""

import pathlib
import subprocess
import sys

MINIMUM_MACOS = (14, 0)
ALLOWED = ("/usr/lib/", "/System/Library/", "@rpath/")


def macho_files(root):
    for path in sorted(root.rglob("*")):
        if path.is_file() and not path.is_symlink() and (path.suffix == ".dylib" or path.parent.name == "bin"):
            yield path


def otool(*args):
    return subprocess.run(["otool", *args], check=True, capture_output=True, text=True).stdout


def minimum_os(path):
    lines = otool("-l", str(path)).splitlines()
    for i, line in enumerate(lines):
        if line.strip() == "cmd LC_BUILD_VERSION":
            for follow in lines[i + 1:i + 6]:
                key, _, value = follow.strip().partition(" ")
                if key == "minos":
                    return tuple(int(part) for part in value.split("."))
    return None


def main():
    root = pathlib.Path(sys.argv[1])
    failures = []
    checked = 0
    for path in macho_files(root):
        checked += 1
        name = path.relative_to(root)
        archs = subprocess.run(["lipo", "-archs", str(path)], check=True, capture_output=True, text=True).stdout.split()
        if archs != ["arm64"]:
            failures.append(f"{name}: built for {' '.join(archs)}, not arm64 alone")
        if path.suffix == ".dylib":
            own = otool("-D", str(path)).splitlines()[1:]
            if not own or not own[0].startswith("@rpath/"):
                failures.append(f"{name}: names itself {own[0] if own else 'nothing'}, not by @rpath")
        for line in otool("-L", str(path)).splitlines()[1:]:
            dependency = line.strip().split(" (")[0]
            if not dependency.startswith(ALLOWED):
                failures.append(f"{name}: links {dependency}")
        minos = minimum_os(path)
        if minos is None or minos > MINIMUM_MACOS:
            failures.append(f"{name}: needs macOS {'.'.join(map(str, minos)) if minos else 'unknown'}")
    if checked == 0:
        failures.append(f"no Mach-O file under {root}")
    for line in failures:
        print(f"FAIL: {line}")
    if not failures:
        print(f"{checked} files checked, each links only the system and its own libraries")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
