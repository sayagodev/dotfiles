#!/bin/bash
# Skills menu — inspiración tmux/menu.sh (SUPER+U) + keybindings.sh (2 líneas)
# Fix: usa -sep '\0' -eh 2 para legibilidad, sin \n literales
# Tema: tmux/menu.rasi con override de tamaño

THEME="$HOME/.config/tmux/menu.rasi"
[[ -f "$THEME" ]] || THEME="$HOME/.config/rofi/config-compact.rasi"

groups=()
skills=()
descs=()
hints=()

add() {
  groups+=("$1")
  skills+=("$2")
  descs+=("$3")
  hints+=("$4")
}

# ── WORKFLOW ──
add "🏗️  Workflow" "audit"     "Audita repo y genera AGENTS.md"        "al iniciar o sin docs · /audit src/auth"
add "🏗️  Workflow" "scope"     "Define QUÉ construir (docs/scope/)"    "planear producto o nueva feature"
add "🏗️  Workflow" "architect" "Diseña CÓMO (docs/specs/)"             "decisión técnica sin spec"
add "🏗️  Workflow" "develop"   "Construye feature desde spec"          "UI/backend ya diseñado"
add "🏗️  Workflow" "check"     "Verifica vs spec + code review"        "/check verify tras develop, review antes PR"
add "🏗️  Workflow" "test"      "Genera suite de tests"                 "tras implementar feature/fix"
add "🏗️  Workflow" "debug"     "Reproduce → localiza → fix bug"        "test falla o comportamiento roto"
add "🏗️  Workflow" "sync"      "Sincroniza AGENTS.md y scope"          "al final, antes de merge"
add "🏗️  Workflow" "document"  "Escribe PR/changelog/release-note"     "prosa humana del cambio"

# ── ARQUITECTURA ──
add "🏛️  Arquitectura" "fp-clean-architecture" "Capas FP: dominio → casos → infra → oRPC" "estructurar TS limpio"
add "🏛️  Arquitectura" "orpc"                "oRPC contract-first + TanStack Query"      "routers / contracts / handlers"
add "🏛️  Arquitectura" "payload-cms"         "Payload CMS headless + Next.js"            "collections / fields / hooks"
add "🏛️  Arquitectura" "next-best-practices" "Best practices Next.js RSC"                "file conventions, RSC, metadata"
add "🏛️  Arquitectura" "better-auth"         "Better Auth full-stack TS"                 "email / OAuth / 2FA / sessions"
add "🏛️  Arquitectura" "better-auth-payload-integration" "Sync BetterAuth ↔ Payload"     "solo Vanguardias Iberófonas"
add "🏛️  Arquitectura" "vercel-react-best-practices" "Performance React/Next"            "optimizar componentes/fetch"
add "🏛️  Arquitectura" "vercel-composition-patterns" "Patrones composición React"         "compound components"

# ── AUTH CLERK ──
add "🔐 Auth Clerk" "clerk"                           "Router Clerk (deriva a sub-skills)"     "dudas sobre qué clerk-* usar"
add "🔐 Auth Clerk" "clerk-setup"                     "Quickstart Clerk"                       "instalar Clerk por 1a vez"
add "🔐 Auth Clerk" "clerk-nextjs-patterns"           "Middleware / Server Actions"            "Next.js + Clerk"
add "🔐 Auth Clerk" "clerk-react-patterns"            "Vite/CRA + ClerkProvider"               "React SPA"
add "🔐 Auth Clerk" "clerk-react-router-patterns"     "React Router v7/v8"                     "SSR + Clerk"
add "🔐 Auth Clerk" "clerk-tanstack-patterns"         "TanStack Start + Clerk"                 "Vinxi / createServerFn"
add "🔐 Auth Clerk" "clerk-expo"                      "Expo / React Native"                    "app móvil"
add "🔐 Auth Clerk" "clerk-chrome-extension-patterns" "Chrome Extension + Clerk"               "popup / sidepanel"
add "🔐 Auth Clerk" "clerk-orgs"                      "Organizations B2B multi-tenant"         "workspaces / RBAC / SSO"
add "🔐 Auth Clerk" "clerk-billing"                   "Billing / PricingTable"                 "SaaS monetización"
add "🔐 Auth Clerk" "clerk-custom-ui"                 "Flujos custom + theming"                "sign-in visual custom"
add "🔐 Auth Clerk" "clerk-cli"                       "CLI clerk"                              "users / orgs / impersonate"
add "🔐 Auth Clerk" "clerk-backend-api"               "REST API Clerk"                         "scripts backend"
add "🔐 Auth Clerk" "clerk-webhooks"                  "Webhooks Clerk"                         "sync DB / eventos"
add "🔐 Auth Clerk" "clerk-testing"                   "E2E Playwright/Cypress"                 "testear flujos auth"

