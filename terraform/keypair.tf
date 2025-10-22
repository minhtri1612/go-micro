# Generate SSH Key Pair for Jenkins
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins_key" {
  key_name   = "${var.project_name}-jenkins-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

# Save private key to file
resource "local_file" "jenkins_private_key" {
  content  = tls_private_key.jenkins_key.private_key_pem
  filename = "${path.module}/jenkins-key.pem"
  file_permission = "0600"
}

# Save public key to file
resource "local_file" "jenkins_public_key" {
  content  = tls_private_key.jenkins_key.public_key_openssh
  filename = "${path.module}/jenkins-key.pub"
}
