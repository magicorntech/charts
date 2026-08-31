# CLAUDE.md — magicorntech/charts

Agent rulebook for this repo. README.md is the human-facing chart docs;
this file is operating rules for whoever (human or agent) touches this
codebase next.

## Hard rule: never commit without a full green gate

Every change — a new feature, an optional key, a bugfix, a CI script
edit, anything — must pass the **entire** existing test suite before it
gets committed. Not a subset, not "the tests related to what I changed."
The full gate:

```bash
make test          # == ci/gate.sh all: lint, unittest, render, kubeconform,
                    # notes, destination-guard, exec-probe-guard, package-check
```

This is a direct, explicit instruction from the user (2026-08-31) — not a
default I inferred. "O olmadan commitlemiyoruz."

Why this matters more than usual here: this repo has already been bitten,
more than once in its own history (see the commit log for the Phase
4-through-6 work), by changes that looked correct locally but broke under
conditions the author's own machine didn't reproduce — a stale vendored
`.tgz`, a `set -o pipefail` + `grep -q` SIGPIPE that only manifests once a
package listing crosses a size threshold, a Helm-version-specific flag or
error-message difference. The test suite (227 unittest cases + kubeconform
+ render/package-check) is what actually catches these, but only if it's
run to completion, not skipped because "this change is small."

## Before trusting a green local run

- `make test` pins Helm 3.21.4 (the version this chart actually publishes
  with) via `.bin/helm` — don't assume a bare `helm` on PATH matches it.
  A newer local Helm (e.g. 4.x on this repo's own dev machine) can behave
  differently in ways that only show up in CI. If you need to check
  against a different pinned version (3.10.3 is the README's documented
  floor), download that binary explicitly and point `PATH` at it.
- If you're diagnosing a CI-only failure that doesn't reproduce locally,
  don't guess — reproduce the actual CI environment. Docker running
  `ubuntu:24.04` with `--platform linux/amd64` (GitHub Actions'
  `ubuntu-latest` is x86_64; this repo's own dev machine is Apple
  Silicon, and Docker's default arm64 emulation there has already once
  masked a real bug during this repo's own CI debugging) plus the exact
  pinned Helm binary is what actually found the two bugs in that class so
  far (`ci/gate.sh` SIGPIPE issue, `helm plugin install --verify` not
  existing on Helm 3.x). Guessing from the error text alone burned real
  time before that switch.
- Version-specific error message text is not safe to hardcode in a shell
  check. Different Helm versions link different underlying library
  versions (e.g. `gojsonschema`) and phrase the *same* rejection
  differently. Match on substance (the check's `cmd_destination_guard` is
  the reference example: verifies every valid destination name is
  present in the error, not one exact string).

## Where the actual gate lives

`ci/gate.sh` is the single source of truth — GitHub Actions, and any
local `make test`, all call it. Never add test logic anywhere else that
could drift from what CI actually runs.
