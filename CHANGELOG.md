# Changelog

## [2.5.0]

### Added

- **`global.networkPolicy` — NetworkPolicy**, for both the deployment and
  statefulset umbrellas (shared `charts-common.networkPolicy` define). Opt-in
  (`enabled: false` by default): every existing values file renders
  byte-for-byte as before.
  - Selects the release's own `selectorLabels`, so it works unchanged for a
    Deployment, a StatefulSet and an Argo Rollout.
  - `ingress` / `egress` are plain `networking.k8s.io/v1` rule lists passed
    through verbatim (`ipBlock`, `namespaceSelector`, `podSelector`, ports; numeric
    ports are the portable choice, named ports depend on the CNI). A direction
    is controlled only when its key is set; `ingress: []` is a real value meaning
    "allow nothing in". Enabling with neither key set fails at render time, naming
    the keys.
  - Schema-validated in both `values.schema.json` files. See README's new
    "NetworkPolicy" section, including that the object is only enforced when the
    cluster's CNI enforces NetworkPolicy (EKS: VPC CNI network policy enabled).

### Changed

- **`global.deployment.ndots` now defaults to `5`** (Kubernetes' own default) and
  is rendered explicitly as pod `dnsConfig`, instead of being omitted when unset.
  Override it from your values with any integer (`global.deployment.ndots: 2`
  lowers it, a higher number raises it, `0` is valid); set it to `null` to omit
  `dnsConfig` again. **Upgrade note:** the explicit default changes the pod
  template of every workload (Deployment, StatefulSet, Rollout, cronjobs and
  hook jobs), so the first `helm upgrade` to this chart version rolls every
  workload once. DNS behaviour is unchanged (5 is what pods already used).

### Fixed

- **`global.deployment.ndots: 0` was silently dropped.** The pod `dnsConfig`
  was gated on a truthiness check, and `0` is falsy in Go templates, so a
  workload that asked for `ndots: 0` rendered no `dnsConfig` at all. It is now
  rendered (new `charts-common.hasNdots` helper, used by the pod spec, cronjobs,
  and pre/post hook jobs). Any integer, including values above 5, is honoured.

## [2.4.1]

### Fixed

Two edge cases in `global.deployment.extraVolumes` / `extraVolumeMounts` (2.4.0),
found reviewing it after release. Both only turn a silent misconfiguration into
a clear render-time error; valid configurations render exactly as in 2.4.0.

- **A mount of a chart-managed volume that is not enabled now fails at render
  time.** `storage` needs `pvc.enabled`, `app-config` needs `configMap.enabled`,
  `gcpsecrets` needs secrets on gcp. In 2.4.0 the mount passed validation and
  rendered for a volume the pod does not have, so the API server rejected the
  whole rollout. The error names the setting to turn on.
- **The statefulset umbrella now rejects the keys instead of silently ignoring
  them.** In 2.4.0 setting `extraVolumes` / `extraVolumeMounts` on the statefulset
  chart rendered nothing, which looks exactly like a working config that did
  nothing. It now fails with a message pointing at the deployment chart (same
  precedent as the Argo Rollout guard). Empty lists, the default, are unaffected.

## [2.4.0]

### Added

- **`global.deployment.extraVolumes` / `extraVolumeMounts` — raw pod volumes**
  for the Deployment and Argo Rollout pod template (shared
  `charts-common.podTemplateSpec`). Opt-in (`[]` by default): every existing
  values file renders byte-for-byte as before.
  - Plain core/v1 `Volume` / `VolumeMount` lists, appended after the
    chart-managed volumes (`app-config`, `storage`, `gcpsecrets`), so existing
    order is unchanged. Typical use: a size-limited `emptyDir` for the
    writable paths of a container running with `readOnlyRootFilesystem: true`.
  - Render-time validation (`charts-common.validateExtraVolumes`): every
    volume needs a unique `name` that does not reuse a chart-managed name;
    every mount needs `name` + `mountPath` and must refer to an extra volume or
    a chart-managed one. Failures name the offending key.
  - Schema-validated in `deployment/values.schema.json`. The statefulset
    umbrella (which has its own pod template and mandatory PVC) is unchanged.
    See README's new "Extra pod volumes" section.

## [2.3.0]

### Added

- **`global.pdb` — PodDisruptionBudget**, for both the deployment and
  statefulset umbrellas (shared `charts-common.pdb` define). Opt-in
  (`enabled: false` by default): every existing values file renders
  byte-for-byte as before.
  - `minAvailable` **or** `maxUnavailable` (exactly one — both-set and
    neither-set `fail()` at render time naming the keys), each an integer or
    a percentage string; `0` is a real value, not "unset".
  - Optional `unhealthyPodEvictionPolicy` (`IfHealthyBudget` | `AlwaysAllow`),
    emitted only when set, since the field doesn't exist before Kubernetes
    1.26.
  - Selects the release's own `selectorLabels`, so it works unchanged for a
    Deployment, a StatefulSet and an Argo Rollout.
  - Schema-validated in both `values.schema.json` files (percentage pattern,
    policy enum). See README's new "PodDisruptionBudget" section, including
    the `minAvailable == replicas` drain-blocking footgun.

## [2.2.0]

### Added

- **`destination: azure` (AKS).** New fifth destination, additive-only —
  every existing values file's render is byte-for-byte unchanged.
  - **L7 (`global.ingress`)**: targets **Application Gateway for
    Containers (AGC)** via the Kubernetes Ingress API — Microsoft's
    current recommendation, the successor to the older AGIC. New
    `ingressClassName: azure-alb-external` (hardcoded, same pattern as
    aws/hcp), new `global.ingress[]` fields `albId`/`albName`/
    `albNamespace`/`albFrontend` to bind to a managed or bring-your-own
    AGC frontend, `tls` support (same shared block gcp/datacenter already
    use), and a real HTTP→HTTPS redirect (`sslRedirect`, default `true`,
    same key as aws) — implemented as an `IngressExtension` CRD +
    second port-80 Ingress, since AGC's Ingress API has no
    single-annotation redirect the way aws-load-balancer-controller does.
    `scheme: internal` and `wafId` are hard `fail()`s (AGC's Ingress API
    supports neither a private frontend nor WAF) rather than silent
    no-ops, since silently exposing a WAF-less public endpoint where the
    author asked for internal-only/WAF-protected would be a real,
    invisible security regression. See README's new "Azure (AKS)"
    section for the full prerequisite list, the ignored-vs-rejected key
    table, and the one thing this template-only test suite cannot prove
    (a real AGC frontend routing traffic end-to-end) — verify that once
    against a real AKS cluster before relying on it in production.
  - **L4 (`global.service`, `type: LoadBalancer`)**: the plain **Azure
    Load Balancer** (AKS's own cloud-provider integration, no separate
    controller to install) — new `service.beta.kubernetes.io/
    azure-load-balancer-health-probe-interval`/`-num-of-probe`
    annotations derived from `global.deployment.liveness`, clamped to
    Azure Load Balancer's own hard minimums (interval >= 5s, probe count
    >= 2) so a liveness probe tuned for aws/http semantics can't silently
    produce a manifest Azure would reject. `internet-facing` by default,
    same as aws; opt into an internal Azure Load Balancer via the
    standard `service.beta.kubernetes.io/azure-load-balancer-internal:
    "true"` user annotation (user still wins on any collision, same
    precedence aws/gcp/hcp/datacenter already have).
  - **Not included in this release, planned as a separate phase**: Azure
    Key Vault (Secrets Store CSI) as the azure counterpart to gcp's
    Secret Manager integration (`global.secrets`).

