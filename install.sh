#!/usr/bin/env bash
# =============================================================
#  dotfiles installer — overlay sobre ML4W
#
#  No toca el árbol de ML4W más que en los ficheros declarados
#  como override (con backup + blacklist del instalador).
#  Es idempotente: puedes ejecutarlo las veces que quieras.
#
#  Uso:
#    ./install.sh                 # enlaces + overrides + hosts
#    ./install.sh --dry-run       # muestra lo que haría, sin escribir
#    ./install.sh --packages      # además instala pacman/AUR/flatpak
#    ./install.sh --tools         # además oh-my-posh / nvm
#    ./install.sh --system        # habilita servicios y grupos
#    ./install.sh --nvim          # clona tu repo de Neovim
#    ./install.sh --voxtype       # dictado opcional: paquete, modelo y servicio
#    ./install.sh --all           # todo lo anterior
#    ./install.sh --only links,overrides
#                                 # solo esas categorías (lo usa la TUI)
#    ./install.sh --only aur --aur-pkgs "blesh-git"
#                                 # instala solo esos paquetes, no la lista
#                                 # completa (también --native-pkgs y
#                                 # --flatpak-apps)
#
#  Salida: azul = información, verde = ok, amarillo = aviso,
#  rojo = fallo (con pista de cómo arreglarlo). Al final hay un
#  resumen y el exit code es 1 si algo falló.
# =============================================================
set -uo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REAL_HOME="${HOME:?HOME no está definido}"

# -------------------------------------------------------------
# Flags
# -------------------------------------------------------------
DRY_RUN=0
DO_PACKAGES=0
DO_TOOLS=0
DO_SYSTEM=0
DO_NVIM=0
DO_VOXTYPE=0
ONLY=""
NATIVE_PKGS_SET=0
AUR_PKGS_SET=0
FLATPAK_PKGS_SET=0
NATIVE_PKGS=""
AUR_PKGS=""
FLATPAK_PKGS=""

usage() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
}

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --packages) DO_PACKAGES=1 ;;
        --tools) DO_TOOLS=1 ;;
        --system) DO_SYSTEM=1 ;;
        --nvim) DO_NVIM=1 ;;
        --voxtype) DO_VOXTYPE=1 ;;
        --all) DO_PACKAGES=1; DO_TOOLS=1; DO_SYSTEM=1; DO_NVIM=1; DO_VOXTYPE=1 ;;
        --only)
            [[ -n ${2:-} ]] || { echo "--only necesita una lista (ej: links,overrides)" >&2; exit 2; }
            ONLY="$2"; shift ;;
        --only=*) ONLY="${1#*=}" ;;
        --native-pkgs) NATIVE_PKGS="${2-}"; NATIVE_PKGS_SET=1; shift ;;
        --aur-pkgs) AUR_PKGS="${2-}"; AUR_PKGS_SET=1; shift ;;
        --flatpak-apps) FLATPAK_PKGS="${2-}"; FLATPAK_PKGS_SET=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Opción desconocida: $1 (usa --help)" >&2
            exit 2
            ;;
    esac
    shift
done

# -------------------------------------------------------------
# Colores (se desactivan si no hay TTY o si NO_COLOR está definido)
# -------------------------------------------------------------
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    C_RESET=$'\033[0m'
    C_BLUE=$'\033[1;34m'
    C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m'
    C_RED=$'\033[1;31m'
    C_DIM=$'\033[2m'
    C_BOLD=$'\033[1m'
else
    C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""
fi

# -------------------------------------------------------------
# Estado y log
# -------------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$REAL_HOME/.local/state}/dotfiles"
if ((DRY_RUN)); then
    LOG_FILE="${TMPDIR:-/tmp}/dotfiles-dry-run.log"
else
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    LOG_FILE="$STATE_DIR/install.log"
fi
BACKUP_DIR="$REAL_HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)-$$"

OK_COUNT=0
WARN_COUNT=0
BLACKLIST_WARNED=0
FAILED=()   # entradas "descripción|pista"

_log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG_FILE" 2>/dev/null || true; }

step() {
    printf '\n%s━━ %s %s%s\n' "$C_BOLD" "$*" "$C_RESET" ""
    _log "== $*"
}

info() {
    printf '  %s::%s %s\n' "$C_BLUE" "$C_RESET" "$*"
    _log "INFO $*"
}

