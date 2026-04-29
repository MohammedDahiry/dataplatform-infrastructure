#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-terraform/environments/dev}"

: "${TF_STATE_BUCKET:?Set TF_STATE_BUCKET (e.g. dataplatform-tfstate-pfe)}"
: "${CF_ACCOUNT_ID:?Set CF_ACCOUNT_ID}"
: "${CF_R2_ACCESS_KEY_ID:?Set CF_R2_ACCESS_KEY_ID}"
: "${CF_R2_SECRET_ACCESS_KEY:?Set CF_R2_SECRET_ACCESS_KEY}"

echo "Running terraform init in ${TARGET_DIR}"
terraform -chdir="${TARGET_DIR}" init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=terraform/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true" \
  -backend-config="access_key=${CF_R2_ACCESS_KEY_ID}" \
  -backend-config="secret_key=${CF_R2_SECRET_ACCESS_KEY}" \
  -backend-config="endpoints={s3=\"https://${CF_ACCOUNT_ID}.r2.cloudflarestorage.com\"}" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_region_validation=true" \
  -backend-config="skip_metadata_api_check=true" \
  -backend-config="skip_requesting_account_id=true" \
  -backend-config="skip_s3_checksum=true"
