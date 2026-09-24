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
The Application Gateway for Containers (AGC) alb.networking.azure.io
annotations. Dict: {root, ingress, name}. Two ways to bind an Ingress to
an AGC frontend, mutually exclusive (validated in
charts-common.ingress.validateAzure below): `albId` (bring-your-own — an
already-provisioned Application Gateway for Containers resource ID), or
`albName`+`albNamespace` (managed — the ALB Controller provisions the
Azure resources itself, matching the AWS/aws-load-balancer-controller
model this chart otherwise follows). `albFrontend` defaults to this
Ingress object's own name — deterministic, so the port-80 redirect
Ingress (see charts-common.ingress.redirectAzure below) can share the
exact same frontend without a second value to keep in sync, and so the
existing position-based Ingress naming invariant (never rename on
`enabled` toggle) extends to the frontend name too.
*/}}
{{- define "charts-common.ingress.annotations.azure" -}}
{{- $ingress := .ingress -}}
{{- if $ingress.albId }}
alb.networking.azure.io/alb-id: {{ $ingress.albId | quote }}
{{- else }}
alb.networking.azure.io/alb-name: {{ $ingress.albName | quote }}
alb.networking.azure.io/alb-namespace: {{ $ingress.albNamespace | quote }}
{{- end }}
alb.networking.azure.io/alb-frontend: {{ $ingress.albFrontend | default .name | quote }}
{{- end -}}

{{/*
Fails loudly on an azure ingress[] entry that's missing what AGC actually
needs, or that silently asks for something AGC's Ingress API cannot do.
Dict: {ingress, index, name}.

scheme "internal" and wafId are hard failures, not silently-ignored
no-ops, on purpose — unlike the other AWS-only keys (sslPolicy,
listenPorts, idleTimeout, lbId, lbOrder, certificateId, healthcheckPath),
which just don't apply here and are documented as such, these two are
security-relevant: silently exposing a WAF-less public ingress where the
author asked for internal-only or WAF-protected would be a real, invisible
regression, not a cosmetic no-op.
*/}}
{{- define "charts-common.ingress.validateAzure" -}}
{{- $ingress := .ingress -}}
{{- $name := .name -}}
{{- if not (or $ingress.albId $ingress.albName) -}}
{{- fail (printf "global.ingress[%d] (%s): azure requires either albId (bring-your-own) or albName (+ albNamespace, managed deployment)" .index $name) -}}
{{- end -}}
{{- if and $ingress.albName (not $ingress.albNamespace) -}}
{{- fail (printf "global.ingress[%d] (%s): albName requires albNamespace" .index $name) -}}
{{- end -}}
{{- if and $ingress.albId (not $ingress.albFrontend) -}}
{{- fail (printf "global.ingress[%d] (%s): albId (bring-your-own) requires albFrontend — the pre-existing Application Gateway for Containers frontend name in Azure" .index $name) -}}
{{- end -}}
{{- if eq $ingress.scheme "internal" -}}
{{- fail (printf "global.ingress[%d] (%s): Application Gateway for Containers has no private/internal frontend — expose this privately via an internal Azure Load Balancer Service instead (global.service.type: LoadBalancer + the service.beta.kubernetes.io/azure-load-balancer-internal: \"true\" annotation)" .index $name) -}}
{{- end -}}
{{- if $ingress.wafId -}}
{{- fail (printf "global.ingress[%d] (%s): wafId has no effect on azure — WAF on Application Gateway for Containers is only exposed via the Gateway API, not the Ingress API this chart uses" .index $name) -}}
{{- end -}}
{{- end -}}

{{/*
The HTTP->HTTPS redirect pair for an azure ingress[] entry: an
IngressExtension (AGC's own CRD for anything the plain Ingress API can't
express) carrying one requestRedirect rule per host, plus a second,
port-80 Ingress that references it via the alb-ingress-extension
annotation — AGC's Ingress API has no single-annotation redirect the way
aws-load-balancer-controller's ssl-redirect does, this is the two-object
shape its own docs require. Shares $name's exact annotations (so it binds
to the identical alb-frontend — see charts-common.ingress.annotations.azure
above) and the identical `rules:` block as the main Ingress, just with no
`tls:` — same "AGC still expects the backend routing declared" shape its
own example carries. Dict: {root, ingress, dest, name, annotations}.
*/}}
{{- define "charts-common.ingress.redirectAzure" -}}
{{- $root := .root -}}
{{- $ingress := .ingress -}}
{{- $name := .name -}}
apiVersion: alb.networking.azure.io/v1
kind: IngressExtension
metadata:
  name: {{ $name }}-https-redirect
  namespace: "{{ $root.Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" $root | nindent 4 }}