ok() {
    OK_COUNT=$((OK_COUNT + 1))
    printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"
    _log "OK   $*"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
    _log "WARN $*"
}

fail() {
    local desc="$1" hint="${2:-}"
    FAILED+=("$desc|$hint")
    printf '  %s✘ %s%s\n' "$C_RED" "$desc" "$C_RESET"
    if [[ -n $hint ]]; then
        printf '    %s↳ %s%s\n' "$C_DIM" "$hint" "$C_RESET"
    fi
    _log "FAIL $desc | $hint"
}

have() { command -v "$1" >/dev/null 2>&1; }

# -------------------------------------------------------------
# Acciones
# -------------------------------------------------------------
# run_action <desc> <pista> <cmd...>
run_action() {
    local desc="$1" hint="$2"
    shift 2
    if ((DRY_RUN)); then
        info "[dry-run] $desc"
        return 0
    fi
    if "$@" >>"$LOG_FILE" 2>&1; then
        ok "$desc"
        return 0
    fi
    fail "$desc" "$hint"
    return 1
}

backup_path() {
    local rel="$1" src="$REAL_HOME/$1" dst="$BACKUP_DIR/$1"
    if ((DRY_RUN)); then
        info "[dry-run] backup $src -> $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")" || {
        fail "no se pudo crear el directorio de backup para $rel" \
            "Comprueba permisos de $BACKUP_DIR"
        return 1
    }
    if cp -a "$src" "$dst" >>"$LOG_FILE" 2>&1; then
        info "backup de $rel -> $dst"
        return 0
    fi
    fail "no se pudo respaldar $rel" \
        "Copia a mano: cp -a '$src' '$dst'"
    return 1
}

# link_path <ruta relativa a $HOME> [origen]
# Sin origen usa overlay/<ruta>; con origen permite enlazar ficheros
# específicos del host (p. ej. hosts/<id>/voxtype/config.toml).
link_path() {
    local rel="$1"
    local src="${2:-$DOTFILES_DIR/overlay/$rel}"
    local src_label="${src#"$DOTFILES_DIR/"}"
    local dst="$REAL_HOME/$rel"

    if [[ ! -e $src ]]; then
        fail "falta el origen del enlace: $src_label" \
            "El repo está incompleto: vuelve a clonarlo o revisa 'git status'"
        return
    fi

    if [[ -L $dst ]] && [[ "$(readlink -f -- "$dst")" == "$(readlink -f -- "$src")" ]]; then
        ok "$rel (ya enlazado)"
        return
    fi

    if [[ -e $dst && ! -L $dst ]]; then
        backup_path "$rel" || return
        if ((DRY_RUN)); then
            info "[dry-run] reemplazar $rel por un symlink al repo"
            return
        fi
        # `ln -f` no puede borrar directorios (tmux, fcitx5, kanata):
        # tras el backup, se retira el original para colocar el symlink.
        rm -rf -- "$dst" 2>>"$LOG_FILE" || {
            fail "no se pudo retirar $rel para colocar el symlink" \
                "Tienes el backup en $BACKUP_DIR/$rel; retíralo a mano y repite"
            return
        }
    fi

    if ((DRY_RUN)); then
        info "[dry-run] ln -sfnT $src $dst"
        return
    fi

    # -T: si el destino es un directorio (tmux, fcitx5…), lo reemplaza
    # por el symlink en vez de crear el enlace dentro.
    if mkdir -p "$(dirname "$dst")" 2>>"$LOG_FILE" && ln -sfnT "$src" "$dst" 2>>"$LOG_FILE"; then
        ok "$rel → repo"
    else
        fail "no se pudo enlazar $rel" \
            "Revisa permisos: ls -ld '$(dirname "$dst")' y que $src exista"
    fi
}

# override_copy <ruta relativa a ~/.config>
override_copy() {
    local rel="$1"
    local src="$DOTFILES_DIR/overrides/$rel"
    local dst="$REAL_HOME/.config/$rel"
    local mode=644
    [[ -x $src ]] && mode=755

    if [[ ! -e $src ]]; then
        fail "falta el override: overrides/$rel" \
            "El repo está incompleto: vuelve a clonarlo o revisa 'git status'"
        return
    fi

    if [[ -f $dst ]] && cmp -s "$src" "$dst"; then
        ok ".config/$rel (sin cambios)"
        return
    fi

    if [[ -e $dst ]]; then
        backup_path ".config/$rel" || return
    fi

    if ((DRY_RUN)); then
        info "[dry-run] install -Dm$mode $src $dst"
        return
    fi

    if install -Dm"$mode" "$src" "$dst" 2>>"$LOG_FILE"; then
        ok ".config/$rel (override)"
    else
        fail "no se pudo copiar el override .config/$rel" \
            "Comprueba que ML4W está instalado y que tienes permiso en $(dirname "$dst")"
    fi
}

