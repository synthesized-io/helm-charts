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
Resolve tdkWorkers feature flag with backward-compatible fallback from
legacy "tdkAgents" key. Same merge semantics as governor.workerValues.
*/}}
{{- define "governor.tdkWorkersValues" -}}
{{- $w := .Values.tdkWorkers | default dict -}}
{{- $a := .Values.tdkAgents | default dict -}}
{{- mustMergeOverwrite (deepCopy $w) (deepCopy $a) | toYaml -}}
{{- end -}}

{{/*
Shared cert-manager Certificate manifest.

Usage:
{{ include "governor.certificate" (dict
  "root" .
  "name" "component-cert"
  "app" "component"
  "secretName" "component-tls"
  "cert" .Values.tlsInternal.certificates
  "certificate" .Values.component.tlsInternal.certificate
  "defaultDnsName" "component.namespace.svc.cluster.local"
) }}
*/}}
{{- define "governor.certificate" -}}
{{- $root := .root -}}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ .name }}
  labels:
    app: {{ .app }}
    {{- include "governor.selectorLabels" $root | nindent 4 }}
spec:
  secretName: {{ .secretName }}
  duration: {{ .cert.duration }}
  renewBefore: {{ .cert.renewBefore }}
  privateKey:
    algorithm: {{ .cert.privateKey.algorithm }}
    size: {{ .cert.privateKey.size }}
    encoding: {{ .cert.privateKey.encoding }}
  {{- with .certificate }}
  {{- with .usages }}
  usages:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .commonName }}
  commonName: {{ . }}
  {{- end }}
  {{- end }}
  {{- if .defaultDnsName }}
  dnsNames:
    {{- if and .certificate .certificate.dnsNames }}
    {{- toYaml .certificate.dnsNames | nindent 4 }}
    {{- else }}
    - {{ .defaultDnsName }}
    {{- end }}
  {{- end }}
  issuerRef:
    name: {{ .cert.issuerRef.name }}
    kind: {{ .cert.issuerRef.kind }}
{{- end }}

{{/*
Envoy node identity required for SDS initialization.
*/}}
{{- define "governor.envoy.node" -}}
node:
  cluster: {{ printf "%s-envoy" .componentName | quote }}
  id: {{ printf "%s.%s" .componentName .Release.Namespace | quote }}
{{- end }}

{{/*
Envoy sidecar container template
Usage: {{ include "governor.tlsInternal.sidecar" (dict "componentName" "api" "config" .Values.api "tlsInternal" .Values.tlsInternal "hasHttpPort" true "hasGrpcPort" true) }}
*/}}
{{- define "governor.tlsInternal.sidecar" -}}
- name: envoy-sidecar
  image: "{{ .tlsInternal.image.repository }}:{{ .tlsInternal.image.tag }}"
  imagePullPolicy: {{ .tlsInternal.image.pullPolicy }}
  args:
    - -c
    - /etc/envoy/envoy.yaml
    - --log-level
    - {{ .tlsInternal.logLevel }}
  ports:
    {{- if .hasHttpPort }}
    - name: https
      containerPort: {{ .tlsInternal.ports.secureHttp }}
      protocol: TCP
    {{- end }}
    {{- if .hasGrpcPort }}
    - name: grpcs
      containerPort: {{ .tlsInternal.ports.secureGrpc }}
      protocol: TCP
    {{- end }}
    - name: admin
      containerPort: {{ .tlsInternal.ports.admin }}
      protocol: TCP
  readinessProbe:
    httpGet:
      path: /ready
      port: {{ .tlsInternal.ports.admin }}
    initialDelaySeconds: 5
    periodSeconds: 10
  livenessProbe:
    httpGet:
      path: /ready
      port: {{ .tlsInternal.ports.admin }}
    initialDelaySeconds: 10
    periodSeconds: 15
  resources:
    {{- toYaml .tlsInternal.resources | nindent 4 }}
  volumeMounts:
    - name: envoy-config
      mountPath: /etc/envoy
      readOnly: true
    - name: tls-certs
      mountPath: /etc/envoy/certs
      readOnly: true
    - name: ca-cert
      mountPath: /etc/envoy/ca
      readOnly: true
{{- end }}

