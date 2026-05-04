import http from 'k6/http';
import { check, sleep } from 'k6';

// Read configuration from environment variables (passed by the pipeline)
const vus = __ENV.VUS || 10;
const duration = __ENV.DURATION || '30s';
const errorRate = __ENV.ERROR_RATE || '0.1';
const service = __ENV.SERVICE_NAME || 'product';
const target = __ENV.TARGET_URL || 'localhost';

export const options = {
  vus: vus,
  duration: duration,
  thresholds: {
    http_req_failed: [`rate<${errorRate}`],
    http_req_duration: ['p(95)<2000'],
  },
};

function targetPort(service) {
  const ports = { product: 8080, order: 8081, inventory: 8082, noti: 8083, payment: 8084, client: 80 };
  return ports[service] || 8080;
}

function probePath(service) {
  if (service === 'client') return '/';
  if (service === 'order') return '/orders';
  return '/health';
}

export default function () {
  const port = targetPort(service);
  const path = probePath(service);
  let res = http.get(`http://${target}:${port}${path}`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(0.3);
}
