{{- define "alquimia-slight.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "alquimia-slight.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.labels" -}}
app.kubernetes.io/name: {{ include "alquimia-slight.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/part-of: alquimia-vision
app.kubernetes.io/component: platform
{{- end -}}

{{- define "alquimia-slight.selectorLabels" -}}
app.kubernetes.io/name: {{ include "alquimia-slight.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "alquimia-slight.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (printf "%s-sa" (include "alquimia-slight.fullname" .)) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.engine.fullname" -}}
{{- printf "%s-engine" (include "alquimia-slight.fullname" .) -}}
{{- end -}}

{{- define "alquimia-slight.bff.fullname" -}}
{{- printf "%s-bff" (include "alquimia-slight.fullname" .) -}}
{{- end -}}

{{- define "alquimia-slight.postgres.fullname" -}}
{{- printf "%s-postgres" (include "alquimia-slight.fullname" .) -}}
{{- end -}}

{{- define "alquimia-slight.minio.fullname" -}}
{{- printf "%s-minio" (include "alquimia-slight.fullname" .) -}}
{{- end -}}

{{- define "alquimia-slight.vlm.fullname" -}}
{{- printf "%s-vlm" (include "alquimia-slight.fullname" .) -}}
{{- end -}}

{{- define "alquimia-slight.web.fullname" -}}
{{- printf "%s-web" (include "alquimia-slight.fullname" .) -}}
{{- end -}}