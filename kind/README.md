# Kind — khởi động lại mỗi ngày (sau reboot)

Luồng **chính** trong tài liệu này: xoá / tạo lại 4 cluster (management + dev + staging + prod), Helm Cilium trên management, Argo CD, đăng ký cluster workload, secrets, bootstrap GitOps, Cilium CNI + Traefik trên dev–staging–prod.

**Chạy lệnh từ thư mục gốc repo** (`cd ~/Downloads/go-micro`). Argo CD chỉ trên **kind-management**. API từ máy host: management `127.0.0.1:33443`, dev `30443`, staging `32443`, prod `31443`.

---

## 1. Khởi động lại môi trường Kind (sau reboot / mỗi ngày)

Kind là môi trường **ephemeral** để test. Sau khi tắt/bật máy lại **không có lệnh "start lại nguyên cụm" đơn giản**. Cách an toàn, ít lỗi nhất:

> **Xóa cụm cũ (nếu còn) → tạo lại Kind (management + Helm Cilium → dev/staging/prod) → Argo CD → đăng ký cluster → secrets (1.5.1 ESO hoặc 1.5.2 kubectl) → bootstrap Argo → sync app.**

Giả sử đang ở branch `kind` của repo này.

### 1.1. Xóa 4 cluster cũ (nếu còn)

```bash
kind delete cluster --name management
kind delete cluster --name dev
kind delete cluster --name staging
kind delete cluster --name prod
```

Không sao cả: mọi config cho Kind đã nằm trong Git (branch `kind`).

### 1.2. Tạo lại 4 cluster Kind

Tạo **management** trước, **Helm Cilium** ngay (sau khi chỉnh kubeconfig), rồi **dev / staging / prod**.

```bash
cd ~/Downloads/go-micro   # bắt buộc từ thư mục repo

kind create cluster --name management --config kind/management-kind-config.yaml

kubectl config use-context kind-management
# Bắt buộc trước helm (tránh TLS 0.0.0.0 và tránh cài Argo khi chưa có CNI)
kubectl config set-cluster kind-management --server=https://127.0.0.1:33443

helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo update
# Bootstrap file tắt 2 thứ chưa có lúc này:
# 1) ServiceMonitor CRD (chưa cài Prometheus Operator) → Helm lỗi "no matches for kind ServiceMonitor"
# 2) LoadBalancer → NodePort (chưa cài MetalLB → Helm --wait treo chờ EXTERNAL-IP mãi không có)
# Sau khi Argo sync monitoring + cilium-management, Git sẽ chuyển lại cấu hình đầy đủ.
helm upgrade --install cilium cilium/cilium -n kube-system --create-namespace \
  --version 1.19.2 \
  -f cilium/cilium-values-management.yaml \
  -f cilium/cilium-values-management-bootstrap.yaml \
  --wait --timeout 15m

kind create cluster --name dev        --config kind/dev-kind-config.yaml
kind create cluster --name staging    --config kind/staging-kind-config.yaml
kind create cluster --name prod       --config kind/prod-kind-config.yaml

kubectl config set-cluster kind-dev --server=https://127.0.0.1:30443
kubectl config set-cluster kind-staging --server=https://127.0.0.1:32443
kubectl config set-cluster kind-prod --server=https://127.0.0.1:31443
# hoặc: bash scripts/kind-fix-kubeconfig-servers.sh

kubectl config get-contexts   # phải thấy kind-management, kind-dev, kind-staging, kind-prod
```

CIDR pod/service: file `kind/*-kind-config.yaml` (không trùng giữa cụm). Kubeconfig: **mục 1.2** (`127.0.0.1` trước Helm).

**Nếu vẫn lỗi TLS** sau khi đã tạo lại cluster: chạy `bash scripts/kind-fix-kubeconfig-servers.sh` hoặc bốn lệnh `kubectl config set-cluster` như **mục 1.2**.

### 1.3. Cài lại Argo CD trên `management`

Chỉ khi **Cilium đã Ready** trên `kind-management` (mục 1.2). Nếu bỏ qua Helm / lỗi TLS, pod Argo sẽ **Pending**.

```bash
kubectl config use-context kind-management

kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd wait --for=condition=Ready pods --all --timeout=300s
```

Lấy lại password admin + port-forward:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

**Quan trọng (mỗi lần recreate Argo CD):** `argocd` CLI có thể vẫn giữ token cũ → lỗi kiểu:
`invalid session: token signature is invalid`.
Sau khi cài lại Argo CD (mục 1.3) **hãy reset token và login lại** trước khi chạy các lệnh `argocd ...`:

```bash
rm -rf ~/.argocd
PASS=$(kubectl --context kind-management -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$PASS"
```

### 1.4. Đăng ký lại cluster `dev` + `staging` + `prod` cho Argo CD

Trên `kind-dev`, `kind-staging` và `kind-prod`:

```bash
kubectl --context kind-dev  apply -f kind/dev-argocd-manager.yaml
kubectl --context kind-staging apply -f kind/dev-argocd-manager.yaml
kubectl --context kind-prod apply -f kind/prod-argocd-manager.yaml
sleep 5

DEV_TOKEN=$(kubectl --context kind-dev  get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
STAGING_TOKEN=$(kubectl --context kind-staging get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
PROD_TOKEN=$(kubectl --context kind-prod get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
```

Dùng **IP container trực tiếp** + port **6443** (cách ổn định nhất trên Linux):

```bash
kubectl config use-context kind-management

DEV_IP=$(docker inspect dev-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
STAGING_IP=$(docker inspect staging-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
PROD_IP=$(docker inspect prod-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')

kubectl create secret generic cluster-dev -n argocd \
  --from-literal=name=dev \
  --from-literal=server=https://$DEV_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$DEV_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl label secret cluster-dev -n argocd argocd.argoproj.io/secret-type=cluster

kubectl create secret generic cluster-staging -n argocd \
  --from-literal=name=staging \
  --from-literal=server=https://$STAGING_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$STAGING_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl label secret cluster-staging -n argocd argocd.argoproj.io/secret-type=cluster

kubectl create secret generic cluster-prod -n argocd \
  --from-literal=name=prod \
  --from-literal=server=https://$PROD_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$PROD_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl label secret cluster-prod -n argocd argocd.argoproj.io/secret-type=cluster
```

### 1.5. Secrets cho database + backend (sau khi recreate cluster)

#### 1.5.1. External Secrets Operator + AWS Secrets Manager (thay cho “ESO giả”)

Dùng khi máy/cluster có egress ra AWS và bạn đã có secret JSON trên Secrets Manager (cùng keys như Terraform `modules/secrets`: `POSTGRES_*`, `DATABASE_URL`, `NEXTAUTH_SECRET`).

**Trên từng workload cluster** (`kind-dev`, `kind-staging`, `kind-prod`) — lặp lại với đúng `--context` và file values tương ứng:

