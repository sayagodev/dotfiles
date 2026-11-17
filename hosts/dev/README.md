# host `dev`

Perfil de esta máquina concreta. `install.sh` lo aplica solo cuando
`/etc/hostname` coincide con el nombre del directorio (o cuando pasas
`DOTFILES_HOST=dev`).

## Contenido

- `hypr/monitors.lua` — monitores (generado con nwg-displays). Sustituye al
  de ML4W y queda en su blacklist.
- `packages.txt` — paquetes específicos de este hardware: microcódigo AMD y
  la pila de NVIDIA. Se instalan aparte de `packages/native.txt` para que
  una máquina con otra GPU no arrastre drivers equivocados.

## Máquina nueva

```bash
cp -a hosts/dev hosts/$(cat /etc/hostname)
# edita monitors.lua y packages.txt
./install.sh
./scripts/snapshot.sh --update
```
