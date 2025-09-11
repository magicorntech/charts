# Magicorn Helm Charts

A comprehensive collection of Helm charts for deploying generic service applications on Kubernetes platforms.

## ⚠️ Important Notice

**Please read `values-example.yaml` carefully before deployment.** All configuration options and their explanations are documented there.

## Overview

This repository contains versatile Helm charts designed to package generic service applications for private Kubernetes platforms. The charts have been thoroughly tested and optimized for:

- **AWS Elastic Kubernetes Service (EKS)** with AWS Application Load Balancer Ingress Controller
- **Huawei Cloud Platform** with CCE Turbo Cluster networking
- **Google Cloud Platform (GCP)** with Google Kubernetes Engine (GKE) and Secret Manager integration
- **On-premise/datacenter** deployments with TLS support

### Available Charts

| Chart | Description | Use Case |
|-------|-------------|----------|
| `deployment` | Standard Kubernetes Deployment | Stateless applications, web services, APIs |
| `statefulset` | Kubernetes StatefulSet | Stateful applications, databases, message queues |
| `common` | Library chart with shared templates | Used internally by deployment and statefulset charts |

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
# Basic installation for stateless applications
helm upgrade --install --create-namespace \
  $APP_NAME oci://public.ecr.aws/magicorn/charts-deployment \
  -f values.yaml \
  -n $APP_NAME-$ENVIRONMENT \
  --version 1.0.1
```

#### StatefulSet Chart (Stateful Applications)

```bash
# Basic installation for stateful applications
helm upgrade --install --create-namespace \
  $APP_NAME oci://public.ecr.aws/magicorn/charts-statefulset \
  -f values.yaml \
  -n $APP_NAME-$ENVIRONMENT \
  --version 1.0.1
```

## Configuration

Refer to `values-example.yaml` for comprehensive configuration examples and detailed explanations of all available options.

### Chart-Specific Configuration

#### Deployment Chart
- **File**: `deployment/values-example.yaml`
- **Use Case**: Stateless applications, web services, APIs
- **PVC**: Optional (for shared storage)

#### StatefulSet Chart  
- **File**: `statefulset/values-example.yaml`
- **Use Case**: Stateful applications, databases, message queues
- **PVC**: **Required** (each pod gets its own persistent volume)

### Key Differences

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| **Pod Management** | Random pod names | Ordered pod names (app-0, app-1, app-2) |
| **Storage** | Shared PVC (optional) | Individual PVCs (required) |
| **Network** | Random pod IPs | Stable network identity |
| **Updates** | Rolling update with surge | Ordered rolling updates |
| **Scaling** | Can scale up/down randomly | Scales in order (0→1→2, 2→1→0) |

## Chart Repository

These charts are maintained and distributed through our [AWS ECR Public Gallery](https://gallery.ecr.aws/magicorn/):

- **Deployment Chart**: `public.ecr.aws/magicorn/charts-deployment`
- **StatefulSet Chart**: `public.ecr.aws/magicorn/charts-statefulset`

## Troubleshooting

### Common Issues

#### StatefulSet Issues
- **PVC not created**: Ensure `pvc` section is configured in values.yaml (required for StatefulSet)
- **Pod stuck in Pending**: Check if storage class exists and is accessible
- **Network issues**: Verify headless service is created (service type: ClusterIP with clusterIP: None)

#### Deployment Issues  
- **Image pull errors**: Check image URI and imagePullSecrets configuration
- **Service not accessible**: Verify service ports match container ports
- **Ingress not working**: Check ingress configuration and controller availability

### Getting Help

- Check the `values-example.yaml` for configuration examples
- Review Kubernetes logs: `kubectl logs -f <pod-name> -n <namespace>`
- Verify chart installation: `helm status <release-name> -n <namespace>`

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