1. Cài External Secrets Operator (**một lần trên mỗi** cluster `kind-dev`, `kind-staging`, `kind-prod`):

   Config Kind của repo dùng **Kubernetes 1.28** (`kindest/node:v1.28.0`). Chart ESO **≥ 0.20.1** kèm CRD có `selectableFields` (chỉ hợp lệ từ K8s ~1.31+) → `helm install` báo lỗi kiểu `.spec.versions[0].selectableFields: field not declared in schema` và **CRD không được cài** → apply `ExternalSecret` sẽ lỗi `no matches for kind "ExternalSecret"`.

   **Cách xử lý:** ghim chart **0.19.2** (bản 0.20.1 trở lên cần K8s mới hơn). Nếu lần trước cài hỏng: `helm uninstall external-secrets -n external-secrets` trên context tương ứng, rồi cài lại.

   ```bash
   helm repo add external-secrets https://charts.external-secrets.io
   helm repo update

   for ctx in kind-dev kind-staging kind-prod; do
     helm upgrade --install external-secrets external-secrets/external-secrets \
       --version 0.19.2 \
       -n external-secrets --create-namespace \
       --kube-context "$ctx"
   done
   ```

   **Sau `helm install`, bắt buộc chờ pod ESO (webhook) Ready** rồi mới apply `ClusterSecretStore` / `ExternalSecret`. Nếu apply quá sớm, API server gọi validating webhook `external-secrets-webhook` trong khi pod chưa listen → lỗi `connection refused` / `Internal error occurred: failed calling webhook`.

   ```bash
   for ctx in kind-dev kind-staging kind-prod; do
     kubectl --context "$ctx" -n external-secrets rollout status deployment/external-secrets-webhook --timeout=300s
     kubectl --context "$ctx" -n external-secrets wait --for=condition=Ready pods --all --timeout=300s
   done
   ```

   (Nếu tên deployment webhook khác: `kubectl --context kind-dev -n external-secrets get deploy`.)

   (Muốn dùng ESO mới nhất: nâng image Kind lên **≥ 1.31** trong `kind/*-kind-config.yaml` rồi bỏ `--version`.)

2. Tạo `aws-credentials` trong namespace `external-secrets` **trên từng cluster**

   **Không bỏ bước này** dù bạn đã tạo secret **trên AWS Secrets Manager** (Terraform / console) từ trước:

   - Secret **trên AWS** (ví dụ `go-micro/dev/app-credentials`) chứa JSON app (`POSTGRES_*`, `DATABASE_URL`, …) — đích mà **ExternalSecret** đồng bộ vào K8s.
   - Secret **`aws-credentials` trong cluster** chứa **Access key IAM** để **controller ESO** gọi API AWS (`GetSecretValue`). Không có nó (hoặc không có auth tương đương), ESO không đọc được AWS.

   IAM cần `secretsmanager:GetSecretValue` trên prefix secret của project (giống user ESO trong `terraform_secret` hoặc `terraform/modules/iam`).

   ```bash
   kubectl --context kind-dev -n external-secrets create secret generic aws-credentials \
     --from-literal=access-key-id='YOUR_AWS_ACCESS_KEY_ID' \
     --from-literal=secret-access-key='YOUR_AWS_SECRET_ACCESS_KEY'
   # Lặp với kind-staging / kind-prod (thường cùng một cặp key). Nếu secret đã tồn tại: thêm --dry-run=client -o yaml | kubectl apply -f - hoặc delete rồi create lại.
   ```

3. Tạo namespace đích (ESO ghi K8s Secret vào `databases-<env>` + `microservices-<env>`). Ví dụ cho **kind-dev** (đổi context cho staging/prod):

   ```bash
   kubectl --context kind-dev create namespace databases-dev --dry-run=client -o yaml | kubectl --context kind-dev apply -f -
   kubectl --context kind-dev create namespace microservices-dev --dry-run=client -o yaml | kubectl --context kind-dev apply -f -
   kubectl --context kind-prod create namespace databases-prod --dry-run=client -o yaml | kubectl --context kind-prod apply -f -
   kubectl --context kind-prod create namespace microservices-prod --dry-run=client -o yaml | kubectl --context kind-prod apply -f -
   kubectl --context kind-staging create namespace databases-staging --dry-run=client -o yaml | kubectl --context kind-staging apply -f -
   kubectl --context kind-staging create namespace microservices-staging --dry-run=client -o yaml | kubectl --context kind-staging apply -f -
   ```

4. Apply `ClusterSecretStore` + `ExternalSecret` từ repo (từ thư mục gốc repo):

   ```bash
   cd ~/Downloads/go-micro

    # DEV
    helm template external-secrets external-secrets/applications \
      -f external-secrets/applications/values.yaml \
      -f config/base/config.yaml \
      -f config/env/dev.yaml \
      | kubectl --context kind-dev apply -f -

    # STAGING
    helm template external-secrets external-secrets/applications \
      -f external-secrets/applications/values.yaml \
      -f config/base/config.yaml \
      -f config/env/staging.yaml \
      | kubectl --context kind-staging apply -f -

    # PROD
    helm template external-secrets external-secrets/applications \
      -f external-secrets/applications/values.yaml \
      -f config/base/config.yaml \
      -f config/env/prod.yaml \
      | kubectl --context kind-prod apply -f -
   ```

5. Kiểm tra sync:

   ```bash
   kubectl --context kind-dev get externalsecret,secret -n databases-dev
   kubectl --context kind-dev get externalsecret,secret -n microservices-dev
   ```

**Staging trên AWS:** đảm bảo secret key cho staging tồn tại trên AWS (ví dụ `go-micro/staging/app-credentials`) trước khi ESO sync.

#### 1.5.2. Secret tĩnh bằng kubectl (không AWS — “giả ESO”)

Khi không dùng ESO/AWS, tạo Secret thủ công trên từng cluster. **Lưu ý:** lệnh có pipe phải có `--context` ở cả hai bên (`| kubectl --context kind-dev apply -f -`), nếu không namespace sẽ bị tạo nhầm cluster.

**Trên `kind-dev`:**

```bash
# DB
kubectl --context kind-dev create namespace database --dry-run=client -o yaml | kubectl --context kind-dev apply -f -
kubectl --context kind-dev -n databases-dev create secret generic go-micro-database-secrets-dev \
  --from-literal=POSTGRES_USER=meo_admin \
  --from-literal=POSTGRES_DB=meo_stationery \
  --from-literal=POSTGRES_PASSWORD=localdev

# Backend
kubectl --context kind-dev create namespace microservices-dev --dry-run=client -o yaml | kubectl --context kind-dev apply -f -
kubectl --context kind-dev -n microservices-dev create secret generic go-micro-backend-secrets-dev \
  --from-literal=DATABASE_URL='postgresql://meo_admin:localdev@postgres.database.svc.cluster.local:5432/meo_stationery?schema=public' \
  --from-literal=NEXTAUTH_SECRET='kind-dev-nextauth'
```

**Trên `kind-staging`:**

```bash
# DB
kubectl --context kind-staging create namespace database --dry-run=client -o yaml | kubectl --context kind-staging apply -f -
kubectl --context kind-staging -n databases-staging create secret generic go-micro-database-secrets-staging \
  --from-literal=POSTGRES_USER=meo_admin \
  --from-literal=POSTGRES_DB=meo_stationery \
  --from-literal=POSTGRES_PASSWORD=localstaging

# Backend
kubectl --context kind-staging create namespace microservices-staging --dry-run=client -o yaml | kubectl --context kind-staging apply -f -
kubectl --context kind-staging -n microservices-staging create secret generic go-micro-backend-secrets-staging \
  --from-literal=DATABASE_URL='postgresql://meo_admin:localstaging@postgres.database.svc.cluster.local:5432/meo_stationery?schema=public' \
  --from-literal=NEXTAUTH_SECRET='kind-staging-nextauth'
```

