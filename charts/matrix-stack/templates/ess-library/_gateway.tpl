{{- /*
Copyright 2025-2026 Element Creations Ltd

SPDX-License-Identifier: AGPL-3.0-only
*/ -}}

{{- define "element-io.ess-library.gateway.annotations" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.gateway.annotations missing context" .context -}}
{{- $annotations := .extraAnnotations | default dict -}}
{{- with required "element-io.ess-library.gateway.annotations context missing gateway" .gateway }}
{{- $annotations = mustMergeOverwrite $annotations ($root.Values.gateway.annotations | deepCopy) -}}
{{- $annotations = mustMergeOverwrite $annotations (.annotations | deepCopy) -}}
{{- with $annotations -}}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "element-io.ess-library.gateway-service.annotations" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.gateway-service.annotations missing context" .context -}}
{{- $gatewayService := .service -}}
{{- $annotations := .extraAnnotations | default dict -}}
{{- $annotations = mustMergeOverwrite $annotations ($root.Values.gateway.service.annotations | deepCopy) -}}
{{- if $gatewayService.annotations }}
{{- $annotations = mustMergeOverwrite $annotations ($gatewayService.annotations | deepCopy) -}}
{{- end -}}
{{- with $annotations -}}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "element-io.ess-library.gateway-service.spec" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.gateway-service.spec missing context" .context -}}
{{- $headlessService := .headlessService | default false -}}
{{- $gatewayService := .service -}}
{{ with $gatewayService.type | default $root.Values.gateway.service.type }}
type: {{ . }}
{{ if and $headlessService (eq . "ClusterIP") }}
clusterIP: None
{{- end }}
{{- if (list "LoadBalancer" "NodePort") | has . }}
externalTrafficPolicy: {{ $gatewayService.externalTrafficPolicy | default $root.Values.gateway.service.externalTrafficPolicy }}
{{- end }}
{{- end }}
{{- if hasKey $gatewayService "externalIPs" }}
externalIPs: {{ $gatewayService.externalIPs | toYaml | nindent 4 }}
{{- end }}
internalTrafficPolicy: {{ $gatewayService.internalTrafficPolicy | default $root.Values.gateway.service.internalTrafficPolicy }}
ipFamilyPolicy: PreferDualStack
{{- end }}
{{- end }}

{{- define "element-io.ess-library.gateway.parentRefs" -}}
{{- $root := .root -}}
{{- if not (hasKey . "context") -}}
{{- fail "element-io.ess-library.gateway.parentRefs missing context" -}}
{{- end }}
{{- with .context -}}
parentRefs:
{{- if kindIs "slice" . }}
{{- toYaml . | nindent 2 }}
{{- else }}
  - group: {{ .group | default "gateway.networking.k8s.io" | quote }}
    kind: {{ .kind | default "Gateway" | quote }}
    name: {{ required "parentRefs.name is required" .name | quote }}
    {{- if .namespace }}
    namespace: {{ .namespace | quote }}
    {{- end }}
    {{- if .sectionName }}
    sectionName: {{ .sectionName | quote }}
    {{- end }}
    {{- if .port }}
    port: {{ .port }}
    {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
