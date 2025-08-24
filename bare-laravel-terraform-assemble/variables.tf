# =============================================================================
# variables.tf - 変数定義ファイル
# =============================================================================
# このファイルでは、Terraformで使用する変数を定義します。
# 各変数には型制約、説明、デフォルト値、バリデーションルールを設定しています。

# Google Cloudプロジェクト設定
# -----------------------------------------------------------------------------

# Google CloudのプロジェクトIDを指定する変数
variable "project_id" {
  description = "リソースを作成するGoogle CloudプロジェクトのID（例：playground2）"
  type        = string  # 文字列型を指定
  
  # バリデーション：プロジェクトIDが空でないことをチェック
  validation {
    condition     = length(var.project_id) > 0  # 文字数が0より大きい
    error_message = "プロジェクトIDは空にできません。"
  }
}

# リージョン（地域）を指定する変数
variable "region" {
  description = "地域リソースを作成するGoogle Cloudのリージョン（地域）"
  type        = string
  default     = "asia-northeast1"  # 東京リージョンをデフォルトに設定
  
  # バリデーション：有効なリージョンのみを許可
  validation {
    condition = contains([
      "asia-northeast1",  # 東京
      "asia-northeast2",  # 大阪
      "asia-northeast3",  # ソウル
      "us-central1",      # アイオワ
      "us-east1",         # サウスカロライナ
      "us-east4",         # 北バージニア
      "us-west1",         # オレゴン
      "europe-west1",     # ベルギー
      "europe-west2",     # ロンドン
      "europe-west3"      # フランクフルト
    ], var.region)
    error_message = "有効なGoogle Cloudリージョンを指定してください。"
  }
}

# アプリケーション設定
# -----------------------------------------------------------------------------

# 環境名（開発、ステージング、本番など）を指定する変数
variable "environment" {
  description = "デプロイ環境（dev=開発、staging=ステージング、prod=本番）"
  type        = string
  default     = "dev"  # 開発環境をデフォルトに設定
  
  # バリデーション：指定された環境名のみを許可
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "環境は dev、staging、prod のいずれかである必要があります。"
  }
}

# アプリケーション名を指定する変数
variable "app_name" {
  description = "アプリケーションの名前（リソース名のプレフィックスに使用）"
  type        = string
  default     = "laravel-app"  # Laravelアプリをデフォルトに設定
  
  # バリデーション：命名規則をチェック（小文字、数字、ハイフンのみ）
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.app_name))
    error_message = "アプリ名は小文字で始まり、小文字・数字・ハイフンのみを含み、小文字または数字で終わる必要があります。"
  }
}

# GitHub設定
# -----------------------------------------------------------------------------

# GitHubリポジトリの所有者（ユーザー名または組織名）
variable "github_repo_owner" {
  description = "GitHubリポジトリの所有者（組織名またはユーザー名）"
  type        = string
  default     = "kter"  # デフォルトの所有者名
}

# GitHubリポジトリ名
variable "github_repo_name" {
  description = "GitHubリポジトリ名"
  type        = string
  default     = "learning-google-cloud"  # デフォルトのリポジトリ名
}

# ビルドをトリガーするブランチのパターン
variable "github_branch_pattern" {
  description = "ビルドをトリガーするGitHubブランチのパターン（正規表現）"
  type        = string
  default     = "^main$"  # mainブランチのみをトリガー対象に設定
}

# Docker設定
# -----------------------------------------------------------------------------

# Dockerfileのパス（リポジトリルートからの相対パス）
variable "dockerfile_path" {
  description = "リポジトリルートからのDockerfileへの相対パス"
  type        = string
  default     = "bare-laravel-manual-assemble/Dockerfile.cloudrun"
}

# ビルドコンテキストのパス（リポジトリルートからの相対パス）
variable "build_context_path" {
  description = "ビルドコンテキストディレクトリへの相対パス"
  type        = string
  default     = "bare-laravel-manual-assemble"
}

