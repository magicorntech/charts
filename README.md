# Magicorn Helm Charts

A comprehensive collection of Helm charts for deploying generic service applications on Kubernetes platforms.

## ⚠️ Important Notice

**Please read the configuration documentation carefully before deployment:**
- Review `values-example.yaml` files in each chart directory for configuration examples
- See the configuration section below for detailed explanations

## Overview

This repository contains versatile Helm charts designed to package generic service applications for private Kubernetes platforms. The charts have been thoroughly tested and optimized for:

- **AWS Elastic Kubernetes Service (EKS)** with AWS Application Load Balancer Ingress Controller
- **Azure Kubernetes Service (AKS)** with Application Gateway for Containers (see the dedicated section below)
- **Huawei Cloud Platform** with CCE Turbo Cluster networking
- **Google Cloud Platform (GCP)** with Google Kubernetes Engine (GKE) and Secret Manager integration
- **On-premise/datacenter** deployments with TLS support

### Available Charts

Only two charts are ever installed directly — `common` is a **library
chart** (`type: library`), meaning it has no templates of its own that
render on their own; it exists purely to be depended on.

| Chart | Type | Description | Use Case |
|-------|------|-------------|----------|
| `deployment` | Umbrella | Owns its own `templates/` (Deployment/Rollout, Service, Ingress, HPA, ...), depends on `common` | Deploy stateless applications |
| `statefulset` | Umbrella | Owns its own `templates/` (StatefulSet, headless Service, Service, Ingress, HPA, ...), depends on `common` | Deploy stateful applications |
| `common` | **Library** (not installable on its own) | Every shared piece of logic (`{{- define ... }}` blocks only — Service/Ingress/RBAC/HPA/volumes/etc.), consumed by both umbrellas | Not deployed directly — a single shared dependency |

### Chart Architecture

- **Two installable charts, one shared dependency.** `deployment` and
  `statefulset` each have a real `templates/` directory of their own,
  usually just a one-line `{{- include "charts-common.X" . }}` per
  object — the actual rendering logic lives once, in `common`.
- **Why a library chart, specifically**: Helm doesn't deduplicate
  transitive dependencies, so declaring `common` as a plain `application`
  subchart of *another* subchart would render every shared object twice
  in a single release (two Services, two Ingresses, ...). A `library`
  chart has no templates of its own to accidentally render at all — it
  can only be reached through an `include`, which is exactly the shape
  this repo needs.
- **Global Values**: Shared configuration using the `global:` key flows
  from each umbrella's own `values.yaml` into every `common.*` template.
- **`.Chart.Name`/`.Chart.Version` always resolve to the umbrella**,
  never the library — a real fix from an earlier architecture where a
  single release could show two different `helm.sh/chart` label values
  depending on which subchart rendered a given object.

> **Note:** These charts are not recommended for other cloud platforms unless you plan to manage them as datacenter deployments.

## Compatibility

- **Kubernetes:** v1.25+
- **Helm:** v3.10+ required and CI-tested; Helm 4.x renders identically and is exercised in CI too, but is still treated as advisory (not yet a promise this chart makes to consumers) until it's been in the field longer.

## Chart Components

Both charts are organized into distinct configuration groups for simplicity and modularity:

| Component | Description | Required |
|-----------|-------------|----------|
| `deployment` | Core application deployment configuration | ✅ Required |
| `rollout` | Argo Rollouts (canary/blueGreen) instead of a plain Deployment — **`deployment` chart only**, mutually exclusive with `deployment.enabled` | Optional |
| `service` | Service configuration for internal/external access | Optional |
| `ingress` | Ingress controller configuration | Optional |
| `scaling` | Horizontal Pod Autoscaler settings | Optional |
| `configmap` | Configuration data management | Optional |
| `prehooks` | Pre-deployment hooks and jobs | Optional |
| `posthooks` | Post-deployment hooks and jobs (list — see note below) | Optional |
| `cronjobs` | Scheduled job configurations | Optional |
| `security` | Security policies and contexts | Optional |
| `pvc` | Persistent Volume Claims | Optional (Deployment) / ✅ Required (StatefulSet) |
| `secrets` | GCP Secret Manager integration via CSI driver | Optional |

### StatefulSet Specific Features

The StatefulSet chart includes additional features for stateful applications:

