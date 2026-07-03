{{/*
Shared cert-manager Certificate manifest.

Usage:
{{ include "governor.cert-manager.certificate" (dict
  "root" .
  "name" "component-cert"
  "app" "component"
  "secretName" "component-tls"
  "cert" .Values.tlsInternal.certificates
  "certificate" .Values.component.tlsInternal.certificate
  "defaultDnsName" "component.namespace.svc.cluster.local"
) }}
*/}}
{{- define "governor.cert-manager.certificate" -}}
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
