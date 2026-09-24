{{/*
The 9 hardcoded NLB annotations, aws + LoadBalancer only. Returned as raw
YAML text so the caller can `fromYaml` it into a real map and `merge` it
against the user's own annotations — this is what makes "user wins on a
colliding key" a real guarantee instead of the raw-text splice this used
to be (which produced a literal duplicate-key crash on collision, not a
precedence rule).
*/}}
{{- define "charts-common.service.nlbAnnotations" -}}
service.beta.kubernetes.io/aws-load-balancer-type: external
service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: {{ add1 .Values.global.deployment.liveness.successThreshold | quote }}
service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: {{ .Values.global.deployment.liveness.failureThreshold | quote }}
service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: {{ .Values.global.deployment.liveness.timeoutSeconds | quote }}
service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: {{ .Values.global.deployment.liveness.periodSeconds | quote }}
service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: deregistration_delay.timeout_seconds={{ .Values.global.deployment.deregistrationTime }}, deregistration_delay.connection_termination.enabled=true, preserve_client_ip.enabled=true
service.beta.kubernetes.io/aws-load-balancer-attributes: load_balancing.cross_zone.enabled=false, deletion_protection.enabled=true
{{- end -}}

{{/*
The Azure Load Balancer (AKS) health-probe annotations, aws-NLB-block's
azure counterpart. Only interval/threshold are set -- Azure LB probes stay
plain TCP (no protocol/path annotation), same reasoning the AWS NLB block
already follows: this chart's Service always carries more than one port
(see global.service.ports), and an HTTP-path probe would be evaluated
against every one of them, breaking a non-HTTP port. `internet-facing` is
the default scheme, matching AWS's own hardcoded default -- an internal LB
is opted into via the user's own `azure-load-balancer-internal: "true"`
annotation, which wins over this block (see charts-common.service below).
Azure Load Balancer enforces hard minimums (interval >= 5s, probe count >=
2) that AWS's NLB does not -- clamped with `max` so a liveness probe tuned
for AWS/HTTP semantics can't silently produce a rejected-by-Azure manifest.
*/}}
{{- define "charts-common.service.azureLbAnnotations" -}}
service.beta.kubernetes.io/azure-load-balancer-health-probe-interval: {{ max .Values.global.deployment.liveness.periodSeconds 5 | quote }}
service.beta.kubernetes.io/azure-load-balancer-health-probe-num-of-probe: {{ max .Values.global.deployment.liveness.failureThreshold 2 | quote }}
{{- end -}}

{{/*
Collapses service-{aws,gcp,hcp,datacenter}.yaml, which differed only in
the destination guard and (aws only) the NLB annotation block — 84 of 112
lines were pure copy-paste. Takes the plain root context.
*/}}
{{- define "charts-common.service" -}}
{{- $root := . -}}
{{- $dest := include "charts-common.destination" $root -}}
{{- $skipMainService := false -}}
{{- if and $root.Values.global.rollout.enabled (eq $root.Values.global.rollout.strategyType "blueGreen") -}}
{{/*
FIXED (§B6, from the source branch's own 1a68fd4 fix): the main Service
is skipped for blueGreen only — never for canary's own createCanaryService,
which the buggy 50ac9ec shape on that branch also skipped it for. A
canary rollout's main Service must keep pointing at the whole
stable+canary pod set the entire time (that's how Argo shifts weighted
traffic between them); only blueGreen genuinely replaces it with its own
active/preview pair, since blueGreen has no single "current" service.
*/}}
{{- $skipMainService = true -}}
{{- end -}}
{{- if and $root.Values.global.service.enabled (not $skipMainService) }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "charts-common.name" $root }}
  namespace: "{{ $root.Release.Namespace }}"
  annotations:
    {{- $user := default (dict) $root.Values.global.service.annotations }}
    {{- $plat := dict }}
    {{- if and (eq $dest "aws") (eq (default "ClusterIP" $root.Values.global.service.type) "LoadBalancer") }}
    {{- $plat = include "charts-common.service.nlbAnnotations" $root | fromYaml }}
    {{- else if and (eq $dest "azure") (eq (default "ClusterIP" $root.Values.global.service.type) "LoadBalancer") }}
    {{- $plat = include "charts-common.service.azureLbAnnotations" $root | fromYaml }}
    {{- end }}
    {{- toYaml (merge (dict) $user $plat) | nindent 4 }}
  labels:
    {{- include "charts-common.labels" $root | nindent 4 }}
spec:
  {{- if eq $root.Values.global.service.type "None" }}
  type: ClusterIP
  clusterIP: None
  {{- else }}
  type: {{ $root.Values.global.service.type | quote }}
  {{- end }}
  ports:
    {{- range $key, $val := $root.Values.global.service.ports }}
    - name: {{ $key }}
      targetPort: {{ $val.inner }}
      port: {{ $val.outer }}
      protocol: TCP
    {{- end }}
  selector:
    {{- include "charts-common.selectorLabels" $root | nindent 4 }}
{{- end }}
{{- end -}}
