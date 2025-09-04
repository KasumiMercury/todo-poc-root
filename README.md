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
│   └── deployment-account/          # [NEW] デプロイ用アカウント（GitHub Actionsデプロイ用）
└── environments/                     # 環境別設定
    ├── production/                   # 本番環境
    │   ├── runtime-account/          # 本番環境用ランタイムアカウント
    │   └── cloud-run-deploy/        # 本番環境用Cloud Runデプロイ設定
    └── staging/                      # ステージング環境
        ├── runtime-account/          # ステージング環境用ランタイムアカウント
        └── cloud-run-deploy/        # ステージング環境用Cloud Runデプロイ設定
```

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
- `service_account_github_actions_email`: GitHub Secretsに設定（実装リポジトリ用）
- `google_iam_workload_identity_pool_provider_github_name`: GitHub Secretsに設定（実装リポジトリ用）

#### 1.2. Artifact Registry作成（全環境共通）
```bash
cd ../artifact-registry
terraform init
terraform plan
terraform apply
```

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
terraform plan -var="image_tag=v1.2.3"
terraform apply
```

#### 4.2. Staging環境
```bash
cd ../../staging/cloud-run-deploy
terraform init
terraform plan -var="image_tag=v1.2.3-rc.1"
terraform apply
```

### 5. 新環境の追加手順

新しい環境を追加する際はdeployment-accountの更新が必要

新しい環境（例：development）を追加する場合：
1. `environments/development/` ディレクトリを作成
2. `staging/` の設定をコピーして環境名を調整
3. 新環境のruntime-accountを作成：
   ```bash
   cd terraform/environments/development/runtime-account
   terraform init
   terraform plan
   terraform apply
   ```
4. deployment-accountを更新して新環境のサービスアカウントを追加：
   - `terraform/shared/deployment-account/main.tf` の `service_account_impersonation_targets` に新しいサービスアカウントを追加
   - `terraform apply` を実行
5. **新環境のcloud-run-deployを作成：**
   ```bash
   cd ../cloud-run-deploy
   terraform init
   terraform plan -var="image_tag=version"
   terraform apply
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

CI/CDアカウント作成後、外部リポジトリで以下をGitHub Secretsに設定：

- `GOOGLE_IAM_WORKLOAD_IDENTITY_POOL_PROVIDER`: 
  `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-ci-cd/providers/github-provider`
- `SERVICE_ACCOUNT_EMAIL`: 
  `todo-poc-ci-cd@PROJECT_ID.iam.gserviceaccount.com`
- `GCP_PROJECT_ID`: プロジェクトID
- `GCP_ARTIFACT_REPO_ID`: `todo-poc-repo`

## デプロイ方法

### Option 1: GitHub Actions

"Deploy to Cloud Run" workflowの実行

### Option 2: 手動デプロイ

```bash
# 本番環境デプロイ（サービス名: todo-poc-cloud-run-prod）
cd terraform/environments/production/cloud-run-deploy
terraform apply -var="image_tag=v1.2.3"

# ステージング環境デプロイ（サービス名: todo-poc-cloud-run-staging）
cd ../../staging/cloud-run-deploy  
terraform apply -var="image_tag=v1.2.3-rc.1"
```

## サービスアカウントアーキテクチャ

### 1. CI/CDサービスアカウント (`todo-poc-ci-cd`)
- 用途: 外部リポジトリからのDockerコンテナビルド・プッシュ操作
- 使用場所: 別の実装リポジトリのGitHub Actions
- 作成箇所: `terraform/shared/ci-cd-account/`

### 2. デプロイサービスアカウント (`todo-poc-deployment`)
- 用途: このインフラストラクチャリポジトリからのCloud Runデプロイ操作
- 使用場所: このリポジトリの"Deploy to Cloud Run"ワークフロー
- 作成箇所: `terraform/shared/deployment-account/`

### 3. ランタイムサービスアカウント（環境固有）
- 用途: Cloud Runサービスの実行時認証とGCPリソースアクセス
- 使用場所: デプロイされたCloud Runサービスのランタイム操作に割り当て
- 作成箇所: `terraform/environments/{env}/runtime-account/`

### 環境固有設定オプション

```bash
terraform apply \
  -var="image_tag=v1.2.3" \
  -var="environment_variables={DEBUG=true,LOG_LEVEL=info}" \
  -var="allow_unauthenticated_access=false" \
  -var="deletion_protection=true"
```
