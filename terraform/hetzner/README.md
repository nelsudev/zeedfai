# zeedfai na Hetzner Cloud (Fase 7)

Cluster k3s com billing à hora para demonstrar **escala de máquinas** real —
o que a Contabo (billing mensal) não consegue fazer com honestidade económica.

## Pré-requisitos

- Conta Hetzner Cloud + token API (project → Security → API tokens, Read & Write)
- `terraform` ≥ 1.6

## Subir

```bash
cd terraform/hetzner
export TF_VAR_hcloud_token=<token>
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
terraform init && terraform apply
# seguir o output "next_steps"
```

Custo: 2× cx22 ≈ €0.012/h — uma tarde de demo custa cêntimos.

## Escala de nodes (cluster-autoscaler)

O [cluster-autoscaler oficial tem provider Hetzner](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/hetzner):
instala-se com o token e uma node-group spec (`HCLOUD_CLUSTER_CONFIG`), e
quando pods ficam `Pending` por falta de capacidade cria servers novos em
~1 min, apagando-os quando sobra capacidade. Combinado com o autoscaler de
pods do zeedfai-operator, dá a demo completa: burst → mais réplicas → sem
capacidade → mais **nodes** → burst acaba → menos réplicas → menos nodes.

## Desligar (importante)

```bash
terraform destroy
```

Rede de segurança: todos os servers têm a label `zeedfai=true`, e a GitHub
Action `teardown-cloud-demo.yml` apaga qualquer server com essa label todas
as noites às 03:00 UTC (secret `HCLOUD_TOKEN` no repo).
