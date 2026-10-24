#!/usr/bin/env python3
"""Fails when a shipped FFmpeg library carries GPL code.

Scans every shared library of an unpacked build for the traces GPL
components leave in the binary. Two are known to have reached the
upstream LGPL build through LGPL libraries that link them:

- FFTW (GPL-2.0-or-later), linked by Chromaprint built with FFT_LIB=fftw3;
  its planner names every codelet "fftw_codelet_*" and its version
  string starts "fftw-".
- zvbi's src/packet-830.c (GPL-2.0-only), called by the Teletext decoder;
  its 8/30 local time decoder subtracts 0x11111 and 0x111111 from two
  BCD fields within a few instructions of each other.

The rest are the GPL-only libraries FFmpeg accepts only with
--enable-gpl, read off the configure line every library embeds - their
names alone are no evidence, since that line names them in --disable
options and FFmpeg's own decoders recognise their encoders' signatures -
and FFmpeg's license string, which names GPL once a GPL part is in.

Usage: gpl_scan.py <directory>
"""

import pathlib
import re
import struct
import sys

STRINGS = {
    b"fftw_codelet_": "FFTW (via Chromaprint)",
    b"fftw-3.": "FFTW (via Chromaprint)",
}

# configure options that put GPL or non-free code into the build.
GPL_OPTIONS = re.compile(
    rb"--enable-(gpl|nonfree|libx264|libx265|libxvid|librubberband|libvidstab|frei0r"
    rb"|libdavs2|libxavs2|libxavs|libcdio|libfdk-aac|chromaprint)\b"
)

LICENSE_OK = b"LGPL version 3 or later"
LICENSE_GPL = re.compile(rb"(?<!L)GPL version [23] or later")

BCD_SMALL = struct.pack("<i", -0x11111)
BCD_LARGE = struct.pack("<i", -0x111111)


def libraries(root):
    for path in sorted(root.rglob("*")):
        name = path.name
        if path.is_file() and (name.endswith((".dll", ".dylib")) or ".so" in name):
            yield path


def packet_830(data):
    small = [m.start() for m in re.finditer(re.escape(BCD_SMALL), data)]
    large = [m.start() for m in re.finditer(re.escape(BCD_LARGE), data)]
    return any(abs(a - b) < 512 for a in small for b in large)


def main():
    root = pathlib.Path(sys.argv[1])
    found = []
    licensed = False
    scanned = 0
    for path in libraries(root):
        data = path.read_bytes()
        scanned += 1
        for marker, what in STRINGS.items():
            if marker in data:
                found.append(f"{path.name}: {what} ({marker.decode()!r})")
        for option in sorted(set(GPL_OPTIONS.findall(data))):
            found.append(f"{path.name}: configured with --enable-{option.decode()}")
        if packet_830(data):
            found.append(f"{path.name}: zvbi packet-830.c (8/30 local time decoder)")
        if LICENSE_OK in data:
            licensed = True
        if LICENSE_GPL.search(data):
            found.append(f"{path.name}: FFmpeg configured with GPL parts")
    if scanned == 0:
        found.append(f"no shared library under {root}")
    elif not licensed:
        found.append("no library carries FFmpeg's LGPL v3 license string")
    for line in found:
        print(f"FAIL: {line}")
    if not found:
        print(f"{scanned} libraries scanned, no GPL code found")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
