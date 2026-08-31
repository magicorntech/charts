{{- define "charts-common.cronjobs" -}}
{{- range $job := .Values.global.cronjobs }}
{{- if $job.enabled -}}
{{- with $ }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "charts-common.name" . }}-{{ $job.name }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
spec:
  schedule: {{ $job.schedule | quote }}
  concurrencyPolicy: {{ $job.concurrencyPolicy }}
  failedJobsHistoryLimit: {{ $job.failedJobsHistoryLimit }}
  successfulJobsHistoryLimit: {{ $job.successfulJobsHistoryLimit }}
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: {{ include "charts-common.name" . }}-{{ $job.name }}
            cron: {{ $job.name }}
        spec:
          {{- with .Values.global.deployment.image.imagePullSecrets }}
          imagePullSecrets:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with include "charts-common.serviceAccountName" . }}
          serviceAccountName: {{ . }}
          {{- end }}
          securityContext:
            {{- toYaml .Values.global.security.podSecurityContext | nindent 12 }}
          {{- if or .Values.global.configMap.enabled (include "charts-common.gcpSecretsEnabled" .) }}
          volumes:
            {{- with include "charts-common.volumes.appConfig" . -}}
            {{ . | nindent 12 }}
            {{- end }}
            {{- with include "charts-common.volumes.gcpSecrets" . -}}
            {{ . | nindent 12 }}
            {{- end }}
          {{- end }}
          containers:
          - name: {{ $job.name }}
            image: "{{ .Values.global.deployment.image.uri }}"
            imagePullPolicy: {{ .Values.global.deployment.image.pullPolicy | quote }}
            env:
              {{- toYaml .Values.global.deployment.env | nindent 12 }}
              {{- with include "charts-common.env.k8sSecrets" . -}}
              {{ . | nindent 12 }}
              {{- end }}
            {{- with $job.command }}
            command: {{ toYaml . | nindent 12 }}
            {{- end }}
            {{- with $job.args }}
            args: {{ toYaml . | nindent 12 }}
            {{- end }}
            resources:
              {{- toYaml $job.resources | nindent 14 }}
            {{- if or .Values.global.configMap.enabled (include "charts-common.gcpSecretsEnabled" .) }}
            volumeMounts:
              {{- with include "charts-common.volumeMounts.appConfig" . -}}
              {{ . | nindent 14 }}
              {{- end }}
              {{- with include "charts-common.volumeMounts.gcpSecrets" . -}}
              {{ . | nindent 14 }}
              {{- end }}
            {{- end }}
          dnsPolicy: ClusterFirst
          {{- if .Values.global.deployment.ndots }}
          dnsConfig:
            options:
              - name: ndots
                value: {{ .Values.global.deployment.ndots | toString | quote }}
          {{- end }}
          {{- with .Values.global.deployment.nodeSelector }}
          nodeSelector:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          restartPolicy: {{ $job.restartPolicy }}
          schedulerName: default-scheduler
          {{- with .Values.global.deployment.affinity }}
          affinity:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.global.deployment.tolerations }}
          tolerations:
            {{- toYaml . | nindent 12 }}
          {{- end }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
