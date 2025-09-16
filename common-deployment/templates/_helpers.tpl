{{/*
Expand the name of the chart.
*/}}
{{- define "charts-common-deployment.name" -}}
{{- include "charts-common.name" . }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "charts-common-deployment.chart" -}}
{{- include "charts-common.chart" . }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "charts-common-deployment.labels" -}}
{{- include "charts-common.labels" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "charts-common-deployment.selectorLabels" -}}
{{- include "charts-common.selectorLabels" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "charts-common-deployment.serviceAccountName" -}}
{{- include "charts-common.serviceAccountName" . }}
{{- end }}