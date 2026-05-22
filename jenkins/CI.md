# CI — `PIPELINE_SCOPE=auto` (mặc định)

Jenkins **detect commit** — không cần chọn `build-only` vs `full` mỗi lần.

## 1. Chỉ sửa `env/dev.yaml` (test tag GitOps)

- **Skip:** Build & push images, Push Git  
- **Chạy:** Prepare → test → promote gate  
- Argo sync Git là đủ để cluster dùng tag mới  

## 2. Sửa code `order-service/` (ví dụ)

- **Chạy:** Build & push **chỉ order** → bump tag order trong `env/dev.yaml` → Push Git  
- **Rồi:** Prepare → test (auto chọn `order` nếu 1 service) → promote  

## 3. Commit `ci: bump` / chỉ Jenkinsfile

- **Skip** cả build lẫn test → SUCCESS  

## Override thủ công

| Scope | Khi nào |
|-------|---------|
| `build-only` | Chỉ build, không test |
| `full` | Chỉ test/promote, không build |
| `build-and-full` | Luôn cả hai |

`BUILD_SERVICES=all` chỉ khi rebuild cả 6 service + client.
