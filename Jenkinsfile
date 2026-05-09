// External quality gate pipeline: dependency/business/route smoke + k6.
// Agent cần: curl, sh; stage k6 cần Docker (CLI + quyền chạy docker run) hoặc tự đổi stage sang image có sẵn k6.
// Bốn stage test chạy song song (Declarative parallel); trong Dependency/Business các service chạy tuần tự để Blue Ocean không vẽ nhầm thành chuỗi tuần tự (tránh lồng script { parallel }).

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
  }

  parameters {
    choice(
      name: 'PIPELINE_SCOPE',
      choices: ['full', 'dependency-only', 'business-only', 'route-smoke-only', 'load-only'],
      description: '`full` = Prepare + mọi stage + Promote (nếu bật). `*-only` = chỉ Prepare + đúng một nhóm test; bỏ qua Promote (không đụng rollout).'
    )
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
  }

  stages {
    stage('Prepare') {
      steps {
        sh 'kubectl version --client'
        script {
          validateKubeContext(params.DEV_KUBE_CONTEXT)
          env.RESOLVED_ROLLOUT_SERVICE = resolveRolloutService(params.ROLLOUT_SERVICE, params.DEPENDENCY_SERVICES, params.BUSINESS_SERVICES)
          env.EFFECTIVE_ROUTE_PREFIX = resolveEffectiveRoutePrefix(params.ROUTE_PREFIX, params.DEPENDENCY_SERVICES, params.BUSINESS_SERVICES)
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
          expression { params.PIPELINE_SCOPE != 'load-only' }
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
        expression { params.PIPELINE_SCOPE == 'full' }
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
          expression { params.PIPELINE_SCOPE == 'full' }
          expression { env.RESOLVED_ROLLOUT_SERVICE?.trim() }
          expression { params.AUTO_PROMOTE == false && params.ENABLE_MANUAL_ROLLOUT_GATE == true }
        }
      }
      steps {
        script {
          echo "--- QUALITY GATES PASSED ---"
          echo "Chờ chọn hành động rollout cho service: ${env.RESOLVED_ROLLOUT_SERVICE}"
          def decision = 'Promote to stable'
          timeout(time: 30, unit: 'MINUTES') {
            decision = input(
              id: "rollout-decision-${env.BUILD_NUMBER}",
              message: "Quality gate PASS cho [${env.RESOLVED_ROLLOUT_SERVICE}]. Chọn Promote hoặc Rollback.",
              ok: 'Xác nhận',
              parameters: [
                choice(name: 'ROLLOUT_ACTION', choices: ['Promote to stable', 'Rollback now'], description: 'Hành động rollout')
              ]
            )
          }
          if (decision == 'Rollback now') {
            runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
            error("Manual decision = rollback. Rollout đã abort theo yêu cầu.")
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
          expression { params.PIPELINE_SCOPE == 'full' }
          expression { env.RESOLVED_ROLLOUT_SERVICE?.trim() }
          expression { params.AUTO_PROMOTE == true }
        }
      }
      steps {
        script {
          runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'promote')
        }
      }
    }
  }

  post {
    failure {
      script {
        if (params.PIPELINE_SCOPE == 'full' && params.AUTO_ABORT && env.RESOLVED_ROLLOUT_SERVICE?.trim()) {
          runRolloutAction(params.DEV_KUBE_CONTEXT, params.ROLLOUT_NAMESPACE, env.RESOLVED_ROLLOUT_SERVICE, 'abort')
        } else if (params.PIPELINE_SCOPE == 'full' && !params.AUTO_ABORT && env.RESOLVED_ROLLOUT_SERVICE?.trim()) {
          def failDecision = params.ON_FAILURE_MANUAL_ACTION ?: 'Rollback now'
          timeout(time: 20, unit: 'MINUTES') {
            failDecision = input(
              id: "failure-action-${env.BUILD_NUMBER}",
              message: "Pipeline FAILED cho [${env.RESOLVED_ROLLOUT_SERVICE}]. Chọn rollback hay giữ nguyên trạng thái rollout.",
              ok: 'Xác nhận',
              parameters: [
                choice(name: 'FAILURE_ACTION', choices: ['Rollback now', 'Do nothing'], description: 'Hành động khi fail')
              ]
            )
          }
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
  sh """
    set -e
    kubectl --context ${kubeContext} -n ${namespace} run ${podName} --image=${image} --restart=Never --overrides='{"apiVersion":"v1","spec":{"serviceAccountName":"${serviceAccount}"}}' --command -- sh -lc '${escaped}'
    START=\$(date +%s)
    while true; do
      PHASE=\$(kubectl --context ${kubeContext} -n ${namespace} get pod/${podName} -o jsonpath='{.status.phase}' 2>/dev/null || echo Unknown)
      if [ "\$PHASE" = "Succeeded" ] || [ "\$PHASE" = "Failed" ]; then
        break
      fi
      NOW=\$(date +%s)
      if [ \$((NOW-START)) -ge ${timeoutSeconds} ]; then
        echo "Pod ${podName} timeout after ${timeout} (current phase=\$PHASE)"
        PHASE="Timeout"
        break
      fi
      sleep 2
    done
    kubectl --context ${kubeContext} -n ${namespace} logs ${podName} || true
    PHASE=\$(kubectl --context ${kubeContext} -n ${namespace} get pod/${podName} -o jsonpath='{.status.phase}')
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

def runDependencyCheckSteps() {
  def allDep = ['product', 'inventory', 'order', 'payment', 'noti']
  def svcs = expandServicesCsv(params.DEPENDENCY_SERVICES, allDep)
  def canaryHeader = shouldEnableCanaryHeaderForApiTests() ? 'true' : 'false'
  svcs.each { svc ->
    runWithMode(
      env.EFFECTIVE_EXECUTION_MODE,
      params.DEV_KUBE_CONTEXT,
      params.DEV_TEST_NAMESPACE,
      'python:3.11-slim',
      """
        apt-get update >/dev/null 2>&1
        apt-get install -y --no-install-recommends git ca-certificates >/dev/null 2>&1
        rm -rf /var/lib/apt/lists/*
        pip install requests >/dev/null 2>&1
        git clone --depth 1 https://github.com/minhtri1612/go-micro.git /tmp/go-micro >/dev/null 2>&1
        cd /tmp/go-micro
        CANARY_HEADER=${canaryHeader} python3 tests/dependency-check/run.py ${svc} ${params.BACKEND_IP}
      """,
      "CANARY_HEADER=${canaryHeader} python3 tests/dependency-check/run.py ${svc} ${params.BACKEND_IP}"
    )
  }
}

def runBusinessSmokeSteps() {
  def allBiz = ['product', 'inventory', 'order', 'payment', 'noti']
  def svcs = expandServicesCsv(params.BUSINESS_SERVICES, allBiz)
  def canaryHeader = shouldEnableCanaryHeaderForApiTests() ? 'true' : 'false'
  svcs.each { svc ->
    runWithMode(
      env.EFFECTIVE_EXECUTION_MODE,
      params.DEV_KUBE_CONTEXT,
      params.DEV_TEST_NAMESPACE,
      'python:3.11-slim',
      """
        apt-get update >/dev/null 2>&1
        apt-get install -y --no-install-recommends git ca-certificates >/dev/null 2>&1
        rm -rf /var/lib/apt/lists/*
        pip install requests >/dev/null 2>&1
        git clone --depth 1 https://github.com/minhtri1612/go-micro.git /tmp/go-micro >/dev/null 2>&1
        cd /tmp/go-micro
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
      apt-get update >/dev/null 2>&1
      apt-get install -y --no-install-recommends git ca-certificates >/dev/null 2>&1
      rm -rf /var/lib/apt/lists/*
      pip install requests >/dev/null 2>&1
      git clone --depth 1 https://github.com/minhtri1612/go-micro.git /tmp/go-micro >/dev/null 2>&1
      cd /tmp/go-micro
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
      apt-get update >/dev/null 2>&1
      apt-get install -y --no-install-recommends git ca-certificates >/dev/null 2>&1
      rm -rf /var/lib/apt/lists/*
      pip install requests >/dev/null 2>&1
      git clone --depth 1 https://github.com/minhtri1612/go-micro.git /tmp/go-micro >/dev/null 2>&1
      cd /tmp/go-micro
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
