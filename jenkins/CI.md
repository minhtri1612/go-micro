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

## Rollback tự động (`PIPELINE_SCOPE=rollback`)

Không sửa tay `env/` — Jenkins đọc tag **hiện tại trong Git**, patch **−1**, verify image có trên Hub, ghi yaml + push → Argo sync.

| Param | Ý nghĩa |
|-------|---------|
| `PIPELINE_SCOPE=rollback` | Chỉ stage Rollback (checkout + decrement + push Git) |
| `ROLLBACK_SERVICE` | `payment` = một service; để trống = product, inventory, order, payment, noti (không client) |
| `TARGET_ENV` | `dev` → `env/dev.yaml` |
| `PUSH_GIT` | Mặc định true — push commit `ci: rollback tags ...` |

Ví dụ: yaml `payment-service-v1.0.4` → rollback → `v1.0.3` (phải còn trên Hub).

**Giới hạn:** rollback = **một bậc patch** so với tag trong `env/` (Git), không phải “latest Hub − 1” nếu yaml lệch cluster.

## Override

| Param / scope | Ý nghĩa |
|---------------|---------|
| `DEPLOY_EXISTING_ENV_TAGS` | Luôn dùng tag trong env/, verify Hub, test+promote |
| `build-only` | Chỉ build, không test |
| `full` | Chỉ test/promote |
