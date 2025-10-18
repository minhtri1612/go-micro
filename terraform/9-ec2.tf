# ----------------------------
# EC2 Instance for Jenkins
# ----------------------------
resource "aws_instance" "jenkins_ec2" {
  ami                         = data.aws_ami.ami.image_id
  instance_type                = var.instance_type
  key_name                     = aws_key_pair.jenkins_key.key_name
  subnet_id                    = aws_subnet.public_zone1.id
  vpc_security_group_ids        = [aws_security_group.jenkins_sg.id]
  iam_instance_profile          = aws_iam_instance_profile.jenkins_instance_profile.name
  associate_public_ip_address   = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    delete_on_termination = true
    encrypted = true
  }

  user_data = templatefile("${path.module}/scripts/tools-install.sh", {
    jenkins_port = var.jenkins_port
  })

  tags = {
    Name        = var.instance_name
    Environment = var.environment
    Role        = "Jenkins"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------
# Outputs
# ----------------------------
output "jenkins_instance_id" {
  description = "The ID of the Jenkins EC2 instance"
  value       = aws_instance.jenkins_ec2.id
}

output "jenkins_public_ip" {
  description = "The public IP address of the Jenkins EC2 instance"
  value       = aws_instance.jenkins_ec2.public_ip
}

output "jenkins_public_dns" {
  description = "The public DNS of the Jenkins EC2 instance"
  value       = aws_instance.jenkins_ec2.public_dns
}

output "jenkins_access_info" {
  description = "Information to access Jenkins"
  value = {
    url = "http://${aws_instance.jenkins_ec2.public_ip}:${var.jenkins_port}"
    ssh_command = "ssh -i ../jenkins-key ubuntu@${aws_instance.jenkins_ec2.public_ip}"
    initial_password_command = "ssh -i ../jenkins-key ubuntu@${aws_instance.jenkins_ec2.public_ip} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
  }
}
