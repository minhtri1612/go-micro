// External quality gate pipeline: dependency/business/route smoke + k6.
// Agent cần: curl, sh; stage k6 cần Docker (CLI + quyền chạy docker run) hoặc tự đổi stage sang image có sẵn k6.

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
    string(name: 'ROLLOUT_NAMESPACE', defaultValue: 'microservices-dev', description: 'Namespace chứa Argo Rollout cần promote/abort.')
    string(name: 'ROLLOUT_SERVICE', defaultValue: 'auto', description: '`auto` = tự suy ra từ DEPENDENCY_SERVICES/BUSINESS_SERVICES (chỉ khi 1 service); hoặc ghi rõ service, ví dụ: inventory.')
    booleanParam(name: 'AUTO_PROMOTE', defaultValue: true, description: 'Tự promote rollout khi toàn bộ quality gate pass.')
    booleanParam(name: 'AUTO_ABORT', defaultValue: true, description: 'Tự abort rollout khi pipeline fail.')
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
          validateKubeContext(params.DEV_KUBE_CONTEXT)
          env.RESOLVED_ROLLOUT_SERVICE = resolveRolloutService(params.ROLLOUT_SERVICE, params.DEPENDENCY_SERVICES, params.BUSINESS_SERVICES)
          echo "Execution mode: ${env.EFFECTIVE_EXECUTION_MODE}"
          echo "Rollout target: ${params.ROLLOUT_NAMESPACE}/${env.RESOLVED_ROLLOUT_SERVICE ?: '(none)'}"
        }
      }
    }

    // Các nhánh Dependency / Business / Route / k6 chạy song song (sau khi cả khối xong mới tới Promote).
    stage('Quality gate') {
      parallel {
        stage('Dependency Check') {
          when {
            anyOf {
              expression { params.PIPELINE_SCOPE == 'full' }
              expression { params.PIPELINE_SCOPE == 'dependency-only' }
            }
          }
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
          when {
            anyOf {
              expression { params.PIPELINE_SCOPE == 'full' }
              expression { params.PIPELINE_SCOPE == 'business-only' }
            }
          }
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
            allOf {
              expression { params.ROUTE_SMOKE != false && params.ROUTE_SMOKE != 'false' }
              anyOf {
                expression { params.PIPELINE_SCOPE == 'full' }
                expression { params.PIPELINE_SCOPE == 'route-smoke-only' }
              }
            }
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
          when {
            anyOf {
              expression { params.PIPELINE_SCOPE == 'full' }
              expression { params.PIPELINE_SCOPE == 'load-only' }
            }
          }
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
    }

    stage('Promote Rollout') {
      when {
        allOf {
          expression { params.PIPELINE_SCOPE == 'full' }
          expression { params.AUTO_PROMOTE && env.RESOLVED_ROLLOUT_SERVICE?.trim() }
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
  String contextsRaw = sh(
    script: "kubectl config get-contexts -o name || true",
    returnStdout: true
  ).trim()
  List contexts = contextsRaw ? contextsRaw.split('\n').collect { it.trim() } : []
  if (!contexts.contains(kubeContext.trim())) {
    error("Không tìm thấy context '${kubeContext}' trong Jenkins KUBECONFIG=${env.KUBECONFIG}. Context hiện có: ${contextsRaw ?: '(none)'}.")
  }
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
