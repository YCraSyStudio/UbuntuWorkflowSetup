#!/usr/bin/env bash

declare -A APP_LABELS=(
  [docker]="Docker"
  [qemu]="QEMU/KVM (Virtual Machine Manager)"
  [dotnet]=".NET SDK"
  [mysql]="MySQL"
  [postgresql]="PostgreSQL"
  [unity]="Unity Hub"
  [vscode]="Visual Studio Code"
  [dbeaver]="DBeaver"
  [bruno]="Bruno"
  [node]="Node.js"
  [npm]="npm"
  [angular]="Angular CLI"
  [ncu]="npm-check-updates"
  [chatgpt]="ChatGPT"
  [github_cli]="GitHub CLI"
  [atlassian_cli]="Atlassian CLI"
  [yed]="yEd"
  [chromium]="Chromium"
  [chrome]="Google Chrome"
  [telegram]="Telegram Desktop"
  [gnome_manager]="GNOME Extension Manager"
  [copyous]="Copyous"
  [dash_to_panel]="Dash to Panel"
)

DEV_APPS=(
  docker dotnet mysql postgresql unity vscode dbeaver bruno node npm angular ncu chatgpt
  github_cli atlassian_cli qemu
)
PRODUCTIVITY_APPS=(
  yed chromium chrome telegram
)
OTHER_APPS=(
  gnome_manager copyous dash_to_panel
)
APP_KEYS=(
  "${DEV_APPS[@]}"
  "${PRODUCTIVITY_APPS[@]}"
  "${OTHER_APPS[@]}"
)
declare -A APP_DEPTHS=([npm]=1 [angular]=1 [ncu]=1 [copyous]=1 [dash_to_panel]=1)
declare -A APP_INDEX=()
declare -A SELECTED_APPS=()
APP_LINE_OFFSETS=()
MENU_ROWS=0
SELECTOR_ACTIVE=0

is_selected() {
  [[ "${SELECTED_APPS[$1]:-0}" == 1 ]]
}

leave_selector() {
  if ((SELECTOR_ACTIVE)); then
    printf '\033[?1000l\033[?1006l\033[?25h\033[?1049l'
    SELECTOR_ACTIVE=0
  fi
}

print_app_option() {
  local index="$1"
  local current="$2"
  local key="${APP_KEYS[$index]}"
  local indent=""

  if (( ${APP_DEPTHS[$key]:-0} > 0 )); then indent="  "; fi
  if ((index == current)); then
    printf '%s> ' "$indent"
  else
    printf '%s  ' "$indent"
  fi

  if is_selected "$key"; then
    printf '[*] %s' "${APP_LABELS[$key]}"
  else
    printf '[ ] %s' "${APP_LABELS[$key]}"
  fi
}

redraw_app_option() {
  local index="$1"
  local current="$2"
  local lines_up=$((MENU_ROWS + 2 - APP_LINE_OFFSETS[index]))

  printf '\033[%dA\r\033[2K' "$lines_up"
  print_app_option "$index" "$current"
  printf '\033[%dB\r' "$lines_up"
}

set_app_family() {
  local parent="$1"
  local value="$2"
  local child

  SELECTED_APPS["$parent"]="$value"
  case "$parent" in
    node)
      for child in npm angular ncu; do SELECTED_APPS["$child"]="$value"; done
      ;;
    gnome_manager)
      for child in copyous dash_to_panel; do SELECTED_APPS["$child"]="$value"; done
      ;;
  esac
}

select_app_option() {
  local key="$1"
  local value="$2"

  set_app_family "$key" "$value"
  case "$key" in
    npm | angular | ncu)
      if [[ "$value" == 1 ]]; then SELECTED_APPS[node]=1; fi
      ;;
    copyous | dash_to_panel)
      if [[ "$value" == 1 ]]; then SELECTED_APPS[gnome_manager]=1; fi
      ;;
  esac
}

redraw_all_options() {
  local current="$1"
  local index

  for index in "${!APP_KEYS[@]}"; do
    redraw_app_option "$index" "$current"
  done
}

