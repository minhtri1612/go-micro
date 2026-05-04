// Thay cho GitHub Actions external-smoke-tests: curl smoke + k6 (tests/).
// Agent cần: curl, sh; stage k6 cần Docker (CLI + quyền chạy docker run) hoặc tự đổi stage sang image có sẵn k6.

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

pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'TARGET_HOST', defaultValue: 'dev.go-micro.local', description: 'Host trong URL + header Host cho route smoke (Traefik/Ingress :80).')
    string(name: 'BACKEND_IP', defaultValue: '172.18.255.10', description: 'IP gateway/Ingress: dependency & business (http://IP:port), route smoke (--resolve), k6 TARGET_URL.')
    string(name: 'DEPENDENCY_SERVICES', defaultValue: 'all', description: '`all` = chạy hết service có trong tests/dependency-check/run.sh; hoặc CSV: product,inventory,order,noti,payment')
    string(name: 'BUSINESS_SERVICES', defaultValue: 'all', description: '`all` = chạy hết service có trong tests/business-smoke/run.sh; hoặc CSV tùy chọn.')
    string(name: 'ROUTE_PREFIX', defaultValue: '/api/v1/products', description: 'Path prefix cho route smoke (khớp Rollout/ingress).')
    booleanParam(name: 'ROUTE_SMOKE', defaultValue: true, description: 'Chạy route smoke canary/preview (curl qua --resolve, không cần ghi /etc/hosts).')
    string(name: 'K6_SERVICE_NAME', defaultValue: 'product', description: 'Service k6 load-test (map port trong tests/load-test/k6-script.js).')
    string(name: 'K6_VUS', defaultValue: '5', description: 'k6 virtual users')
    string(name: 'K6_DURATION', defaultValue: '15s', description: 'k6 duration')
    string(name: 'K6_ERROR_RATE', defaultValue: '0.1', description: 'k6 http_req_failed threshold (rate<value)')
  }

  stages {
    stage('Prepare') {
      steps {
        sh 'chmod +x tests/*/run.sh'
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
              sh "./tests/dependency-check/run.sh ${svc} ${params.BACKEND_IP}"
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
              sh "./tests/business-smoke/run.sh ${svc} ${params.BACKEND_IP}"
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
      parallel {
        stage('canary') {
          steps {
            sh "./tests/route-smoke-test/run.sh ${params.TARGET_HOST} ${params.ROUTE_PREFIX} canary ${params.BACKEND_IP}"
          }
        }
        stage('preview') {
          steps {
            sh "./tests/route-smoke-test/run.sh ${params.TARGET_HOST} ${params.ROUTE_PREFIX} preview ${params.BACKEND_IP}"
          }
        }
      }
    }

    stage('Load Test (k6)') {
      steps {
        sh """
          docker run --rm \\
            -e TARGET_URL=${params.BACKEND_IP} \\
            -e SERVICE_NAME=${params.K6_SERVICE_NAME} \\
            -e VUS=${params.K6_VUS} \\
            -e DURATION=${params.K6_DURATION} \\
            -e ERROR_RATE=${params.K6_ERROR_RATE} \\
            -v "${env.WORKSPACE}/tests/load-test:/scripts" \\
            grafana/k6 run /scripts/k6-script.js
        """
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}
