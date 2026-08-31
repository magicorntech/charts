{{/*
Shared body for the two pre-install/pre-upgrade prehook Jobs (dbMigrations
and otherPrehooks) — 78 of 80 lines were identical between them. Call with
a dict:
  root:   $ (the umbrella's root context)
  spec:   .Values.global.prehooks.dbMigrations or .otherPrehooks
  suffix: "migrations" or "prehooks" (object name suffix)
  weight: "-100" or "-90" (helm.sh/hook-weight; migrations must stay
          numerically lower so it runs first — see the ordering note in
          each umbrella's own migrations.yaml/other-prehooks.yaml)
*/}}
{{- define "charts-common.prehookJob" -}}
{{- $root := .root -}}
{{- $spec := .spec -}}
{{- if $spec.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "charts-common.name" $root }}-{{ .suffix }}
  namespace: "{{ $root.Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" $root | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": {{ .weight | quote }}
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
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
          {{- if $spec.command }}
          command: {{- toYaml $spec.command | nindent 12 }}
          {{- end }}
          {{- if $spec.args }}
          args: {{- toYaml $spec.args | nindent 12 }}
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
            {{- toYaml $root.Values.global.deployment.resources | nindent 12 }}
{{- end }}
{{- end -}}
