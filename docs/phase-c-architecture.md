# Phase C — architecture changes, pending approval

Phases A (quality gates) and B (security scanning) are merged and additive:
they cannot affect the running cluster. Everything below **modifies a repo
that ArgoCD auto-syncs with `prune` and `selfHeal` against the live house**.

Ordered by value per unit of risk. Each item is independently shippable.

| Item | Status |
|---|---|
| C1 — ApplicationSet split | **pending** — needs a maintenance window |
| C2 — digest pinning | **done** |
| C3 — NetworkPolicies | **done for `health`**; `media` still open |
| C4 — seal workflow | **length tripwire done**; per-app split pending |
| C5 — enforce advisory checks | pending — waiting on the first CI runs |
| C6 — observability | pending |

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

## C2 — Pin every image by digest — DONE

**Risk: low. Value: high.**

This item originally said three images. That was wrong: it had been written
from a grep of `apps/assistant/` only. The mutable-tag check added in phase A
found **thirteen**, across the whole stack — the media apps too.

Every one is now pinned as `tag@sha256:...`, keeping the tag for readability
while the digest decides what actually runs. Each digest was taken from the
`imageID` of the **container already running in the cluster**, and each was
verified resolvable in its registry before being written, so no pin points at
something unpullable.

`imagePullPolicy: Always` became `IfNotPresent` on the two deployments that
had it — a digest is immutable, so re-pulling on every start buys nothing.

**This is not a no-op rollout.** Changing the image string changes the pod
template, so all thirteen workloads roll once when ArgoCD syncs. They roll
onto byte-identical images, so nothing changes version; expect one restart
each and a few minutes of media-stack churn. `kubectl diff -k apps/` was
confirmed to contain *only* these image lines and the two pull policies.

One gotcha worth recording: `lscr.io` digests appear unresolvable if you ask
`lscr.io/token` for the auth token. lscr.io is ghcr.io-backed — its
`www-authenticate` header points at `https://ghcr.io/token`, and the digests
resolve fine with a ghcr token.

Why it mattered: a mutable tag means no rollback target, no drift detection
(ArgoCD reports Synced while the running image differs from what anyone
believes is deployed), and pods that only change on an unrelated restart — so
a bad upstream push lands at the worst possible moment.

`renovate.json` opens the bump PRs. Dependabot cannot do this job: it reads
only Dockerfiles and docker-compose, never Kubernetes manifests. **It needs
the Renovate GitHub App installed on the repository to do anything.** The
media stack is grouped into one PR; the three assistant images get individual
PRs so each can be reverted alone, and `open-webui` is de-prioritised and
never automerged because `main` is a development branch.

The home-harness build workflow prints each new digest to its job summary, so
bumping that one by hand is a copy-paste if Renovate is not installed.

## C3 — Default-deny NetworkPolicies per namespace — DONE for `health`

**Risk: low. Value: high for `health` specifically.**

`health` holds body metrics in InfluxDB with an Ingress exposed on the LAN,
in a cluster that also runs a Cloudflare tunnel, and had no policy at all —
any pod anywhere could read or write the whole bucket. It is also the only
durable copy: Health Connect prunes itself after ~30 days.

`apps/health/network-policy.yaml` adds `default-deny-ingress` plus explicit
allows. The trap this section warned about was real and nearly sprung: the
allow list is **three** clients, not two. Besides Grafana and the ingress
controller, the harness reads InfluxDB directly over cluster DNS at
`influxdb.health.svc.cluster.local:8086` — not through the Ingress. An
ingress-controller-only policy would have silently broken "how did I sleep
last week" while every dashboard kept working.

Verified before committing: all five selectors resolve to real pods, and the
harness→InfluxDB path returns HTTP 204 today. Re-run that probe after the
sync:

```
kubectl exec -n assistant deploy/harness -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://influxdb.health.svc.cluster.local:8086/ping', timeout=8).status)"
```

Ingress-only, deliberately: an egress policy would also have to allow DNS, and
getting that wrong breaks InfluxDB in a way that looks like a storage fault.

**Still open:** the `media` namespace has no policy.

## C4 — Seal workflow hardening — length tripwire DONE

**Risk: low. Value: medium.**

The hardcoded commit file list is fixed (phase A) — it now discovers
`apps/**/sealed-secret.yaml`.

Worth carrying forward, both learned expensively:

- Never put a heredoc inside a `run: |` block scalar. It terminates the
  scalar and GitHub rejects the file before running anything — 0s duration,
  no logs, only "workflow file issue".
- `gh secret set --body -` writes the literal string `-`. `--body` takes a
  string; stdin is read only when `--body` is omitted. **Verify sealed values
  by length, not presence.**

The length assertion is in: a non-empty secret shorter than 4 characters now
fails the run with the offending key names, instead of sealing cleanly and
applying to the cluster looking perfectly healthy. Empty values still pass —
an unconfigured optional vendor is legitimate — and the shortest real value,
`GOOGLE_CALENDAR_ID="primary"`, is 7.

**Still open:** all 21 keys are sealed in one job, so one failing app's step
can still leave a partial commit.

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

---

## Incident 2026-09-01 — cloudflared tunnel down after the C2 rollout

**What broke.** The media tunnel is down. `cloudflared` crashloops with
`Provided Tunnel token is not valid.`, and `jellyfin.calzadoskiruz.com`
returns 530.

**Root cause, which predates this work.** `apps/cloudflared/sealed-secret.yaml`
has contained `PLACEHOLDER_...` (35 chars) since `3c7c725`, the original
secrets-pipeline commit — it has never been changed since. ArgoCD applied that
placeholder Secret to the cluster, but the running pod had started
2026-05-10 and a container reads its environment **once, at start**. So the
pod kept serving with the real token for 114 days while the Secret behind it
was worthless.

**What triggered it.** Pinning images by digest (C2) changed the pod template,
which is exactly the "unrelated restart" that section warned about. The
Deployment rolled, the 114-day-old pod was replaced, and the new one read the
placeholder. The working token existed only in that container's environment
and went away with it.

**Recovery — needs the Cloudflare dashboard.** The value is not in
`secrets/.env`, not in git, and not recoverable from the cluster:

1. Cloudflare Zero Trust → Networks → Tunnels → the tunnel → Configure, and
   copy the token (or rotate it).
2. GitHub → `Franion03/arr-stack` → Settings → Secrets and variables →
   Actions → set `CLOUDFLARE_TUNNEL_TOKEN`.
3. Actions → Seal Secrets → **Run workflow** (the cloudflared step is
   `workflow_dispatch`-only by design).
4. ArgoCD applies it, then `kubectl rollout restart deploy/cloudflared -n media`.

**Prevention, now in the seal workflow.** The cloudflared step refuses to seal
a value containing `PLACEHOLDER`/`changeme` or shorter than 60 characters, and
the harness loop's tripwire catches placeholder-shaped values as well as short
ones.

**The general lesson.** A Secret being wrong is invisible for as long as the
pod does not restart, and `kubectl get secret` shows a healthy-looking object
either way. An audit of every Secret in the cluster found this was the only
placeholder — the other empty keys are unconfigured optional vendors
(Groq, Deepgram, ElevenLabs, OpenAI, CF Workers AI) and
`GOOGLE_CALENDAR_ID="primary"`.