# -------------------------------------------------------------
# Detección de ML4W
# -------------------------------------------------------------
detect_ml4w() {
    local active="$REAL_HOME/.config/ml4w-dotfiles-installer/active.json"
    ML4W_PROFILE=""
    ML4W_ROOT=""

    if [[ -f $active ]] && have jq; then
        ML4W_PROFILE="$(jq -r '.active // empty' "$active" 2>/dev/null)"
    fi

    if [[ -n $ML4W_PROFILE && -d "$REAL_HOME/.mydotfiles/$ML4W_PROFILE" ]]; then
        ML4W_ROOT="$REAL_HOME/.mydotfiles/$ML4W_PROFILE"
        return 0
    fi

    if [[ -L "$REAL_HOME/.config/hypr" ]]; then
        local target
        target="$(readlink -f -- "$REAL_HOME/.config/hypr")"
        ML4W_ROOT="$(dirname "$(dirname "$target")")"
        ML4W_PROFILE="$(basename "$ML4W_ROOT")"
        [[ -d $ML4W_ROOT ]] && return 0
    fi

    return 1
}

# -------------------------------------------------------------
# Blacklist del instalador de ML4W
# -------------------------------------------------------------
blacklist_file() {
    printf '%s/.config/ml4w-dotfiles-installer/%s/blacklist' "$REAL_HOME" "$ML4W_PROFILE"
}

blacklist_add() {
    local rel="$1" file
    file="$(blacklist_file)"

    if ((DRY_RUN)); then
        info "[dry-run] blacklist += $rel"
        return
    fi

    if [[ ! -d $(dirname "$file") ]]; then
        if ((BLACKLIST_WARNED == 0)); then
            warn "no existe el perfil del instalador ($ML4W_PROFILE); blacklist omitida"
            warn "los enlaces/overrides funcionan, pero un update de ML4W podría pisarlos"
            BLACKLIST_WARNED=1
        fi
        return
    fi

    touch "$file" 2>>"$LOG_FILE" || {
        fail "no se pudo crear la blacklist" \
            "Crea el fichero a mano: $file"
        return
    }

    if grep -qxF "$rel" "$file" 2>/dev/null; then
        ok "blacklist ya contenía $rel"
        return
    fi

    printf '%s\n' "$rel" >>"$file" 2>>"$LOG_FILE" \
        && ok "blacklist += $rel" \
        || fail "no se pudo escribir en la blacklist" \
                "Añade a mano esta línea: $rel  →  $file"
}

# -------------------------------------------------------------
# Listas declarativas (una sola fuente de verdad: lib/manifest.sh)
# -------------------------------------------------------------
MANIFEST="$DOTFILES_DIR/lib/manifest.sh"
if [[ ! -f $MANIFEST ]]; then
    printf '%s✘ falta lib/manifest.sh%s\n' "$C_RED" "$C_RESET" >&2
    exit 2
fi
# shellcheck source=lib/manifest.sh
source "$MANIFEST"

HOST="$(resolve_host)"

# -------------------------------------------------------------
# Sistema de ficheros: enlaces
# -------------------------------------------------------------
do_links() {
    step "Enlaces del overlay"
    local rel
    for rel in "${LINKED[@]}"; do
        link_path "$rel"
    done

    for rel in "${TREE_LINKS[@]}"; do
        blacklist_add "$rel"
    done

    # El unit de wayscriber se activa con un symlink, sin necesitar
    # una sesión de usuario activa.
    local wants="$REAL_HOME/.config/systemd/user/graphical-session.target.wants"
    if ((DRY_RUN)); then
        info "[dry-run] systemctl --user enable wayscriber.service"
    elif mkdir -p "$wants" 2>>"$LOG_FILE" &&
         ln -sfn ../wayscriber.service "$wants/wayscriber.service" 2>>"$LOG_FILE"; then
        ok "wayscriber.service habilitado en graphical-session.target"
    else
        fail "no se pudo habilitar wayscriber.service" \
            "Ejecuta: systemctl --user enable --now wayscriber.service"
    fi
}

