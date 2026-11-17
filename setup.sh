#!/usr/bin/env bash
# =============================================================
#  Instalador interactivo (TUI) del overlay.
#
#  Detecta Go; si no está, descarga la última versión estable en
#  ~/.local/share/dotfiles/go (sin sudo, con verificación sha256).
#  Compila tui/ (bubbletea + bubbles) y lo ejecuta.
#
#  Uso:
#    ./setup.sh                # TUI
#    ./setup.sh --list         # estado, sin TUI (no necesita TTY)
#    ./setup.sh --classic      # install.sh de siempre
#    ./setup.sh --rebuild      # fuerza recompilar la TUI
#    ./setup.sh --classic --dry-run
# =============================================================
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${DOTFILES_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles}"
GO_ROOT="$DATA_DIR/go"
BIN="$DATA_DIR/bin/dotfiles-tui"
MIN_GO="1.22"

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    B=$'\033[1;34m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; D=$'\033[2m'; N=$'\033[0m'
else
    B=""; G=""; Y=""; R=""; D=""; N=""
fi
info() { printf '  %s::%s %s\n' "$B" "$N" "$*" >&2; }
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*" >&2; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '  %s✘%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
gum_on() { have gum && [[ -t 0 && -t 1 ]]; }

# -------------------------------------------------------------
# Argumentos
# -------------------------------------------------------------
CLASSIC=0
REBUILD=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --classic|--no-tui) CLASSIC=1 ;;
        --rebuild) REBUILD=1 ;;
        -h|--help)
            awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
            exit 0 ;;
        *) ARGS+=("$arg") ;;
    esac
done

# -------------------------------------------------------------
# Fallbacks
# -------------------------------------------------------------
run_classic() {
    exec bash "$ROOT/install.sh" "${ARGS[@]}"
}

((CLASSIC)) && run_classic

# Sin TTY solo dejamos pasar --list; el resto va al modo clásico.
if [[ ! -t 0 && " ${ARGS[*]-} " != *" --list "* ]]; then
    warn "sin terminal interactiva; usando install.sh"
    run_classic
fi

if [[ ${ARGS[0]-} == "--list" ]]; then
    # --list no necesita Go si ya hay binario.
    if [[ -x $BIN ]]; then
        DOTFILES_ROOT="$ROOT" exec "$BIN" "${ARGS[@]}"
    fi
fi

# -------------------------------------------------------------
# Go
# -------------------------------------------------------------
version_ge() { # <actual> <min>
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

go_usable() {
    local bin="$1" v
    [[ -x $bin ]] || return 1
    v="$("$bin" version 2>/dev/null | awk '{print $3}' | sed 's/^go//')"
    [[ -n $v ]] && version_ge "$v" "$MIN_GO"
}

install_go() {
    local arch file version sha tmp
    case "$(uname -m)" in
        x86_64|amd64) arch=amd64 ;;
        aarch64|arm64) arch=arm64 ;;
        *) die "arquitectura no soportada: $(uname -m)" ;;
    esac

    for dep in curl jq tar sha256sum; do
        have "$dep" || die "falta $dep; instala: sudo pacman -S $dep"
    done

    info "buscando la última versión estable de Go…"
    local json
    json="$(curl -fsSL --retry 3 'https://go.dev/dl/?mode=json')" \
        || die "no pude consultar go.dev (¿sin red?). Alternativa: sudo pacman -S go"

    version="$(jq -r '.[0].version' <<<"$json")"
    file="$(jq -r --arg a "$arch" '.[0].files[] | select(.os=="linux" and .arch==$a and .kind=="archive") | .filename' <<<"$json")"
    sha="$(jq -r --arg a "$arch" '.[0].files[] | select(.os=="linux" and .arch==$a and .kind=="archive") | .sha256' <<<"$json")"
    [[ -n $file && $file != null && -n $sha && $sha != null ]] \
        || die "no encontré un tarball de Go para linux/$arch"

    if gum_on; then
        gum confirm "Go no está instalado. ¿Descargar $version (~80 MB) en $GO_ROOT?" \
            || die "cancelado. Alternativa: sudo pacman -S go y repite"
    else
        printf '  %sGo no está instalado. ¿Descargar %s (~80 MB)? [S/n] %s' "$Y" "$version" "$N"
        read -r answer
        [[ ${answer:-s} =~ ^[SsYy]$ ]] || die "cancelado. Alternativa: sudo pacman -S go"
    fi

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    if gum_on; then
        gum spin --spinner dot --title "Descargando $version…" -- \
            curl -fsSL --retry 3 -o "$tmp/$file" "https://go.dev/dl/$file" \
            || die "falló la descarga de $file"
    else
        info "descargando $file…"
        curl -fsSL --retry 3 -o "$tmp/$file" "https://go.dev/dl/$file" \
            || die "falló la descarga de $file"
    fi

    ( cd "$tmp" && printf '%s  %s\n' "$sha" "$file" | sha256sum -c - ) \
        || die "el sha256 de Go no coincide; descarga abortada"

    mkdir -p "$GO_ROOT"
    rm -rf "$GO_ROOT/$version"
    tar -C "$tmp" -xzf "$tmp/$file" || die "no pude extraer $file"
    mv "$tmp/go" "$GO_ROOT/$version" || die "no pude mover Go a $GO_ROOT/$version"
    ln -sfn "$version" "$GO_ROOT/current"
    ok "Go $version instalado en $GO_ROOT/$version"
}

GO_BIN=""
if go_usable "$GO_ROOT/current/bin/go"; then
    GO_BIN="$GO_ROOT/current/bin/go"
elif go_usable "$(command -v go 2>/dev/null || echo /nonexistent)"; then
    GO_BIN="$(command -v go)"
else
    install_go
    GO_BIN="$GO_ROOT/current/bin/go"
fi

export GOROOT="$("$GO_BIN" env GOROOT)"
export PATH="$GOROOT/bin:$PATH"
export GOTOOLCHAIN=local

# -------------------------------------------------------------
# Compilar la TUI
# -------------------------------------------------------------
needs_build() {
    ((REBUILD)) && return 0
    [[ -x $BIN ]] || return 0
    [[ -n "$(find "$ROOT/tui" -type f \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' \) -newer "$BIN" -print -quit)" ]]
}

build_tui() {
    mkdir -p "$DATA_DIR/bin" || die "no pude crear $DATA_DIR/bin"
    info "compilando TUI con $( "$GO_BIN" version | awk '{print $3}' )…"
    if gum_on; then
        ( cd "$ROOT/tui" && gum spin --spinner dot --title "Compilando TUI…" -- \
            "$GO_BIN" build -o "$BIN" . ) || die "falló la compilación (prueba ./setup.sh --classic)"
    else
        ( cd "$ROOT/tui" && "$GO_BIN" build -o "$BIN" . ) \
            || die "falló la compilación (prueba ./setup.sh --classic)"
    fi
    ok "TUI lista en $BIN"
}

if needs_build; then
    build_tui
fi

# -------------------------------------------------------------
# Ejecutar
# -------------------------------------------------------------
DOTFILES_ROOT="$ROOT" exec "$BIN" "${ARGS[@]}"
