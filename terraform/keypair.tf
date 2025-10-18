
resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-key"
  public_key = file("${path.module}/../jenkins-key.pub")
}
