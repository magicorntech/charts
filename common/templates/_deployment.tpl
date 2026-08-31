{{- define "charts-common.deployment" -}}
{{- include "charts-common.validateWorkloadMode" . }}
{{- if .Values.global.deployment.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "charts-common.name" . }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
spec:
  {{- if not .Values.global.autoscaling.enabled }}
  replicas: {{ .Values.global.deployment.replicaCount }}
  {{- end }}
  progressDeadlineSeconds: {{ .Values.global.deployment.failSeconds }}
  revisionHistoryLimit: {{ .Values.global.deployment.revisionHistory }}
  strategy:
    {{- toYaml .Values.global.deployment.strategy | nindent 4 }}
  selector:
    matchLabels:
      {{- include "charts-common.selectorLabels" . | nindent 6 }}
  template:
    {{- include "charts-common.podTemplateSpec" . | nindent 4 }}
{{- end }}
{{- end -}}
