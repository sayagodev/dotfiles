-- Perfil de la laptop.
-- Ajusta el output y la escala a lo que reporte `hyprctl monitors`.
-- Este archivo solo se aplica si la máquina usa este perfil:
--   echo laptop > ~/.config/dotfiles/host
-- y luego: ./install.sh --only host

hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "0x0",
    scale = 1.0,
})
