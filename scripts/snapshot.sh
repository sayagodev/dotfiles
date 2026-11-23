#!/usr/bin/env bash
# =============================================================
#  Snapshot del sistema -> repo.
#
#  Regenera:
#    packages/native.txt   (explícitos de pacman, sin los de hosts/)
#    packages/aur.txt
#    packages/flatpak.txt
#    system/services.txt
#    system/groups.txt
#    system/user-units.txt
#
#  Y detecta overrides que hayan cambiado en el árbol de ML4W
#  (por ejemplo, al tocar ajustes con la app de ML4W).
#
#  Uso:
#    ./scripts/snapshot.sh            # solo informa de diferencias
#    ./scripts/snapshot.sh --update   # copia las diferencias a overrides/
#    ./scripts/snapshot.sh --dry-run
# =============================================================
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

DRY_RUN=0
UPDATE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --update) UPDATE=1 ;;
        -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    esac
done

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    B=$'\033[1;34m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; D=$'\033[2m'; N=$'\033[0m'
else
    B=""; G=""; Y=""; R=""; D=""; N=""
fi

HOST="${DOTFILES_HOST:-$(cat /etc/hostname 2>/dev/null || uname -n)}"
say() { printf '%s\n' "$*"; }

write_file() { # <ruta> <contenido por stdin>
    local target="$1"
    if ((DRY_RUN)); then
        say "  ${B}::${N} [dry-run] escribir $target"
        cat >/dev/null
        return
    fi
    local tmp
    tmp="$(mktemp)"
    cat >"$tmp"
    if cmp -s "$tmp" "$target" 2>/dev/null; then
        say "  ${G}✔${N} $target (sin cambios)"
        rm -f "$tmp"
        return
    fi
    if install -Dm644 "$tmp" "$target"; then
        say "  ${G}✔${N} $target actualizado"
    else
        say "  ${R}✘${N} no se pudo escribir $target (revisa permisos)"
    fi
    rm -f "$tmp"
}

# -------------------------------------------------------------
say "${B}━━ Paquetes${N}"
if command -v pacman >/dev/null 2>&1; then
    host_pkgs="hosts/$HOST/packages.txt"
    if [[ -f $host_pkgs ]]; then
        pacman -Qqen | grep -vxF -f "$host_pkgs" | sort | write_file packages/native.txt
    else
        pacman -Qqen | sort | write_file packages/native.txt
    fi
    # voxtype es opcional y lo instala `install.sh --voxtype`; si está
    # instalado, no debe colarse en la lista general de AUR.
    pacman -Qqem | grep -vxE 'voxtype|voxtype-debug' | sort | write_file packages/aur.txt
else
    say "  ${Y}!${N} pacman no disponible; se omite"
fi

if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application 2>/dev/null | sort | write_file packages/flatpak.txt
fi

# -------------------------------------------------------------
say "${B}━━ Sistema${N}"
if command -v systemctl >/dev/null 2>&1; then
    # Unidades de sistema: fuera las internas y las que gestiona el propio
    # stack de red (NetworkManager ya está en la lista).
    systemctl list-unit-files --state=enabled --plain --no-pager 2>/dev/null |
        awk '$2 == "enabled" { print $1 }' |
        grep -vE '^(getty@|systemd-|remote-fs|NetworkManager-wait-online|NetworkManager-dispatcher)' |
        sort | write_file system/services.txt

    # voxtype.service también es opcional y lo habilita esa misma categoría.
    systemctl --user list-unit-files --state=enabled --plain --no-pager 2>/dev/null |
        awk '$2 == "enabled" { print $1 }' |
        grep -vE '^(wireplumber|pipewire|pipewire-pulse|xdg-user-dirs|p11-kit|figma-agent|voxtype)' |
        sort | write_file system/user-units.txt
fi

id -Gn | tr ' ' '\n' | grep -vx "$(id -un)" | sort | write_file system/groups.txt

# -------------------------------------------------------------
say "${B}━━ Overrides desincronizados${N}"
DIFFS=0
while IFS= read -r -d '' file; do
    rel="${file#overrides/}"
    installed="$HOME/.config/$rel"
    [[ -f $installed ]] || { say "  ${Y}!${N} .config/$rel no existe en el sistema"; continue; }
    if cmp -s "$file" "$installed"; then
        continue
    fi
    DIFFS=$((DIFFS + 1))
    say "  ${Y}!${N} .config/$rel difiere del repo"
    if ((UPDATE)); then
        if ((DRY_RUN)); then
            say "    ${D}↳ [dry-run] copiar .config/$rel -> overrides/$rel${N}"
        elif install -Dm644 "$installed" "overrides/$rel"; then
            say "    ${G}↳ copiado a overrides/$rel${N}"
        else
            say "    ${R}↳ no se pudo copiar overrides/$rel${N}"
        fi
    else
        say "    ${D}↳ ./scripts/snapshot.sh --update  para traerlo al repo${N}"
    fi
done < <(find overrides -type f ! -path 'overrides/.upstream/*' ! -name 'BASE_VERSION' -print0 | sort -z)

if ((DIFFS == 0)); then
    say "  ${G}✔${N} overrides sincronizados"
fi

say ""
say "${D}Nota: los cambios hechos con la app de ML4W viven en el árbol;${N}"
say "${D}pásalos al repo con --update para que sobrevivan a un Arch nuevo.${N}"
