{{/*
###############################################################################
# _helpers.tpl — Shared template helpers for the soc-stack chart
# These are called with {{ include "soc-stack.xxx" . }} in other templates
###############################################################################
*/}}

{{/* Chart name */}}
{{- define "soc-stack.name" -}}
{{- .Chart.Name }}
{{- end }}

{{/* Full release name */}}
{{- define "soc-stack.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels applied to every resource */}}
{{- define "soc-stack.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
project: aws-soc-kubernetes
environment: {{ .Values.global.environment }}
owner: {{ .Values.global.owner }}
{{- end }}

{{/* Selector labels — used in matchLabels and pod selectors */}}
{{- define "soc-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "soc-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Namespace — always soc-system */}}
{{- define "soc-stack.namespace" -}}
{{ .Values.namespace.name }}
{{- end }}
