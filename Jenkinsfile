// Luồng lab (PIPELINE_SCOPE=auto — mặc định):
//   Chỉ sửa env/dev.yaml        → SKIP Build + Push Git; chạy Prepare + test + promote gate (test tag GitOps).
//   Sửa order-service/ (ví dụ) → CHỈ build/push order; bump tag order; Push Git; rồi test + promote.
//   ci: bump / Jenkinsfile only → SKIP toàn pipeline (SUCCESS).
//   build-only / full — override thủ công khi cần.
// Credentials: dockerhub-credentials, github-go-micro-pat (bắt buộc cho PUSH_GIT).

pipeline {
  agent {
    label 'built-in'
  }

  options {
    disableConcurrentBuilds()
  }

  environment {
    KUBECONFIG = '/var/jenkins_home/.kube/config'
    EFFECTIVE_EXECUTION_MODE = 'dev-pod'
    // Không khai báo SKIP_* ở đây — Declarative environment reset mỗi stage, xóa giá trị Precheck set.
  }

  parameters {
    choice(
      name: 'PIPELINE_SCOPE',
      choices: ['auto', 'build-only', 'build-and-full', 'full', 'dependency-only', 'business-only', 'route-smoke-only', 'load-only'],
      description: '`auto` (mặc định): detect commit — env/ only → test; *-service/ → build đúng service + test. `build-only`/`full` = ép một nhánh.'
    )
    choice(name: 'TARGET_ENV', choices: ['dev', 'staging'], description: 'env/<TARGET_ENV>.yaml — dùng khi scope có build.')
    choice(
      name: 'BUILD_SERVICES',
      choices: ['auto', 'all', 'product', 'inventory', 'order', 'payment', 'noti', 'client'],
      description: '`auto` (mặc định) = chỉ *-service/ hoặc client/ đổi trong commit; không đổi → skip build. `all` = build cả 6+client (chỉ khi cần rebuild hàng loạt).'
    )
    booleanParam(name: 'PUSH_GIT', defaultValue: true, description: 'Sau build: commit + push env/<TARGET_ENV>.yaml lên Git (Argo sync tag mới).')
    string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Branch push Git sau build.')
    string(name: 'DEV_KUBE_CONTEXT', defaultValue: 'kind-dev', description: 'Kubernetes context của cụm dev để chạy pod test.')
    string(name: 'DEV_TEST_NAMESPACE', defaultValue: 'default', description: 'Namespace trên cụm dev để tạo pod test tạm.')
    string(name: 'DEV_TEST_SERVICE_ACCOUNT', defaultValue: 'go-micro-test-runner', description: 'ServiceAccount dùng cho pod test (cần có quyền list nodes cho K8s API node check).')
    string(name: 'ROLLOUT_NAMESPACE', defaultValue: 'microservices-dev', description: 'Namespace chứa Argo Rollout cần promote/abort.')
    string(name: 'ROLLOUT_SERVICE', defaultValue: 'auto', description: '`auto` = tự suy ra từ DEPENDENCY_SERVICES/BUSINESS_SERVICES (chỉ khi 1 service); hoặc ghi rõ service, ví dụ: inventory.')
    booleanParam(name: 'AUTO_PROMOTE', defaultValue: false, description: 'Tự promote rollout khi toàn bộ quality gate pass. Nếu FALSE, Jenkins sẽ dừng lại hiện nút bấm cho anh duyệt.')
    booleanParam(name: 'AUTO_ABORT', defaultValue: true, description: 'Tự abort rollout khi pipeline fail hoặc anh nhấn nút Abort.')
    booleanParam(name: 'ENABLE_MANUAL_ROLLOUT_GATE', defaultValue: true, description: 'Hiện bước nút bấm Promote/Rollback trên Jenkins UI sau khi test pass.')
    choice(name: 'ON_FAILURE_MANUAL_ACTION', choices: ['Rollback now', 'Do nothing'], description: 'Khi pipeline fail và AUTO_ABORT=false: chọn hành động mặc định cho bước manual fail gate.')
    string(name: 'TARGET_HOST', defaultValue: 'dev.go-micro.local', description: 'Host trong URL + header Host cho route smoke (Traefik/Ingress :80).')
    string(name: 'BACKEND_IP', defaultValue: '172.18.255.10', description: 'IP gateway/Ingress: dependency & business (http://IP:port), route smoke (--resolve), k6 TARGET_URL.')
    choice(
      name: 'DEPENDENCY_SERVICES',
      choices: ['all', 'product', 'inventory', 'order', 'payment', 'noti'],
      description: 'Dependency check: `all` = lần lượt 5 service; chọn 1 tên nếu chỉ cần check một service.'
    )
    choice(
      name: 'BUSINESS_SERVICES',
      choices: ['all', 'product', 'inventory', 'order', 'payment', 'noti'],
      description: 'Business smoke: `all` = lần lượt 5 service (lâu hơn); chọn 1 tên nếu chỉ cần smoke một service.'
    )
    string(name: 'ROUTE_PREFIX', defaultValue: 'auto', description: '`auto` = suy từ BUSINESS_SERVICES (ưu tiên) hoặc DEPENDENCY_SERVICES khi chọn 1 service; cả hai `all` → `/api/v1/products`. Ghi path tường minh để override.')
    booleanParam(name: 'ROUTE_SMOKE', defaultValue: true, description: 'Chạy route smoke canary/preview (curl qua --resolve, không cần ghi /etc/hosts).')
    choice(name: 'ROUTE_MODE', choices: ['canary', 'preview', 'standard'], description: 'Mode route smoke để test traffic split trước promote.')
    booleanParam(name: 'CANARY_HEADER_API_TESTS', defaultValue: false, description: 'Bật để ép dependency/business gửi X-Canary:true. Mặc định tắt vì một số endpoint POST có thể trả 405 qua canary route.')
    booleanParam(name: 'ENABLE_K8S_NODE_CHECK', defaultValue: true, description: 'Chạy check Kubernetes API thuần (requests) để list nodes trước test chính.')
    string(name: 'K6_SERVICE_NAME', defaultValue: 'product', description: 'Service k6 load-test (map port trong tests/load-test/k6-script.js).')
    string(name: 'K6_VUS', defaultValue: '5', description: 'k6 virtual users')
    string(name: 'K6_DURATION', defaultValue: '15s', description: 'k6 duration')
    string(name: 'K6_ERROR_RATE', defaultValue: '0.1', description: 'k6 http_req_failed threshold (rate<value)')
    string(name: 'POD_WAIT_TIMEOUT', defaultValue: '600s', description: 'Timeout chờ mỗi pod test hoàn thành (ví dụ: 300s, 600s).')
    string(name: 'ROLLOUT_WAIT_TIMEOUT', defaultValue: '45m', description: 'Sau promote: chờ rollout tới xong (kubectl argo rollouts status --watch). GNU timeout hoặc flag CLI; ví dụ 45m, 30m.')
  }

  stages {
    stage('Checkout') {
      when {
        expression { pipelineNeedsCheckout() }
      }
      steps {
        checkout scm
      }
    }

    stage('Precheck') {
      when {
        expression { pipelineNeedsPrecheck() }
      }
      steps {
        script {
          precheckPipeline()
        }
      }
    }

    stage('Build & push images') {
      when {
        expression { pipelineNeedsImageBuild() }
      }
      steps {
        script {
          if (isSkipImageBuild()) {
            echo "Build skipped (Precheck). SKIP_IMAGE_BUILD=${env.SKIP_IMAGE_BUILD ?: '(unset)'}"
          } else {
            runImageBuildSteps()
          }
        }
      }
    }

    stage('Push Git') {
      when {
        allOf {
          expression { pipelineNeedsImageBuild() }
          expression { params.PUSH_GIT == true }
        }
      }
      steps {
        script {
          if (isSkipImageBuild()) {
            echo 'Push Git skipped (không có build).'
          } else {
            runCiGitPushSteps()
          }
        }
      }
    }

    stage('Prepare') {
      when {
        expression { pipelineNeedsQualityGates() }
      }
      steps {
        sh 'kubectl version --client'
        script {
          validateKubeContext(params.DEV_KUBE_CONTEXT)
          env.RESOLVED_ROLLOUT_SERVICE = resolveRolloutService(params.ROLLOUT_SERVICE, getEffectiveDependencyServices(), getEffectiveBusinessServices())
          env.EFFECTIVE_ROUTE_PREFIX = resolveEffectiveRoutePrefix(params.ROUTE_PREFIX, getEffectiveDependencyServices(), getEffectiveBusinessServices())
          echo "Execution mode: ${env.EFFECTIVE_EXECUTION_MODE}"
          echo "Rollout target: ${params.ROLLOUT_NAMESPACE}/${env.RESOLVED_ROLLOUT_SERVICE ?: '(none)'}"
          echo "Route smoke prefix: ${env.EFFECTIVE_ROUTE_PREFIX} (ROUTE_PREFIX param='${params.ROUTE_PREFIX}')"
        }
      }
    }

    stage('K8s API Node Check') {
      when {
        allOf {
          expression { params.ENABLE_K8S_NODE_CHECK == true }
          expression { pipelineNeedsQualityGates() && params.PIPELINE_SCOPE != 'load-only' }
        }
      }
      steps {
        script {
          sh "kubectl --context ${params.DEV_KUBE_CONTEXT} apply -f tests/k8s-node-check/rbac.yaml"
          runK8sNodeCheckSteps()
        }
      }
    }

    // Chỉ `full` mới dùng Declarative parallel (4 nhánh). `*-only` chạy một stage riêng — tránh log/CPS rối (mọi nhánh skipped trừ một).
    stage('Parallel tests') {
      when {
        expression { pipelineNeedsQualityGates() && (params.PIPELINE_SCOPE == 'full' || params.PIPELINE_SCOPE == 'build-and-full' || params.PIPELINE_SCOPE == 'auto') }
      }
      parallel {
        stage('Dependency Check') {
          steps {
            script {
              runDependencyCheckSteps()
            }
          }
        }
        stage('Business Smoke Test') {
          steps {
            script {
              runBusinessSmokeSteps()
            }
          }
        }
        stage('Route Smoke') {
          when {
            expression { params.ROUTE_SMOKE != false && params.ROUTE_SMOKE != 'false' }
          }
          steps {
            script {
              runRouteSmokeSteps()
            }
          }
        }
        stage('Load Test (k6)') {
          steps {
            script {
              runK6LoadSteps()
            }
          }
        }
      }
    }

    stage('Rollout Decision Gate') {
      when {
        allOf {
          expression { pipelineNeedsQualityGates() && (params.PIPELINE_SCOPE == 'full' || params.PIPELINE_SCOPE == 'build-and-full' || params.PIPELINE_SCOPE == 'auto') }
          expression { env.RESOLVED_ROLLOUT_SERVICE?.trim() }
          expression { params.AUTO_PROMOTE == false && params.ENABLE_MANUAL_ROLLOUT_GATE == true }
        }
      }
      steps {
        script {
          echo "--- QUALITY GATES PASSED ---"
          echo "Chờ chọn hành động rollout cho service: ${env.RESOLVED_ROLLOUT_SERVICE}"
          def rawDecision = null
          timeout(time: 30, unit: 'MINUTES') {
            rawDecision = input(
              id: "rollout-decision-${env.BUILD_NUMBER}",
              message: "Quality gate PASS cho [${env.RESOLVED_ROLLOUT_SERVICE}]. Chọn Promote hoặc Rollback.",
              ok: 'Xác nhận',
              parameters: [
                choice(name: 'ROLLOUT_ACTION', choices: ['Promote to stable', 'Rollback now'], description: 'Hành động rollout')
              ]
            )
          }
          // input() with parameters returns a Map (e.g. [ROLLOUT_ACTION: '...']), not a plain String.
          def decision = (rawDecision instanceof Map) ? rawDecision['ROLLOUT_ACTION']?.toString() : rawDecision?.toString()
          echo "Rollout manual choice: ${decision}"
          if (decision == 'Rollback now') {
            runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
            error("Manual decision = rollback. Rollout đã abort theo yêu cầu.")
          } else if (decision == 'Promote to stable') {
            runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'promote')
            waitRolloutComplete(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE)
          } else {
            error("Unexpected ROLLOUT_ACTION value: '${decision}'")
          }
        }
      }
    }

    stage('Dependency Check') {
      when {
        expression { params.PIPELINE_SCOPE == 'dependency-only' }
      }
      steps {
        script {
          runDependencyCheckSteps()
        }
      }
    }

    stage('Business Smoke Test') {
      when {
        expression { params.PIPELINE_SCOPE == 'business-only' }
      }
      steps {
        script {
          runBusinessSmokeSteps()
        }
      }
    }

    stage('Route Smoke') {
      when {
        allOf {
          expression { params.ROUTE_SMOKE != false && params.ROUTE_SMOKE != 'false' }
          expression { params.PIPELINE_SCOPE == 'route-smoke-only' }
        }
      }
      steps {
        script {
          runRouteSmokeSteps()
        }
      }
    }

    stage('Load Test (k6)') {
      when {
        expression { params.PIPELINE_SCOPE == 'load-only' }
      }
      steps {
        script {
          runK6LoadSteps()
        }
      }
    }

    stage('Promote Rollout') {
      when {
        allOf {
          expression { pipelineNeedsQualityGates() && (params.PIPELINE_SCOPE == 'full' || params.PIPELINE_SCOPE == 'build-and-full' || params.PIPELINE_SCOPE == 'auto') }
          expression { env.RESOLVED_ROLLOUT_SERVICE?.trim() }
          expression { params.AUTO_PROMOTE == true }
        }
      }
      steps {
        script {
          runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'promote')
          waitRolloutComplete(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE)
        }
      }
    }
  }

  post {
    failure {
      script {
        def fullScope = pipelineNeedsQualityGates() && (params.PIPELINE_SCOPE == 'full' || params.PIPELINE_SCOPE == 'build-and-full' || params.PIPELINE_SCOPE == 'auto')
        if (fullScope && params.AUTO_ABORT && env.RESOLVED_ROLLOUT_SERVICE?.trim()) {
          runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
        } else if (fullScope && !params.AUTO_ABORT && env.RESOLVED_ROLLOUT_SERVICE?.trim()) {
          def failDecision = params.ON_FAILURE_MANUAL_ACTION ?: 'Rollback now'
          def rawFail = null
          timeout(time: 20, unit: 'MINUTES') {
            rawFail = input(
              id: "failure-action-${env.BUILD_NUMBER}",
              message: "Pipeline FAILED cho [${env.RESOLVED_ROLLOUT_SERVICE}]. Chọn rollback hay giữ nguyên trạng thái rollout.",
              ok: 'Xác nhận',
              parameters: [
                choice(name: 'FAILURE_ACTION', choices: ['Rollback now', 'Do nothing'], description: 'Hành động khi fail')
              ]
            )
          }
          failDecision = (rawFail instanceof Map) ? rawFail['FAILURE_ACTION']?.toString() : rawFail?.toString()
          echo "Failure manual choice: ${failDecision}"
          if (failDecision == 'Rollback now') {
            runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
          } else {
            echo "Manual failure action: none (giữ nguyên rollout state)"
          }
        } else {
          echo "Skip abort rollout: PIPELINE_SCOPE=${params.PIPELINE_SCOPE}, AUTO_ABORT=${params.AUTO_ABORT}, service='${env.RESOLVED_ROLLOUT_SERVICE ?: ''}'"
        }
      }
    }
    always {
      deleteDir()
    }
  }
}

