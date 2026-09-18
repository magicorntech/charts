{{/*
Post-install/post-upgrade hook Jobs, driven by `global.posthooks` — a
list (same shape as `global.cronjobs`), not a fixed pair of keys like
_prehook-job.tpl's dbMigrations/otherPrehooks. There's no single
canonical "the one post-deploy job" the way migrations is for prehooks,
so an arbitrary number of named post-deploy jobs (smoke test, cache
warmup, Slack notify, ...) need to be supported, each independently
enable/disable-able and independently weighted if ordering between them
matters.

⚠️ Helm only runs post-install/post-upgrade hooks after the release's
main resources are CREATED (accepted by the API server) — it does NOT
wait for them to become Ready (pods Running, Deployment rollout
complete) unless the `helm upgrade`/`helm install` invocation itself
passed `--wait` (or `--atomic`, which implies it). Without `--wait`, a
posthook here can start running against a Deployment that is still
rolling out. This chart has no control over the flag the calling
pipeline uses — document this requirement wherever a posthook depends on
the new version actually being live (README's Values Contract section).

Call via the range wrapper `charts-common.posthooks` below; do not call
`charts-common.posthookJob` directly.
*/}}
{{- define "charts-common.posthookJob" -}}
{{- $root := .root -}}
{{- $job := .job -}}
{{- if $job.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "charts-common.name" $root }}-{{ $job.name }}
  namespace: "{{ $root.Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" $root | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": {{ $job.weight | default "0" | quote }}
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  {{- with $job.backoffLimit }}
  backoffLimit: {{ . }}
  {{- end }}
  template:
    metadata:
      {{- with $root.Values.global.deployment.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "charts-common.selectorLabels" $root | nindent 8 }}
    spec:
      {{- with $root.Values.global.deployment.image.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with include "charts-common.serviceAccountName" $root }}
      serviceAccountName: {{ . }}
      {{- end }}
      {{- if $root.Values.global.deployment.ndots }}
      dnsConfig:
        options:
          - name: ndots
            value: {{ $root.Values.global.deployment.ndots | toString | quote }}
      {{- end }}
      restartPolicy: Never
      {{- if or $root.Values.global.configMap.enabled (include "charts-common.gcpSecretsEnabled" $root) }}
      volumes:
        {{- with include "charts-common.volumes.appConfig" $root -}}
        {{ . | nindent 8 }}
        {{- end }}
        {{- with include "charts-common.volumes.gcpSecrets" $root -}}
        {{ . | nindent 8 }}
        {{- end }}
      {{- end }}
      containers:
        - name: {{ include "charts-common.name" $root }}
          image: "{{ $root.Values.global.deployment.image.uri }}"
          imagePullPolicy: {{ $root.Values.global.deployment.image.pullPolicy | quote }}
          {{- if $job.command }}
          command: {{- toYaml $job.command | nindent 12 }}
          {{- end }}
          {{- if $job.args }}
          args: {{- toYaml $job.args | nindent 12 }}
          {{- end }}
          {{- if or $root.Values.global.configMap.enabled (include "charts-common.gcpSecretsEnabled" $root) }}
          volumeMounts:
            {{- with include "charts-common.volumeMounts.appConfig" $root -}}
            {{ . | nindent 12 }}
            {{- end }}
            {{- with include "charts-common.volumeMounts.gcpSecrets" $root -}}
            {{ . | nindent 12 }}
            {{- end }}
          {{- end }}
          env:
            {{- toYaml $root.Values.global.deployment.env | nindent 12 }}
            {{- with include "charts-common.env.k8sSecrets" $root -}}
            {{ . | nindent 12 }}
            {{- end }}
          resources:
            {{- toYaml (default $root.Values.global.deployment.resources $job.resources) | nindent 12 }}
{{- end }}
{{- end -}}

{{- define "charts-common.posthooks" -}}
{{- range $job := .Values.global.posthooks }}
{{- with $ }}
{{- include "charts-common.posthookJob" (dict "root" . "job" $job) }}
---
{{- end }}
{{- end }}
{{- end -}}
