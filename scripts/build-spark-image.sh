#!/usr/bin/env bash
# Build the spark-iceberg image and push it to ECR.
#
# Usage:
#   ./scripts/build-spark-image.sh                  # auto-detect ECR registry from terraform output
#   REGISTRY=123.dkr.ecr.us-east-1.amazonaws.com ./scripts/build-spark-image.sh
#   TAG=3.5.0-rc1 ./scripts/build-spark-image.sh
#   SKIP_BUILD=1 ./scripts/build-spark-image.sh     # only ECR login + push (image already built)
#   DOCKER_PUSH_RETRIES=5   # default 4; large images often need retries on flaky networks
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="${ROOT_DIR}/docker/spark-iceberg"
DEV_DIR="${ROOT_DIR}/terraform/environments/dev"

REPO_NAME="${REPO_NAME:-spark-iceberg}"
TAG="${TAG:-3.5.0}"
NAME_PREFIX="${NAME_PREFIX:-dataplatform}"
AWS_REGION="${AWS_REGION:-us-east-1}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}
require_cmd docker
require_cmd aws

if [[ -z "${REGISTRY:-}" ]]; then
  if command -v terraform >/dev/null 2>&1 && [[ -d "${DEV_DIR}/.terraform" ]]; then
    REGISTRY="$(terraform -chdir="${DEV_DIR}" output -raw ecr_registry_url 2>/dev/null || true)"
  fi
fi

if [[ -z "${REGISTRY:-}" ]]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
fi

REPO_PATH="${NAME_PREFIX}/${REPO_NAME}"
FULL_IMAGE="${REGISTRY}/${REPO_PATH}:${TAG}"

echo "==> ECR registry: ${REGISTRY}"
echo "==> Repo path:    ${REPO_PATH}"
echo "==> Image tag:    ${TAG}"
echo "==> Full image:   ${FULL_IMAGE}"

echo "==> Logging in to ECR (${AWS_REGION})..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  echo "==> Building image (this can take 5-15 min on first build)..."
  docker build \
    --tag "${FULL_IMAGE}" \
    --tag "${REPO_PATH}:${TAG}" \
    "${DOCKER_DIR}"
else
  echo "==> SKIP_BUILD=1 — skipping docker build, pushing existing tag ${FULL_IMAGE}"
fi

PUSH_RETRIES="${DOCKER_PUSH_RETRIES:-4}"
echo "==> Pushing ${FULL_IMAGE} (up to ${PUSH_RETRIES} attempts; large layers may need retries)..."
attempt=1
while [[ "${attempt}" -le "${PUSH_RETRIES}" ]]; do
  if docker push "${FULL_IMAGE}"; then
    break
  fi
  if [[ "${attempt}" -ge "${PUSH_RETRIES}" ]]; then
    echo "Push failed after ${PUSH_RETRIES} attempts. Retry manually:  aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}  &&  docker push ${FULL_IMAGE}" >&2
    echo "Tip: unstable Wi‑Fi / corporate proxy can cause 'broken pipe'; try wired network or add ECR to NO_PROXY if you use HTTP_PROXY." >&2
    exit 1
  fi
  wait_sec=$((attempt * 5))
  echo "   push failed (attempt ${attempt}/${PUSH_RETRIES}), retrying in ${wait_sec}s..."
  sleep "${wait_sec}"
  attempt=$((attempt + 1))
  aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login --username AWS --password-stdin "${REGISTRY}"
done

echo "==> Done. Use this image in SparkApplication CRDs:"
echo "    image: ${FULL_IMAGE}"
echo
echo "Tip: render the SparkApplication manifests automatically via"
echo "    SPARK_IMAGE=${FULL_IMAGE} ./scripts/bootstrap-phase4.sh"
