// Luồng lab (PIPELINE_SCOPE=auto — mặc định):
//   Chỉ sửa env/dev.yaml        → SKIP Build + Push Git; chạy Prepare + test + promote gate (test tag GitOps).
//   Sửa order-service/ (ví dụ) → CHỈ build/push order; bump tag order; Push Git; rồi test + promote.
//   Build bump tag              → snapshot env/ trước bump; rollback = revert Git + abort rollout.
//   Sau promote Healthy         → Emergency Rollback Gate (15 phút) nếu ENABLE_POST_PROMOTE_GATE.
//   ci: bump [skip ci] (SCM) → SKIP (tránh loop); Build Now (user) → test+promote tag env/.
//   build-only / full — override thủ công khi cần.
// Credentials: dockerhub-credentials, github-go-micro-pat (bắt buộc cho PUSH_GIT).
//
// Refactor: helpers tách sang `.jenkins/lib/*.groovy` (load ở stage Init); Jenkinsfile chỉ còn stage definition.
//   .jenkins/lib/precheck.groovy → scope detection + precheck
//   .jenkins/lib/build.groovy    → image build + git push
//   .jenkins/lib/rollback.groovy → rollback + promote/abort + wait rollout
//   .jenkins/lib/tests.groovy    → dependency / business / route / k6 / k8s-node + prepare helpers

