# GitOps

Flux structure:

```
gitops/
├── clusters/
│   ├── staging/        # flux bootstrap points here
│   └── prod/
└── infrastructure/     # HelmReleases: strimzi, kube-prometheus-stack, operator
```

Bootstrap (once the repo is on GitHub):

```bash
flux bootstrap github --owner=<user> --repository=zeedfai \
  --branch=main --path=gitops/clusters/staging --personal
```

Includes ImageRepository/ImagePolicy/ImageUpdateAutomation for the scorer:
push a new tag → Flux commits automatically → the operator rolls it out.
