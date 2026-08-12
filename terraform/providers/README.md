# Multi-cloud provisioning roots

The infrastructure deploy layer (GitHub Actions → SSH → `scripts/deploy.sh`) is
cloud-agnostic: it only needs an Ubuntu host with Docker and a key-only login
user. So provisioning is decoupled from deployment, and each cloud gets its own
self-contained Terraform root with its **own state**.

```
terraform/                 # AWS root (EC2 staging+production+monitoring) — the original, UNTOUCHED
terraform/shared/bootstrap.sh.tftpl   # one cloud-init used by every non-AWS root
terraform/providers/
  contabo/                 # single "shared" VPS for the cost-consolidated topology
  hcloud/                  # Hetzner Cloud
  gcp/                     # GCP Compute Engine
```

## Why separate roots (not one `var.cloud` state)

A single Terraform state can only describe one desired reality: applying it with
`cloud=contabo` against the state that holds the AWS resources would **destroy
AWS**. Keeping each cloud in its own root/state means standing up Contabo (or
Hetzner, or GCP) **never touches the live AWS resources** — which is exactly the
"keep AWS untouched" requirement. The existing AWS root (`terraform/*.tf` +
`terraform.tfstate`) is left exactly as it was.

## Pick a cloud and apply

```bash
cd terraform/providers/contabo        # or hcloud / gcp
cp terraform.tfvars.example terraform.tfvars   # fill in creds + ssh_public_key
terraform init
terraform apply
terraform output host_public_ips      # -> SSH_HOST ; also point DNS A records here
terraform output ssh_user             # -> SSH_USER
```

Each root outputs `host_public_ips` (a `host-key → IP` map) and `ssh_user` in an
identical shape, so the downstream wiring (GitHub Environment vars + DNS) is the
same regardless of which cloud you chose.

## Cost-consolidated single box

The default `hosts = ["shared"]` provisions **one** VPS. Combined with
`EDGE_MODE=shared` in the runtime env (see the repo `RUNBOOK`/`README`), that box
runs one Traefik in front of every product and environment. Point every service
hostname's DNS A record at the single output IP. See `docs/runbooks/host-lifecycle.md`
for the full single-box bring-up runbook.

To go back to one box per environment on any cloud, set
`hosts = ["staging","production"]`.
