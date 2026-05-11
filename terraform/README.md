# Terraform – RKE2 + OpenVPN + ALB/NLB (go-micro)

## Cấu trúc

- **`../terraform_secret/`** – stack tách chỉ tạo AWS Secrets Manager `app-credentials` + IAM ESO (dùng khi **chỉ** quản lý secret, không đụng RKE2). **Schema JSON secret trùng với `terraform/modules/secrets`** (DB_*, POSTGRES_*, `*_DB_NAME`, `STRIPE_SECRET_KEY`).
- **`modules/`** – VPC, IAM, keys, certificate, **secrets** (RKE2 token + app-credentials như trên), loadbalancers, openvpn, rke2
- **`environments/dev`**, **`environments/prod`**, **`environments/management`**

## Chạy theo environment

**Không** chạy `terraform apply` từ thư mục `terraform/` root (legacy `ec2.tf`). Luôn:

```bash
terraform -chdir=environments/dev init -input=false
terraform -chdir=environments/dev apply -var-file=terraform.tfvars -auto-approve -input=false
```

**Biến bắt buộc / quan trọng** (trong `terraform.tfvars` mỗi env):

| Biến | Ghi chú |
|------|--------|
| `stripe_secret_key` | `sk_test_...` hoặc `sk_live_...` (validation giống `terraform_secret`) |
| `db_password` | **Prod:** bắt buộc set (không default). **Dev/management:** có default lab trong `variables.tf` |
| `project_name` | Mặc định `go-micro` — phải khớp `config/env/*.yaml` (`remoteKey` / prefix AWS) |

**Đổi tên IAM user ESO:** user giờ là `${project_name}-eso-secrets-${environment}` (vd `go-micro-eso-secrets-dev`). Apply sẽ **tạo user mới** nếu trước đây là `k8s-eso-secrets-dev` — cập nhật `configure.py` / Secret `aws-credentials` sau apply.

**State:** `.terraform/` và state nằm trong từng `environments/<env>/`.

**Scripts:** `provision.py` / `configure.py` ở root repo; kubeconfig: `kube_config_rke2_<env>.yaml`.

## Gateway (Envoy Gateway) + ALB Terraform

- Module `loadbalancers` tạo **ALB** (HTTP→HTTPS) + target group **HTTP/HTTPS trên cổng 80/443** tới **instance** (worker). Không dùng MetalLB.
- Argo bootstrap **`23-envoyproxy-nodeport-*`** + **`gateway-infra-*`** gắn `GatewayClass` với `EnvoyProxy` (Service data plane = **NodePort**). Terraform ALB forward tới **NodePort** đó trên EC2 (cập nhật target group sau khi `kubectl get svc -n microservices-<env>` thấy Service Envoy, hoặc automation riêng).
- Luồng tham chiếu: Internet → **ALB** → worker:`<nodePort>` → Envoy (HTTPRoute/Gateway API). NLB trong module hiện tại phục vụ **API server** nội bộ (`6443`), không thay Gateway HTTP.
