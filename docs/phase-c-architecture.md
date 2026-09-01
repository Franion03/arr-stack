# Phase C — architecture changes, pending approval

Phases A (quality gates) and B (security scanning) are merged and additive:
they cannot affect the running cluster. Everything below **modifies a repo
that ArgoCD auto-syncs with `prune` and `selfHeal` against the live house**,
so none of it is done yet.

Ordered by value per unit of risk. Each item is independently shippable.

---

## C1 — Split `arr-stack-root` into an ApplicationSet

**Risk: medium. Value: highest.**

Today `argocd/root.yaml` is a single Application pointing at `apps/`, covering
all 15 apps. One app's failure is every app's failure, and this has already
happened once: the gitops-engine nil-pointer panic on cert-manager's CRDs
stopped the *entire* stack from syncing, visible only as `OutOfSync` with a
stale revision. Nothing about that incident was specific to cert-manager —
any app can do it again.

Replace with an ApplicationSet using a git directory generator over `apps/*`,
producing one Application per directory. Each app then gets its own sync
status, its own health, and its own blast radius.

**Migration hazard — the reason this needs a maintenance window.** ArgoCD
tracks ownership by the `app.kubernetes.io/instance` label. Moving a resource
from `arr-stack-root` to a per-app Application rewrites that label on every
object in the cluster. Done carelessly with `prune: true`, the old
Application can delete resources the new one has not adopted yet.

Sequence:

1. Add the ApplicationSet with `syncPolicy.automated` **omitted** (manual sync).
2. Set `arr-stack-root` to `prune: false`.
3. Sync one low-stakes app manually (`homarr`), confirm adoption is clean.
4. Roll the rest one at a time; `assistant` and `health` last.
5. Delete `arr-stack-root` with `--cascade=false` so it drops the Application
   without touching workloads.
6. Re-enable automated sync per app.

Keep `Replace=true` on cert-manager. `ServerSideApply=true` still panics this
ArgoCD version.

## C2 — Pin every image by digest

**Risk: low. Value: high.**

```
ghcr.io/franion03/home-harness:latest        -> @sha256:...
ghcr.io/open-webui/open-webui:main           -> @sha256:...
ghcr.io/matatonic/openedai-speech-min:latest -> @sha256:...
```

A mutable tag means three things, all bad: no rollback target, no drift
detection (ArgoCD reports Synced while the running image differs from what
anyone believes is deployed), and pods that only change on an unrelated
restart — so a bad upstream push lands at the worst possible moment.

The home-harness build workflow already prints the digest to its job summary
for exactly this. Add Renovate (Dependabot cannot bump a digest-pinned image
that has no version tag) to open the bump PRs.

Do `home-harness` first — it is the image we build, so a bad pin is one
revert away. `open-webui:main` is the riskiest of the three today: it tracks
a development branch.

## C3 — Default-deny NetworkPolicies per namespace

**Risk: low. Value: high for `health` specifically.**

Only `assistant` has policies (`harness-ingress`, `openwebui-ingress`,
`tts-ingress`). `health` holds body metrics in InfluxDB with an Ingress
exposed on the LAN, in a cluster that also runs a Cloudflare tunnel, and has
no policy at all. `media` likewise.

Add a default-deny ingress policy per namespace plus explicit allows. Start
with `health`; it has exactly two legitimate clients (Grafana in-namespace,
Home Assistant at `192.168.1.117` via the Ingress controller), so the allow
list is short and easy to get right.

Verify with a temporary pod in another namespace before and after — a policy
that denies everything including the thing you needed looks identical to a
working one until something breaks at 2am.

## C4 — Split the seal workflow's per-app steps

**Risk: low. Value: medium.**

The hardcoded commit file list is fixed (phase A) — it now discovers
`apps/**/sealed-secret.yaml`. The remaining fragility is that all 21 keys are
sealed in one job, so one failing app's step can leave a partial commit.

Also worth carrying forward, both learned expensively:

- Never put a heredoc inside a `run: |` block scalar. It terminates the
  scalar and GitHub rejects the file before running anything — 0s duration,
  no logs, only "workflow file issue".
- `gh secret set --body -` writes the literal string `-`. `--body` takes a
  string; stdin is read only when `--body` is omitted. **Verify sealed values
  by length, not presence.**

Add a length assertion to the seal step so a one-character secret fails the
run instead of applying cleanly and looking healthy.

## C5 — Enforce what is currently advisory

**Risk: none to the cluster.**

Drop `continue-on-error` once each backlog is clear:

| Check | Repo | Status |
|---|---|---|
| Trivy image scan | home-harness | advisory |
| pip-audit | home-harness | advisory |
| gitleaks | both | advisory |
| ruff format | home-harness | advisory — 657 lines of churn, deliberate |
| Trivy config scan | arr-stack | advisory |
| tflint | arr-stack | advisory |
| shellcheck | arr-stack | advisory |

Ratchet `fail_under` in `home-harness/pyproject.toml` upward as coverage
rises. It is at 78 against a real 79.5% branch coverage.

## C6 — Observability

**Risk: low. Value: medium. Do last.**

There is no cluster monitoring: Grafana exists, but only for health metrics.
Nothing alerts when a pod crashloops, a PVC fills, or a certificate is about
to expire — the Let's Encrypt cert for `casa.calzadoskiruz.com` renews
automatically but nothing shouts if renewal fails.

kube-prometheus-stack is the obvious fit and can reuse the existing Grafana.
Start with three alerts that would actually have caught past incidents:
ArgoCD app not Synced, pod restart rate, and certificate expiry under 14 days.

---

## Not recommended

- **Branch protection requiring PRs.** Reasonable for a team; here it would
  mostly mean opening PRs to yourself, and the seal workflow pushes directly
  to master. The CI gates already run on push.
- **Terraform state backend.** `terraform/` is two files driving a
  `null_resource` over SSH. Remote state would add a dependency without
  solving a problem you have.
