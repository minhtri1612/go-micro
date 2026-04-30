// Jenkinsfile – Build, Push & Update Image Tags
// Flow: build images → push to Docker Hub → update env/<ENV>.yaml tags → git push → ArgoCD picks up → canary triggers
//
// Required Jenkins Credentials:
//   - dockerhub-credentials : Username/Password credential (Docker Hub)
//   - github-credentials    : Username/Password hoặc SSH credential (GitHub)
//
// Required Jenkins Plugins: Git, Pipeline, Credentials Binding

pipeline {
    agent any

    parameters {
        string(
            name: 'TAG',
            defaultValue: 'v1.0.1',
            description: 'Image tag mới cần build & push (ví dụ: v1.0.5)'
        )
        choice(
            name: 'ENV',
            choices: ['dev', 'staging', 'prod'],
            description: 'Environment cần update image tag (Argo CD sẽ tự sync & trigger canary)'
        )
        booleanParam(
            name: 'ALL_SERVICES',
            defaultValue: true,
            description: 'Update tag cho TẤT CẢ services? Bỏ check nếu chỉ muốn update service chọn bên dưới'
        )
        string(
            name: 'SERVICES',
            defaultValue: 'product inventory order payment noti client',
            description: 'Danh sách service cần update tag (space-separated). Chỉ dùng khi ALL_SERVICES = false'
        )
    }

    environment {
        DOCKER_REPO = 'minhtri1612/go-microservice'
        GIT_REPO    = 'https://github.com/minhtri1612/go-micro.git'
        GIT_BRANCH  = 'main'
    }

    stages {

        // ─────────────────────────────────────────
        stage('Validate') {
        // ─────────────────────────────────────────
            steps {
                script {
                    if (!params.TAG?.trim()) {
                        error "TAG không được để trống!"
                    }
                    echo "=== Build & Deploy ==="
                    echo "TAG : ${params.TAG}"
                    echo "ENV : ${params.ENV}"
                    echo "Repo: ${env.DOCKER_REPO}"
                }
            }
        }

        // ─────────────────────────────────────────
        stage('Build & Push Images') {
        // ─────────────────────────────────────────
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        chmod +x ./build-and-push-images.sh
                        ./build-and-push-images.sh ''' + params.TAG + '''
                        docker logout
                    '''
                }
            }
        }

        // ─────────────────────────────────────────
        stage('Update Image Tags in Git') {
        // ─────────────────────────────────────────
        // Mục đích: Ghi tag mới vào env/<ENV>.yaml để Argo CD phát hiện diff và trigger canary
        // ─────────────────────────────────────────
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_PASS'
                    )
                ]) {
                    script {
                        def envFile = "env/${params.ENV}.yaml"
                        def tag     = params.TAG

                        // Map tên service → prefix tag trong Docker Hub
                        def serviceTagMap = [
                            product  : "product-service-${tag}",
                            inventory: "inventory-service-${tag}",
                            order    : "order-service-${tag}",
                            payment  : "payment-service-${tag}",
                            noti     : "notification-service-${tag}",
                            client   : "client-${tag}",
                        ]

                        def targetServices = params.ALL_SERVICES
                            ? serviceTagMap.keySet().toList()
                            : params.SERVICES.trim().split(/\s+/).toList()

                        echo "Updating ${envFile} cho services: ${targetServices}"

                        // Dùng Python (thay vì sed) để update YAML chính xác từng field
                        // tránh sed bị nhầm lẫn nếu tag cũ và mới cùng pattern
                        def pyScript = """
import re, sys

target_services = ${groovy.json.JsonOutput.toJson(targetServices)}
service_tag_map = ${groovy.json.JsonOutput.toJson(serviceTagMap)}

with open('${envFile}', 'r') as f:
    lines = f.readlines()

current_service = None
result = []
for line in lines:
    svc_match = re.match(r'^(\\w[\\w-]*):\\s*\$', line)
    if svc_match:
        current_service = svc_match.group(1)

    if current_service in target_services and re.match(r'\\s+tag:\\s*".+"', line):
        new_tag = service_tag_map.get(current_service, '')
        if new_tag:
            line = re.sub(r'(tag:\\s*")[^"]*(")', r'\\g<1>' + new_tag + r'\\g<2>', line)

    result.append(line)

with open('${envFile}', 'w') as f:
    f.writelines(result)

print("Done updating ${envFile}")
"""
                        writeFile file: 'update_tags.py', text: pyScript
                        sh 'python3 update_tags.py'
                        sh 'rm -f update_tags.py'

                        // Xác nhận thay đổi
                        sh "grep 'tag:' ${envFile}"
                    }
                }
            }
        }

        // ─────────────────────────────────────────
        stage('Git Commit & Push') {
        // ─────────────────────────────────────────
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_PASS'
                    )
                ]) {
                    sh """
                        git add env/${params.ENV}.yaml
                        git diff --cached --stat

                        # Chỉ commit nếu có thay đổi thực sự
                        if git diff --cached --quiet; then
                            echo "Không có thay đổi – tag có thể đã là ${params.TAG}"
                        else
                            git -c user.email="jenkins@go-micro.local" -c user.name="Jenkins CI" \
                              commit -m "ci(${params.ENV}): bump image tags to ${params.TAG} [skip ci]"
                            set +x
                            git push https://\${GIT_USER}:\${GIT_PASS}@github.com/minhtri1612/go-micro.git HEAD:${env.GIT_BRANCH}
                            set -x
                            echo "✅ Pushed! Argo CD sẽ phát hiện diff và trigger canary rollout trên ${params.ENV}."
                        fi
                    """
                }
            }
        }
    }

    post {
        success {
            echo """
╔══════════════════════════════════════════╗
║  ✅  Pipeline SUCCESS                    ║
║  TAG  : ${params.TAG}
║  ENV  : ${params.ENV}
║  → Argo CD sẽ sync & trigger canary     ║
╚══════════════════════════════════════════╝
"""
        }
        failure {
            echo "❌ Pipeline FAILED. Kiểm tra logs ở trên."
        }
        always {
            // Xóa docker credentials khỏi memory
            sh 'docker logout || true'
        }
    }
}
