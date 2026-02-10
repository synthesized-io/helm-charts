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
