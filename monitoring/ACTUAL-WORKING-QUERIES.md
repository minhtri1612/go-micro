# ✅ PROMETHEUS QUERIES THAT ACTUALLY WORK

## Available Metrics in Your Services

### Order Service Only:
- `orders_created_total` - Counter
- `orders_updated_total` - Counter  
- `active_orders` - Gauge
- `order_processing_duration_seconds_*` - Histogram
- `order_status_updates_total{status}` - Counter (if implemented)

### All Services:
- `go_goroutines` - Goroutine count
- `go_memstats_*` - Memory stats
- `go_gc_duration_seconds_*` - GC metrics
- `process_*` - Process metrics
- `promhttp_metric_handler_requests_total` - Prometheus handler requests

## 1. SERVICE HEALTH ✅

```promql
# All services UP/DOWN status
up{job=~".*go-micro.*"}

# By specific job
up{job="go-micro/go-micro-api-gateway"}
up{job="go-micro/go-micro-order-service"}
up{job="go-micro/go-micro-product-service"}
```

## 2. ORDER SERVICE BUSINESS METRICS ✅

```promql
# Orders created per second
rate(orders_created_total{job="go-micro/go-micro-order-service"}[5m])

# Orders created per minute
rate(orders_created_total{job="go-micro/go-micro-order-service"}[5m]) * 60

# Total orders created (last hour)
increase(orders_created_total{job="go-micro/go-micro-order-service"}[1h])

# Active orders count (current)
active_orders{job="go-micro/go-micro-order-service"}

# Orders updated per second
rate(orders_updated_total{job="go-micro/go-micro-order-service"}[5m])

# Total order processing time
rate(order_processing_duration_seconds_sum{job="go-micro/go-micro-order-service"}[5m])
```

## 3. GO RUNTIME METRICS ✅

```promql
# Goroutines per service
go_goroutines{job=~".*go-micro.*"}

# Memory allocated (current)
go_memstats_heap_alloc_bytes{job=~".*go-micro.*"}

# Memory allocated (total)
go_memstats_alloc_bytes_total{job=~".*go-micro.*"}

# Memory heap in use
go_memstats_heap_inuse_bytes{job=~".*go-micro.*"}

# GC frequency (GCs per second)
rate(go_gc_duration_seconds_count{job=~".*go-micro.*"}[5m])

# Total GC time
rate(go_gc_duration_seconds_sum{job=~".*go-micro.*"}[5m])
```

## 4. PROCESS METRICS ✅

```promql
# CPU usage (per service)
rate(process_cpu_seconds_total{job=~".*go-micro.*"}[5m])

# Memory (RSS)
process_resident_memory_bytes{job=~".*go-micro.*"}

# Open file descriptors
process_open_fds{job=~".*go-micro.*"}

# Process uptime
time() - process_start_time_seconds{job=~".*go-micro.*"}
```

## 5. KUBERNETES POD METRICS ✅

```promql
# CPU usage per pod
sum(rate(container_cpu_usage_seconds_total{namespace="go-micro",container!="POD"}[5m])) by (pod)

# Memory usage per pod
sum(container_memory_working_set_bytes{namespace="go-micro",container!="POD"}) by (pod)

# Memory usage percentage (if limits set)
sum(container_memory_working_set_bytes{namespace="go-micro",container!="POD"}) by (pod) / sum(container_spec_memory_limit_bytes{namespace="go-micro",container!="POD"}) by (pod) * 100

# Pod restarts
sum(increase(kube_pod_container_status_restarts_total{namespace="go-micro"}[1h])) by (pod)
```

## 6. DATABASE METRICS ✅ (If postgres_exporter configured)

```promql
# PostgreSQL connections
pg_stat_activity_count{datname!~"template.*|postgres"}

# Database size
pg_database_size_bytes{datname!~"template.*|postgres"}

# Cache hit ratio
sum(pg_stat_database_blks_hit{datname!~"template.*|postgres"}) / (sum(pg_stat_database_blks_hit{datname!~"template.*|postgres"}) + sum(pg_stat_database_blks_read{datname!~"template.*|postgres"}))
```

## 7. REDIS METRICS ✅ (If redis_exporter configured)

```promql
# Redis memory
redis_memory_used_bytes

# Redis connections
redis_connected_clients

# Redis commands per second
sum(rate(redis_commands_total[5m]))
```

## 8. RABBITMQ METRICS ✅ (If rabbitmq_exporter configured)

```promql
# Queue messages
rabbitmq_queue_messages

# Queue messages ready
rabbitmq_queue_messages_ready
```

## 9. PROMETHEUS HANDLER METRICS ✅

```promql
# Total /metrics requests
promhttp_metric_handler_requests_total{job=~".*go-micro.*"}

# Rate of /metrics requests
rate(promhttp_metric_handler_requests_total{job=~".*go-micro.*"}[5m])
```

## 10. DASHBOARD QUERIES ✅

### Service Overview Panel
```promql
# Services UP count
count(up{job=~".*go-micro.*"} == 1)

# Services DOWN count  
count(up{job=~".*go-micro.*"} == 0)

# Service list with status
up{job=~".*go-micro.*"}
```

### Order Service Dashboard
```promql
# Orders created today
sum(increase(orders_created_total{job="go-micro/go-micro-order-service"}[24h]))

# Orders per minute
rate(orders_created_total{job="go-micro/go-micro-order-service"}[1m]) * 60

# Active orders trend
active_orders{job="go-micro/go-micro-order-service"}
```

## ⚠️ METRICS THAT DON'T EXIST

These require HTTP middleware to be added:
- ❌ `http_requests_total`
- ❌ `http_request_duration_seconds`
- ❌ HTTP status codes, endpoints, methods

## 💡 TIP

Use these queries in Grafana - they all work with your current setup!

