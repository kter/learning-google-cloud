# =============================================================================
# main.tf - メインリソース定義ファイル
# =============================================================================
# このファイルでは、Google Cloud上にLaravelアプリケーション用のインフラストラクチャを
# 構築するためのリソースを定義します。主要コンポーネント：
# - Cloud Build（CI/CD）
# - Cloud Run（コンテナ実行環境）
# - Artifact Registry（コンテナイメージ保存）
# - Load Balancer（負荷分散）
# - Secret Manager（秘密情報管理）

# プロバイダー設定
# -----------------------------------------------------------------------------

# Google Cloudプロバイダー（メイン）の設定
provider "google" {
  project = var.project_id  # variables.tfで定義されたプロジェクトIDを使用
  region  = var.region      # variables.tfで定義されたリージョンを使用
}

# Google Cloud Betaプロバイダーの設定（Beta機能を使用する場合）
provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# データソース（既存リソースの情報取得）
# -----------------------------------------------------------------------------

# 現在のGoogle Cloudプロジェクトの情報を取得
data "google_project" "project" {
  project_id = var.project_id  # プロジェクト番号などの情報を取得
}

# ローカル値（このファイル内で再利用される値を定義）
# -----------------------------------------------------------------------------

locals {
  # 全リソースに適用するデフォルトラベル（タグ）を作成
  default_labels = merge(var.labels, {
    project     = var.project_id    # プロジェクト識別
    environment = var.environment   # 環境識別（dev/staging/prod）
    application = var.app_name      # アプリケーション識別
    managed_by  = "terraform"       # 管理ツール識別
  })

  # 各リソース名のプレフィックス（統一的な命名のため）
  service_name    = "${var.app_name}-${var.environment}"  # 例：laravel-app-dev
  repository_name = "${var.app_name}-repo"                # 例：laravel-app-repo
  build_sa_name   = "${var.app_name}-build-sa"           # Cloud Build用サービスアカウント名
  run_sa_name     = "${var.app_name}-run-sa"             # Cloud Run用サービスアカウント名
  
  # 有効化が必要なGoogle Cloud APIのリスト
  required_apis = [
    "cloudbuild.googleapis.com",        # Cloud Build API
    "run.googleapis.com",               # Cloud Run API
    "artifactregistry.googleapis.com",  # Artifact Registry API
    "secretmanager.googleapis.com",     # Secret Manager API
    "compute.googleapis.com",           # Compute Engine API（ロードバランサー用）
    "cloudresourcemanager.googleapis.com", # プロジェクト管理API
    "iam.googleapis.com"                # IAM API
  ]
}

# Google Cloud API有効化
# -----------------------------------------------------------------------------

# 必要なAPIを自動的に有効化
resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)  # リストをセットに変換してループ処理
  project  = var.project_id              # 対象プロジェクト
  service  = each.value                  # 各APIサービス名

  disable_on_destroy = false  # terraform destroyでもAPIは無効化しない（安全のため）
  
  # API有効化のタイムアウト設定
  timeouts {
    create = "10m"  # 作成時最大10分
    update = "10m"  # 更新時最大10分
  }
}

# サービスアカウント（Googleが推奨する最小権限の原則に従う）
# -----------------------------------------------------------------------------

# Cloud Build専用のサービスアカウント
resource "google_service_account" "cloud_build_sa" {
  account_id   = local.build_sa_name                                      # アカウントID
  display_name = "Cloud Build Service Account for ${var.app_name}"        # 表示名
  description  = "Service account used by Cloud Build to build and deploy ${var.app_name}"

  depends_on = [google_project_service.apis]  # API有効化を待ってから作成
}

# Cloud Run専用のサービスアカウント
resource "google_service_account" "cloud_run_sa" {
  account_id   = local.run_sa_name                                        # アカウントID
  display_name = "Cloud Run Service Account for ${var.app_name}"          # 表示名
  description  = "Service account used by Cloud Run service ${var.app_name}"

  depends_on = [google_project_service.apis]
}

# IAM権限設定（最小権限の原則）
# -----------------------------------------------------------------------------

# Cloud Buildサービスアカウントに必要な権限を付与

