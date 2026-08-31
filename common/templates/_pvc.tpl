{{- define "charts-common.pvc" -}}
{{- if .Values.global.pvc.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "charts-common.name" . }}-pvc
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-200"
spec:
  accessModes:
    {{- toYaml .Values.global.pvc.accessModes | nindent 4 }}
  storageClassName: {{ .Values.global.pvc.storageClass | quote }}
  resources:
    requests:
      storage: {{ required "pvc.size is required" .Values.global.pvc.size | quote }}
{{- end }}
{{- end -}}
