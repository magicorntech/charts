#!/usr/bin/env bash
# Shared gate entrypoint. Every CI runner (GitHub Actions, CodeBuild, laptop
# `make test`) calls this — no test logic anywhere else, so the merge gate
# and the publish gate can never silently diverge.
#
# Usage: ci/gate.sh <deps|lint|unittest|render|kubeconform|package-check|all> [args...]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHARTS=(deployment statefulset)
KUBE_VERSIONS="${KUBE_VERSIONS:-1.25.0 1.33.0}"
DIST_DIR="$ROOT/dist"

cmd_deps() {
  echo "== deps: rebuilding vendored subcharts from source =="
  # Every path into this gate starts here. A committed or leftover .tgz
  # under */charts/ predates the source and must never be trusted.
  rm -rf deployment/charts statefulset/charts deployment/Chart.lock statefulset/Chart.lock
  helm dependency update deployment
  helm dependency update statefulset
}

cmd_lint() {
  echo "== lint =="
  # NOT --strict: it promotes the umbrella's harmless
  # "templates/: directory does not exist" warning into a failure.
  for chart in "${CHARTS[@]}"; do
    for f in ci/scenarios/"$chart"/*.yaml; do
      [ -e "$f" ] || continue
      echo "-- helm lint $chart -f $f --"
      helm lint "$chart" -f "$f"
    done
  done
}

cmd_unittest() {
  echo "== unittest =="
  mkdir -p "$DIST_DIR/reports"
  local helm_ver
  helm_ver="$(helm version --template '{{.Version}}' 2>/dev/null || echo unknown)"
  # --with-subchart=false + explicit source dirs: the plugin's default
  # (true) collects suites from the vendored copies under */charts/, which
  # .helmignore has just stripped tests/ out of. Naming the 2 umbrella
  # chart dirs directly means every suite is collected from source, exactly
  # once. `common` (the library chart, post-Phase-4) has no test suites of
  # its own -- every one of its `define`s is only exercised indirectly,
  # through the two umbrellas' own tests, and helm-unittest can't render a
  # `type: library` chart standalone anyway.
  helm unittest --with-subchart=false \
    -t JUnit -o "$DIST_DIR/reports/unittest-${helm_ver}.xml" \
    deployment statefulset
}