print_app_group() {
  local title="$1"
  local current="$2"
  local key index
  shift 2

  printf '%s\n' "- $title"
  ((MENU_ROWS += 1))
  for key in "$@"; do
    index="${APP_INDEX[$key]}"
    APP_LINE_OFFSETS[index]="$MENU_ROWS"
    print_app_option "$index" "$current"
    printf '\n'
    ((MENU_ROWS += 1))
  done
}

select_apps() {
  local index key pressed sequence sequence_char mouse_data mouse_button
  local previous current=0

  for index in "${!APP_KEYS[@]}"; do
    key="${APP_KEYS[$index]}"
    APP_INDEX["$key"]="$index"
    SELECTED_APPS["$key"]=1
  done

  if [[ ! -t 0 || ! -t 1 ]]; then
    log "Entrada no interactiva: se instalarán todas las aplicaciones"
    return
  fi

  SELECTOR_ACTIVE=1
  trap leave_selector EXIT
  trap 'leave_selector; exit 130' INT TERM HUP
  printf '\033[?1049h\033[?25l\033[?1000h\033[?1006h\033[2J\033[H'
  printf 'Selecciona las aplicaciones que quieres instalar:\n'
  MENU_ROWS=0
  print_app_group "Herramientas de desarrollo" "$current" "${DEV_APPS[@]}"
  print_app_group "Productividad" "$current" "${PRODUCTIVITY_APPS[@]}"
  print_app_group "Otros" "$current" "${OTHER_APPS[@]}"

  printf '\n\033[1m↑/↓ o rueda\033[0m \033[2mmover\033[0m  '
  printf '\033[1mEspacio\033[0m \033[2mseleccionar\033[0m  '
  printf '\033[1mEnter\033[0m \033[2mcontinuar\033[0m  '
  printf '\033[1mT\033[0m \033[2mtodo\033[0m  '
  printf '\033[1mN\033[0m \033[2mnada\033[0m\n'

  while true; do
    IFS= read -rsn1 pressed
    case "$pressed" in
      '') break ;;
      $'\e')
        previous="$current"
        sequence=""
        IFS= read -rsn1 sequence || true
        case "$sequence" in
          '[')
            IFS= read -rsn1 sequence_char || true
            if [[ "$sequence_char" == '<' ]]; then
              mouse_data=""
              while IFS= read -rsn1 sequence_char; do
                [[ "$sequence_char" == M || "$sequence_char" == m ]] && break
                mouse_data+="$sequence_char"
              done
              mouse_button="${mouse_data%%;*}"
              case "$mouse_button" in
                64) current=$(((current - 1 + ${#APP_KEYS[@]}) % ${#APP_KEYS[@]})) ;;
                65) current=$(((current + 1) % ${#APP_KEYS[@]})) ;;
              esac
            else
              while [[ "$sequence_char" != [A-Za-z~] ]]; do
                IFS= read -rsn1 sequence_char || break
              done
              case "$sequence_char" in
                A) current=$(((current - 1 + ${#APP_KEYS[@]}) % ${#APP_KEYS[@]})) ;;
                B) current=$(((current + 1) % ${#APP_KEYS[@]})) ;;
              esac
            fi
            ;;
          'O')
            IFS= read -rsn1 sequence_char || true
            case "$sequence_char" in
              A) current=$(((current - 1 + ${#APP_KEYS[@]}) % ${#APP_KEYS[@]})) ;;
              B) current=$(((current + 1) % ${#APP_KEYS[@]})) ;;
            esac
            ;;
        esac
        if ((current != previous)); then
          redraw_app_option "$previous" "$current"
          redraw_app_option "$current" "$current"
        fi
        ;;
      ' ')
        key="${APP_KEYS[$current]}"
        if is_selected "$key"; then
          select_app_option "$key" 0
        else
          select_app_option "$key" 1
        fi
        redraw_all_options "$current"
        ;;
      t | T)
        for key in "${APP_KEYS[@]}"; do SELECTED_APPS["$key"]=1; done
        redraw_all_options "$current"
        ;;
      n | N)
        for key in "${APP_KEYS[@]}"; do SELECTED_APPS["$key"]=0; done
        redraw_all_options "$current"
        ;;
    esac
  done

  leave_selector
  trap - EXIT INT TERM HUP
  log "Selección de aplicaciones confirmada"
}
