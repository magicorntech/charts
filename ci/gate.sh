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
  # .helmignore has just stripped tests/ out of. Naming the 5 source chart
  # dirs directly means every suite is collected from source, exactly once.
  helm unittest --with-subchart=false \
    -t JUnit -o "$DIST_DIR/reports/unittest-${helm_ver}.xml" \
    common common-deployment common-statefulset deployment statefulset
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
    # shellcheck disable=SC2086
    if ! kubeconform -verbose \
      -kubernetes-version "$kv" \
      -schema-location default \
      -schema-location 'ci/crd-schemas/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
      -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
      -output junit \
      $files > "$DIST_DIR/reports/kubeconform-$kv.xml"; then
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
  # exercises it. --render-subchart-notes is required today because
  # NOTES.txt lives in the two workload subcharts, not the umbrella
  # itself, and Helm doesn't show subchart notes by default (a real gap
  # fixed in Phase 4, not yet).
  local out
  out="$(helm install ci-deployment-notes deployment -f ci/scenarios/deployment/aws-full.yaml --dry-run=client --render-subchart-notes)"
  echo "$out" | grep -q "^  http://hostname.example/$" \
    || { echo "FAIL: deployment NOTES.txt did not render the expected http:// URL"; echo "$out"; exit 1; }

  out="$(helm install ci-datacenter-notes deployment -f ci/scenarios/deployment/datacenter-full.yaml --dry-run=client --render-subchart-notes)"
  echo "$out" | grep -q "^  https://hostname.example/$" \
    || { echo "FAIL: deployment NOTES.txt did not render https:// for a tls-enabled ingress"; echo "$out"; exit 1; }

  out="$(helm install ci-statefulset-notes statefulset -f ci/scenarios/statefulset/aws-full.yaml --dry-run=client --render-subchart-notes)"
  echo "$out" | grep -q "ci-statefulset-notes-0 8080:80" \
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

    # 1. No fixtures shipped — anywhere in the tree, including subcharts.
    if tar -tzf "$pkg" | grep -E '(^|/)(tests|ci|hack|\.github)/|_test\.yaml$'; then
      echo "FAIL: $pkg contains test fixtures (check .helmignore in the offending chart)"
      exit 1
    fi

    # 2. Subcharts actually vendored.
    local need=""
    case "$pkg" in
      *deployment*)  need="charts-common/ charts-common-deployment/" ;;
      *statefulset*) need="charts-common/ charts-common-statefulset/" ;;
    esac
    for d in $need; do
      tar -tzf "$pkg" | grep -q "/charts/${d}" \
        || { echo "FAIL: $pkg is missing vendored subchart $d"; exit 1; }
    done

    # 3. No nested stale tarball smuggled in.
    if tar -tzf "$pkg" | grep -qE '\.tgz$'; then
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
  package-check)  shift; cmd_package_check "$@" ;;
  all)            cmd_all ;;
  *)
    echo "usage: $0 <deps|lint|unittest|render|kubeconform|notes|package-check|all>" >&2
    exit 2
    ;;
esac
