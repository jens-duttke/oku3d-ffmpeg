#!/usr/bin/env bash
# Points this build at the newest upstream FFmpeg release: writes the
# newest dated BtbN autobuild of the highest release branch into
# oku3d/reference.env, and moves the workflow's variant to that branch.
#
#   oku3d/update-reference.sh                      # highest branch
#   oku3d/update-reference.sh --major 9 --minor 0  # a specific branch
#
# The reference is the build every oku3d build is compared against, and
# the one the player's vendor/ffmpeg.lock pins as its tools build, so it
# has to be the upstream build of the same release branch. Only a dated
# autobuild-* tag carrying both the win64 and the linux64 archive counts:
# `latest` floats, and a tag with one half would mix commits.
#
# Needs gh (GitHub CLI, authenticated), curl and sha256sum. Commit,
# push, and run the workflow with doRelease afterwards.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$repo_root/oku3d/reference.env"
workflow="$repo_root/.github/workflows/oku3d.yml"

die() {
    echo "error: $*" >&2
    exit 1
}

major=""
minor=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --major) [[ $# -ge 2 ]] || die "--major takes a number"; major="$2"; shift 2 ;;
        --minor) [[ $# -ge 2 ]] || die "--minor takes a number"; minor="$2"; shift 2 ;;
        *) die "usage: $0 [--major N --minor N]" ;;
    esac
done
for value in "$major" "$minor"; do
    [[ -z "$value" || "$value" =~ ^[0-9]+$ ]] || die "--major / --minor take a number, got '$value'"
done

if [[ -z "$major" || -z "$minor" ]]; then
    echo "==> Discovering the highest FFmpeg release branch BtbN builds"
    best="$(gh api 'repos/BtbN/FFmpeg-Builds/releases/tags/latest' --jq '.assets[].name' \
        | sed -nE 's/^ffmpeg-n([0-9]+)\.([0-9]+)-latest-win64-lgpl-shared-[0-9]+\.[0-9]+\.zip$/\1 \2/p' \
        | sort -k1,1n -k2,2n | tail -n 1)"
    [[ -n "$best" ]] || die "No 'ffmpeg-nX.Y-latest-win64-lgpl-shared-X.Y.zip' asset in BtbN's latest release"
    [[ -n "$major" ]] || major="${best% *}"
    [[ -n "$minor" ]] || minor="${best#* }"
fi
echo "==> Newest BtbN autobuild of FFmpeg n$major.$minor"

# Asset names carry `git describe` output: `ffmpeg-nX.Y.Z-win64-...` at a
# release point, with a `-<commits>-g<hash>` suffix past it.
pattern="^ffmpeg-n${major}\.${minor}\.[0-9]+(-[0-9]+-g[0-9a-f]+)?-win64-lgpl-shared-${major}\.${minor}\.zip$"
releases="$(gh api 'repos/BtbN/FFmpeg-Builds/releases?per_page=30' \
    --jq '.[] | select(.tag_name | startswith("autobuild-")) | .tag_name as $t | .assets[] | "\($t) \(.name)"')"

tag=""
asset=""
linux_asset=""
while read -r candidate; do
    names="$(awk -v t="$candidate" '$1 == t { print $2 }' <<<"$releases")"
    match="$(grep -E -m 1 "$pattern" <<<"$names" || true)"
    [[ -n "$match" ]] || continue
    linux_name="${match/-win64-/-linux64-}"
    linux_name="${linux_name%.zip}.tar.xz"
    if ! grep -qxF "$linux_name" <<<"$names"; then
        echo "    skipping $candidate: no $linux_name next to $match"
        continue
    fi
    tag="$candidate"
    asset="$match"
    linux_asset="$linux_name"
    break
done < <(awk '!seen[$1]++ { print $1 }' <<<"$releases")

[[ -n "$asset" ]] || die "No autobuild-* tag in the last 30 releases has a win64 + linux64 pair matching $pattern"
echo "    tag: $tag"

base="https://github.com/BtbN/FFmpeg-Builds/releases/download/$tag"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
hash_of() {
    echo "    downloading $1" >&2
    curl --fail --location --silent --show-error --output "$tmp_dir/archive" "$base/$1"
    sha256sum "$tmp_dir/archive" | cut -d' ' -f1
}
win_sha256="$(hash_of "$asset")"
linux_sha256="$(hash_of "$linux_asset")"

{
    awk '/^REFERENCE_/ { exit } { print }' "$env_file"
    echo "REFERENCE_LINUX64_URL=$base/$linux_asset"
    echo "REFERENCE_LINUX64_SHA256=$linux_sha256"
    echo "REFERENCE_WIN64_URL=$base/$asset"
    echo "REFERENCE_WIN64_SHA256=$win_sha256"
} > "$tmp_dir/reference.env"
cat "$tmp_dir/reference.env" > "$env_file"

[[ -f "$repo_root/addins/$major.$minor.sh" ]] || die "no addins/$major.$minor.sh - merge upstream first"
sed -i -E "s/^(  VARIANT: lgpl-oku3d-shared) [0-9]+\.[0-9]+$/\1 $major.$minor/" "$workflow"
grep -q "^  VARIANT: lgpl-oku3d-shared $major.$minor$" "$workflow" || die "could not set the workflow's VARIANT to $major.$minor"

echo "==> Reference is $tag (n$major.$minor); commit, push, then run the workflow with doRelease"
