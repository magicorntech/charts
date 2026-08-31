# Changelog

This is a single consolidated entry for the `2.0.0` release — everything
accumulated in the `next` branch since `1.1.1`, released together rather
than as a series of smaller version bumps (see the project plan this
branch worked from). Every diverged `0.x`/`1.1.x` branch's own changes
were individually analyzed and, where they carried a real fix or feature
not already on `master`, forward-ported here; see each item below for
where it came from.

## [2.0.0]

### Breaking changes

- **`global.destination` is now schema-validated.** An unset or
  misspelled value (anything other than `aws`, `gcp`, `hcp`,
  `datacenter`) is rejected immediately with a clear error, both via
  `values.schema.json` and a second, independent template-level check.
  Previously this failed deep inside the ingress/service template logic
  with an opaque Go template error instead.
- **`helm.sh/chart` and `k8s.magicorn.net/chart-version` label values
  changed.** Since `common`/`common-deployment`/`common-statefulset`
  no longer exist as separate charts (see Architecture below), every
  object in a release now shows one consistent value
  (`charts-deployment-2.0.0` / `charts-statefulset-2.0.0`) instead of
  three different ones depending on which subchart rendered it
  (`charts-common-X.Y.Z`, `charts-common-deployment-X.Y.Z`,
  `charts-common-statefulset-X.Y.Z`). This is a label-only change — it
  does not touch `spec.selector`/`spec.template.metadata.labels`, so it
  does not trigger a rollout on upgrade.
- **`NOTES.txt` now actually renders after `helm install`/`upgrade`.**
  It previously lived in a subchart, and Helm does not show subchart
  notes by default — so every install has been silently missing its
  post-install message (the application URL, port-forward instructions)
  until now.
- **Empty Service `annotations:` now renders as `{}`** instead of a
  bare, invalid trailing colon (aws + `type: LoadBalancer` with no
  annotations at all) or an omitted key. Semantically a no-op — Kubernetes
  treats both as "no annotations" — but the exact bytes changed.
- **AWS NLB and Huawei HCP annotation key ordering (and quoting style)
  changed.** A side effect of routing them through `toYaml` instead of
  hand-written YAML text (which is also what makes user-supplied
  annotations correctly override or be overridden by the platform's own,
  depending on object type — see Fixed below). Purely cosmetic — the
  same keys, the same values, just alphabetized and consistently quoted.
- **A `healthcheck-path` ALB ingress annotation with no value (no
  `httpGet` liveness probe configured, no explicit override) is now
  omitted from the rendered manifest entirely**, instead of being present
  with an empty string. An empty-valued key in a Kubernetes
  `map[string]string` annotations block was never actually valid to
  begin with.
- **StatefulSet chart: a new headless Service (`<release>-headless`) is
  now always created** whenever `global.service.ports` is non-empty
  (independent of `global.service.enabled`). This is additive — it does
  not replace or change the existing Service — but it is a genuinely new
  object in every StatefulSet release from now on. It backs the
  StatefulSet's own `spec.serviceName`, which has pointed at this exact
  name since this chart's very first StatefulSet support but never had a
  real object behind it (see Fixed below).

### Fixed

- A `service-aws.yaml`-style Service with `type: LoadBalancer` and no
  user annotations produced invalid YAML (a bare `annotations: {}`
  spliced incorrectly). Fixed structurally as part of the Service
  consolidation above.
- `cronjobs[].command` was joined into a single string instead of a real
  YAML list, unlike `args` and the equivalent field on prehook Jobs.
- `topologySpreadConstraints` with more than one entry only applied the
  auto-generated `labelSelector` to the *last* entry, leaving earlier
  ones without one.
- An empty `serviceAccountName` rendered as a blank value instead of
  omitting the key.
- An HPA with neither a CPU nor a memory target rendered an invalid,
  empty `metrics:` key, which the Kubernetes API server rejects.
- Empty RBAC `rules` rendered as `rules: null` instead of `rules: []`.
- A liveness probe without `httpGet` (e.g. an `exec`-based probe) crashed
  ingress rendering with a nil-pointer error, since the AWS ALB
  healthcheck-path annotation dereferenced `.httpGet.path` unconditionally.
- Several nullable fields (`ingress[].className`, `ingress[].wafId`, and
  others) were missing `| quote`, in some cases producing an invalid
  `""` from a literal `null` value instead of omitting the key.
- The two pre-install/pre-upgrade prehook Jobs' container name was the
  literal chart name (`charts-common`) rather than the release name.
- Dead `semverCompare ">=1.18-0"`/`">=1.19-0"` ingress branches — targeting
  Kubernetes versions well below this chart's own documented 1.25+
  floor — removed. One of them (`$_ := set $ingress.annotations ...`)
  could panic on a nil annotations map.
- **User-supplied Service annotations now reliably win over the
  platform's own (AWS NLB) annotations on a colliding key** — previously
  a raw-text splice, which crashed on any actual collision rather than
  applying a real precedence rule.

