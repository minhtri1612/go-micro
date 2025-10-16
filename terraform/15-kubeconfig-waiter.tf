# 15-kubeconfig-waiter.tf 

resource "null_resource" "wait_for_eks_connection" {
  # This resource depends on the cluster and the node group being provisioned.
  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_node_group.general,
  ]

  # This provisioner runs a local command immediately after the dependencies are met.
  provisioner "local-exec" {
    # ⚠️ Keep the interpreter and the robust wait-loop command. 
    # REMOVE the old single-line command.
    
    # This block forces Terraform to wait and confirm the EKS cluster is reachable 
    # before the Helm provider tries to connect.
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Updating kubeconfig for the Helm provider to connect..."
      # This updates the kubeconfig file referenced by the subsequent kubectl command.
      aws eks update-kubeconfig --name ${aws_eks_cluster.eks.name} --region ${var.region} --kubeconfig ${path.module}/kubeconfig-${aws_eks_cluster.eks.name}
      
      echo "Waiting for EKS Control Plane to respond to kubectl..."
      # Wait for the cluster to be fully accessible before proceeding.
      until kubectl get nodes --kubeconfig ${path.module}/kubeconfig-${aws_eks_cluster.eks.name} &> /dev/null; do
        sleep 5
      done
      echo "EKS cluster is fully reachable. Proceeding with Helm deployment."
    EOT
  }
}