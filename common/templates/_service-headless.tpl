{{/*
FIXED (B5): StatefulSet.spec.serviceName has always pointed at
`<release>-headless` (see charts-common.statefulset), but no Service by
that name ever existed — stable per-pod DNS
(`<pod>.<release>-headless.<ns>.svc.cluster.local`) silently never
worked, contrary to what this chart's own README claimed. Additive only:
a genuinely new object, never replacing or gating the existing
charts-common.service (which stays exactly as it is — a StatefulSet can
still want a real ClusterIP/LoadBalancer Service on top of this one for
actual traffic). Not gated on global.service.enabled — StatefulSet's own
`serviceName` reference is itself unconditional, so this mirrors that:
gated purely on there being ports to publish at all. StatefulSet-only,
never called from the deployment chart (a Deployment has no
`spec.serviceName` concept to back).
*/}}
{{- define "charts-common.serviceHeadless" -}}
{{- if .Values.global.service.ports }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "charts-common.name" . }}-headless
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
spec:
  clusterIP: None
  ports:
    {{- range $key, $val := .Values.global.service.ports }}
    - name: {{ $key }}
      targetPort: {{ $val.inner }}
      port: {{ $val.outer }}
      protocol: TCP
    {{- end }}
  selector:
    {{- include "charts-common.selectorLabels" . | nindent 4 }}
{{- end }}
{{- end -}}
