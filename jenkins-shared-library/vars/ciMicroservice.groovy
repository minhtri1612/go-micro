// vars/ciMicroservice.groovy

def call(Map config) {
    // Define the full ECR URI using the single ECR Account ID
    def ECR_URI = '675613596870.dkr.ecr.ap-southeast-2.amazonaws.com'
    def FULL_IMAGE_NAME = "${ECR_URI}/${config.ecrRepoName}:${env.BUILD_NUMBER}"
    
    pipeline {
        agent any
        
        environment {
            AWS_DEFAULT_REGION = 'ap-southeast-2'
            ECR_REGISTRY = ECR_URI
            ECR_REPOSITORY = config.ecrRepoName
            IMAGE_TAG = "${BUILD_NUMBER}"
        }
        
        stages {
            stage('1. Code Checkout') {
                steps {
                    checkout scm
                    echo "Building ${config.ecrRepoName} - Build #${BUILD_NUMBER}"
                }
            }
            
            stage('2. Docker Build') {
                steps {
                    script {
                        sh """
                            docker build -t ${config.ecrRepoName}:${IMAGE_TAG} -f ${config.servicePath}/Dockerfile .
                            docker tag ${config.ecrRepoName}:${IMAGE_TAG} ${ECR_REGISTRY}/${config.ecrRepoName}:${IMAGE_TAG}
                            docker tag ${config.ecrRepoName}:${IMAGE_TAG} ${ECR_REGISTRY}/${config.ecrRepoName}:latest
                        """
                    }
                }
            }
            
            stage('3. Login to ECR') {
                steps {
                    withCredentials([aws(credentialsId: 'aws-key', roleBindings: [])]) {
                        sh "aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    }
                }
            }
            
            stage('4. Push to ECR') {
                steps {
                    script {
                        sh """
                            docker push ${ECR_REGISTRY}/${config.ecrRepoName}:${IMAGE_TAG}
                            docker push ${ECR_REGISTRY}/${config.ecrRepoName}:latest
                        """
                        echo "Pushed image to ECR: ${ECR_REGISTRY}/${config.ecrRepoName}:${IMAGE_TAG}"
                    }
                }
            }
            
            stage('5. GitOps Update') {
                steps {
                    script {
                        sh """
                            # Update the image tag in the Helm chart values
                            sed -i 's/tag: \".*\"/tag: \"${IMAGE_TAG}\"/g' main/charts/${config.ecrRepoName}/values.yaml
                            
                            # Commit and push the changes to trigger ArgoCD
                            git config user.name "Jenkins"
                            git config user.email "jenkins@example.com"
                            git add main/charts/${config.ecrRepoName}/values.yaml
                            git commit -m "Update ${config.ecrRepoName} image to ${IMAGE_TAG} [skip ci]"
                            git push origin main
                            
                            echo "Git updated - ArgoCD will detect changes and deploy automatically"
                        """
                    }
                }
            }
        }
        
        post {
            always {
                // Clean up Docker images to save space
                sh """
                    docker rmi ${config.ecrRepoName}:${IMAGE_TAG} || true
                    docker rmi ${ECR_REGISTRY}/${config.ecrRepoName}:${IMAGE_TAG} || true
                    docker rmi ${ECR_REGISTRY}/${config.ecrRepoName}:latest || true
                """
            }
            success {
                echo "✅ ${config.ecrRepoName} pipeline completed successfully!"
                echo "🚀 Service deployed at: ${ECR_REGISTRY}/${config.ecrRepoName}:${IMAGE_TAG}"
            }
            failure {
                echo "❌ ${config.ecrRepoName} pipeline failed!"
            }
        }
    }
}

