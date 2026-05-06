// External quality gate pipeline: dependency/business/route smoke + k6.
// Agent cần: curl, sh; stage k6 cần Docker (CLI + quyền chạy docker run) hoặc tự đổi stage sang image có sẵn k6.

pipeline {
  agent any

  options {
    disableConcurrentBuilds()
  }

  parameters {
    choice(name: 'EXECUTION_MODE', choices: ['auto', 'dev-pod', 'direct'], description: 'auto: tự chọn dev-pod nếu có context dev, ngược lại direct.')
    string(name: 'DEV_KUBE_CONTEXT', defaultValue: 'kind-dev', description: 'Kubernetes context của cụm dev để chạy pod test.')
    string(name: 'DEV_TEST_NAMESPACE', defaultValue: 'default', description: 'Namespace trên cụm dev để tạo pod test tạm.')
    string(name: 'TARGET_HOST', defaultValue: 'dev.go-micro.local', description: 'Host trong URL + header Host cho route smoke (Traefik/Ingress :80).')
    string(name: 'BACKEND_IP', defaultValue: '172.18.255.10', description: 'IP gateway/Ingress: dependency & business (http://IP:port), route smoke (--resolve), k6 TARGET_URL.')
    string(name: 'DEPENDENCY_SERVICES', defaultValue: 'all', description: '`all` = chạy hết service có trong tests/dependency-check/run.sh; hoặc CSV: product,inventory,order,noti,payment')
    string(name: 'BUSINESS_SERVICES', defaultValue: 'all', description: '`all` = chạy hết service có trong tests/business-smoke/run.sh; hoặc CSV tùy chọn.')
    string(name: 'ROUTE_PREFIX', defaultValue: '/api/v1/products', description: 'Path prefix cho route smoke qua ingress/gateway.')
    booleanParam(name: 'ROUTE_SMOKE', defaultValue: true, description: 'Chạy route smoke canary/preview (curl qua --resolve, không cần ghi /etc/hosts).')
    choice(name: 'ROUTE_MODE', choices: ['canary', 'preview', 'standard'], description: 'Mode route smoke để test traffic split trước promote.')
    string(name: 'K6_SERVICE_NAME', defaultValue: 'product', description: 'Service k6 load-test (map port trong tests/load-test/k6-script.js).')
    string(name: 'K6_VUS', defaultValue: '5', description: 'k6 virtual users')
    string(name: 'K6_DURATION', defaultValue: '15s', description: 'k6 duration')
    string(name: 'K6_ERROR_RATE', defaultValue: '0.1', description: 'k6 http_req_failed threshold (rate<value)')
  }

  stages {
    stage('Prepare') {
      steps {
        sh 'chmod +x tests/*/run.sh'
        sh 'kubectl version --client'
        script {
          env.EFFECTIVE_EXECUTION_MODE = resolveExecutionMode(params.EXECUTION_MODE, params.DEV_KUBE_CONTEXT)
          echo "Execution mode: ${env.EFFECTIVE_EXECUTION_MODE}"
          if (env.EFFECTIVE_EXECUTION_MODE == 'dev-pod') {
            validateKubeContext(params.DEV_KUBE_CONTEXT)
          }
        }
      }
    }

    stage('Dependency Check') {
      steps {
        script {
          def allDep = ['product', 'inventory', 'order', 'payment', 'noti']
          def svcs = expandServicesCsv(params.DEPENDENCY_SERVICES, allDep)
          def branches = [:]
          svcs.each { svc ->
            branches["dependency-${svc}"] = {
              runWithMode(
                env.EFFECTIVE_EXECUTION_MODE,
                params.DEV_KUBE_CONTEXT,
                params.DEV_TEST_NAMESPACE,
                'alpine:3.20',
                """
                  apk add --no-cache curl git >/dev/null
                  git clone --depth 1 https://github.com/minhtri1612/go-micro.git /tmp/go-micro >/dev/null 2>&1
                  cd /tmp/go-micro
                  chmod +x tests/*/run.sh
                  ./tests/dependency-check/run.sh ${svc} ${params.BACKEND_IP}
                """,
                "./tests/dependency-check/run.sh ${svc} ${params.BACKEND_IP}"
              )
            }
          }
          parallel branches
        }
      }
    }

    stage('Business Smoke Test') {
      steps {
        script {
          def allBiz = ['product', 'inventory', 'order', 'payment', 'noti']
          def svcs = expandServicesCsv(params.BUSINESS_SERVICES, allBiz)
          def branches = [:]
          svcs.each { svc ->
            branches["business-${svc}"] = {
              runWithMode(
                env.EFFECTIVE_EXECUTION_MODE,
                params.DEV_KUBE_CONTEXT,
                params.DEV_TEST_NAMESPACE,
                'alpine:3.20',
                """
                  apk add --no-cache curl git >/dev/null
                  git clone --depth 1 https://github.com/minhtri1612/go-micro.git /tmp/go-micro >/dev/null 2>&1
                  cd /tmp/go-micro
                  chmod +x tests/*/run.sh
                  ./tests/business-smoke/run.sh ${svc} ${params.BACKEND_IP}
                """,
                "./tests/business-smoke/run.sh ${svc} ${params.BACKEND_IP}"
              )
            }
          }
          parallel branches
        }
      }
    }

    stage('Route Smoke') {
      when {
        expression { params.ROUTE_SMOKE != false && params.ROUTE_SMOKE != 'false' }
      }
      steps {
        runWithMode(
          env.EFFECTIVE_EXECUTION_MODE,
          params.DEV_KUBE_CONTEXT,
          params.DEV_TEST_NAMESPACE,
          'alpine:3.20',
          """
            apk add --no-cache curl git >/dev/null
            git clone --depth 1 https://github.com/minhtri1612/go-micro.git /tmp/go-micro >/dev/null 2>&1
            cd /tmp/go-micro
            chmod +x tests/*/run.sh
            ./tests/route-smoke-test/run.sh ${params.TARGET_HOST} ${params.ROUTE_PREFIX} ${params.ROUTE_MODE} ${params.BACKEND_IP}
          """,
          "./tests/route-smoke-test/run.sh ${params.TARGET_HOST} ${params.ROUTE_PREFIX} ${params.ROUTE_MODE} ${params.BACKEND_IP}"
        )
      }
    }

    stage('Load Test (k6)') {
      steps {
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
    }
  }

  post {
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
  sh """
    set -e
    kubectl --context ${kubeContext} -n ${namespace} run ${podName} --image=${image} --restart=Never --command -- sh -lc '${escaped}'
    kubectl --context ${kubeContext} -n ${namespace} wait --for=jsonpath='{.status.phase}'=Succeeded pod/${podName} --timeout=1200s || true
    kubectl --context ${kubeContext} -n ${namespace} logs ${podName}
    PHASE=\$(kubectl --context ${kubeContext} -n ${namespace} get pod/${podName} -o jsonpath='{.status.phase}')
    kubectl --context ${kubeContext} -n ${namespace} delete pod/${podName} --ignore-not-found=true >/dev/null
    [ "\$PHASE" = "Succeeded" ] || (echo "Pod ${podName} failed with phase \$PHASE" && exit 1)
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

def validateKubeContext(String kubeContext) {
  String code = sh(
    script: "kubectl config get-contexts -o name | rg '^${kubeContext}\$' > /dev/null",
    returnStatus: true
  )
  if (code != 0) {
    String contexts = sh(script: "kubectl config get-contexts -o name || true", returnStdout: true).trim()
    error("Không tìm thấy context '${kubeContext}' trong Jenkins. Context hiện có: ${contexts ?: '(none)'}. Chọn EXECUTION_MODE=direct hoặc cung cấp kubeconfig có context dev.")
  }
}

def resolveExecutionMode(String mode, String kubeContext) {
  if (mode == 'direct' || mode == 'dev-pod') {
    return mode
  }
  String code = sh(
    script: "kubectl config get-contexts -o name | rg '^${kubeContext}\$' > /dev/null",
    returnStatus: true
  )
  return code == 0 ? 'dev-pod' : 'direct'
}
