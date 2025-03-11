# Charts
Magicorn Made Helm Charts

## Disclaimer
Please read values-example.yaml carefully!! All the nick-nack explained there.

This is a generic Helm deployment chart that package generic service applications for your private Kubernetes platform. Works very well with AWS Elastic Kubernetes Service and AWS Application Load Balancer Ingress Controller. Additionally it supports datacenter (on-premise) deployment model as of version 0.3.0.

This chart is not recommended to be used with other platforms, unless you would like to manage like a datacenter deployment.

Tested with EKS v1.25+ and Helm v3.10+

## Introduction
When you breakdown the chart values you'll notice;

* deployment
* service
* ingress
* scaling
* configmap
* prehooks
* cronjobs
* security

It's divided into eight (8) different value groups for simplicity. Deployment must be filled in at bare minimum in order for this chart to do it's job. All other value groups are optional.

We maintain this chart at our own [AWS ECR Gallery](https://gallery.ecr.aws/magicorn/charts-deployment):

## Usage
Below is a CI/CD oneliner example for a seamless deployment experience.
 
```
$ helm upgrade --install --create-namespace $APP_NAME oci://public.ecr.aws/magicorn/charts-deployment -f .devops/apps/values-$ENVIRONMENT.yaml -n $APP_NAME-$ENVIRONMENT --set deployment.image.uri=$IMAGE_FULLURI --version 0.4.0
```

Use at your own risk, as Magicorn we don't take responsibility.
For a little piece of mind, we only share projects that we use within our customers. You are always welcome to ask anything related about our projects, raise issues or even contribute if you'd like!

Thank you for your confidence and trust!