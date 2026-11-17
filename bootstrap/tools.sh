#!/usr/bin/env bash
# =============================================================
#  Herramientas que no vienen de pacman.
#  Idempotente: si ya están, no hace nada.
#  Versiones fijadas para que una máquina nueva quede igual.
# =============================================================
set -uo pipefail

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    esac
done

OMP_VERSION="${OMP_VERSION:-29.36.0}"
NVM_VERSION="${NVM_VERSION:-v0.40.4}"
LOCAL_BIN="$HOME/.local/bin"

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    B=$'\033[1;34m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; D=$'\033[2m'; N=$'\033[0m'
else
    B=""; G=""; Y=""; R=""; D=""; N=""
fi

FAILED=0
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
info() { printf '  %s::%s %s\n' "$B" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
bad()  { printf '  %s✘%s %s\n' "$R" "$N" "$*"; FAILED=1; }

have() { command -v "$1" >/dev/null 2>&1; }

# -------------------------------------------------------------
# oh-my-posh (binario suelto en ~/.local/bin)
# -------------------------------------------------------------
install_omp() {
    if have oh-my-posh; then
        ok "oh-my-posh $(oh-my-posh --version 2>/dev/null || echo '')"
        return
    fi
    if [[ -x $LOCAL_BIN/oh-my-posh ]]; then
        ok "oh-my-posh $("$LOCAL_BIN/oh-my-posh" --version 2>/dev/null || echo '') en $LOCAL_BIN"
        return
    fi

    local arch
    case "$(uname -m)" in
        x86_64|amd64) arch=amd64 ;;
        aarch64|arm64) arch=arm64 ;;
        *) bad "arquitectura no soportada por oh-my-posh: $(uname -m)"; return ;;
    esac

    local url="https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${OMP_VERSION}/posh-linux-${arch}"
    if ((DRY_RUN)); then
        info "[dry-run] descargar $url -> $LOCAL_BIN/oh-my-posh"
        return
    fi

    mkdir -p "$LOCAL_BIN" || { bad "no se pudo crear $LOCAL_BIN"; return; }
    if curl -fsSL --retry 3 -o "$LOCAL_BIN/oh-my-posh.tmp" "$url"; then
        chmod +x "$LOCAL_BIN/oh-my-posh.tmp" &&
            mv "$LOCAL_BIN/oh-my-posh.tmp" "$LOCAL_BIN/oh-my-posh" &&
            ok "oh-my-posh $OMP_VERSION instalado en $LOCAL_BIN" ||
            bad "no se pudo mover el binario a $LOCAL_BIN"
    else
        bad "no se pudo descargar oh-my-posh $OMP_VERSION"
        printf '    %s↳ Comprueba red/proxy o instálalo así: yay -S oh-my-posh-bin%s\n' "$D" "$N"
    fi
}

# -------------------------------------------------------------
# nvm
# -------------------------------------------------------------
install_nvm() {
    if [[ -s $HOME/.nvm/nvm.sh ]]; then
        ok "nvm instalado en ~/.nvm"
        return
    fi
    if ((DRY_RUN)); then
        info "[dry-run] git clone --branch $NVM_VERSION https://github.com/nvm-sh/nvm.git ~/.nvm"
        return
    fi
    if git clone --depth 1 --branch "$NVM_VERSION" https://github.com/nvm-sh/nvm.git "$HOME/.nvm"; then
        ok "nvm $NVM_VERSION instalado"
    else
        bad "no se pudo clonar nvm $NVM_VERSION"
        printf '    %s↳ Comprueba red o instálalo con: yay -S nvm%s\n' "$D" "$N"
    fi
}

# -------------------------------------------------------------
# Avisos para binarios que no se pueden automatizar aquí
# -------------------------------------------------------------
check_optional() {
    local bin="$1" hint="$2"
    if have "$bin"; then
        ok "$bin"
    else
        warn "falta $bin — $hint"
    fi
}

printf '%s━━ Herramientas %s\n' "$B" "$N"
install_omp
install_nvm

check_optional bun         "instálalo con: yay -S bun-bin"
check_optional pnpm        "instálalo con: sudo pacman -S pnpm  (o corepack enable)"
check_optional rustup      "instálalo con: sudo pacman -S rustup && rustup default stable"
check_optional opencode    "instálalo con: curl -fsSL https://opencode.ai/install | bash"
check_optional claude      "instálalo con: npm i -g @anthropic-ai/claude-code"
check_optional codex       "instálalo con: npm i -g @openai/codex"
check_optional lf          "instálalo con: sudo pacman -S lf"
check_optional hunk        "instálalo con: yay -S hunk"

exit "$FAILED"
