#!/bin/bash

# Setup Multibranch Pipeline Jobs for Go Microservices
# Run this script after configuring Jenkins

JENKINS_URL="http://52.62.191.15:8080"
JENKINS_USER="admin"
JENKINS_PASS="6e995b84e88e48f78ac1dedd7edc0d6a"

# Get Jenkins Crumb for CSRF protection
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

# Function to create a Multibranch Pipeline job
create_multibranch_job() {
    local job_name=$1
    local jenkinsfile=$2
    
    echo "Creating multibranch job: $job_name"
    
    # Create job XML for Multibranch Pipeline
    cat > "/tmp/${job_name}-multibranch.xml" << EOF
<?xml version='1.1' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject plugin="workflow-multibranch@2.26">
  <description>Multibranch Pipeline for $job_name</description>
  <properties/>
  <folderViews class="jenkins.branch.MultiBranchProjectViewHolder" plugin="branch-api@2.8.0">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </folderViews>
  <healthMetrics>
    <com.cloudbees.hudson.plugins.folder.health.WorstChildHealthMetric plugin="cloudbees-folder@6.18">
      <nonRecursive>false</nonRecursive>
    </com.cloudbees.hudson.plugins.folder.health.WorstChildHealthMetric>
  </healthMetrics>
  <icon class="jenkins.branch.MetadataActionFolderIcon" plugin="branch-api@2.8.0">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </icon>
  <orphanedItemStrategy class="com.cloudbees.hudson.plugins.folder.computed.DefaultOrphanedItemStrategy" plugin="cloudbees-folder@6.18">
    <pruneDeadBranches>true</pruneDeadBranches>
    <daysToKeep>1</daysToKeep>
    <numToKeep>1</numToKeep>
  </orphanedItemStrategy>
  <triggers>
    <com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger plugin="cloudbees-folder@6.18">
      <spec>H/5 * * * *</spec>
      <interval>300000</interval>
    </com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger>
  </triggers>
  <disabled>false</disabled>
  <sources class="jenkins.branch.MultiBranchProject\$BranchSourceList" plugin="branch-api@2.8.0">
    <data>
      <jenkins.branch.BranchSource>
        <source class="jenkins.plugins.git.GitSCMSource" plugin="git@4.11.3">
          <id>git-source</id>
          <remote>https://github.com/your-username/go-micro.git</remote>
          <credentialsId></credentialsId>
          <traits>
            <jenkins.plugins.git.traits.BranchDiscoveryTrait>
              <strategyId>1</strategyId>
            </jenkins.plugins.git.traits.BranchDiscoveryTrait>
            <jenkins.plugins.git.traits.OriginPullRequestDiscoveryTrait>
              <strategyId>1</strategyId>
            </jenkins.plugins.git.traits.OriginPullRequestDiscoveryTrait>
            <jenkins.plugins.git.traits.ForkPullRequestDiscoveryTrait>
              <strategyId>1</strategyId>
            </jenkins.plugins.git.traits.ForkPullRequestDiscoveryTrait>
          </traits>
        </source>
        <strategy class="jenkins.branch.DefaultBranchPropertyStrategy" plugin="branch-api@2.8.0">
          <properties class="empty-list"/>
        </strategy>
      </jenkins.branch.BranchSource>
    </data>
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </sources>
  <factory class="org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory" plugin="workflow-multibranch@2.26">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
    <scriptPath>jenkins-pipeline/$jenkinsfile</scriptPath>
  </factory>
</org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
EOF

    # Create the job
    curl -X POST -u "$JENKINS_USER:$JENKINS_PASS" \
         -H "$CRUMB" \
         -H "Content-Type: application/xml" \
         -d @"/tmp/${job_name}-multibranch.xml" \
         "$JENKINS_URL/createItem?name=$job_name-multibranch"
    
    echo "✅ Multibranch job $job_name-multibranch created successfully!"
}

# Create multibranch jobs for all services
create_multibranch_job "api-gateway" "Jenkinsfile-api_gateway"
create_multibranch_job "product-service" "Jenkinsfile-product_service"
create_multibranch_job "order-service" "Jenkinsfile-order_service"
create_multibranch_job "inventory-service" "Jenkinsfile-inventory_service"
create_multibranch_job "payment-service" "Jenkinsfile-payment_service"
create_multibranch_job "notification-service" "Jenkinsfile-noti_service"
create_multibranch_job "client" "Jenkinsfile-client"

echo "🎉 All Multibranch Pipeline jobs created successfully!"
echo "Visit: $JENKINS_URL"
echo ""
echo "Each job will automatically:"
echo "✅ Discover all branches"
echo "✅ Create jobs for each branch"
echo "✅ Build on every push"
echo "✅ Build pull requests"
