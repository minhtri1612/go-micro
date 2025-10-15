resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  
  instance_type          = var.instance_type  # parameterized for flexibility
  
  key_name               = aws_key_pair.jenkins_key.key_name
  
  subnet_id              = aws_subnet.public_zone1.id
  
  vpc_security_group_ids = [aws_security_group.security-group.id]
  
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name
  
  # Root block device configuration, setting the volume size to 30 GB
  root_block_device {
    volume_size = 30
  }
  
  user_data = templatefile("./scripts/tools-install.sh", {})

  tags = {
    Name        = var.instance_name
  }
}

output "instance_id" {
  value = aws_instance.ec2.id
}

output "instance_public_ip" {
  value = aws_instance.ec2.public_ip
}