### Added

All of the following are **opt-in and off by default** — an existing
values file needs no changes to keep rendering exactly as before.

- **Argo Rollouts support** (`global.rollout.*`, **deployment chart
  only**) — canary or blueGreen strategy, forward-ported from an earlier
  branch's Argo integration with three real bugs fixed along the way:
  a missing mutual-exclusion guard against a plain Deployment being
  rendered at the same time; an ALB traffic-routing target name that
  was hardcoded to the bare release name and so silently failed to find
  its target Ingress whenever more than one `global.ingress[]` entry was
  configured; and no equivalent on the StatefulSet chart, which now
  fails loudly (rather than silently doing nothing) if
  `global.rollout.enabled` is set there.
- **`global.deployment.ndots`** — optional pod `dnsConfig` ndots
  override, unifying two independent, competing implementations from
  earlier branches into one flat contract.
- **`global.k8sSecrets.{common,service}`** — plain Kubernetes Secret
  environment-variable injection (separate from, and compatible with,
  the existing GCP Secret Manager CSI integration).
- **`global.ingress[].listenPorts`** (`http`/`https`/`both`) — narrows
  the ALB listener ports away from the default HTTP+HTTPS pair.
- **`global.ingress[].sslRedirect`** — opts an ALB ingress entry out of
  the HTTP→HTTPS redirect annotation (default stays "on", matching
  today's behavior).
- **`global.configMap.useSubPath`** — opts a configMap volume mount out
  of `subPath`, enabling live config hot-reload without a pod restart.
- **`global.nameOverride` / `global.fullnameOverride`** — override the
  computed object name (plain `.Release.Name` by default).
- **`global.ingress[].name`** — override the deliberate,
  position-and-length-based Ingress naming scheme (see Values Contract
  in the README) for a specific entry.
- **`global.ingress[].servicePortName`** — choose which
  `global.service.ports` entry an ingress rule's backend targets
  (defaults to `one`, matching every ingress entry's existing hardcoded
  behavior).
- **`global.security.serviceAccount.clusterRoleName`** — override the
  ClusterRole/ClusterRoleBinding name when `clusterWideAccess` is on, so
  two releases sharing a release name in different namespaces don't
  collide on the same cluster-scoped object.
- **`global.deployment.dnsPolicy` / `schedulerName` /
  `podManagementPolicy` / `updateStrategyPartition`** — pod-spec-level
  overrides for values that were previously hardcoded literals
  (`podManagementPolicy`/`updateStrategyPartition` apply to the
  StatefulSet chart only).
- **`global.pvc.accessModes`** is now configurable on the StatefulSet
  chart too (previously hardcoded to `ReadWriteOnce`; the Deployment
  chart already had this).

### Architecture

- **`common` is now a real Helm library chart** (`type: library`).
  `common-deployment` and `common-statefulset` no longer exist —
  `deployment` and `statefulset` each own their own `templates/`
  directly (usually a one-line `include` per object), with a single
  shared dependency, `charts-common@1.0.0`. See the README's "Chart
  Architecture" section for why this specific shape (a library chart,
  not a plain shared subchart) was necessary.

### Testing & CI

- A full `helm-unittest` matrix (227 tests across both charts) covering
  every template target and every documented bugfix/feature above as a
  permanent regression test.
- `kubeconform` schema validation (with vendored CRD schemas for
  `SecurityGroupPolicy` and `SecretProviderClass`) across two Kubernetes
  versions.
- GitHub Actions CI (`.github/workflows/ci.yml`) running the full gate
  across a Helm 3.10 / 3.21 / 4.2 matrix, plus a release-preflight
  workflow (`.github/workflows/release-preflight.yml`) that rejects
  re-publishing an already-published version (ECR Public OCI tags are
  mutable).
- `ci/version-guard.sh` (keeps the 5 copies of the chart version in
  sync) and `hack/bump-version.sh` (writes all 5 at once).

### Deprecated

- **The `0.x` line is retired as of this release.** No further `0.x`
  tags will be cut, and the various diverged `0.5.x`/`0.6.x`/`0.7.x`
  branches are closed — everything from them worth keeping has been
  forward-ported into this release (see Added/Fixed above). New
  deployments and upgrades should target `2.0.0`.

### Upgrading from 1.x

- No values file changes are required — every new key defaults to
  reproducing today's exact behavior.
- Expect a one-time, harmless diff on `helm.sh/chart` /
  `k8s.magicorn.net/chart-version` label values on your next `helm
  upgrade` (see Breaking changes above) — this does not trigger a
  rollout.
- If you're on the StatefulSet chart: expect a new headless Service
  object to appear (additive, does not replace your existing Service).
- If you were relying on `NOTES.txt` never appearing (unlikely, but
  possible if you're scripting around `helm upgrade`'s output), it now
  does.
