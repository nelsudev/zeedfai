# Hetzner E2E validation report — 2026-07-09

Branch: `cloud/hetzner-e2e-validation`

Result: **the platform works on real Hetzner Cloud after fixing bootstrap,
networking, firewall, and GitOps ordering issues.**

## Environment

- Hetzner location: `fsn1`
- Server type used for the successful run: `ccx13`
- Nodes: 1 control-plane, 1 worker
- OS image: Ubuntu 24.04
- Kubernetes: k3s `v1.36.2+k3s1`
- Flux source tested in the full application run:
  `main@sha1:22a3655db04677c1116675088075656c777f98d8`
- Fresh Terraform/cloud-init validation commit:
  `a9d3f97 preserve DNS for Hetzner private netplan`
- GHCR auth: `ghcr-pull` created in `default` and `zeedfai-system`

## What passed

### Terraform and local checks

- `terraform -chdir=terraform/hetzner init -backend=false`: passed.
- `terraform -chdir=terraform/hetzner validate`: passed.
- `PATH="$HOME/.local/bin:$HOME/.local/go/bin:$PATH" make test`: passed.

### Hetzner provisioning

- Terraform created the Hetzner network, subnet, SSH key, k3s token,
  firewall, control-plane server, and worker server.
- A clean destroy/apply of the committed PR branch created both nodes with
  private networking and dynamic private NIC detection.
- The control-plane and worker both detected `enp7s0` at runtime; the NIC name
  is no longer hardcoded in Terraform inputs or k3s flags.
- The firewall allows SSH and ICMP publicly, and restricts Kubernetes API
  `tcp/6443` to the validation workstation `/32`.
- Final node state from the clean review follow-up run:

```text
NAME               STATUS   ROLES           VERSION        INTERNAL-IP
zeedfai-cp         Ready    control-plane   v1.36.2+k3s1   10.0.1.10
zeedfai-worker-0   Ready    <none>          v1.36.2+k3s1   10.0.1.20
```

Note: the worker still reports Hetzner/cloud-init recoverable `init-local`
schema warnings, but `runcmd` completed, `k3s-agent` is active, flannel uses
the private interface, and Kubernetes reports the worker `Ready`.

### GitOps platform install

- Flux controllers installed successfully.
- Flux Git source reconciled from GitHub over HTTPS.
- All staging Kustomizations reached `Ready=True`:

```text
infra-crds           Ready=True
infra-demo           Ready=True
infra-kafka-cluster  Ready=True
infra-monitoring     Ready=True
infra-operator       Ready=True
infra-platform-api   Ready=True
infra-sources        Ready=True
infra-strimzi        Ready=True
```

### Runtime health

- Kafka reached `Ready`.
- All deployments reached `Available`.
- The demo pipeline reached `Available=True`.
- GHCR private images pulled successfully after creating `ghcr-pull`.
- Generated observability resources existed:

```text
ServiceMonitor/default/card-payments-eu-scorer
ServiceMonitor/zeedfai-system/zeedfai-operator
PrometheusRule/default/card-payments-eu-scorer
PodDisruptionBudget/default/card-payments-eu-scorer
```

### Autoscaling burst

Command:

```bash
curl -X POST 'http://localhost:8081/burst?rate=2000&seconds=120'
```

Observed timeline:

```text
13:57:29  replicas=2  desired=2  lag=200
13:57:44  replicas=3  desired=3  lag=4735
13:58:00  replicas=3  desired=3  lag=5784
13:58:15  replicas=7  desired=7  lag=2066
13:58:46  replicas=3  desired=3  lag=2680
13:59:17  replicas=5  desired=5  lag=3670
13:59:48  replicas=2  desired=2  lag=100
14:00:03  replicas=2  desired=2  lag=500
```

Conclusion: lag-driven scale-out and scale-in worked on real Hetzner nodes.
The largest observed scale-out was 2 → 7 replicas.

### Platform API / GUI

- `GET /` returned the embedded HTML GUI.
- `GET /api/pipelines` returned the live pipeline state:

