# Todo POC Terraform Infrastructure

## ディレクトリ構造

```
terraform/
├── modules/                          # 再利用可能なモジュール
│   ├── service-account/              # サービスアカウント作成モジュール
│   ├── workload-identity/            # Workload Identity設定モジュール
│   └── cloud-run/                   # Cloud Runサービス定義モジュール（統一）
├── shared/                           # 環境共通リソース
│   ├── ci-cd-account/               # CI/CD用アカウント（外部リポジトリのビルド・プッシュ用）
│   ├── artifact-registry/           # Artifact Registry（全環境共通）
│   └── deployment-account/          # デプロイ用アカウント（GitHub Actionsデプロイ用）
└── environments/                     # 環境別設定
    ├── production/                   # 本番環境
    │   ├── runtime-account/          # 本番環境用ランタイムアカウント
    │   └── cloud-run-deploy/        # 本番環境用Cloud Runデプロイ設定
    └── staging/                      # ステージング環境
        ├── runtime-account/          # ステージング環境用ランタイムアカウント
    └── cloud-run-deploy/        # ステージング環境用Cloud Runデプロイ設定
```

### サービスカタログ

`terraform/service_catalog.json`

サービス構成についての設定を集約

各サービスには以下の情報をもつ：

- Artifact Registry で利用するイメージ名（1 リポジトリ内でサービス名ごとにパッケージ分割）
- CI/CD 用サービスアカウントと Workload Identity 設定（ビルドリポジトリ単位）
- 環境別のランタイムサービスアカウントと Cloud Run サービス名
- ロール/オプション

## デプロイ手順

### 1. 共通基盤の作成（deployment-account除く）

#### 1.1. CI/CDアカウント作成（外部リポジトリのビルド・プッシュ用）
```bash
cd terraform/shared/ci-cd-account
terraform init
terraform plan
terraform apply
```

出力:
- `service_accounts`: サービスIDごとにCI/CD用サービスアカウントの`email` / `name` / `id`を返すマップ

    各実装リポジトリに`service_accounts["task-api"].email`を設定
- `workload_identity_providers`: サービスIDごとにWorkload Identity Provider情報（`name` / `pool_name` / `provider_id` / `workload_identity_pool_id`）を返すマップ
    
    GitHub ActionsのOIDCフェデレーション設定に利用し、Secretsには`workload_identity_providers["task-api"].name`を設定

#### 1.2. Artifact Registry作成（全環境共通）
```bash
cd ../artifact-registry
terraform init
terraform plan
terraform apply
```

**作成される `todo-poc-repo` には `roles/artifactregistry.reader` を `allUsers` に付与**

### 2. 各環境のランタイムアカウント作成

#### 2.1. Production環境ランタイムアカウント（deployment-accountの依存関係）
```bash
cd ../../environments/production/runtime-account
terraform init
terraform plan
terraform apply
```

#### 2.2. Staging環境ランタイムアカウント（deployment-accountの依存関係）
```bash
cd ../../staging/runtime-account
terraform init
terraform plan
terraform apply
```

### 3. デプロイ用アカウント作成

#### 3.1. デプロイ用アカウント作成（このリポジトリのGitHub Actionsデプロイ用）
```bash
cd ../../../shared/deployment-account
terraform init
terraform plan
terraform apply
```

出力:
- `deployment_service_account_email`: GitHub Secretsに設定（このリポジトリ用）
- `workload_identity_pool_provider`: GitHub Secretsに設定（このリポジトリ用）

### 4. Cloud Runデプロイメント

runtime-accountが作成済みであることが前提条件

#### 4.1. Production環境
```bash
cd terraform/environments/production/cloud-run-deploy
terraform init

cp config.example.json config.auto.tfvars.json

terraform plan -var-file="config.auto.tfvars.json"
terraform apply -var-file="config.auto.tfvars.json"
```

```bash
terraform plan \
  -var='service_config={
    "task-api" = { image_tag = "v1.2.3" }
    "id-api"   = { image_tag = "v0.3.0" }
  }'
```

#### 4.2. Staging環境
```bash
cd ../../staging/cloud-run-deploy
terraform init
cp config.example.json config.auto.tfvars.json
terraform plan -var-file="config.auto.tfvars.json"
terraform apply -var-file="config.auto.tfvars.json"
```

### 5. 新環境の追加手順

新しい環境を追加する場合は、サービスカタログと shared/deployment-account の環境リストを更新

