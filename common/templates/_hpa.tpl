{{/*
Call with a dict: {root: $, targetKind: "Deployment"}. targetKind is a
parameter (not hardcoded) so a future Rollout-aware umbrella can pass
"Rollout" instead — today both umbrellas pass "Deployment" explicitly,
including the statefulset chart, which has no HPA-compatible workload at
all. That's a deliberate, pre-existing choice (autoscaling a StatefulSet
via this chart was never a supported combination), not something this
refactor changes — see the statefulset test suite's own "DELIBERATE" case.
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
    apiVersion: apps/v1
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
