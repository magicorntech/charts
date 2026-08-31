{{/*
Call with a dict: {root: $, targetKind: "Deployment"}. targetKind is a
parameter (not hardcoded) — statefulset always passes "Deployment"
explicitly, even though it has no HPA-compatible workload at all (a
deliberate, pre-existing choice — autoscaling a StatefulSet via this
chart was never a supported combination — see the statefulset test
suite's own "DELIBERATE" case); deployment passes "Rollout" instead of
"Deployment" once global.rollout.enabled is true (P7), since Argo
Rollouts' own scaleTargetRef needs a different apiVersion, computed here
from targetKind rather than threaded as a 4th dict field.
*/}}
{{- define "charts-common.hpa" -}}
{{- $root := .root -}}
{{- if $root.Values.global.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "charts-common.name" $root }}
  namespace: "{{ $root.Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" $root | nindent 4 }}
spec:
  scaleTargetRef:
    {{- if eq .targetKind "Rollout" }}
    apiVersion: argoproj.io/v1alpha1
    {{- else }}
    apiVersion: apps/v1
    {{- end }}
    kind: {{ .targetKind }}
    name: {{ include "charts-common.name" $root }}
  minReplicas: {{ $root.Values.global.autoscaling.minReplicas }}
  maxReplicas: {{ $root.Values.global.autoscaling.maxReplicas }}
  {{- if or $root.Values.global.autoscaling.targetCPUUtilizationPercentage $root.Values.global.autoscaling.targetMemoryUtilizationPercentage }}
  metrics:
    {{- if $root.Values.global.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $root.Values.global.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $root.Values.global.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $root.Values.global.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
  {{- end }}
  {{- if $root.Values.global.autoscaling.behavior }}
  behavior:
    {{- toYaml $root.Values.global.autoscaling.behavior | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
