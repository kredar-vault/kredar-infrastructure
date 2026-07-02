# Kredar Infrastructure

Single source of truth for **running** the Kredar platform. It composes the image
built by `kredar-backend` into a TLS-terminated stack and deploys it to AWS EC2 via
GitHub Actions. Modelled on the Xental infrastructure.

- **Runtime:** Docker Compose on EC2 (one host per environment)
- **Registry:** GHCR (`ghcr.io/kredar-vault/*`)
- **Ingress/TLS:** Traefik + Let's Encrypt
- **Environments:** `staging` (branch `staging`) and `production` (branch `main`)
- **Secrets:** GitHub Environment secrets (rendered at deploy time)
- **Deploy transport:** SSH (rsync the stack + rendered env, then run `deploy.sh`)
- **Provisioning:** Terraform (`terraform/`)

> **v1 scope:** backend only (`kredar-api` + Postgres + Traefik). The frontend and
> `ajovault` are added as services when those repos ship images.

```
kredar-backend push ─▶ build image ─▶ push GHCR ─▶ repository_dispatch
                                                        │
                                                        ▼
       infra deploy job (GitHub Environment): pin version
         → render env from GitHub secrets → rsync over SSH → host deploy.sh
                                                        │
                                                        ▼
                  EC2 host: docker compose pull/up → health-check
                                                        │
                                              auto-rollback on failure
```

## Layout

```
compose/      base + per-env docker-compose files
traefik/      static config + dynamic middlewares (TLS, security headers)
env/          layered, non-secret env templates (.example)
secrets/      secret templates you fill in locally (git-ignored)
versions/     pinned image tags per env (auto-managed; the rollback ledger)
scripts/      render-env, deploy (health-check + auto-rollback), rollback, healthcheck
terraform/    AWS: 2 EC2 hosts (staging+prod), EIPs, SSH key, security groups
.github/      deploy-staging, deploy-prod (gated), rollback, reusable _deploy
```

## First-time bring-up

1. **Deploy key:** `ssh-keygen -t ed25519 -f ~/.ssh/kredar_deploy -N ""` — public half → Terraform, private half → GitHub secret `SSH_PRIVATE_KEY`.
2. **Provision:** in `terraform/`, `cp terraform.tfvars.example terraform.tfvars`, set `ami_id` (Ubuntu 24.04 for your region) + region, then `terraform init && terraform apply`. Record `terraform output host_public_ips`.
3. **GHCR token:** a classic PAT with `read:packages` (username + token).
4. **GitHub Environments** on `kredar-infrastructure`: create `staging` and `production` (add **required reviewers** on production). For each:
   - **Variables:** `SSH_HOST` (that env's Elastic IP), `SSH_USER=ubuntu`.
   - **Secrets:** `SSH_PRIVATE_KEY`, `POSTGRES_PASSWORD`, `GHCR_USER`, `GHCR_TOKEN`, `JWT_SIGNING_KEY`, and optionally `TRAEFIK_DASHBOARD_AUTH` (staging), `RESEND_API_KEY`, `NOMBA_*`. (Fill `secrets/<env>.env` locally; these get pushed there.)
5. **App repo:** in `kredar-backend`, add repo secret `INFRA_DISPATCH_TOKEN` (fine-grained PAT with Contents + Actions read/write on `kredar-infrastructure`).
6. **DNS:** point `api.staging.kredar.xyz` and `api.kredar.xyz` A records at the respective Elastic IPs.
7. **Deploy:** push to `staging` in `kredar-backend` (or run **Deploy staging** manually). Traefik obtains Let's Encrypt certs automatically. Once green, promote to production (push `main`, approve the gated run).

## Local validation (offline, no secrets)

```bash
SKIP_SECRETS=1 scripts/render-env.sh staging
```

## Rolling back

Revert `versions/<env>.env` in git and re-run the deploy, or use the **Rollback**
workflow, or host-side `scripts/rollback.sh <env>`.