# ── FRONTEND ──
add "🧱 Frontend" "shadcn"              "Componentes shadcn/ui"                   "añadir / buscar / fix"
add "🧱 Frontend" "building-components" "Componentes accesibles / composables"    "crear componente desde 0"
add "🧱 Frontend" "css-docs"            "Docs CSS en español"                     "dudas flex / grid / anim"
add "🧱 Frontend" "bubbletea"           "TUIs Go Bubble Tea (Elm MVU)"            "TUI Go"
add "🧱 Frontend" "bubbles"             "Componentes Bubbles v2"                  "list / table / input Go"
add "🧱 Frontend" "playwright-cli"      "Automatiza navegador"                    "E2E o scrapear"
add "🧱 Frontend" "variant"             "Genera variantes de componente"          "iterar y elegir"
add "🧱 Frontend" "break"               "Stress-test componente"                  "todos los estados"

# ── DISEÑO ──
add "🎨 Diseño" "better-interface"           "Review combinado a11y+layout+color"  "audit completo UI"
add "🎨 Diseño" "better-accessibility"       "Accesibilidad WCAG"                  "cumplir a11y"
add "🎨 Diseño" "fixing-accessibility"       "Fix ARIA / keyboard / foco"          "corregir HTML"
add "🎨 Diseño" "web-design-guidelines"      "Guidelines interfaz web"             "review UX"
add "🎨 Diseño" "better-layout"              "Agrupación / alineación"             "layout / reading order"
add "🎨 Diseño" "better-colors"              "Sistema color / paletas"             "tokens / contraste"
add "🎨 Diseño" "better-typography"          "Escala tipográfica"                  "type scale / spacing"
add "🎨 Diseño" "better-ui"                  "Polish radius / sombras / iconos"    "detalles finos"
add "🎨 Diseño" "better-writing"             "Mejora copy producto"                "textos UX"
add "🎨 Diseño" "interface-review"           "Review multi-categoría"              "análisis profundo"
add "🎨 Diseño" "high-end-visual-design"     "Diseño agencia premium"              "look luxury"
add "🎨 Diseño" "design-taste-frontend-v1"   "Taste v1 legacy"                     "solo compat"
add "🎨 Diseño" "emil-design-eng"            "Filosofía Emil Kowalski"             "polish invisible"
add "🎨 Diseño" "make-interfaces-feel-better" "Polish 120fps"                      "review rápido/completo"
add "🎨 Diseño" "ui-craft"                   "Spring physics + CSS moderno"        "botones / modals 120fps"

