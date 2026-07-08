# CLAUDE.md

Guidelines for Claude Code in this repository.

## Repo purpose

A portfolio/demo Kubernetes operator (Go, controller-runtime) that runs
fraud-scoring stream pipelines: consumer-lag autoscaling, SLO self-healing,
canary rollback, GitOps delivery via Flux, plus an operations API + GUI.
Personal project built to demonstrate platform-engineering practice — not
affiliated with any employer or client; never reference one by name in this
repo (docs, commit messages, code comments).

## How this repo came to be (provenance)

The design was worked out with **Claude Fable** starting from a job
description's requirements (Kubernetes operators in Go, GitOps with FluxCD,
self-healing, incident response, developer experience) and a deliberately
chosen non-trivial domain (fraud scoring, with a real industry SLA — p99.9 <
250ms — to design against). Every phase (operator core → observability →
GitOps → autoscaling → canary → operations GUI → cloud) was then built,
**run, and verified live** with Claude Code before being called done —
including finding and fixing real bugs along the way (see `docs/FAQ.md` and
the commit history).

This matters for maintenance: claims in the docs are backed by an actual
run, not aspiration. When adding a feature, verify it against a live
cluster before writing it up as working, and keep the docs' habit of stating
trade-offs and honest limitations (e.g. the canary analysis fails open, the
duplication between `hack/` and `gitops/infrastructure/` is deliberate).

## Organization — where knowledge lives

| File | Role | Derived from |
|---|---|---|
| `README.md` | Pitch + map of the repo | summary of everything below |
| `docs/ARCHITECTURE.md` | What every component does and why | the design conversation + the code itself |
| `docs/LOCAL-DEMO-GUIDE.md` | Step-by-step for all demos, with verified timings | actual runs on this repo |
| `docs/FAQ.md` | Troubleshooting real problems, by area | bugs actually hit while building/verifying |
| `docs/postmortems/` | Write-ups of deliberately-induced incidents | game days run against the live cluster |
| `operator/` | The controller: CRD, reconciler, autoscaler, canary, observability | ARCHITECTURE.md §2–4 |
| `gitops/` | Flux repo structure (`clusters/` → `infrastructure/`) | ARCHITECTURE.md §5 |
| `terraform/hetzner/` | Cloud node-scaling target | ARCHITECTURE.md / roadmap "cloud" phase |

**The sync rule**: `docs/ARCHITECTURE.md` and the code must describe the same
system. A change to the operator's behavior (a new CRD field, a changed
autoscaling formula, a new alert) needs a matching update in
`docs/ARCHITECTURE.md` in the same commit — not a follow-up. If a change
also affects how someone runs the demo, update `docs/LOCAL-DEMO-GUIDE.md`
too, and add an FAQ entry for any new failure mode found while verifying it.

## Language & style

- All docs in **English**. Direct, honest about trade-offs, no marketing
  fluff inside technical docs — `README.md` is the only place that sells.
- Emoji as section markers in README headers — keep the pattern, don't
  overdo it inside body text or in the other docs.
- Commands are always in fenced `bash`/`yaml` blocks with inline `#`
  comments explaining the non-obvious flag, not the obvious one.
- Go comments: no comment for what the code already says via naming; a
  comment only for the non-obvious *why* (a hidden constraint, a trade-off,
  a bug that was fixed and would otherwise recur).

## Commit message conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<optional scope>): <short summary, imperative mood, no trailing period>
```

- Allowed types: `feat`, `fix`, `docs`, `refactor`, `chore`, `ci`, `test`.
- Summary line ≤ 72 characters, imperative ("add", not "added"/"adds").
- Scope is optional but useful here: `operator`, `scorer`, `platform-api`,
  `gitops`, `docs`, `ci`, `terraform`.
- Body explains *why* and, for anything touching behavior, **what was
  verified and how** (the habit this repo is built on) — not a restatement
  of the diff.
- Examples:
  - `feat(operator): add consumer-lag autoscaler with SLO self-healing`
  - `fix(gitops): serviceMonitorSelectorNilUsesHelmValues blinded canary analysis`
  - `docs(faq): document the k3d orphaned-node cleanup step`

## Hard rules

- Never commit real cloud tokens, VPS IPs, or kubeconfigs — GHCR/Hetzner/
  Contabo credentials are created out-of-band per the READMEs in
  `gitops/infrastructure/operator/` and `scripts/contabo/`.
- Never make the canary promotion path automatic (the operator writing back
  `spec.model.image`) — it would fight Flux over the GitOps source of
  truth. Rollback stays automatic; promotion stays a Git commit.
- Never claim a feature works without running it against a live cluster
  first — this repo's whole credibility rests on "verified live", not
  "should work".