def libPrecheck
def libBuild
def libRollback
def libTests

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
      choices: ['auto', 'build-only', 'build-and-full', 'full', 'dependency-only', 'business-only', 'route-smoke-only', 'load-only', 'rollback'],
      description: '`auto` (mặc định): detect commit — env/ only → test; *-service/ → build đúng service + test. `rollback` = patch-1 tag trong env/ (verify Hub) + push Git → Argo sync. `build-only`/`full` = ép một nhánh.'
    )
    string(
      name: 'ROLLBACK_SERVICE',
      defaultValue: '',
      description: 'PIPELINE_SCOPE=rollback: service cần rollback (vd: payment). Để trống = rollback product,inventory,order,payment,noti (không gồm client).'
    )
    choice(name: 'TARGET_ENV', choices: ['dev', 'staging'], description: 'env/<TARGET_ENV>.yaml — dùng khi scope có build.')
    string(
      name: 'ROLLBACK_VERSION',
      defaultValue: '',
      description: 'Rollback về semver CỤ THỂ, vd: v1.0.2 (hoặc 1.0.2 — tự thêm v). Chỉ áp dụng khi ROLLBACK_SERVICE chỉ định 1 service. Để trống = tự động patch-1 từ tag hiện tại trong env/.'
    )
    choice(
      name: 'BUILD_SERVICES',
      choices: ['auto', 'all', 'product', 'inventory', 'order', 'payment', 'noti', 'client'],
      description: '`auto` (mặc định) = chỉ *-service/ hoặc client/ đổi trong commit; không đổi → skip build. `all` = build cả 6+client (chỉ khi cần rebuild hàng loạt).'
    )
    booleanParam(name: 'PUSH_GIT', defaultValue: true, description: 'Sau build: commit + push env/<TARGET_ENV>.yaml lên Git (Argo sync tag mới).')
    booleanParam(
      name: 'DEPLOY_EXISTING_ENV_TAGS',
      defaultValue: false,
      description: 'Bỏ qua build/push Docker: dùng tag trong env/<TARGET_ENV>.yaml (phải có trên Hub). Chạy test+promote. Bật khi vừa rollback tag env/ (commit có thể chỉ Jenkinsfile).'
    )
    string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Branch push Git sau build.')
    string(name: 'DEV_KUBE_CONTEXT', defaultValue: 'kind-dev', description: 'Kubernetes context của cụm dev để chạy pod test.')
    string(name: 'DEV_TEST_NAMESPACE', defaultValue: 'default', description: 'Namespace trên cụm dev để tạo pod test tạm.')
    string(name: 'DEV_TEST_SERVICE_ACCOUNT', defaultValue: 'go-micro-test-runner', description: 'ServiceAccount dùng cho pod test (cần có quyền list nodes cho K8s API node check).')
    string(name: 'ROLLOUT_NAMESPACE', defaultValue: 'microservices-dev', description: 'Namespace chứa Argo Rollout cần promote/abort.')
    string(name: 'ROLLOUT_SERVICE', defaultValue: 'auto', description: '`auto` = tự suy ra từ DEPENDENCY_SERVICES/BUSINESS_SERVICES (chỉ khi 1 service); hoặc ghi rõ service, ví dụ: inventory.')
    booleanParam(name: 'AUTO_PROMOTE', defaultValue: false, description: 'Tự promote rollout khi toàn bộ quality gate pass. Nếu FALSE, Jenkins sẽ dừng lại hiện nút bấm cho anh duyệt.')
    booleanParam(name: 'AUTO_ABORT', defaultValue: true, description: 'Tự abort rollout khi pipeline fail hoặc anh nhấn nút Abort.')
    booleanParam(name: 'ENABLE_MANUAL_ROLLOUT_GATE', defaultValue: true, description: 'Hiện bước nút bấm Promote/Rollback trên Jenkins UI sau khi test pass.')
    booleanParam(
      name: 'ENABLE_POST_PROMOTE_GATE',
      defaultValue: true,
      description: 'Sau promote Healthy: hiện nút Emergency Rollback (timeout 15 phút). Timeout → giữ nguyên.'
    )
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
    booleanParam(name: 'CANARY_HEADER_API_TESTS', defaultValue: false, description: 'Ép X-Canary:true. Mặc định tắt; pipeline TỰ bật khi rollout Paused + stable Endpoints trống + canary còn pod (trước khi bấm Promote).')
    booleanParam(name: 'ENABLE_K8S_NODE_CHECK', defaultValue: true, description: 'Chạy check Kubernetes API thuần (requests) để list nodes trước test chính.')
    string(name: 'K6_SERVICE_NAME', defaultValue: 'product', description: 'Service k6 load-test (map port trong tests/load-test/k6-script.js).')
    string(name: 'K6_VUS', defaultValue: '5', description: 'k6 virtual users')
    string(name: 'K6_DURATION', defaultValue: '15s', description: 'k6 duration')
    string(name: 'K6_ERROR_RATE', defaultValue: '0.1', description: 'k6 http_req_failed threshold (rate<value)')
    string(name: 'POD_WAIT_TIMEOUT', defaultValue: '600s', description: 'Timeout chờ mỗi pod test hoàn thành (ví dụ: 300s, 600s).')
    string(name: 'ROLLOUT_WAIT_TIMEOUT', defaultValue: '45m', description: 'Sau promote: chờ rollout tới xong (kubectl argo rollouts status --watch). GNU timeout hoặc flag CLI; ví dụ 45m, 30m.')
  }

  stages {
    // Stage Init: luôn chạy. Declarative SCM đã clone repo trước stages → load 4 file lib có sẵn.
    // Khi PIPELINE_SCOPE không cần Checkout fresh (vd dependency-only), libs vẫn được load từ workspace
    // đã có sẵn từ Declarative checkout — tránh null reference ở when{} các stage sau.
    stage('Init') {
      steps {
        checkout scm
        script {
          libPrecheck = load '.jenkins/lib/precheck.groovy'
          libBuild    = load '.jenkins/lib/build.groovy'
          libRollback = load '.jenkins/lib/rollback.groovy'
          libTests    = load '.jenkins/lib/tests.groovy'
          echo 'Loaded helpers: precheck / build / rollback / tests'
        }
      }
    }

    stage('Rollback') {
      when {
        expression { params.PIPELINE_SCOPE == 'rollback' }
      }
      steps {
        script {
          libRollback.runRollbackSteps()
        }
      }
    }

    stage('Precheck') {
      when {
        expression { libPrecheck.pipelineNeedsPrecheck() }
      }
      steps {
        script {
          libPrecheck.precheckPipeline()
        }
      }
    }

    stage('Build & push images') {
      when {
        expression { libPrecheck.pipelineNeedsImageBuild() }
      }
      steps {
        script {
          if (libBuild.isSkipImageBuild()) {
            echo "Build skipped (Precheck). SKIP_IMAGE_BUILD=${env.SKIP_IMAGE_BUILD ?: '(unset)'}"
          } else {
            libBuild.runImageBuildSteps()
          }
        }
      }
    }

    stage('Push Git') {
      when {
        allOf {
          expression { libPrecheck.pipelineNeedsImageBuild() }
          expression { params.PUSH_GIT == true }
        }
      }
      steps {
        script {
          if (libBuild.isSkipImageBuild()) {
            echo 'Push Git skipped (không có build).'
          } else {
            libBuild.runCiGitPushSteps()
          }
        }
      }
    }

    stage('Prepare') {
      when {
        expression { libPrecheck.pipelineNeedsQualityGates() }
      }
      steps {
        sh 'kubectl version --client'
        script {
          libTests.validateKubeContext(params.DEV_KUBE_CONTEXT)
          env.RESOLVED_ROLLOUT_SERVICE = libTests.resolveRolloutService(params.ROLLOUT_SERVICE, libTests.getEffectiveDependencyServices(), libTests.getEffectiveBusinessServices())
          env.EFFECTIVE_ROUTE_PREFIX = libTests.resolveEffectiveRoutePrefix(params.ROUTE_PREFIX, libTests.getEffectiveDependencyServices(), libTests.getEffectiveBusinessServices())
          echo "Execution mode: ${env.EFFECTIVE_EXECUTION_MODE}"
          echo "Rollout target: ${params.ROLLOUT_NAMESPACE}/${env.RESOLVED_ROLLOUT_SERVICE ?: '(none)'}"
          echo "Route smoke prefix: ${env.EFFECTIVE_ROUTE_PREFIX} (ROUTE_PREFIX param='${params.ROUTE_PREFIX}')"
          def autoCanary = libTests.detectAutoCanaryHeaderForTests()
          env.AUTO_CANARY_HEADER_FOR_TESTS = autoCanary ? 'true' : 'false'
          if (autoCanary) {
            echo 'Canary pause: stable chưa có backend — test dùng X-Canary (không cần promote tay trước Jenkins).'
          }
        }
      }
    }

    stage('K8s API Node Check') {
      when {
        allOf {
          expression { params.ENABLE_K8S_NODE_CHECK == true }
          expression { libPrecheck.pipelineNeedsQualityGates() && params.PIPELINE_SCOPE != 'load-only' }
        }
      }
      steps {
        script {
          sh "kubectl --context ${params.DEV_KUBE_CONTEXT} apply -f tests/k8s-node-check/rbac.yaml"
          libTests.runK8sNodeCheckSteps()
        }
      }
    }

    // Một khối parallel duy nhất — không tạo stage trùng tên ở ngoài (Blue Ocean sẽ không rời rạc).
    stage('Parallel tests') {
      when {
        expression { libPrecheck.pipelineNeedsParallelTests() }
      }
      parallel {
        stage('Dependency Check') {
          when {
            expression { libPrecheck.pipelineNeedsDependencyCheck() }
          }
          steps {
            script {
              libTests.runDependencyCheckSteps()
            }
          }
        }
        stage('Business Smoke Test') {
          when {
            expression { libPrecheck.pipelineNeedsBusinessSmoke() }
          }
          steps {
            script {
              libTests.runBusinessSmokeSteps()
            }
          }
        }
        stage('Route Smoke') {
          when {
            allOf {
              expression { params.ROUTE_SMOKE != false && params.ROUTE_SMOKE != 'false' }
              expression { libPrecheck.pipelineNeedsRouteSmoke() }
            }
          }
          steps {
            script {
              libTests.runRouteSmokeSteps()
            }
          }
        }
        stage('Load Test (k6)') {
          when {
            expression { libPrecheck.pipelineNeedsK6Load() }
          }
          steps {
            script {
              libTests.runK6LoadSteps()
            }
          }
        }
      }
    }

    stage('Rollout Decision Gate') {
      when {
        allOf {
          expression {
            (libPrecheck.pipelineNeedsQualityGates() && (params.PIPELINE_SCOPE in ['full', 'build-and-full', 'auto'])) ||
            params.PIPELINE_SCOPE == 'rollback'
          }
          expression { env.RESOLVED_ROLLOUT_SERVICE?.trim() }
          expression { params.AUTO_PROMOTE == false && params.ENABLE_MANUAL_ROLLOUT_GATE == true }
        }
      }
      steps {
        script {
          def isRollback = params.PIPELINE_SCOPE == 'rollback'
          if (isRollback) {
            echo "--- ROLLBACK SYNC PASSED ---"
            echo "Argo CD đã sync rollout về tag cũ. Bấm Promote để tiến tới 100% stable."
          } else {
            echo "--- QUALITY GATES PASSED ---"
            echo "Chờ chọn hành động rollout cho service: ${env.RESOLVED_ROLLOUT_SERVICE}"
          }
          def rawDecision = null
          def msg = isRollback ?
            "Rollback [${env.RESOLVED_ROLLOUT_SERVICE}] đã sync. Promote để hoàn tất, Abort để dừng (giữ canary)." :
            "Quality gate PASS cho [${env.RESOLVED_ROLLOUT_SERVICE}]. Chọn Promote hoặc Rollback."
          def choices = isRollback ? ['Promote to stable', 'Abort rollout'] : ['Promote to stable', 'Rollback now']
          timeout(time: 30, unit: 'MINUTES') {
            rawDecision = input(
              id: "rollout-decision-${env.BUILD_NUMBER}",
              message: msg,
              ok: 'Xác nhận',
              parameters: [
                choice(name: 'ROLLOUT_ACTION', choices: choices, description: 'Hành động rollout')
              ]
            )
          }
          // input() with parameters returns a Map (e.g. [ROLLOUT_ACTION: '...']), not a plain String.
          def decision = (rawDecision instanceof Map) ? rawDecision['ROLLOUT_ACTION']?.toString() : rawDecision?.toString()
          echo "Rollout manual choice: ${decision}"
          if (decision == 'Rollback now') {
            env.ROLLBACK_ALREADY_HANDLED = 'true'
            libRollback.rollbackGitTags("env/${params.TARGET_ENV}.yaml")
            libRollback.runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
            error("Manual decision = rollback. Rollout đã abort theo yêu cầu.")
          } else if (decision == 'Abort rollout') {
            libRollback.runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
            error("Manual decision = abort (rollback scope). Rollout đã abort — env/ giữ tag mới (đã rollback).")
          } else if (decision == 'Promote to stable') {
            libRollback.runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'promote')
            libRollback.waitRolloutComplete(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE)
            env.ROLLOUT_PROMOTED = 'true'
          } else {
            error("Unexpected ROLLOUT_ACTION value: '${decision}'")
          }
        }
      }
    }

    stage('Promote Rollout') {
      when {
        allOf {
          expression {
            (libPrecheck.pipelineNeedsQualityGates() && (params.PIPELINE_SCOPE in ['full', 'build-and-full', 'auto'])) ||
            params.PIPELINE_SCOPE == 'rollback'
          }
          expression { env.RESOLVED_ROLLOUT_SERVICE?.trim() }
          expression { params.AUTO_PROMOTE == true }
        }
      }
      steps {
        script {
          libRollback.runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'promote')
          libRollback.waitRolloutComplete(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE)
          env.ROLLOUT_PROMOTED = 'true'
        }
      }
    }

    stage('Emergency Rollback Gate') {
      when {
        allOf {
          expression { params.ENABLE_POST_PROMOTE_GATE == true || params.ENABLE_POST_PROMOTE_GATE == 'true' }
          expression { env.RESOLVED_ROLLOUT_SERVICE?.trim() }
          expression { env.ROLLOUT_PROMOTED == 'true' }
          expression { params.PIPELINE_SCOPE in ['full', 'build-and-full', 'auto'] }
        }
      }
      steps {
        script {
          libRollback.runEmergencyRollbackGateSteps()
        }
      }
    }
  }

  post {
    failure {
      script {
        if (libRollback != null && libRollback.shouldAutoAbortRolloutOnFailure()) {
          echo "AUTO_ABORT: abort rollout ${env.RESOLVED_ROLLOUT_SERVICE}"
          libRollback.rollbackGitTags("env/${params.TARGET_ENV}.yaml")
          libRollback.runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
        } else if (libRollback != null && libPrecheck != null && libPrecheck.pipelineNeedsQualityGates() && !params.AUTO_ABORT && env.RESOLVED_ROLLOUT_SERVICE?.trim()) {
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
            libRollback.rollbackGitTags("env/${params.TARGET_ENV}.yaml")
            libRollback.runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
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
