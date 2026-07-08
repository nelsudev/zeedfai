# zeedfai on Hetzner Cloud (cloud phase)

An hourly-billed k3s cluster to demonstrate real **machine scaling** — which
Contabo (monthly billing) can't do with any economic honesty.

## Prerequisites

- Hetzner Cloud account + API token (project → Security → API tokens, Read & Write)
- `terraform` ≥ 1.6

## Bring up

```bash
cd terraform/hetzner
export TF_VAR_hcloud_token=<token>
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
terraform init && terraform apply
# follow the "next_steps" output
```

Cost: 2× cx22 ≈ €0.012/h — an afternoon of demo costs cents.

## Node scaling (cluster-autoscaler)

The [official cluster-autoscaler has a Hetzner provider](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/hetzner):
install it with the token and a node-group spec (`HCLOUD_CLUSTER_CONFIG`),
and when pods go `Pending` for lack of capacity it creates new servers in
~1 min, deleting them once capacity is freed up. Combined with the
zeedfai-operator's pod autoscaler, this gives the full demo: burst → more
replicas → no capacity → more **nodes** → burst ends → fewer replicas →
fewer nodes.

## Tear down (important)

```bash
terraform destroy
```

Safety net: every server carries the `zeedfai=true` label, and the
`teardown-cloud-demo.yml` GitHub Action deletes any server with that label
every night at 03:00 UTC (repo secret `HCLOUD_TOKEN`).