**Trên `kind-prod`:** (**phải** có `--context kind-prod` ở cả hai bên pipe):

```bash
# DB
kubectl --context kind-prod create namespace database --dry-run=client -o yaml | kubectl --context kind-prod apply -f -
kubectl --context kind-prod -n databases-prod create secret generic go-micro-database-secrets-prod \
  --from-literal=POSTGRES_USER=meo_admin \
  --from-literal=POSTGRES_DB=meo_stationery \
  --from-literal=POSTGRES_PASSWORD=localprod

# Backend
kubectl --context kind-prod create namespace microservices-prod --dry-run=client -o yaml | kubectl --context kind-prod apply -f -
kubectl --context kind-prod -n microservices-prod create secret generic go-micro-backend-secrets-prod \
  --from-literal=DATABASE_URL='postgresql://meo_admin:localprod@postgres.database.svc.cluster.local:5432/meo_stationery?schema=public' \
  --from-literal=NEXTAUTH_SECRET='kind-prod-nextauth'
```

### 1.6. Apply lại bootstrap Argo CD

Bootstrap là các file Application; apply lần lượt:

```bash
kubectl config use-context kind-management
cd ~/Downloads/go-micro

argocd repo add https://github.com/minhtri1612/go-micro.git
argocd repo add https://argoproj.github.io/argo-helm --type helm --name argo-helm
argocd repo add https://metallb.github.io/metallb --type helm --name metallb
argocd repo add https://helm.cilium.io/ --type helm --name cilium
argocd repo add https://helm.traefik.io/traefik --type helm --name traefik

# 1. App stack go-micro
kubectl apply -f argocd/bootstrap/01-projects.yaml
# Bắt buộc: Application này render ra AppProject dev/staging/prod. Nếu chưa sync mà đã `argocd app sync` app khác → InvalidSpecError: project does not exist.
argocd app sync argocd/argocd-projects
kubectl apply -f argocd/bootstrap/02-dev-microservices-stack.yaml
kubectl apply -f argocd/bootstrap/03-staging-microservices-stack.yaml
kubectl apply -f argocd/bootstrap/04-prod-microservices-stack.yaml

# 2. App Monitoring
kubectl apply -f argocd/bootstrap/05-monitoring-mgmt.yaml
kubectl apply -f argocd/bootstrap/18-cilium-management.yaml
kubectl apply -f argocd/bootstrap/06-monitoring-dev.yaml
kubectl apply -f argocd/bootstrap/07-monitoring-staging.yaml
kubectl apply -f argocd/bootstrap/08-monitoring-prod.yaml

# Monitoring: sau mỗi lần recreate Kind — remote_write → xem mục 1.6.1 bên dưới (đừng bỏ qua).

# 2b. Argo Rollouts (backend dùng Rollout / AnalysisTemplate)
kubectl apply -f argocd/bootstrap/12-argo-rollouts-dev.yaml
kubectl apply -f argocd/bootstrap/13-argo-rollouts-staging.yaml
kubectl apply -f argocd/bootstrap/14-argo-rollouts-prod.yaml

# 3. App Cilium (peer IP hub: `./scripts/kind-clustermesh-peer-ip.sh` đọc LB IP management; commit/push `cilium/clustermesh-management-peer.yaml` nếu Argo dùng remote)
kubectl apply -f argocd/bootstrap/09-cilium-dev.yaml
kubectl apply -f argocd/bootstrap/10-cilium-staging.yaml
kubectl apply -f argocd/bootstrap/11-cilium-prod.yaml

# 4. MetalLB
# Repo go-micro hiện chưa có bootstrap metallb-*.yaml trong argocd/bootstrap.
# Nếu cần LB trên Kind, apply tài nguyên dưới config/metallb/ theo môi trường bạn đang chạy.

# 5. Traefik (Helm chart upstream; Service LoadBalancer — cần MetalLB đã sync)
kubectl apply -f argocd/bootstrap/19-traefik-dev.yaml
kubectl apply -f argocd/bootstrap/20-traefik-staging.yaml
kubectl apply -f argocd/bootstrap/21-traefik-prod.yaml
```

Sau đó (từ máy đã `argocd login`): `argocd app sync argocd/traefik-dev` và `traefik-staging`; với **prod** nếu AppProject/sync policy là **Manual** thì sync `traefik-prod` tay. Chi tiết kiểm tra CRD / curl: **mục 1.7**.

#### 1.6.1. Monitoring `remote_write` — script `scripts/sync-monitoring-remote-write-url.sh` (**bắt buộc đọc sau recreate Kind**)

Prometheus trên **management** nhận series từ **Prometheus Agent** trên dev/staging/prod qua `remote_write`. URL ghi trong `monitoring/monitoring-workload.yaml` (`prometheus.prometheusSpec.remoteWrite[0].url`) phải là:

`http://<IP-container-management-control-plane>:32090/api/v1/write`

(32090 = NodePort Prometheus trên management, xem `monitoring/monitoring-mgmt.yaml`.)

**Sau mỗi lần** `kind delete` / `kind create` lại cluster **management** (hoặc cả bộ lab), IP container `management-control-plane` trên mạng Docker `kind` **đổi**. Nếu Git vẫn để `127.0.0.1` hoặc IP cũ → agent trên workload **không push** được; Grafana trên management **không** có (hoặc thiếu) series theo label `cluster` / `environment` — dễ đi lạc debug chỗ khác.

**Quy trình chuẩn — copy paste từng khối (đừng bỏ bước):**

1. Trên Argo: app **`monitoring-management` (bootstrap 05)** phải **Healthy** (Prometheus management + NodePort **32090**). Cùng lúc có thể cần chỉnh `cilium/clustermesh-management-peer.yaml` (`bash scripts/kind-clustermesh-peer-ip.sh` rồi commit/push) nếu dùng ClusterMesh từ Git.

2. Vào **thư mục gốc repo** (nơi có `monitoring/`, `scripts/`):

```bash
cd ~/Downloads/go-micro
```

3. **Quyền thực thi script** (lần đầu hoặc nếu gặp `permission denied`):

```bash
chmod +x scripts/sync-monitoring-remote-write-url.sh
# (tuỳ chọn, lưu mode vào git) git add --chmod=+x scripts/sync-monitoring-remote-write-url.sh
```

4. **Ghi URL `remote_write`** vào `monitoring/monitoring-workload.yaml` (đọc IP từ `docker inspect management-control-plane`; có `yq` thì dùng `yq`, không thì `sed`):

```bash
./scripts/sync-monitoring-remote-write-url.sh
```

5. **Kiểm tra Prometheus management** từ máy host (mong đợi `HTTP 200`):

