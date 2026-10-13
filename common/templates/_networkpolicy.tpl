{{/*
NetworkPolicy for the release's own pods. Opt-in (global.networkPolicy.enabled,
default false), so every existing values file renders byte-for-byte as before.
Takes the plain root context, shared by both umbrellas.

Selects on the same selectorLabels as the workload itself, so it works
unchanged for a Deployment, a StatefulSet and an Argo Rollout. The rule lists
are plain networking.k8s.io/v1 `ingress` / `egress` entries, passed through
verbatim (ipBlock, namespaceSelector, podSelector, ports). Use numeric ports
for portability: named ports (the chart's own `one` / `metrics` container port
names) are valid Kubernetes API but whether a CNI honours them depends on its
version.

A direction is controlled only when its key is SET: `ingress` set -> Ingress is
in policyTypes, `egress` set -> Egress is. An empty list (`ingress: []`) is a
real value, not "unset": it means "allow nothing in that direction" (the pod
becomes isolated). Enabling with neither key set `fail`s at render time,
because a policy with no policyTypes would silently default to Ingress with no
rules and cut all inbound traffic.

NOTE: NetworkPolicy objects are only enforced when the cluster's CNI enforces
them (on EKS: VPC CNI network policy enabled). Without enforcement this object
is accepted and ignored.
*/}}
{{- define "charts-common.networkPolicy" -}}
{{- $n := .Values.global.networkPolicy -}}
{{- if and $n $n.enabled -}}
{{- $hasIn := not (kindIs "invalid" $n.ingress) -}}
{{- $hasEg := not (kindIs "invalid" $n.egress) -}}
{{- if not (or $hasIn $hasEg) -}}
{{- fail "global.networkPolicy.enabled is true but neither ingress nor egress is set (use ingress: [] to deny all inbound traffic)" -}}
{{- end -}}
{{- if and $hasIn (not (kindIs "slice" $n.ingress)) -}}
{{- fail "global.networkPolicy.ingress must be a list of NetworkPolicy ingress rules" -}}
{{- end -}}
{{- if and $hasEg (not (kindIs "slice" $n.egress)) -}}
{{- fail "global.networkPolicy.egress must be a list of NetworkPolicy egress rules" -}}
{{- end -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "charts-common.name" . }}
  namespace: "{{ .Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "charts-common.selectorLabels" . | nindent 6 }}
  policyTypes:
    {{- if $hasIn }}
    - Ingress
    {{- end }}
    {{- if $hasEg }}
    - Egress
    {{- end }}
  {{- if $n.ingress }}
  ingress:
    {{- toYaml $n.ingress | nindent 4 }}
  {{- end }}
  {{- if $n.egress }}
  egress:
    {{- toYaml $n.egress | nindent 4 }}
  {{- end }}
{{- end -}}
{{- end -}}