def isSkipImageBuild() {
  return (env.SKIP_IMAGE_BUILD ?: '').toString() == 'true'
}

def isSkipQualityGates() {
  return (env.SKIP_QUALITY_GATES ?: '').toString() == 'true'
}

def pipelineNeedsCheckout() {
  return params.PIPELINE_SCOPE in ['auto', 'build-only', 'build-and-full', 'full']
}

def pipelineNeedsPrecheck() {
  return params.PIPELINE_SCOPE in ['auto', 'build-only', 'build-and-full']
}

def pipelineNeedsImageBuild() {
  return params.PIPELINE_SCOPE in ['auto', 'build-only', 'build-and-full']
}

def pipelineNeedsQualityGates() {
  def s = params.PIPELINE_SCOPE
  if (s == 'build-only') {
    return false
  }
  if (s in ['dependency-only', 'business-only', 'route-smoke-only', 'load-only', 'full', 'build-and-full']) {
    return true
  }
  if (s == 'auto') {
    return !isSkipQualityGates()
  }
  return false
}

def getEffectiveDependencyServices() {
  return env.EFFECTIVE_DEPENDENCY_SERVICES?.trim() ?: params.DEPENDENCY_SERVICES
}

def getEffectiveBusinessServices() {
  return env.EFFECTIVE_BUSINESS_SERVICES?.trim() ?: params.BUSINESS_SERVICES
}

