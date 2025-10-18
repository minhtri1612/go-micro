#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    wget \
    git \
    openjdk-11-jdk \
    python3 \
    python3-pip \
    docker.io \
    awscli

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add Jenkins repository and install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

# Configure Jenkins
systemctl start jenkins
systemctl enable jenkins

# Configure Jenkins to run on port ${jenkins_port}
sed -i "s/HTTP_PORT=8080/HTTP_PORT=${jenkins_port}/g" /etc/default/jenkins
systemctl restart jenkins

# Create Jenkins user and add to docker group
usermod -aG docker jenkins

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create directory for Jenkins workspace
mkdir -p /var/lib/jenkins/workspace
chown -R jenkins:jenkins /var/lib/jenkins

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform

echo "Jenkins installation completed successfully!"
echo "Jenkins is running on port ${jenkins_port}"
echo "Get initial admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
