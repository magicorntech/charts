{{/*
The configMap volume entry, byte-identical across every pod spec in this
repo (deployment, statefulset, cronjobs, migrations, other-prehooks).
Split from the gcpsecrets volume entry below (rather than one combined
define) specifically so deployment.yaml can interleave its own optional
pvc-backed "storage" volume between the two, matching the original
per-file ordering (configMap, storage, gcpsecrets) exactly — a combined
define would put gcpsecrets before storage instead.
Every define in this file returns a string with no leading/trailing
newline, so a caller's `{{- with include "X" . }}{{ . | nindent N }}{{- end }}`
wrapper never emits a stray blank line whether the value is empty or not.
Takes the plain root context — no dict needed, nothing else varies.
*/}}
{{- define "charts-common.volumes.appConfig" -}}
{{- if .Values.global.configMap.enabled -}}
- name: app-config
  configMap:
    name: {{ .Values.global.configMap.name | quote }}
    items:
      - key: {{ .Values.global.configMap.fileName | quote }}
        path: {{ .Values.global.configMap.fileName | quote }}
    defaultMode: 420
{{- end -}}
{{- end -}}

{{/*
The gcpsecrets CSI volume entry — see charts-common.volumes.appConfig above
for why this is a separate define rather than combined with it.
*/}}
{{- define "charts-common.volumes.gcpSecrets" -}}
{{- if include "charts-common.gcpSecretsEnabled" . -}}
- name: gcpsecrets
  csi:
    driver: secrets-store-gke.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: {{ include "charts-common.name" . }}
{{- end -}}
{{- end -}}

{{/*
The matching volumeMounts entry for charts-common.volumes.appConfig — same
scope, same byte-for-byte duplication this collapses, and split for the
same ordering reason (see above). The deployment chart's optional
pvc-backed "storage" mount, and the statefulset chart's unconditional one,
are each still written locally by their own template (their positions
relative to this block genuinely differ and neither is worth forcing into
one shape).
*/}}
{{- define "charts-common.volumeMounts.appConfig" -}}
{{- if .Values.global.configMap.enabled -}}
- name: app-config
  readOnly: true
  mountPath: {{ .Values.global.configMap.mountPath | quote }}
  {{- if ne (toString .Values.global.configMap.useSubPath) "false" }}
  subPath: {{ .Values.global.configMap.fileName | quote }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/*
The matching volumeMounts entries for charts-common.volumes.gcpSecrets —
one per file in global.secrets.data. Built via printf+join (not a plain
`{{- range }}...{{- end }}` body) so the returned string has no
leading/trailing newline regardless of item count, matching every other
define in this file's with-wrapper contract.
*/}}
{{- define "charts-common.volumeMounts.gcpSecrets" -}}
{{- if include "charts-common.gcpSecretsEnabled" . -}}
{{- $items := list -}}
{{- range .Values.global.secrets.data -}}
{{- $items = append $items (printf "- name: gcpsecrets\n  mountPath: %s/%s\n  subPath: %s\n  readOnly: true" $.Values.global.secrets.mountPath .fileName .fileName) -}}
{{- end -}}
{{- join "\n" $items -}}
{{- end -}}
{{- end -}}

{{/*
The env vars injected from plain Kubernetes Secrets (k8sSecrets.common +
.service). Identical across every pod spec that reads
global.deployment.env. Callers `{{- include "charts-common.env.k8sSecrets" . }}`
right after their own `{{- toYaml .Values.global.deployment.env | nindent N }}`.
Built via printf+join for the same no-leading/trailing-newline reason as
charts-common.volumeMounts.gcpSecrets above.
*/}}
{{- define "charts-common.env.k8sSecrets" -}}
{{- $items := list -}}
{{- if .Values.global.k8sSecrets.common.enabled -}}
{{- range .Values.global.k8sSecrets.common.keys -}}
{{- $items = append $items (printf "- name: %s\n  valueFrom:\n    secretKeyRef:\n      name: %s\n      key: %s" .envName $.Values.global.k8sSecrets.common.secretName .key) -}}
{{- end -}}
{{- end -}}
{{- if .Values.global.k8sSecrets.service.enabled -}}
{{- range .Values.global.k8sSecrets.service.keys -}}
{{- $items = append $items (printf "- name: %s\n  valueFrom:\n    secretKeyRef:\n      name: %s\n      key: %s" .envName $.Values.global.k8sSecrets.service.secretName .key) -}}
{{- end -}}
{{- end -}}
{{- join "\n" $items -}}
{{- end -}}

