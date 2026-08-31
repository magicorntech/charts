{{- define "charts-common.serviceAccount" -}}
{{- if .Values.global.security.serviceAccount.enabled -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "charts-common.serviceAccountName" . }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-200"
    {{- with .Values.global.security.serviceAccount.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end -}}

{{- define "charts-common.role" -}}
{{- if .Values.global.security.serviceAccount.enabled -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: {{ if .Values.global.security.serviceAccount.clusterWideAccess }}"ClusterRole"{{ else }}"Role"{{ end }}
metadata:
  name: {{ include "charts-common.serviceAccountName" . }}
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-200"
  {{ if not .Values.global.security.serviceAccount.clusterWideAccess -}}
  namespace: {{ .Release.Namespace | quote }}
  {{- end }}
{{- if .Values.global.security.serviceAccount.rules }}
rules:
{{- range .Values.global.security.serviceAccount.rules }}
- apiGroups: {{ (default (list "") .apiGroups) | toJson }}
  resources: {{ (default (list "*") .resources) | toJson }}
  verbs: {{ (default (list "*") .verbs) | toJson }}
{{- end }}
{{- else }}
rules: []
{{- end }}
{{- end -}}
{{- end -}}

{{- define "charts-common.roleBinding" -}}
{{- if .Values.global.security.serviceAccount.enabled -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: {{ if .Values.global.security.serviceAccount.clusterWideAccess }}"ClusterRoleBinding"{{ else }}"RoleBinding"{{ end }}
metadata:
  name: {{ include "charts-common.serviceAccountName" . }}
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-200"
  {{ if not .Values.global.security.serviceAccount.clusterWideAccess -}}
  namespace: {{ .Release.Namespace | quote }}
  {{- end }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: {{ if .Values.global.security.serviceAccount.clusterWideAccess }}"ClusterRole"{{ else }}"Role"{{ end }}
  name: {{ include "charts-common.serviceAccountName" . }}
subjects:
- kind: ServiceAccount
  name: {{ include "charts-common.serviceAccountName" . }}
  namespace: "{{ .Release.Namespace }}"
{{- end -}}
{{- end -}}