### Fixed (found while building the above)

- **A single `global.ingress[]` entry with an HTTP→HTTPS redirect pair
  produced invalid YAML** on azure specifically — a leading trim-dash on
  the redirect's `{{ if ... }}` tag ate the newline right after the
  literal `---` document separator that always follows an Ingress's
  `rules:` block, gluing `---` directly onto the redirect content's first
  line (`---apiVersion: alb.networking.azure.io/v1`). Caught by `helm
  lint` (`invalid Yaml document separator: ...`) before this ever shipped
  — fixed by moving the trim to the tag's trailing side instead, which
  correctly preserves the separator's own newline while still trimming
  the (now newline-free, since the include itself doesn't add one)
  whitespace between the `if` and its first action.

## [2.1.1]

### Fixed

- **Multiple `hosts` in a single `global.ingress[]` entry produced
  invalid YAML.** A stray trailing trim-dash on the hosts `range` tag in
  `charts-common.ingress.rules` swallowed the newline between consecutive
  host entries, concatenating them (e.g. `number: 80- host: ...`) into a
  render that failed to even parse. This only affected multiple *hosts*
  under one ingress entry — multiple *paths* under a single host was
  never affected, and was always the supported way to give one ALB/
  Ingress object several host+paths rules (each `global.ingress[]` entry
  is one Ingress object; each entry's `hosts` list can carry any number
  of `{host, paths}` pairs onto that same object, exactly like a native
  Kubernetes Ingress's own `spec.rules`). Fixed to match the working
  pattern `paths` already used, with an index-gated separator so the
  first host in a list still renders without a spurious leading blank
  line. See `ingress_aws_test.yaml`'s new regression test in both
  charts for the exact repro.

## [2.1.0]

### Added

- **`global.posthooks`** — post-install/post-upgrade hook Jobs, the
  counterpart to `global.prehooks`. Unlike `prehooks` (a fixed
  `dbMigrations`/`otherPrehooks` pair), this is a list — same shape as
  `global.cronjobs` — since there's no single canonical "the one
  post-deploy job" (smoke test, cache warmup, Slack notify, ...). Each
  entry supports `name`, `enabled`, `command`, `args`, an optional
  `weight` (string, default `"0"`, for ordering multiple posthooks
  relative to each other), an optional per-entry `resources` (falls back
  to `global.deployment.resources`), and an optional `backoffLimit`.
  Additive-only: `global.posthooks` defaults to `[]`, so an existing
  values file's render is byte-for-byte unchanged. See the README's
  "Post-deployment hooks" section for the important `--wait`/`--atomic`
  caveat — Helm does not wait for the Deployment/StatefulSet to actually
  be Ready before running a post-install/post-upgrade hook unless the
  calling `helm upgrade`/`helm install` invocation itself passes that
  flag.

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
