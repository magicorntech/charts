{{/*
The ingress object's name. Deliberately based on LIST POSITION and LIST
LENGTH, not on how many entries are enabled — toggling one entry's
`enabled` must never rename another entry's Ingress (Helm would delete +
recreate it, which for an ALB means a brand new load balancer and real
downtime). Do not "fix" this to count only enabled entries.
Dict: {root, index, count}.
*/}}
{{- define "charts-common.ingress.name" -}}
{{- .ingress.name | default (printf "%s%s" (include "charts-common.name" .root) (ternary (printf "-%d" (add1 .index)) "" (gt .count 1))) -}}
{{- end -}}

{{/*
The 14 hardcoded ALB annotations. Dict: {root, ingress}. Returned as raw
YAML for `fromYaml`+`merge`, same reasoning as the Service equivalent.
*/}}
{{- define "charts-common.ingress.annotations.aws" -}}
{{- $root := .root -}}
{{- $ingress := .ingress -}}
alb.ingress.kubernetes.io/certificate-arn: {{ $ingress.certificateId | quote }}
alb.ingress.kubernetes.io/group.name: {{ $ingress.lbId | quote }}
alb.ingress.kubernetes.io/group.order: {{ $ingress.lbOrder | quote }}
alb.ingress.kubernetes.io/healthcheck-interval-seconds: {{ $root.Values.global.deployment.liveness.periodSeconds | quote }}
alb.ingress.kubernetes.io/healthcheck-path: {{ default (dig "httpGet" "path" "" $root.Values.global.deployment.liveness) $ingress.healthcheckPath }}
alb.ingress.kubernetes.io/healthcheck-timeout-seconds: {{ $root.Values.global.deployment.liveness.timeoutSeconds | quote }}
alb.ingress.kubernetes.io/healthy-threshold-count: {{ add1 $root.Values.global.deployment.liveness.successThreshold | quote }}
{{- if eq $ingress.listenPorts "http" }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
{{- else if eq $ingress.listenPorts "https" }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
{{- else }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
{{- end }}
alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds={{ $ingress.idleTimeout }}, deletion_protection.enabled=true
alb.ingress.kubernetes.io/scheme: {{ $ingress.scheme | quote }}
alb.ingress.kubernetes.io/ssl-policy: {{ $ingress.sslPolicy | quote }}
{{- if ne (toString $ingress.sslRedirect) "false" }}
alb.ingress.kubernetes.io/ssl-redirect: '443'
{{- end }}
alb.ingress.kubernetes.io/success-codes: '200'
alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds={{ $root.Values.global.deployment.deregistrationTime }}
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/unhealthy-threshold-count: {{ $root.Values.global.deployment.liveness.failureThreshold | quote }}
{{- if $ingress.wafId }}
alb.ingress.kubernetes.io/wafv2-acl-arn: {{ $ingress.wafId | quote }}
{{- end }}
{{- end -}}

{{/*
The 8 hardcoded HCP/CCE elb.* annotations. Dict: {root, ingress, name}.
*/}}
{{- define "charts-common.ingress.annotations.hcp" -}}
{{- $root := .root -}}
{{- $ingress := .ingress -}}
kubernetes.io/elb.class: performance
kubernetes.io/elb.http2-enable: 'true'
kubernetes.io/elb.id: {{ $ingress.lbId | quote }}
kubernetes.io/elb.listener-master-ingress: {{ $root.Release.Namespace }}/{{ .name }}
kubernetes.io/elb.port: '443'
kubernetes.io/elb.tls-certificate-ids: {{ $ingress.certificateId | quote }}
kubernetes.io/elb.tls-ciphers-policy: {{ $ingress.sslPolicy | quote }}
kubernetes.io/elb.ingress-order: {{ $ingress.lbOrder | quote }}
kubernetes.io/elb.client_timeout: {{ $ingress.idleTimeout | quote }}
{{- end -}}

{{/*
The rules: block. Identical across all 4 destinations except hcp's
per-path `property:` block. Dict: {root, ingress, dest}. k8s 1.25+ only
(the pre-1.18/1.19 semverCompare branches this repo carried are gone —
dead code below this chart's own README-declared floor).
*/}}
{{- define "charts-common.ingress.rules" -}}
{{- $root := .root -}}
{{- range $ingress := list .ingress }}
{{- range $ingress.hosts -}}
- host: {{ .host | quote }}
  http:
    paths:
      {{- range .paths }}
      - path: {{ .path | quote }}
        {{- if .pathType }}
        pathType: {{ .pathType | quote }}
        {{- end }}
        backend:
          service:
            name: {{ include "charts-common.name" $root }}
            port:
              number: {{ $root.Values.global.service.ports.one.outer }}
        {{- if eq $.dest "hcp" }}
        property:
          ingress.beta.kubernetes.io/url-match-mode: STARTS_WITH
        {{- end }}
      {{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Collapses ingress-{aws,gcp,hcp,datacenter}.yaml — ~180 of 244 lines were
shared. Differences reduce to 4 axes: ingressClassName (hardcoded on
aws/hcp, from values on gcp/datacenter), the platform annotation block
(aws/hcp only — and unlike Service, PLATFORM wins on a colliding user
annotation here, the opposite precedence, preserved on purpose), tls
(gcp/datacenter only), and hcp's per-path `property:`. Plain root context.
*/}}
{{- define "charts-common.ingress" -}}
{{- $root := . -}}
{{- $dest := include "charts-common.destination" $root -}}
{{- $count := len $root.Values.global.ingress -}}
{{- range $index, $ingress := $root.Values.global.ingress }}
{{- if $ingress.enabled }}
{{- $name := include "charts-common.ingress.name" (dict "root" $root "ingress" $ingress "index" $index "count" $count) }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $name }}
  namespace: "{{ $root.Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" $root | nindent 4 }}
  annotations:
    {{- $user := default (dict) $ingress.annotations }}
    {{- $plat := dict }}
    {{- if eq $dest "aws" }}
    {{- $plat = include "charts-common.ingress.annotations.aws" (dict "root" $root "ingress" $ingress) | fromYaml }}
    {{- else if eq $dest "hcp" }}
    {{- $plat = include "charts-common.ingress.annotations.hcp" (dict "root" $root "ingress" $ingress "name" $name) | fromYaml }}
    {{- end }}
    {{- toYaml (merge (dict) $plat $user) | nindent 4 }}
spec:
  {{- if or (eq $dest "aws") (eq $dest "hcp") }}
  ingressClassName: {{ if eq $dest "aws" }}alb{{ else }}cce{{ end }}
  {{- else }}
  {{- with $ingress.className }}
  ingressClassName: {{ . | quote }}
  {{- end }}
  {{- end }}
  {{- if and (or (eq $dest "gcp") (eq $dest "datacenter")) $ingress.tls }}
  tls:
    {{- range $ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName | quote }}
    {{- end }}
  {{- end }}
  rules:
    {{- include "charts-common.ingress.rules" (dict "root" $root "ingress" $ingress "dest" $dest) | nindent 4 }}
---
{{- end }}
{{- end }}
{{- end -}}
