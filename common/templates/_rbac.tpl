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

{{/*
The Role/ClusterRole's own name — normally the same as the
ServiceAccount's (charts-common.serviceAccountName), except when
clusterWideAccess is on AND an explicit clusterRoleName override is set.
A ClusterRole is cluster-scoped, not namespaced, so two releases of this
chart in two different namespaces sharing the same release name would
otherwise collide on the exact same ClusterRole object -- this override
exists specifically to let each one pick a unique name. Only affects the
Role/ClusterRole object's own metadata.name and the matching
roleRef.name in charts-common.roleBinding; the ServiceAccount itself and
the (Cluster)RoleBinding's own metadata.name are untouched (namespaced
RoleBindings never collide across namespaces to begin with; a
same-name-collision on a ClusterRoleBinding specifically is a real,
separate, narrower gap this key was not asked to close).
*/}}
{{- define "charts-common.roleName" -}}
{{- if .Values.global.security.serviceAccount.clusterWideAccess -}}
{{- .Values.global.security.serviceAccount.clusterRoleName | default (include "charts-common.serviceAccountName" .) -}}
{{- else -}}
{{- include "charts-common.serviceAccountName" . -}}
{{- end -}}
{{- end -}}

{{- define "charts-common.role" -}}
{{- if .Values.global.security.serviceAccount.enabled -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: {{ if .Values.global.security.serviceAccount.clusterWideAccess }}"ClusterRole"{{ else }}"Role"{{ end }}
metadata:
  name: {{ include "charts-common.roleName" . }}
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
  name: {{ include "charts-common.roleName" . }}
subjects:
- kind: ServiceAccount
  name: {{ include "charts-common.serviceAccountName" . }}
  namespace: "{{ .Release.Namespace }}"
{{- end -}}
{{- end -}}
