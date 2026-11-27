#!/usr/bin/env bash
# =============================================================
#  Validación barata: sintaxis de bash/lua/json y shellcheck
#  si está instalado. No escribe nada.
#  Uso: ./scripts/check.sh
# =============================================================
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    B=$'\033[1;34m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; D=$'\033[2m'; N=$'\033[0m'
else
    B=""; G=""; Y=""; R=""; D=""; N=""
fi

ERRORS=0
check() {
    local desc="$1"
    shift
    if "$@" >/tmp/dotfiles-check.$$ 2>&1; then
        printf '  %s✔%s %s\n' "$G" "$N" "$desc"
    else
        printf '  %s✘%s %s\n' "$R" "$N" "$desc"
        sed 's/^/      /' /tmp/dotfiles-check.$$ | head -20
        ERRORS=$((ERRORS + 1))
    fi
    rm -f /tmp/dotfiles-check.$$
}

printf '%s━━ Sintaxis bash %s\n' "$B" "$N"
BASH_FILES=(
    "install.sh"
    "setup.sh"
    "bootstrap/tools.sh"
    "lib/manifest.sh"
    "scripts/check.sh"
    "scripts/check-drift.sh"
    "scripts/snapshot.sh"
    "scripts/status.sh"
    "overlay/.bash_profile"
    "overlay/.bashrc_custom"
    "overlay/.blerc"
    "overlay/.config/bashrc-custom"
    "overlay/.config/bashrc/custom/00-init"
    "overlay/.config/ml4w/scripts/ml4w-toggle-no-suspend"
    "overlay/.config/tmux/menu.sh"
    "overlay/.config/lf/preview"
    "overlay/.config/lf/cleaner"
    "overrides/ml4w/settings/browser.sh"
    "overrides/ml4w/settings/editor.sh"
    "overrides/ml4w/settings/terminal.sh"
)
for f in "${BASH_FILES[@]}"; do
    [[ -f $f ]] || { printf '  %s!%s falta %s\n' "$Y" "$N" "$f"; continue; }
    check "bash -n $f" bash -n "$f"
done

printf '%s━━ Sintaxis lua %s\n' "$B" "$N"
if command -v luac >/dev/null 2>&1; then
    while IFS= read -r -d '' f; do
        check "luac -p $f" luac -p "$f"
    done < <(find overlay overrides hosts -name '*.lua' -print0 2>/dev/null)
else
    printf '  %s!%s luac no instalado; se omite la comprobación lua (sudo pacman -S lua)\n' "$Y" "$N"
fi

printf '%s━━ JSON %s\n' "$B" "$N"
if command -v jq >/dev/null 2>&1; then
    while IFS= read -r -d '' f; do
        check "jq empty $f" jq empty "$f"
    done < <(find . -name '*.json' -not -path './.git/*' -print0 2>/dev/null)
else
    printf '  %s!%s jq no instalado; se omite\n' "$Y" "$N"
fi

printf '%s━━ shellcheck %s\n' "$B" "$N"
if command -v shellcheck >/dev/null 2>&1; then
    for f in "${BASH_FILES[@]}"; do
        [[ -f $f ]] || continue
        check "shellcheck $f" shellcheck -x -S warning "$f"
    done
else
    printf '  %s!%s shellcheck no instalado; se omite (sudo pacman -S shellcheck)\n' "$Y" "$N"
fi

printf '%s━━ Go (TUI) %s\n' "$B" "$N"
GO_BIN="$(command -v go 2>/dev/null || true)"
GO_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/go/current/bin/go"
[[ -z $GO_BIN && -x $GO_DATA ]] && GO_BIN="$GO_DATA"
if [[ -n $GO_BIN ]]; then
    GOFMT="$(dirname "$GO_BIN")/gofmt"
    check "gofmt tui/ (sin cambios)" bash -c 'out=$("$1" -l tui); [[ -z $out ]] || { printf "%s\n" "$out"; exit 1; }' _ "$GOFMT"
    check "go vet ./..." bash -c 'cd tui && "$1" vet ./...' _ "$GO_BIN"
else
    printf '  %s!%s Go no instalado; se omite (lo instala ./setup.sh)\n' "$Y" "$N"
fi

printf '\n'
if ((ERRORS)); then
    printf '%s✘ %d problema(s) de validación%s\n' "$R" "$ERRORS" "$N"
    exit 1
fi
printf '%s✔ Validación limpia%s\n' "$G" "$N"
