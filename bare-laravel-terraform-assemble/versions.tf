# =============================================================================
# versions.tf - Terraformとプロバイダーのバージョン制約ファイル
# =============================================================================
# このファイルは、Terraformのバージョンと使用するプロバイダー（Google Cloud、ランダム値生成）の
# バージョンを指定します。これにより、異なる環境でも同じバージョンを使用できます。

terraform {
  # Terraformのバージョンを1.5以上に制限（新しい機能を使用するため）
  required_version = ">= 1.5"
  
  # 使用するプロバイダーとそのバージョンを指定
  required_providers {
    # Google Cloudプロバイダー（メインのGCPリソース管理用）
    google = {
      source  = "hashicorp/google"  # プロバイダーの提供元
      version = "~> 5.8"            # バージョン5.8系の最新を使用（5.9未満）
    }
    
    # Google Cloud Betaプロバイダー（Beta機能を使用する場合）
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.8"
    }
    
    # ランダム値生成プロバイダー（ユニークな名前生成などに使用）
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"            # バージョン3.4系の最新を使用
    }
  }
}