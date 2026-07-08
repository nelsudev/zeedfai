# zeedfai on Contabo (cheap cloud via API)

A low-cost alternative to the cloud phase (GKE/EKS/Hetzner): a Contabo VPS
running **k3s + Flux**, provisioned entirely via API — plays the same "real
cloud demo" role for ~€5/month, and demonstrates infrastructure automation
via API.

> Official alternative to these scripts: the Contabo **`cntb` CLI**
> (https://contabo.com/en/contabo-cli/) covers the same operations
> (`cntb create instance --userData "$(cat cloud-init.yaml)"`). The scripts
> here talk to the REST API directly (https://api.contabo.com) to show the
> OAuth2 + endpoint mechanics without extra dependencies.

## Credentials

In the Contabo dashboard → API: create `CLIENT_ID`, `CLIENT_SECRET`, and use
your API user/password.

```bash
export CNTB_CLIENT_ID=...
export CNTB_CLIENT_SECRET=...
export CNTB_API_USER=...
export CNTB_API_PASS=...
```

## Automatic teardown (cost safety net)

`.github/workflows/teardown-cloud-demo.yml` runs
`scripts/teardown-cloud.sh` every night (03:00 UTC) and also on demand
(Actions tab → "Run workflow"). It destroys any Contabo instance whose
`displayName` starts with `zeedfai` and any Hetzner server labeled
`zeedfai=true`. Configure the repo secrets (Settings → Secrets and
variables → Actions): `CNTB_CLIENT_ID`, `CNTB_CLIENT_SECRET`,
`CNTB_API_USER`, `CNTB_API_PASS`, `HCLOUD_TOKEN`. If none are configured,
the workflow runs and does nothing (each provider is skipped without
credentials).

## Usage

```bash
./create-vps.sh            # creates a VPS (VPS 10, eu-west) with cloud-init k3s+flux
./list-instances.sh        # lists instances and IPs
# when you're done with the demo:
./delete-instance.sh <id>  # destroys it (don't forget!)
```

`cloud-init.yaml` installs k3s, kubectl, and runs `flux install`. Once you
have the IP: `ssh root@IP`, copy the kubeconfig
(`/etc/rancher/k3s/k3s.yaml`), and run
`flux bootstrap github ...` pointing at your GitOps repo.

> Note: for the candidacy this is aimed at, the Contabo path proves API
> automation and infrastructure management; the "AWS or GCP" job
> requirement is better satisfied by the GKE/EKS + Terraform phase
> described in `docs/`. The two aren't mutually exclusive.
