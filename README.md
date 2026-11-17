# dotfiles — overlay sobre ML4W

Configuración personal encima de [ML4W](https://github.com/mylinuxforwork/dotfiles).
No es un fork: ML4W sigue siendo ML4W y este repo solo añade lo tuyo,
de forma idempotente y sobreviviendo a sus actualizaciones.

## Instalación interactiva (recomendada)

```bash
./setup.sh
```

Arranca una TUI (Go + [bubbletea/bubbles](https://github.com/charmbracelet/bubbles))
donde marcas qué aplicar en esta pasada: config, overrides, host, paquetes
oficiales, AUR, flatpak, herramientas, servicios y Neovim. Tiene toggle de
**dry-run**, selección recomendada y al aplicar ejecuta
`install.sh --only <selección>`: la TUI no reimplementa nada.

La primera vez:

1. Detecta Go. Si no está, descarga la **última estable** desde `go.dev`,
   verifica su sha256 y la extrae en `~/.local/share/dotfiles/go` (sin sudo).
2. Compila `tui/` en `~/.local/share/dotfiles/bin/dotfiles-tui`.
3. Usa [gum](https://github.com/charmbracelet/gum) para confirmaciones y
   spinners si está disponible (ya viene en `packages/native.txt`).

Opciones:

```bash
./setup.sh --list       # estado por categoría, sin TUI ni TTY
./setup.sh --rebuild    # fuerza recompilar la TUI
./setup.sh --classic    # install.sh de siempre (acepta sus flags)
```

Sin terminal interactiva, `setup.sh` cae solo a `install.sh`. La compilación
necesita red la primera vez (Go + módulos); el binario queda cacheado.

## Instalación en una máquina nueva (modo clásico)

```bash
# 1. Arch base + tu kernel/drivers + yay
# 2. ML4W (su instalador oficial)
ml4w-dotfiles-installer

# 3. Este repo
git clone git@github.com:sayagodev/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/check.sh          # valida sintaxis antes de tocar nada
./install.sh --dry-run      # mira qué va a hacer
./install.sh                # enlaces + overrides + host
./install.sh --packages     # paquetes oficiales, AUR y flatpak
./install.sh --tools        # oh-my-posh y nvm
./install.sh --system       # servicios, grupos y unidades de usuario
./install.sh --nvim         # clona git@github.com:sayagodev/nvim.git
# o todo de una: ./install.sh --all
```

Neovim vive en su propio repo (no se duplica aquí). Si el clone por SSH
falla: `NVIM_REPO=https://github.com/sayagodev/nvim.git ./install.sh --nvim`.

Después: cierra sesión (o `SUPER + SHIFT + R` para Hyprland y abre un
shell nuevo).

`install.sh` es idempotente y **no aborta al primer error**: cada acción
sale en verde/rojo con una pista, y al final hay un resumen. El log queda en
`~/.local/state/dotfiles/install.log`.

## Modelo de capas

```
Arch + paquetes        -> packages/ + system/ + bootstrap/
ML4W                   -> lo instala su instalador (no se versiona)
~/dotfiles (este repo) -> overlay/ + overrides/ + hosts/
```

Regla al añadir algo nuevo:

1. **¿ML4W tiene hook?** Úsalo (`custom.lua`, `~/.config/bashrc/custom/`,
   `~/.config/bashrc-custom`, `~/.bashrc_custom`). Va en `overlay/` como
   symlink.
2. **¿Es configuración tuya completa?** Symlink en `overlay/` (tmux,
   fcitx5, kanata…).
3. **¿Es un fichero de ML4W sin hook?** Copia en `overrides/` + blacklist.
   Es el último recurso: cada override hay que revisarlo cuando ML4W cambia.

## Qué hace exactamente `install.sh`

### Sin flags (siempre)

1. Detecta el árbol de ML4W (por `active.json`; si falla, siguiendo el
   symlink `~/.config/hypr`) y se detiene con un mensaje claro si no existe.
2. Crea **15 symlinks** desde `$HOME` al repo:
   `.bash_profile`, `.bashrc_custom`, `.blerc`, `.config/bashrc-custom`,
   `.config/bashrc/custom/00-init`, `.config/hypr/custom.lua`,
   `.config/hypr/scripts/skills-menu.sh`,
   `.config/ml4w/scripts/ml4w-toggle-no-suspend`,
   `.config/ml4w/wallpapers/shobun.jpg`, `.config/tmux`,
   `.config/fcitx5`, `.config/kanata`,
   `.config/environment.d/10-fcitx.conf`,
   `.config/autostart/gpu-screen-recorder-ui.desktop` y
   `.config/systemd/user/wayscriber.service`.
3. Copia **17 overrides** a `~/.config` (ficheros de ML4W que no tienen hook):
   `hypridle.conf`, keybindings, decorations, window, zen.toml, kitty.conf,
   `SidebarWindow.qml`, `mimeapps.list` y las preferencias de escritorio
   (`launcher`, `statusbar`, `wallpaper-app`, `browser.sh`, `filemanager`,
   `terminal.sh`, `editor.sh`, `dock-disabled`, `waybar-disabled`).
4. Copia `hosts/<hostname>/hypr/monitors.lua` si existe el perfil.
5. Añade las rutas necesarias al `blacklist` del instalador de ML4W y
   habilita `wayscriber.service` con un symlink en
   `graphical-session.target.wants` (sin necesitar sesión activa).

### Con flags

- `--packages`: `pacman -S --needed` con los 196 explícitos, los 4 de
  hardware del host, los 39 de AUR (con `yay` o `paru`) y 6 apps flatpak.
- `--tools`: `bootstrap/tools.sh` → oh-my-posh **29.36.0** en
  `~/.local/bin` y nvm **v0.40.4** en `~/.nvm`; avisa (sin fallar) de
  bun, pnpm, rustup, opencode, claude, codex, lf y hunk.
- `--system`: habilita los 17 servicios de `system/services.txt`, añade
  los 6 grupos de `system/groups.txt` y las 3 unidades de usuario.
- `--nvim`: clona `git@github.com:sayagodev/nvim.git` si no existe.
- `--only links,overrides,host,…`: ejecuta solo esas categorías. Es lo que
  usa la TUI. Válidas: `links`, `overrides`, `host`, `native`, `aur`,
  `flatpak`, `tools`, `system`, `nvim` (y el alias `packages`).
- `--all`: todo lo anterior. `--dry-run` no escribe nada.

### Copias de seguridad

- Solo se respalda **lo que el instalador va a reemplazar y ya existe**.
- Destino: `~/.dotfiles-backup/<fecha>-<pid>/<ruta original>`.
- Se usa `cp -a`: conserva permisos, symlinks y directorios completos.
- Los symlinks existentes no se respaldan (se sustituyen).
- Si el backup falla, esa acción se cancela y se marca en rojo; nunca se
  borra nada sin copia previa.
- No se respalda el árbol completo de ML4W ni la base de datos de pacman.

## Estructura

```
setup.sh                    arranque interactivo: Go + build + TUI
install.sh                  motor idempotente con colores y resumen
tui/                        TUI en Go (bubbletea + bubbles + lipgloss)
lib/manifest.sh             fuente única de las rutas que se gestionan
overlay/                    espejo de $HOME; se enlaza con symlinks
  .bash_profile             source de .bashrc + bun
  .bashrc_custom            ble-attach final (debe cargarse el último)
  .blerc                    config de ble.sh (vi mode, autocompletado, ruler)
  .config/bashrc-custom     aliases, funciones, exports, PATHs
  .config/bashrc/custom/    override del hook de ML4W (ble.sh temprano)
  .config/hypr/custom.lua   binds, input (US intl), fcitx, autostart
  .config/hypr/scripts/     skills-menu.sh
  .config/ml4w/scripts/     ml4w-toggle-no-suspend
  .config/ml4w/wallpapers/  shobun.jpg (único wallpaper versionado)
  .config/tmux/             tmux.conf + menu
  .config/fcitx5/           chino (pinyin) + perfil
  .config/kanata/           remapeo de teclado
  .config/environment.d/    XMODIFIERS / SDL_IM_MODULE para systemd
  .config/systemd/user/     wayscriber.service
overrides/                  ficheros de ML4W que no tienen hook
  .upstream/                copia del upstream de la versión base
  BASE_VERSION              versión de ML4W sobre la que se tomaron
hosts/<hostname>/           monitores y paquetes de hardware
packages/                   native / aur / flatpak (generados)
system/                     servicios, grupos, unidades de usuario
scripts/
  check.sh                  bash -n, luac, jq, shellcheck, gofmt, go vet
  check-drift.sh            ¿cambió upstream lo que overrideo?
  status.sh                 estado por categoría (lo usa la TUI)
  snapshot.sh               regenera listas y detecta overrides tocados
bootstrap/tools.sh          oh-my-posh, nvm y avisos de binarios
```

`system/` guarda lo que no es un dotfile: servicios de systemd, grupos del
usuario y unidades de usuario. Se aplican con `--system`.

## Qué NO se versiona (a propósito)

- `.config/ml4w/settings/` — estado runtime (tema, dock, statusbar). El
  instalador de ML4W ya lo preserva en sus updates.
- Colores de matugen, GTK/kitty/swaync generados por el tema y wallpapers
  salvo `shobun.jpg`.
- Historiales, cachés, `.nvm`, `~/.local/bin`, `~/.config/gh`, claves SSH.
- Binarios grandes (`oh-my-posh`, `ocx`). Se reinstalan con
  `bootstrap/tools.sh` o su instalador.

## Revisión: qué falta o queda fuera (a propósito)

Detectado al contrastar con el sistema real, pendiente de decisión:

- **Wallpapers**: solo se versiona `shobun.jpg` (3.2 MB), en
  `overlay/.config/ml4w/wallpapers/`. Los `FM-01..05` quedan fuera. Tras
  instalar, shobun aparece en el selector de ML4W; hay que elegirlo una vez
  (la elección activa vive en `~/.cache`, no es config).
- **`~/.gitconfig`**: identidad y credential helper de `gh`. Versionable,
  pero expone tu email en el repo.
- **`~/.config/opencode/opencode.json`** y `~/.agents/`. `~/.agents` ya es
  su propio repo git; `cli.json` es 0600 (auth) y no debe versionarse.
- **Apps referenciadas y no instaladas**: `pinta` (screenshot-editor) y los
  flatpaks `org.gnome.Calculator` y `com.tomjwatson.Emote`. Las settings
  apuntan a ellas, así que hoy fallarían: o se añaden a `packages/` o se
  cambia la preferencia.
- **`iwd.service` + `NetworkManager.service`** habilitados a la vez. Se
  suele usar uno; lo dejé tal cual porque así está el sistema.
- **LunarVim** (`~/.config/lvim` y `~/.local/bin/lvim` con rutas
  hardcodeadas): parece un resto; no incluido.
- **Tema EDM115 de oh-my-posh**: alternativo y comentado; no incluido.

Lo que `install.sh` **no** hace: crear usuarios, tocar `/etc`, instalar
bootloader o kernel, restaurar contraseñas/claves SSH/`gh auth`, regenerar
temas de ML4W/matugen, ni recargar servicios de sesión. Tampoco copia
`~/.config/ml4w/settings` completo: solo las 9 preferencias listadas.

## Uso diario

Edita siempre en `~/dotfiles`, no en `~/.config`. Los symlinks hacen el
resto. Para ver qué está enlazado:

```bash
./install.sh --dry-run
```

Si cambias algo con la app de ajustes de ML4W (borde, blur, monitor…),
tráelo al repo:

```bash
./scripts/snapshot.sh            # solo informa
./scripts/snapshot.sh --update   # copia a overrides/ y regenera listas
```

## Actualizar ML4W

```bash
# 1. actualiza con su instalador
# 2. reaplica el overlay
cd ~/dotfiles && ./install.sh
# 3. comprueba que los overrides siguen siendo válidos
./scripts/check-drift.sh
```

`check-drift.sh` compara `overrides/.upstream/` (upstream de la versión
base) con el último release. Si un fichero cambió, te dice cuál y te da el
`diff` para revisarlo. Si todo está bien, sube `overrides/BASE_VERSION` y
actualiza `.upstream/`.

## Notas y decisiones

- **Base real: ML4W 2.15.** `~/.config/ml4w/version.json` decía 2.12.3, pero
  el árbol instalado corresponde a 2.15 (comprobado por hashes). Por eso el
  drift se ancla a `overrides/BASE_VERSION`, no a `version.json`.
- **Teclado US internacional** (`us` + `intl` + `lv3:lalt_switch`) vive en
  `custom.lua`, no en `input.lua`, para sobrevivir a los updates.
- **ble.sh** se carga temprano desde `bashrc/custom/00-init` y se engancha
  al final en `.bashrc_custom`. Ese orden es obligatorio.
- **oh-my-posh** se inicializa una sola vez (en `20-customization` de
  ML4W). Antes se inicializaba dos veces.
- **`alias c`** pisa el `c='clear'` de ML4W a propósito (`unalias` explícito
  antes). Si prefieres `clear`, renómbralo a `oc`.
- **Fcitx**: `custom.lua` exporta `XMODIFIERS`/`SDL_IM_MODULE` y
  `environment.d` los replica para systemd. `GTK_IM_MODULE=fcitx` se
  mantiene en `bashrc-custom` para apps GTK lanzadas desde terminal. Si
  quieres el path Wayland nativo, quita ese export y añade
  `--enable-wayland-ime` a Chromium/Electron.
- **No-suspend** son dos piezas: el script
  `ml4w-toggle-no-suspend` (inhibidor de systemd + marker) y el switch del
  sidebar (`SidebarWindow.qml`). Ambas van en el repo; el QML es override.

## Seguridad

Este repo no contiene tokens, claves ni historiales. Antes de hacerlo
público: `grep -riE 'token|secret|password|api[_-]?key' .` y revisa
`git status` la primera vez.
