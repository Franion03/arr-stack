# assistant

The house assistant: **Open WebUI** for everything a chat app needs, and a
small **tool server** for the one thing it cannot do — the house.

```
        ingress (assistant.192.168.1.114.nip.io)
                        │
              [ openwebui ]   UI · sessions · auth · voice · model routing
                 │      │                                    ← PVC 8Gi
                 │      └── models ──▶ Cloudflare AI Gateway ──▶ Anthropic
                 │
                 └── tools ──▶ [ harness ]   Home Assistant + Google Calendar
                                             ClusterIP only, no ingress
```

| Service | Image | Repo |
|---|---|---|
| `openwebui` | `ghcr.io/open-webui/open-webui:main` | upstream |
| `harness` | `ghcr.io/franion03/home-harness` | [home-harness](https://github.com/Franion03/home-harness) |

Runs in namespace **`assistant`**, not `media`. `arr-stack-root`'s destination
namespace is `media`, so `kustomization.yaml` pins `assistant`.

## Why so little of this is ours

Open WebUI already provides conversation storage, authentication, streaming,
voice in and out, model management and document RAG. Writing a bespoke UI and
API for that is work with no payoff. What is genuinely ours is control of the
house, and that is the only thing in this namespace we maintain.

## Wiring the tools

Open WebUI does not discover the tool server on its own. Once, after the first
deploy:

**Settings → Admin → Integrations → Tool Servers → +**

```
URL       http://harness.assistant.svc.cluster.local
Auth      Bearer   <TOOLS_API_KEY>
```

It fetches `/openapi.json` and turns each of the nine operations into a tool.
Adding it under *Admin* shares it with every user; adding it under personal
*Settings → Tools* keeps it to one account.

## Swapping the model

`openwebui/configmap.yaml` is the swap point. Both URLs point at the
Cloudflare AI Gateway, so caching, cost analytics and rate limiting apply
whichever vendor answers:

```
https://gateway.ai.cloudflare.com/v1/<account>/home-harness/anthropic/v1
                                                ▲
                          change this segment and the matching key
```

| Provider segment | Key to point `OPENAI_API_KEY` at |
|---|---|
| `anthropic` | `ANTHROPIC_API_KEY` |
| `openai` | `OPENAI_API_KEY` |
| `google-ai-studio` | `GOOGLE_AI_API_KEY` |
| `openrouter` | `OPENROUTER_API_KEY` |

Open WebUI reaches Anthropic through its OpenAI-compatible endpoint, so
streaming, multi-turn and tool calling all work without a shim. Set the URL to
a vendor's own host to bypass the gateway entirely.

## Security posture

The tool server can turn off the heating, unlock a door and delete calendar
events. So:

- it has **no Ingress** — ClusterIP only
- a **NetworkPolicy** admits only Open WebUI; nothing else in the cluster,
  including the media namespace, can reach it
- it runs read-only-root, non-root, all capabilities dropped
- it holds **no model-vendor keys**; Open WebUI holds no Home Assistant token

Each pod is handed only the secret keys it uses, by name.

## Secrets

One Secret, `harness-secrets`. The canonical list is
`secrets/keys.env.example` at the repo root.

```bash
set -a && . secrets/.env && set +a
scripts/create-harness-secret.sh
```

`WEBUI_SECRET_KEY` must stay stable — changing it logs every user out.

For GitOps, put the values in this repo's GitHub Secrets and run **Seal
Secrets**.

## Checking it

```bash
kubectl -n assistant get pods
kubectl -n assistant exec deploy/openwebui -- \
  curl -s http://harness/health          # tool server, from where it is allowed
```
