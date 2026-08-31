# Magicorn Helm Charts

A comprehensive collection of Helm charts for deploying generic service applications on Kubernetes platforms.

## ⚠️ Important Notice

**Please read the configuration documentation carefully before deployment:**
- Review `values-example.yaml` files in each chart directory for configuration examples
- See the configuration section below for detailed explanations

## Overview

This repository contains versatile Helm charts designed to package generic service applications for private Kubernetes platforms. The charts have been thoroughly tested and optimized for:

- **AWS Elastic Kubernetes Service (EKS)** with AWS Application Load Balancer Ingress Controller
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
  --version 1.2.0
```

#### StatefulSet Chart (Stateful Applications)

```bash
# Deploy stateful applications (databases, message queues)
# Note: PVC configuration is MANDATORY for StatefulSets
helm upgrade --install --create-namespace \
  $APP_NAME oci://public.ecr.aws/magicorn/charts-statefulset \
  -f values-example.yaml \
  -n $APP_NAME-$ENVIRONMENT \
  --version 1.2.0
```

## Configuration

### Global Values Structure

All charts use a consistent global values structure with the following key sections:
- `global.destination`: Target platform (aws, gcp, hcp, datacenter) — schema-validated, see Values Contract below
- `global.deployment`: Application configuration (image, resources, health checks, `enabled` toggle, DNS/scheduling overrides)
- `global.rollout`: Argo Rollouts canary/blueGreen — **`deployment` chart only**, off by default, mutually exclusive with `global.deployment.enabled`
- `global.service`: Service configuration (ports, type, annotations)
- `global.ingress`: Ingress configuration (hosts, TLS, load balancer settings)
- `global.pvc`: Persistent volume configuration (different for Deployment vs StatefulSet)
- `global.security`: Security settings (RBAC, pod security, service accounts)
- `global.secrets`: Secret management (GCP Secret Manager integration)
- `global.autoscaling`: Horizontal Pod Autoscaler configuration
- `global.cronjobs`: Scheduled job configurations
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