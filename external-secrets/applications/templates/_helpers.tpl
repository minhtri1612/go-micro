{{/*
Suffix for generated K8s Secret names by environment.
*/}}
{{- define "external-secrets.k8sSecretSuffix" -}}
{{- if eq .Values.env "dev" -}}
-dev
{{- end -}}
{{- end -}}