```json
[{"name":"card-payments-eu","namespace":"default","image":"ghcr.io/nelsudev/zeedfai-scorer:0.2.0","replicas":2,"desired":2,"lag":500,"available":"True","canary":"","sloMs":250}]
```

## Failures found and fixed

### 1. Hetzner server type drift

Original Terraform used `cx22`. Hetzner returned:

```text
server type cx22 not found
```

Cheaper x86 shared SKUs were visible but not orderable in this project:

```text
Server Type "cpx21" is unavailable in "nbg1" and can no longer be ordered
Server Type "cpx21" is unavailable in "fsn1" and can no longer be ordered
Server Type "cpx31" is unavailable in "fsn1" and can no longer be ordered
Server Type "cpx41" is unavailable in "fsn1" and can no longer be ordered
```

Fix: make `server_type` and `location` Terraform variables and default to the
validated x86 combination `ccx13` / `fsn1`.

### 2. Private network interface was not configured inside Ubuntu

The Hetzner private NIC existed but booted without an IPv4 address:

```text
enp7s0 DOWN
```

k3s was started with `--node-ip 10.0.1.10 --flannel-iface enp7s0`, causing
the control-plane to restart until the interface was manually configured.

Fix: cloud-init now detects the Hetzner private NIC by MAC address and writes
netplan with a `/32` private IP, explicit DNS resolvers, and the Hetzner
gateway route:

```text
10.0.0.1 dev enp7s0 scope link
10.0.0.0/16 via 10.0.0.1 dev enp7s0
```

### 3. Worker registered with its public IP

The worker originally joined without explicit k3s agent network flags and
registered:

```text
INTERNAL-IP <worker-public-ip>
```

Fix: worker cloud-init now starts k3s agent with:

```text
--node-ip <private-ip> --flannel-iface <detected-private-iface>
```

### 4. Remote kubeconfig TLS SAN was incomplete

Replacing `127.0.0.1` with the public IP failed because the k3s certificate
did not include the public IP:

```text
x509: certificate is valid for 10.0.1.10, 10.43.0.1, 127.0.0.1, ::1, not <control-plane-public-ip>
```

Fix: control-plane cloud-init now adds both private IP and public IPv4 as
k3s `--tls-san` values.

### 5. GitOps ordering bug

`infra-operator` tried to apply a `ServiceMonitor` before the Prometheus
Operator CRDs existed:

```text
ServiceMonitor/zeedfai-system/zeedfai-operator dry-run failed:
no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
```

Fix: `infra-operator` now depends on `infra-monitoring` as well as
`infra-crds`.

### 6. Kubernetes API was exposed publicly

The initial Terraform did not attach a Hetzner firewall, so the public
control-plane address exposed `tcp/6443` to the internet.

Fix: Terraform now creates `hcloud_firewall.zeedfai`. SSH and ICMP remain
open for demo access and diagnostics, while Kubernetes API access is controlled
by `var.kube_api_allowed_cidrs`. The clean validation run used a single `/32`.

### 7. k3s installer failed during early boot

The review follow-up clean apply exposed two boot-time issues:

- fetching public metadata after `netplan apply` could fail;
- downloading the k3s installer to `/tmp` and replacing netplan without DNS
  made the installer unreliable.

Fix: cloud-init now reads public metadata before applying netplan, downloads
the installer to `/root/install-k3s.sh`, preserves DNS in the generated
netplan, and waits for the control-plane API before installing the worker
agent.

## Remaining gaps

- Canary rollback was not executed in this cloud run.
- Hetzner cluster-autoscaler / real node scale-out was not installed or tested.
- The run used Flux installed manually with an HTTPS Git source rather than a
  full `flux bootstrap github` deploy-key flow.
- Full GitOps application reconciliation was proven in the first live run. The
  review follow-up clean run focused on the Terraform/cloud-init fixes and
  validated both k3s nodes from committed code.

## Teardown

Initial full application run teardown completed successfully:

```bash
terraform -chdir=terraform/hetzner destroy
hcloud server list -o columns=name,labels | grep zeedfai || true
```

Terraform destroyed the managed resources and the final `hcloud` check returned
no servers with a `zeedfai` label. The review follow-up validation cluster was
also destroyed after collecting the clean node evidence.