{{/*
Envoy init container to wait for certificates
Usage: {{ include "governor.tlsInternal.initContainer" . }}
*/}}
{{- define "governor.tlsInternal.initContainer" -}}
- name: wait-for-certs
  {{/*
  We use the same image as the main sidecar, because convenience images such as 'busybox' might
  not be readily available in the target environment.
  */}}
  image: "{{ .Values.tlsInternal.image.repository }}:{{ .Values.tlsInternal.image.tag }}"
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for TLS certificates..."
      while [ ! -f /etc/envoy/certs/tls.crt ] || [ ! -f /etc/envoy/certs/tls.key ] || [ ! -f /etc/envoy/ca/ca.crt ]; do
        echo "Certificates not ready, waiting..."
        sleep 2
      done
      echo "Certificates are ready!"
  volumeMounts:
    - name: tls-certs
      mountPath: /etc/envoy/certs
      readOnly: true
    - name: ca-cert
      mountPath: /etc/envoy/ca
      readOnly: true
{{- end }}

{{/*
Envoy volumes template
Usage: {{ include "governor.tlsInternal.volumes" (dict "componentName" "api" "config" .Values.api "tlsInternal" .Values.tlsInternal) }}
*/}}
{{- define "governor.tlsInternal.volumes" -}}
- name: envoy-config
  configMap:
    name: {{ .config.name }}-envoy-config
- name: tls-certs
  secret:
    secretName: {{ .config.name }}-tls
- name: ca-cert
  secret:
    {{- if .tlsInternal.certificates.ca.bundled }}
    secretName: {{ .config.name }}-tls
    items:
      - key: ca.crt
        path: ca.crt
    {{- else }}
    secretName: {{ .tlsInternal.certificates.ca.secretName }}
    items:
      - key: {{ .tlsInternal.certificates.ca.key }}
        path: ca.crt
    {{- end }}
{{- end }}

{{/*
Envoy file-based SDS secret documents for hot-reloading mounted cert-manager
Secrets. These are consumed via path_config_source.
*/}}
{{- define "governor.envoy.downstreamTlsSdsSecret" -}}
resources:
  - "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
    name: downstream_tls_certificate
    tls_certificate:
      certificate_chain:
        filename: /etc/envoy/certs/tls.crt
      private_key:
        filename: /etc/envoy/certs/tls.key
      watched_directory:
        path: /etc/envoy/certs
{{- end }}

{{- define "governor.envoy.upstreamValidationContextSdsSecret" -}}
resources:
  - "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
    name: upstream_validation_context
    validation_context:
      trusted_ca:
        filename: /etc/envoy/ca/ca.crt
      watched_directory:
        path: /etc/envoy/ca
{{- end }}

{{/*
Envoy HTTP router filter (used in all listeners)
*/}}
{{- define "governor.envoy.httpRouter" -}}
- name: envoy.filters.http.router
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
{{- end }}

{{/*
Envoy downstream TLS context (for inbound TLS termination)
*/}}
{{- define "governor.envoy.downstreamTls" -}}
transport_socket:
  name: envoy.transport_sockets.tls
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
    common_tls_context:
      tls_certificate_sds_secret_configs:
        - name: downstream_tls_certificate
          sds_config:
            path_config_source:
              path: /etc/envoy/downstream_tls_certificate.yaml
{{- end }}

{{/*
Envoy upstream TLS context (for egress with CA validation)
*/}}
{{- define "governor.envoy.upstreamTls" -}}
transport_socket:
  name: envoy.transport_sockets.tls
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
    common_tls_context:
      validation_context_sds_secret_config:
        name: upstream_validation_context
        sds_config:
          path_config_source:
            path: /etc/envoy/upstream_validation_context.yaml
{{- end }}

{{/*
Envoy gRPC egress listener to api (shared by front and agent)
*/}}
{{- define "governor.envoy.apiGrpcEgressListener" -}}
- name: api_grpc_egress
  address:
    socket_address:
      address: 127.0.0.1
      port_value: {{ .egressGrpcPort }}
  filter_chains:
    - filters:
        - name: envoy.filters.network.http_connection_manager
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
            stat_prefix: api_grpc_egress
            codec_type: HTTP2
            route_config:
              name: api_grpc_route
              virtual_hosts:
                - name: api_grpc_service
                  domains: ["*"]
                  routes:
                    - match:
                        prefix: "/"
                      route:
                        cluster: api_grpcs
            http_filters:
              {{- include "governor.envoy.httpRouter" . | nindent 14 }}
{{- end }}

{{/*
Envoy api gRPCS upstream cluster (shared by front and agent)
*/}}
{{- define "governor.envoy.apiGrpcsCluster" -}}
- name: api_grpcs
  type: STRICT_DNS
  connect_timeout: 5s
  http2_protocol_options: {}
  load_assignment:
    cluster_name: api_grpcs
    endpoints:
      - lb_endpoints:
          - endpoint:
              address:
                socket_address:
                  address: {{ .apiName }}
                  port_value: {{ .apiGrpcPort }}
  {{- include "governor.envoy.upstreamTls" . | nindent 2 }}
{{- end }}