- **Volume Claim Templates**: Each pod gets its own persistent volume (REQUIRED)
- **Ordered Pod Management**: Pods are created/deleted in order (0, 1, 2, ...)
- **Stable Network Identity**: a headless Service (`<release>-headless`) backs the StatefulSet's own `spec.serviceName`, giving every pod a real, resolvable DNS name (`<pod>.<release>-headless.<namespace>.svc.cluster.local`)
- **Graceful Updates**: Rolling updates with partition control

> **Minimum requirements:** 
> - **Deployment Chart**: Only the `deployment` section must be configured
> - **StatefulSet Chart**: Both `deployment` and `pvc` sections must be configured

## Installation

### Prerequisites

- Helm 3.10+ installed
- Kubernetes cluster access
- Appropriate RBAC permissions

### Quick Start

#### Deployment Chart (Stateless Applications)

```bash
# Deploy stateless applications (web services, APIs)
helm upgrade --install --create-namespace \
  $APP_NAME oci://public.ecr.aws/magicorn/charts-deployment \
  -f values-example.yaml \
  -n $APP_NAME-$ENVIRONMENT \
  --version 2.4.0
```

#### StatefulSet Chart (Stateful Applications)

```bash
# Deploy stateful applications (databases, message queues)
# Note: PVC configuration is MANDATORY for StatefulSets
helm upgrade --install --create-namespace \
  $APP_NAME oci://public.ecr.aws/magicorn/charts-statefulset \
  -f values-example.yaml \
  -n $APP_NAME-$ENVIRONMENT \
  --version 2.4.0
```

## Configuration

### Global Values Structure

All charts use a consistent global values structure with the following key sections:
- `global.destination`: Target platform (aws, gcp, hcp, datacenter, azure) — schema-validated, see Values Contract below
- `global.deployment`: Application configuration (image, resources, health checks, `enabled` toggle, DNS/scheduling overrides)
- `global.rollout`: Argo Rollouts canary/blueGreen — **`deployment` chart only**, off by default, mutually exclusive with `global.deployment.enabled`
- `global.service`: Service configuration (ports, type, annotations)
- `global.ingress`: Ingress configuration (hosts, TLS, load balancer settings)
- `global.pvc`: Persistent volume configuration (different for Deployment vs StatefulSet)
- `global.security`: Security settings (RBAC, pod security, service accounts)
- `global.secrets`: Secret management (GCP Secret Manager integration)
- `global.autoscaling`: Horizontal Pod Autoscaler configuration
- `global.pdb`: PodDisruptionBudget — see the dedicated section below
- `global.cronjobs`: Scheduled job configurations
- `global.prehooks` / `global.posthooks`: pre/post-install,upgrade hook Jobs — see the dedicated section below for the `--wait` caveat on posthooks
- `global.k8sSecrets`: Plain Kubernetes Secret env-var injection
- `global.nameOverride` / `global.fullnameOverride`: override the computed object name (plain `.Release.Name` by default)

### Chart-Specific Configuration

#### Deployment Chart (Umbrella)
- **File**: `deployment/values-example.yaml`
- **Use Case**: Stateless applications, web services, APIs
- **PVC**: Optional (shared storage, `global.pvc.accessModes` defaults to `ReadWriteOnce` — set explicitly for `ReadWriteMany`)
- **Dependencies**: `charts-common@1.0.0` (the one shared library chart — see Chart Architecture above)
- **Renders**: Service + Ingress + Deployment (or Rollout, see `global.rollout.enabled`) + optional resources

#### StatefulSet Chart (Umbrella)
- **File**: `statefulset/values-example.yaml`
- **Use Case**: Stateful applications, databases, message queues
- **PVC**: **MANDATORY** (per-pod storage, `global.pvc.accessModes` defaults to `ReadWriteOnce`)
- **Dependencies**: `charts-common@1.0.0` (same shared library chart the deployment umbrella uses)
- **Renders**: Service + headless Service + Ingress + StatefulSet + VolumeClaimTemplates + optional resources

### Value Inheritance

Charts use the following value resolution order:
1. **Global values** (`global:` key) - shared across all charts
2. **Chart-specific values** - override global values for specific charts
3. **Command-line overrides** (`--set` flags) - highest priority

### Post-deployment hooks (`global.posthooks`)

A list of Jobs that run as `post-install,post-upgrade` Helm hooks — the
counterpart to `global.prehooks`, for work that needs to happen *after*
the release, e.g. a smoke test, cache warmup, or a Slack notification.
Unlike `prehooks` (a fixed `dbMigrations`/`otherPrehooks` pair), this is a
list, same shape as `global.cronjobs`, since there's no single canonical
"the one post-deploy job":

