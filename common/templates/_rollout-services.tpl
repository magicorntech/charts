{{/*
The extra Service objects Argo Rollouts manages on top of the main
Service (charts-common.service, unaffected by this file — see its own
"NEW: skip when blueGreen" note): a preview/canary Service for the canary
strategy (only when createCanaryService is on), or active+preview Services
for blueGreen (both always created — blueGreen has no equivalent
"off" switch, unlike canary's createCanaryService). Ported from the
0.7.5/0.7.6 branch's rollout-services.yaml, 1a68fd4's shape (canary's
Service is named `-preview`, not `-canary` — matches the Rollout's own
`canaryService` field, fixed on that branch from an earlier, inconsistent
`-canary` naming). Deployment-chart-only, called from its own
rollout-services.yaml; statefulset has no equivalent (see
charts-common.rolloutUnsupported).
*/}}
{{- define "charts-common.rolloutServices" -}}
{{- if .Values.global.rollout.enabled }}
{{- if eq .Values.global.rollout.strategyType "canary" }}
{{- if .Values.global.rollout.canary.createCanaryService }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.global.rollout.canary.canaryServiceName | default (printf "%s-preview" (include "charts-common.name" .)) }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
  {{- with .Values.global.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.global.service.type }}
  ports:
    {{- range $key, $val := .Values.global.service.ports }}
    - port: {{ $val.outer }}
      targetPort: {{ $key }}
      protocol: TCP
      name: {{ $key }}
    {{- end }}
  selector:
    {{- include "charts-common.selectorLabels" . | nindent 4 }}
{{- end }}
{{- else if eq .Values.global.rollout.strategyType "blueGreen" }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.global.rollout.blueGreen.activeService | default (printf "%s-active" (include "charts-common.name" .)) }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
  {{- with .Values.global.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.global.service.type }}
  ports:
    {{- range $key, $val := .Values.global.service.ports }}
    - port: {{ $val.outer }}
      targetPort: {{ $key }}
      protocol: TCP
      name: {{ $key }}
    {{- end }}
  selector:
    {{- include "charts-common.selectorLabels" . | nindent 4 }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.global.rollout.blueGreen.previewService | default (printf "%s-preview" (include "charts-common.name" .)) }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
  {{- with .Values.global.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.global.service.type }}
  ports:
    {{- range $key, $val := .Values.global.service.ports }}
    - port: {{ $val.outer }}
      targetPort: {{ $key }}
      protocol: TCP
      name: {{ $key }}
    {{- end }}
  selector:
    {{- include "charts-common.selectorLabels" . | nindent 4 }}
{{- end }}
{{- end }}
{{- end -}}