# Cloud Buildでビルドを実行する権限
resource "google_project_iam_member" "cloud_build_editor" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.editor"                  # ビルド作成・編集権限
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Artifact Registryへイメージをプッシュする権限
resource "google_project_iam_member" "cloud_build_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"                  # レジストリ書き込み権限
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Cloud Runサービスをデプロイ・更新する権限
resource "google_project_iam_member" "cloud_build_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"                            # Cloud Run開発者権限
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# サービスアカウントを使用する権限
resource "google_project_iam_member" "cloud_build_iam_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"                   # サービスアカウント使用権限
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Cloud Runサービスアカウントに必要な権限を付与

# Secret Managerからシークレットを読み取る権限
resource "google_project_iam_member" "cloud_run_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"             # シークレット読み取り権限
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Artifact Registry（コンテナイメージ保存）
# -----------------------------------------------------------------------------

# DockerイメージのためのArtifact Registryリポジトリを作成
resource "google_artifact_registry_repository" "laravel_repo" {
  location      = var.region              # リポジトリの場所（リージョン）
  repository_id = local.repository_name   # リポジトリの識別子
  description   = "Docker repository for ${var.app_name} application"
  format        = "DOCKER"                # Dockerイメージ形式を指定
  labels        = local.default_labels    # 共通ラベルを適用

  depends_on = [google_project_service.apis]  # Artifact Registry APIの有効化を待つ
}

# Secret Manager（機密情報の安全な管理）
# -----------------------------------------------------------------------------

# APP_KEY用のシークレットを作成
resource "google_secret_manager_secret" "app_key" {
  secret_id = "${local.service_name}-app-key"  # シークレットの識別子
  
  labels = local.default_labels                # 共通ラベルを適用

  # レプリケーション設定（複数リージョンでの自動レプリケーション）
  replication {
    auto {}  # Googleが自動的に適切なリージョンにレプリケーション
  }

  depends_on = [google_project_service.apis]  # Secret Manager APIの有効化を待つ
}

# APP_KEYの実際の値をシークレットに保存
resource "google_secret_manager_secret_version" "app_key_version" {
  secret      = google_secret_manager_secret.app_key.id  # 上記で作成したシークレット
  secret_data = var.app_key                              # variables.tfで定義された値
}

# Cloud Build設定（CI/CD）
# -----------------------------------------------------------------------------

