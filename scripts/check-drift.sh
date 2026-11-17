#!/usr/bin/env bash
# =============================================================
#  ¿Sigue siendo válido mi override?
#
#  Compara el ML4W upstream de la versión base (guardada en
#  overrides/BASE_VERSION) con el último release. Si un fichero
#  que overrideo cambió upstream, avisa: hay que revisarlo antes
#  de que ML4W lo actualice y el blacklist te conserve una copia
#  vieja.
#
#  Uso: ./scripts/check-drift.sh [--quiet]
#  Exit: 0 sin drift (o sin red), 1 si hay drift.
# =============================================================
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

QUIET=0
[[ ${1:-} == "--quiet" ]] && QUIET=1

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    B=$'\033[1;34m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; D=$'\033[2m'; N=$'\033[0m'
else
    B=""; G=""; Y=""; R=""; D=""; N=""
fi
say() { ((QUIET)) || printf '%s\n' "$*"; }

REPO="mylinuxforwork/dotfiles"
LOCAL_PREFIX="overrides/.upstream"
BASE_VERSION="$(cat overrides/BASE_VERSION 2>/dev/null || echo desconocida)"

say "${B}━━ Drift de overrides${N}"
say "  base: ${BASE_VERSION}   repo upstream: ${REPO}"

# Versión instalada (puede estar desactualizada: no es fuente de verdad)
INSTALLED="desconocida"
if command -v jq >/dev/null 2>&1 && [[ -f $HOME/.config/ml4w/version.json ]]; then
    INSTALLED="$(jq -r '.Version // "desconocida"' "$HOME/.config/ml4w/version.json" 2>/dev/null)"
fi

# Último release
LATEST=""
if command -v curl >/dev/null 2>&1; then
    LATEST="$(curl -fsSL --max-time 20 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
        | jq -r '.tag_name // empty' 2>/dev/null)"
fi

if [[ -z $LATEST ]]; then
    say "  ${Y}!${N} sin red o API de GitHub no disponible; no puedo comprobar upstream"
    say "  ${D}↳ Reintenta más tarde o compara a mano contra el release que tengas instalado${N}"
    exit 0
fi

say "  instalado: ${INSTALLED}   último release: ${LATEST}"
if [[ $INSTALLED != "$BASE_VERSION" && $INSTALLED != "desconocida" ]]; then
    say "  ${Y}!${N} tu árbol declara ${INSTALLED}, pero los overrides se tomaron sobre ${BASE_VERSION}"
    say "  ${D}↳ Si ML4W se actualizó, revisa los overrides y actualiza overrides/BASE_VERSION${N}"
fi

if [[ $LATEST == "$BASE_VERSION" ]]; then
    say "  ${G}✔${N} upstream no ha cambiado desde la base"
    exit 0
fi

if ! find "$LOCAL_PREFIX" -type f -print -quit 2>/dev/null | grep -q .; then
    say "  ${Y}!${N} no hay copias en ${LOCAL_PREFIX}; no puedo comparar"
    exit 0
fi

DRIFT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

while IFS= read -r -d '' localfile; do
    rel="${localfile#"$LOCAL_PREFIX"/}"
    remote="https://raw.githubusercontent.com/${REPO}/${LATEST}/dotfiles/.config/${rel}"
    if ! curl -fsSL --max-time 20 "$remote" -o "$TMP/upstream" 2>/dev/null; then
        say "  ${Y}!${N} ${rel}: no existe en ${LATEST}"
        continue
    fi
    if cmp -s "$TMP/upstream" "$localfile"; then
        say "  ${G}✔${N} ${rel} (sin cambios)"
    else
        DRIFT=$((DRIFT + 1))
        say "  ${R}✘${N} ${rel} cambió upstream entre ${BASE_VERSION} y ${LATEST}"
        say "      ${D}↳ Revisa el diff y actualiza overrides/${rel}${N}"
        say "      ${D}  diff <(curl -fsSL ${remote}) overrides/.upstream/${rel}${N}"
    fi
done < <(find "$LOCAL_PREFIX" -type f -print0 2>/dev/null)

if ((DRIFT)); then
    say ""
    say "  ${R}${DRIFT} override(s) desfasados.${N} Actualiza el fichero en overrides/ y"
    say "  ${D}overrides/.upstream/, luego sube overrides/BASE_VERSION a ${LATEST}.${N}"
    exit 1
fi

say "  ${G}✔${N} overrides al día con ${LATEST}"
exit 0
