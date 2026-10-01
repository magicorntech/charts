{{/*
PodDisruptionBudget for the release's own pods. Opt-in (global.pdb.enabled,
default false), so every existing values file renders byte-for-byte as
before. Takes the plain root context, shared by both umbrellas.

Selects on the same selectorLabels as the workload itself, so it works
unchanged for a Deployment, a StatefulSet and an Argo Rollout.

Exactly one of minAvailable / maxUnavailable must be set (the Kubernetes API
rejects both-set, and a PDB with neither selects nothing useful); this
`fail`s at render time with a message naming the key, instead of the API
server's much less helpful rejection at install time. Values may be an
integer or a percentage string ("50%"); 0 is valid and is NOT treated as
unset. unhealthyPodEvictionPolicy is only emitted when set, because the field
does not exist on clusters older than 1.26.
*/}}
{{- define "charts-common.pdb" -}}
{{- $p := .Values.global.pdb -}}
{{- if $p.enabled -}}
{{- $hasMin := not (kindIs "invalid" $p.minAvailable) -}}
{{- $hasMax := not (kindIs "invalid" $p.maxUnavailable) -}}
{{- if and $hasMin $hasMax -}}
{{- fail "global.pdb: set exactly one of minAvailable or maxUnavailable, not both" -}}
{{- end -}}
{{- if not (or $hasMin $hasMax) -}}
{{- fail "global.pdb.enabled is true but neither minAvailable nor maxUnavailable is set" -}}
{{- end -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "charts-common.name" . }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
spec:
  {{- if $hasMin }}
  minAvailable: {{ $p.minAvailable | toJson }}
  {{- else }}
  maxUnavailable: {{ $p.maxUnavailable | toJson }}
  {{- end }}
  {{- with $p.unhealthyPodEvictionPolicy }}
  unhealthyPodEvictionPolicy: {{ . }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "charts-common.selectorLabels" . | nindent 6 }}
{{- end -}}
{{- end -}}