# -------------------------------------------------------------
# Sistema de ficheros: overrides
# -------------------------------------------------------------
do_overrides() {
    step "Overrides (ficheros de ML4W sin hook)"

    local rel
    for rel in "${OVERRIDES[@]}"; do
        override_copy "$rel"
    done

    # Solo los que viven dentro del árbol necesitan blacklist.
    for rel in "${TREE_OVERRIDES[@]}"; do
        blacklist_add ".config/$rel"
    done
}

# -------------------------------------------------------------
# Host: monitores y paquetes de hardware
# -------------------------------------------------------------
do_host() {
    step "Perfil de hardware ($HOST)"
    local dir="$DOTFILES_DIR/hosts/$HOST"

    if [[ ! -d $dir ]]; then
        warn "no hay perfil para '$HOST' (crea hosts/$HOST/ si quieres monitores propios)"
        return
    fi

    local rel
    for rel in "${HOST_FILES[@]}"; do
        if [[ ! -e "$dir/$rel" ]]; then
            warn "falta hosts/$HOST/$rel; se omite"
            continue
        fi
        local src="$dir/$rel" dst="$REAL_HOME/.config/$rel"
        if [[ -f $dst ]] && cmp -s "$src" "$dst"; then
            ok ".config/$rel (sin cambios)"
            continue
        fi
        [[ -e $dst ]] && { backup_path ".config/$rel" || continue; }
        if ((DRY_RUN)); then
            info "[dry-run] install -Dm644 $src $dst"
        elif install -Dm644 "$src" "$dst" 2>>"$LOG_FILE"; then
            ok ".config/$rel (host $HOST)"
        else
            fail "no se pudo copiar .config/$rel" \
                "Comprueba permisos de $dst"
        fi
        blacklist_add ".config/$rel"
    done
}

# -------------------------------------------------------------
# Paquetes
# -------------------------------------------------------------
do_native() {
    step "Paquetes oficiales"

    if ! have pacman; then
        fail "pacman no está disponible" "Este repo asume Arch Linux"
        return
    fi

    local pkgs count
    if ((NATIVE_PKGS_SET)); then
        pkgs="$(echo $NATIVE_PKGS)"
    elif [[ -s $DOTFILES_DIR/packages/native.txt ]]; then
        pkgs="$(tr '\n' ' ' <"$DOTFILES_DIR/packages/native.txt")"
    else
        warn "packages/native.txt vacío; ejecuta ./scripts/snapshot.sh"
        pkgs=""
    fi
    count=$(wc -w <<<"$pkgs")

    if ((count == 0)); then
        info "0 paquetes oficiales seleccionados"
    elif ((DRY_RUN)); then
        info "[dry-run] sudo pacman -S --needed $count paquetes oficiales"
    elif sudo pacman -S --needed --noconfirm $pkgs >>"$LOG_FILE" 2>&1; then
        ok "paquetes oficiales ($count)"
    else
        fail "algunos paquetes oficiales fallaron" \
            "Revisa el log y ejecuta: sudo pacman -S --needed $(printf '%s' "$pkgs" | cut -c1-60)…"
    fi

    # Los paquetes de hardware del host son pacman, van con los oficiales.
    # Con una selección manual no se añaden: se instala exactamente lo elegido.
    local host_pkgs="$DOTFILES_DIR/hosts/$HOST/packages.txt"
    if ((NATIVE_PKGS_SET == 0)) && [[ -s $host_pkgs ]]; then
        local hp
        hp="$(tr '\n' ' ' <"$host_pkgs")"
        if ((DRY_RUN)); then
            info "[dry-run] sudo pacman -S --needed $(wc -l <"$host_pkgs") paquetes de $HOST"
        elif sudo pacman -S --needed --noconfirm $hp >>"$LOG_FILE" 2>&1; then
            ok "paquetes de hardware ($HOST)"
        else
            fail "paquetes de hardware ($HOST) fallaron" \
                "Revisa hosts/$HOST/packages.txt y el log: $LOG_FILE"
        fi
    fi
}

