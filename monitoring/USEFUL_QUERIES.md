# 📊 Prometheus Useful Queries & Stress Test Commands

Tài liệu này lưu trữ các câu lệnh PromQL quan trọng và các lệnh dập tải để kiểm tra sức khỏe hệ thống.

---

## 🛠 I. Stress Test Commands (Lệnh dập tải)

Dùng để tạo lưu lượng truy cập giả lập, giúp kiểm tra tính ổn định của hệ thống.

### 1. Dập tải bằng wget (Chạy từ bên trong Pod)
Bắn 500 request, tối đa 20 luồng cùng lúc.
```bash
kubectl --context kind-dev -n microservices-dev exec $(kubectl --context kind-dev -n microservices-dev get pod -l app.kubernetes.io/name=product -o name | head -n 1) -- \
sh -c "seq 500 | xargs -I{} -P 20 wget -qO- http://localhost:8080/health"
```

### 2. Dập tải bằng Apache Benchmark (ab)
Ép 1000 request, với 100 request đồng thời (concurrency).
```bash
# Cài đặt nếu chưa có: sudo apt install apache2-utils
ab -n 1000 -c 100 http://dev.go-micro.local/api/v1/products/health
```

---

## 📈 II. Prometheus Queries (PromQL)

Dùng để dán vào Grafana để theo dõi kết quả.

### 1. Độ trễ P95 (Latency P95) - QUAN TRỌNG NHẤT
```promql
histogram_quantile(0.95, sum(rate(gin_request_duration_bucket{pod=~"product-.*"}[1m])) by (le, pod))
```

### 2. Tỉ lệ thành công (Success Rate %)
```promql
sum(rate(gin_uri_request_total{pod=~"product-.*", code=~"2.*"}[1m])) / sum(rate(gin_uri_request_total{pod=~"product-.*"}[1m])) * 100
```

### 3. Lưu lượng truy cập (Requests Per Second - RPS)
```promql
sum(rate(gin_request_total{pod=~"product-.*"}[1m])) by (pod)
```

### 4. Top các API bị lỗi (Top Error Routes)
```promql
sum(rate(gin_uri_request_total{pod=~"product-.*", code!~"2.*"}[1m])) by (uri, code)
```

### 5. Tài nguyên CPU & RAM
```promql
# CPU Usage
sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{pod=~"product-.*"}) by (pod)

# Memory Usage
sum(container_memory_working_set_bytes{pod=~"product-.*"}) by (pod)
```
