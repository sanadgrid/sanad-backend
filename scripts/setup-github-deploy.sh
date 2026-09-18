#!/usr/bin/env bash
# إعداد لمرة واحدة: يسمح لـ GitHub Actions في ريبو sanad-backend بالنشر على Firebase
# بدون مفاتيح JSON (Workload Identity Federation).
# يُشغَّل في Google Cloud Shell: https://shell.cloud.google.com/?project=sanadgrid-5176a
set -euo pipefail

PROJECT_ID="sanadgrid-5176a"
REPO="sanadgrid/sanad-backend"
POOL="github"
PROVIDER="sanad-backend"
SA_NAME="github-deployer"
SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

echo "==> تفعيل الـ APIs"
gcloud services enable \
  iamcredentials.googleapis.com sts.googleapis.com \
  firebaserules.googleapis.com firestore.googleapis.com \
  --project "$PROJECT_ID"

echo "==> حساب الخدمة"
gcloud iam service-accounts describe "$SA" --project "$PROJECT_ID" >/dev/null 2>&1 ||
  gcloud iam service-accounts create "$SA_NAME" --project "$PROJECT_ID" \
    --display-name "GitHub Actions deployer"

echo "==> صلاحيات النشر (قواعد وفهارس Firestore فقط)"
for ROLE in roles/firebaserules.admin roles/datastore.indexAdmin roles/serviceusage.serviceUsageViewer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:${SA}" --role "$ROLE" --condition=None >/dev/null
done

echo "==> Workload Identity Pool"
gcloud iam workload-identity-pools describe "$POOL" --project "$PROJECT_ID" --location global >/dev/null 2>&1 ||
  gcloud iam workload-identity-pools create "$POOL" --project "$PROJECT_ID" --location global \
    --display-name "GitHub"

echo "==> Provider (مقيّد بالريبو ${REPO} فقط)"
gcloud iam workload-identity-pools providers describe "$PROVIDER" \
  --project "$PROJECT_ID" --location global --workload-identity-pool "$POOL" >/dev/null 2>&1 ||
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
    --project "$PROJECT_ID" --location global --workload-identity-pool "$POOL" \
    --issuer-uri "https://token.actions.githubusercontent.com" \
    --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition "assertion.repository == '${REPO}'"

echo "==> السماح للريبو بانتحال حساب الخدمة"
gcloud iam service-accounts add-iam-policy-binding "$SA" --project "$PROJECT_ID" \
  --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${REPO}" >/dev/null

echo
echo "تم ✓  القيم المستخدمة في .github/workflows/deploy.yml:"
echo "  WORKLOAD_IDENTITY_PROVIDER: projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}"
echo "  SERVICE_ACCOUNT:            ${SA}"
