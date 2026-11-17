# Perfiles de máquina (`hosts/`)

Cada carpeta es un perfil que se aplica según la identidad de la máquina:

1. `$DOTFILES_HOST` si está definido.
2. `~/.config/dotfiles/host` (lo escribe la TUI al elegir perfil con `h`).
3. `/etc/hostname`.

Sirve para dos equipos con el mismo hostname (por ejemplo, ambos `dev`).

## Contenido de un perfil

- `hypr/monitors.lua` — monitores (sustituye al de ML4W y va a su blacklist).
- `packages.txt` — paquetes propios del hardware (microcódigo, GPU). Se
  instalan con los oficiales; vacío = no añadir nada.

## Máquina nueva

No copies `dev` tal cual: tiene los monitores del escritorio.

```bash
mkdir -p ~/dotfiles/hosts/laptop/hypr
cp ~/.config/hypr/monitors.lua ~/dotfiles/hosts/laptop/hypr/monitors.lua
echo laptop > ~/.config/dotfiles/host
cd ~/dotfiles && ./install.sh --only host
```

O desde la TUI: `./setup.sh` → `h` hasta `laptop` → aplicar. El perfil queda
guardado para las próximas ejecuciones.

## Laptop `dev` que recibió el perfil del escritorio

Si el hostname era `dev`, se aplicó `hosts/dev` (HDMI-A-1/DP-3 y paquetes
NVIDIA). Para recuperar la config original:

```bash
ls -1t ~/.dotfiles-backup | head
cp -a ~/.dotfiles-backup/<carpeta>/.config/hypr/monitors.lua ~/.config/hypr/monitors.lua
hyprctl reload
```

Después crea el perfil `laptop` como arriba, y revisa que no se hayan
instalado drivers que no correspondan:

```bash
pacman -Q | grep -E 'nvidia|amd-ucode'
```
