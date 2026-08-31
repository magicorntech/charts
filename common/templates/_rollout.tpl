{{/*
The Argo Rollouts `Rollout` object (P7) — deployment.yaml's alternative,
mutually exclusive with charts-common.deployment (see
charts-common.validateWorkloadMode). Same pod template as the Deployment
(charts-common.podTemplateSpec, shared verbatim) — only the object kind,
`spec.strategy`, and the fields Rollout doesn't share with Deployment
(no `strategy.rollingUpdate`, its own `revisionHistoryLimit` source)
differ. Ported from the 0.7.5/0.7.6 `devops/argo-rollout` branch
(commit 1a68fd4's shape specifically — the later of two competing designs
on that branch, which dropped a redundant `-stable` Service the earlier
one created and renamed `-canary` to `-preview`, matching what
charts-common.rolloutServices below actually creates).
*/}}
{{- define "charts-common.rollout" -}}
{{- include "charts-common.validateWorkloadMode" . }}
{{- if .Values.global.rollout.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
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
  revisionHistoryLimit: {{ .Values.global.rollout.revisionHistory }}
  selector:
    matchLabels:
      {{- include "charts-common.selectorLabels" . | nindent 6 }}
  template:
    {{- include "charts-common.podTemplateSpec" . | nindent 4 }}
  strategy:
    {{- if eq .Values.global.rollout.strategyType "canary" }}
    canary:
      {{- if .Values.global.rollout.canary.createCanaryService }}
      canaryService: {{ .Values.global.rollout.canary.canaryServiceName | default (printf "%s-preview" (include "charts-common.name" .)) }}
      {{- end }}
      {{- if .Values.global.rollout.canary.maxSurge }}
      maxSurge: {{ .Values.global.rollout.canary.maxSurge }}
      {{- end }}
      {{- if .Values.global.rollout.canary.maxUnavailable }}
      maxUnavailable: {{ .Values.global.rollout.canary.maxUnavailable }}
      {{- end }}
      {{- if .Values.global.rollout.canary.steps }}
      steps:
        {{- toYaml .Values.global.rollout.canary.steps | nindent 8 }}
      {{- end }}
      {{- if .Values.global.rollout.canary.trafficRouting.enabled }}
      trafficRouting:
        {{- if eq .Values.global.rollout.canary.trafficRouting.type "alb" }}
        alb:
          ingress: {{ include "charts-common.rollout.albIngressName" . }}
          servicePort: {{ (index .Values.global.service.ports "one").outer }}
        {{- else if eq .Values.global.rollout.canary.trafficRouting.type "istio" }}
        istio:
          virtualService:
            name: {{ include "charts-common.name" . }}
        {{- else if eq .Values.global.rollout.canary.trafficRouting.type "nginx" }}
        nginx:
          stableIngress: {{ include "charts-common.rollout.albIngressName" . }}
        {{- end }}
      {{- end }}
      {{- if .Values.global.rollout.canary.analysis.enabled }}
      analysis:
        templates:
          - templateName: {{ .Values.global.rollout.canary.analysis.templateName }}
        {{- if .Values.global.rollout.canary.analysis.args }}
        args:
          {{- toYaml .Values.global.rollout.canary.analysis.args | nindent 10 }}
        {{- end }}
      {{- end }}
    {{- else if eq .Values.global.rollout.strategyType "blueGreen" }}
    blueGreen:
      activeService: {{ .Values.global.rollout.blueGreen.activeService | default (printf "%s-active" (include "charts-common.name" .)) }}
      previewService: {{ .Values.global.rollout.blueGreen.previewService | default (printf "%s-preview" (include "charts-common.name" .)) }}
      autoPromotionEnabled: {{ .Values.global.rollout.blueGreen.autoPromotionEnabled }}
      {{- if .Values.global.rollout.blueGreen.autoPromotionSeconds }}
      autoPromotionSeconds: {{ .Values.global.rollout.blueGreen.autoPromotionSeconds }}
      {{- end }}
      {{- if .Values.global.rollout.blueGreen.scaleDownDelaySeconds }}
      scaleDownDelaySeconds: {{ .Values.global.rollout.blueGreen.scaleDownDelaySeconds }}
      {{- end }}
      {{- if .Values.global.rollout.blueGreen.previewReplicaCount }}
      previewReplicaCount: {{ .Values.global.rollout.blueGreen.previewReplicaCount }}
      {{- end }}
      {{- if .Values.global.rollout.blueGreen.analysis.enabled }}
      prePromotionAnalysis:
        templates:
          - templateName: {{ .Values.global.rollout.blueGreen.analysis.templateName }}
        {{- if .Values.global.rollout.blueGreen.analysis.args }}
        args:
          {{- toYaml .Values.global.rollout.blueGreen.analysis.args | nindent 10 }}
        {{- end }}
      {{- end }}
    {{- end }}
{{- end }}
{{- end -}}

{{/*
FIXED (§B6 bug 2): the source branch hardcoded `ingress: {{ include
"charts-deployment.name" . }}` — but an Ingress with more than one
`global.ingress[]` entry is named `<release>-N` (see
charts-common.ingress.name), never bare `<release>`, so a multi-ingress
config had no Ingress object matching that name at all and Argo's ALB
traffic-routing silently found nothing to manage. Resolved here instead:
an explicit `global.rollout.canary.trafficRouting.alb.ingressName`
override, or — the common case — the first configured `global.ingress[]`
entry's own computed name.
*/}}
{{- define "charts-common.rollout.albIngressName" -}}
{{- $override := .Values.global.rollout.canary.trafficRouting.alb.ingressName -}}
{{- if $override -}}
{{- $override -}}
{{- else -}}
{{- $count := len .Values.global.ingress -}}
{{- include "charts-common.ingress.name" (dict "root" . "ingress" (index .Values.global.ingress 0) "index" 0 "count" $count) -}}
{{- end -}}
{{- end -}}