do_aur() {
    step "Paquetes AUR"

    local aur count helper=""
    if ((AUR_PKGS_SET)); then
        aur="$(echo $AUR_PKGS)"
    elif [[ -s $DOTFILES_DIR/packages/aur.txt ]]; then
        aur="$(tr '\n' ' ' <"$DOTFILES_DIR/packages/aur.txt")"
    else
        warn "packages/aur.txt vacío; ejecuta ./scripts/snapshot.sh"
        aur=""
    fi
    count=$(wc -w <<<"$aur")

    if ((count == 0)); then
        info "0 paquetes AUR seleccionados"
        return
    fi

    have yay && helper=yay
    [[ -z $helper ]] && have paru && helper=paru

    if [[ -z $helper ]]; then
        fail "no hay helper de AUR (yay/paru)" \
            "Instala uno: sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si"
    elif ((DRY_RUN)); then
        info "[dry-run] $helper -S --needed $count paquetes AUR"
    elif "$helper" -S --needed --noconfirm $aur >>"$LOG_FILE" 2>&1; then
        ok "paquetes AUR ($count)"
    else
        fail "algunos paquetes AUR fallaron" \
            "Revisa el log: $LOG_FILE  ·  reintenta: $helper -S --needed $(printf '%s' "$aur" | cut -c1-60)…"
    fi
}

do_flatpak() {
    step "Flatpak"

    if ! have flatpak; then
        warn "flatpak no está instalado; se omite"
        return
    fi

    local fps count
    if ((FLATPAK_PKGS_SET)); then
        fps="$(echo $FLATPAK_PKGS)"
    elif [[ -s $DOTFILES_DIR/packages/flatpak.txt ]]; then
        fps="$(tr '\n' ' ' <"$DOTFILES_DIR/packages/flatpak.txt")"
    else
        warn "packages/flatpak.txt vacío; ejecuta ./scripts/snapshot.sh"
        fps=""
    fi
    count=$(wc -w <<<"$fps")

    if ((count == 0)); then
        info "0 apps flatpak seleccionadas"
        return
    fi

    if ((DRY_RUN)); then
        info "[dry-run] flatpak install $count apps"
    elif flatpak install -y --noninteractive $fps >>"$LOG_FILE" 2>&1; then
        ok "apps flatpak ($count)"
    else
        fail "algunas apps flatpak fallaron" \
            "Ejecuta: flatpak install $fps"
    fi
}

# -------------------------------------------------------------
# Voxtype (dictado por voz, opcional)
# -------------------------------------------------------------
voxtype_model_installed() {
    local model="$1"
    local dir="${XDG_DATA_HOME:-$REAL_HOME/.local/share}/voxtype/models"
    [[ -e "$dir/ggml-$model.bin" || -e "$dir/$model" || -d "$dir/$model" ]]
}

