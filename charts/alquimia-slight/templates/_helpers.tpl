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

{{- define "alquimia-slight.vlm.modelPvcName" -}}
{{- if .Values.model.persistence.existingClaim -}}
{{- .Values.model.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-models" (include "alquimia-slight.vlm.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.vlm.downloaderFullname" -}}
{{- printf "%s-model-downloader" (include "alquimia-slight.vlm.fullname" .) -}}
{{- end -}}

{{/* Mount path of the model volume inside the container. */}}
{{- define "alquimia-slight.vlm.modelMountPath" -}}
{{- default "/models" .Values.model.mountPath -}}
{{- end -}}

{{/* Local model subdirectory. If unset, it is derived from servedName. */}}
{{- define "alquimia-slight.vlm.modelLocalDir" -}}
{{- if .Values.model.localDir -}}
{{- .Values.model.localDir -}}
{{- else -}}
{{- .Values.model.servedName | replace "/" "-" | lower -}}
{{- end -}}
{{- end -}}

{{/* Absolute path to the model inside the container (mountPath + localDir). */}}
{{- define "alquimia-slight.vlm.modelFullPath" -}}
{{- printf "%s/%s" (include "alquimia-slight.vlm.modelMountPath" .) (include "alquimia-slight.vlm.modelLocalDir" .) -}}
{{- end -}}

{{/* HF repo id to download; defaults to model.servedName. */}}
{{- define "alquimia-slight.vlm.downloader.repoId" -}}
{{- default .Values.model.servedName .Values.model.downloader.repoId -}}
{{- end -}}

{{/* Downloader target subdirectory; defaults to modelLocalDir. */}}
{{- define "alquimia-slight.vlm.downloader.targetSubdir" -}}
{{- default (include "alquimia-slight.vlm.modelLocalDir" .) .Values.model.downloader.targetSubdir -}}
{{- end -}}

{{- define "alquimia-slight.web.fullname" -}}
{{- printf "%s-web" (include "alquimia-slight.fullname" .) -}}
{{- end -}}

{{- define "alquimia-slight.web.publicPort" -}}
{{- if and (eq .Values.web.service.type "NodePort") .Values.web.service.nodePort -}}
{{- .Values.web.service.nodePort -}}
{{- else -}}
{{- .Values.web.service.port -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.bff.publicPort" -}}
{{- if and (eq .Values.bff.service.type "NodePort") .Values.bff.service.nodePort -}}
{{- .Values.bff.service.nodePort -}}
{{- else -}}
{{- .Values.bff.service.port -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.globalHost" -}}
{{- if .Values.global.host -}}
{{- .Values.global.host -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.web.viteBffUrl" -}}
{{- if .Values.web.config.viteBffUrl -}}
{{- .Values.web.config.viteBffUrl -}}
{{- else if include "alquimia-slight.globalHost" . -}}
{{- printf "http://%s:%v" (include "alquimia-slight.globalHost" .) (include "alquimia-slight.bff.publicPort" .) -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.web.mediamtxPublicHost" -}}
{{- if .Values.web.config.mediamtxPublicHost -}}
{{- .Values.web.config.mediamtxPublicHost -}}
{{- else if include "alquimia-slight.globalHost" . -}}
{{- include "alquimia-slight.globalHost" . -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.web.mediamtxWebrtcAllowOrigins" -}}
{{- if .Values.web.config.mediamtxWebrtcAllowOrigins -}}
{{- .Values.web.config.mediamtxWebrtcAllowOrigins -}}
{{- else if include "alquimia-slight.globalHost" . -}}
{{- printf "http://%s:%v" (include "alquimia-slight.globalHost" .) (include "alquimia-slight.web.publicPort" .) -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.web.mediamtxWebrtcAdditionalHosts" -}}
{{- if .Values.web.config.mediamtxWebrtcAdditionalHosts -}}
{{- .Values.web.config.mediamtxWebrtcAdditionalHosts -}}
{{- else if include "alquimia-slight.globalHost" . -}}
{{- include "alquimia-slight.globalHost" . -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.mediamtx.fullname" -}}
{{- printf "%s-mediamtx" (include "alquimia-slight.fullname" .) -}}
{{- end -}}

{{- define "alquimia-slight.mediamtx.namespace" -}}
{{- default .Release.Namespace .Values.mediamtx.namespace -}}
{{- end -}}

{{- define "alquimia-slight.mediamtx.authHttpAddress" -}}
{{- $ns := default .Release.Namespace .Values.mediamtx.auth.bffNamespace -}}
{{- $path := default "/internal/media/auth" .Values.mediamtx.auth.path -}}
{{- $computed := printf "http://%s.%s.svc.cluster.local:%v%s" (include "alquimia-slight.bff.fullname" .) $ns .Values.bff.service.port $path -}}
{{- default $computed .Values.mediamtx.auth.httpAddress -}}
{{- end -}}

{{/* Args: (list $root "api"|"rtsp"|"webrtc"|...): NodePort if Service is NodePort, else service port. */}}
{{- define "alquimia-slight.mediamtx.publicPort" -}}
{{- $root := index . 0 -}}
{{- $portName := index . 1 -}}
{{- range $root.Values.mediamtx.service.ports -}}
{{- if eq .name $portName -}}
{{- if and (eq $root.Values.mediamtx.service.type "NodePort") .nodePort -}}
{{- .nodePort -}}
{{- else -}}
{{- .port -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.bff.mediaGatewayApiBaseUrl" -}}
{{- if .Values.bff.config.mediaGateway.apiBaseUrl -}}
{{- .Values.bff.config.mediaGateway.apiBaseUrl -}}
{{- else if and (include "alquimia-slight.globalHost" .) .Values.mediamtx.enabled -}}
{{- printf "http://%s:%v" (include "alquimia-slight.globalHost" .) (include "alquimia-slight.mediamtx.publicPort" (list . "api")) -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.bff.mediaGatewayEngineRtspBaseUrl" -}}
{{- if .Values.bff.config.mediaGateway.engineRtspBaseUrl -}}
{{- .Values.bff.config.mediaGateway.engineRtspBaseUrl -}}
{{- else if and (include "alquimia-slight.globalHost" .) .Values.mediamtx.enabled -}}
{{- printf "rtsp://%s:%v" (include "alquimia-slight.globalHost" .) (include "alquimia-slight.mediamtx.publicPort" (list . "rtsp")) -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.bff.mediaGatewayPublicWebrtcBaseUrl" -}}
{{- if .Values.bff.config.mediaGateway.publicWebrtcBaseUrl -}}
{{- .Values.bff.config.mediaGateway.publicWebrtcBaseUrl -}}
{{- else if and (include "alquimia-slight.globalHost" .) .Values.mediamtx.enabled -}}
{{- printf "http://%s:%v" (include "alquimia-slight.globalHost" .) (include "alquimia-slight.mediamtx.publicPort" (list . "webrtc")) -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.engine.mediaGatewayPlaybackBaseUrl" -}}
{{- if .Values.engine.config.media.playbackBaseUrl -}}
{{- .Values.engine.config.media.playbackBaseUrl -}}
{{- else if and (include "alquimia-slight.globalHost" .) .Values.mediamtx.enabled -}}
{{- printf "rtsp://%s:%v" (include "alquimia-slight.globalHost" .) (include "alquimia-slight.mediamtx.publicPort" (list . "playback")) -}}
{{- end -}}
{{- end -}}

{{/* MediaMTX WebRTC: when allowOrigins/additionalHosts are "*" or empty and global.host is set, concrete lists are built. */}}
{{- define "alquimia-slight.mediamtx.webrtcAllowOrigins" -}}
{{- $v := .Values.mediamtx.webrtc.allowOrigins -}}
{{- if and $v (ne $v "*") -}}
{{- $v -}}
{{- else if include "alquimia-slight.globalHost" . -}}
{{- printf "http://%s:%v,http://127.0.0.1:5173,http://localhost:5173,http://127.0.0.1:8080,http://localhost:8080" (include "alquimia-slight.globalHost" .) (include "alquimia-slight.web.publicPort" .) -}}
{{- else -}}
{{- default "*" $v -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.mediamtx.webrtcAdditionalHosts" -}}
{{- $v := .Values.mediamtx.webrtc.additionalHosts -}}
{{- if and $v (ne $v "*") -}}
{{- $v -}}
{{- else if include "alquimia-slight.globalHost" . -}}
{{- printf "%s,127.0.0.1,localhost" (include "alquimia-slight.globalHost" .) -}}
{{- else -}}
{{- default "*" $v -}}
{{- end -}}
{{- end -}}

{{- define "alquimia-slight.otel.secretName" -}}
{{- printf "%s-otel" (include "alquimia-slight.fullname" .) -}}
{{- end -}}