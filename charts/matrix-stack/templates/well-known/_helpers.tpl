{{- /*
Copyright 2024-2025 New Vector Ltd
Copyright 2025 Element Creations Ltd

SPDX-License-Identifier: AGPL-3.0-only
*/ -}}

{{- define "element-io.well-known-delegation.validations" }}
{{ $root := .root }}
{{- with required "element-io.well-known-delegation.validations missing context" .context -}}
{{- $messages := list }}
{{- if not $root.Values.serverName -}}
{{ $messages = append $messages "serverName is required when wellKnownDelegation.enabled=true" }}
{{- end }}
{{ $messages | toJson }}
{{- end }}
{{- end }}

{{- define "element-io.well-known-delegation.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" (dict "labels" .labels)) }}
app.kubernetes.io/component: matrix-delegation
app.kubernetes.io/name: well-known-delegation
app.kubernetes.io/instance: {{ $root.Release.Name }}-well-known-delegation
app.kubernetes.io/version: {{ include "element-io.ess-library.labels.makeSafe" $root.Values.haproxy.image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.well-known-delegation-ingress.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation-ingress.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" (dict "labels" .labels)) }}
app.kubernetes.io/component: matrix-stack-ingress
app.kubernetes.io/name: well-known-ingress
app.kubernetes.io/instance: {{ $root.Release.Name }}-well-known-ingress
app.kubernetes.io/version: {{ include "element-io.ess-library.labels.makeSafe" .image.tag }}
k8s.element.io/target-name: haproxy
k8s.element.io/target-instance: {{ $root.Release.Name }}-haproxy
{{- end }}
{{- end }}


{{- define "element-io.well-known-delegation.client" }}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.client missing context" .context -}}
{{- $config := dict -}}
{{- if $root.Values.synapse.enabled -}}
{{- $synapseHost := "" -}}
{{- if and $root.Values.synapse.gateway.enabled $root.Values.synapse.gateway.host -}}
{{- $synapseHost = (tpl $root.Values.synapse.gateway.host $root) -}}
{{- else if and $root.Values.synapse.ingress.enabled $root.Values.synapse.ingress.host -}}
{{- $synapseHost = (tpl $root.Values.synapse.ingress.host $root) -}}
{{- end -}}
{{- if $synapseHost -}}
{{- $mHomeserver := dict "base_url" (printf "https://%s" $synapseHost) -}}
{{- $_ := set $config "m.homeserver" $mHomeserver -}}
{{- else -}}
{{- required "WellKnownDelegation requires synapse.gateway.host (when synapse.gateway.enabled=true) or synapse.ingress.host (when synapse.ingress.enabled=true)" $synapseHost -}}
{{- end -}}
{{- end -}}
{{- if include "element-io.matrix-authentication-service.readyToHandleAuth" (dict "root" $root) }}
{{- $masHost := "" -}}
{{- if and $root.Values.matrixAuthenticationService.gateway.enabled $root.Values.matrixAuthenticationService.gateway.host -}}
{{- $masHost = (tpl $root.Values.matrixAuthenticationService.gateway.host $root) -}}
{{- else if and $root.Values.matrixAuthenticationService.ingress.enabled $root.Values.matrixAuthenticationService.ingress.host -}}
{{- $masHost = (tpl $root.Values.matrixAuthenticationService.ingress.host $root) -}}
{{- end -}}
{{- if $masHost -}}
{{- $msc2965 := dict "issuer" (printf "https://%s/" $masHost)
                     "account" (printf "https://%s/account" $masHost)
-}}
{{- $_ := set $config "org.matrix.msc2965.authentication" $msc2965 -}}
{{- else -}}
{{- required "WellKnownDelegation requires matrixAuthenticationService.gateway.host (when matrixAuthenticationService.gateway.enabled=true) or matrixAuthenticationService.ingress.host (when matrixAuthenticationService.ingress.enabled=true)" $masHost -}}
{{- end -}}
{{- end -}}
{{- if $root.Values.matrixRTC.enabled -}}
{{- $rtcHost := "" -}}
{{- if and $root.Values.matrixRTC.gateway.enabled $root.Values.matrixRTC.gateway.host -}}
{{- $rtcHost = (tpl $root.Values.matrixRTC.gateway.host $root) -}}
{{- else if and $root.Values.matrixRTC.ingress.enabled $root.Values.matrixRTC.ingress.host -}}
{{- $rtcHost = (tpl $root.Values.matrixRTC.ingress.host $root) -}}
{{- end -}}
{{- if $rtcHost -}}
{{- $_ := set $config "org.matrix.msc4143.rtc_foci" (list (dict "type" "livekit" "livekit_service_url" (printf "https://%s" $rtcHost))) -}}
{{- else -}}
{{- required "WellKnownDelegation requires matrixRTC.gateway.host (when matrixRTC.gateway.enabled=true) or matrixRTC.ingress.host (when matrixRTC.ingress.enabled=true)" $rtcHost -}}
{{- end -}}
{{- end -}}
{{- $additional := .additional.client | fromJson -}}
{{- tpl (toPrettyJson (mustMergeOverwrite $additional $config)) $root -}}
{{- end -}}
{{- end }}

{{- define "element-io.well-known-delegation.server" }}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.server missing context" .context -}}
{{- $config := dict -}}
{{- if $root.Values.synapse.enabled -}}
{{- $synapseHost := "" -}}
{{- if and $root.Values.synapse.gateway.enabled $root.Values.synapse.gateway.host -}}
{{- $synapseHost = (tpl $root.Values.synapse.gateway.host $root) -}}
{{- else if and $root.Values.synapse.ingress.enabled $root.Values.synapse.ingress.host -}}
{{- $synapseHost = (tpl $root.Values.synapse.ingress.host $root) -}}
{{- end -}}
{{- if $synapseHost -}}
{{- $_ := set $config "m.server" (printf "%s:443" $synapseHost) -}}
{{- else -}}
{{- required "WellKnownDelegation requires synapse.gateway.host (when synapse.gateway.enabled=true) or synapse.ingress.host (when synapse.ingress.enabled=true)" $synapseHost -}}
{{- end -}}
{{- end -}}
{{- $additional := .additional.server | fromJson -}}
{{- tpl (toPrettyJson (mustMergeOverwrite $additional $config)) $root -}}
{{- end -}}
{{- end }}

{{- define "element-io.well-known-delegation.support" }}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.support missing context" .context -}}
{{- $config := dict -}}
{{- $additional := .additional.support | fromJson -}}
{{- tpl (toPrettyJson (mustMergeOverwrite $additional $config)) $root -}}
{{- end -}}
{{- end }}

{{- define "element-io.well-known-delegation.configmap-data" -}}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.configmap-data missing context" .context -}}
client: |
  {{- (tpl (include "element-io.well-known-delegation.client" (dict "root" $root "context" .)) $root) | nindent 2 }}
server: |
  {{- (tpl (include "element-io.well-known-delegation.server" (dict "root" $root "context" .)) $root) | nindent 2 }}
support: |
  {{- (tpl (include "element-io.well-known-delegation.support" (dict "root" $root "context" .)) $root) | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "element-io.well-known.ports" -}}
{{- /*
  Port mappings for well-known service.
  Returns the numeric port value for the named port.
  
  Parameters:
    .portName: name of the port (e.g., "haproxy-wkd")
  
  Returns: numeric port value
  
  Example: {{ include "element-io.well-known.ports" (dict "portName" "haproxy-wkd") }}
*/}}
{{- $portName := .portName -}}
{{- if eq $portName "haproxy-wkd" }}8010{{- else -}}
{{- fail (printf "Port '%s' not found for service 'well-known'" $portName) -}}
{{- end -}}
{{- end -}}