def applyAutoTestTargets(String detected) {
  def rolloutList = detected.split(/\s+/).collect { it.trim() }.findAll { it && it != 'client' }
  if (rolloutList.size() == 1) {
    env.EFFECTIVE_DEPENDENCY_SERVICES = rolloutList[0]
    env.EFFECTIVE_BUSINESS_SERVICES = rolloutList[0]
    echo "auto: test + promote target → ${rolloutList[0]}"
  } else if (rolloutList.size() > 1) {
    echo "auto: build [${detected}] — test dùng DEPENDENCY/BUSINESS trên Jenkins (mặc định all)"
  }
}

def precheckPipeline() {
  env.SKIP_IMAGE_BUILD = 'false'
  env.SKIP_QUALITY_GATES = 'false'
  env.DETECTED_SERVICES = ''
  if (params.PIPELINE_SCOPE == 'build-only') {
    echo 'Gợi ý: commit chỉ Jenkinsfile/env → dùng PIPELINE_SCOPE=auto (không phải build-only).'
  }
  def msg = sh(script: 'git log -1 --pretty=%s', returnStdout: true).trim()
  if (msg ==~ /(?i)^ci:\s*bump\b.*/ || msg.contains('[skip ci]')) {
    env.SKIP_IMAGE_BUILD = 'true'
    env.SKIP_QUALITY_GATES = 'true'
    currentBuild.description = 'Skipped: ci bump commit'
    echo "SKIP all: '${msg}'"
    return
  }

  if (params.PIPELINE_SCOPE == 'auto') {
    def mode = sh(script: 'bash scripts/ci/detect-commit-mode.sh', returnStdout: true).trim()
    def detected = sh(script: 'bash scripts/ci/detect-changed-services.sh', returnStdout: true).trim()
    echo "auto: mode=${mode}, services='${detected}'"
    if (mode == 'service' && detected) {
      env.SKIP_IMAGE_BUILD = 'false'
      env.SKIP_QUALITY_GATES = 'false'
      env.DETECTED_SERVICES = detected
      applyAutoTestTargets(detected)
      currentBuild.description = "auto: build+test [${detected}]"
      return
    }
    if (mode == 'env-only') {
      env.SKIP_IMAGE_BUILD = 'true'
      env.SKIP_QUALITY_GATES = 'false'
      currentBuild.description = 'auto: env/ only — test (skip build)'
      echo 'Chỉ env/* đổi → skip Build + Push Git; chạy Prepare + test. Argo sync Git.'
      sh 'git show -1 --name-only --pretty=format:"  %h %s"'
      return
    }
    env.SKIP_IMAGE_BUILD = 'true'
    env.SKIP_QUALITY_GATES = 'true'
    currentBuild.description = 'auto: skip (không service/env)'
    echo 'SKIP: commit không đổi *-service/ hay env/'
    sh 'git show -1 --name-only --pretty=format:"  %h %s"'
    return
  }

  precheckLegacyBuildScope()
}

