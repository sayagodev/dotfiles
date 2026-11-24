local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local HOME = os.getenv("HOME")

-- -----------------------------------------------------
-- INPUT / TECLADO
-- Vive aquí y no en input.lua para sobrevivir a los
-- updates de ML4W (input.lua es fichero upstream).
-- US internacional: AltGr = teclas muertas (lv3:lalt_switch).
-- -----------------------------------------------------
hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "intl",
		kb_options = "lv3:lalt_switch",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = { natural_scroll = true },
	},
	render = {
		-- HDR automático en fullscreen: en DP-3 (GGF MG701) el cambio
		-- de infoframe HDR hace que nvidia-drm pierda el flip y la
		-- pantalla se quede negra, con el vídeo descolorido y a tirones.
		-- El monitor anuncia HDR400, pero se ve mejor en SDR.
		cm_auto_hdr = 0,
	},
})

hl.unbind(mainMod .. " + K", hl.dsp.layout("swapsplit"), { description = "Swapsplit" })
hl.unbind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split" })

hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }), { description = "Move focus left" })
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }), { description = "Move focus right" })
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }), { description = "Move focus up" })
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }), { description = "Move focus down" })

hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("wayscriber -a"), { description = "Activate Wayscriber" })
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd(HOME .. "/.config/tmux/menu.sh"), { description = "Tmux command menu" })
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/skills-menu.sh"), { description = "Skills menu (opencode)" })
-- -----------------------------------------------------
-- VOX TYPE (dictado por voz)
-- Cambia "KP_Enter" por la tecla que quieras:
--   "F9", "SUPER + F9", "ALT + grave", "XF86AudioMicMute"…
-- En laptops sin teclado numérico, KP_Enter no existe: usa
-- "SUPER + F9" o la que prefieras.
-- El resto de ajustes está en ~/.config/voxtype/config.toml
-- (modelo por máquina en hosts/<id>/voxtype/config.toml).
-- -----------------------------------------------------
local voxtypeKey = "KP_Enter"
hl.bind(voxtypeKey, hl.dsp.exec_cmd("voxtype record toggle"), { description = "Voxtype toggle (start/stop)" })

-- Fcitx5 en Wayland (Hyprland con text-input): NO poner GTK_IM_MODULE ni QT_IM_MODULE,
-- se usa el frontend nativo Wayland. Solo XMODIFIERS para apps XWayland.
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")

-- Autostart custom: sobrevive a updates de ml4w/omarchy (no tocar conf/autostart.lua)
hl.on("hyprland.start", function()
	-- Fcitx5: arrancar daemon si no está corriendo.
	-- `env -u GTK_IM_MODULE` evita el aviso de fcitx5 si el login
	-- arrastra la variable (SDDM entra con bash --login).
	hl.exec_cmd("env -u GTK_IM_MODULE fcitx5 --replace -d")
	-- Propaga Wayland env a systemd (complementa conf/autostart.lua)
	hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	-- Blueman applet: agente Bluetooth para auto-connect + icono tray en waybar
	-- Fix para "Trusted: no" + "Authentication attempt without agent"
	hl.exec_cmd("blueman-applet")
	-- Voxtype: graphical-session.target está inactivo, iniciar explícitamente
	hl.exec_cmd("systemctl --user start voxtype.service")
	-- No Suspend: re-aplica el estado si quedó activo (marker en ml4w/settings)
	hl.exec_cmd(HOME .. "/.config/ml4w/scripts/ml4w-toggle-no-suspend start")
end)
-- Push-to-talk alternativo (mantener para grabar): descomentar y cambiar toggle->start arriba
-- hl.bind(voxtypeKey, hl.dsp.exec_cmd("voxtype record stop"), { description = "Voxtype PTT (stop)", release = true })

-- RustDesk: flotante, pequeña, esquina inferior derecha
-- (size/move relativos al monitor: se adapta a 1920x1080 y 2560x1440)
hl.window_rule({
	name = "rustdesk-floating",
	match = { class = "rustdesk" },
	float = true,
	workspace = "5",
	size = { "(monitor_w*0.3)", "(monitor_h*0.35)" },
	move = { "(monitor_w-window_w)-20", "(monitor_h-window_h)-20" },
})

-- Voxtype Meeting Mode
hl.bind(
	mainMod .. " + CTRL + M",
	hl.dsp.exec_cmd("voxtype meeting start"),
	{ description = "Toggle meeting transcription" }
)
hl.bind(
	mainMod .. " + ALT + M",
	hl.dsp.exec_cmd("voxtype meeting pause"),
	{ description = "Pause meeting transcription" }
)
hl.bind(
	mainMod .. " + SHIFT + ALT + M",
	hl.dsp.exec_cmd("voxtype meeting resume"),
	{ description = "Resume meeting transcription" }
)
hl.bind(
	mainMod .. " + SHIFT + CTRL + M",
	hl.dsp.exec_cmd("voxtype meeting stop"),
	{ description = "Stop meeting transcription" }
)
