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
