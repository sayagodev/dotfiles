// dotfiles-tui — selección interactiva de lo que aplica el overlay.
//
// No reimplementa la lógica: muestra el estado (scripts/status.sh) y
// ejecuta install.sh --only <selección>. Así la TUI y el modo clásico
// nunca se desincronizan.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// -------------------------------------------------------------
// Datos
// -------------------------------------------------------------

type item struct {
	key      string
	title    string
	desc     string
	selected bool
	status   string
	detail   string
}

type statusResult struct {
	data map[string][2]string
	err  error
}

type execDoneMsg struct{ err error }

func defaultItems() []item {
	return []item{
		{key: "links", title: "Configuración base", desc: "Symlinks: bash, hypr, tmux, fcitx5, kanata, wallpaper", selected: true},
		{key: "overrides", title: "Overrides de ML4W", desc: "Ficheros sin hook: QML, hypridle, settings, mimeapps", selected: true},
		{key: "host", title: "Perfil de hardware", desc: "Monitores de este equipo (hosts/<hostname>)", selected: true},
		{key: "native", title: "Paquetes oficiales", desc: "pacman --needed, incluidos los de hardware"},
		{key: "aur", title: "Paquetes AUR", desc: "yay/paru --needed"},
		{key: "flatpak", title: "Apps Flatpak", desc: "flatpak install"},
		{key: "tools", title: "Herramientas", desc: "oh-my-posh y nvm"},
		{key: "system", title: "Servicios y grupos", desc: "systemd, grupos del usuario y unidades"},
		{key: "nvim", title: "Neovim", desc: "clona git@github.com:sayagodev/nvim.git"},
	}
}

func recommended() map[string]bool {
	return map[string]bool{"links": true, "overrides": true, "host": true}
}

func hostname() string {
	if h := os.Getenv("DOTFILES_HOST"); h != "" {
		return h
	}
	if b, err := os.ReadFile("/etc/hostname"); err == nil {
		if h := strings.TrimSpace(string(b)); h != "" {
			return h
		}
	}
	if h, err := os.Hostname(); err == nil {
		return h
	}
	return "unknown"
}

func repoRoot() string {
	if r := os.Getenv("DOTFILES_ROOT"); r != "" {
		return r
	}
	if exe, err := os.Executable(); err == nil {
		dir := filepath.Dir(exe)
		for i := 0; i < 6; i++ {
			if _, err := os.Stat(filepath.Join(dir, "install.sh")); err == nil {
				return dir
			}
			dir = filepath.Dir(dir)
		}
	}
	if wd, err := os.Getwd(); err == nil {
		return wd
	}
	return "."
}

// -------------------------------------------------------------
// Teclas
// -------------------------------------------------------------

type keyMap struct {
	Up, Down, Toggle, All, None, Recommended, Dry, Apply, Back, Quit, Help key.Binding
}

func newKeys() keyMap {
	return keyMap{
		Up:          key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "subir")),
		Down:        key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "bajar")),
		Toggle:      key.NewBinding(key.WithKeys(" ", "t"), key.WithHelp("espacio", "marcar")),
		All:         key.NewBinding(key.WithKeys("a"), key.WithHelp("a", "todo")),
		None:        key.NewBinding(key.WithKeys("n"), key.WithHelp("n", "nada")),
		Recommended: key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "recomendado")),
		Dry:         key.NewBinding(key.WithKeys("d"), key.WithHelp("d", "dry-run")),
		Apply:       key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "aplicar")),
		Back:        key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		Quit:        key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "salir")),
		Help:        key.NewBinding(key.WithKeys("?"), key.WithHelp("?", "ayuda")),
	}
}

func (k keyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Toggle, k.All, k.Recommended, k.Dry, k.Apply, k.Quit}
}

func (k keyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Up, k.Down, k.Toggle},
		{k.All, k.None, k.Recommended},
		{k.Dry, k.Apply, k.Back, k.Quit},
	}
}

// -------------------------------------------------------------
// Estilos
// -------------------------------------------------------------

var (
	titleStyle   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("39"))
	subStyle     = lipgloss.NewStyle().Faint(true)
	cursorStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("39")).Bold(true)
	checkedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	unchecked    = lipgloss.NewStyle().Faint(true)
	okStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	partialStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	pendingStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("203"))
	naStyle      = lipgloss.NewStyle().Faint(true)
	errorStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("203")).Bold(true)
	successStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("42")).Bold(true)
	helpStyle    = lipgloss.NewStyle().Faint(true)
	messageStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	dividerStyle = lipgloss.NewStyle().Faint(true)
	headerBox    = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("39")).Padding(0, 1)
)

