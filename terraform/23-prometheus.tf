# ----------------------------
# Prometheus Monitoring Stack
# ----------------------------

# Kubernetes namespace for monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Helm release for kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {
  depends_on = [
    null_resource.wait_for_eks_connection,
    kubernetes_namespace.monitoring
  ]
  
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "61.1.1"  # Latest stable version

  timeout = 600

  # Configuration values for Prometheus stack
  values = [
    <<-EOT
      # Prometheus configuration
      prometheus:
        prometheusSpec:
          retention: 30d
          storageSpec:
            volumeClaimTemplate:
              spec:
                storageClassName: gp2
                accessModes: ["ReadWriteOnce"]
                resources:
                  requests:
                    storage: 50Gi

      # Grafana configuration
      grafana:
        adminPassword: admin123
        service:
          type: NodePort
          nodePort: 30000
        persistence:
          enabled: true
          storageClassName: gp2
          size: 10Gi

      # Alertmanager configuration
      alertmanager:
        alertmanagerSpec:
          storage:
            volumeClaimTemplate:
              spec:
                storageClassName: gp2
                accessModes: ["ReadWriteOnce"]
                resources:
                  requests:
                    storage: 10Gi

      # Node Exporter
      nodeExporter:
        enabled: true

      # Kube State Metrics
      kubeStateMetrics:
        enabled: true

      # Service Monitor for all namespaces
      prometheus:
        prometheusSpec:
          serviceMonitorSelectorNilUsesHelmValues: false
          ruleSelectorNilUsesHelmValues: false
    EOT
  ]
}

# Output Prometheus access information
output "prometheus_access_info" {
  description = "Prometheus and Grafana access information"
  value = {
    prometheus_url = "http://localhost:9090"
    grafana_url    = "http://localhost:30000"
    grafana_credentials = {
      username = "admin"
      password = "admin123"
    }
  }
}
