# Laravel on Google Cloud Run

LaravelアプリケーションをGoogle Cloud Runで動作させるためのDockerコンテナ構成プロジェクトです。

## プロジェクト概要

このプロジェクトは、Laravel PHPフレームワークをGoogle Cloud Platform上で効率的に動作させるための構成を提供します。ローカル開発環境（Docker Compose）と本番環境（Cloud Run）の両方に対応しています。

### 主な特徴
- PHP 8.2 + Laravel最新版
- Nginx Webサーバー
- Cloud Runでの自動スケーリング対応
- Cloud Buildによる自動デプロイ

## ディレクトリ構造

```
.
├── app/                    # Laravelアプリケーションコード
├── public/                 # 公開ディレクトリ（index.php等）
├── docker/                 # Docker関連設定ファイル
│   ├── supervisord.conf    # Supervisordプロセス管理設定
│   └── start.sh           # コンテナ起動スクリプト
├── nginx/                  # Nginx設定ファイル
│   ├── default.conf       # ローカル開発用Nginx設定
│   ├── cloudrun.conf      # Cloud Run用Nginx設定（ポート8080）
│   └── Dockerfile         # Nginx専用Dockerfile（未使用）
├── Dockerfile             # PHP-FPM用Dockerfile（ローカル開発用）
├── Dockerfile.cloudrun    # Cloud Run用統合Dockerfile
├── docker-compose.yml     # ローカル開発環境構成
├── cloudbuild.yaml        # Cloud Build設定ファイル
└── .gcloudignore         # Cloud Buildで除外するファイル

```

## ファイル説明

### Docker関連

#### `Dockerfile`
ローカル開発用のPHP-FPMコンテナ定義。PHP 8.2-fpmベースで、必要なPHP拡張機能とComposerをインストール。

#### `Dockerfile.cloudrun`
Cloud Run用の統合コンテナ定義。NginxとPHP-FPMを単一コンテナで動作させるための設定。
- Supervisordまたはシェルスクリプトでプロセス管理
- ポート8080でリッスン（Cloud Run要件）
- 本番用の最適化設定

#### `docker-compose.yml`
ローカル開発環境の構成:
- `php`: PHP-FPMサービス
- `nginx`: Nginxサービス（ポート80）
- 両サービスは`laravel-network`で通信

### Nginx設定

#### `nginx/default.conf`
ローカル開発用設定:
- ポート80でリッスン
- PHP-FPMとはサービス名`php:9000`で通信
- Laravel用のURLリライト設定

#### `nginx/cloudrun.conf`
Cloud Run用設定:
- ポート8080でリッスン（Cloud Run要件）
- PHP-FPMとは`127.0.0.1:9000`で通信（同一コンテナ内）
- ヘルスチェックエンドポイント`/health`を提供

### プロセス管理

#### `docker/supervisord.conf`
Supervisordによるプロセス管理設定:
- PHP-FPMとNginxを同時起動
- 自動再起動設定
- ログをstdout/stderrに出力

#### `docker/start.sh`
シンプルな起動スクリプト（Supervisordの代替）:
- PHP-FPMをバックグラウンドで起動
- Nginxをフォアグラウンドで起動

### Cloud Build/Deploy

#### `cloudbuild.yaml`
Cloud Buildの自動ビルド・デプロイ設定:
1. Dockerイメージのビルド
2. Container Registryへのプッシュ
3. Cloud Runへの自動デプロイ
   - リージョン: asia-northeast1
   - メモリ: 1Gi
   - CPU: 2
   - 自動スケーリング: 0-10インスタンス

#### `.gcloudignore`
Cloud Buildで除外するファイル:
- vendor/（composer依存関係）
- node_modules/
- .env（環境変数）
- ローカル開発用ファイル

## 使用方法

### ローカル開発環境

```bash
# Laravelプロジェクトの初期化（初回のみ）
docker run --rm -v $(pwd):/app -w /app composer:latest create-project laravel/laravel .

# 開発環境の起動
docker compose up -d

# http://localhost でアクセス
```