# GitHubからのプッシュをトリガーとするCloud Buildトリガー
resource "google_cloudbuild_trigger" "github_trigger" {
  name        = "${local.service_name}-github-trigger"  # トリガー名
  description = "Trigger builds from GitHub pushes to ${var.github_repo_name}"
  location    = var.region                              # トリガーの場所

  service_account = google_service_account.cloud_build_sa.id  # 使用するサービスアカウント

  # GitHub設定
  github {
    owner = var.github_repo_owner  # GitHubリポジトリの所有者
    name  = var.github_repo_name   # GitHubリポジトリ名
    push {
      branch = var.github_branch_pattern  # トリガーするブランチパターン
    }
  }

  # ビルド手順の定義
  build {
    logs_bucket = "gs://${data.google_project.project.project_id}_cloudbuild"  # ログ保存先

    # ステップ1：デバッグ情報の出力
    step {
      name       = "ubuntu"           # 使用するコンテナイメージ
      entrypoint = "bash"             # 実行するコマンド
      args = [
        "-c",
        <<-EOF
        echo "=== Listing all files in /workspace ==="
        ls -la /workspace/
        echo "=== Looking for Dockerfile* files ==="
        find /workspace -name "Dockerfile*" -type f
        EOF
      ]
      id = "debug-files"              # ステップの識別子
    }

    # ステップ2：Dockerイメージのビルド
    step {
      name = "gcr.io/cloud-builders/docker"  # Dockerビルダーを使用
      args = [
        "build",                                                                                                      # dockerビルドコマンド
        "-t", "${var.region}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.laravel_repo.repository_id}/${var.app_name}:$SHORT_SHA",  # タグ（コミットSHA付き）
        "-t", "${var.region}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.laravel_repo.repository_id}/${var.app_name}:latest",      # タグ（latest）
        "-f", var.dockerfile_path,    # Dockerfileのパス
        var.build_context_path        # ビルドコンテキスト
      ]
      id       = "build-app"          # ステップの識別子
      wait_for = ["debug-files"]      # 前のステップの完了を待つ
    }

    # ステップ3：コミットSHA付きイメージのプッシュ
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.region}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.laravel_repo.repository_id}/${var.app_name}:$SHORT_SHA"
      ]
      id = "push-sha"
    }

    # ステップ4：latestタグ付きイメージのプッシュ
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.region}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.laravel_repo.repository_id}/${var.app_name}:latest"
      ]
      id = "push-latest"
    }

    # ステップ5：Cloud Runサービスのデプロイ
    step {
      name = "gcr.io/cloud-builders/gcloud"  # gcloudコマンドを使用
      args = [
        "run", "deploy", local.service_name,   # Cloud Runデプロイコマンド
        "--image", "${var.region}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.laravel_repo.repository_id}/${var.app_name}:$SHORT_SHA",  # 使用するイメージ
        "--region", var.region,                # デプロイ先リージョン
        "--platform", "managed",               # マネージドプラットフォームを使用
        "--service-account", google_service_account.cloud_run_sa.email  # 使用するサービスアカウント
      ]
      id       = "deploy-to-run"     # ステップの識別子
      wait_for = ["push-sha"]        # SHAタグ付きイメージのプッシュ完了を待つ
    }

    # ビルド結果として保存するイメージ
    images = [
      "${var.region}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.laravel_repo.repository_id}/${var.app_name}:$SHORT_SHA",
      "${var.region}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.laravel_repo.repository_id}/${var.app_name}:latest"
    ]

    # ビルドオプション
    options {
      logging      = "CLOUD_LOGGING_ONLY"  # Cloud Loggingのみを使用
      machine_type = "E2_HIGHCPU_8"        # 高CPU仕様のマシンタイプ
    }

    timeout = "1200s"  # ビルドタイムアウト（20分）
  }

  depends_on = [
    google_project_service.apis,
    google_artifact_registry_repository.laravel_repo
  ]
}

# Cloud Run設定（コンテナ実行環境）
# -----------------------------------------------------------------------------

# Laravelアプリケーション用のCloud Runサービス
resource "google_cloud_run_v2_service" "laravel_service" {
  name     = local.service_name      # サービス名
  location = var.region              # 実行リージョン
  labels   = local.default_labels    # 共通ラベル

  # サービステンプレート（コンテナの設定）
  template {
    service_account = google_service_account.cloud_run_sa.email  # 使用するサービスアカウント
    
    # スケーリング設定
    scaling {
      min_instance_count = var.cloud_run_min_instances  # 最小インスタンス数
      max_instance_count = var.cloud_run_max_instances  # 最大インスタンス数
    }

    # コンテナ設定
    containers {
      # 使用するDockerイメージ
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.laravel_repo.repository_id}/${var.app_name}:latest"
      
      # リソース制限
      resources {
        limits = {
          cpu    = var.cloud_run_cpu     # CPU制限
          memory = var.cloud_run_memory  # メモリ制限
        }
      }

      # ポート設定
      ports {
        container_port = 8080  # コンテナがリッスンするポート
      }

      # 環境変数設定
      env {
        name  = "LOG_CHANNEL"  # Laravel logging設定
        value = "stdout"       # 標準出力へのログ出力
      }

      # Secret Managerからの環境変数設定
      env {
        name = "APP_KEY"      # LaravelのAPP_KEY
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.app_key.secret_id  # 参照するシークレット
            version = "latest"                                        # 最新バージョンを使用
          }
        }
      }
    }
  }

  # トラフィック設定
  traffic {
    percent = 100                                          # 全トラフィックを最新リビジョンに
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"      # 最新リビジョンを使用
  }

  depends_on = [
    google_project_service.apis,
    google_artifact_registry_repository.laravel_repo,
    google_secret_manager_secret_version.app_key_version
  ]
}

# Cloud Runサービスへのパブリックアクセス許可
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.laravel_service.location
  project  = google_cloud_run_v2_service.laravel_service.project
  service  = google_cloud_run_v2_service.laravel_service.name
  role     = "roles/run.invoker"  # Cloud Runサービス呼び出し権限
  member   = "allUsers"           # 全ユーザーに許可（パブリックアクセス）
}

