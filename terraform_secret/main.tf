module "app_credentials" {
  source   = "./modules/app_credentials_only"
  for_each = var.environments

  environment                 = each.key
  project_name                = var.project_name
  db_user                     = var.db_user
  app_credentials_name_suffix = lookup(var.app_credentials_name_suffix_by_env, each.key, "")
}