cmd_render() {
  echo "== render =="
  rm -rf "$DIST_DIR/render"
  for chart in "${CHARTS[@]}"; do
    for f in ci/scenarios/"$chart"/*.yaml; do
      [ -e "$f" ] || continue
      local scenario
      scenario="$(basename "$f" .yaml)"
      for kv in $KUBE_VERSIONS; do
        local out="$DIST_DIR/render/$chart/$scenario/$kv.yaml"
        mkdir -p "$(dirname "$out")"
        helm template "ci-$chart" "$chart" -f "$f" \
          --namespace ci --kube-version "$kv" > "$out"
        [ -s "$out" ] || { echo "EMPTY RENDER: $out"; exit 1; }
      done
    done
  done
}

cmd_kubeconform() {
  echo "== kubeconform =="
  mkdir -p "$DIST_DIR/reports"
  if [ ! -d "$DIST_DIR/render" ]; then
    cmd_render
  fi
  local overall_status=0
  for kv in $KUBE_VERSIONS; do
    local files
    files="$(find "$DIST_DIR/render" -name "$kv.yaml")"
    [ -n "$files" ] || { echo "no rendered files for kube version $kv"; exit 1; }
    echo "-- kubeconform against kube $kv --"
    # Deliberately NOT -ignore-missing-schemas: that would let a typo'd or
    # newly-introduced kind sail through silently. The two CRD kinds this
    # repo emits (SecurityGroupPolicy, SecretProviderClass) are vendored
    # locally so this stays hermetic; the datree catalog is a network
    # fallback for anything else.
    #
    # Deliberately NOT -strict either: ingress-hcp.yaml emits a
    # `property:` field per path (Huawei CCE's own ingress-controller
    # extension, e.g. url-match-mode) that has no place in the standard
    # networking.k8s.io/v1 Ingress schema. -strict flags it as an unknown
    # additional property on every hcp render, which isn't a chart bug —
    # it's a real, if nonstandard, vendor field. A YAML-syntax defect
    # (e.g. bug B2's invalid `{}` splice) already fails at `helm template`
    # before kubeconform ever runs, so -strict's marginal catch here isn't
    # worth the permanent false positive.
    #
    # Runs every kube version even if an earlier one fails, so a single
    # scenario failure doesn't hide problems on the others; the aggregate
    # exit code is checked once every version has run.
    #
    # Retried with backoff: raw.githubusercontent.com's schema CDN has a
    # real, observed flake where one specific file (e.g. the non-strict
    # v1.25.0 apps/v1 Deployment schema) intermittently 400s for a few
    # minutes at a time — confirmed independently of this repo via direct
    # curl, unrelated to anything in the chart. A single transient fetch
    # failure shouldn't fail the whole gate.
    local attempt ok=0
    for attempt in 1 2 3; do
      # shellcheck disable=SC2086
      if kubeconform -verbose \
        -kubernetes-version "$kv" \
        -schema-location default \
        -schema-location 'ci/crd-schemas/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
        -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
        -output junit \
        $files > "$DIST_DIR/reports/kubeconform-$kv.xml"; then
        ok=1
        break
      fi
      if grep -q "error while downloading schema" "$DIST_DIR/reports/kubeconform-$kv.xml" 2>/dev/null; then
        echo "kubeconform: transient schema-download error at kube $kv (attempt $attempt/3), retrying in $((attempt * 5))s..."
        sleep "$((attempt * 5))"
        continue
      fi
      break
    done
    if [ "$ok" -ne 1 ]; then
      overall_status=1
      echo "kubeconform found issues at kube $kv (see $DIST_DIR/reports/kubeconform-$kv.xml)"
    fi
  done
  return "$overall_status"
}

cmd_notes() {
  echo "== notes =="
  # helm-unittest cannot target NOTES.txt at all (not a Kind it renders),
  # and `helm template` skips it entirely — only `helm install --dry-run`
  # exercises it. Since Phase 4, NOTES.txt lives directly in each
  # umbrella's own templates/ (no longer a subchart's), so it renders by
  # default -- --render-subchart-notes is kept anyway, harmlessly, in case
  # a future subchart ever grows its own notes again.
  #
  # `--dry-run=client`'s own --help text says it "will not attempt cluster
  # connections" -- confirmed FALSE for both pinned Helm versions this
  # repo's CI matrix uses (3.10.3 and 3.21.4; only this dev machine's own
  # Helm 4.2.4 actually honors it). `helm install` (even dry-run) on those
  # 3.x versions genuinely needs: (1) a live IsReachable() handshake
  # against /version, then (2) real REST discovery (/api, /apis, and a
  # full per-GVK resource list) to resource-map every kind the chart
  # renders, then (3) --disable-openapi-validation only skips the
  # protobuf-encoded OpenAPI schema fetch, not (1) or (2). Building a fake
  # control plane that correctly answers all of that (and keeping it in
  # sync with every Kind this chart ever adds) is a real, ongoing cost
  # this smoke check — which only verifies post-install messaging text,
  # never anything that affects what actually gets deployed — doesn't
  # justify paying. So: probe once, cheaply, whether this specific Helm
  # binary's dry-run is genuinely offline; skip (not fail) if it isn't.
  local probe
  probe="$(KUBECONFIG=/dev/null helm install ci-notes-probe deployment -f ci/scenarios/deployment/minimal.yaml --dry-run=client 2>&1 || true)"
  if grep -qE "cluster unreachable|could not get server version|unable to build kubernetes objects" <<< "$probe"; then
    echo "SKIP: this Helm binary's --dry-run=client still requires live cluster reachability (see this function's own comment) — notes assertions not run"
    return 0
  fi

  local out
  out="$(helm install ci-deployment-notes deployment -f ci/scenarios/deployment/aws-full.yaml --dry-run=client --render-subchart-notes)"
  grep -q "^  http://hostname.example/$" <<< "$out" \
    || { echo "FAIL: deployment NOTES.txt did not render the expected http:// URL"; echo "$out"; exit 1; }

  out="$(helm install ci-datacenter-notes deployment -f ci/scenarios/deployment/datacenter-full.yaml --dry-run=client --render-subchart-notes)"
  grep -q "^  https://hostname.example/$" <<< "$out" \
    || { echo "FAIL: deployment NOTES.txt did not render https:// for a tls-enabled ingress"; echo "$out"; exit 1; }

  out="$(helm install ci-statefulset-notes statefulset -f ci/scenarios/statefulset/aws-full.yaml --dry-run=client --render-subchart-notes)"
  grep -q "ci-statefulset-notes-0 8080:80" <<< "$out" \
    || { echo "FAIL: statefulset NOTES.txt missing its ordinal-pod port-forward example"; echo "$out"; exit 1; }
}

cmd_destination_guard() {
  echo "== destination-guard =="
  # helm-unittest's `failedTemplate` assertion can't catch this: schema
  # validation happens before template rendering even starts, so an
  # invalid `global.destination` crashes the whole unittest run rather
  # than producing an assertable per-test failure. Shell-level check
  # instead, same fallback shape as the NOTES.txt check above.
  for chart in deployment statefulset; do
    if helm template "ci-$chart" "$chart" --set global.destination=azure > /dev/null 2>/tmp/destination-guard.err; then
      echo "FAIL: $chart accepted global.destination=azure — the schema should have rejected it"
      exit 1
    fi
    grep -q "value must be one of 'aws', 'gcp', 'hcp', 'datacenter'" /tmp/destination-guard.err \
      || { echo "FAIL: $chart rejected the bad destination for the wrong reason:"; cat /tmp/destination-guard.err; exit 1; }
  done
  rm -f /tmp/destination-guard.err
}

cmd_exec_probe_guard() {
  echo "== exec-probe-guard =="
  # Regression check for bug B9. Not expressible as a helm-unittest case:
  # both its set: and values: deep-merge into the suite's base fixture
  # the same way Helm's own -f layering does, and there is no way to
  # truly clear a nested key (like liveness.httpGet) that an earlier
  # layer already populated without collapsing the parent map to nil.
  # Uses a dedicated fixture with no httpGet key from the start instead.
  local out
  out="$(helm template ci-exec-probe deployment -f ci/scenarios/deployment/exec-probe.yaml -s templates/ingress.yaml)" \
    || { echo "FAIL: exec-probe liveness nil-pointered the ingress.yaml render (regression of B9)"; exit 1; }
  # Since Phase 4's merge-based annotation consolidation, a null-valued
  # annotation (no httpGet path, no explicit override) is dropped from the
  # map entirely rather than rendered as `key: ` (empty) -- a real fix, not
  # a regression: a null value is not valid in a Kubernetes `map[string]string`
  # annotations block, so the old empty-string rendering was itself
  # borderline-invalid. Assert the key is absent, not merely empty.
  grep -q 'alb.ingress.kubernetes.io/healthcheck-path' <<< "$out" \
    && { echo "FAIL: expected no healthcheck-path annotation at all for a non-httpGet probe with no override"; echo "$out"; exit 1; }
  true
}

cmd_package_check() {
  echo "== package-check =="
  local pkgs=("$@")
  if [ "${#pkgs[@]}" -eq 0 ]; then
    mkdir -p "$DIST_DIR/pkg"
    pkgs=(
      "$(helm package deployment -d "$DIST_DIR/pkg" | awk '{print $NF}')"
      "$(helm package statefulset -d "$DIST_DIR/pkg" | awk '{print $NF}')"
    )
  fi
  for pkg in "${pkgs[@]}"; do
    echo "-- checking $pkg --"

    # Captured once into a variable, not piped live into each check below.
    # `grep -q`/`-l` exit the instant they find a match, closing their end
    # of the pipe -- if `tar -tzf` (dozens of entries once a subchart is
    # vendored) is still writing when that happens, it gets SIGPIPEd and
    # exits 141. Under this script's own `set -o pipefail`, that 141
    # becomes the pipeline's reported exit status regardless of grep's
    # own (correct) result, which either manufactures a false FAIL (the
    # `... || FAIL` shape below) or silently swallows a real one (a bare
    # `if pipeline; then FAIL; fi` shape) — confirmed for real: this
    # exact pattern passed every local/dev-machine check (small pipe
    # writes never blocked long enough to matter) but reproducibly failed
    # in CI's real environment. A here-string has no live writer process
    # to SIGPIPE, so grep's own exit code is always what actually reaches
    # the check.
    local listing
    listing="$(tar -tzf "$pkg")"

    # 1. No fixtures shipped — anywhere in the tree, including subcharts.
    if grep -E '(^|/)(tests|ci|hack|\.github)/|_test\.yaml$' <<< "$listing"; then
      echo "FAIL: $pkg contains test fixtures (check .helmignore in the offending chart)"
      exit 1
    fi

    # 2. Subcharts actually vendored.
    local need=""
    case "$pkg" in
      *deployment*)  need="charts-common/" ;;
      *statefulset*) need="charts-common/" ;;
    esac
    for d in $need; do
      grep -q "/charts/${d}" <<< "$listing" \
        || { echo "FAIL: $pkg is missing vendored subchart $d"; exit 1; }
    done

    # 3. No nested stale tarball smuggled in.
    if grep -qE '\.tgz$' <<< "$listing"; then
      echo "FAIL: $pkg contains a nested .tgz"
      exit 1
    fi

    # 4. The packaged artifact must render identically to the source tree
    #    for every scenario — the only check that catches an over-broad
    #    .helmignore pattern silently dropping a template.
    local chart
    chart="$(basename "$pkg" | sed -E 's/^charts-(deployment|statefulset)-.*/\1/')"
    for f in ci/scenarios/"$chart"/*.yaml; do
      [ -e "$f" ] || continue
      for kv in $KUBE_VERSIONS; do
        diff -u \
          <(helm template "ci-$chart" "$chart" -f "$f" --namespace ci --kube-version "$kv") \
          <(helm template "ci-$chart" "$pkg"   -f "$f" --namespace ci --kube-version "$kv") \
          || { echo "FAIL: packaged $pkg renders differently from source ($f @ $kv)"; exit 1; }
      done
    done
  done
}

cmd_all() {
  cmd_deps
  cmd_lint
  cmd_unittest
  cmd_render
  cmd_kubeconform
  cmd_notes
  cmd_destination_guard
  cmd_exec_probe_guard
  cmd_package_check
}

case "${1:-}" in
  deps)           cmd_deps ;;
  lint)           cmd_lint ;;
  unittest)       cmd_unittest ;;
  render)         cmd_render ;;
  kubeconform)    cmd_kubeconform ;;
  notes)          cmd_notes ;;
  destination-guard) cmd_destination_guard ;;
  exec-probe-guard)  cmd_exec_probe_guard ;;
  package-check)  shift; cmd_package_check "$@" ;;
  all)            cmd_all ;;
  *)
    echo "usage: $0 <deps|lint|unittest|render|kubeconform|notes|package-check|all>" >&2
    exit 2
    ;;
esac
