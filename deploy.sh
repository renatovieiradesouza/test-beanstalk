#!/usr/bin/env bash
set -euo pipefail

# Config (override via env if needed)
ROOT_DIR="${ROOT_DIR:-/home/renato/projetos/pessoal/test-beanstalk}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:-737414041081}"
APP_NAME="${APP_NAME:-hello-app}"
ENV_NAME="${ENV_NAME:-hello-app-dev}"
CUSTOM_DOMAIN="${CUSTOM_DOMAIN:-girus.pipastudios.com}"

S3_BUCKET="elasticbeanstalk-${REGION}-${ACCOUNT_ID}"
TS="$(date +%Y%m%d-%H%M%S)"
LABEL="hello-ebpkg-${TS}"
TMP_DIR="/tmp/hello-war-build-${TS}"
ZIP_NAME="hello-war-ebpkg-${TS}.zip"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }

echo "Checking dependencies..."
need mvn
need zip
need aws
need curl
need tar

echo "Building WAR in clean temp dir: ${TMP_DIR}"
mkdir -p "${TMP_DIR}"
# Copy war project without target to avoid permission issues
tar -C "${ROOT_DIR}/war" --exclude=target -cf - . | tar -C "${TMP_DIR}" -xf -

(
  cd "${TMP_DIR}"
  mvn -DskipTests clean package
)

WAR_FILE="$(ls -1 "${TMP_DIR}/target/"*.war | head -n1)"
[ -f "${WAR_FILE}" ] || { echo "WAR not found in ${TMP_DIR}/target"; exit 1; }

echo "Replacing ebpkg/ROOT.war (configs left untouched)"
cp -f "${WAR_FILE}" "${ROOT_DIR}/ebpkg/ROOT.war"

echo "Zipping ebpkg to ${ZIP_NAME}"
(
  cd "${ROOT_DIR}/ebpkg"
  zip -qr "../${ZIP_NAME}" .
)

echo "Uploading ${ZIP_NAME} to s3://${S3_BUCKET}/${APP_NAME}/${ZIP_NAME}"
aws s3 cp "${ROOT_DIR}/${ZIP_NAME}" "s3://${S3_BUCKET}/${APP_NAME}/${ZIP_NAME}" --only-show-errors --region "${REGION}"

echo "Creating EB application version: ${LABEL}"
aws elasticbeanstalk create-application-version \
  --region "${REGION}" \
  --application-name "${APP_NAME}" \
  --version-label "${LABEL}" \
  --source-bundle "S3Bucket=${S3_BUCKET},S3Key=${APP_NAME}/${ZIP_NAME}" \
  --no-auto-create-application \
  --output table

echo "Updating environment ${ENV_NAME} -> ${LABEL}"
aws elasticbeanstalk update-environment \
  --region "${REGION}" \
  --environment-name "${ENV_NAME}" \
  --version-label "${LABEL}" \
  --output text

echo "Waiting for environment to settle..."
for i in {1..8}; do
  sleep 10
  aws elasticbeanstalk describe-environments \
    --region "${REGION}" \
    --environment-names "${ENV_NAME}" \
    --query 'Environments[0].{Status:Status,Health:Health,Version:VersionLabel}' \
    --output table || true
done

echo "Quick checks:"
echo -n "HTTP (${CUSTOM_DOMAIN}): "
curl -s -o /dev/null -w '%{http_code}\n' "http://${CUSTOM_DOMAIN}/" || true
echo -n "HTTPS (${CUSTOM_DOMAIN}): "
curl -k -s -o /dev/null -w '%{http_code}\n' "https://${CUSTOM_DOMAIN}/" || true

echo "Done. Version label: ${LABEL}"