def precheckLegacyBuildScope() {
  if (params.BUILD_SERVICES == 'auto') {
    def detected = sh(script: 'bash scripts/ci/detect-changed-services.sh', returnStdout: true).trim()
    if (!detected) {
      env.SKIP_IMAGE_BUILD = 'true'
      env.SKIP_QUALITY_GATES = 'true'
      currentBuild.description = 'Skipped: không có *-service/ trong commit'
      echo 'SKIP build: BUILD_SERVICES=auto, không có service đổi'
      sh 'git show -1 --name-only --pretty=format:"  %h %s"'
      return
    }
    env.DETECTED_SERVICES = detected
    echo "build scope → ${detected}"
  }
  env.SKIP_IMAGE_BUILD = 'false'
  env.SKIP_QUALITY_GATES = (params.PIPELINE_SCOPE == 'build-only') ? 'true' : 'false'
}

def resolveBuildServicesList() {
  if (env.DETECTED_SERVICES?.trim()) {
    return env.DETECTED_SERVICES.trim()
  }
  def allSvcs = 'product inventory order payment noti client'
  if (params.BUILD_SERVICES == 'all') {
    return allSvcs
  }
  if (params.BUILD_SERVICES == 'auto') {
    return sh(script: 'bash scripts/ci/detect-changed-services.sh', returnStdout: true).trim()
  }
  return params.BUILD_SERVICES?.trim() ?: ''
}

