# =============================================================
#  Fuente única de verdad de las rutas que gestiona el repo.
#  Lo leen install.sh y scripts/status.sh.
# =============================================================

# Symlinks desde $HOME al repo.
LINKED=(
    ".bash_profile"
    ".bashrc_custom"
    ".blerc"
    ".config/bashrc-custom"
    ".config/bashrc/custom/00-init"
    ".config/hypr/custom.lua"
    ".config/hypr/scripts/skills-menu.sh"
    ".config/ml4w/scripts/ml4w-toggle-no-suspend"
    ".config/ml4w/wallpapers/shobun.jpg"
    ".config/tmux"
    ".config/fcitx5"
    ".config/kanata"
    ".config/environment.d/10-fcitx.conf"
    ".config/autostart/gpu-screen-recorder-ui.desktop"
    ".config/systemd/user/wayscriber.service"
)

# Symlinks que viven DENTRO del árbol de ML4W: van a su blacklist.
TREE_LINKS=(
    ".config/bashrc/custom/00-init"
    ".config/hypr/custom.lua"
    ".config/hypr/scripts/skills-menu.sh"
    ".config/ml4w/scripts/ml4w-toggle-no-suspend"
    ".config/ml4w/wallpapers/shobun.jpg"
)

# Overrides que sustituyen ficheros del árbol de ML4W.
TREE_OVERRIDES=(
    "hypr/hypridle.conf"
    "hypr/conf/keybindings/default.lua"
    "hypr/conf/decorations/default.lua"
    "hypr/conf/window.lua"
    "ohmyposh/zen.toml"
    "kitty/kitty.conf"
    "quickshell/SidebarApp/SidebarWindow.qml"
    "ml4w/settings/launcher"
    "ml4w/settings/statusbar"
    "ml4w/settings/wallpaper-app"
    "ml4w/settings/browser.sh"
    "ml4w/settings/filemanager"
    "ml4w/settings/terminal.sh"
    "ml4w/settings/editor.sh"
    "ml4w/settings/dock-disabled"
    "ml4w/settings/waybar-disabled"
)

# Ficheros propios fuera del árbol de ML4W.
OVERRIDES=(
    "${TREE_OVERRIDES[@]}"
    "mimeapps.list"
)

# Ficheros por host (se aplican desde hosts/<hostname>/).
HOST_FILES=(
    "hypr/monitors.lua"
)
