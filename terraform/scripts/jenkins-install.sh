#!/bin/bash

# Update system
apt update -y

# Install Java 17
apt install -y openjdk-17-jre-headless

# Install Docker
apt install -y docker.io
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt install -y unzip
unzip awscliv2.zip
./aws/install

# Install Git
apt install -y git

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configure Jenkins
JENKINS_HOME="/var/lib/jenkins"
mkdir -p $JENKINS_HOME/init.groovy.d

# Create Jenkins configuration script
cat > $JENKINS_HOME/init.groovy.d/configure-jenkins.groovy << 'EOF'
import jenkins.model.*
import hudson.security.*
import hudson.security.csrf.DefaultCrumbIssuer
import jenkins.security.s2m.AdminWhitelistRule

def instance = Jenkins.getInstance()

// Disable CSRF protection for easier setup
instance.setCrumbIssuer(null)

// Enable agent to master security subsystem
instance.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)

// Save configuration
instance.save()
EOF

# Set proper permissions
chown -R jenkins:jenkins $JENKINS_HOME
chmod 755 $JENKINS_HOME

# Restart Jenkins to apply configuration
systemctl restart jenkins

# Create Jenkins user setup script
cat > /home/ubuntu/setup-jenkins.sh << 'EOF'
#!/bin/bash
echo "Jenkins is starting up..."
echo "Please wait 2-3 minutes for Jenkins to be ready"
echo ""
echo "To get the initial admin password, run:"
echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
echo "Then access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "Jenkins setup will be available in a few minutes..."
EOF

chmod +x /home/ubuntu/setup-jenkins.sh
chown ubuntu:ubuntu /home/ubuntu/setup-jenkins.sh

# Log completion
echo "Jenkins installation completed at $(date)" >> /var/log/jenkins-install.log
