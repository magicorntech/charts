{{/*
The pod template spec shared verbatim between charts-common.deployment
and charts-common.rollout (P7) -- from `metadata:` through the shared
podSpecTail, i.e. everything under `spec.template`. Extracted specifically
for the Argo Rollouts port: a Rollout's pod template is functionally
identical to a Deployment's (same containers/volumes/env/probes), and
duplicating it a second time would double the maintenance surface for
every future fix to this block. Callers write their own `template:` key
and `{{- include "charts-common.podTemplateSpec" . | nindent 4 }}` right
under it -- same indentation-via-nindent convention as every other
multi-line helper in this chart. Takes the plain root context.
*/}}
{{- define "charts-common.podTemplateSpec" -}}
metadata:
  {{- with .Values.global.deployment.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "charts-common.selectorLabels" . | nindent 4 }}
spec:
  {{- with .Values.global.deployment.image.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with include "charts-common.serviceAccountName" . }}
  serviceAccountName: {{ . }}
  {{- end }}
  securityContext:
    {{- toYaml .Values.global.security.podSecurityContext | nindent 4 }}
  {{- if or .Values.global.configMap.enabled .Values.global.pvc.enabled (include "charts-common.gcpSecretsEnabled" .) }}
  volumes:
    {{- with include "charts-common.volumes.appConfig" . -}}
    {{ . | nindent 4 }}
    {{- end }}
    {{- if .Values.global.pvc.enabled }}
    - name: storage
      persistentVolumeClaim:
        claimName: {{ include "charts-common.name" . }}-pvc
    {{- end }}
    {{- with include "charts-common.volumes.gcpSecrets" . -}}
    {{ . | nindent 4 }}
    {{- end }}
  {{- end }}
  containers:
    - name: {{ include "charts-common.name" . }}
      image: "{{ .Values.global.deployment.image.uri }}"
      imagePullPolicy: {{ .Values.global.deployment.image.pullPolicy | quote }}
      {{- if .Values.global.deployment.image.command }}
      command: {{- toYaml .Values.global.deployment.image.command | nindent 8 }}
      {{- end }}
      {{- if .Values.global.deployment.image.args }}
      args: {{- toYaml .Values.global.deployment.image.args | nindent 8 }}
      {{- end }}
      {{- if .Values.global.service.enabled }}
      ports:
        {{- range $key, $val := .Values.global.service.ports }}
        - name: {{ $key }}
          containerPort: {{ $val.inner }}
          protocol: TCP
        {{- end }}
      {{- end }}
      {{- if or .Values.global.configMap.enabled .Values.global.pvc.enabled (include "charts-common.gcpSecretsEnabled" .) }}
      volumeMounts:
        {{- with include "charts-common.volumeMounts.appConfig" . -}}
        {{ . | nindent 8 }}
        {{- end }}
        {{- if .Values.global.pvc.enabled }}
        - name: storage
          mountPath: {{ .Values.global.pvc.mountPath | quote }}
          subPath: {{ .Values.global.pvc.subPath | quote }}
          readOnly: false
        {{- end }}
        {{- with include "charts-common.volumeMounts.gcpSecrets" . -}}
        {{ . | nindent 8 }}
        {{- end }}
      {{- end }}
      {{- if .Values.global.deployment.readiness }}
      readinessProbe:
        {{- toYaml .Values.global.deployment.readiness | nindent 8 }}
      {{- end }}
      {{- if .Values.global.deployment.liveness }}
      livenessProbe:
        {{- toYaml .Values.global.deployment.liveness | nindent 8 }}
      {{- end }}
      env:
        {{- toYaml .Values.global.deployment.env | nindent 8 }}
        {{- with include "charts-common.env.k8sSecrets" . -}}
        {{ . | nindent 8 }}
        {{- end }}
      resources:
        {{- toYaml .Values.global.deployment.resources | nindent 8 }}
      {{- if .Values.global.deployment.lifecycle }}
      lifecycle:
        {{- toYaml .Values.global.deployment.lifecycle | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.global.security.securityContext | nindent 8 }}
      terminationMessagePath: /dev/termination-log
      terminationMessagePolicy: File
  {{- include "charts-common.podSpecTail" . | nindent 2 }}
{{- end -}}
