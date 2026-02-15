<!--
Copyright 2025 New Vector Ltd
Copyright 2025-2026 Element Creations Ltd

SPDX-License-Identifier: AGPL-3.0-only
-->

# Advanced setup

**Contents**
- [Values documentation](#values-documentation)
- [Using a dedicated PostgreSQL database](#using-a-dedicated-postgresql-database)
- [Configuring the storage path when using k3s](#configuring-the-storage-path-when-using-k3s)
- [Monitoring](#monitoring)
- [Gateway API](#gateway-api)
- [Components Configuration](#configuration)
   - [Configuring Element Web](#configuring-element-web)
   - [Configuring Hookshot](#configuring-hookshot)
   - [Configuring Synapse](#configuring-synapse)
   - [Configuring Matrix Authentication Service](#configuring-matrix-authentication-service)
   - [Configuring Matrix RTC](#configuring-matrix-rtc)
     - [Networking](#networking)

## Values documentation

 The Helm chart values documentation is available in:

- The GitHub repository [values files](https://github.com/element-hq/ess-helm/blob/main/charts/matrix-stack/values.yaml).
- The chart [README](https://github.com/element-hq/ess-helm/blob/main/charts/matrix-stack/README.md).
- [Artifacthub.io](https://artifacthub.io/packages/helm/element-server-suite-community/matrix-stack).

Configuration samples are available [in the GitHub repository](https://github.com/element-hq/ess-helm/tree/main/charts/matrix-stack/ci).

### Using a dedicated PostgreSQL database

Each of these databases can be on independent instances or separate databases on the same PostgreSQL instance. They must not be in the same database in the same PostgreSQL instance.

You need to create 2 databases:

- For Synapse [https://element-hq.github.io/synapse/latest/postgres.html](https://element-hq.github.io/synapse/latest/postgres.html#set-up-database)

- For MAS [https://element-hq.github.io/matrix-authentication-service/setup/database.html](https://element-hq.github.io/matrix-authentication-service/setup/database.html)

To configure your own PostgreSQL Database in your installation, copy the file `charts/matrix-stack/ci/fragments/quick-setup-postgresql.yaml` to `postgresql.yaml` in your ESS configuration values directory and configure it accordingly.

## Configuring the storage path when using K3s

K3s by default deploys the storage in `/var/lib/rancher/k3s/storage/`. If you want to change the path, you will have to run the K3s setup with the parameter `--default-local-storage-path <your path>`.

## Configuring Traefik ingress timeouts when using K3s

If you are experiencing timeouts when uploading large files to ESS, you will want to customize Traefik timeouts creating the file `traefik-config.yaml` in `/var/lib/rancher/k3s/server/manifests`. If the file already exists because you have configured custom ports for Traefik, add the example below to the existing file.

```yml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    ports:
      web:
        transport:
          respondingTimeouts:
            readTimeout: "<timeout in seconds>s"
            writeTimeout: "<timeout in seconds>s"
            idleTimeout: "<timeout in seconds>s"
      websecure:
        transport:
          respondingTimeouts:
            readTimeout: "<timeout in seconds>s"
            writeTimeout: "<timeout in seconds>s"
            idleTimeout: "<timeout in seconds>s"
```

The above values correspond to the Traefik installation managed by K3s. If you are installing Traefik by other means, the exact structure of the configuration may differ.

## Monitoring

The chart provides `ServiceMonitor` automatically to monitor the metrics exposed by ESS Community.

If your cluster has [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) or [Victoria Metrics Operator](https://docs.victoriametrics.com/operator/) installed, the metrics will automatically be scraped.

## Gateway API

This chart supports the Kubernetes Gateway API in addition to the traditional Ingress API. The Gateway API provides a more powerful and flexible model for managing external access to Kubernetes services.

### Requirements

- Kubernetes 1.29+ (for stable Gateway API v1 support)
- A [GatewayClass](https://gateway-api.sigs.k8s.io/concepts/api-overview/#gatewayclass) deployed in your cluster (e.g., from NGINX Gateway, Envoy Gateway, or another Gateway API controller)

### Enabling Gateway API

To use Gateway API instead of (or in addition to) Ingress, you must first ensure a Gateway exists in your cluster for the chart to bind to. Consult your Gateway API controller's documentation for instructions on creating a GatewayClass and Gateway.

Once a Gateway is available, you can enable HTTPRoute resources for individual components by setting the `gateway.className` and component-specific `gateway.host` values:

```yaml
# Global Gateway API configuration
gateway:
  className: my-gateway-class  # Name of the GatewayClass your Gateway uses

# Enable Gateway API for individual components
synapse:
  gateway:
    host: synapse.example.com

elementWeb:
  gateway:
    host: element.example.com
```

### Gateway API with TLS

By default, the chart assumes TLS termination is handled by the Gateway. You can specify TLS certificates for HTTPRoute resources:

```yaml
synapse:
  gateway:
    host: synapse.example.com
    tlsSecret: my-synapse-cert  # Reference to a Secret containing the TLS certificate and key

elementWeb:
  gateway:
    host: element.example.com
    tlsSecret: my-element-cert
```

The referenced Secret must exist in the same namespace as the Helm release and contain `tls.crt` and `tls.key` keys.

### Coexisting with Ingress

You can use both Ingress and Gateway API simultaneously. Components can have both `ingress.host` and `gateway.host` configured:

```yaml
synapse:
  ingress:
    host: synapse-ingress.example.com  # Uses Ingress
  gateway:
    host: synapse-gateway.example.com  # Uses Gateway API

elementWeb:
  ingress:
    host: element-ingress.example.com
  gateway:
    host: element-gateway.example.com
```

### Gateway API Annotations

You can add Gateway API-specific annotations to HTTPRoute resources using the same mechanism as Ingress:

```yaml
# Global Gateway annotations
gateway:
  annotations:
    my-annotation: my-value

# Component-specific Gateway annotations
synapse:
  gateway:
    annotations:
      component-specific: value
```

### More Information

For more details on Kubernetes Gateway API, see the [official Gateway API documentation](https://gateway-api.sigs.k8s.io/).

## Configuration

ESS Community allows you to easily configure its individual components. You basically have to create a values file for each component in which you specify your custom configuration. Below you find sections for each component.

Some component configuration options are controlled by the chart.
These configuration options usually fall into one of the following categories:
* Required configuration options, so that the chart can validate that they've been set at install time rather than the application failing at runtime.
* Configuration options that are required to "wire-up" the component either to its dependencies or other configured components in the chart.
* Configuration options that need to be consistently set in several places.

Attempting to change these configuration options by the mechanism described below will appear to have no effect.

**If you have created new values files for custom configuration, make sure to apply them by passing them with the helm upgrade command (see [Setting up the stack](#setting-up-the-stack)).**

### Configuring Element Web

Element Web configuration is written in JSON. The documentation can be found in the [Element Web repository.](https://github.com/element-hq/element-web/blob/develop/docs/config.md)

To configure Element Web, create a values file with the JSON config to inject as a string under “additional”:

```yml
elementWeb:
  additional:
    user-config.json: |
      {
        "some": "settings"
      }
```

### Configuring Hookshot

Hookshot is disabled by default and needs to be explicitly enabled.

```yml
hookshot:
  enabled: true
```

Hookshot configuration is written in YAML. The documentation can be found in the [Hookshot website](https://matrix-org.github.io/matrix-hookshot/latest/setup/sample-configuration.html)

Below is an example configuration enabling generic webhooks:

```yml
hookshot:
  additional:
    user-config.yaml:
      config: |
        generic:
          enabled: true
          allowJsTransformationFunctions: false
          waitForComplete: true
          enableHttpGet: false
```

Note that by default, Hookshot will be setup behind Synapse hostname unless configured with a dedicated ingress :

```yml
hookshot:
  ingress:
    host: <hookshot domain name>
```

### Configuring Synapse

Synapse configuration is written in YAML. The documentation can be found [here](https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html).

```yml
synapse:
  additional:
    user-config.yaml:
      config: |
        # Add your settings below, taking care of the spacing indentation
        some: settings
```

One common Synapse configuration option that can't be set by this mechanism is `max_upload_size`.
This is controlled by `synapse.media.maxUploadSize`.
This is so that Ingress controller specific annotations can be adjusted to match.

### Configuring Matrix Authentication Service

Matrix Authentication Service configuration is written in YAML. The documentation can be found [here](https://element-hq.github.io/matrix-authentication-service/reference/configuration.html).

```yml
matrixAuthenticationService:
  additional:
    user-config.yaml:
      config: |
        # Add your settings below, taking care of the spacing indentation
        some: settings
```

While Matrix Authentication Service supports registration tokens, by default they still require users to validate an email address as part of the registration flow. To remove this requirement you can do:

```yml
matrixAuthenticationService:
  additional:
    auth.yaml:
      config: |
        account:
          password_registration_enabled: true
          registration_token_required: true
          password_registration_email_required: false
          password_change_allowed: true
```

`account.password_registration_email_required` must **never** be set to `false` on a publicly federating deployment without restrictions like `registration_token_required: true` or your deployment will be abused and become a source of spam.

### Configuring Matrix RTC

Matrix RTC SFU configuration is written in YAML. The documentation can be found [here](https://docs.livekit.io/home/self-hosting/deployment/).

```yml
matrixRTC:
  sfu:
    additional:
      user-config.yaml:
        config: |
          # Add your settings below, taking care of the spacing indentation
          some: settings
```

#### Networking

Matrix RTC SFU will by default advertise the IP resolved after a STUN Request to the Google STUN Servers.

If you want to disable this behaviour, set `useStunToDiscoverPublicIP` to `false` :

```yml
matrixRTC:
  sfu:
    useStunToDiscoverPublicIP: false
```

Without STUN, Matrix RTC will advertise the Host IP as the publicly reachable IP. If your host is behind NAT,
you can configured a manual IP address for the server public IP by setting `manualIP`:

```yml
matrixRTC:
  sfu:
    manualIP: "<your node public IP>"
```
Optionally, if you don't want to use Google's STUN servers you can override this with `stun_servers`:

```yml
matrixRTC:
  sfu:
    additional:
      stun.yaml:
        config: |
          rtc:
            stun_servers:
            - "example.com:3478"
```

#### Enable Turn-TLS behind Traefik

For Turn-TLS to work behind Traefik, you need to create the following manifest :

```yml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: ess-turn-tls
  namespace: ess
spec:
  entryPoints:
    - websecure
  routes:
  - match: HostSNI(`< .matrixRTC.sfu.exposedServices.turnTLS.domain >`)
    priority: 10
    services:
    - name: ess-matrix-rtc-sfu-turn-tls
      port: < .matrixRTC.sfu.exposedServices.turnTLS.port >
  tls:
    passthrough: true
```