func badge(it item) string {
	if it.detail == "" {
		return naStyle.Render("…")
	}
	switch it.status {
	case "ok":
		return okStyle.Render("✔ " + it.detail)
	case "partial":
		return partialStyle.Render("◐ " + it.detail)
	case "pending":
		return pendingStyle.Render("○ " + it.detail)
	default:
		return naStyle.Render("— " + it.detail)
	}
}

// -------------------------------------------------------------
// Modelo
// -------------------------------------------------------------

type model struct {
	root    string
	items   []item
	cursor  int
	dry     bool
	confirm bool
	done    bool
	execErr error
	loaded  bool
	loadErr string
	message string
	width   int
	height  int
	help    help.Model
	keys    keyMap
}

func newModel(root string) model {
	h := help.New()
	h.ShowAll = false
	return model{
		root:  root,
		items: defaultItems(),
		help:  h,
		keys:  newKeys(),
	}
}

func (m model) Init() tea.Cmd {
	return loadStatus(m.root)
}

func loadStatus(root string) tea.Cmd {
	return func() tea.Msg {
		out, err := exec.Command("bash", filepath.Join(root, "scripts", "status.sh")).Output()
		if err != nil {
			return statusResult{err: err}
		}
		data := map[string][2]string{}
		for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			parts := strings.Split(line, "|")
			if len(parts) >= 3 {
				data[parts[0]] = [2]string{parts[1], strings.Join(parts[2:], "|")}
			}
		}
		return statusResult{data: data}
	}
}

func (m model) selectedKeys() []string {
	keys := make([]string, 0, len(m.items))
	for _, it := range m.items {
		if it.selected {
			keys = append(keys, it.key)
		}
	}
	return keys
}

func (m model) installCmd() *exec.Cmd {
	args := []string{filepath.Join(m.root, "install.sh"), "--only", strings.Join(m.selectedKeys(), ",")}
	if m.dry {
		args = append(args, "--dry-run")
	}
	cmd := exec.Command("bash", args...)
	cmd.Dir = m.root
	cmd.Env = append(os.Environ(), "DOTFILES_HOST="+hostname())
	return cmd
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.help.Width = msg.Width - 4
		return m, nil

	case statusResult:
		m.loaded = true
		if msg.err != nil {
			m.loadErr = msg.err.Error()
			return m, nil
		}
		for i := range m.items {
			if s, ok := msg.data[m.items[i].key]; ok {
				m.items[i].status = s[0]
				m.items[i].detail = s[1]
			}
		}
		return m, nil

	case execDoneMsg:
		m.done = true
		m.execErr = msg.err
		return m, nil

	case tea.KeyMsg:
		if m.done {
			switch msg.String() {
			case "enter", "q", "esc", "ctrl+c":
				return m, tea.Quit
			}
			return m, nil
		}

		if m.confirm {
			switch msg.String() {
			case "enter":
				if len(m.selectedKeys()) == 0 {
					m.message = "Selecciona al menos una categoría."
					return m, nil
				}
				m.message = ""
				return m, tea.ExecProcess(m.installCmd(), func(err error) tea.Msg {
					return execDoneMsg{err: err}
				})
			case "esc", "q":
				m.confirm = false
				m.message = ""
			}
			return m, nil
		}

		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.items)-1 {
				m.cursor++
			}
		case " ", "t":
			m.items[m.cursor].selected = !m.items[m.cursor].selected
		case "a":
			for i := range m.items {
				m.items[i].selected = true
			}
		case "n":
			for i := range m.items {
				m.items[i].selected = false
			}
		case "r":
			rec := recommended()
			for i := range m.items {
				m.items[i].selected = rec[m.items[i].key]
			}
		case "d":
			m.dry = !m.dry
		case "enter":
			if len(m.selectedKeys()) == 0 {
				m.message = "Selecciona al menos una categoría (espacio para marcar)."
				return m, nil
			}
			m.message = ""
			m.confirm = true
		case "?":
			m.help.ShowAll = !m.help.ShowAll
		}
		return m, nil
	}
	return m, nil
}

// -------------------------------------------------------------
// Vista
// -------------------------------------------------------------

