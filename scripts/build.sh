#!/usr/bin/env bash
# Build the site into _site/.
#
# Static pages are copied; every slide deck is rendered from its Markdown source
# to both HTML and PDF. CI runs this exact script, so a local run and a release
# build cannot disagree about what "the site" is.
#
#   ./scripts/build.sh            # -> _site/
#   ./scripts/build.sh somewhere  # -> somewhere/
#
# Needs node (for npx) and a Chrome/Chromium binary for the PDF export. Point
# CHROME_PATH at one if it is not auto-detected.
set -euo pipefail

MARP_VERSION=4.5.0

out=${1:-_site}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

rm -rf "$out"
mkdir -p "$out/slides"

# CNAME is load-bearing: with Pages building from a workflow, the custom domain
# is dropped if the deployed artifact does not carry this file. Losing it takes
# netclab.dev down, so it is copied first and checked below.
#
# `.nojekyll` is deliberately NOT copied, though it stays in the repository. It
# is read only by the Jekyll build Pages runs when serving from a branch; a
# deployed artifact is served as-is, so in this build it would be inert. It is
# kept because reverting Pages to a branch is then one setting rather than a
# setting plus remembering this file.
cp CNAME index.html "$out/"
cp slides/index.html "$out/slides/"

marp() { npx --yes "@marp-team/marp-cli@${MARP_VERSION}" "$@"; }

for src in slides/*/index.md; do
  deck=$(basename "$(dirname "$src")")
  mkdir -p "$out/slides/$deck"
  echo "==> $deck"
  # --html: the decks use inline <br> and <span style> for layout, which Marp
  # strips unless raw HTML is allowed.
  marp --html "$src" -o "$out/slides/$deck/index.html"
  marp --html "$src" --pdf -o "$out/slides/$deck/$deck.pdf"
done

test -s "$out/CNAME" || { echo "FATAL: CNAME missing from $out" >&2; exit 1; }

echo
echo "built into $out/:"
find "$out" -type f | sort | sed 's/^/  /'
