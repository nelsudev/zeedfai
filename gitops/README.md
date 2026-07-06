# GitOps (Fase 3)

Estrutura Flux prevista:

```
gitops/
├── clusters/
│   ├── staging/        # flux bootstrap aponta aqui
│   └── prod/
└── infrastructure/     # HelmReleases: strimzi, kube-prometheus-stack, operator
```

Bootstrap (quando o repo estiver no GitHub):

```bash
flux bootstrap github --owner=<user> --repository=zeedfai \
  --branch=main --path=gitops/clusters/staging --personal
```

Inclui ImageRepository/ImagePolicy/ImageUpdateAutomation para o scorer:
push de nova tag → commit automático do Flux → rollout pelo operator.