func (m model) View() string {
	if m.done {
		return m.viewDone()
	}
	if m.confirm {
		return m.viewConfirm()
	}

	var b strings.Builder
	b.WriteString(titleStyle.Render("dotfiles") + subStyle.Render(" · overlay para ML4W") + "\n")

	mode := "solo lectura: nada seleccionado"
	if m.dry {
		mode = partialStyle.Render("DRY-RUN: no escribe nada")
	} else if len(m.selectedKeys()) > 0 {
		mode = fmt.Sprintf("%d categoría(s) seleccionada(s)", len(m.selectedKeys()))
	}
	b.WriteString(subStyle.Render("host "+hostname()+" · "+m.root) + "\n")
	b.WriteString(mode + "\n")
	b.WriteString(dividerStyle.Render(strings.Repeat("─", min(max(m.width-2, 30), 72))) + "\n\n")

	for i, it := range m.items {
		cursor := "  "
		if i == m.cursor {
			cursor = cursorStyle.Render("> ")
		}
		box := unchecked.Render("[ ]")
		if it.selected {
			box = checkedStyle.Render("[x]")
		}
		title := fmt.Sprintf("%-26s", it.title)
		if i == m.cursor {
			title = cursorStyle.Render(title)
		}
		line := fmt.Sprintf("%s%s %s %s", cursor, box, title, badge(it))
		b.WriteString(line + "\n")
		if i == m.cursor {
			b.WriteString("      " + subStyle.Render(it.desc) + "\n")
		}
	}

	b.WriteString("\n")
	if !m.loaded {
		b.WriteString(subStyle.Render("comprobando estado…") + "\n")
	} else if m.loadErr != "" {
		b.WriteString(messageStyle.Render("no pude leer el estado: "+m.loadErr) + "\n")
	}
	if m.message != "" {
		b.WriteString(messageStyle.Render(m.message) + "\n")
	}
	b.WriteString(helpStyle.Render(m.help.View(m.keys)))
	b.WriteString("\n" + dividerStyle.Render(strings.Repeat("─", min(max(m.width-2, 30), 72))))
	return b.String()
}

func (m model) viewConfirm() string {
	var b strings.Builder
	b.WriteString(headerBox.Render(titleStyle.Render("Aplicar selección")) + "\n\n")
	for _, it := range m.items {
		if !it.selected {
			continue
		}
		b.WriteString(checkedStyle.Render("  ✔ ") + it.title + subStyle.Render(" · "+it.detailOrDesc()) + "\n")
	}
	if m.dry {
		b.WriteString("\n" + partialStyle.Render("  MODO DRY-RUN: se mostrará el plan, sin escribir.") + "\n")
	} else {
		b.WriteString("\n" + successStyle.Render("  Se aplicará de verdad (con backup de lo que reemplace).") + "\n")
	}
	if m.message != "" {
		b.WriteString("\n" + messageStyle.Render(m.message) + "\n")
	}
	b.WriteString("\n" + helpStyle.Render("enter aplicar · esc volver"))
	return b.String()
}

func (m model) viewDone() string {
	var b strings.Builder
	if m.execErr != nil {
		b.WriteString(errorStyle.Render("✘ La instalación terminó con error") + "\n\n")
		b.WriteString("Revisa el resumen de arriba y el log:\n")
		b.WriteString(subStyle.Render("  ~/.local/state/dotfiles/install.log") + "\n")
	} else {
		b.WriteString(successStyle.Render("✔ Listo") + "\n\n")
		b.WriteString("Abre un shell nuevo y recarga Hyprland (SUPER + SHIFT + R).\n")
	}
	b.WriteString("\n" + helpStyle.Render("enter para salir"))
	return b.String()
}

func (it item) detailOrDesc() string {
	if it.detail != "" {
		return it.detail
	}
	return it.desc
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// -------------------------------------------------------------
// Modos sin TUI
// -------------------------------------------------------------

func printList(root string) {
	cmd := exec.Command("bash", filepath.Join(root, "scripts", "status.sh"))
	out, err := cmd.Output()
	if err != nil {
		fmt.Fprintln(os.Stderr, "no pude leer el estado:", err)
		os.Exit(1)
	}
	fmt.Printf("%-10s %-8s %s\n", "CATEGORÍA", "ESTADO", "DETALLE")
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		parts := strings.Split(line, "|")
		if len(parts) < 3 {
			continue
		}
		fmt.Printf("%-10s %-8s %s\n", parts[0], parts[1], strings.Join(parts[2:], "|"))
	}
}

func runClassic(root string) {
	cmd := exec.Command("bash", filepath.Join(root, "install.sh"))
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if exit, ok := err.(*exec.ExitError); ok {
			os.Exit(exit.ExitCode())
		}
		os.Exit(1)
	}
}

func main() {
	list := flag.Bool("list", false, "muestra el estado y sale")
	classic := flag.Bool("no-tui", false, "ejecuta install.sh con los valores por defecto")
	flag.Parse()

	root := repoRoot()

	if *list {
		printList(root)
		return
	}
	if *classic {
		runClassic(root)
		return
	}

	p := tea.NewProgram(newModel(root), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "error de la TUI:", err)
		os.Exit(1)
	}
}
