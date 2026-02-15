{{- /*
Copyright 2026 Element Creations Ltd

SPDX-License-Identifier: AGPL-3.0-only
*/ -}}

{{- $root := .root }}
{{- with required "hookshot/config-overrides.yaml.tpl missing context" .context }}
{{- $context := . -}}
{{- $hookshotHasHost := false -}}
{{- if and .gateway.enabled .gateway.host -}}
{{- $hookshotHasHost = true -}}
{{- else if and .ingress.enabled .ingress.host -}}
{{- $hookshotHasHost = true -}}
{{- end -}}
bridge:
  domain: "{{ tpl $root.Values.serverName $root }}"
{{- if $root.Values.synapse.enabled }}
  url: "http://{{ include "element-io.synapse.internal-hostport" (dict "root" $root "context" (dict "targetProcessType" "")) }}"
{{- end }}
  port: 9993
  bindAddress: 0.0.0.0

passFile: /secrets/{{
                include "element-io.ess-library.init-secret-path" (
                      dict "root" $root
                      "context" (dict
                        "secretPath" "hookshot.passkey"
                        "initSecretKey" "HOOKSHOT_RSA_PASSKEY"
                        "defaultSecretName" (include "element-io.hookshot.secret-name" (dict "root" $root "context" $context))
                        "defaultSecretKey" "RSA_PASSKEY"
                      )
                    ) }}

{{- if .enableEncryption }}
encryption:
 storagePath: /storage
{{- end }}

cache:
  redisUri: "redis://{{ $root.Release.Name }}-redis.{{ $root.Release.Namespace }}.svc.{{ $root.Values.clusterDomain }}:6379"

logging:
  level: {{ .logging.level }}

metrics:
  enabled: true

listeners:
  - port: 7775
    bindAddress: 0.0.0.0
    resources:
      - webhooks
{{- if and $root.Values.synapse.enabled (not $hookshotHasHost) }}
    prefix: "/_matrix/hookshot"
{{- end }}
  - port: 7777
    bindAddress: 0.0.0.0
    resources:
      - metrics
  - port: 7778
    bindAddress: 0.0.0.0
    resources:
      - widgets
{{- if and $root.Values.synapse.enabled (not $hookshotHasHost) }}
    prefix: "/_matrix/hookshot"
{{- end }}

generic:
{{- $hookshotHost := "" -}}
{{- if and .gateway.enabled .gateway.host -}}
{{- $hookshotHost = (tpl .gateway.host $root) -}}
{{- else if and .ingress.enabled .ingress.host -}}
{{- $hookshotHost = (tpl .ingress.host $root) -}}
{{- end }}
{{- $synapseHost := "" -}}
{{- if and $root.Values.synapse.gateway.enabled $root.Values.synapse.gateway.host -}}
{{- $synapseHost = (tpl $root.Values.synapse.gateway.host $root) -}}
{{- else if and $root.Values.synapse.ingress.enabled $root.Values.synapse.ingress.host -}}
{{- $synapseHost = (tpl $root.Values.synapse.ingress.host $root) -}}
{{- end }}
{{ if $hookshotHost }}
  urlPrefix: https://{{ $hookshotHost }}/webhook
{{ else if $root.Values.synapse.enabled }}
  urlPrefix: https://{{ $synapseHost }}/_matrix/hookshot/webhook
{{ end }}

widgets:
{{- if $hookshotHost }}
  publicUrl: https://{{ $hookshotHost }}/widgetapi/v1/static
{{ else if $root.Values.synapse.enabled }}
  publicUrl: https://{{ $synapseHost }}/_matrix/hookshot/widgetapi/v1/static
{{ end }}

{{- end -}}
