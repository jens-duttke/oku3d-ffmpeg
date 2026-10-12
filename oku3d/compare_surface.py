#!/usr/bin/env python3
"""Checks that the Oku3D build reads everything the upstream build reads.

Compares two dumps of oku3d/surface.c - the upstream LGPL shared build
the player shipped before, and this repository's build - and fails on
anything the player could open before and cannot now:

- a demuxer, input protocol, parser or bitstream filter gone;
- a codec no decoder decodes any more, or decoded by a different
  decoder than the one upstream picks for it;
- a decoder that reached one of the player's hardware routes no longer
  reaching it;
- a hardware device type, capture device, filter or muxer the player
  itself opens missing.

Everything else upstream carried and this build leaves out is listed in
the report, so a reviewer sees what went without reading configure.

Usage: compare_surface.py {windows,linux} upstream.txt oku3d.txt report.md
"""

import sys
from collections import defaultdict

# What the player opens itself, per platform: its hardware decode routes,
# its capture input, and the filters and muxer it builds.
ROUTES = {"windows": {"d3d11va"}, "linux": {"vaapi", "vulkan"}}
CAPTURE = {"windows": "dshow", "linux": "video4linux2,v4l2"}
FILTERS = {"abuffer", "abuffersink", "atempo"}
MUXERS = {"spdif"}
# Codecs left out on purpose, with the decision that let them go.
AGREED_LOSSES = {
    "svg": "the player renders SVG itself with resvg, and decoding it here takes librsvg with glib, cairo and pango (owner decision 2026-10-12)",
}


def parse(path):
    surface = defaultdict(set)
    decoders = {}
    picked = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            kind, _, rest = line.strip().partition(" ")
            if not kind:
                continue
            if kind == "decoder":
                name, codec, *flags = rest.split(" ")
                codec = codec.removeprefix("codec=")
                decoders[name] = codec
                if "picked" in flags:
                    picked[codec] = name
            elif kind == "hwconfig":
                surface["hwconfig"].add(tuple(rest.split(" ")))
            else:
                surface[kind].add(rest)
    return surface, decoders, picked


def main():
    platform, upstream_path, ours_path, report_path = sys.argv[1:5]
    up, up_decoders, up_picked = parse(upstream_path)
    ours, our_decoders, our_picked = parse(ours_path)
    failures = []

    for kind in ("demuxer", "protocol-in", "parser", "bsf"):
        lost = sorted(up[kind] - ours[kind])
        if lost:
            failures.append(f"{kind} lost: {', '.join(lost)}")

    lost_codecs = sorted(set(up_decoders.values()) - set(our_decoders.values()) - set(AGREED_LOSSES))
    if lost_codecs:
        failures.append(f"codecs no longer decoded: {', '.join(lost_codecs)}")
    for codec, name in sorted(up_picked.items()):
        if codec not in AGREED_LOSSES and our_picked.get(codec) != name:
            failures.append(f"{codec}: upstream decodes with {name}, this build with {our_picked.get(codec)}")

    routes = ROUTES[platform]
    for name, device in sorted(up["hwconfig"]):
        if device in routes and (name, device) not in ours["hwconfig"]:
            failures.append(f"{name} no longer reaches {device}")
    for device in sorted(routes - ours["hwdevice"]):
        failures.append(f"hardware device type {device} missing")

    if CAPTURE[platform] not in ours["indev"]:
        failures.append(f"capture input {CAPTURE[platform]} missing")
    for name in sorted(FILTERS - ours["filter"]):
        failures.append(f"filter {name} missing")
    for name in sorted(MUXERS - ours["muxer"]):
        failures.append(f"muxer {name} missing")

    unknown = sorted(set(our_decoders) - set(up_decoders))
    if unknown:
        failures.append(f"decoders upstream does not have: {', '.join(unknown)}")

    left_out = sorted(set(up_decoders) - set(our_decoders))
    lines = [f"# FFmpeg read surface, {platform}", ""]
    lines.append("Result: " + ("FAIL" if failures else "every format the upstream build reads is still read"))
    lines.append("")
    for failure in failures:
        lines.append(f"- FAIL: {failure}")
    lines.append("")
    lines.append(f"Kept: {len(ours['demuxer'])} demuxers, {len(our_decoders)} decoders "
                 f"for {len(set(our_decoders.values()))} codecs, {len(ours['protocol-in'])} input protocols, "
                 f"{len(ours['parser'])} parsers, {len(ours['bsf'])} bitstream filters.")
    lines.append("")
    for codec, why in sorted(AGREED_LOSSES.items()):
        state = "left out" if codec not in set(our_decoders.values()) else "still decoded"
        lines.append(f"Codec {codec} {state} on purpose: {why}.")
    lines.append("")
    lines.append("Decoders left out - none is the one upstream picks for a codec this build keeps:")
    for name in left_out:
        lines.append(f"- {name} ({up_decoders[name]})")
    lines.append("")
    for kind in ("muxer", "filter", "indev", "hwdevice"):
        gone = sorted(up[kind] - ours[kind])
        lines.append(f"{kind}s left out ({len(gone)}): {', '.join(gone) or '-'}")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
