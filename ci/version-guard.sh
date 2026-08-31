#!/usr/bin/env bash
# Confirms the 5 copies of the chart version agree with each other
# (--mode=internal), and — in --mode=release — that HEAD is exactly on a
# tag matching Chart.yaml's own version (never `git tag | sort -V |
# tail -1`: the 0.x line was tagged AFTER 1.x, so a naive sort picks the
# wrong "latest" — always use `git describe`'s HEAD-reachable answer).
# --mode=auto (the default, what the regular CI `guard` job runs) always
# does the internal check, and additionally does the release check IFF
# HEAD happens to sit exactly on a tag already (so a normal PR branch,
# not on any tag, only gets the internal check — the release check is
# meaningless there).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="auto"
for arg in "$@"; do
  case "$arg" in
    --mode=*) MODE="${arg#--mode=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  internal|release|auto) ;;
  *) echo "unknown --mode='$MODE' (want internal|release|auto)" >&2; exit 2 ;;
esac

fail=0
say_fail() {
  echo "FAIL: $1" >&2
  fail=1
}

chart_version() {
  # Anchored at column 0 -- never the indented dependency version line.
  grep -E '^version: ' "$1/Chart.yaml" | head -1 | awk '{print $2}'
}

values_example_version() {
  grep -E '^# v[0-9]+\.[0-9]+\.[0-9]+$' "$1/values-example.yaml" | head -1 | sed -E 's/^# v//'
}

echo "== version-guard: internal (5-copy agreement) =="

dep_v="$(chart_version deployment)"
sts_v="$(chart_version statefulset)"
dep_ve="$(values_example_version deployment)"
sts_ve="$(values_example_version statefulset)"
readme_versions="$(grep -oE -- '--version [0-9]+\.[0-9]+\.[0-9]+' README.md | awk '{print $2}' | sort -u)"
readme_count="$(echo "$readme_versions" | grep -c . || true)"

echo "  deployment/Chart.yaml:        $dep_v"
echo "  statefulset/Chart.yaml:       $sts_v"
echo "  deployment/values-example:    $dep_ve"
echo "  statefulset/values-example:   $sts_ve"
echo "  README.md --version refs:     $(echo "$readme_versions" | tr '\n' ' ')"

[ -n "$dep_v" ] || say_fail "deployment/Chart.yaml has no top-level version: line"
[ -n "$sts_v" ] || say_fail "statefulset/Chart.yaml has no top-level version: line"
[ -n "$dep_ve" ] || say_fail "deployment/values-example.yaml has no '# vX.Y.Z' header"
[ -n "$sts_ve" ] || say_fail "statefulset/values-example.yaml has no '# vX.Y.Z' header"
[ "$readme_count" -ge 1 ] 2>/dev/null || say_fail "README.md has no --version X.Y.Z reference at all"
[ "$readme_count" -le 1 ] 2>/dev/null || say_fail "README.md's --version references disagree with each other: $(echo "$readme_versions" | tr '\n' ' ')"

readme_v="$(echo "$readme_versions" | head -1)"

if [ "$fail" -eq 0 ]; then
  all_agree=1
  for v in "$sts_v" "$dep_ve" "$sts_ve" "$readme_v"; do
    [ "$v" = "$dep_v" ] || all_agree=0
  done
  if [ "$all_agree" -eq 0 ]; then
    say_fail "the 5 copies don't all agree (deployment/Chart.yaml says '$dep_v', see the table above) — run 'hack/bump-version.sh <version>' to fix all 5 at once"
  else
    echo "  OK — all 5 copies agree on ${dep_v}"
  fi
fi

do_release_check=0
if [ "$MODE" = "release" ]; then
  do_release_check=1
elif [ "$MODE" = "auto" ]; then
  if git describe --tags --exact-match >/dev/null 2>&1; then
    do_release_check=1
  else
    echo "  (auto mode: HEAD is not exactly on a tag — skipping the release check)"
  fi
fi

if [ "$do_release_check" -eq 1 ]; then
  echo "== version-guard: release (HEAD must be exactly on a tag matching Chart.yaml) =="
  if ! head_tag="$(git describe --tags --exact-match 2>/dev/null)"; then
    say_fail "--mode=release requires HEAD to be exactly on a tag (git describe --tags --exact-match failed) — did you forget --fetch-tags or fetch-depth:0 in checkout?"
  else
    echo "  HEAD tag (git describe, HEAD-reachable — never 'git tag | sort -V | tail -1'): $head_tag"
    if [ "$fail" -eq 0 ] && [ "$head_tag" != "$dep_v" ]; then
      say_fail "tag '$head_tag' does not match Chart.yaml's version '$dep_v' — 'helm push' derives the OCI tag from the filename Chart.yaml builds, so a mismatch here silently publishes under the wrong tag"
    elif [ "$fail" -eq 0 ]; then
      echo "  OK — tag ${head_tag} matches"
    fi
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "version-guard FAILED" >&2
  exit 1
fi
echo "version-guard OK"