def runImageBuildSteps() {
  if (isSkipImageBuild()) {
    echo 'runImageBuildSteps: skipped.'
    return
  }
  def envFile = "env/${params.TARGET_ENV}.yaml"
  def svcs = resolveBuildServicesList()
  if (!svcs?.trim()) {
    echo "Không có service để build (BUILD_SERVICES=${params.BUILD_SERVICES}) — bỏ qua, không fail."
    env.SKIP_IMAGE_BUILD = 'true'
    return
  }
  withCredentials([usernamePassword(
    credentialsId: 'dockerhub-credentials',
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'
  )]) {
    sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
    svcs.split(/\s+/).each { svc ->
      def tag = sh(script: "bash scripts/ci/bump-image-tag.sh '${envFile}' '${svc}'", returnStdout: true).trim()
      echo "${svc} → ${tag}"
      sh "bash scripts/ci/docker-build-push.sh '${svc}' '${tag}'"
    }
  }
}

def runCiGitPushSteps() {
  def envFile = "env/${params.TARGET_ENV}.yaml"
  withCredentials([usernamePassword(
    credentialsId: 'github-go-micro-pat',
    usernameVariable: 'GH_USER',
    passwordVariable: 'GH_TOKEN'
  )]) {
    sh """
      set -e
      git config user.email 'jenkins@go-micro.local'
      git config user.name 'jenkins-ci'
      git add '${envFile}'
      if git diff --cached --quiet; then
        echo 'Nothing to commit'
        exit 0
      fi
      git commit -m 'ci: bump tags in ${envFile} [skip ci] #${env.BUILD_NUMBER}'
      git push 'https://x-access-token:${GH_TOKEN}@github.com/minhtri1612/go-micro.git' 'HEAD:${params.GIT_BRANCH}'
    """
  }
}

def expandServicesCsv(String raw, List allList) {
  if (raw == null || !raw.trim()) {
    error('Thiếu DEPENDENCY_SERVICES / BUSINESS_SERVICES (dùng `all` hoặc CSV).')
  }
  def t = raw.trim()
  if (t.equalsIgnoreCase('all')) {
    return allList
  }
  def out = t.split(',').collect { it.trim().toLowerCase() }.findAll { it.length() > 0 }.unique()
  if (out.isEmpty()) {
    error('Danh sách service sau khi parse rỗng.')
  }
  return out
}

def runInDevPod(String kubeContext, String namespace, String image, String scriptBody) {
  String podName = "ci-${env.BUILD_NUMBER}-${java.util.UUID.randomUUID().toString().take(8)}".toLowerCase()
  String escaped = scriptBody.stripIndent().trim().replace("'", "'\"'\"'")
  String timeout = (params.POD_WAIT_TIMEOUT ?: '600s').trim()
  String serviceAccount = (params.DEV_TEST_SERVICE_ACCOUNT ?: 'default').trim()
  int timeoutSeconds = parseTimeoutSeconds(timeout)
  sh """#!/bin/sh
    set -e
    kubectl --context ${kubeContext} -n ${namespace} run ${podName} --image=${image} --restart=Never --overrides='{"apiVersion":"v1","spec":{"serviceAccountName":"${serviceAccount}"}}' --command -- sh -lc '${escaped}'
    START=\$(date +%s)
    LASTLOG=\$START
    ITER=0
    while true; do
      ITER=\$((ITER + 1))
      PHASE=\$(kubectl --context ${kubeContext} -n ${namespace} get pod/${podName} -o jsonpath='{.status.phase}' 2>/dev/null | awk 'NR==1{gsub(\"\\r\",\"\"); gsub(\"\\n\",\"\"); print; exit}' || true)
      PHASE=\${PHASE:-Unknown}
      if [ "\$PHASE" = "Succeeded" ] || [ "\$PHASE" = "Failed" ]; then
        break
      fi
      NOW=\$(date +%s)
      if [ \$((NOW-START)) -ge ${timeoutSeconds} ]; then
        echo "Pod ${podName} timeout after ${timeout} (current phase=\$PHASE)"
        PHASE="Timeout"
        break
      fi
      if [ \$((NOW-LASTLOG)) -ge 30 ]; then
        echo "[wait pod ${podName}] phase=\$PHASE elapsed=\$((NOW-START))s iter=\$ITER"
        LASTLOG=\$NOW
      fi
      sleep 2
    done
    kubectl --context ${kubeContext} -n ${namespace} logs ${podName} || true
    PHASE=\$(kubectl --context ${kubeContext} -n ${namespace} get pod/${podName} -o jsonpath='{.status.phase}' 2>/dev/null | awk 'NR==1{gsub(\"\\r\",\"\"); gsub(\"\\n\",\"\"); print; exit}' || true)
    PHASE=\${PHASE:-Unknown}
    if [ "\$PHASE" != "Succeeded" ]; then
      echo "Pod ${podName} ended with phase \$PHASE (timeout=${timeout})"
      kubectl --context ${kubeContext} -n ${namespace} describe pod/${podName} || true
      kubectl --context ${kubeContext} -n ${namespace} delete pod/${podName} --ignore-not-found=true >/dev/null
      exit 1
    fi
    kubectl --context ${kubeContext} -n ${namespace} delete pod/${podName} --ignore-not-found=true >/dev/null
  """
}