# ── ANIMACIÓN ──
add "✨ Animación" "animations-web"           "Metodología Emil Kowalski UI motion"   "CUALQUIER animación web"
add "✨ Animación" "12-principles-of-animation" "12 principios Disney web"           "auditar calidad motion"
add "✨ Animación" "gsap"                     "GSAP GreenSock"                        "tweens / timelines"
add "✨ Animación" "gsap-patterns"            "Patrones GSAP reales (390)"            "scroll / pin / marquee"
add "✨ Animación" "motion"                   "Motion.dev (ex-Framer)"                "elige vs GSAP"
add "✨ Animación" "threejs-fundamentals"     "Three.js escena / cámara"              "setup 3D"
add "✨ Animación" "threejs-geometry"         "Geometrías / BufferGeometry"           "crear shapes 3D"
add "✨ Animación" "threejs-animation"        "Keyframe / skeletal / morph"           "animar objetos 3D"
add "✨ Animación" "threejs-interaction"      "Raycasting / controles"                "interacción 3D"
add "✨ Animación" "threejs-shaders"          "Shaders GLSL"                          "efectos custom"

# ── IMAGEN ──
add "🖼️  Imagen" "brandkit"                  "Brand boards / logo systems"           "identidad visual"
add "🖼️  Imagen" "imagegen-frontend-web"     "Refs web (1 img por sección)"          "landings / marketing"
add "🖼️  Imagen" "imagegen-frontend-mobile"  "Screens mobile en mockup"              "app iOS / Android"
add "🖼️  Imagen" "diagram-design"            "Diagramas arquitectura / flow / ER"    "HTML / SVG branded"
add "🖼️  Imagen" "explain-interface"         "Reverse-engineer UI"                   "con screenshot / URL"

# ── UTILIDADES ──
add "🛠️  Utilidades" "caveman"               "Modo cavernícola -75% tokens"          "respuestas concisas"
add "🛠️  Utilidades" "caveman-commit"        "Commits Conventional cortos"           "mensajes commit"
add "🛠️  Utilidades" "humanizer"             "Humaniza texto IA"                     "reescribir copy"
add "🛠️  Utilidades" "find-skills"           "Descubre / instala skills"             "¿hay skill para X?"
add "🛠️  Utilidades" "datamatic-eng-os"      "OS Datamatic ~/workspace/datamatic"    "SOLO cliente Datamatic"
add "🛠️  Utilidades" "datamatic-eng-os-replit" "OS Datamatic Replit"                 "SOLO Replit"

# ── Construir menú 2 líneas + \0 (como keybindings.sh) ──
# Línea 1: skill  ·  GRUPO
# Línea 2: ➔ desc  •  hint
choice=$(for ((i=0; i<${#skills[@]}; i++)); do
  printf "%s  ·  %s\n➔ %s  •  %s\0" "${skills[$i]}" "${groups[$i]}" "${descs[$i]}" "${hints[$i]}"
done | rofi -dmenu -i -p "skills:" -sep '\0' -eh 2 -theme "$THEME" \
  -theme-str 'window { width: 52em; height: 36em; } listview { lines: 14; } element { padding: 0.55em 0.8em; border-radius: 0.6em; }' \
  -format i 2>/dev/null)

[[ -z $choice ]] && exit 0

skill="${skills[$choice]}"
desc="${descs[$choice]}"
hint="${hints[$choice]}"
group="${groups[$choice]}"

if command -v wl-copy >/dev/null 2>&1; then
  echo -n "$skill" | wl-copy
  copied=" · copiado"
else
  copied=""
fi

skill_path="$HOME/.agents/skills/$skill/SKILL.md"

# Mensaje con saltos reales (no literales \n)
if [[ -f "$skill_path" ]]; then
  msg=$(printf "[%s] %s%s\n%s\n%s\n\n%s" "$group" "$skill" "$copied" "$desc" "$hint" "$skill_path")
else
  msg=$(printf "[%s] %s%s\n%s\n%s" "$group" "$skill" "$copied" "$desc" "$hint")
fi

# Usa notify-send si existe, si no rofi -e
if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "skills" "$group — $skill$copied" "$desc
$hint
$skill_path" 2>/dev/null &
  # también muestra en rofi para confirmar (opcional, 2s)
  rofi -theme "$THEME" -e "$msg" 2>/dev/null &
else
  rofi -theme "$THEME" -e "$msg" 2>/dev/null
fi
