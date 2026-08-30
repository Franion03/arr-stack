# secrets

One list of credentials, three destinations.

`keys.env.example` is the canonical inventory. Copy it to `.env` here — that
file is gitignored and must never be committed — fill it in once, and use it
for all three:

| Destination | How | What needs it |
|---|---|---|
| **Local dev** | `set -a && . secrets/.env && set +a` | running any service on your machine |
| **The cluster** | `scripts/create-harness-secret.sh` | bootstrapping, before GitOps |
| **GitHub** | `scripts/sync-github-secrets.sh` | the Seal Secrets workflow |

## Tests do not need credentials

All 103 tests across the three repos are stubbed — the harness fakes its
gateway, the backend fakes the harness with `httpx.MockTransport`, the web
tests are pure functions. **CI passes with no secrets configured at all.**

So do not add vendor keys to `home-harness`, `home-harness-backend` or
`home-harness-web` "so the tests can run". It would widen the blast radius of
a leak for no benefit. Real values are needed in exactly one place: this
repo's Seal Secrets workflow.

## Sharing secrets across repos properly

GitHub has no way to share secrets between repositories owned by a **personal
account** — each repo carries its own copy. The supported mechanism is an
**organization secret**, which requires an organization (free):

1. github.com/organizations/plan → create a free org, e.g. `franion-lab`
2. Transfer the repos into it (Settings → Danger Zone → Transfer)
3. Org Settings → Secrets and variables → Actions → **New organization secret**
4. Set *Repository access* to **Selected repositories** — grant each secret
   only to the repo that actually needs it

Then one update propagates everywhere, and `sync-github-secrets.sh --org`
writes them in one pass.

Until then the script's per-repo mode does the same job by writing the same
value to each repo you name — which, given the note above, should really only
be this one.
