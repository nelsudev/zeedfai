# zeedfai

Plataforma de demonstração de **platform engineering** para fraud-scoring em
streaming: um Kubernetes Operator em Go que gere pipelines de scoring
(Kafka → scorer), com autoscaling por consumer lag, self-healing por SLO
(p99.9 < 250 ms) e entrega via GitOps (FluxCD).

> Nome é um anagrama afetuoso; projeto pessoal, sem afiliação com a Feedzai.

## Componentes

| Diretório | O quê |
|---|---|
| `operator/` | Operator (controller-runtime): CRD `ScoringPipeline` + reconciler |
| `scorer/` | Serviço Go que consome Kafka e pontua transações, métricas Prometheus |
| `loadgen/` | Gerador de transações sintéticas com modo burst (`POST /burst`) |
| `gitops/` | Estrutura Flux (staging/prod) — fase 3 |
| `runbooks/` | Runbooks ligados aos alertas |
| `scripts/contabo/` | Provisionar um nó k3s+Flux na Contabo via API |
| `hack/` | Manifests de demo local (kind, Strimzi/Kafka) |

## Levantar e testar em local (virtualização com kind/Docker)

O ambiente local corre em **kind** (Kubernetes-in-Docker) — só precisas de Docker.

```bash
# 1. Instalar a toolchain (go, kind, kubectl, helm, flux → ~/.local)
make tools
export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$PATH"

# 2. Subir tudo: cluster kind + Strimzi/Kafka + loadgen + CRD (~5 min)
make demo-up

# 3. Num terminal: correr o operator (fora do cluster, fluxo de dev)
make run

# 4. Noutro terminal: criar um pipeline e observar
make deploy-sample
kubectl get scoringpipelines -w        # Available=True quando as réplicas estiverem prontas
kubectl get deploy,pods                # card-payments-eu-scorer com 2 réplicas

# 5. Testar o burst (2000 ev/s durante 2 min)
make burst
kubectl logs deploy/card-payments-eu-scorer --tail=5

# 6. (Opcional) Prometheus + Grafana
make monitoring

# Limpar
make demo-down
```

Teste rápido de reconciliação (self-healing básico):

```bash
kubectl delete deploy card-payments-eu-scorer   # o operator repõe-no em segundos
kubectl get deploy -w
```

## Roadmap (fases)

- [x] **F0–F2**: toolchain, scorer/loadgen, operator v1 (Deployment/Service + conditions)
- [ ] **F2b**: ServiceMonitor + PrometheusRule com `runbook_url` + PDB
- [ ] **F3**: GitOps completo com Flux image automation
- [ ] **F4**: autoscaler por consumer lag + self-healing por SLO p99.9 (com cooldown)
- [ ] **F5**: canary com rollback automático
- [ ] **F6**: platform-api (escritas via PR no repo GitOps) + GUI com botão de burst
- [ ] **F7**: cloud — Terraform GKE/EKS e/ou Contabo k3s via API (`scripts/contabo/`)

## Cloud barata: Contabo

`scripts/contabo/` provisiona um VPS com k3s + Flux inteiramente via API da
Contabo (~5€/mês) — ver o README lá dentro.
