
resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-key"
  public_key = file("/home/minhtri/cloud/go-micro/jenkins-key.pub")
}
