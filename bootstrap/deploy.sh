#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# deploy.sh — End-to-end bootstrap orchestrator
#
#   1. Runs the remote-state backend bootstrap (bootstrap/backend/backend.sh)
#   2. Optionally provisions infrastructure with OpenTofu (main.tf)
#   3. Optionally bootstraps ArgoCD on the freshly provisioned GKE cluster
#
# Every potentially destructive / long-running step waits for completion and
# prompts the user before continuing.
# ──────────────────────────────────────────────────────────────────────────────

# Always operate from the directory this script lives in (the iac/ root).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR"

# ── Helpers ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
step()  { echo -e "\n${BLUE}==>${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || error "Required command not found: '$1'. Please install it and try again."
}

# Read a string variable (var = "value") from terraform.tfvars. Empty if missing.
tfvar() {
  local key="$1" file="$2"
  [[ -f "$file" ]] || return 0
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$file" | head -n1
}

# Ask a yes/no question. Returns 0 for yes, 1 for no. Defaults to "no".
confirm() {
  local prompt="$1" reply
  read -r -p "$(echo -e "${YELLOW}[?]${NC} ${prompt} [y/N] ")" reply
  [[ "$reply" =~ ^([yY]|[yY][eE][sS])$ ]]
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Orchestrate the full platform bootstrap: backend state bucket, OpenTofu
infrastructure, and ArgoCD.

Backend options (forwarded to bootstrap/backend/backend.sh):
  -p <project_id>   GCP project ID          (default: gcp_project_id from terraform.tfvars)
  -b <bucket_name>  Bucket name             (default: gcp_bucket_state from terraform.tfvars)
  -r <region>       Bucket region           (default: europe-west4)
  -s <sa_email>     Service account email to grant state-bucket access

Other options:
  -t <tofu_bin>     OpenTofu/Terraform binary to use (default: tofu)
  -y                Assume "yes" to all prompts (non-interactive)
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
TOFU_BIN="tofu"
ASSUME_YES=false


while getopts ":p:b:r:s:t:yh" opt; do
  case $opt in
    p) PROJECT_ID="$OPTARG" ;;
    b) BUCKET_NAME="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    s) SA_EMAIL="$OPTARG" ;;
    t) TOFU_BIN="$OPTARG" ;;
    y) ASSUME_YES=true ;;
    h) usage ;;
    :) error "Option -$OPTARG requires an argument." ;;
    \?) error "Unknown option: -$OPTARG" ;;
  esac
done

# Wrap confirm() so -y short-circuits every prompt.
ask() {
  $ASSUME_YES && { info "Auto-confirming: $1"; return 0; }
  confirm "$1"
}

# ── Defaults from terraform.tfvars ────────────────────────────────────────────
TFVARS_FILE="$SCRIPT_DIR/terraform.tfvars"
if [[ -z "$PROJECT_ID" ]]; then
  PROJECT_ID="$(tfvar gcp_project_id "$TFVARS_FILE")"
  [[ -n "$PROJECT_ID" ]] && info "Using gcp_project_id from terraform.tfvars: $PROJECT_ID"
fi
if [[ -z "$BUCKET_NAME" ]]; then
  BUCKET_NAME="$(tfvar gcp_bucket_state "$TFVARS_FILE")"
  [[ -n "$BUCKET_NAME" ]] && info "Using gcp_bucket_state from terraform.tfvars: $BUCKET_NAME"
fi

# ── Dependency checks ─────────────────────────────────────────────────────────
require_cmd gcloud
require_cmd kubectl
require_cmd "$TOFU_BIN"

BACKEND_SCRIPT="$SCRIPT_DIR/modules/backend/backend.sh"
[[ -f "$BACKEND_SCRIPT" ]] || error "Backend script not found: $BACKEND_SCRIPT"
[[ -x "$BACKEND_SCRIPT" ]] || chmod +x "$BACKEND_SCRIPT"

# ──────────────────────────────────────────────────────────────────────────────
# Step 1 — Bootstrap the remote-state backend (GCS bucket).
# ──────────────────────────────────────────────────────────────────────────────
step "Step 1/3 — Bootstrapping OpenTofu remote-state backend"