{{/*
Validates global.deployment.extraVolumes / extraVolumeMounts (the opt-in,
raw pod-volume escape hatch for the Deployment/Rollout pod template: emptyDir,
projected, hostPath, any other core/v1 Volume the chart has no dedicated key
for). Fails at render time with the offending key named, instead of letting a
typo surface as an API-server rejection after the rollout has started:
  - every volume needs a `name`, and names must be unique;
  - a volume may not reuse a chart-managed name (app-config, storage,
    gcpsecrets) — those are built from configMap/pvc/secrets and a duplicate
    name would make the pod invalid;
  - every mount needs `name` + `mountPath`, and `name` must refer to an extra
    volume or to a chart-managed volume that is actually ENABLED (a mount of
    `storage` while `pvc` is off would render a mount for a volume the pod does
    not have, and the API server would reject the whole rollout).
Both keys default to [] (or are absent in older values files), in which case
this renders nothing and the pod template is byte-identical to before.
Takes the plain root context.
*/}}
{{- define "charts-common.validateExtraVolumes" -}}
{{- $reserved := list "app-config" "storage" "gcpsecrets" -}}
{{- /* The subset of the reserved volumes this release actually renders. */ -}}
{{- $managed := list -}}
{{- if .Values.global.configMap.enabled -}}{{- $managed = append $managed "app-config" -}}{{- end -}}
{{- if .Values.global.pvc.enabled -}}{{- $managed = append $managed "storage" -}}{{- end -}}
{{- if include "charts-common.gcpSecretsEnabled" . -}}{{- $managed = append $managed "gcpsecrets" -}}{{- end -}}
{{- $names := list -}}
{{- range $i, $v := (default (list) .Values.global.deployment.extraVolumes) -}}
{{- if not $v.name -}}
{{- fail (printf "global.deployment.extraVolumes[%d].name is required" $i) -}}
{{- end -}}
{{- if has $v.name $reserved -}}
{{- fail (printf "global.deployment.extraVolumes[%d].name %q collides with a chart-managed volume name (%s)" $i $v.name (join ", " $reserved)) -}}
{{- end -}}
{{- if has $v.name $names -}}
{{- fail (printf "global.deployment.extraVolumes[%d].name %q is duplicated" $i $v.name) -}}
{{- end -}}
{{- $names = append $names $v.name -}}
{{- end -}}
{{- range $i, $m := (default (list) .Values.global.deployment.extraVolumeMounts) -}}
{{- if not $m.name -}}
{{- fail (printf "global.deployment.extraVolumeMounts[%d].name is required" $i) -}}
{{- end -}}
{{- if not $m.mountPath -}}
{{- fail (printf "global.deployment.extraVolumeMounts[%d].mountPath is required" $i) -}}
{{- end -}}
{{- if not (or (has $m.name $names) (has $m.name $managed)) -}}
{{- if has $m.name $reserved -}}
{{- $needs := dict "app-config" "global.configMap.enabled" "storage" "global.pvc.enabled" "gcpsecrets" "global.secrets.enabled (destination: gcp)" -}}
{{- fail (printf "global.deployment.extraVolumeMounts[%d].name %q refers to a chart-managed volume that is not enabled (set %s, or mount an extraVolumes entry instead)" $i $m.name (get $needs $m.name)) -}}
{{- end -}}
{{- fail (printf "global.deployment.extraVolumeMounts[%d].name %q does not match any global.deployment.extraVolumes entry" $i $m.name) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
The statefulset umbrella does not support extraVolumes / extraVolumeMounts (its
pod template has a mandatory PVC via volumeClaimTemplates and its own volume
layout). Rather than silently ignoring the keys -- which looks exactly like a
working config that did nothing -- fail at render time, same precedent as
charts-common.rolloutUnsupported. Takes the plain root context.
*/}}
{{- define "charts-common.extraVolumesUnsupported" -}}
{{- if or .Values.global.deployment.extraVolumes .Values.global.deployment.extraVolumeMounts -}}
{{- fail "global.deployment.extraVolumes / extraVolumeMounts are not supported by the statefulset chart (its pod template has a mandatory PVC and its own volume layout); remove them, or use the deployment chart" -}}
{{- end -}}
{{- end -}}
