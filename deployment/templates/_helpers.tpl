{{/*
Expand the name of the chart.
*/}}
{{- define "charts-deployment.name" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "charts-deployment.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "charts-deployment.labels" -}}
helm.sh/chart: {{ include "charts-deployment.chart" . }}
k8s.magicorn.net/chart-version: {{ .Chart.Version }}
{{ include "charts-deployment.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "charts-deployment.selectorLabels" -}}
app.kubernetes.io/name: {{ include "charts-deployment.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "charts-deployment.serviceAccountName" -}}
{{- if .Values.security.serviceAccount.enabled }}
{{- default (include "charts-deployment.name" .) }}
{{- end }}
{{- end }}

{{/*
Create the name of the GKE frontend config to use
*/}}
{{- define "charts-deployment.gkeFrontendConfigName" -}}
{{- if and (eq .Values.destination "gke") .Values.ingress.gke.frontendConfig }}
{{- default (include "charts-deployment.name" .) .Values.ingress.gke.frontendConfig }}
{{- end }}
{{- end -}}