# TerraformでGoogle CloudにLaravelアプリをデプロイする

このプロジェクトは、TerraformとGoogle Cloud Platform（GCP）を使用してLaravelアプリケーションを自動デプロイするためのインフラストラクチャコードです。初心者でも理解しやすいように詳細なコメントと手順を用意しています。

## 📋 目次

- [システム構成](#システム構成)
- [前提条件](#前提条件)
- [事前準備](#事前準備)
- [設定手順](#設定手順)
- [Google Cloudへの反映手順](#google-cloudへの反映手順)
- [ファイル構成説明](#ファイル構成説明)
- [トラブルシューティング](#トラブルシューティング)
- [コスト管理](#コスト管理)
- [セキュリティ設定](#セキュリティ設定)

## 🏗️ システム構成

このTerraformコードで構築されるインフラストラクチャは以下の通りです：

```
GitHub Repository
       ↓ (push to main)
   Cloud Build Trigger
       ↓ (build & deploy)
   Artifact Registry ← Docker Image
       ↓
   Cloud Run Service ← Secret Manager (APP_KEY)
       ↓
   Load Balancer ← Static IP
       ↓
   ユーザーアクセス
```

### 主要コンポーネント

- **Cloud Build**: GitHubからのpushを検知してDockerイメージを自動ビルド
- **Artifact Registry**: Dockerイメージの保存・管理
- **Cloud Run**: サーバーレスでLaravelアプリを実行
- **Cloud Load Balancer**: グローバル負荷分散とHTTPS終端
- **Secret Manager**: APP_KEYなどの機密情報を安全に管理
- **IAM**: 最小権限の原則に基づくセキュリティ設定

## 📋 前提条件

### 必要なツール

1. **Google Cloudアカウント** - [登録はこちら](https://cloud.google.com/)
2. **Terraform** (v1.5以上) - [インストールガイド](https://developer.hashicorp.com/terraform/downloads)
3. **Google Cloud SDK** - [インストールガイド](https://cloud.google.com/sdk/docs/install)
4. **Git** - [インストールガイド](https://git-scm.com/downloads)

### 知識レベル

- 基本的なLinuxコマンドの操作
- Google Cloud Platform の基本概念
- Dockerの基本的な理解（推奨）

## 🚀 事前準備

### 1. Google Cloudプロジェクトの作成

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 「プロジェクトを作成」をクリック
3. プロジェクト名を「Playground2」に設定（または任意の名前）
4. プロジェクトIDをメモしておく（例：playground2-123456）

### 2. Google Cloud SDK の認証設定

```bash
# Google Cloud SDKにログイン
gcloud auth login

# アプリケーションデフォルト認証を設定
gcloud auth application-default login

# デフォルトプロジェクトを設定
gcloud config set project YOUR_PROJECT_ID
```

### 3. Laravel APP_KEY の生成

#### 方法1: Laravelプロジェクトがある場合
```bash
cd your-laravel-project
php artisan key:generate --show
```

#### 方法2: オンラインツールを使用
「Laravel Key Generator」で検索して、オンラインツールで生成してください。

#### 方法3: 手動生成（Linux/Mac）
```bash
# 32文字のランダム文字列を生成
echo "base64:$(openssl rand -base64 32)"
```

## ⚙️ 設定手順

### 1. プロジェクトのクローンまたはダウンロード

```bash
# このディレクトリに移動
cd bare-laravel-terraform-assemble
```

### 2. 設定ファイルの作成

```bash
# サンプル設定ファイルをコピー
cp terraform.tfvars.example terraform.tfvars
```

### 3. terraform.tfvars の編集

`terraform.tfvars` ファイルを開いて、以下の値を実際の環境に合わせて変更してください：

```hcl
# 必須設定（必ず変更してください）
project_id = "your-actual-project-id"     # あなたのGoogle CloudプロジェクトID
app_key    = "base64:YOUR_GENERATED_KEY"  # 生成したLaravel APP_KEY

# オプション設定（必要に応じて変更）
region        = "asia-northeast1"         # デプロイするリージョン
environment   = "dev"                     # 環境名
app_name      = "laravel-app"             # アプリ名

# リソースサイズ（アクセス量に応じて調整）
cloud_run_cpu           = "1000m"        # CPU: 1000m = 1CPU
cloud_run_memory        = "512Mi"        # メモリ: 512Mi = 512MB
cloud_run_max_instances = 10             # 最大インスタンス数
```

## 🌐 Google Cloudへの反映手順

### Step 1: Terraformの初期化

```bash
# Terraformプラグインのダウンロードと初期化
terraform init
```

**実行結果例:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/google versions matching "~> 5.8"...
- Installing hashicorp/google v5.8.0...
Terraform has been successfully initialized!
```

### Step 2: 実行計画の確認

```bash
# 作成されるリソースを事前確認（実際には何も作成されません）
terraform plan
```

**確認ポイント:**
- 緑色の `+` マークが表示されるリソースが作成される
- 赤色の `-` マークがあれば削除される（初回は表示されません）
- `Plan: X to add, 0 to change, 0 to destroy` と表示される

### Step 3: インフラストラクチャの作成

```bash
# 実際にGoogle Cloudにリソースを作成
terraform apply
```

**重要:** 実行前に表示される内容を確認し、`yes` と入力してください。

**作成時間:** 約5-10分程度かかります。

### Step 4: デプロイ結果の確認

作成が完了すると、以下のような出力が表示されます：

```
Outputs:

load_balancer_url = "http://123.456.789.012"
cloud_run_service_url = "https://laravel-app-dev-abcdef-an.a.run.app"
artifact_registry_repository_url = "asia-northeast1-docker.pkg.dev/playground2/laravel-app-repo"
```

### Step 5: GitHubトリガーの設定確認

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. **Cloud Build > トリガー** に移動
3. 作成されたトリガーを確認
4. 必要に応じてGitHub連携の設定を完了

## 📁 ファイル構成説明

### 核となるファイル

| ファイル名 | 説明 | 役割 |
|-----------|------|------|
| `versions.tf` | バージョン制約 | Terraformとプロバイダーのバージョンを固定 |
| `variables.tf` | 変数定義 | カスタマイズ可能な設定値を定義 |
| `main.tf` | メインリソース | 実際のGCPリソースを定義 |
| `outputs.tf` | 出力値 | デプロイ後に表示される重要な情報 |
| `terraform.tfvars` | 設定値 | 実際の設定値（作成が必要） |

### 設定ファイル

| ファイル名 | 説明 | 用途 |
|-----------|------|------|
| `terraform.tfvars.example` | 設定例 | terraform.tfvars作成時の参考 |
| `README.md` | 説明書 | このファイル |

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. API有効化エラー
**エラー:** `Error: Error when reading or editing Project Service`

**解決方法:**
```bash
# 手動でAPIを有効化
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

#### 2. プロジェクトIDエラー
**エラー:** `Error: google: could not find default credentials`

**解決方法:**
```bash
# 認証を再実行
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

#### 3. GitHubトリガーが動作しない
**確認ポイント:**
- Cloud Build APIが有効になっているか
- GitHub App連携が設定されているか
- リポジトリのブランチ名が正しいか

**解決方法:**
1. Cloud Console > Cloud Build > トリガー で設定確認
2. GitHub連携を再設定

#### 4. Cloud Runサービスが起動しない
**確認ポイント:**
- Dockerイメージが正常にビルドされているか
- APP_KEYが正しく設定されているか
- ポート8080をリッスンしているか

**デバッグ方法:**
```bash
# Cloud Runログを確認
gcloud logging read \"resource.type=cloud_run_revision\" --limit 50
```

### 緊急時のリソース削除

問題が解決できない場合は、一度全てのリソースを削除してやり直すことができます：

```bash
# 全リソースを削除（注意：元に戻せません）
terraform destroy
```

## 💰 コスト管理

### 概算コスト（月額）

#### 開発環境（軽負荷）
- **Cloud Run**: $0-5（使用量に応じて）
- **Load Balancer**: $18-25
- **Artifact Registry**: $0.10-1
- **Secret Manager**: $0.06-0.1
- **Cloud Build**: $0-3（ビルド回数に応じて）

**合計**: 約$20-35/月

#### 本番環境（高負荷）
- **Cloud Run**: $20-100（トラフィックに応じて）
- **Load Balancer**: $18-50
- その他は同様

**合計**: 約$40-200/月

### コスト削減のコツ

1. **最小インスタンス数を0に設定**: `cloud_run_min_instances = 0`
2. **リソースサイズの最適化**: 必要最小限のCPU/メモリに設定
3. **不要なリソースの削除**: 使わなくなったら `terraform destroy`

## 🔐 セキュリティ設定

### 設定済みのセキュリティ機能

1. **IAM最小権限**: 各サービスに必要最小限の権限のみを付与
2. **Secret Manager**: 機密情報の暗号化保存
3. **HTTPS**: Load Balancer経由でHTTPS通信
4. **サービスアカウント**: 専用のサービスアカウントで権限分離

### セキュリティのベストプラクティス

1. **terraform.tfvarsをGitにコミットしない**
   ```bash
   # .gitignoreに追加
   echo "terraform.tfvars" >> .gitignore
   ```

2. **定期的なAPP_KEYローテーション**
   - 新しいAPP_KEYを生成
   - terraform.tfvarsを更新
   - `terraform apply`で反映

3. **アクセスログの監視**
   - Cloud Loggingでアクセス状況を確認
   - 異常なアクセスパターンをチェック

## 🎯 次のステップ

### 機能拡張

1. **カスタムドメインの設定**
   ```hcl
   domain_name = "your-domain.com"
   enable_ssl  = true
   ```

2. **データベースの追加**
   - Cloud SQL PostgreSQL/MySQL
   - VPC設定
   - データベース接続設定

3. **キャッシュの追加**
   - Cloud Memorystore (Redis)
   - セッション管理

### 運用改善

1. **監視設定**
   - Cloud Monitoring
   - アラート設定
   - ダッシュボード作成

2. **バックアップ設定**
   - データベースバックアップ
   - 設定ファイルバックアップ

3. **複数環境対応**
   - 開発・ステージング・本番環境の分離
   - 環境ごとの設定管理

## 📞 サポート

### 公式リソース

- [Google Cloud Documentation](https://cloud.google.com/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest)
- [Laravel Documentation](https://laravel.com/docs)

### コミュニティ

- [Google Cloud Community](https://www.googlecloudcommunity.com/)
- [Terraform Community](https://discuss.hashicorp.com/c/terraform-core)
- [Laravel Community](https://laravel.io/)

---

このTerraformコードを使用して、Google Cloud上でLaravelアプリケーションを効率的にデプロイ・運用できます。質問や問題がある場合は、上記のトラブルシューティングセクションを参照してください。