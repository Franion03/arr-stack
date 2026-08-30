# harness

Deployment of the [home-harness](https://github.com/Franion03/home-harness)
assistant — an LLM-agnostic agent with voice, Home Assistant and Google
Calendar tools.

**Application code is not here.** It lives in its own repo and is built to
`ghcr.io/franion03/home-harness:latest` by that repo's CI. This directory is
only how it gets deployed on this cluster.

| Concern | Where |
|---|---|
| Python source, Dockerfile, tests | `Franion03/home-harness` |
| Deployment, ingress, storage, secrets | here |

Runs in namespace **`assistant`**, not `media`. `arr-stack-root`'s destination
namespace is `media`, so `kustomization.yaml` pins `assistant` explicitly.

## Swapping the LLM

`models.yaml` is the swap point — no code change, no rebuild:

```yaml
routes:
  chat:
    primary: anthropic/claude-opus-5     # ← change this line
    fallback: openai/gpt-4o
```

Commit and push; ArgoCD syncs, the ConfigMap hash changes, the pod rolls.
For an immediate change with no restart:

```bash
curl -XPOST -H "X-API-Key: $KEY" http://assistant.192.168.1.114.nip.io/v1/admin/reload
```

Speech works the same way — `stt:` and `tts:` are model references with
fallbacks, exactly like the chat routes.

## Secrets

Local bootstrap:

```bash
export ANTHROPIC_API_KEY=... HA_TOKEN=... HARNESS_API_KEY=...
scripts/create-harness-secret.sh
```

GitOps: put the same values in GitHub Secrets, run the **Seal Secrets**
workflow. It seals them to `sealed-secret.yaml` here and adds that file to
`kustomization.yaml` on the first run.

`GET /health` reports which integrations came up, so a missing credential is
visible rather than silent.
