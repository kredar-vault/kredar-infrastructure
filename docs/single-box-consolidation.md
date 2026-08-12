# Single-box consolidation (Contabo/Hetzner) — bring-up runbook

Run **every product and environment behind one shared Traefik on a single VPS** to
cut hosting spend, while keeping the AWS/GCP options intact. This runbook covers
both `xental-infrastructure` (Xental + PayLibre) and `kredar-infrastructure`
(Kredar + AjoVault).

## How it works

- **Provisioning** is decoupled per cloud under `terraform/providers/{contabo,hcloud,gcp}`
  (the original AWS root is untouched — see `terraform/providers/README.md`). Each
  outputs `host_public_ips` + `ssh_user` and prepares the host with the shared
  cloud-init (`terraform/shared/bootstrap.sh.tftpl`): Docker, a key-only `deploy`
  user, fail2ban, and the external `edge` Docker network.
- **Co-tenancy** is opt-in per GitHub Environment via the variable `EDGE_MODE=shared`.
  When set, the deploy runs the stack as its own project (`<product>-<env>`),
  env-scopes every container/network/router name, skips the in-stack Traefik, and
  attaches the app services to the shared external `edge` network. One `edge`
  Traefik (compose project `edge`, brought up idempotently by the first deploy)
  terminates TLS for every hostname. Unset `EDGE_MODE` = the classic
  one-Traefik-per-box behaviour (AWS), unchanged.

## 1. Provision the box

```bash
cd terraform/providers/contabo        # or hcloud
cp terraform.tfvars.example terraform.tfvars   # creds + ssh_public_key; smallest tier by default
terraform init && terraform apply
terraform output host_public_ips      # -> the single IP
terraform output ssh_user             # -> deploy
```

Size note: the defaults are the **smallest** tiers (Hetzner `cx22`, Contabo
`V45`). One box hosting *all* products *and* environments may need more RAM —
size up (`server_type` / `product_id`) if containers get OOM-killed.

## 2. DNS — point every hostname at the single IP

Create an A record for each name → the box IP.

| Environment | Xental / PayLibre                     | Kredar / AjoVault                  |
|-------------|---------------------------------------|------------------------------------|
| production  | `xental.online`                       | `kredar.xyz`                       |
|             | `api.xental.online`                   | `api.kredar.xyz`                   |
|             | `paylibre.xental.online`              | `vault.kredar.xyz`                 |
|             | `app.paylibre.xental.online`          | `api.vault.kredar.xyz`             |
| staging     | `staging.xental.online`               | `staging.kredar.xyz`               |
|             | `api.staging.xental.online`           | `api.staging.kredar.xyz`           |
|             | `paylibre.staging.xental.online`      | `vault.staging.kredar.xyz`         |
|             | `app.paylibre.staging.xental.online`  | `api.vault.staging.kredar.xyz`     |

## 3. Wire the GitHub Environments (both repos)

For **staging** and **production** in both `xental-infrastructure` and
`kredar-infrastructure`:

- `vars.SSH_HOST` = the box IP
- `vars.SSH_USER` = `deploy`
- `vars.EDGE_MODE` = `shared`   ← this is the switch that enables co-tenancy
- `secrets.SSH_PRIVATE_KEY` = the private key matching `ssh_public_key`

(All the app secrets — DB passwords, JWT key, Nomba, etc. — stay exactly as they
are today.)

## 4. Deploy

The shared `edge` Traefik comes up on the first deploy. Deploy **staging first,
then production**, and **Xental first** (it owns the apex hostnames), then Kredar:

1. `xental-infrastructure` → staging → production
2. `kredar-infrastructure` → staging → production

Trigger by pushing the app repos (staging/main) or via each infra repo's
`deploy-staging` / `deploy-prod` `workflow_dispatch`.

> First bring-up TLS tip: to avoid Let's Encrypt rate limits while DNS settles,
> you can point `traefik.edge.yml`'s resolver at the LE **staging** ACME endpoint,
> confirm certs issue, then switch back to production ACME and redeploy the edge
> project (`docker compose -p edge -f compose/docker-compose.edge.yml up -d`).

## 5. Verify

```bash
# every hostname answers 200 through the shared edge Traefik
for h in xental.online api.xental.online paylibre.xental.online app.paylibre.xental.online \
         kredar.xyz api.kredar.xyz vault.kredar.xyz api.vault.kredar.xyz ; do
  echo "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "https://$h/health" 2>/dev/null || echo ---)  $h"
done
# on the box: per-env isolation (distinct projects, volumes, one edge Traefik)
docker ps --format '{{.Names}}' | sort
docker volume ls  | grep -E 'staging|production'
```

Expect: one `edge-traefik`; `*-staging` and `*-production` containers/volumes
side by side; Let's Encrypt certs served for every hostname.

## 6. Decommission AWS (realise the saving)

Once the box is proven, stop/terminate the old AWS hosts (or `terraform destroy`
in the AWS root). Keep them a few days as a fallback first.

## Rollback / split back out

To move an environment back to its own box, unset that GitHub Environment's
`vars.EDGE_MODE` and point `vars.SSH_HOST` at a dedicated host — the next deploy
reverts to a self-contained stack with its own Traefik. No code changes needed.
