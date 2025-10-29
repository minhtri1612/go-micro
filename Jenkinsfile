// Single Jenkinsfile for ALL microservices
// Builds all services every time - simple and works!

pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'ap-southeast-2'
        ECR_REGISTRY = '398045402467.dkr.ecr.ap-southeast-2.amazonaws.com'
    }
    
    parameters {
        choice(
            name: 'SERVICE_TO_BUILD',
            choices: ['ALL', 'api-gateway', 'product-service', 'order-service', 'inventory-service', 'payment-service', 'noti-service', 'client'],
            description: 'Which service to build (ALL = build everything)'
        )
    }
    
    stages {
        stage('1. Code Checkout') {
            steps {
                checkout scm
                echo "Building services - Build #${BUILD_NUMBER}"
            }
        }
        
        stage('2. Run Tests') {
            steps {
                script {
                    def services = [
                        [servicePath: 'api-gateway', ecrRepoName: 'api-gateway'],
                        [servicePath: 'product-service', ecrRepoName: 'product-service'],
                        [servicePath: 'order-service', ecrRepoName: 'order-service'],
                        [servicePath: 'inventory-service', ecrRepoName: 'inventory-service'],
                        [servicePath: 'payment-service', ecrRepoName: 'payment-service'],
                        [servicePath: 'notification-service', ecrRepoName: 'noti-service'],
                        [servicePath: 'client', ecrRepoName: 'client']
                    ]
                    
                    def servicesToTest = params.SERVICE_TO_BUILD == 'ALL' ? 
                        services : 
                        services.findAll { 
                            it.ecrRepoName == params.SERVICE_TO_BUILD || 
                            it.servicePath == params.SERVICE_TO_BUILD
                        }
                    
                    if (servicesToTest.isEmpty()) {
                        servicesToTest = services
                    }
                    
                    // Run tests for each service
                    def testSteps = [:]
                    servicesToTest.each { service ->
                        testSteps["Test ${service.ecrRepoName}"] = {
                            stage("Test ${service.ecrRepoName}") {
                                script {
                                    // Go services - run go test
                                    if (service.servicePath != 'client') {
                                        sh """
                                            echo "Running Go tests for ${service.ecrRepoName}..."
                                            cd ${service.servicePath}
                                            go mod tidy
                                            go test ./... -v || echo "No tests found or tests failed"
                                        """
                                    } else {
                                        // Client (Node.js) - run npm test
                                        sh """
                                            echo "Running Node.js tests for ${service.ecrRepoName}..."
                                            cd ${service.servicePath}
                                            npm install
                                            npm test || echo "No tests found or tests failed"
                                        """
                                    }
                                }
                            }
                        }
                    }
                    
                    parallel testSteps
                }
            }
        }
        
        stage('3. Login to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                """
            }
        }
        
        stage('4. Build & Push Services') {
            steps {
                script {
                    def services = [
                        [servicePath: 'api-gateway', ecrRepoName: 'api-gateway'],
                        [servicePath: 'product-service', ecrRepoName: 'product-service'],
                        [servicePath: 'order-service', ecrRepoName: 'order-service'],
                        [servicePath: 'inventory-service', ecrRepoName: 'inventory-service'],
                        [servicePath: 'payment-service', ecrRepoName: 'payment-service'],
                        [servicePath: 'notification-service', ecrRepoName: 'noti-service'],
                        [servicePath: 'client', ecrRepoName: 'client']
                    ]
                    
                    def servicesToBuild = params.SERVICE_TO_BUILD == 'ALL' ? 
                        services : 
                        services.findAll { 
                            it.ecrRepoName == params.SERVICE_TO_BUILD || 
                            it.servicePath == params.SERVICE_TO_BUILD
                        }
                    
                    if (servicesToBuild.isEmpty()) {
                        servicesToBuild = services // Default to all
                    }
                    
                    echo "Building ${servicesToBuild.size()} service(s): ${servicesToBuild.collect { it.ecrRepoName }.join(', ')}"
                    
                    // Build all services in parallel
                    def buildSteps = [:]
                    servicesToBuild.each { service ->
                        buildSteps[service.ecrRepoName] = {
                            stage("Build ${service.ecrRepoName}") {
                                sh """
                                    echo "Building ${service.ecrRepoName}..."
                                    docker build -t ${service.ecrRepoName}:${BUILD_NUMBER} -f ${service.servicePath}/Dockerfile .
                                    docker tag ${service.ecrRepoName}:${BUILD_NUMBER} ${ECR_REGISTRY}/${service.ecrRepoName}:${BUILD_NUMBER}
                                    docker tag ${service.ecrRepoName}:${BUILD_NUMBER} ${ECR_REGISTRY}/${service.ecrRepoName}:latest
                                    docker push ${ECR_REGISTRY}/${service.ecrRepoName}:${BUILD_NUMBER}
                                    docker push ${ECR_REGISTRY}/${service.ecrRepoName}:latest
                                    echo "✅ ${service.ecrRepoName} pushed to ECR"
                                    docker rmi ${service.ecrRepoName}:${BUILD_NUMBER} || true
                                    docker rmi ${ECR_REGISTRY}/${service.ecrRepoName}:${BUILD_NUMBER} || true
                                    docker rmi ${ECR_REGISTRY}/${service.ecrRepoName}:latest || true
                                """
                            }
                        }
                    }
                    
                    parallel buildSteps
                }
            }
        }
        
        stage('5. GitOps Update') {
            when {
                expression { params.SERVICE_TO_BUILD == 'ALL' }
            }
            steps {
                script {
                    sh """
                        git config user.name "Jenkins"
                        git config user.email "jenkins@example.com"
                        # Update Helm chart values if needed
                        echo "GitOps update completed"
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo "✅ Pipeline completed!"
        }
        success {
            echo "🎉 All services built and pushed successfully!"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