# ロードバランサー設定（グローバル負荷分散）
# -----------------------------------------------------------------------------

# 静的外部IPアドレスの予約
resource "google_compute_global_address" "default" {
  name         = "${local.service_name}-lb-ip"  # IPアドレス名
  description  = "Static IP for ${var.app_name} load balancer"
  address_type = "EXTERNAL"                     # 外部アドレス
  ip_version   = "IPV4"                         # IPv4を使用

  depends_on = [google_project_service.apis]
}

# Cloud Run用のネットワークエンドポイントグループ
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "${local.service_name}-neg"    # NEG名
  network_endpoint_type = "SERVERLESS"                   # サーバーレスタイプ
  region                = var.region                     # リージョン
  
  # Cloud Runサービスの設定
  cloud_run {
    service = google_cloud_run_v2_service.laravel_service.name
  }

  depends_on = [google_project_service.apis]
}

# バックエンドサービス（ロードバランサーのバックエンド）
resource "google_compute_backend_service" "cloud_run_backend" {
  name        = "${local.service_name}-backend"  # バックエンドサービス名
  description = "Backend service for ${var.app_name}"
  protocol    = "HTTPS"                          # HTTPS通信を使用
  
  # バックエンド設定
  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }

  # アクセスログ設定
  log_config {
    enable = true  # ログを有効化
  }

  depends_on = [google_project_service.apis]
}

# URLマップ（URLルーティング設定）
resource "google_compute_url_map" "default" {
  name            = "${local.service_name}-url-map"        # URLマップ名
  description     = "URL map for ${var.app_name}"
  default_service = google_compute_backend_service.cloud_run_backend.id  # デフォルトバックエンド

  depends_on = [google_project_service.apis]
}

# HTTPS用のターゲットプロキシ（SSL有効時）
resource "google_compute_target_https_proxy" "default" {
  count = var.enable_ssl ? 1 : 0  # SSL有効時のみ作成
  
  name    = "${local.service_name}-https-proxy"
  url_map = google_compute_url_map.default.id
  
  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]  # SSL証明書を関連付け

  depends_on = [google_project_service.apis]
}

# HTTP用のターゲットプロキシ（SSL無効時）
resource "google_compute_target_http_proxy" "default" {
  count = var.enable_ssl ? 0 : 1  # SSL無効時のみ作成
  
  name    = "${local.service_name}-http-proxy"
  url_map = google_compute_url_map.default.id

  depends_on = [google_project_service.apis]
}

# マネージドSSL証明書（カスタムドメイン使用時）
resource "google_compute_managed_ssl_certificate" "default" {
  count = var.enable_ssl && var.domain_name != "" ? 1 : 0  # SSL有効且つドメイン名指定時のみ
  
  name = "${local.service_name}-ssl-cert"

  # マネージド証明書設定
  managed {
    domains = [var.domain_name]  # 証明書を発行するドメイン
  }

  depends_on = [google_project_service.apis]
}

# グローバル転送ルール（外部からのアクセスを受け付ける）
# -----------------------------------------------------------------------------

# HTTPS用の転送ルール（SSL有効時）
resource "google_compute_global_forwarding_rule" "https_rule" {
  count = var.enable_ssl ? 1 : 0
  
  name       = "${local.service_name}-https-rule"
  target     = google_compute_target_https_proxy.default[0].id  # HTTPSプロキシに転送
  port_range = "443"                                           # HTTPS標準ポート
  ip_address = google_compute_global_address.default.id       # 予約済みIP使用

  depends_on = [google_project_service.apis]
}

# HTTP用の転送ルール
resource "google_compute_global_forwarding_rule" "http_rule" {
  name       = "${local.service_name}-http-rule"
  target     = var.enable_ssl ? google_compute_target_https_proxy.default[0].id : google_compute_target_http_proxy.default[0].id  # SSL設定に応じて転送先を選択
  port_range = var.enable_ssl ? "443" : "80"                  # SSL有効時は443、無効時は80
  ip_address = google_compute_global_address.default.id       # 予約済みIP使用

  depends_on = [google_project_service.apis]
}