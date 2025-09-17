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

| Chart | Type | Description | Use Case |
|-------|------|-------------|----------|
| `deployment` | Umbrella | Combines common + deployment workload | Deploy stateless applications |
| `statefulset` | Umbrella | Combines common + statefulset workload | Deploy stateful applications |
| `common` | Application | Shared templates (Service, Ingress, etc.) | Used as subchart by umbrella charts |
| `common-deployment` | Application | Kubernetes Deployment workload | Used as subchart by deployment umbrella |
| `common-statefulset` | Application | Kubernetes StatefulSet workload | Used as subchart by statefulset umbrella |

### Chart Architecture

This repository follows Helm best practices with an **umbrella chart structure**:

- **Umbrella Charts**: `deployment` and `statefulset` are umbrella charts that combine multiple subcharts
- **Shared Resources**: `common` chart contains shared templates (Service, Ingress, etc.)
- **Workload Charts**: `common-deployment` and `common-statefulset` contain workload-specific templates
- **Global Values**: Shared configuration using the `global:` key flows to all subcharts
- **No Code Duplication**: Service and ingress templates exist only in the `common` chart

> **Note:** These charts are not recommended for other cloud platforms unless you plan to manage them as datacenter deployments.

## Compatibility

- **Kubernetes:** v1.25+
- **Helm:** v3.10+

## Chart Components

Both charts are organized into ten (10) distinct configuration groups for simplicity and modularity:

| Component | Description | Required |
|-----------|-------------|----------|
| `deployment` | Core application deployment configuration | ✅ Required |
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
- **Stable Network Identity**: Predictable hostnames and network identity
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
  --version 1.1.0
```

#### StatefulSet Chart (Stateful Applications)

```bash
# Deploy stateful applications (databases, message queues)
# Note: PVC configuration is MANDATORY for StatefulSets
helm upgrade --install --create-namespace \
  $APP_NAME oci://public.ecr.aws/magicorn/charts-statefulset \
  -f values-example.yaml \
  -n $APP_NAME-$ENVIRONMENT \
  --version 1.1.0
```

## Configuration

### Global Values Structure

All charts use a consistent global values structure with the following key sections:
- `global.destination`: Target platform (aws, gcp, hcp, datacenter)
- `global.deployment`: Application configuration (image, resources, health checks)
- `global.service`: Service configuration (ports, type, annotations)
- `global.ingress`: Ingress configuration (hosts, TLS, load balancer settings)
- `global.pvc`: Persistent volume configuration (different for Deployment vs StatefulSet)
- `global.security`: Security settings (RBAC, pod security, service accounts)
- `global.secrets`: Secret management (GCP Secret Manager integration)
- `global.autoscaling`: Horizontal Pod Autoscaler configuration
- `global.cronjobs`: Scheduled job configurations

### Chart-Specific Configuration

#### Deployment Chart (Umbrella)
- **File**: `deployment/values-example.yaml`
- **Use Case**: Stateless applications, web services, APIs
- **PVC**: Optional (shared storage with ReadWriteMany)
- **Dependencies**: `charts-common@0.0.1` + `charts-common-deployment@0.0.1`
- **Renders**: Service + Ingress + Deployment + optional resources

#### StatefulSet Chart (Umbrella)
- **File**: `statefulset/values-example.yaml`
- **Use Case**: Stateful applications, databases, message queues
- **PVC**: **MANDATORY** (per-pod storage with ReadWriteOnce)
- **Dependencies**: `charts-common@0.0.1` + `charts-common-statefulset@0.0.1`
- **Renders**: Service + Ingress + StatefulSet + VolumeClaimTemplates + optional resources

### Value Inheritance

Charts use the following value resolution order:
1. **Global values** (`global:` key) - shared across all charts
2. **Chart-specific values** - override global values for specific charts
3. **Command-line overrides** (`--set` flags) - highest priority

### Key Differences

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| **Pod Management** | Random pod names (app-xyz123) | Ordered pod names (app-0, app-1, app-2) |
| **Storage** | Shared PVC (optional, ReadWriteMany) | Individual PVCs (**mandatory**, ReadWriteOnce) |
| **Network** | Random pod IPs | Stable network identity with headless service |
| **Updates** | Rolling update with surge | Ordered rolling updates (no surge) |
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