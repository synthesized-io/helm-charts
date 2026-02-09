{{/*
Expand the name of the chart.
*/}}
{{- define "governor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "governor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Envoy sidecar container template
Usage: {{ include "governor.envoy.sidecar" (dict "componentName" "api" "config" .Values.api "envoy" .Values.envoy "hasHttpPort" true "hasGrpcPort" true) }}
*/}}
{{- define "governor.envoy.sidecar" -}}
- name: envoy-sidecar
  image: "{{ .envoy.image.repository }}:{{ .envoy.image.tag }}"
  imagePullPolicy: {{ .envoy.image.pullPolicy }}
  args:
    - -c
    - /etc/envoy/envoy.yaml
    - --log-level
    - {{ .envoy.logLevel }}
  ports:
    {{- if .hasHttpPort }}
    - name: https
      containerPort: {{ .envoy.ports.secureHttp }}
      protocol: TCP
    {{- end }}
    {{- if .hasGrpcPort }}
    - name: grpcs
      containerPort: {{ .envoy.ports.secureGrpc }}
      protocol: TCP
    {{- end }}
    - name: admin
      containerPort: {{ .envoy.ports.admin }}
      protocol: TCP
  readinessProbe:
    httpGet:
      path: /ready
      port: {{ .envoy.ports.admin }}
    initialDelaySeconds: 5
    periodSeconds: 10
  livenessProbe:
    httpGet:
      path: /ready
      port: {{ .envoy.ports.admin }}
    initialDelaySeconds: 10
    periodSeconds: 15
  resources:
    {{- toYaml .envoy.resources | nindent 4 }}
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
Usage: {{ include "governor.envoy.initContainer" . }}
*/}}
{{- define "governor.envoy.initContainer" -}}
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
Usage: {{ include "governor.envoy.volumes" (dict "componentName" "api" "config" .Values.api "envoy" .Values.envoy) }}
*/}}
{{- define "governor.envoy.volumes" -}}
- name: envoy-config
  configMap:
    name: {{ .config.name }}-envoy-config
- name: tls-certs
  secret:
    secretName: {{ .config.name }}-tls
{{- end }}
