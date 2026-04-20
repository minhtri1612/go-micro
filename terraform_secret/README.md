# terraform_secret - AWS Secrets Manager for go-micro

This stack creates one JSON secret per environment in AWS Secrets Manager:

`{project_name}/{env}/app-credentials{suffix}`

## Keys stored in each JSON secret

- `DB_USER`
- `DB_PASSWORD`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `STRIPE_SECRET_KEY`

## Run

```bash
cd terraform_secret
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
terraform output app_credentials_secret_names
```

## IAM credentials for External Secrets Operator

This stack also creates an IAM user with `secretsmanager:GetSecretValue` for the project prefix.

Get credentials:

```bash
terraform output -raw eso_access_key_id
terraform output -raw eso_secret_access_key
```

Create Kubernetes secret for ESO:

```bash
kubectl -n external-secrets create secret generic aws-credentials \
  --from-literal=access-key-id="$(terraform output -raw eso_access_key_id)" \
  --from-literal=secret-access-key="$(terraform output -raw eso_secret_access_key)"
```
