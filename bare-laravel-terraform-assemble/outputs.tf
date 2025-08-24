# =============================================================================
# outputs.tf - 出力値定義ファイル
# =============================================================================
# このファイルでは、Terraformでリソースを作成した後に表示される出力値を定義します。
# これらの値は、デプロイ完了後に重要な情報（URL、IDなど）をユーザーに提供します。

# プロジェクト基本情報
# -----------------------------------------------------------------------------

# 使用したGoogle CloudプロジェクトIDを出力
output "project_id" {
  description = "リソースが作成されたGoogle CloudプロジェクトのID"
  value       = var.project_id  # variables.tfで定義されたproject_id変数の値
}

# 使用したリージョン（地域）を出力
output "region" {
  description = "リソースが作成されたGoogle Cloudリージョン（地域）"
  value       = var.region  # variables.tfで定義されたregion変数の値
}

# Artifact Registry（コンテナレジストリ）情報
# -----------------------------------------------------------------------------

# Artifact RegistryリポジトリのIDを出力
output "artifact_registry_repository_id" {
  description = "Artifact Registryリポジトリの一意識別子"
  value       = google_artifact_registry_repository.laravel_repo.repository_id
}

# Artifact RegistryリポジトリのURLを出力（Dockerイメージのプッシュ先）
output "artifact_registry_repository_url" {
  description = "Artifact RegistryリポジトリのURL（Dockerイメージの保存先）"
  # フォーマット例：asia-northeast1-docker.pkg.dev/playground2/laravel-app-repo
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.laravel_repo.repository_id}"
}

# Cloud Build情報
# -----------------------------------------------------------------------------

# Cloud BuildトリガーのIDを出力
output "cloud_build_trigger_id" {
  description = "Cloud Buildトリガーの一意識別子"
  value       = google_cloudbuild_trigger.github_trigger.trigger_id
}

# Cloud Run情報
# -----------------------------------------------------------------------------

# Cloud Runサービス名を出力
output "cloud_run_service_name" {
  description = "Cloud Runサービスの名前"
  value       = google_cloud_run_v2_service.laravel_service.name
}

# Cloud RunサービスのURLを出力（直接アクセス用）
output "cloud_run_service_url" {
  description = "Cloud RunサービスのURL（直接アクセス用）"
  value       = google_cloud_run_v2_service.laravel_service.uri
}

# ロードバランサー情報
# -----------------------------------------------------------------------------

# ロードバランサーの外部IPアドレスを出力
output "load_balancer_ip" {
  description = "ロードバランサーの外部IPアドレス"
  value       = google_compute_global_address.default.address
}

# アプリケーションへのアクセスURL（SSL設定に応じてhttp/httpsを選択）
output "load_balancer_url" {
  description = "ロードバランサー経由でアプリケーションにアクセスするためのURL"
  # SSL有効時：https://ドメイン名またはIP、SSL無効時：http://ドメイン名またはIP
  value = var.enable_ssl ? 
    "https://${var.domain_name != "" ? var.domain_name : google_compute_global_address.default.address}" : 
    "http://${var.domain_name != "" ? var.domain_name : google_compute_global_address.default.address}"
}

# Secret Manager情報
# -----------------------------------------------------------------------------

# Secret ManagerのシークレットIDを出力
output "secret_manager_secret_id" {
  description = "APP_KEYを保存するSecret Managerシークレットの識別子"
  value       = google_secret_manager_secret.app_key.secret_id
}

# サービスアカウント情報
# -----------------------------------------------------------------------------

# Cloud Run用サービスアカウントのメールアドレス
output "cloud_run_invoker_email" {
  description = "Cloud Runサービスで使用されるサービスアカウントのメールアドレス"
  value       = google_service_account.cloud_run_sa.email
}

# Cloud Build用サービスアカウントのメールアドレス
output "cloud_build_sa_email" {
  description = "Cloud Buildで使用されるサービスアカウントのメールアドレス"
  value       = google_service_account.cloud_build_sa.email
}