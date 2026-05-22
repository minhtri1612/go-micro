# CI — `PIPELINE_SCOPE=auto`

## Chỉ sửa `env/dev.yaml` (tag đã build sẵn trên Hub, ví dụ rollback v1.0.3)

1. Push `env/dev.yaml` lên `main` **hoặc** đã push rồi → Jenkins Build:
   - `PIPELINE_SCOPE=auto` **hoặc**
   - bật **`DEPLOY_EXISTING_ENV_TAGS=true`** (khi commit hiện tại chỉ Jenkinsfile)
2. Pipeline: **verify tag có trên Hub** → **skip** Build + Push Git → **chạy** Prepare + test + promote
3. Argo sync Git (tag trong env/) — Jenkins không push Git lại nếu không build

## Sửa code `order-service/`

- Build **chỉ order** (bump tag) → nếu tag mới **đã có Hub** thì skip docker build → Push Git → test + promote

## Commit chỉ Jenkinsfile / scripts/ci

- `auto` → **skip build**, vẫn **chạy Parallel tests** với tag trong `env/dev.yaml` (verify Hub).
- Hoặc bật **`DEPLOY_EXISTING_ENV_TAGS=true`** (cùng ý).

## Test trước Promote (canary pause)

Sau Argo sync tag mới: rollout **Paused**, stable Endpoints trống, canary có pod. Jenkins **tự** `X-Canary:true` — không cần `kubectl promote` trước test. Pass test → **Rollout Decision Gate** → Promote.

## Override

| Param / scope | Ý nghĩa |
|---------------|---------|
| `DEPLOY_EXISTING_ENV_TAGS` | Luôn dùng tag trong env/, verify Hub, test+promote |
| `build-only` | Chỉ build, không test |
| `full` | Chỉ test/promote |
