#!/usr/bin/env bash
# ==============================================
# Push the values in secrets/.env to GitHub Actions secrets.
# ==============================================
# GitHub encrypts secrets with a libsodium sealed box before storing them,
# so this shells out to `gh`, which handles the crypto. Install it with:
#     sudo pacman -S github-cli && gh auth login
#
# Usage:
#   scripts/sync-github-secrets.sh                 # this repo only (the default,
#                                                  # and the only one that needs keys)
#   scripts/sync-github-secrets.sh --org my-org    # organization secrets
#   scripts/sync-github-secrets.sh --repo a/b --repo a/c
#   scripts/sync-github-secrets.sh --dry-run
# ==============================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/secrets/.env}"
ORG=""
DRY=0
REPOS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --org)     ORG="$2"; shift 2 ;;
    --repo)    REPOS+=("$2"); shift 2 ;;
    --env)     ENV_FILE="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ "$DRY" = "0" ]; then
  command -v gh >/dev/null || {
    echo "gh is required. Install it with: sudo pacman -S github-cli" >&2
    exit 1
  }
fi
[ -f "$ENV_FILE" ] || {
  echo "no $ENV_FILE — copy secrets/keys.env.example to secrets/.env first" >&2
  exit 1
}

# Values are stored as GitHub *secrets*, not variables, even the non-sensitive
# ones. Keeping the whole set in one place is worth more than the marginal
# convenience of variables, and the workflow reads them uniformly.
KEYS=$(grep -oE '^[A-Z_]+=' "$ENV_FILE" | tr -d '=' || true)
[ -n "$KEYS" ] || { echo "no KEY= lines found in $ENV_FILE" >&2; exit 1; }

# Default to the current repository when none was named.
if [ -z "$ORG" ] && [ ${#REPOS[@]} -eq 0 ]; then
  REPOS=("$(gh repo view --json nameWithOwner --jq .nameWithOwner)")
fi

echo "==> reading $ENV_FILE"
skipped=0
applied=0

for name in $KEYS; do
  # Read the value without sourcing the file, so a stray command in it
  # cannot execute.
  value=$(sed -n "s/^${name}=//p" "$ENV_FILE" | head -1)
  if [ -z "$value" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  if [ -n "$ORG" ]; then
    if [ "$DRY" = "1" ]; then
      echo "  [org $ORG] $name (${#value} chars)"
    else
      # No --body: gh reads the value from stdin. "--body -" does not mean
      # stdin, it sets the secret to the literal string "-".
      printf '%s' "$value" | gh secret set "$name" --org "$ORG" \
        --visibility selected --repos "$(IFS=,; echo "${REPOS[*]}")"
    fi
    applied=$((applied + 1))
  else
    for repo in "${REPOS[@]}"; do
      if [ "$DRY" = "1" ]; then
        echo "  [$repo] $name (${#value} chars)"
      else
        printf '%s' "$value" | gh secret set "$name" --repo "$repo"
      fi
    done
    applied=$((applied + 1))
  fi
done

echo
echo "✓ ${applied} secret(s) applied, ${skipped} skipped because they are empty."
[ "$DRY" = "1" ] && echo "  (dry run — nothing was written)"
echo
echo "Reminder: the test suites need no credentials. Only this repo's"
echo "Seal Secrets workflow consumes these values."