```yaml
global:
  posthooks:
    - name: smoke-test
      enabled: true
      command: ["/usr/local/bin/curl"]
      args: ["-f", "http://localhost:8080/healthz"]
      weight: "10"        # optional, default "0" — lower runs first
      backoffLimit: 2     # optional
      resources: {}       # optional, falls back to global.deployment.resources
```

⚠️ **Helm does not wait for your Deployment/StatefulSet to be Ready before
running a post-install/post-upgrade hook** — it runs as soon as the
release's main resources are accepted by the API server, which can be
*before* the new pods have finished rolling out. If a posthook needs to
talk to the version it's deploying (a smoke test hitting the new pods, for
example), the `helm upgrade`/`helm install` invocation itself must pass
`--wait` (or `--atomic`, which implies it) — this chart has no way to
enforce that from inside the template. Without `--wait`, treat a posthook
as running against "the release was accepted", not "the release is live."

### PodDisruptionBudget (`global.pdb`)

Off by default — nothing renders unless you opt in. Limits how many of the
release's pods voluntary disruptions (node drains, cluster upgrades,
autoscaler scale-down) may take down at once:

```yaml
global:
  pdb:
    enabled: true
    minAvailable: 1        # integer or "50%" ...
    # maxUnavailable: 25%  # ... OR this. Exactly one of the two.
    # unhealthyPodEvictionPolicy: AlwaysAllow   # IfHealthyBudget | AlwaysAllow, Kubernetes 1.26+
```

- Set **exactly one** of `minAvailable` / `maxUnavailable`; setting both, or
  enabling with neither, fails at render time with a message naming the keys.
  `0` is a valid value, not "unset".
- It selects the release's own pods (same labels as the workload), so it works
  for a Deployment, a StatefulSet and an Argo Rollout alike. Both umbrella
  charts support it.
- ⚠️ Keep `minAvailable` **below** your replica count (or
  `autoscaling.minReplicas` when autoscaling is on). With `minAvailable` equal
  to the number of replicas no pod may ever be evicted, and node drains block
  forever. A percentage or `maxUnavailable` avoids this by construction.
- A PDB only guards *voluntary* evictions; it does nothing for a node that
  dies.

### Extra pod volumes (`global.deployment.extraVolumes`)

Off by default — nothing renders unless you opt in. A raw escape hatch for
pod volumes the chart has no dedicated key for: a size-limited `emptyDir`
(writable scratch space for a container running with
`securityContext.readOnlyRootFilesystem: true`), `projected`, `hostPath`, any
other core/v1 `Volume`. Both keys are plain Kubernetes lists:

```yaml
global:
  deployment:
    extraVolumes:
    - name: package
      emptyDir:
        sizeLimit: 512Mi
    extraVolumeMounts:
    - name: package
      mountPath: /package
  security:
    securityContext:
      readOnlyRootFilesystem: true
```

- They are appended **after** the chart-managed volumes (`app-config` from
  `configMap`, `storage` from `pvc`, `gcpsecrets` from `secrets`), so existing
  volume and mount order never changes.
- Applies to the Deployment and the Argo Rollout pod template (they share one
  pod template). The statefulset umbrella does **not** support them: setting
  either key there fails at render time instead of being silently ignored.
- Validated at render time, naming the offending key: every volume needs a
  unique `name` that is not `app-config`, `storage` or `gcpsecrets`; every mount
  needs `name` and `mountPath`, and `name` must match an `extraVolumes` entry
  (or a chart-managed volume that is **enabled**, e.g. a second `subPath` of the
  PVC while `pvc.enabled` is true; mounting `storage` with `pvc` off fails).
- Mounts go to the main container only. Hooks, cronjobs and posthooks are not
  affected.
- An `emptyDir` `sizeLimit` is enforced by the kubelet, which evicts the pod
  when it is exceeded; keep it above what the app actually writes. Memory-backed
  (`medium: Memory`) volumes count against the container's memory limit.

### Azure (AKS)

