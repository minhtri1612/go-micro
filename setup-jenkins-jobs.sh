#!/bin/bash

# Setup Jenkins Jobs for Go Microservices
# Run this script after configuring Jenkins

JENKINS_URL="http://52.62.191.15:8080"
JENKINS_USER="admin"
JENKINS_PASS="6e995b84e88e48f78ac1dedd7edc0d6a"

# Get Jenkins Crumb for CSRF protection
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

# Function to create a Jenkins job
create_job() {
    local job_name=$1
    local jenkinsfile=$2
    
    echo "Creating job: $job_name"
    
    # Create job XML
    cat > "/tmp/${job_name}.xml" << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.45">
  <description>Pipeline for $job_name</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.92">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.11.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/your-username/go-micro.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>jenkins-pipeline/$jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

    # Create the job
    curl -X POST -u "$JENKINS_USER:$JENKINS_PASS" \
         -H "$CRUMB" \
         -H "Content-Type: application/xml" \
         -d @"/tmp/${job_name}.xml" \
         "$JENKINS_URL/createItem?name=$job_name"
    
    echo "✅ Job $job_name created successfully!"
}

# Create jobs for all services
create_job "api-gateway" "Jenkinsfile-api_gateway"
create_job "product-service" "Jenkinsfile-product_service"
create_job "order-service" "Jenkinsfile-order_service"
create_job "inventory-service" "Jenkinsfile-inventory_service"
create_job "payment-service" "Jenkinsfile-payment_service"
create_job "notification-service" "Jenkinsfile-noti_service"
create_job "client" "Jenkinsfile-client"

echo "🎉 All Jenkins jobs created successfully!"
echo "Visit: $JENKINS_URL"
