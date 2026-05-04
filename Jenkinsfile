// Thay cho GitHub Actions external-smoke-tests: curl smoke + k6 (tests/).
// Agent cần: curl, sh; stage k6 cần Docker (CLI + quyền chạy docker run) hoặc tự đổi stage sang image có sẵn k6.
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'TARGET_HOST', defaultValue: 'dev.go-micro.local', description: 'Host trong URL + header Host cho route smoke (Traefik/Ingress :80).')
    string(name: 'BACKEND_IP', defaultValue: '172.18.255.10', description: 'IP gateway/Ingress: dependency & business (http://IP:port), route smoke (--resolve), k6 TARGET_URL.')
    string(name: 'ROUTE_PREFIX', defaultValue: '/api/v1/products', description: 'Path prefix cho route smoke (khớp Rollout/ingress).')
    booleanParam(name: 'ROUTE_SMOKE', defaultValue: true, description: 'Chạy route smoke canary/preview (curl qua --resolve, không cần ghi /etc/hosts).')
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
      parallel {
        stage('product') {
          steps {
            sh "./tests/dependency-check/run.sh product ${params.BACKEND_IP}"
          }
        }
        stage('inventory') {
          steps {
            sh "./tests/dependency-check/run.sh inventory ${params.BACKEND_IP}"
          }
        }
      }
    }

    stage('Business Smoke Test') {
      parallel {
        stage('product') {
          steps {
            sh "./tests/business-smoke/run.sh product ${params.BACKEND_IP}"
          }
        }
        stage('order') {
          steps {
            sh "./tests/business-smoke/run.sh order ${params.BACKEND_IP}"
          }
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
            -e SERVICE_NAME=product \\
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
