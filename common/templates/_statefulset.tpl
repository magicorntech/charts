{{- define "charts-common.statefulset" -}}
{{- include "charts-common.rolloutUnsupported" . }}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "charts-common.name" . }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
spec:
  {{- if not .Values.global.autoscaling.enabled }}
  replicas: {{ .Values.global.deployment.replicaCount }}
  {{- end }}
  # StatefulSet specific: serviceName is required for stable network identity
  serviceName: {{ include "charts-common.name" . }}-headless
  # StatefulSet specific: podManagementPolicy controls how pods are created/deleted
  # Default is OrderedReady, which ensures pods are created/deleted in order
  podManagementPolicy: {{ .Values.global.deployment.podManagementPolicy | default "OrderedReady" }}
  # StatefulSet specific: updateStrategy for rolling updates
  # Default RollingUpdate with partition: 0 for immediate updates
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: {{ .Values.global.deployment.updateStrategyPartition | default 0 }}
  selector:
    matchLabels:
      {{- include "charts-common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.global.deployment.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "charts-common.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.global.deployment.image.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with include "charts-common.serviceAccountName" . }}
      serviceAccountName: {{ . }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.global.security.podSecurityContext | nindent 8 }}
      {{- if or .Values.global.configMap.enabled (include "charts-common.gcpSecretsEnabled" .) }}
      volumes:
        {{- with include "charts-common.volumes.appConfig" . -}}
        {{ . | nindent 8 }}
        {{- end }}
        {{- with include "charts-common.volumes.gcpSecrets" . -}}
        {{ . | nindent 8 }}
        {{- end }}
      {{- end }}

      containers:
        - name: {{ include "charts-common.name" . }}
          image: "{{ .Values.global.deployment.image.uri }}"
          imagePullPolicy: {{ .Values.global.deployment.image.pullPolicy | quote }}
          {{- if .Values.global.deployment.image.command }}
          command: {{- toYaml .Values.global.deployment.image.command | nindent 12 }}
          {{- end }}
          {{- if .Values.global.deployment.image.args }}
          args: {{- toYaml .Values.global.deployment.image.args | nindent 12 }}
          {{- end }}
          {{- if .Values.global.service.enabled }}
          ports:
            {{- range $key, $val := .Values.global.service.ports }}
            - name: {{ $key }}
              containerPort: {{ $val.inner }}
              protocol: TCP
            {{- end }}
          {{- end }}
          volumeMounts:
            # StatefulSet specific: volumeMounts for persistent storage
            # Each pod will get its own PVC based on volumeClaimTemplates
            - name: storage
              mountPath: {{ .Values.global.pvc.mountPath | quote }}
              subPath: {{ .Values.global.pvc.subPath | quote }}
              readOnly: false
            {{- with include "charts-common.volumeMounts.appConfig" . -}}
            {{ . | nindent 12 }}
            {{- end }}
            {{- with include "charts-common.volumeMounts.gcpSecrets" . -}}
            {{ . | nindent 12 }}
            {{- end }}

          {{- if .Values.global.deployment.readiness }}
          readinessProbe:
            {{- toYaml .Values.global.deployment.readiness | nindent 12 }}
          {{- end }}
          {{- if .Values.global.deployment.liveness }}
          livenessProbe:
            {{- toYaml .Values.global.deployment.liveness | nindent 12 }}
          {{- end }}
          env:
            {{- toYaml .Values.global.deployment.env | nindent 12 }}
            {{- with include "charts-common.env.k8sSecrets" . -}}
            {{ . | nindent 12 }}
            {{- end }}
          resources:
            {{- toYaml .Values.global.deployment.resources | nindent 12 }}
          {{- if .Values.global.deployment.lifecycle }}
          lifecycle:
            {{- toYaml .Values.global.deployment.lifecycle | nindent 12 }}
          {{- end }}
          securityContext:
            {{- toYaml .Values.global.security.securityContext | nindent 12 }}
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
      {{- include "charts-common.podSpecTail" . | nindent 6 }}

  # StatefulSet specific: volumeClaimTemplates for persistent storage
  # Each pod will get its own PVC: <statefulset-name>-<pod-ordinal>-<template-name>
  volumeClaimTemplates:
  - metadata:
      name: storage
      labels:
        {{- include "charts-common.labels" . | nindent 8 }}
    spec:
      accessModes:
        {{- toYaml (default (list "ReadWriteOnce") .Values.global.pvc.accessModes) | nindent 8 }}
      resources:
        requests:
          storage: {{ .Values.global.pvc.size }}
      {{- if .Values.global.pvc.storageClass }}
      storageClassName: {{ .Values.global.pvc.storageClass | quote }}
      {{- end }}
{{- end -}}
