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
oficiales, AUR, flatpak, voxtype, herramientas, servicios y Neovim. Tiene toggle de
**dry-run**, selección recomendada y al aplicar ejecuta
`install.sh --only <selección>`: la TUI no reimplementa nada.

Teclas: `espacio` marca · `p` paquetes · `h` perfil de máquina · `a` todo ·
`n` nada · `r` recomendado · `d` dry-run · `enter` aplica · `?` ayuda.

- **`h` perfil de máquina**: cicla por `hosts/` y “sin perfil”. El elegido
  se guarda en `~/.config/dotfiles/host` al aplicar, así dos equipos con el
  mismo hostname (`dev`) no comparten monitores ni paquetes de hardware.
- **`p` paquetes**: `gum filter` con todos los paquetes. `tab` marca,
  `enter` confirma. Sustituye las listas completas y activa solo las
  categorías con paquetes elegidos. Para instalar únicamente `blesh-git`:
  `p` → `blesh` → `tab` → `enter` → aplicar.

La primera vez:

1. Detecta Go. Si no está, descarga la **última estable** desde `go.dev`,
   verifica su sha256 y la extrae en `~/.local/share/dotfiles/go` (sin sudo).
2. Compila `tui/` en `~/.local/share/dotfiles/bin/dotfiles-tui`. Sin `gum`
   verás puntos de progreso; la primera compilación puede tardar.
