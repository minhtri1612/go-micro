# CI: git push → bump tag → Hub → env/dev.yaml

## Việc của bạn

1. Sửa code trong **một** service (vd. `order-service/`)
2. `git push main` — Jenkins poll SCM (~5 phút), mặc định **`BUILD_SERVICES=auto`**
3. Chỉ service đó được bump + build + push Hub + push `env/dev.yaml`
4. **Promote** (tách bước): `PIPELINE_SCOPE=full`, `ROLLOUT_SERVICE` = service vừa deploy (vd. `order`) → test → Promote

`build-only` **không có** Promote — đó là đúng thiết kế.

## Jenkins tự làm (build-only + auto)

- `detect-changed-services.sh` — file trong commit thuộc `*-service/` hoặc `client/`
- Chỉ service đó: `bump-image-tag.sh` (+1 patch) → `docker-build-push.sh` → `git push` env
- Commit message `ci: bump tags … [skip ci]` → **không** build lại (tránh vòng poll SCM)

## Khi nào **không** bump tag

- Commit chỉ Jenkinsfile / `scripts/ci/` / **`env/dev.yaml`** (downgrade tag v1.0.8→v1.0.3) → Jenkins **SUCCESS + skip build**; **Argo sync** là đủ, không cần `build-only`.
- Commit do Jenkins push (`ci: bump …`)
- Dùng `BUILD_SERVICES=all` thủ công nếu cần rebuild cả 6 service + client

## Tag baseline

`env/dev.yaml` là source of truth cho Argo. Chỉ tăng patch khi **có build** service đó.

## Credentials

Xem `scripts/jenkins-ci.env.example` + `bash scripts/jenkins-setup-ci-secrets.sh`