# Cloud Run設定
# -----------------------------------------------------------------------------

# Cloud RunサービスのCPU割り当て
variable "cloud_run_cpu" {
  description = "Cloud RunサービスのCPU割り当て（例：1000m = 1CPU）"
  type        = string
  default     = "1000m"  # 1CPUをデフォルトに設定
  
  # バリデーション：CPUの形式をチェック
  validation {
    condition = can(regex("^[0-9]+m?$", var.cloud_run_cpu))
    error_message = "CPUは '1000m' または '2' のような有効な形式である必要があります。"
  }
}

# Cloud Runサービスのメモリ割り当て
variable "cloud_run_memory" {
  description = "Cloud Runサービスのメモリ割り当て（例：512Mi、2Gi）"
  type        = string
  default     = "512Mi"  # 512MBをデフォルトに設定
  
  # バリデーション：メモリの形式をチェック
  validation {
    condition = can(regex("^[0-9]+(Mi|Gi)$", var.cloud_run_memory))
    error_message = "メモリは '512Mi' または '2Gi' のような形式である必要があります。"
  }
}

# Cloud Runの最大インスタンス数
variable "cloud_run_max_instances" {
  description = "Cloud Runサービスの最大インスタンス数（自動スケーリングの上限）"
  type        = number
  default     = 10  # 最大10インスタンスをデフォルトに設定
  
  # バリデーション：インスタンス数の範囲をチェック
  validation {
    condition     = var.cloud_run_max_instances > 0 && var.cloud_run_max_instances <= 1000
    error_message = "最大インスタンス数は1から1000の間である必要があります。"
  }
}

# Cloud Runの最小インスタンス数
variable "cloud_run_min_instances" {
  description = "Cloud Runサービスの最小インスタンス数（常時起動するインスタンス数）"
  type        = number
  default     = 0  # 0（使用時のみ起動）をデフォルトに設定
  
  # バリデーション：インスタンス数の範囲をチェック
  validation {
    condition     = var.cloud_run_min_instances >= 0 && var.cloud_run_min_instances <= 1000
    error_message = "最小インスタンス数は0から1000の間である必要があります。"
  }
}

# セキュリティ設定
# -----------------------------------------------------------------------------

# LaravelのAPP_KEY（暗号化に使用される秘密鍵）
variable "app_key" {
  description = "Laravel暗号化用のアプリケーションキー（Secret Managerに保存されます）"
  type        = string
  sensitive   = true  # 機密情報としてマークし、ログに出力されないようにする
  
  # バリデーション：APP_KEYが空でないことをチェック
  validation {
    condition     = length(var.app_key) > 0
    error_message = "APP_KEYは空にできません。"
  }
}

# SSL設定
# -----------------------------------------------------------------------------

# カスタムドメイン名（オプション）
variable "domain_name" {
  description = "ロードバランサー用のカスタムドメイン名（オプション、空の場合はIPアドレスを使用）"
  type        = string
  default     = ""  # デフォルトは空（IPアドレスを使用）
}

# SSL証明書の有効化フラグ
variable "enable_ssl" {
  description = "ロードバランサーでSSL証明書を有効化するか（true/false）"
  type        = bool
  default     = false  # デフォルトはHTTP（SSL無し）
}

# リソースタグ設定
# -----------------------------------------------------------------------------

# 全リソースに適用するラベル（タグ）
variable "labels" {
  description = "全リソースに適用するラベルのマップ（コスト管理や組織化に使用）"
  type        = map(string)  # 文字列のキー・バリューペア
  default     = {}  # デフォルトは空のマップ
  
  # バリデーション：ラベルキーの命名規則をチェック
  validation {
    condition = alltrue([
      for k, v in var.labels : can(regex("^[a-z][a-z0-9_-]*[a-z0-9]$", k))
    ])
    error_message = "ラベルキーは小文字で始まり、小文字・数字・アンダースコア・ハイフンのみを含み、小文字または数字で終わる必要があります。"
  }
}