{{/*
Expand the name of the chart.
*/}}
{{- define "charts-common.name" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "charts-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "charts-common.labels" -}}
helm.sh/chart: {{ include "charts-common.chart" . }}
k8s.magicorn.net/chart-version: {{ .Chart.Version }}
{{ include "charts-common.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "charts-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "charts-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "charts-common.serviceAccountName" -}}
{{- if .Values.global.security.serviceAccount.enabled }}
{{- default (include "charts-common.name" .) }}
{{- end }}
{{- end }}
