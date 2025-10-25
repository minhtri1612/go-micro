# ArgoCD removed - focusing on Jenkins + Prometheus + Grafana only

# ArgoCD Application will be created manually after deployment
# Run this command after terraform apply completes:
# kubectl apply -f - <<EOF
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: go-micro-app
#   namespace: argocd
# spec:
#   project: default
#   source:
#     repoURL: https://github.com/minhtri1612/go-micro.git
#     targetRevision: HEAD
#     path: main
#   destination:
#     server: https://kubernetes.default.svc
#     namespace: go-micro
#   syncPolicy:
#     automated:
#       prune: true
#       selfHeal: true
#     syncOptions:
#       - CreateNamespace=true
# EOF