3. Usa [gum](https://github.com/charmbracelet/gum) para confirmaciones,
   spinners y el selector de paquetes si está disponible (ya viene en
   `packages/native.txt`).

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
./install.sh --voxtype      # dictado opcional: paquete, modelo y servicio
# o todo de una: ./install.sh --all
```

Neovim vive en su propio repo (no se duplica aquí). Si el clone por SSH
falla: `NVIM_REPO=https://github.com/sayagodev/nvim.git ./install.sh --nvim`.

Después: cierra sesión (o `SUPER + SHIFT + R` para Hyprland y abre un
shell nuevo).

`install.sh` es idempotente y **no aborta al primer error**: cada acción
sale en verde/rojo con una pista, y al final hay un resumen. El log queda en
`~/.local/state/dotfiles/install.log`.

Si la selección incluye paquetes, AUR, flatpak, servicios o voxtype, `sudo`
pide la contraseña **al principio** y la mantiene viva mientras dura la
instalación. La salida de pacman/yay/flatpak se muestra en pantalla y se
guarda en el log.

## Voxtype (dictado por voz, opcional)

[Voxtype](https://voxtype.io) convierte voz en texto y lo escribe en la app
activa. Es opcional: la TUI lo muestra como categoría propia y no se instala
salvo que lo marques.

```bash
./install.sh --only voxtype     # paquete, dependencias, modelo y servicio
```

La categoría hace:

1. Enlaza `hosts/<perfil>/voxtype/config.toml` a
   `~/.config/voxtype/config.toml` (con backup del original).
2. Instala `voxtype` desde AUR si falta (con `yay` o `paru`).
3. Instala `wtype`, `wl-clipboard` y `playerctl` si faltan.
4. Descarga el modelo declarado en `[whisper] model` de ese config.
5. Habilita y reinicia `voxtype.service`.

`voxtype` no está en `packages/aur.txt` ni `voxtype.service` en
`system/user-units.txt`: esta categoría es la única que los toca, así que
quien no quiera dictado no lo recibe con `--aur` ni con `--system`.

### Cambiar la tecla

La tecla de dictado está en `overlay/.config/hypr/custom.lua`:

```lua
local voxtypeKey = "KP_Enter"
```

Cámbiala por `F9`, `SUPER + F9`, `ALT + grave`, etc., y recarga Hyprland
(`SUPER + SHIFT + R`). En una laptop sin teclado numérico, `KP_Enter` no
existe: usa por ejemplo `SUPER + F9`.

El bloque `[hotkey]` de `config.toml` es el hotkey evdev propio de voxtype
y está desactivado porque se usa el binding del compositor. Si lo activas,
pon ahí la tecla (`key = "SCROLLLOCK"`, `enabled = true`).

### Modelo por máquina

Cada perfil tiene su propio `hosts/<perfil>/voxtype/config.toml`; el modelo
es la línea `[whisper] model`:

| Perfil | Modelo | Por qué |
| --- | --- | --- |
| `dev` (escritorio, GPU) | `medium` | Más precisión con Vulkan |
| `laptop` (iGPU) | `small` | Multilingüe, 466 MB, cabe en iGPU/CPU |

Para una laptop sin GPU dedicada:

- **`small`** es el equilibrio: español + inglés, ~3× tiempo real en CPU y
  más rápido con Vulkan en iGPU Intel/AMD.
- **`base`** (142 MB) o **`tiny`** (75 MB) si el portátil es viejo o va justo
  de RAM.
- **`medium`** (1.5 GB, ~5 GB de VRAM) no es para iGPU;
  **`large-v3-turbo`** solo con GPU dedicada.
- **Parakeet** (`parakeet-tdt-0.6b-v3-int8`, 670 MB) es más rápido y trae
  puntuación, pero necesita el binario ONNX; el paquete `voxtype` de AUR
  solo trae Whisper/Vulkan. Es una mejora opcional, no el default.

Comprueba qué está usando:

```bash
voxtype info accel        # GPU/CPU y backend
voxtype setup check       # dependencias, modelo, grupo input
systemctl --user status voxtype
```

Si el portátil no tiene Vulkan o falla, fuerza CPU:

```bash
voxtype setup gpu --status
voxtype setup gpu --disable
```

Cambiar el modelo:

```bash
# Edita el config del perfil (o usa voxtype config set, que escribe
# a través del symlink al repo) y aplica:
vi ~/dotfiles/hosts/laptop/voxtype/config.toml   # model = "small"
./install.sh --only voxtype
```

`voxtype setup check` y el CLI leen el mismo config que el servicio, así que
no hay que llevar el modelo en dos sitios.

### Atajos de reunión

`custom.lua` ya define:

- `SUPER + CTRL + M` — empezar transcripción de reunión
- `SUPER + ALT + M` — pausar
- `SUPER + SHIFT + ALT + M` — reanudar
- `SUPER + SHIFT + CTRL + M` — parar

Documentación oficial: [modelos](https://voxtype.io/docs/MODEL_SELECTION_GUIDE),
[configuración](https://voxtype.io/docs/CONFIGURATION) y
[Parakeet](https://voxtype.io/docs/PARAKEET).

## RustDesk (Wayland, opcional)

RustDesk normal no permite acceso desatendido en Wayland. La instalación
usa el paquete AUR `rustdesk-unattended-wayland` (nightly con captura por
PipeWire y `libdrmtap`), ya incluido en `packages/aur.txt`, y habilita
`rustdesk.service`, ya incluido en `system/services.txt`.

```bash
./install.sh --only aur,system   # paquete + servicio al arranque
```

Notas de funcionamiento:

- El servicio corre como root y captura la pantalla por PipeWire/portal.
  La primera conexión pide permiso; concédelo una vez.
- Si el compositor sigue pidiendo permiso, ejecuta `rustdesk --service`
  dentro de la sesión y vuelve a probar.
- Para acceso desatendido, define una contraseña permanente en RustDesk
  (Ajustes → Seguridad). La opción
  `verification-method = 'use-permanent-password'` vive en
  `~/.config/rustdesk/RustDesk2.toml`.

### Configuración y secretos

`~/.config/rustdesk/` (`RustDesk.toml`, `RustDesk2.toml`,
`RustDesk_local.toml`, `RustDesk_group` y `peers/`) contiene el ID, la
clave privada, el hash de la contraseña y el token de acceso. **No se
versiona**: el repo es público y con esos datos se puede acceder al equipo.
Si quieres conservar el ID y los dispositivos de confianza al reinstalar,
guarda una copia privada (gestor de contraseñas o disco cifrado), nunca en
`~/dotfiles`.

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
2. Crea **19 symlinks** desde `$HOME` al repo:
   `.bash_profile`, `.bashrc_custom`, `.blerc`, `.config/bashrc-custom`,
   `.config/bashrc/custom/00-init`, `.config/hypr/custom.lua`,
   `.config/hypr/scripts/skills-menu.sh`,
   `.config/ml4w/scripts/ml4w-toggle-no-suspend`,
   `.config/ml4w/wallpapers/shobun.jpg`, `.config/tmux`,
   `.config/fcitx5`, `.config/kanata`,
   `.config/environment.d/10-fcitx.conf`,
   `.config/autostart/gpu-screen-recorder-ui.desktop`,
   `.config/systemd/user/wayscriber.service` y los flags de Chromium/Edge/VS Code
   (`.config/chromium-flags.conf`, `.config/edge-flags.conf`,
   `.config/code-flags.conf`, `.config/electron-flags.conf`).
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
  los 6 grupos de `system/groups.txt` y las 2 unidades de usuario.
- `--nvim`: clona `git@github.com:sayagodev/nvim.git` si no existe.
- `--voxtype`: dictado opcional. Instala `voxtype` desde AUR, sus
  dependencias, el modelo de `hosts/<perfil>/voxtype/config.toml` y
  habilita el servicio. Ver la sección de Voxtype.
- `--only links,overrides,host,…`: ejecuta solo esas categorías. Es lo que
  usa la TUI. Válidas: `links`, `overrides`, `host`, `native`, `aur`,
  `flatpak`, `tools`, `system`, `nvim`, `voxtype` (y el alias `packages`).
- `--native-pkgs "firefox kitty"`, `--aur-pkgs "blesh-git"`,
  `--flatpak-apps "org.telegram.desktop"`: instala exactamente esos
  paquetes en vez de la lista completa. Con selección manual no se añaden
  los paquetes de hardware del host.
- `--all`: todo lo anterior, incluido Voxtype. `--dry-run` no escribe nada.

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
  .bashrc_custom            carga bashrc-custom + ble-attach final
  .blerc                    config de ble.sh (vi mode, autocompletado, ruler)
  .config/bashrc-custom     aliases, funciones, exports y Ctrl+O
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
hosts/<perfil>/             monitores, paquetes y config de voxtype
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
- `~/.config/rustdesk/`: ID, clave privada, contraseña y token de acceso.
- Modelos de voxtype (`~/.local/share/voxtype/models`): pesan cientos de
  MB y se descargan con `./install.sh --only voxtype`.
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
- **Perfil por máquina**: `~/.config/dotfiles/host` manda sobre el
  hostname. Dos equipos llamados `dev` pueden usar `hosts/dev` y
  `hosts/laptop` sin pisarse monitores ni paquetes de hardware.
- **Teclado US internacional** (`us` + `intl` + `lv3:lalt_switch`) vive en
  `custom.lua`, no en `input.lua`, para sobrevivir a los updates.
- **HDR automático desactivado** (`render:cm_auto_hdr = 0`): en DP-3 el
  cambio de infoframe HDR provoca `Flip event timeout` en `nvidia-drm`
  (pantalla negra y vídeo descolorido). El monitor anuncia HDR400, pero se
  usa SDR. Para probar HDR:
  `hyprctl eval 'hl.config({ render = { cm_auto_hdr = 1 } })'`.
- **ble.sh** se carga temprano desde `bashrc/custom/00-init` y se engancha
  al final en `.bashrc_custom`. Ese orden es obligatorio.
- **`bashrc-custom`** se carga desde `.bashrc_custom`, con guarda contra
  doble carga. ML4W nuevo dejó de sourcearlo en `20-customization`; así los
  alias, funciones y `Ctrl+O` no dependen de la versión de ML4W.
- **oh-my-posh** se inicializa una sola vez (en `20-customization` de
  ML4W). Antes se inicializaba dos veces.
- **`alias c`** pisa el `c='clear'` de ML4W a propósito (`unalias` explícito
  antes). Si prefieres `clear`, renómbralo a `oc`.
- **Fcitx**: `custom.lua` exporta `XMODIFIERS`/`SDL_IM_MODULE` y
  `environment.d` los replica para systemd. **No** se exporta
  `GTK_IM_MODULE`: SDDM entra con `bash --login`, así que ponerlo en
  `bashrc-custom` contamina todo el compositor y fcitx5 avisa al arrancar.
  GTK usa el frontend nativo Wayland. Chromium, Edge y Electron/VS Code
  llevan `--enable-wayland-ime` en sus flags (`*-flags.conf`).
- **No-suspend** son dos piezas: el script
  `ml4w-toggle-no-suspend` (inhibidor de systemd + marker) y el switch del
  sidebar (`SidebarWindow.qml`). Ambas van en el repo; el QML es override.

## Seguridad

Este repo no contiene tokens, claves ni historiales. Antes de hacerlo
público: `grep -riE 'token|secret|password|api[_-]?key' .` y revisa
`git status` la primera vez.