> **Quan trọng:** Sau recreate Kind, Prometheus pod trên management phải pull image từ `quay.io` / `registry.k8s.io` — mất **3–5 phút** (tuỳ mạng). Trong lúc pod còn `PodInitializing`, NodePort 32090 chưa có process lắng nghe → `--check` sẽ nhận `HTTP 000` (connection refused) liên tục. **Đợi pod Ready trước** rồi mới chạy `--check`:
>
> ```bash
> kubectl --context kind-management -n monitoring wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus --timeout=600s
> ```

```bash
./scripts/sync-monitoring-remote-write-url.sh --check
```

6. **Đẩy lên Git** (bắt buộc nếu Argo trỏ remote `go-micro` / `main`) — chọn **một** trong hai cách:

   **Cách A — một lệnh (sau bước 5; script **ghi lại** file rồi `git add` → `commit` chỉ khi có diff → `push`):**

```bash
./scripts/sync-monitoring-remote-write-url.sh --commit-push
```

   (Nếu URL không đổi, không tạo commit rỗng; `git push` vẫn chạy — thường báo *up to date*. Đã làm bước 4+5 rồi thì **cách B** cũng đủ, không bắt buộc chạy thêm `--commit-push`.)

   **Cách B — tay (review diff trước khi push):**

```bash
git add monitoring/monitoring-workload.yaml
git status
git commit -m "chore(monitoring): sync remote_write URL for Kind"
git push
```

7. Trên Argo (context **kind-management**): **Refresh + Sync** `monitoring-dev`, `monitoring-staging`, `monitoring-prod` (prod **Manual** trong bootstrap thì sync tay).

```bash
kubectl config use-context kind-management
argocd app sync argocd/monitoring-dev
argocd app sync argocd/monitoring-staging
argocd app sync argocd/monitoring-prod
```

**Một dải lệnh copy paste (đủ bước 2→7, sau khi `monitoring-management` đã Healthy):**

```bash
cd ~/Downloads/go-micro
chmod +x scripts/sync-monitoring-remote-write-url.sh
./scripts/sync-monitoring-remote-write-url.sh
# Đợi Prometheus pod Ready (pull image lần đầu mất 3-5 phút, không đợi → --check trả 000)
kubectl --context kind-management -n monitoring wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus --timeout=600s
./scripts/sync-monitoring-remote-write-url.sh --check
git add monitoring/monitoring-workload.yaml
git commit -m "chore(monitoring): sync remote_write URL for Kind" || true
git push
kubectl config use-context kind-management
# Đợi ArgoCD Server tải cache Project (tránh lỗi InvalidSpecError)
sleep 3
argocd app sync argocd/monitoring-dev
argocd app sync argocd/monitoring-staging
argocd app sync argocd/monitoring-prod
```

*(Nếu không có thay đổi so với commit trước, `git commit` báo lỗi “nothing to commit” — `|| true` để dải lệnh không dừng; `git push` vẫn chạy. Muốn chắc chắn có commit: dùng cách A `./scripts/sync-monitoring-remote-write-url.sh --commit-push` **thay cho** ba lệnh `git` ở trên — lệnh đó vừa ghi file vừa `add`/`commit` chỉ khi có diff rồi `push`.)*

**Lệnh phụ (tuỳ chọn):**

```bash
./scripts/sync-monitoring-remote-write-url.sh --print-only   # chỉ in URL write, không sửa file
```

**Override khi không dùng Docker / tên container khác:**

- `MGMT_PROMETHEUS_REMOTE_WRITE_URL='http://IP:32090/api/v1/write' ./scripts/sync-monitoring-remote-write-url.sh`
- `MGMT_CONTROL_PLANE_CONTAINER=...` — tên container control-plane management.
- `MONITORING_WORKLOAD_VALUES=...` — đường dẫn tương đối repo tới file values workload (mặc định `monitoring/monitoring-workload.yaml`).

**Không cần** chạy lại toàn bộ bước trên mỗi ngày nếu **không** recreate Kind và remote_write vẫn đúng. Trên **RKE2 / cloud** thường dùng hostname hoặc IP cố định — có thể ghi URL ổn định trong Git, không phụ thuộc script Docker.

Sau khi sync xong, sẽ có:

- `argocd-projects` → tạo AppProject dev, staging, prod
- `dev-microservices` → render `argocd/manifest-apps` và sinh app dạng `dev-go-microservices-*-app`
- `staging-microservices` → sinh app dạng `staging-go-microservices-*-app`
- `prod-microservices` → sinh app dạng `prod-go-microservices-*-app`

Với môi trường **prod** (sync policy `Manual`), force sync thủ công:

```bash
argocd app sync argocd/prod-microservices
# rồi sync từng app con cần thiết, ví dụ:
argocd app sync argocd/prod-go-microservices-payment-app
argocd app sync argocd/prod-go-microservices-payment-db-app
```

> **Lưu ý:** Nếu ArgoCD CLI báo `permission denied`, login lại trước:
> ```bash
> rm -rf ~/.argocd
> PASS=$(kubectl --context kind-management -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
> argocd login localhost:8080 --insecure --username admin --password "$PASS"
> ```

---

### 1.7. Cài Traefik Ingress cho dev/staging/prod (traffic routing + Canary/Blue-Green)

Mục tiêu của bước này:

- Cilium CNI trên các workload cluster (`kind-dev`, `kind-staging`, `kind-prod`) — GitOps **09–11** (mục **1.6** / bên dưới).
- **Traefik** làm ingress north–south: Application Helm (`argocd/bootstrap/19–21-traefik-*.yaml`) cài controller + CRD `traefik.io`, Service kiểu **LoadBalancer** (trên Kind cần **MetalLB** trước).
- **Định tuyến tới backend:** manifest `IngressRoute` + `TraefikService` do chart `template/` render khi `routing.provider: traefik` và `traefik.enabled: true` (xem `template/templates/ingressroute.yaml`, `traefikservice.yaml`). Canary/blue-green với Argo Rollouts dùng plugin **`argoproj-labs/traefik`** trong `Rollout` (controller Rollouts phải được sync từ bootstrap **12–14** trước khi kỳ vọng canary hoạt động).
- GitOps: **Argo CD là source of truth**; không duy trì song song `kubectl apply` tay lâu dài.

> **Thứ tự nên tuân thủ (tránh CRD / LB thiếu khi sync app):**
> 1. **Cilium** Ready trên workload cluster.
> 2. **MetalLB** Healthy — pool khớp subnet Docker `kind` (`config/metallb/pools/...`).
> 3. **Traefik** (`traefik-*` apps) Healthy — CRD `ingressroutes.traefik.io`, `traefikservices.traefik.io` có mặt.
> 4. **Argo Rollouts** (bootstrap 12–14) nếu backend dùng `Rollout` + traffic splitting.
> 5. Sync app backend (`*-go-microservices-*-app`) để Helm tạo `IngressRoute` / `TraefikService` trỏ tới Service stable/canary.

#### 1.7.1. Bootstrap Traefik (GitOps)

Đăng ký Helm repo (một lần, nếu chưa): `argocd repo add https://helm.traefik.io/traefik --type helm --name traefik` (đã có trong **mục 1.6**).

Từ cluster `kind-management`:

```bash
kubectl config use-context kind-management
cd ~/Downloads/go-micro

kubectl apply -f argocd/bootstrap/19-traefik-dev.yaml
kubectl apply -f argocd/bootstrap/20-traefik-staging.yaml
kubectl apply -f argocd/bootstrap/21-traefik-prod.yaml

# Đợi ArgoCD Server tải cache Project (tránh lỗi InvalidSpecError: project does not exist)
sleep 3

argocd app sync argocd/traefik-dev
argocd app sync argocd/traefik-staging
argocd app sync argocd/traefik-prod   # prod Manual → sync tay nếu Argo báo policy
```

Kiểm tra nhanh CRD Traefik + pod + Service (mong đợi **EXTERNAL-IP** sau MetalLB):

```bash
for ctx in kind-dev kind-staging kind-prod; do
  echo "=== $ctx ==="
  kubectl --context "$ctx" get crd 2>/dev/null | rg "ingressroutes\.traefik|traefikservices\.traefik" || true
  kubectl --context "$ctx" -n traefik get pods,svc
done
```

**Ghi chú:** Luồng repo **không** còn dùng `Gateway` / `HTTPRoute` (Gateway API) cho app `go-micro`. Bạn **không** cần `kubectl apply` `standard-install.yaml` của Gateway API cho lab này trừ khi bạn tự thêm workload khác dựa trên Gateway API.

#### 1.7.2. Cài Cilium bằng Argo CD (GitOps chuẩn)

Từ cluster `kind-management`, apply 3 bootstrap Application:

```bash
kubectl config use-context kind-management
cd ~/Downloads/go-micro

kubectl apply -f argocd/bootstrap/09-cilium-dev.yaml
kubectl apply -f argocd/bootstrap/10-cilium-staging.yaml
kubectl apply -f argocd/bootstrap/11-cilium-prod.yaml
```

Sau đó đợi khoảng 3s cho ArgoCD làm nóng cache (để không bị văng lỗi Multi-source App Project dev does not exist) và sync ứng dụng Cilium:

```bash
sleep 3
argocd app sync argocd/cilium-dev
argocd app sync argocd/cilium-staging
argocd app sync argocd/cilium-prod
```

Nếu bạn vừa thêm CRD networking (ít gặp với luồng Traefik hiện tại) **sau** khi Cilium đã chạy, có thể restart `cilium-operator` một lần để reconcile:

```bash
kubectl --context kind-dev -n kube-system rollout restart deploy/cilium-operator
kubectl --context kind-staging -n kube-system rollout restart deploy/cilium-operator
kubectl --context kind-prod -n kube-system rollout restart deploy/cilium-operator
```

> Nếu `prod` đang policy `Manual`, giữ nguyên: sync `cilium-prod` thủ công khi bạn muốn rollout.

#### 1.7.2b. MetalLB (GitOps) — LoadBalancer cho Traefik trên Kind

1. Đăng ký Helm repo (một lần): `argocd repo add https://metallb.github.io/metallb --type helm --name metallb`
2. Cập nhật AppProject (namespace `metallb-system`): `kubectl apply -f argocd/bootstrap/01-projects.yaml`
3. Apply + sync:

   ```bash
   # go-micro chưa có bootstrap metallb-*.yaml ở argocd/bootstrap
   # apply manifest trong config/metallb/ trước, sau đó mới sync traefik
   ```

4. Pool IP nằm trong `config/metallb/pools/{dev,staging,prod,management}/pool.yaml` — **mỗi cluster một dải** (`172.18.255.10-19` dev, `20-29` staging, `30-39` prod, `40-49` management). Management dùng MetalLB để cấp IP tĩnh cho `clustermesh-apiserver` LB (`172.18.255.41`), tránh phụ thuộc Docker IP/NodePort. Nếu `docker network inspect kind` không phải `172.18.0.0/16`, sửa các file đó cho khớp subnet.

5. Sau khi MetalLB **Healthy**, Service Traefik (`kubectl -n traefik get svc traefik`) sẽ có **EXTERNAL-IP**. Gọi:

   ```bash
   curl -sS -H 'Host: dev.meo.local' http://<EXTERNAL-IP>/api/health
   ```

   (`/etc/hosts`: `127.0.0.1 dev.meo.local` chỉ đúng khi bạn dùng NodePort/localhost; với IP MetalLB trên mạng Docker, thường **curl thẳng tới EXTERNAL-IP** là đủ.)

Kiểm tra nhanh:

```bash
for ctx in kind-dev kind-staging kind-prod; do
  echo "=== $ctx ==="
  kubectl --context "$ctx" -n kube-system get pods -l k8s-app=cilium
  kubectl --context "$ctx" -n kube-system get cm cilium-config -o yaml | rg "enable-wireguard|encrypt-node|enable-l7-proxy|loadbalancer-algorithm"
  kubectl --context "$ctx" -n kube-system get servicemonitor | rg "cilium|hubble" || true
done
```