### Cloud Runへのデプロイ

```bash
# プロジェクトIDの設定
export PROJECT_ID=your-project-id

# Cloud Buildを使用したデプロイ
gcloud builds submit --config cloudbuild.yaml

# または手動でビルド・デプロイ
docker build -t gcr.io/$PROJECT_ID/laravel-app -f Dockerfile.cloudrun .
docker push gcr.io/$PROJECT_ID/laravel-app
gcloud run deploy laravel-app \
  --image gcr.io/$PROJECT_ID/laravel-app \
  --region asia-northeast1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080
```

### Cloud Run用Dockerfileのローカルテスト

```bash
# Cloud Run用Dockerfileのビルド
docker build -t laravel-cloudrun -f Dockerfile.cloudrun .

# 環境変数を指定してコンテナを起動
docker run -d --name laravel-cloudrun -p 8080:8080 \
  -e APP_KEY=base64:$(openssl rand -base64 32) \
  -e APP_ENV=production \
  -e APP_DEBUG=false \
  laravel-cloudrun

# ヘルスチェックエンドポイントでテスト
curl http://localhost:8080/health

# Laravelアプリケーションにアクセス
curl http://localhost:8080

# ログの確認
docker logs laravel-cloudrun
```

## 環境変数

Cloud Runでは以下の環境変数を設定してください：

```bash
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:xxxxxx  # php artisan key:generate で生成
DB_CONNECTION=mysql
DB_HOST=your-db-host
DB_DATABASE=your-db-name
DB_USERNAME=your-db-user
DB_PASSWORD=your-db-password
LOG_CHANNEL=stderr
```

## 注意事項

1. **セキュリティ**: 本番環境では必ず`.env`ファイルを除外し、環境変数を適切に設定してください
2. **ストレージ**: Cloud Runはステートレスなので、ファイルアップロードはCloud Storageを使用してください
3. **セッション**: データベースまたはRedisベースのセッション管理を推奨
4. **ログ**: Cloud Loggingと統合するため、`LOG_CHANNEL=stderr`を設定

## 動作確認結果

### Cloud Run用Dockerfileのテスト結果

✅ **ビルド成功**: `Dockerfile.cloudrun`は正常にビルドされます  
✅ **コンテナ起動**: NginxとPHP-FPMは正常に起動します  
✅ **ヘルスチェック**: `/health`エンドポイントは200 OKを返します  
⚠️ **Laravelアプリ**: 環境変数（特にAPP_KEY）が未設定の場合500エラーが発生します

### 確認済み機能
- Nginx（ポート8080）とPHP-FPMの同一コンテナ内通信
- ヘルスチェックエンドポイント（`/health`）
- Laravel標準ルーティングとミドルウェア
- ログ出力（docker logsで確認可能）

## トラブルシューティング

### 500 Internal Server Errorが発生する場合
Laravel初回起動時に`APP_KEY`が設定されていないと500エラーが発生します：

```bash
# 環境変数を指定してコンテナを再起動
docker run -d --name laravel-cloudrun -p 8080:8080 \
  -e APP_KEY=base64:$(openssl rand -base64 32) \
  -e APP_ENV=production \
  -e APP_DEBUG=false \
  laravel-cloudrun

# または既存コンテナ内で設定
docker exec laravel-cloudrun sh -c "echo 'APP_KEY=base64:$(openssl rand -base64 32)' > .env"
docker exec laravel-cloudrun php artisan config:cache
```

### ポート関連のエラー
Cloud Runは`PORT`環境変数で指定されたポートでリッスンする必要があります。デフォルトは8080です。

### メモリ不足
Composerの依存関係インストール時にメモリ不足になる場合は、Cloud Buildのマシンタイプを変更してください。

### 権限エラー
`storage/`と`bootstrap/cache/`ディレクトリの書き込み権限を確認してください。

### Nginxとのプロキシエラー
PHP-FPMとの通信でエラーが発生する場合は、nginx設定ファイル（`nginx/cloudrun.conf`）の`fastcgi_pass`設定を確認してください。

## ライセンス

MIT License