# CI: git push → bump tag → Hub → env/dev.yaml

## Việc của bạn

1. Sửa code (vd. `order-service/`)
2. `git push main`
3. Jenkins: `build-only`, **`BUILD_SERVICES=all`** (mặc định), `PUSH_GIT=true` — build 6 service + client. Dùng `auto` chỉ khi commit có sửa code trong `*-service/`.
4. Lần promote: Build với `PIPELINE_SCOPE=full`, `DEPENDENCY_SERVICES` / `BUSINESS_SERVICES` / `ROLLOUT_SERVICE` = service vừa đổi → Promote

## Jenkins tự làm (build-only)

- `detect-changed-services.sh` — service nào có diff (`order-service/**` → `order`)
- `bump-image-tag.sh` — đọc tag trong `env/dev.yaml`, **+1 patch** (vd. `order-service-v1.0.4` → `v1.0.5`)
- `docker-build-push.sh` — push `minhtri1612/go-microservice:<tag>`
- `git push` — cập nhật `env/dev.yaml` trên GitHub → Argo dev sync

**Không sửa `env/` tay.**

## `BUILD_SERVICES=auto`

- Commit có `product-service/`, `order-service/`, … → chỉ build service đó.
- Commit **chỉ** Jenkinsfile / `scripts/ci/` → **fallback build all** (6 service + client), không fail.

## Tag baseline

`env/dev.yaml` khớp Hub hiện tại (`v1.0.3`). Lần build tiếp theo cho `order` → `order-service-v1.0.4`, lần sau `v1.0.5`, …

## Credentials (setup từ đầu — không UI)

```bash
cp scripts/jenkins-ci.env.example scripts/jenkins-ci.env
# Điền DOCKERHUB_TOKEN (Hub) + GITHUB_PAT — KHÔNG dùng AWS key ESO
source scripts/jenkins-ci.env && bash scripts/jenkins-setup-ci-secrets.sh
argocd app sync jenkins-management
kubectl -n jenkins delete pod jenkins-management-0
```

JCasC tạo ID:

- `dockerhub-credentials`
- `github-go-micro-pat` (push Git)
