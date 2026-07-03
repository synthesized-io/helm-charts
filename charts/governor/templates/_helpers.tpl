{{/*
Chart name, truncated to 63 chars.
*/}}
{{- define "governor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels applied to all resources.
*/}}
{{- define "governor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "governor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end }}

{{/*
Resolve worker values with backward-compatible fallback from legacy "agent" key.

Merge order: `worker:` (with chart defaults) < legacy `agent:` overrides.
Customer's `agent:` overrides take precedence for any field they specify.
This means a customer with only legacy overrides keeps the values they set
explicitly, while picking up new defaults for everything else.

For the case of a customer setting BOTH `worker.X` and `agent.X` for
the same field, `agent.X` wins.

Usage: {{- $w := include "governor.workerValues" . | fromYaml }}
*/}}
{{- define "governor.workerValues" -}}
{{- $w := .Values.worker | default dict -}}
{{- $a := .Values.agent | default dict -}}
{{- mustMergeOverwrite (deepCopy $w) (deepCopy $a) | toYaml -}}
{{- end -}}

{{/*
Labels for a component: app:<name> + selectorLabels.
Usage: {{- include "governor.component.labels" (list $comp .) | nindent N }}
*/}}
{{- define "governor.component.labels" -}}
{{- $comp := index . 0 -}}
{{- $root := index . 1 -}}
app: {{ $comp.name }}
{{ include "governor.selectorLabels" $root }}
{{- end }}

{{/*
envFrom (configmap + secret) and optional env (secretEnv) for a component container.
Usage: {{- include "governor.component.envSources" $comp | nindent 10 }}
*/}}
{{- define "governor.component.envSources" -}}
{{- $comp := . -}}
envFrom:
  - configMapRef:
      name: {{ $comp.name }}-configmap
  - secretRef:
      name: {{ $comp.name }}-secret
{{- if $comp.container.secretEnv }}
env:
  {{- range $comp.container.secretEnv }}
  - name: {{ .name }}
    valueFrom:
      secretKeyRef:
        name: {{ .valueFrom.secretKeyRef.name }}
        key: {{ .valueFrom.secretKeyRef.key }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
nodeSelector, affinity, and tolerations from chart-wide values.
Usage: {{- include "governor.component.schedulingConstraints" . | nindent 6 }}
*/}}
{{- define "governor.component.schedulingConstraints" -}}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
