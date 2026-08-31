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

{{/*
Validated destination. Second layer of defense behind values.schema.json's
enum (--skip-schema-validation, or an older Helm without schema support,
would otherwise let an invalid destination render nothing, silently).
*/}}
{{- define "charts-common.destination" -}}
{{- $d := default "" .Values.global.destination -}}
{{- if not (has $d (list "aws" "gcp" "hcp" "datacenter")) -}}
{{- fail (printf "global.destination must be one of: aws, gcp, hcp, datacenter (got %q)" $d) -}}
{{- end -}}
{{- $d -}}
{{- end -}}

{{/*
"true" when this is a gcp destination with CSI-based secrets enabled — the
one condition every gcpsecrets volume/mount site already repeats via
`and (eq .Values.global.destination "gcp") .Values.global.secrets.enabled`.
Returns "" (falsy) otherwise, so callers can `{{- if include ... }}`.
*/}}
{{- define "charts-common.gcpSecretsEnabled" -}}
{{- if and (eq (include "charts-common.destination" .) "gcp") .Values.global.secrets.enabled -}}
true
{{- end -}}
{{- end -}}