do_voxtype() {
    step "Voxtype (dictado por voz, opcional)"

    # Config completa por máquina. El modelo vive en el propio TOML,
    # así `voxtype setup check` y el CLI ven lo mismo que el servicio.
    local src="$DOTFILES_DIR/hosts/$HOST/voxtype/config.toml"
    if [[ ! -f $src ]]; then
        warn "no hay hosts/$HOST/voxtype/config.toml; se omite voxtype"
        warn "copia hosts/dev/voxtype/config.toml a hosts/$HOST/voxtype/ y ajusta el modelo"
        return
    fi

    local model
    model="$(sed -n 's/^[[:space:]]*model[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$src" | head -n1)"
    [[ -n $model ]] || model="small"

    # 1. Config del host → ~/.config/voxtype/config.toml (symlink).
    link_path ".config/voxtype/config.toml" "$src"

    # 2. Paquete AUR
    if ! have voxtype; then
        local helper=""
        have yay && helper=yay
        [[ -z $helper ]] && have paru && helper=paru
        if [[ -z $helper ]]; then
            fail "voxtype no está instalado y no hay helper de AUR" \
                "Instala yay/paru y repite, o: yay -S voxtype"
            return
        fi
        if ((DRY_RUN)); then
            info "[dry-run] $helper -S --needed voxtype"
        elif "$helper" -S --needed --noconfirm voxtype >>"$LOG_FILE" 2>&1; then
            ok "voxtype instalado"
        else
            fail "no se pudo instalar voxtype" \
                "Revisa el log: $LOG_FILE  ·  o instálalo a mano: $helper -S voxtype"
            return
        fi
    else
        ok "voxtype ya instalado"
    fi

    # 3. Dependencias de salida y de pausa de música
    local missing=()
    have wtype || missing+=(wtype)
    have wl-copy || missing+=(wl-clipboard)
    have playerctl || missing+=(playerctl)
    if ((${#missing[@]})); then
        if ((DRY_RUN)); then
            info "[dry-run] sudo pacman -S --needed ${missing[*]}"
        elif have pacman && sudo pacman -S --needed --noconfirm "${missing[@]}" >>"$LOG_FILE" 2>&1; then
            ok "dependencias de voxtype (${missing[*]})"
        else
            warn "faltan dependencias de voxtype: ${missing[*]} (sudo pacman -S ${missing[*]})"
        fi
    else
        ok "dependencias de salida (wtype, wl-clipboard, playerctl)"
    fi

    # 4. Modelo de Whisper declarado en el config del host
    if ((DRY_RUN)); then
        info "[dry-run] voxtype setup --download --model $model"
    elif voxtype_model_installed "$model"; then
        ok "modelo $model ya descargado"
    elif voxtype setup --download --model "$model" --no-post-install >>"$LOG_FILE" 2>&1; then
        ok "modelo $model descargado"
    else
        fail "no se pudo descargar el modelo $model" \
            "Pruébalo a mano: voxtype setup --download --model $model"
    fi

    # 5. Servicio de usuario
    if ! have systemctl; then
        warn "systemctl no está disponible; no se habilita voxtype.service"
        return
    fi
    if ((DRY_RUN)); then
        info "[dry-run] systemctl --user enable --now voxtype.service"
        return
    fi

    if ! systemctl --user enable voxtype.service >>"$LOG_FILE" 2>&1; then
        fail "no se pudo habilitar voxtype.service" \
            "Necesita una sesión de usuario activa: systemctl --user enable --now voxtype.service"
        return
    fi
    ok "voxtype.service habilitado"

    # Reinicia siempre: así se aplican cambios del TOML (modelo,
    # idioma, meeting…) aunque el symlink no haya cambiado.
    if systemctl --user restart voxtype.service >>"$LOG_FILE" 2>&1; then
        ok "voxtype.service reiniciado (modelo $model)"
    else
        warn "no se pudo reiniciar voxtype.service; hazlo a mano: systemctl --user restart voxtype"
    fi
}

# -------------------------------------------------------------
# Herramientas fuera de pacman
# -------------------------------------------------------------
do_tools() {
    step "Herramientas (oh-my-posh, nvm…)"
    if [[ ! -x $DOTFILES_DIR/bootstrap/tools.sh ]]; then
        fail "bootstrap/tools.sh no existe o no es ejecutable" \
            "Ejecuta: chmod +x '$DOTFILES_DIR/bootstrap/tools.sh'"
        return
    fi
    local args=()
    ((DRY_RUN)) && args+=(--dry-run)
    if "$DOTFILES_DIR/bootstrap/tools.sh" "${args[@]}"; then
        ok "herramientas"
    else
        fail "las herramientas no se instalaron completas" \
            "Revisa la salida de bootstrap/tools.sh; es idempotente, puedes repetirlo"
    fi
}

# -------------------------------------------------------------
# Servicios, grupos y unidades de usuario
# -------------------------------------------------------------
do_system() {
    step "Sistema (servicios y grupos)"

    local unit group
    local services="$DOTFILES_DIR/system/services.txt"

    if [[ -s $services ]]; then
        while IFS= read -r unit; do
            [[ -z $unit ]] && continue
            if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
                ok "$unit ya habilitado"
                continue
            fi
            if ((DRY_RUN)); then
                info "[dry-run] sudo systemctl enable --now $unit"
                continue
            fi
            if sudo systemctl enable --now "$unit" >>"$LOG_FILE" 2>&1; then
                ok "$unit habilitado"
            else
                fail "no se pudo habilitar $unit" \
                    "Mira: systemctl status $unit  ·  o hazlo a mano: sudo systemctl enable --now $unit"
            fi
        done <"$services"
    fi

    local groups_file="$DOTFILES_DIR/system/groups.txt"
    if [[ -s $groups_file ]]; then
        while IFS= read -r group; do
            [[ -z $group ]] && continue
            if id -nG "$(id -un)" | grep -qw -- "$group"; then
                ok "grupo $group (ya perteneces)"
                continue
            fi
            if ((DRY_RUN)); then
                info "[dry-run] sudo usermod -aG $group $(id -un)"
            elif sudo usermod -aG "$group" "$(id -un)" >>"$LOG_FILE" 2>&1; then
                ok "grupo $group añadido (requiere volver a entrar)"
            else
                fail "no se pudo añadir el grupo $group" \
                    "Hazlo a mano: sudo usermod -aG $group $(id -un)"
            fi
        done <"$groups_file"
    fi

    local user_unit
    local user_units="$DOTFILES_DIR/system/user-units.txt"
    if [[ -s $user_units ]]; then
        while IFS= read -r user_unit; do
            [[ -z $user_unit ]] && continue
            if systemctl --user is-enabled --quiet "$user_unit" 2>/dev/null; then
                ok "$user_unit (usuario, ya habilitado)"
                continue
            fi
            if ((DRY_RUN)); then
                info "[dry-run] systemctl --user enable $user_unit"
                continue
            fi
            if systemctl --user enable "$user_unit" >>"$LOG_FILE" 2>&1; then
                ok "$user_unit habilitado (usuario)"
            else
                fail "no se pudo habilitar $user_unit (usuario)" \
                    "Necesita una sesión de usuario activa; ejecuta: systemctl --user enable $user_unit"
            fi
        done <"$user_units"
    fi
}

# -------------------------------------------------------------
# Neovim (repo propio)
# -------------------------------------------------------------
do_nvim() {
    step "Neovim"
    local repo="${NVIM_REPO:-git@github.com:sayagodev/nvim.git}"
    local dst="$REAL_HOME/.config/nvim"

    if [[ -d $dst/.git ]]; then
        ok "nvim ya está clonado en $dst"
        return
    fi
    if [[ -e $dst ]]; then
        warn "$dst existe pero no es un repo git; no lo toco"
        warn "muévelo aparte y repite, o clónalo a mano: git clone $repo $dst"
        return
    fi
    if ! have git; then
        fail "git no está instalado" "sudo pacman -S git"
        return
    fi
    if ((DRY_RUN)); then
        info "[dry-run] git clone $repo $dst"
        return
    fi
    if git clone "$repo" "$dst" >>"$LOG_FILE" 2>&1; then
        ok "nvim clonado desde $repo"
    else
        fail "no se pudo clonar el repo de nvim" \
            "Si es privado y falla SSH: NVIM_REPO=https://github.com/sayagodev/nvim.git ./install.sh --nvim"
    fi
}

# -------------------------------------------------------------
# Validación previa
# -------------------------------------------------------------
preflight() {
    step "Comprobaciones previas"

    if ((DRY_RUN)); then
        info "modo dry-run: no se escribe nada"
    fi

    have bash || fail "bash no encontrado" "Instala bash (no deberías necesitarlo)"

    if ! detect_ml4w; then
        printf '\n%s✘ No encuentro la instalación de ML4W.%s\n' "$C_RED" "$C_RESET"
        printf '  %sSin el árbol de ML4W no hay dónde aplicar el overlay.%s\n\n' "$C_DIM" "$C_RESET"
        printf '  Instálalo primero:\n'
        printf '    %shttps://github.com/mylinuxforwork/dotfiles%s\n' "$C_BLUE" "$C_RESET"
        printf '  o con el instalador:\n'
        printf '    %sml4w-dotfiles-installer%s\n\n' "$C_BLUE" "$C_RESET"
        printf '  Después vuelve a ejecutar: %s./install.sh%s\n' "$C_BOLD" "$C_RESET"
        exit 2
    fi
    ok "ML4W detectado en $ML4W_ROOT"

    if [[ -f $REAL_HOME/.config/ml4w/version.json ]] && have jq; then
        local ver base
        ver="$(jq -r '.Version // "desconocida"' "$REAL_HOME/.config/ml4w/version.json" 2>/dev/null)"
        base="$(cat "$DOTFILES_DIR/overrides/BASE_VERSION" 2>/dev/null || echo desconocida)"
        info "versión declarada por ML4W: $ver (base de los overrides: $base)"
    fi

    if [[ ! -d $DOTFILES_DIR/overlay ]]; then
        fail "no existe overlay/ en el repo" "¿Estás ejecutando el install.sh correcto?"
    fi
    if [[ ! -d $DOTFILES_DIR/overrides ]]; then
        fail "no existe overrides/ en el repo" "El repo está incompleto"
    fi
}

# -------------------------------------------------------------
# Resumen
# -------------------------------------------------------------
summary() {
    printf '\n%s━━ Resumen %s%s\n' "$C_BOLD" "$C_RESET" ""

    if ((${#FAILED[@]} == 0)); then
        printf '  %s✔ %d acciones correctas, %d avisos, 0 fallos%s\n' \
            "$C_GREEN" "$OK_COUNT" "$WARN_COUNT" "$C_RESET"
        printf '  %sLog: %s%s\n' "$C_DIM" "$LOG_FILE" "$C_RESET"
        if ((DRY_RUN)); then
            printf '\n  %sDry-run: no se ha modificado nada.%s\n' "$C_BLUE" "$C_RESET"
        else
            printf '\n  %sSiguiente paso: abre un shell nuevo y recarga Hyprland (%s + SHIFT + R).%s\n' \
                "$C_DIM" "SUPER" "$C_RESET"
        fi
        return 0
    fi

    printf '  %s✘ %d fallo(s), %d avisos, %d acciones correctas%s\n\n' \
        "$C_RED" "${#FAILED[@]}" "$WARN_COUNT" "$OK_COUNT" "$C_RESET"
    printf '  %sQué falló y cómo arreglarlo:%s\n' "$C_BOLD" "$C_RESET"
    local item desc hint
    for item in "${FAILED[@]}"; do
        desc="${item%%|*}"
        hint="${item#*|}"
        printf '    %s✘ %s%s\n' "$C_RED" "$desc" "$C_RESET"
        [[ -n $hint ]] && printf '      %s↳ %s%s\n' "$C_YELLOW" "$hint" "$C_RESET"
    done
    printf '\n  %sLog completo: %s%s\n' "$C_DIM" "$LOG_FILE" "$C_RESET"
    printf '  %sPuedes repetir ./install.sh: es idempotente.%s\n' "$C_DIM" "$C_RESET"
    return 1
}

# -------------------------------------------------------------
# Main
# -------------------------------------------------------------
# should_run <categoría>
#   Sin --only: las categorías de config siempre; el resto según su flag.
#   Con --only: solo las listadas.
should_run() {
    local key="$1"
    if [[ -n $ONLY ]]; then
        [[ ",$ONLY," == *",$key,"* ]]
        return
    fi
    case "$key" in
        links|overrides|host) return 0 ;;
        native|aur|flatpak) ((DO_PACKAGES)) ;;
        tools) ((DO_TOOLS)) ;;
        system) ((DO_SYSTEM)) ;;
        nvim) ((DO_NVIM)) ;;
        voxtype) ((DO_VOXTYPE)) ;;
        *) return 1 ;;
    esac
}

