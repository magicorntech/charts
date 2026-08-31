{{/*
Expand the name of the chart — plain .Release.Name by default (this chart
has never prefixed/suffixed it with the chart name the way the standard
Helm scaffold's fullname helper does), with two opt-in overrides:
fullnameOverride replaces it outright (highest precedence); nameOverride
replaces just the base name it's built from (equivalent to
fullnameOverride here specifically, since there's no chart-name
component to combine it with — kept as its own key anyway for parity
with the standard Helm scaffold's naming, so a values file written for
that convention still does something sensible here rather than being a
silent no-op). Neither set -> byte-identical to before either existed.
*/}}
{{- define "charts-common.name" -}}
{{- if .Values.global.fullnameOverride -}}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- default .Release.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

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

{{/*
Mutual-exclusion guard for the Deployment/Rollout workload choice (P7).
Both controllers targeting the same selectorLabels would fight over the
same pods — fail loudly at render time instead of silently rendering
both (or, worse, silently rendering neither, if some future refactor
guarded the wrong way). Called once from charts-common.deployment's own
entry point; deliberately not called from a Rollout entry point too,
since that path is deployment-chart-only (P7's own StatefulSet fail
guard is the statefulset chart's own charts-common.rolloutUnsupported).
*/}}
{{- define "charts-common.validateWorkloadMode" -}}
{{- if and .Values.global.deployment.enabled .Values.global.rollout.enabled -}}
{{- fail "global.deployment.enabled and global.rollout.enabled cannot both be true — pick exactly one workload controller" -}}
{{- end -}}
{{- end -}}

{{/*
Statefulset has no Rollout equivalent (P7 is deployment-only — Argo
Rollouts has no StatefulSet controller). Called from the statefulset
chart's own statefulset.yaml wrapper so a misconfigured
global.rollout.enabled=true fails loudly and immediately, rather than
silently doing nothing on a chart where the key has no effect at all.
*/}}
{{- define "charts-common.rolloutUnsupported" -}}
{{- if .Values.global.rollout.enabled -}}
{{- fail "global.rollout.enabled has no effect on the statefulset chart — Argo Rollouts has no StatefulSet controller" -}}
{{- end -}}
{{- end -}}
