{{/*
Envoy sidecar container template
Usage: {{ include "governor.tlsInternal.sidecar" (dict "componentName" "api" "config" .Values.api "tlsInternal" .Values.envoy "hasHttpPort" true "hasGrpcPort" true) }}
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
{{- end }}

{{/*
Envoy init container to wait for certificates
Usage: {{ include "governor.tlsInternal.initContainer" . }}
*/}}
{{- define "governor.tlsInternal.initContainer" -}}
- name: wait-for-certs
  image: busybox:1.36
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for TLS certificates..."
      while [ ! -f /etc/envoy/certs/tls.crt ] || [ ! -f /etc/envoy/certs/tls.key ]; do
        echo "Certificates not ready, waiting..."
        sleep 2
      done
      echo "Certificates are ready!"
  volumeMounts:
    - name: tls-certs
      mountPath: /etc/envoy/certs
      readOnly: true
{{- end }}

{{/*
Envoy volumes template
Usage: {{ include "governor.tlsInternal.volumes" (dict "componentName" "api" "config" .Values.api "tlsInternal" .Values.envoy) }}
*/}}
{{- define "governor.tlsInternal.volumes" -}}
- name: envoy-config
  configMap:
    name: {{ .config.name }}-envoy-config
- name: tls-certs
  secret:
    secretName: {{ .config.name }}-tls
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
      tls_certificates:
        - certificate_chain:
            filename: /etc/envoy/certs/tls.crt
          private_key:
            filename: /etc/envoy/certs/tls.key
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
      validation_context:
        trusted_ca:
          filename: /etc/envoy/certs/ca.crt
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
