{{/*
The pod-spec tail shared verbatim between deployment.yaml and
statefulset.yaml: dnsPolicy through topologySpreadConstraints. Callers
`{{- include "charts-common.podSpecTail" . | nindent 6 }}` (spec.template.spec
level in both files — same pattern every other multi-line helper in this
chart uses, so indentation is the caller's job, not baked into the define).
Includes the B4 fix (per-item labelSelector, not one spliced after the
whole list).
*/}}
{{- define "charts-common.podSpecTail" -}}
dnsPolicy: ClusterFirst
{{- with .Values.global.deployment.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
restartPolicy: Always
schedulerName: default-scheduler
terminationGracePeriodSeconds: {{ .Values.global.deployment.deregistrationTime }}
{{- with .Values.global.deployment.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.global.deployment.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.global.deployment.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- range $c := . }}
  - {{- toYaml $c | nindent 4 }}
    {{- if not $c.labelSelector }}
    labelSelector:
      matchLabels:
        {{- include "charts-common.selectorLabels" $ | nindent 8 }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}
