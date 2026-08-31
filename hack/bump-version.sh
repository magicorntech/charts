#!/usr/bin/env bash
# Writes the new chart version into every one of the 5 files that carry a
# copy of it — deliberately does NOT create a git tag itself (tagging is
# what actually triggers publish via .devops/buildspec.yml, and that
# should stay a separate, deliberate action, not a side effect of editing
# values). Run `ci/version-guard.sh --mode=internal` afterward (or just
# `make test`, which runs it) to confirm all 5 copies actually agree.
#
# Usage: hack/bump-version.sh X.Y.Z
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: hack/bump-version.sh X.Y.Z" >&2
  echo "  (got: '${VERSION}' — must be a bare semver, no leading 'v')" >&2
  exit 2
fi

sedi() {
  # BSD sed (macOS) needs `-i ''`; GNU sed (CI) accepts `-i` bare. Try GNU
  # form first since it's what actually runs in CI; fall back to BSD.
  if sed --version >/dev/null 2>&1; then
    sed -i -E "$1" "$2"
  else
    sed -i '' -E "$1" "$2"
  fi
}

echo "== bumping to ${VERSION} =="

for chart in deployment statefulset; do
  f="${chart}/Chart.yaml"
  # Anchored at column 0 (`^version: `) so the dependency's own
  # `  version: "1.0.0"` line (charts-common's, indented under
  # `dependencies:`) is never touched — only the umbrella's own top-level
  # version field.
  sedi "s/^version: .*/version: ${VERSION}/" "$f"
  echo "  updated $f"
done

for chart in deployment statefulset; do
  f="${chart}/values-example.yaml"
  sedi "s/^# v[0-9]+\.[0-9]+\.[0-9]+\$/# v${VERSION}/" "$f"
  echo "  updated $f"
done

sedi "s/--version [0-9]+\.[0-9]+\.[0-9]+/--version ${VERSION}/g" README.md
echo "  updated README.md"

echo "== done — run 'ci/version-guard.sh --mode=internal' (or 'make test') to confirm =="
