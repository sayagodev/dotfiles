#!/usr/bin/env bash
# =============================================================
#  Estado del overlay, en formato key|status|detalle.
#  Lo usa la TUI (y sirve para mirar a mano).
#  status: ok | partial | pending | na
# =============================================================
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/manifest.sh
source "$ROOT/lib/manifest.sh"

HOST="$(resolve_host)"
have() { command -v "$1" >/dev/null 2>&1; }

# -------------------------------------------------------------
# links
# -------------------------------------------------------------
total=${#LINKED[@]}
ok=0
for rel in "${LINKED[@]}"; do
    dst="$HOME/$rel"
    src="$ROOT/overlay/$rel"
    if [[ -L $dst ]] && [[ "$(readlink -f -- "$dst")" == "$(readlink -f -- "$src")" ]]; then
        ok=$((ok + 1))
    fi
done
if ((ok == total)); then st=ok; else ((ok == 0)) && st=pending || st=partial; fi
printf 'links|%s|%d/%d enlaces\n' "$st" "$ok" "$total"

# -------------------------------------------------------------
# overrides
# -------------------------------------------------------------
total=${#OVERRIDES[@]}
ok=0
for rel in "${OVERRIDES[@]}"; do
    cmp -s "$ROOT/overrides/$rel" "$HOME/.config/$rel" 2>/dev/null && ok=$((ok + 1))
done
if ((ok == total)); then st=ok; else ((ok == 0)) && st=pending || st=partial; fi
printf 'overrides|%s|%d/%d ficheros\n' "$st" "$ok" "$total"

# -------------------------------------------------------------
# host
# -------------------------------------------------------------
if [[ ! -d $ROOT/hosts/$HOST ]]; then
    printf 'host|na|sin perfil para %s\n' "$HOST"
else
    total=0; ok=0
    for rel in "${HOST_FILES[@]}"; do
        [[ -f "$ROOT/hosts/$HOST/$rel" ]] || continue
        total=$((total + 1))
        cmp -s "$ROOT/hosts/$HOST/$rel" "$HOME/.config/$rel" 2>/dev/null && ok=$((ok + 1))
    done
    if ((total == 0)); then
        printf 'host|na|perfil vacío\n'
    elif ((ok == total)); then
        printf 'host|ok|%d/%d ficheros\n' "$ok" "$total"
    else
        printf 'host|pending|%d/%d ficheros\n' "$ok" "$total"
    fi
fi

# -------------------------------------------------------------
# paquetes oficiales (incluye los de hardware del host)
# -------------------------------------------------------------
if ! have pacman; then
    printf 'native|na|pacman no disponible\n'
else
    mapfile -t native <"$ROOT/packages/native.txt"
    [[ -s $ROOT/hosts/$HOST/packages.txt ]] && mapfile -t -O "${#native[@]}" native <"$ROOT/hosts/$HOST/packages.txt"
    total=${#native[@]}
    missing=$(pacman -T "${native[@]}" 2>/dev/null | wc -l)
    if ((missing == 0)); then
        printf 'native|ok|%d/%d instalados\n' "$total" "$total"
    elif ((missing == total)); then
        printf 'native|pending|0/%d instalados\n' "$total"
    else
        printf 'native|partial|%d por instalar de %d\n' "$missing" "$total"
    fi
fi

# -------------------------------------------------------------
# AUR
# -------------------------------------------------------------
if ! have pacman; then
    printf 'aur|na|pacman no disponible\n'
else
    mapfile -t aur <"$ROOT/packages/aur.txt"
    total=${#aur[@]}
    mapfile -t installed < <(pacman -Qq 2>/dev/null)
    missing=0
    for p in "${aur[@]}"; do
        [[ -z $p ]] && continue
        found=0
        for q in "${installed[@]}"; do
            [[ $p == "$q" ]] && { found=1; break; }
        done
        ((found)) || missing=$((missing + 1))
    done
    if ((missing == 0)); then
        printf 'aur|ok|%d/%d instalados\n' "$total" "$total"
    elif ((missing == total)); then
        printf 'aur|pending|0/%d instalados\n' "$total"
    else
        printf 'aur|partial|%d por instalar de %d\n' "$missing" "$total"
    fi
fi

# -------------------------------------------------------------
# Flatpak
# -------------------------------------------------------------
if ! have flatpak; then
    printf 'flatpak|na|flatpak no disponible\n'
else
    mapfile -t fps <"$ROOT/packages/flatpak.txt"
    total=${#fps[@]}
    mapfile -t installed < <(flatpak list --app --columns=application 2>/dev/null)
    missing=0
    for p in "${fps[@]}"; do
        [[ -z $p ]] && continue
        found=0
        for q in "${installed[@]}"; do
            [[ $p == "$q" ]] && { found=1; break; }
        done
        ((found)) || missing=$((missing + 1))
    done
    if ((missing == 0)); then
        printf 'flatpak|ok|%d/%d instaladas\n' "$total" "$total"
    elif ((missing == total)); then
        printf 'flatpak|pending|0/%d instaladas\n' "$total"
    else
        printf 'flatpak|partial|%d por instalar de %d\n' "$missing" "$total"
    fi
fi

# -------------------------------------------------------------
# Herramientas
# -------------------------------------------------------------
ok=0
total=2
if have oh-my-posh || [[ -x $HOME/.local/bin/oh-my-posh ]]; then
    ok=$((ok + 1))
fi
[[ -s $HOME/.nvm/nvm.sh ]] && ok=$((ok + 1))
if ((ok == total)); then st=ok; else ((ok == 0)) && st=pending || st=partial; fi
printf 'tools|%s|%d/%d (oh-my-posh, nvm)\n' "$st" "$ok" "$total"

# -------------------------------------------------------------
# Sistema: servicios + grupos + unidades de usuario
# -------------------------------------------------------------
if ! have systemctl; then
    printf 'system|na|systemctl no disponible\n'
else
    total=0; ok=0
    while IFS= read -r unit; do
        [[ -z $unit ]] && continue
        total=$((total + 1))
        systemctl is-enabled --quiet "$unit" 2>/dev/null && ok=$((ok + 1))
    done <"$ROOT/system/services.txt"
    while IFS= read -r group; do
        [[ -z $group ]] && continue
        total=$((total + 1))
        id -nG "$(id -un)" 2>/dev/null | grep -qw -- "$group" && ok=$((ok + 1))
    done <"$ROOT/system/groups.txt"
    while IFS= read -r unit; do
        [[ -z $unit ]] && continue
        total=$((total + 1))
        systemctl --user is-enabled --quiet "$unit" 2>/dev/null && ok=$((ok + 1))
    done <"$ROOT/system/user-units.txt"
    if ((ok == total)); then st=ok; else ((ok == 0)) && st=pending || st=partial; fi
    printf 'system|%s|%d/%d aplicados\n' "$st" "$ok" "$total"
fi

# -------------------------------------------------------------
# Neovim
# -------------------------------------------------------------
if [[ -d $HOME/.config/nvim/.git ]]; then
    printf 'nvim|ok|repo clonado\n'
elif [[ -e $HOME/.config/nvim ]]; then
    printf 'nvim|pending|existe pero no es repo git\n'
else
    printf 'nvim|pending|sin clonar\n'
fi
