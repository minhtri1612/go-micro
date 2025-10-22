# ArgoCD Deployment in EKS
resource "helm_release" "argocd" {
  depends_on = [
    null_resource.wait_for_eks_connection
  ]
  
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "5.51.6"

  create_namespace = true
  timeout         = 600

  values = [
    file("${path.module}/values/argocd.yaml"),
    yamlencode({
      server = {
        service = {
          type = "LoadBalancer"
        }
        ingress = {
          enabled = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme" = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
          }
          hosts = ["argocd.${aws_eip.jenkins_eip.public_ip}.nip.io"]
        }
      }
    })
  ]
}

# ArgoCD Application for Go Microservices
resource "kubernetes_manifest" "argocd_application" {
  depends_on = [helm_release.argocd]
  
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "go-micro-app"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/minhtri1612/go-micro.git"
        targetRevision = "HEAD"
        path           = "main"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "go-micro"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}
