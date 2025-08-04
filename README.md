# Magicorn Helm Charts

A comprehensive Helm chart for deploying generic service applications on Kubernetes platforms.

## ⚠️ Important Notice

**Please read `values-example.yaml` carefully before deployment.** All configuration options and their explanations are documented there.

## Overview

This is a versatile Helm deployment chart designed to package generic service applications for private Kubernetes platforms. It has been thoroughly tested and optimized for:

- **AWS Elastic Kubernetes Service (EKS)** with AWS Application Load Balancer Ingress Controller
- **Huawei Cloud Platform** with CCE Turbo Cluster networking
- **On-premise/datacenter** deployments

### Coming Soon
- **Google Cloud Platform (GCP)** integration with Google Kubernetes Engine (GKE) support

> **Note:** This chart is not recommended for other cloud platforms unless you plan to manage them as datacenter deployments.

## Compatibility

- **Kubernetes:** v1.25+
- **Helm:** v3.10+

## Chart Components

The chart is organized into nine (9) distinct configuration groups for simplicity and modularity:

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
| `pvc` | Persistent Volume Claims | Optional |

> **Minimum requirement:** Only the `deployment` section must be configured for the chart to function.

## Installation

### Prerequisites

- Helm 3.10+ installed
- Kubernetes cluster access
- Appropriate RBAC permissions

### Quick Start

```bash
# Basic installation
helm upgrade --install --create-namespace \
  $APP_NAME oci://public.ecr.aws/magicorn/charts-deployment \
  -f values.yaml \
  -n $APP_NAME-$ENVIRONMENT \
  --version 0.6.1
```

## Configuration

Refer to `values-example.yaml` for comprehensive configuration examples and detailed explanations of all available options.

## Chart Repository

This chart is maintained and distributed through our [AWS ECR Public Gallery](https://gallery.ecr.aws/magicorn/charts-deployment).

## Support & Contributing

We welcome community involvement! Feel free to:

- Ask questions about chart usage
- Report issues or bugs  
- Submit feature requests
- Contribute improvements

## License & Disclaimer

**Use at your own risk.** Magicorn provides this chart as-is and assumes no responsibility for its usage. 

This chart represents a project actively used within our customer deployments, ensuring real-world testing and reliability.

---

Thank you for your confidence and trust in Magicorn solutions!