`destination: azure` targets **Application Gateway for Containers (AGC)**
via the Kubernetes **Ingress API** for L7 (`global.ingress`), and the
plain **Azure Load Balancer** (AKS's own cloud-provider integration) for
L4 (`global.service`, `type: LoadBalancer`). AGC is Microsoft's current
recommendation, the successor to the older Application Gateway Ingress
Controller (AGIC) — this chart does not support AGIC.

**A plain, freshly-created AKS cluster cannot use `destination: azure`
out of the box** — same as EKS needing `aws-load-balancer-controller`
installed separately, AKS needs its own prerequisites in place first:

1. The **ALB Controller** installed on the cluster (AKS add-on, or Helm —
   see [Microsoft's quickstart](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-helm)).
2. The Application Gateway for Containers Azure resource itself —
   either **managed** (the ALB Controller provisions it for you from an
   `ApplicationLoadBalancer` custom resource — use `global.ingress[].albName`
   + `albNamespace`) or **bring-your-own** (you provision it yourself in
   Azure — use `albId` + `albFrontend`).
3. A TLS certificate as a plain **Kubernetes Secret** in-cluster
   (`global.ingress[].tls`) — AGC cannot mount a certificate from Azure
   Key Vault directly (the Secrets Store CSI driver isn't supported for
   AGC's own certificates); use [cert-manager](https://cert-manager.io/)
   with Let's Encrypt, or sync from Key Vault into a Secret yourself.

**What's deliberately not supported, and why the chart fails loudly
instead of silently ignoring it:**

| `global.ingress[]` key | On azure |
|---|---|
| `scheme: internal` | **Rejected at render time.** AGC's Ingress API has no private/internal frontend. Expose privately instead via `global.service.type: LoadBalancer` + the `service.beta.kubernetes.io/azure-load-balancer-internal: "true"` annotation (a real internal Azure Load Balancer). |
| `wafId` | **Rejected at render time.** WAF on AGC is only exposed via the Gateway API, not the Ingress API this chart uses. |
| `sslPolicy`, `idleTimeout`, `lbId`, `lbOrder`, `certificateId`, `listenPorts`, `healthcheckPath` | Silently ignored (AWS-only) — AGC's Ingress API has no equivalent knob for any of these (health probes fall back to the pod's own readiness probe; ports are fixed at 80/443). |

**HTTP → HTTPS redirect** (`sslRedirect`, default `true`, same key as
AWS): AGC has no single-annotation redirect — when `tls` is set and
`sslRedirect` isn't `false`, this chart generates two extra objects per
ingress entry: an `IngressExtension` (AGC's own CRD) carrying the redirect
rule, and a second, port-80-only `Ingress` referencing it. Both share the
main Ingress's `alb-frontend`, so they route through the same AGC
frontend/FQDN.

**Binding fields** (`global.ingress[]`):

```yaml
global:
  ingress:
    - enabled: true
      # Managed: the ALB Controller provisions the Azure resources for you.
      albName: alb-test
      albNamespace: alb-test-infra
      # ...or bring-your-own: reference an already-provisioned frontend.
      # albId: /subscriptions/xxx/resourceGroups/yyy/providers/Microsoft.ServiceNetworking/trafficControllers/zzz
      # albFrontend: frontend
      tls:
        - hosts: [hostname.example]
          secretName: hostname-tls
      hosts:
        - host: hostname.example
          paths:
            - path: /
              pathType: Prefix
```

⚠️ This chart's test suite is template-only — it cannot prove that a real
`Ingress`+`IngressExtension` pair actually redirects traffic end-to-end
against a live AGC frontend, or that the main and port-80 Ingress objects
genuinely share one frontend without conflicting. Verify this once
against a real AKS cluster before relying on it in production.

### Values Contract

The `global.*` values schema is **frozen and additive-only**: any new key
this chart ever gains defaults to reproducing the exact behavior it had
before that key existed, and no `additionalProperties: false` is set
anywhere — a values file with keys this chart doesn't (yet) recognize
keeps working, it just doesn't do anything extra with the parts it
doesn't understand. Existing values files should never need editing to
pick up a new chart version, only to opt into whatever that version adds.

Two enforced exceptions, both deliberate:

- **`global.destination` is schema-validated against a fixed enum**
  (`aws`, `gcp`, `hcp`, `datacenter`). An unrecognized value is rejected
  at render time with a clear error, both by `values.schema.json` (Helm's
  own JSON-schema validation) and by a second, independent template-level
  `fail()` check (for an older Helm without schema support, or a render
  invoked with `--skip-schema-validation`). This was already effectively
  required — an unset or misspelled destination previously failed with an
  opaque Go template error deep inside the ingress/service logic instead
  of a clear message up front.
- **Ingress object naming is deliberately based on list *position* and
  list *length*, not on which entries happen to be `enabled`.** With more
  than one `global.ingress[]` entry, the first is named `<release>-1`,
  the second `<release>-2`, and so on — disabling one entry never renames
  another. This is intentional: renaming an Ingress makes Helm delete and
  recreate it, which for an AWS ALB means provisioning a **brand new load
  balancer**, with real downtime and (depending on your DNS setup) a
  changed endpoint. Toggling `enabled` on any entry is always safe;
  reordering entries in the list is not — set `global.ingress[].name`
  explicitly if you need a name that survives a reorder.

### Key Differences

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| **Pod Management** | Random pod names (app-xyz123) | Ordered pod names (app-0, app-1, app-2) |
| **Storage** | Shared PVC (optional, default ReadWriteOnce) | Individual PVCs (**mandatory**, default ReadWriteOnce) |
| **Network** | Random pod IPs | Stable network identity with headless service |
| **Updates** | Rolling update with surge, or Argo Rollouts canary/blueGreen (`global.rollout.enabled`) | Ordered rolling updates (no surge) |
| **Scaling** | Can scale up/down randomly | Scales in order (0→1→2, 2→1→0) |
| **Use Case** | Web services, APIs, stateless apps | Databases, message queues, stateful apps |

## Chart Repository

These charts are maintained and distributed through our [AWS ECR Public Gallery](https://gallery.ecr.aws/magicorn/):

- **Deployment Chart**: `public.ecr.aws/magicorn/charts-deployment`
- **StatefulSet Chart**: `public.ecr.aws/magicorn/charts-statefulset`

## Troubleshooting

### Common Issues

#### StatefulSet Issues
- **PVC not created**: Ensure `pvc` section is configured in values-example.yaml (**MANDATORY** for StatefulSet)
- **Pod stuck in Pending**: Check if storage class exists and has sufficient capacity for per-pod PVCs
- **Network issues**: Verify headless service is created automatically for StatefulSet
- **Pods not starting in order**: Check if previous pod is ready before next pod starts

#### Deployment Issues  
- **Image pull errors**: Check image URI and imagePullSecrets configuration
- **Service not accessible**: Verify service ports match container ports
- **Ingress not working**: Check ingress configuration and controller availability
- **Templates not rendering**: Ensure you're using umbrella charts (`deployment/` or `statefulset/`), not workload charts directly

#### Objects left behind by `helm uninstall`

The ServiceAccount, Role/ClusterRole, RoleBinding, PVC, SecurityGroupPolicy,
and SecretProviderClass objects are all rendered as Helm hooks
(`pre-install,pre-upgrade`), not as ordinary tracked release resources.
This is a known, currently-unfixed limitation, not a bug you're hitting by
accident: Helm hooks are never recorded in the release's own manifest, so
`helm uninstall` leaves every one of them behind, and a subsequent
`helm install` of the same release name creates them fresh
(`before-hook-creation` is the default delete policy, so they don't pile
up release-over-release — they're just never cleaned up on uninstall).
The correct long-term fix is to stop rendering these as hooks at all, but
doing that on an *existing* release breaks its next `helm upgrade` with
`invalid ownership metadata` (Helm refuses to adopt an object it didn't
create as a tracked resource without being told to). If you hit that
error, adopt the object manually first, once, per object:

```bash
kubectl annotate --overwrite <kind> <name> -n <namespace> \
  meta.helm.sh/release-name=<release-name> \
  meta.helm.sh/release-namespace=<namespace>
kubectl label --overwrite <kind> <name> -n <namespace> \
  app.kubernetes.io/managed-by=Helm
```

### Getting Help

- Review `values-example.yaml` files in chart directories for configuration examples
- Check Kubernetes logs: `kubectl logs -f <pod-name> -n <namespace>`
- Verify chart installation: `helm status <release-name> -n <namespace>`
- Validate templates: `helm template <chart-name> --validate`

## Support & Contributing

We welcome community involvement! Feel free to:

- Ask questions about chart usage
- Report issues or bugs  
- Submit feature requests
- Contribute improvements

## License & Disclaimer

**Use at your own risk.** Magicorn provides this chart as-is and assumes no responsibility for its usage. 

These charts represent projects actively used within our customer deployments, ensuring real-world testing and reliability.

---

Thank you for your confidence and trust in Magicorn solutions!