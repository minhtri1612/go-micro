# CI: git push → bump tag → Hub → env/dev.yaml

## Việc của bạn

1. Sửa code (vd. `order-service/`)
2. `git push main`
3. Jenkins tự chạy (poll ~5 phút) **hoặc** Build Now với mặc định: `build-only`, `BUILD_SERVICES=auto`, `PUSH_GIT=true`
4. Lần promote: Build với `PIPELINE_SCOPE=full`, `DEPENDENCY_SERVICES` / `BUSINESS_SERVICES` / `ROLLOUT_SERVICE` = service vừa đổi → Promote

## Jenkins tự làm (build-only)

- `detect-changed-services.sh` — service nào có diff (`order-service/**` → `order`)
- `bump-image-tag.sh` — đọc tag trong `env/dev.yaml`, **+1 patch** (vd. `order-service-v1.0.4` → `v1.0.5`)
- `docker-build-push.sh` — push `minhtri1612/go-microservice:<tag>`
- `git push` — cập nhật `env/dev.yaml` trên GitHub → Argo dev sync

**Không sửa `env/` tay.**

## `No services to build` / SUCCESS nhưng không làm gì

`BUILD_SERVICES=auto` chỉ nhìn diff **code service** (`order-service/**`, …). Commit chỉ đổi `env/`, `jenkins/`, `Jenkinsfile` → **không build** (đúng).

- Commit trên GitHub **phải có** file `order-service/...` (`git show --name-only -1`). Message "fix order" nhưng chỉ push Jenkinsfile → auto **không** build order.
- Hoặc Build tay: `BUILD_SERVICES=order`

## Tag baseline

`env/dev.yaml` khớp Hub hiện tại (`v1.0.3`). Lần build tiếp theo cho `order` → `order-service-v1.0.4`, lần sau `v1.0.5`, …

## Credentials Jenkins

- `dockerhub-credentials`
- `github-go-micro-pat` (push Git)
