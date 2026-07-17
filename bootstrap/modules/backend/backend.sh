#!/usr/bin/env bash
set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || error "Required command not found: '$1'. Please install it and try again."
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Create a GCS bucket for OpenTofu remote state (idempotent).

Options:
  -p <project_id>   GCP project ID          (default: current gcloud project)
  -b <bucket_name>  Bucket name             (default: <project_id>-tofu-state)
  -r <region>       Bucket region           (default: us-central1)
  -s <sa_email>     Service account email to grant access (optional)
  -h                Show this help message

Examples:
  $(basename "$0") -p my-project -r europe-west1
  $(basename "$0") -p my-project -b my-tfstate -s tofu@my-project.iam.gserviceaccount.com
USAGE
  exit 0
}

# ── Parse flags ───────────────────────────────────────────────────────────────
PROJECT_ID=""
BUCKET_NAME=""
REGION="europe-west4"
SA_EMAIL=""

while getopts ":p:b:r:s:h" opt; do
  case $opt in
    p) PROJECT_ID="$OPTARG" ;;
    b) BUCKET_NAME="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    s) SA_EMAIL="$OPTARG" ;;
    h) usage ;;
    :) error "Option -$OPTARG requires an argument." ;;
    \?) error "Unknown option: -$OPTARG" ;;
  esac
done

# ── Dependency checks ─────────────────────────────────────────────────────────
require_cmd gcloud
require_cmd python3

# ── Defaults ──────────────────────────────────────────────────────────────────
[[ -z "$PROJECT_ID" ]] && PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
[[ -z "$PROJECT_ID" ]] && error "Project ID is required. Use -p <project_id> or set a default gcloud project."
[[ -z "$BUCKET_NAME" ]] && BUCKET_NAME="${PROJECT_ID}-tofu-state"

info "Project : $PROJECT_ID"
info "Bucket  : gs://$BUCKET_NAME"
info "Region  : $REGION"
echo

# ── 1. Enable required APIs ───────────────────────────────────────────────────
for api in storage.googleapis.com iam.googleapis.com; do
  STATUS=$(gcloud services list --project="$PROJECT_ID" \
    --filter="name:$api" --format="value(state)" 2>/dev/null)
  if [[ "$STATUS" == "ENABLED" ]]; then
    warn "API already enabled: $api"
  else
    info "Enabling API: $api"
    gcloud services enable "$api" --project="$PROJECT_ID"
  fi
done

# ── 2. Create bucket ──────────────────────────────────────────────────────────
if gcloud storage buckets describe "gs://$BUCKET_NAME" \
     --project="$PROJECT_ID" &>/dev/null; then
  warn "Bucket already exists: gs://$BUCKET_NAME"
else
  info "Creating bucket: gs://$BUCKET_NAME"
  gcloud storage buckets create "gs://$BUCKET_NAME" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention
fi

# ── 3. Enable versioning ──────────────────────────────────────────────────────
VERSIONING=$(gcloud storage buckets describe "gs://$BUCKET_NAME" \
  --format="value(versioning.enabled)" 2>/dev/null || echo "")
if [[ "$VERSIONING" == "True" ]]; then
  warn "Versioning already enabled."
else
  info "Enabling versioning..."
  gcloud storage buckets update "gs://$BUCKET_NAME" --versioning
fi

# ── 4. Grant IAM roles ────────────────────────────────────────────────────────
grant_role_if_missing() {
  local member="$1" role="$2"

  EXISTS=$(gcloud storage buckets get-iam-policy "gs://$BUCKET_NAME" \
    --format=json 2>/dev/null \
    | python3 -c "
import sys, json
policy = json.load(sys.stdin)
for b in policy.get('bindings', []):
    if b['role'] == '$role' and '$member' in b.get('members', []):
        print('true')
        break
" 2>/dev/null || echo "")

  if [[ "$EXISTS" == "true" ]]; then
    warn "IAM binding already exists: $member → $role"
  else
    info "Granting $role to $member"
    gcloud storage buckets add-iam-policy-binding "gs://$BUCKET_NAME" \
      --member="$member" \
      --role="$role"
  fi
}

if [[ -n "$SA_EMAIL" ]]; then
  MEMBER="serviceAccount:$SA_EMAIL"
else
  warn "No service account specified (-s). Falling back to the active gcloud account."
  ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
  [[ -z "$ACTIVE_ACCOUNT" ]] && error "No active gcloud account found. Run 'gcloud auth login' first."
  info "Using active gcloud account: $ACTIVE_ACCOUNT"
  MEMBER="user:$ACTIVE_ACCOUNT"
fi

grant_role_if_missing "$MEMBER" "roles/storage.objectAdmin"
grant_role_if_missing "$MEMBER" "roles/storage.legacyBucketReader"

echo
info "Done. Backend config for OpenTofu:"
cat <<TOFU
terraform {
  backend "gcs" {
    bucket = "$BUCKET_NAME"
    prefix = "tofu/state"
  }
}
TOFU