validate_only() {
    [[ -z $ONLY ]] && return 0
    ONLY="${ONLY// /}" # tolera "links, overrides"
    # Alias cómodo: packages = native,aur,flatpak
    ONLY="${ONLY//packages/native,aur,flatpak}"
    local key valid=",links,overrides,host,native,aur,flatpak,tools,system,nvim,voxtype,"
    local IFS=,
    for key in $ONLY; do
        [[ -z $key ]] && continue
        if [[ $valid != *",$key,"* ]]; then
            fail "categoría desconocida en --only: $key" \
                "Válidas: links, overrides, host, native, aur, flatpak, tools, system, nvim, voxtype (o packages)"
            return 1
        fi
    done
    return 0
}

main() {
    printf '%s╭──────────────────────────────────────────────╮%s\n' "$C_BLUE" "$C_RESET"
    printf '%s│  dotfiles overlay para ML4W                   │%s\n' "$C_BLUE" "$C_RESET"
    printf '%s╰──────────────────────────────────────────────╯%s\n' "$C_BLUE" "$C_RESET"

    preflight
    validate_only

    should_run links && do_links
    should_run overrides && do_overrides
    should_run host && do_host
    should_run native && do_native
    should_run aur && do_aur
    should_run flatpak && do_flatpak
    should_run tools && do_tools
    should_run system && do_system
    should_run voxtype && do_voxtype
    should_run nvim && do_nvim

    summary
}

main "$@"