def runWithMode(String mode, String kubeContext, String namespace, String image, String podScriptBody, String directScriptBody) {
  if (mode == 'dev-pod') {
    runInDevPod(kubeContext, namespace, image, podScriptBody)
    return
  }
  sh """
    set -e
    ${directScriptBody}
  """
}

def parseTimeoutSeconds(String raw) {
  String t = (raw ?: '600s').trim().toLowerCase()
  if (!t) {
    return 600
  }
  if (t ==~ /\d+/) {
    return t.toInteger()
  }
  if (t ==~ /\d+s/) {
    return t[0..-2].toInteger()
  }
  if (t ==~ /\d+m/) {
    return t[0..-2].toInteger() * 60
  }
  if (t ==~ /\d+h/) {
    return t[0..-2].toInteger() * 3600
  }
  error("POD_WAIT_TIMEOUT không hợp lệ: '${raw}'. Dùng dạng 300s, 10m, 1h hoặc số giây.")
}

/** Apt + pip inside ephemeral python pods; must not hide install failures (silent apt break → git missing). */
def devPodAptBootstrapShell() {
  return '''set -e
export DEBIAN_FRONTEND=noninteractive
# IPv6 thường không route; song song nhiều pod dễ trúng "Unable to connect" tới deb.debian.org → retry apt.
mkdir -p /etc/apt/apt.conf.d
cat >/etc/apt/apt.conf.d/99ci-go-micro <<'EOF'
Acquire::ForceIPv4 "true";
Acquire::Retries "5";
EOF
ok=0
for attempt in 1 2 3 4 5 6; do
  if apt-get update -qq && apt-get install -y --no-install-recommends git ca-certificates; then
    ok=1
    break
  fi
  echo "[WARN] apt update/install failed (attempt $attempt/6); retry in 18s..." >&2
  sleep 18
done
if [ "$ok" != "1" ]; then
  echo "[FATAL] apt could not install git after 6 attempts" >&2
  exit 1
fi
rm -rf /var/lib/apt/lists/*
command -v git >/dev/null
pip install --no-cache-dir requests
'''
}

/** Shell snippet: clone repo into /tmp/go-micro (retries; do not swallow errors — parallel pods hammer GitHub). */
def devPodCloneRepoShell() {
  return '''export GIT_TERMINAL_PROMPT=0
rm -rf /tmp/go-micro
for i in 1 2 3 4 5; do
  if git clone --depth 1 https://github.com/minhtri1612/go-micro.git /tmp/go-micro; then
    break
  fi
  echo "[WARN] git clone failed, retry in 12s ($i/5)"
  sleep 12
done
test -d /tmp/go-micro/tests || { echo "[FATAL] clone missing tests/"; ls -la /tmp || true; exit 1; }
cd /tmp/go-micro'''
}

def runDependencyCheckSteps() {
  def allDep = ['product', 'inventory', 'order', 'payment', 'noti']
  def svcs = expandServicesCsv(getEffectiveDependencyServices(), allDep)
  def canaryHeader = shouldEnableCanaryHeaderForApiTests() ? 'true' : 'false'
  svcs.each { svc ->
    runWithMode(
      env.EFFECTIVE_EXECUTION_MODE,
      params.DEV_KUBE_CONTEXT,
      params.DEV_TEST_NAMESPACE,
      'python:3.11-slim',
      """
        ${devPodAptBootstrapShell()}
        ${devPodCloneRepoShell()}
        CANARY_HEADER=${canaryHeader} python3 tests/dependency-check/run.py ${svc} ${params.BACKEND_IP}
      """,
      "CANARY_HEADER=${canaryHeader} python3 tests/dependency-check/run.py ${svc} ${params.BACKEND_IP}"
    )
  }
}

def runBusinessSmokeSteps() {
  def allBiz = ['product', 'inventory', 'order', 'payment', 'noti']
  def svcs = expandServicesCsv(getEffectiveBusinessServices(), allBiz)
  def canaryHeader = shouldEnableCanaryHeaderForApiTests() ? 'true' : 'false'
  svcs.each { svc ->
    runWithMode(
      env.EFFECTIVE_EXECUTION_MODE,
      params.DEV_KUBE_CONTEXT,
      params.DEV_TEST_NAMESPACE,
      'python:3.11-slim',
      """
        ${devPodAptBootstrapShell()}
        ${devPodCloneRepoShell()}
        CANARY_HEADER=${canaryHeader} python3 tests/business-smoke/run.py ${svc} ${params.BACKEND_IP}
      """,
      "CANARY_HEADER=${canaryHeader} python3 tests/business-smoke/run.py ${svc} ${params.BACKEND_IP}"
    )
  }
}

def runRouteSmokeSteps() {
  runWithMode(
    env.EFFECTIVE_EXECUTION_MODE,
    params.DEV_KUBE_CONTEXT,
    params.DEV_TEST_NAMESPACE,
    'python:3.11-slim',
    """
      ${devPodAptBootstrapShell()}
      ${devPodCloneRepoShell()}
      python3 tests/route-smoke-test/run.py ${params.TARGET_HOST} ${env.EFFECTIVE_ROUTE_PREFIX} ${params.ROUTE_MODE} ${params.BACKEND_IP}
    """,
    "python3 tests/route-smoke-test/run.py ${params.TARGET_HOST} ${env.EFFECTIVE_ROUTE_PREFIX} ${params.ROUTE_MODE} ${params.BACKEND_IP}"
  )
}

