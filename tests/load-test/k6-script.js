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

function getPrefix(service) {
  const prefixes = {
    product: '/api/v1/products',
    order: '/api/v1/orders',
    inventory: '/api/v1/inventory',
    noti: '/api/v1/notifications',
    payment: '/api/v1/payments',
    client: '/'
  };
  return prefixes[service] || '/api/v1/products';
}

function probePath(service) {
  if (service === 'client') return '/';
  if (service === 'order') return '/orders';
  return '/health';
}

export default function () {
  const prefix = getPrefix(service);
  const path = probePath(service);
  const params = {
    headers: {
      'Host': 'dev.go-micro.local'
    }
  };
  let res = http.get(`http://${target}${prefix}${path}`, params);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(0.3);
}
