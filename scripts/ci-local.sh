#!/usr/bin/env bash
# Local CI gate used by git pre-push and agent pre-push loops.
# Detects project tooling and runs lint/format-check, tests, and build when available.
#
# Usage:
#   ./scripts/ci-local.sh
#   CI_LOCAL_SKIP_BUILD=1 ./scripts/ci-local.sh
#   CI_LOCAL_FORCE=1 ./scripts/ci-local.sh   # ignore .local-ci.json bypass
#
# Untracked `.local-ci.json` (see templates/local-ci.json.example):
#   bypass_pre_push, bypass_local_ci, run_ci_before_commit

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SKIP_BUILD="${CI_LOCAL_SKIP_BUILD:-0}"
FORCE="${CI_LOCAL_FORCE:-0}"
HOOK_KIND="${CI_LOCAL_FROM_HOOK:-}"
FAILED=0

LOCAL_CI_JSON="$ROOT/.local-ci.json"
if [[ -f "$LOCAL_CI_JSON" ]] && command -v python3 >/dev/null 2>&1; then
  eval "$(python3 - "$LOCAL_CI_JSON" <<'PY'
import json, sys
path = sys.argv[1]
defaults = {
    "bypass_pre_push": False,
    "bypass_local_ci": False,
    "run_ci_before_commit": False,
}
try:
    with open(path) as f:
        data = {**defaults, **json.load(f)}
except Exception:
    data = defaults
for k, v in data.items():
    print(f"{k}={1 if v else 0}")
PY
)"
else
  bypass_pre_push=0
  bypass_local_ci=0
  run_ci_before_commit=0
fi

if [[ "$HOOK_KIND" == "pre-commit" && "${run_ci_before_commit:-0}" != "1" ]]; then
  exit 0
fi

if [[ "$FORCE" != "1" ]]; then
  if [[ "${bypass_local_ci:-0}" == "1" ]]; then
    echo "ci-local: skipped (.local-ci.json bypass_local_ci)"
    exit 0
  fi
  if [[ "$HOOK_KIND" == "pre-push" && "${bypass_pre_push:-0}" == "1" ]]; then
    echo "ci-local: skipped (.local-ci.json bypass_pre_push)"
    exit 0
  fi
fi

run_step() {
  local name="$1"
  shift
  echo "==> $name"
  if "$@"; then
    echo "OK: $name"
  else
    echo "FAIL: $name" >&2
    FAILED=1
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

npm_script_exists() {
  local script="$1"
  [[ -f package.json ]] || return 1
  node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts['$script'] ? 0 : 1)" 2>/dev/null
}

# --- Elixir / Mix ---
if [[ -f mix.exs ]]; then
  if have mix; then
    run_step "mix format --check-formatted" mix format --check-formatted
    if mix help credo >/dev/null 2>&1; then
      run_step "mix credo" mix credo --strict
    fi
    run_step "mix test" mix test
    if [[ "$SKIP_BUILD" != "1" ]]; then
      run_step "mix compile --warnings-as-errors" mix compile --warnings-as-errors
    fi
  else
    echo "WARN: mix.exs present but mix not installed" >&2
    FAILED=1
  fi
fi

# --- Node / npm | pnpm | yarn ---
if [[ -f package.json ]]; then
  PKG=()
  if [[ -f pnpm-lock.yaml ]] && have pnpm; then
    PKG=(pnpm)
  elif [[ -f yarn.lock ]] && have yarn; then
    PKG=(yarn)
  elif have npm; then
    PKG=(npm)
  else
    echo "WARN: package.json present but no npm/pnpm/yarn" >&2
    FAILED=1
    PKG=()
  fi

  if [[ ${#PKG[@]} -gt 0 ]]; then
    if npm_script_exists lint; then
      if [[ "${PKG[0]}" == "npm" ]]; then
        run_step "npm run lint" npm run lint
      else
        run_step "${PKG[0]} lint" "${PKG[@]}" run lint
      fi
    fi
    if npm_script_exists test; then
      if [[ "${PKG[0]}" == "npm" ]]; then
        run_step "npm test" npm test
      else
        run_step "${PKG[0]} test" "${PKG[@]}" test
      fi
    fi
    if [[ "$SKIP_BUILD" != "1" ]] && npm_script_exists build; then
      if [[ "${PKG[0]}" == "npm" ]]; then
        run_step "npm run build" npm run build
      else
        run_step "${PKG[0]} build" "${PKG[@]}" run build
      fi
    fi
  fi
fi

# --- Python ---
if [[ -f pyproject.toml || -f pytest.ini || -f setup.py ]]; then
  if have pytest; then
    run_step "pytest" pytest
  elif have python3 && python3 -c "import pytest" 2>/dev/null; then
    run_step "python3 -m pytest" python3 -m pytest
  else
    echo "WARN: Python project markers present but pytest unavailable" >&2
  fi
  if have ruff; then
    run_step "ruff check" ruff check .
  fi
fi

# --- Go ---
if [[ -f go.mod ]]; then
  if have go; then
    run_step "go test ./..." go test ./...
    if [[ "$SKIP_BUILD" != "1" ]]; then
      run_step "go build ./..." go build ./...
    fi
  else
    echo "WARN: go.mod present but go not installed" >&2
    FAILED=1
  fi
fi

# --- Makefile targets (optional extras) ---
if [[ -f Makefile ]] && have make; then
  if grep -qE '^ci:' Makefile; then
    run_step "make ci" make ci
  elif grep -qE '^check:' Makefile; then
    run_step "make check" make check
  fi
fi

# --- GitHub Actions workflow sanity (presence only; does not run Actions) ---
if [[ -d .github/workflows ]]; then
  echo "==> CI workflows present under .github/workflows"
  find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -print
fi

# --- UI lock (design language / CSS / icons / tokens) ---
if [[ -f "$ROOT/scripts/ui-check.sh" ]]; then
  chmod +x "$ROOT/scripts/ui-check.sh" 2>/dev/null || true
  run_step "ui-check" "$ROOT/scripts/ui-check.sh"
elif [[ -f "$ROOT/scripts/ui-check.py" ]]; then
  run_step "ui-check" python3 "$ROOT/scripts/ui-check.py" "$ROOT"
fi

if [[ "$FAILED" -ne 0 ]]; then
  echo "ci-local: FAILED" >&2
  exit 1
fi

echo "ci-local: PASSED"
exit 0