def runK8sNodeCheckSteps() {
  runWithMode(
    env.EFFECTIVE_EXECUTION_MODE,
    params.DEV_KUBE_CONTEXT,
    params.DEV_TEST_NAMESPACE,
    'python:3.11-slim',
    """
      ${devPodAptBootstrapShell()}
      ${devPodCloneRepoShell()}
      python3 tests/k8s-node-check/run.py
    """,
    """
      pip3 install requests >/dev/null 2>&1 || true
      python3 tests/k8s-node-check/run.py
    """
  )
}

def runK6LoadSteps() {
  runWithMode(
    env.EFFECTIVE_EXECUTION_MODE,
    params.DEV_KUBE_CONTEXT,
    params.DEV_TEST_NAMESPACE,
    'grafana/k6:0.49.0',
    """
      cat >/tmp/k6-script.js <<'EOF'
      import http from 'k6/http';
      import { check, sleep } from 'k6';
      const vus = __ENV.VUS || 10;
      const duration = __ENV.DURATION || '30s';
      const errorRate = __ENV.ERROR_RATE || '0.1';
      const service = __ENV.SERVICE_NAME || 'product';
      const target = __ENV.TARGET_URL || 'localhost';
      export const options = { vus: vus, duration: duration, thresholds: { http_req_failed: ['rate<' + errorRate], http_req_duration: ['p(95)<2000'] } };
      function getPrefix(s) { return ({ product:'/api/v1/products', order:'/api/v1/orders', inventory:'/api/v1/inventory', noti:'/api/v1/notifications', payment:'/api/v1/payments', client:'/' }[s] || '/api/v1/products'); }
      function probePath(s) { if (s === 'client') return '/'; if (s === 'order') return '/orders'; return '/health'; }
      export default function () { const prefix = getPrefix(service); const path = probePath(service); const params = { headers: { Host: 'dev.go-micro.local' } }; const res = http.get('http://' + target + prefix + path, params); check(res, { 'status is 200': (r) => r.status === 200 }); sleep(0.3); }
      EOF
      TARGET_URL=${params.BACKEND_IP} SERVICE_NAME=${params.K6_SERVICE_NAME} VUS=${params.K6_VUS} DURATION=${params.K6_DURATION} ERROR_RATE=${params.K6_ERROR_RATE} k6 run /tmp/k6-script.js
    """,
    """docker run --rm \
      -e TARGET_URL=${params.BACKEND_IP} \
      -e SERVICE_NAME=${params.K6_SERVICE_NAME} \
      -e VUS=${params.K6_VUS} \
      -e DURATION=${params.K6_DURATION} \
      -e ERROR_RATE=${params.K6_ERROR_RATE} \
      -v "\$(pwd)/tests/load-test/k6-script.js:/scripts/k6-script.js:ro" \
      grafana/k6:0.49.0 run /scripts/k6-script.js"""
  )
}

def shouldEnableCanaryHeaderForApiTests() {
  return params.CANARY_HEADER_API_TESTS == true
}

def validateKubeContext(String kubeContext) {
  String contextsRaw = sh(
    script: "kubectl config get-contexts -o name || true",
    returnStdout: true
  ).trim()
  List contexts = contextsRaw ? contextsRaw.split('\n').collect { it.trim() } : []
  if (!contexts.contains(kubeContext.trim())) {
    error("Không tìm thấy context '${kubeContext}' trong Jenkins KUBECONFIG=${env.KUBECONFIG}. Context hiện có: ${contextsRaw ?: '(none)'}.")
  }
}

def serviceToRoutePrefix(String svc) {
  if (!svc?.trim()) {
    return '/api/v1/products'
  }
  switch (svc.trim().toLowerCase()) {
    case 'product':
      return '/api/v1/products'
    case 'order':
      return '/api/v1/orders'
    case 'inventory':
      return '/api/v1/inventory'
    case 'noti':
      return '/api/v1/notifications'
    case 'payment':
      return '/api/v1/payments'
    default:
      return '/api/v1/products'
  }
}

def resolveEffectiveRoutePrefix(String routeParam, String depServices, String bizServices) {
  def p = routeParam?.trim()
  if (p && !p.equalsIgnoreCase('auto')) {
    return p
  }
  def b = bizServices?.trim()?.toLowerCase()
  def d = depServices?.trim()?.toLowerCase()
  if (b && b != 'all') {
    return serviceToRoutePrefix(b)
  }
  if (d && d != 'all') {
    return serviceToRoutePrefix(d)
  }
  return '/api/v1/products'
}

def resolveRolloutService(String rolloutService, String depServices, String bizServices) {
  if (rolloutService != null && rolloutService.trim() && !rolloutService.trim().equalsIgnoreCase('auto')) {
    return rolloutService.trim().toLowerCase()
  }
  def candidates = [] as Set
  [depServices, bizServices].each { raw ->
    if (!raw) {
      return
    }
    def t = raw.trim().toLowerCase()
    if (t == 'all') {
      return
    }
    t.split(',').collect { it.trim() }.findAll { it }.each { candidates << it }
  }
  if (candidates.size() == 1) {
    return candidates.first()
  }
  echo "Không thể auto-resolve rollout service (DEP='${depServices}', BIZ='${bizServices}')."
  echo "Đặt ROLLOUT_SERVICE=<service> để bật promote/abort tự động."
  return ''
}