1. `terraform/service_catalog.json` に新しい環境 (`runtime.service_accounts.<env>`, `deploy.cloud_run.<env>`) を追記
2. `terraform/environments/development/` のように新しいディレクトリを作成し、`staging/` の設定をコピーした上で `variables.tf` の `environment` デフォルト値を更新
3. 新環境の runtime アカウントをデプロイ：
   ```bash
   cd terraform/environments/development/runtime-account
   terraform init
   terraform plan
   terraform apply
   ```
4. `terraform/shared/deployment-account/variables.tf` の `environments` に新しい環境名を追加して `terraform apply`
    これでデプロイ SA の `service_account_impersonation_targets` が自動的に拡張
5. **新環境の cloud-run-deploy を実行：**
   ```bash
   cd ../cloud-run-deploy
   terraform init
   cp config.example.json config.auto.tfvars.json
   terraform plan -var-file="config.auto.tfvars.json"
   terraform apply -var-file="config.auto.tfvars.json"
   ```

## GitHub Actions設定

アウトプットは
```bash
terraform output -json
```
で取得

### デプロイ用GitHub Secrets（このリポジトリ用）

デプロイ用アカウント作成後、以下をGitHub Secretsに設定：

- `DEPLOYMENT_WORKLOAD_IDENTITY_PROVIDER`: Terraformアウトプットから取得
- `DEPLOYMENT_SERVICE_ACCOUNT_EMAIL`: Terraformアウトプットから取得
- `GCP_PROJECT_ID`: プロジェクトID
- `GCP_LOCATION`: ロケーション
- `AWS_ACCESS_KEY_ID`: Terraformバックエンド用（Cloudflare R2アクセスキー）
- `AWS_SECRET_ACCESS_KEY`: Terraformバックエンド用（Cloudflare R2シークレットキー）
- `AWS_S3_ENDPOINT`: Terraformバックエンド用（Cloudflare R2エンドポイント）
- `CLOUDFLARE_API_TOKEN`: Cloudflare provider用APIトークン

### CI/CD用GitHub Secrets（外部リポジトリ用）

- `GOOGLE_IAM_WORKLOAD_IDENTITY_POOL_PROVIDER`: `terraform output -json workload_identity_providers` の `<service>.name`
- `SERVICE_ACCOUNT_EMAIL`: `terraform output -json service_accounts` の `<service>.email`
- `GCP_PROJECT_ID`: プロジェクトID
- `GCP_ARTIFACT_REPO_ID`: `todo-poc-repo`

例（`task-api` の場合）

```bash
terraform output -json workload_identity_providers | jq -r '."task-api".name'
terraform output -json service_accounts | jq -r '."task-api".email'
```

## デプロイ方法

### Option 1: GitHub Actions

"Deploy to Cloud Run" workflowの実行

### Option 2: 手動デプロイ

```bash
# 本番環境デプロイ
cd terraform/environments/production/cloud-run-deploy
terraform apply -var-file="service_config.auto.tfvars.json"

# ステージング環境デプロイ
cd ../../staging/cloud-run-deploy  
terraform apply -var-file="service_config.auto.tfvars.json"
```

## サービスアカウントアーキテクチャ

### 1. CI/CDサービスアカウント（サービス別）
- `todo-poc-task-api-ci`: `KasumiMercury/todo-server-poc-go` 向け
    Artifact Registry への push 権限
- `todo-poc-id-api-ci`: `usbharu/todo-user` 向け
    Artifact Registry への push 権限
- 作成箇所: `terraform/shared/ci-cd-account/`（サービスカタログから自動生成）

### 2. デプロイサービスアカウント (`todo-poc-deployment`)
- 用途: このインフラストラクチャリポジトリからのCloud Runデプロイ操作
- 使用場所: このリポジトリの"Deploy to Cloud Run"ワークフロー
- 作成箇所: `terraform/shared/deployment-account/`

### 3. ランタイムサービスアカウント（サービス × 環境）
- 例: `todo-poc-task-api-runtime`（Task API 本番）、`todo-poc-id-api-runtime`（ID API 本番）など
- 用途: Cloud Run サービスの実行時認証と GCP リソースアクセス
- 作成箇所: `terraform/environments/{env}/runtime-account/`

### 環境固有設定オプション

```bash
terraform apply \
  -var='service_config={
    "task-api" = {
      image_tag             = "v1.2.3"
      environment_variables = { DEBUG = true, LOG_LEVEL = "info" }
    }
    "id-api" = {
      image_tag                  = "v0.3.0"
      allow_unauthenticated_access = false
      deletion_protection           = true
    }
  }'
```
