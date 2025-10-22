# Jenkins EC2 Instance
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t3.medium"
  key_name              = aws_key_pair.jenkins_key.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  subnet_id             = aws_subnet.public_zone1.id
  
  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name

  user_data = base64encode(templatefile("${path.module}/scripts/jenkins-install.sh", {
    ECR_REGISTRY = data.aws_caller_identity.current.account_id
    AWS_REGION   = var.region
  }))

  tags = {
    Name = "${var.project_name}-jenkins"
    Type = "Jenkins"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
}

# Elastic IP for Jenkins
resource "aws_eip" "jenkins_eip" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-jenkins-eip"
  }
}