BACKEND_ARGS=()
[[ -n "$PROJECT_ID"  ]] && BACKEND_ARGS+=(-p "$PROJECT_ID")
[[ -n "$BUCKET_NAME" ]] && BACKEND_ARGS+=(-b "$BUCKET_NAME")
[[ -n "$REGION"      ]] && BACKEND_ARGS+=(-r "$REGION")
[[ -n "$SA_EMAIL"    ]] && BACKEND_ARGS+=(-s "$SA_EMAIL")

info "Running: $BACKEND_SCRIPT ${BACKEND_ARGS[*]:-}"
"$BACKEND_SCRIPT" "${BACKEND_ARGS[@]}"
info "Backend bootstrap finished."

# ──────────────────────────────────────────────────────────────────────────────
# Step 2 — Provision infrastructure with OpenTofu.
# ──────────────────────────────────────────────────────────────────────────────
step "Step 2/3 — Infrastructure provisioning with OpenTofu"

if ask "Bootstrap infrastructure now by running '$TOFU_BIN apply' (main.tf)?"; then

  info "Enabling apis"
  "$TOFU_BIN" -chdir="$SCRIPT_DIR/modules/gcp_apis" init
  "$TOFU_BIN" -chdir="$SCRIPT_DIR/modules/gcp_apis" apply -auto-approve

  info "Initialising OpenTofu..."
  "$TOFU_BIN" -chdir="$SCRIPT_DIR" init
  info "Applying infrastructure (this can take a while)..."
  "$TOFU_BIN" -chdir="$SCRIPT_DIR" apply -auto-approve
  info "OpenTofu apply finished."
else
  warn "Skipping infrastructure provisioning."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 3 — Bootstrap ArgoCD on the GKE cluster.
# ──────────────────────────────────────────────────────────────────────────────
step "Step 3/3 — ArgoCD bootstrap"

if ask "Did the previous step finish successfully and do you want to bootstrap ArgoCD now?"; then
  KUBECONFIG_FILE="$SCRIPT_DIR/gke.kubeconfig"

  # Generate ./gke.kubeconfig from the OpenTofu output if it isn't there yet.
  if [[ ! -f "$KUBECONFIG_FILE" ]]; then
    info "Fetching cluster credentials into $KUBECONFIG_FILE ..."
    GKE_CMD="$("$TOFU_BIN" -chdir="$SCRIPT_DIR" output -raw gke)" \
      || error "Could not read the 'gke' output. Did the apply step succeed?"
    eval "$GKE_CMD" || error "Failed to fetch GKE credentials."
  else
    info "Reusing existing kubeconfig: $KUBECONFIG_FILE"
  fi

  # Create the argocd namespace (idempotent).
  info "Creating 'argocd' namespace..."
  kubectl create ns argocd --kubeconfig="$KUBECONFIG_FILE" \
    --dry-run=client -o yaml | kubectl apply --kubeconfig="$KUBECONFIG_FILE" -f -

  # Render and apply the ArgoCD bootstrap kustomization.
  info "Deploying ArgoCD (kustomize build + server-side apply)..."
  kubectl kustomize --enable-helm modules/argocd \
    | kubectl apply --kubeconfig="$KUBECONFIG_FILE" --server-side -f -

  info "Waiting for ArgoCD..."
  kubectl --kubeconfig="$KUBECONFIG_FILE" wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s

  info "ArgoCD bootstrap finished."

  info "Intitial ArgoCD admin password: "
  kubectl --kubeconfig="$KUBECONFIG_FILE" -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

else
  warn "Skipping ArgoCD bootstrap."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 4 — Deploy root application
# ──────────────────────────────────────────────────────────────────────────────

if ask "Want to apply root application now?"; then
  kubectl apply --kubeconfig="$KUBECONFIG_FILE" --server-side -f "$SCRIPT_DIR/modules/argocd/root-app.yaml"


  if [[ -f  "$SCRIPT_DIR/github-secret.yaml" ]]; then
    info "Github secret found. Applying..."
    kubectl apply --kubeconfig="$KUBECONFIG_FILE" --server-side -f "$SCRIPT_DIR/github-secret.yaml"
  else
    warn "no repo secret found!"
  fi
fi

step "Done."
info "Deployment workflow complete."