def runRolloutAction(String kubeContext, String namespace, String service, String action) {
  if (!(action in ['promote', 'abort'])) {
    error("Unsupported rollout action: ${action}")
  }
  sh """
    set -e
    if kubectl argo rollouts --context ${kubeContext} version >/dev/null 2>&1; then
      kubectl argo rollouts --context ${kubeContext} -n ${namespace} ${action} ${service}
    else
      echo "kubectl-argo-rollouts not found, fallback to kubectl patch for action=${action}"
      if [ "${action}" = "promote" ]; then
        kubectl --context ${kubeContext} -n ${namespace} patch rollout ${service} --type merge -p '{"spec":{"paused":false}}'
      else
        kubectl --context ${kubeContext} -n ${namespace} patch rollout ${service} --type merge -p '{"spec":{"paused":true}}'
      fi
    fi
    kubectl --context ${kubeContext} -n ${namespace} get rollout ${service}
  """
}

def waitRolloutComplete(String kubeContext, String namespace, String service) {
  String waitRaw = (params.ROLLOUT_WAIT_TIMEOUT ?: '45m').trim()
  int waitSec = parseTimeoutSeconds(waitRaw)
  // Dùng withEnv + sh ''' để Groovy không parse ${…} trong chuỗi (lỗi CPS với --timeout='${waitRaw}').
  withEnv([
    'WRC_CTX=' + kubeContext,
    'WRC_NS=' + namespace,
    'WRC_SVC=' + service,
    'WRC_DEADLINE_SEC=' + waitSec.toString(),
  ]) {
    sh '''#!/bin/bash
set -e
echo "Chờ rollout ${WRC_SVC} tới Healthy sau promote (poll mỗi 5s, tối đa ~${WRC_DEADLINE_SEC}s)..."
if ! kubectl argo rollouts --context "${WRC_CTX}" version >/dev/null 2>&1; then
  echo "WARN: không có kubectl-argo-rollouts; dùng kubectl get rollout"
fi
deadline=$(( $(date +%s) + ${WRC_DEADLINE_SEC} ))
last_log=0
degraded_streak=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  ph=""
  if IFS= read -r ph < <(kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o jsonpath="{.status.phase}" 2>/dev/null); then
    :
  fi
  ph=${ph:-}
  case "$ph" in
    Healthy)
      echo "Rollout Healthy."
      kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o wide || true
      exit 0
      ;;
    Failed)
      echo "Rollout Failed."
      kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o wide || true
      kubectl argo rollouts --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" 2>/dev/null | head -40 || true
      exit 1
      ;;
    Degraded)
      # Argo đôi khi giữ phase=Degraded + RolloutAborted dù stable đủ pod (canary RS scale về 0).
      # Không so ready với spec.replicas: env có thể 7 nhưng cluster đang 5 → mismatch vĩnh viễn.
      cur=$(kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o jsonpath='{.status.replicas}' 2>/dev/null || true)
      ready=$(kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
      upd=$(kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o jsonpath='{.status.updatedReplicas}' 2>/dev/null || true)
      desired=$(kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
      cur=${cur:-}; ready=${ready:-}; upd=${upd:-}; desired=${desired:-}
      [ -z "$upd" ] && upd=0
      ok=0
      if [ -n "$cur" ] && [ "$cur" != "0" ] && [ "$ready" = "$cur" ] && [ "$upd" = "0" ]; then
        ok=1
      elif [ -n "$desired" ] && [ "$ready" = "$desired" ] && [ "$upd" = "0" ]; then
        ok=1
      fi
      if [ "$ok" = "1" ]; then
        echo "INFO: phase=Degraded nhưng fleet ổn định (status.replicas=${cur} ready=${ready}, spec.replicas=${desired}, updatedReplicas=${upd}) — coi như promote xong."
        kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o wide || true
        exit 0
      fi
      degraded_streak=$((degraded_streak + 1))
      if [ "$degraded_streak" -ge 36 ]; then
        echo "Rollout Degraded liên tục ~3 phút (36 lần poll), dừng."
        kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o wide || true
        kubectl argo rollouts --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" 2>/dev/null | head -40 || true
        exit 1
      fi
      echo "WARN: phase=Degraded (lần $degraded_streak/36, có thể tạm sau promote), tiếp tục chờ..."
      ;;
    "")
      degraded_streak=0
      ;;
    *)
      degraded_streak=0
      now=$(date +%s)
      if [ $((now - last_log)) -ge 30 ]; then
        echo "... vẫn chờ (phase=$ph)"
        kubectl argo rollouts --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" 2>/dev/null | head -25 || true
        last_log=$now
      fi
      ;;
  esac
  sleep 5
done
echo "Timeout: chưa thấy rollout Healthy sau ${WRC_DEADLINE_SEC}s (phase cuối: ${ph:-unknown})"
kubectl --context "${WRC_CTX}" -n "${WRC_NS}" get rollout "${WRC_SVC}" -o wide || true
exit 1
'''
  }
}
