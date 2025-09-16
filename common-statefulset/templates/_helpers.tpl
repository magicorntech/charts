{{/*
Expand the name of the chart.
*/}}
{{- define "charts-statefulset.name" -}}
{{- include "charts-common.name" . }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "charts-statefulset.chart" -}}
{{- include "charts-common.chart" . }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "charts-statefulset.labels" -}}
{{- include "charts-common.labels" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "charts-statefulset.selectorLabels" -}}
{{- include "charts-common.selectorLabels" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "charts-statefulset.serviceAccountName" -}}
{{- include "charts-common.serviceAccountName" . }}
{{- end }}