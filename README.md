# platform-2at-gitops-gke

A GitOps platform on **Google Kubernetes Engine (GKE)**. Infrastructure is
provisioned with **OpenTofu/Terraform**, and everything running on the cluster
is delivered continuously by **Argo CD** using an app-of-apps pattern.

The bootstrap flow is:

```
deploy.sh ──▶ GCS state bucket ──▶ enable GCP APIs ──▶ OpenTofu (GKE/VPC/DNS/IAM)
          ──▶ Argo CD install ──▶ root Application ──▶ clusters/platform
                                                        ├─ apps/     (Argo CD + infra)
                                                        └─ tenants/  (workloads)
```

## Prerequisites

Install and authenticate the following before bootstrapping:

- `gcloud` (authenticated: `gcloud auth login` and `gcloud auth application-default login`)
- `kubectl`
- `tofu` (OpenTofu) — or set `-t terraform`
- `python3` (used by the state-bucket bootstrap)

### 1. Set the project ID in the tfvars files

The GCP project ID must be filled in **before** running the deploy script, in
**both** tfvars files — the deploy script and the state-bucket bootstrap read
the project ID from them:

- [bootstrap/terraform.tfvars](bootstrap/terraform.tfvars) — the main
  configuration. At minimum set `gcp_project_id` and `gcp_bucket_state` (the
  name of the GCS bucket that will hold the remote state). The deploy script
  reads these to create and target the state bucket.
- [bootstrap/modules/gcp_apis/terraform.tfvars](bootstrap/modules/gcp_apis/terraform.tfvars)
  — set `project_id` here as well, since the API-enablement step runs as its
  own OpenTofu module.

> These tfvars files are not committed. Create them from the variables declared
> in [bootstrap/variables.tf](bootstrap/variables.tf) and
> [bootstrap/modules/gcp_apis/variables.tf](bootstrap/modules/gcp_apis/variables.tf).

### 2. Provide the GitHub repository secret in advance

Argo CD needs credentials to pull this repository. Place the repository secret
manifest at `bootstrap/github-secret.yaml` **before** running the deploy
script. The final step of the deploy script applies it automatically if the
file exists (otherwise it warns and skips it, and Argo CD will fail to sync a
private repo).

## Bootstrapping with the deploy script

Run the orchestrator from the `bootstrap/` directory:

```bash
cd bootstrap
./deploy.sh
```

The script ([bootstrap/deploy.sh](bootstrap/deploy.sh)) walks through the full
bootstrap, prompting before each major step:

1. **State backend** — creates the GCS bucket for OpenTofu remote state
   (idempotent), using the project ID / bucket name from `terraform.tfvars`.
2. **Infrastructure** — enables the required GCP APIs, then runs
   `tofu apply` to provision the GKE cluster, VPC, DNS and IAM.
3. **Argo CD** — installs Argo CD onto the new cluster and prints the initial
   admin password.
4. **Root application** — applies the root Argo CD `Application` and the GitHub
   repository secret, handing control over to GitOps.

Useful flags (see `./deploy.sh -h` for all):

```bash
./deploy.sh -p my-project -r europe-west1     # override project / region
./deploy.sh -y                                 # non-interactive (assume yes)
```

### Cluster credentials (kubeconfig)

You do **not** need to fetch cluster credentials manually. During the Argo CD
step the deploy script pulls the GKE credentials from the OpenTofu output and
writes them to `bootstrap/gke.kubeconfig`, then uses that kubeconfig for all
`kubectl` operations. If the file already exists it is reused.

## Repository structure

| Path          | Purpose |
| ------------- | ------- |
| [bootstrap/](bootstrap) | OpenTofu/Terraform IaC and the `deploy.sh` orchestrator. Provisions the GCS state backend, GCP APIs, GKE cluster, VPC, DNS and IAM (under `modules/`), then installs Argo CD and applies the root application. This is the only imperative, one-time step. |
| [apps/](apps) | The app-of-apps layer. Argo CD `Application` definitions that self-manage Argo CD (`argocd.yaml`) and deploy the platform infrastructure (`infra-apps.yaml`). |
| [clusters/](clusters) | Per-cluster entry point. `clusters/platform` is the target of the root Application and kustomizes together the `apps/` layer and the tenant apps for this cluster. |
| [infra/](infra) | Platform infrastructure components delivered by Argo CD: Argo CD projects, cert-manager, Crossplane (with tenant compositions/XRDs), Envoy Gateway, external-dns, external-secrets and the CNPG operator. |
| [tenants/](tenants) | Tenant workloads (e.g. `tenant-planka`). Each tenant requests its namespace and guardrails (ResourceQuota, LimitRange, NetworkPolicies) via a Crossplane `XTenant` claim, plus its application manifests and database. |