spec:
  rules:
    {{- range $ingress.hosts }}
    - host: {{ .host | quote }}
      requestRedirect:
        scheme: https
        statusCode: 301
    {{- end }}

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $name }}-http
  namespace: "{{ $root.Release.Namespace }}"
  labels:
    {{- include "charts-common.labels" $root | nindent 4 }}
  annotations:
    {{- .annotations | nindent 4 }}
    alb.networking.azure.io/alb-ingress-extension: {{ $name }}-https-redirect
spec:
  ingressClassName: azure-alb-external
  rules:
    {{- include "charts-common.ingress.rules" (dict "root" $root "ingress" $ingress "dest" .dest) | nindent 4 }}
{{- end -}}

{{/*
Resolves an Ingress rule's backend service name — the plain release name,
unless P7's Argo Rollouts is active AND this specific
global.ingress[] entry opted in via `rolloutService` (empty by default —
an ingress entry not routing rollout traffic keeps pointing at the plain
release-named Service, same as before P7 existed). Dict: {root, ingress}.
Ported from the source branch's own modern (k8s >=1.19 `service:`, not
the legacy `serviceName:`) shape only — the legacy branch is dead code
below this chart's own 1.25+ floor, same reasoning as charts-common.ingress
itself already dropping it.
*/}}
{{- define "charts-common.ingress.rules.serviceName" -}}
{{- $root := .root -}}
{{- $ingress := .ingress -}}
{{- if and $root.Values.global.rollout.enabled $ingress.rolloutService -}}
  {{- if eq $root.Values.global.rollout.strategyType "canary" -}}
    {{- if eq $ingress.rolloutService "preview" -}}
{{- $root.Values.global.rollout.canary.canaryServiceName | default (printf "%s-preview" (include "charts-common.name" $root)) -}}
    {{- else -}}
{{- include "charts-common.name" $root -}}
    {{- end -}}
  {{- else if eq $root.Values.global.rollout.strategyType "blueGreen" -}}
    {{- if eq $ingress.rolloutService "active" -}}
{{- $root.Values.global.rollout.blueGreen.activeService | default (printf "%s-active" (include "charts-common.name" $root)) -}}
    {{- else if eq $ingress.rolloutService "preview" -}}
{{- $root.Values.global.rollout.blueGreen.previewService | default (printf "%s-preview" (include "charts-common.name" $root)) -}}
    {{- else -}}
{{- include "charts-common.name" $root -}}
    {{- end -}}
  {{- else -}}
{{- include "charts-common.name" $root -}}
  {{- end -}}
{{- else -}}
{{- include "charts-common.name" $root -}}
{{- end -}}
{{- end -}}

{{/*
The rules: block. Identical across all 4 destinations except hcp's
per-path `property:` block. Dict: {root, ingress, dest}. k8s 1.25+ only
(the pre-1.18/1.19 semverCompare branches this repo carried are gone —
dead code below this chart's own README-declared floor). The backend
port always comes from `global.service.ports.one` unless this specific
ingress entry sets its own `servicePortName` — every entry has hardcoded
"one" today, so unset stays byte-identical.
*/}}
{{- define "charts-common.ingress.rules" -}}
{{- $root := .root -}}
{{- range $ingress := list .ingress }}
{{- range $hIdx, $host := $ingress.hosts }}
{{- if $hIdx }}
{{ end -}}
- host: {{ $host.host | quote }}
  http:
    paths:
      {{- range $host.paths }}
      - path: {{ .path | quote }}
        {{- if .pathType }}
        pathType: {{ .pathType | quote }}
        {{- end }}
        backend:
          service:
            name: {{ include "charts-common.ingress.rules.serviceName" (dict "root" $root "ingress" $ingress) }}
            port:
              number: {{ (index $root.Values.global.service.ports ($ingress.servicePortName | default "one")).outer }}
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
    {{- else if eq $dest "azure" }}
    {{- include "charts-common.ingress.validateAzure" (dict "ingress" $ingress "index" $index "name" $name) }}
    {{- $plat = include "charts-common.ingress.annotations.azure" (dict "ingress" $ingress "name" $name) | fromYaml }}
    {{- end }}
    {{- $mergedAnnotations := merge (dict) $plat $user }}
    {{- toYaml $mergedAnnotations | nindent 4 }}
spec:
  {{- if or (eq $dest "aws") (eq $dest "hcp") (eq $dest "azure") }}
  ingressClassName: {{ if eq $dest "aws" }}alb{{ else if eq $dest "hcp" }}cce{{ else }}azure-alb-external{{ end }}
  {{- else }}
  {{- with $ingress.className }}
  ingressClassName: {{ . | quote }}
  {{- end }}
  {{- end }}
  {{- if and (or (eq $dest "gcp") (eq $dest "datacenter") (eq $dest "azure")) $ingress.tls }}
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
{{ if and (eq $dest "azure") $ingress.tls (ne (toString $ingress.sslRedirect) "false") -}}
{{- include "charts-common.ingress.redirectAzure" (dict "root" $root "ingress" $ingress "dest" $dest "name" $name "annotations" (toYaml $mergedAnnotations)) }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