#### 1.7.3. (Tuỳ chọn) Cài Cilium CLI cho break-glass

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check "cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
cilium version
```

#### 1.7.4. Chạy một lệnh cho cả 3 cluster (sau reboot)

`IngressRoute`, `TraefikService` được quản lý trong Helm chart (`template/templates/*.yaml`) và sẽ được Argo CD sync từ Git.

Lệnh một dòng để apply bootstrap Cilium Apps:

```bash
bash -lc 'set -euo pipefail; kubectl --context kind-management apply -f argocd/bootstrap/09-cilium-dev.yaml; kubectl --context kind-management apply -f argocd/bootstrap/10-cilium-staging.yaml; kubectl --context kind-management apply -f argocd/bootstrap/11-cilium-prod.yaml; sleep 3; argocd app sync argocd/cilium-dev; argocd app sync argocd/cilium-staging; argocd app sync argocd/cilium-prod'
```

Sau Cilium + MetalLB (nếu vừa apply bootstrap **1.6**), có thể apply/sync Traefik một dòng:

```bash
bash -lc 'set -euo pipefail; kubectl --context kind-management apply -f argocd/bootstrap/19-traefik-dev.yaml; kubectl --context kind-management apply -f argocd/bootstrap/20-traefik-staging.yaml; kubectl --context kind-management apply -f argocd/bootstrap/21-traefik-prod.yaml; sleep 3; argocd app sync argocd/traefik-dev; argocd app sync argocd/traefik-staging; argocd app sync argocd/traefik-prod'
```

(`traefik-prod` bị chặn bởi policy **Manual** thì sync tay trên UI/CLI.)

Sau đó sync lại app stack backend để Helm chart apply `IngressRoute` / `TraefikService`.

Kiểm tra nhanh các tính năng Cilium đã bật:

```bash
for ctx in kind-dev kind-staging kind-prod; do
  echo "=== $ctx ==="
  kubectl --context "$ctx" -n kube-system get cm cilium-config -o yaml | rg "enable-wireguard|encrypt-node|enable-l7-proxy|loadbalancer-algorithm"
  kubectl --context "$ctx" -n kube-system get servicemonitor | rg "cilium|hubble" || true
done
```

**Hubble UI**

- **`kind-management`:** ClusterIP — mở bằng CLI hoặc port-forward **localhost:12000** (mặc định của `cilium hubble ui`).
- **dev / staging / prod:** `hubble-ui` kiểu **NodePort** cố định trong Git (`cilium/cilium-cluster-*.yaml`): **31201** (dev), **31202** (staging), **31203** (prod). Trên Kind (Linux), lấy IP node rồi mở trình duyệt:

```bash
DEV_IP=$(docker inspect dev-control-plane        --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
STG_IP=$(docker inspect staging-control-plane   --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
PRD_IP=$(docker inspect prod-control-plane      --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
echo "dev:      http://${DEV_IP}:31201"
echo "staging:  http://${STG_IP}:31202"
echo "prod:     http://${PRD_IP}:31203"
```

```bash
# Management → http://localhost:12000
cilium hubble ui --context kind-management
# hoặc: kubectl --context kind-management -n kube-system port-forward svc/hubble-ui 12000:80
```

```bash
# Workload clusters (mỗi context một local port riêng để không trùng)
cilium hubble ui --context kind-dev --port-forward 12001      # http://localhost:12001
cilium hubble ui --context kind-staging --port-forward 12002  # http://localhost:12002
cilium hubble ui --context kind-prod --port-forward 12003     # http://localhost:12003
```

**CLI flow (tuỳ chọn):** `cilium` không có `hubble observe`. Cần binary **`hubble`**: [cilium/hubble#installation](https://github.com/cilium/hubble#installation).

```bash
# Port-forward Relay cho từng context (chạy song song thì dùng port khác nhau)
cilium hubble port-forward --context kind-dev --port-forward 4247
cilium hubble port-forward --context kind-staging --port-forward 4248
cilium hubble port-forward --context kind-prod --port-forward 4249
```

```bash
# Observe flow qua hubble CLI (ví dụ HTTP)
hubble observe --server 127.0.0.1:4247 --protocol http --last 50
hubble observe --server 127.0.0.1:4248 --protocol http --last 50
hubble observe --server 127.0.0.1:4249 --protocol http --last 50
```

#### 1.7.4b. Tạo traffic HTTP GET để nhìn rõ trên Hubble (dev/staging/prod)

Mục tiêu: tạo flow `GET` ổn định để Hubble UI/CLI hiển thị rõ method `GET` cho backend stable/canary.

```bash
# 1) Tạo pod curl test trong namespace app cho từng cluster
for ctx in kind-dev kind-staging kind-prod; do
  kubectl --context "$ctx" -n microservices-${ctx#kind-} run curlbox --image=curlimages/curl:8.7.1 --restart=Never -- sleep 3600 || true
  kubectl --context "$ctx" -n microservices-${ctx#kind-} wait --for=condition=Ready pod/curlbox --timeout=120s
done
```

```bash
# 2) Tạo traffic GET in-cluster vào stable + canary service
for ctx in kind-dev kind-staging kind-prod; do
  kubectl --context "$ctx" -n microservices-${ctx#kind-} exec curlbox -- sh -lc '
  for i in $(seq 1 80); do
    curl -sS "http://backend-stable/api/health" >/dev/null || true
    curl -sS "http://backend-canary/api/health" >/dev/null || true
    sleep 0.2
  done
  '
done
```

```bash
# 3) (Tuỳ chọn) Tạo GET từ host qua Traefik (world -> backend)
# Thay IP nếu pool MetalLB của bạn khác.
for i in $(seq 1 80); do
  curl -sS -H "Host: dev.meo.local" "http://172.18.255.10/api/health" >/dev/null || true
  curl -sS -H "Host: staging.meo.local" "http://172.18.255.20/api/health" >/dev/null || true
  curl -sS -H "Host: prod.meo.local" "http://172.18.255.30/api/health" >/dev/null || true
  sleep 0.2
done
```

```bash
# 4) Verify nhanh bằng hubble CLI (ví dụ dev)
cilium hubble port-forward --context kind-dev --port-forward 4247
hubble observe --server 127.0.0.1:4247 --protocol http --verdict FORWARDED --last 100 | rg " GET "
```

```bash
# 5) Dọn pod test
for ctx in kind-dev kind-staging kind-prod; do
  kubectl --context "$ctx" -n microservices-${ctx#kind-} delete pod curlbox --force --grace-period=0 --ignore-not-found
done
```

#### 1.7.5. Truy cập app **không** `kubectl port-forward`

- **Khuyến nghị:** MetalLB GitOps — xem **1.7.2b** (`argocd/bootstrap/15–17`, `config/metallb/`).
- **Tùy chọn:** NodePort + `extraPortMappings` trong `kind/*-kind-config.yaml` (phải `kind delete`/`create` lại cluster) rồi chỉnh Service Traefik / host header cho đúng; hoặc xem lịch sử git nếu bạn từng dùng Cilium Gateway (`cilium-gateway-*`).
- **Cloud / RKE2:** dùng LoadBalancer / Ingress có sẵn — không cần MetalLB trên Kind.

> Nếu Traefik pod Pending, Service `traefik` không có **EXTERNAL-IP**, hoặc `IngressRoute` không Synced: xem **mục 1.8.1**.

### 1.8. Gỡ rối thường gặp (đọc trước khi blame doc)

**Argo CD là source of truth (GitOps)**

- Argo CD (cluster `kind-management`) là bên nắm trạng thái mong muốn của `Application`, Helm values và manifest Traefik.
- Không maintain song song hai nguồn (vừa Argo vừa apply tay lâu dài), vì dễ gây drift và khó debug.
- Có thể test nhanh bằng `kubectl apply`/`helm` ở `kind-dev`, nhưng sau khi xác nhận phải đưa ngay về Git rồi sync lại bằng Argo CD.
- Nếu đã lỡ cài Helm tay đè lên workload Argo đang quản lý: gỡ release tay (`helm uninstall ...`) rồi refresh/sync lại app trên Argo.
- **Lưu ý thao tác Sync:** Do ArgoCD thỉnh thoảng có độ trễ trong việc cập nhật thông tin cache của Project, nếu bạn vừa `kubectl apply` ứng dụng xong rồi gọi ngay lệnh `argocd app sync ...`, nó có thể báo lỗi ảo `InvalidSpecError: Application referencing project xxx which does not exist`. Gặp trường hợp này, bạn chỉ việc đợi tầm 3-5 giây và gõ lại lệnh Sync một lần nữa là được.

**Argo CD — `IngressRoute` / `TraefikService` hoặc app backend không Healthy**

- App **`traefik-*`** phải **Synced/Healthy** trước: namespace `traefik`, pod controller Running; CRD nhóm `*.traefik.io` tồn tại (Helm Traefik tạo khi cài đặt thành công).
- **MetalLB:** Service `traefik` trong namespace `traefik` cần **EXTERNAL-IP**. Nếu `<pending>` lâu → xem pool IP **1.7.2b** và subnet `docker network inspect kind`.
- **Thứ tự sync:** backend (`*-go-microservices-*-app`) sau Traefik + (nếu dùng canary) sau **Argo Rollouts** bootstrap **12–14** — plugin `argoproj-labs/traefik` phải có trong controller Rollouts (`argocd/argo-rollouts-values.yaml`).
- Nếu Argo báo lỗi thiếu kind `IngressRoute` / `TraefikService`: cluster chưa có CRD Traefik → sync lại app `traefik-<env>`.

**1.8.1.** Traefik pod **Pending** / Service không có EXTERNAL-IP / không curl được qua Host header

- `kubectl --context kind-dev -n traefik describe pod -l app.kubernetes.io/name=traefik` — thường gặp khi **chưa có MetalLB**, pool sai, hoặc thiếu quyền trên node.
- `kubectl --context kind-dev -n traefik get svc traefik -o wide` — cột **EXTERNAL-IP** phải khớp dải pool (ví dụ dev `172.18.255.10-19`).
- Sau khi có IP: `curl -sS -H 'Host: dev.meo.local' http://<EXTERNAL-IP>/api/health` (hostname theo `config/env/dev.yaml` / `traefik.hostname`).

**1.8.2.** (Phụ lục) Cilium **Gateway API** — `Gateway` / `HTTPRoute` treo **Progressing** trên Kind

Repo hiện tại **không** sync `Gateway` / `HTTPRoute` cho stack `go-micro`; mục này chỉ để tham chiếu nếu bạn tự thêm workload Gateway API.

- Argo CD health cho Gateway API thường cần *Programmed=True* / parent *Accepted*; trên Kind, Cilium Gateway đôi khi không đạt đủ điều kiện → resource treo **Progressing** dù **Rollout** đã **Healthy**.
- Triệu chứng: `kubectl get gateway meo-gw` *Waiting for controller*; không có Service **`cilium-gateway-*`**; `kubectl get gatewayclass cilium` ACCEPTED **Unknown**.
- Thử: restart `deployment/cilium-operator` trên cluster đang lỗi; kiểm MetalLB; tùy chọn tùy chỉnh health Lua trong `argocd-cm` hoặc nâng Argo CD.

**Context đúng cho từng việc**

- CRD `Application` (Argo) chỉ có trên cluster cài Argo → **`kubectl ... application ...` dùng `--context kind-management`**, **không** dùng `kind-dev`.
- Pod/Secret/ConfigMap trên workload cluster → **`kind-dev` / `kind-staging` / `kind-prod`**.
- Lệnh **Helm** trỏ cluster bằng **`--kube-context kind-dev`**, không có flag `--context` (đó là của `kubectl`).

**External Secrets chart trong repo (không còn file cũ)**

- Apply manifest ESO **không** dùng các file `-secrets.yaml` lẻ tẻ. Luôn dùng:
  - `external-secrets/applications/values.yaml`
  - `config/base/config.yaml` (Chứa danh sách key secret)
  - `config/env/dev.yaml` | `staging.yaml` | `prod.yaml` (Chứa path metadata)
- Mỗi env chỉ cần chạy **một** lệnh `helm template ... | kubectl apply` tổng thể thay vì chia ra backend/database profile.

**Pod `ContainerCreating` + `configmap "backend-config" not found`**

- Chart `template` chỉ tạo ConfigMap khi **có** `runtimeConfig.enabled` **và** `runtimeConfig.data` (xem `template/templates/configmap.yaml`). Nếu trên cluster vẫn không thấy ConfigMap, gần như chắc **Argo đang sync revision Git cũ** (bootstrap trỏ `https://github.com/minhtri1612/go-micro.git` `main` — phải **push** đúng repo/branch đó). Sau khi push: Refresh + Sync app trên Argo.
- Từ bản chart đã cập nhật: Deployment/StatefulSet **chỉ mount** volume `app-config` khi có `runtimeConfig.data` (khớp điều kiện tạo ConfigMap) — tránh pod kẹt vĩnh viễn khi Git chưa có `data` (pod có thể lên nhưng thiếu file config cho tới khi bạn sync đúng Git).

**DATABASE_URL hostname `postgres` vs service name `database`**

- AWS Secrets Manager (và mục 1.5.2 static secrets) lưu `DATABASE_URL` với hostname **`postgres.database.svc.cluster.local`**.
- Nhưng ArgoCD template set `fullnameOverride: database` → K8s service tên **`database`**, không phải `postgres`.
- **Fix đã có trong Git:** `config/base/config.yaml` khai báo `database.service.aliases: [postgres]`, template `service-alias.yaml` tự tạo ExternalName service `postgres` → `database.database.svc.cluster.local`. ArgoCD quản lý, không mất khi recreate Kind.
- Nếu vẫn lỗi DNS `NXDOMAIN` cho `postgres.database.svc...`: sync lại database app (`argocd app sync argocd/*-go-microservices-*-db-app`).

**ExternalSecret database `SecretSyncedError`**

- Kiểm tra `config/env/<env>.yaml`: `database.secrets.remoteKey` phải **trùng tên secret thật** trên AWS. Nếu Terraform chỉ tạo một JSON `.../app-credentials`, đừng trỏ DB sang `.../database` khi secret đó chưa tồn tại.

**Backend CrashLoopBackOff — probe timeout trên Kind**

- CiliumNetworkPolicy L7 HTTP rules route tất cả traffic qua Envoy proxy. Trên Kind single-node, Envoy bị overload → kubelet health probe timeout → liveness kill container → CrashLoopBackOff.
- **Fix:** `ciliumNetworkPolicy.enabled: false` trong `config/env/{dev,staging,prod}.yaml` khi chạy trên Kind. Bật lại trên cluster multi-node / RKE2.
- Probe config nên có `initialDelaySeconds` và `timeoutSeconds` >= 5s (xem `app/be.yaml`).

**Grafana không thấy (hoặc thiếu) metrics từ cluster dev/staging/prod**

- Xem **mục 1.6.1**: sau recreate Kind, URL `remote_write` trong Git thường **sai**. Chạy `./scripts/sync-monitoring-remote-write-url.sh`, commit/push, sync lại `monitoring-{dev,staging,prod}`. Kiểm `./scripts/sync-monitoring-remote-write-url.sh --check`.
- Thứ tự: `monitoring-management` (05) phải **Healthy** trước khi kỳ vọng agent push. Pod trên workload cluster **không** nhất thiết `curl` được tới IP management (mạng Kind tách cluster) — đừng dùng `kubectl run curl` trên dev để kết luận Prometheus management chết; test từ **host** hoặc `--check` như trên.

**ServiceAccount “exists and cannot be imported into the current release”**

- Tài nguyên đã được tạo trước đó không thuộc Helm release hiện tại. Trên môi trường practice: ưu tiên **một** luồng (Argo **hoặc** Helm tay); tránh vừa Argo vừa `helm upgrade` cùng release.

---

## 2. Kiểm tra nhanh

- Remote write (sau recreate Kind): `./scripts/sync-monitoring-remote-write-url.sh --check` — xem **1.6.1**.
- ClusterMesh: `bash scripts/kind-clustermesh-status.sh` (hoặc `cilium clustermesh status --context kind-management`). Mô hình hiện tại: **tất cả 4 cluster** đều chạy `clustermesh-apiserver` kiểu `LoadBalancer` với IP tĩnh MetalLB, tránh phụ thuộc Docker IP/NodePort sau recreate Kind:
  - management: `172.18.255.41:2379`
  - dev: `172.18.255.11:2379`
  - staging: `172.18.255.21:2379`
  - prod: `172.18.255.31:2379`

  Spoke kết nối tới hub qua hostname `management.mesh.cilium.io` (resolve bằng `hostAliases` trên clustermesh-apiserver pod → `172.18.255.41`). Hub kết nối tới spoke qua `<spoke>.mesh.cilium.io` (cùng cơ chế). Khi có drift/CA rotate: sync `cilium-management` → chạy `./scripts/kind-clustermesh-sync-spoke-from-hub.sh` → sync `cilium-{dev,staging,prod}` → kiểm lại status.

  Script `./scripts/kind-clustermesh-peer-ip.sh` tự đọc EXTERNAL-IP của management LB (không phụ thuộc `docker inspect` nữa) và ghi vào `cilium/clustermesh-management-peer.yaml`.

  Verify nhanh (copy/paste):
  ```bash
  # 1) Kiểm endpoint LB của clustermesh-apiserver trên cả 4 cluster
  for ctx in kind-management kind-dev kind-staging kind-prod; do
    echo "=== $ctx ===" && kubectl --context $ctx -n kube-system get svc clustermesh-apiserver -o wide
  done

  # 2) Kiểm hostAliases trên spoke (phải map management.mesh.cilium.io → 172.18.255.41)
  for ctx in kind-dev kind-staging kind-prod; do
    echo "=== $ctx ===" && kubectl --context $ctx -n kube-system get deploy clustermesh-apiserver \
      -o jsonpath='{range .spec.template.spec.hostAliases[*]}{.ip} {.hostnames}{"\n"}{end}'
  done

  # 3) Kiểm hostAliases trên management (phải map spoke IP MetalLB)
  kubectl --context kind-management -n kube-system get deploy clustermesh-apiserver \
    -o jsonpath='{range .spec.template.spec.hostAliases[*]}{.ip} {.hostnames}{"\n"}{end}'

  # 4) Kiểm kết nối ClusterMesh 4 cụm (mong đợi tất cả 1/1 connected)
  for ctx in kind-management kind-dev kind-staging kind-prod; do
    echo "========== $ctx ==========" && cilium clustermesh status --context $ctx
  done
  ```
- UI ArgoCD: https://localhost:8080 → Applications: `dev-*`, `monitoring-*`...
- UI Grafana (tập trung; series từ workload có nhãn `cluster` / `environment` từ remote_write):
  ```bash
  kubectl -n monitoring port-forward svc/monitoring-management-grafana 3000:80
  # Truy cập: http://localhost:3000 (admin / admin)
  ```
- Management: `kubectl --context kind-management get pods -n monitoring`
- Dev: `kubectl --context kind-dev get pods -n monitoring`
- Staging: `kubectl --context kind-staging get pods -A`
- Prod: `kubectl --context kind-prod get pods -A`

---

## 3. Lưu ý

- Replica count / image tag trong `env/<env>.yaml`. Chart workload `template/`; profile `app/be.yaml`, `app/db.yaml`; config `config/base/config.yaml`, override `config/env/<env>.yaml`.
- **Traefik + canary:** Bootstrap **`argocd/bootstrap/19–21-traefik-*.yaml`** (sau MetalLB). App values: `routing.provider: traefik`, `traefik.enabled`, hostname theo env. Argo Rollouts cần plugin trong `argocd/argo-rollouts-values.yaml` — **mục 1.7**, gỡ rối **1.8.1**.
- **Kind API / TLS:** `bash scripts/kind-fix-kubeconfig-servers.sh` sau `kind create`. Trên **management**, **trước** `helm install cilium` — nếu Helm lỗi TLS thì không có CNI (`disableDefaultCNI`) và Argo CD **Pending**.
- **Helm Cilium bootstrap:** Lần đầu trên management **chưa** có kube-prometheus-stack và MetalLB → **bắt buộc** dùng thêm file `cilium-values-management-bootstrap.yaml` (mục **1.2**). File này tắt ServiceMonitor (chưa có CRD) và override `clustermesh.apiserver.service.type` về `NodePort` (chưa có MetalLB → Helm `--wait` sẽ treo chờ EXTERNAL-IP mãi). Sau khi Argo sync monitoring + cilium-management, ArgoCD sẽ chuyển lại cấu hình đầy đủ.
- **Hubble UI / CLI:** Management → port-forward **12000**. Workload → NodePort **31201 / 31202 / 31203** (IP `docker inspect *-control-plane`). CLI flow: `cilium hubble port-forward` + **`hubble observe flows`** — **mục 1.7.4**.
- **ClusterMesh:** Tất cả 4 cluster đều dùng `clustermesh-apiserver` kiểu **LoadBalancer** với IP tĩnh MetalLB (`management: 172.18.255.41`, `dev: .11`, `staging: .21`, `prod: .31`), **không phụ thuộc Docker IP/NodePort** — khi recreate Kind, IP Docker đổi nhưng IP MetalLB giữ nguyên.
  - **Hub** (management): khai báo endpoint spoke trong `cilium-values-management.yaml` → `clustermesh.config.clusters` (dev/staging/prod: `172.18.255.11/21/31:2379`).
  - **Spoke** (dev/staging/prod): khai báo endpoint hub trong `cilium/clustermesh-management-peer.yaml` (`172.18.255.41:2379`). File này do script `./scripts/kind-clustermesh-peer-ip.sh` tự generate (đọc EXTERNAL-IP của management LB).
  - Hub/spoke cần **cùng** cấu hình encryption (`cilium/cilium-values.yaml`).
  - **CA bundle cross-cluster:** Mỗi cluster có CA riêng. ClusterMesh cần tất cả CA được bundle trong `clustermesh-apiserver-remote-cert` và `clustermesh-apiserver-server-cert` trên **mỗi** cluster. Script `./scripts/kind-clustermesh-sync-spoke-from-hub.sh` xử lý việc này. **Sau mỗi lần recreate Kind** (CA mới được sinh), **phải** chạy lại script sync CA.
  - Nếu pool MetalLB đổi/subnet đổi mà chưa cập nhật values, KVStoreMesh sẽ báo `connection refused`. Sau khi sửa values: sync `cilium-management` → chạy `./scripts/kind-clustermesh-sync-spoke-from-hub.sh` → sync `cilium-{dev,staging,prod}` → kiểm bằng `cilium clustermesh status`.
- **Monitoring remote_write:** Sau mỗi lần recreate Kind, chạy `./scripts/sync-monitoring-remote-write-url.sh` rồi commit/push và sync agent — chi tiết **1.6.1**. Management không còn scrape tĩnh node-exporter/kube-state từ các workload cluster; nếu bỏ bước này, Grafana thiếu series theo `cluster`/`environment`.
- **Linux:** Argo CD → API dev/staging/prod dùng **container IP + 6443** (mục **1.4**). `docker inspect <cluster>-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}'`. Không dùng `host.docker.internal` trên Linux.
- Đổi port trong `kind/*-kind-config.yaml` thì cập nhật tương ứng mục **1.4** và `scripts/kind-fix-kubeconfig-servers.sh` nếu cần.
- **RAM:** Nhiều cụm Kind song song dễ thiếu bộ nhớ → **kind/README.md**.
- **Database/backend:** ESO+AWS (**mục 1.5.1**) hoặc Secret tĩnh (**mục 1.5.2**). Lệnh có pipe: `--context` ở **cả hai** phía.
