#!/bin/bash

xstartup_script=~/.vnc/xstartup
de_was_selected_file="$HOME/.vnc/.kasmvncserver-easy-start-de-was-selected"

manual_xstartup_choice="Manually edit xstartup"
declare -A all_desktop_environments=(
  [Cinnamon]=cinnamon-session
  [Mate]="XDG_CURRENT_DESKTOP=MATE dbus-launch --exit-with-session mate-session"
  [LXDE]=lxsession [Lxqt]=startlxqt
  [KDE]=startkde
  [Gnome]="XDG_CURRENT_DESKTOP=GNOME dbus-launch --exit-with-session /usr/bin/gnome-session"
  [XFCE]=xfce4-session)

readarray -t sorted_desktop_environments < <(for de in "${!all_desktop_environments[@]}"; do echo "$de"; done | sort)

all_desktop_environments[$manual_xstartup_choice]=""
sorted_desktop_environments+=("$manual_xstartup_choice")

detected_desktop_environments=()
declare -A numbered_desktop_environments

print_detected_desktop_environments() {
  declare -i i=1

  echo "Please choose Desktop Environment to run:"
  for detected_de in "${detected_desktop_environments[@]}"; do
    echo "[$i] $detected_de"
    numbered_desktop_environments[$i]=$detected_de
    i+=1
  done
}

detect_desktop_environments() {
  for de_name in "${sorted_desktop_environments[@]}"; do
    if [[ "$de_name" = "$manual_xstartup_choice" ]]; then
      detected_desktop_environments+=("$de_name")
      continue;
    fi

    local executable=${all_desktop_environments[$de_name]}
    executable=($executable)
    executable=${executable[-1]}

    if detect_desktop_environment "$de_name" "$executable"; then
      detected_desktop_environments+=("$de_name")
    fi
  done
}

ask_user_to_choose_de() {
  while : ; do
    print_detected_desktop_environments
    read -r de_number_to_run
    de_name_from_number "$de_number_to_run"
    if [[ -n "$de_name" ]]; then
      break;
    fi

    echo "Incorrect number: $de_number_to_run"
    echo
  done
}

remember_de_choice() {
  touch "$de_was_selected_file"
}

de_was_selected_on_previous_run() {
  [[ -f "$de_was_selected_file" ]]
}

detect_desktop_environment() {
  local de_name="$1"
  local executable="$2"

  if command -v "$executable" &>/dev/null; then
    return 0
  fi

  return 1
}

did_user_forbid_replacing_xstartup() {
  grep -q -v KasmVNC-safe-to-replace-this-file "$xstartup_script"
}

de_cmd_from_name() {
  de_cmd=${all_desktop_environments[$de_name]}
}

de_name_from_number() {
  local de_number_to_run="$1"

  de_name=${numbered_desktop_environments[$de_number_to_run]}
}

warn_xstartup_will_be_overwriten() {
  echo -n "WARNING: $xstartup_script will be overwritten y/N?"
  read -r do_overwrite_xstartup
  if [[ "$do_overwrite_xstartup" = "y" || "$do_overwrite_xstartup" = "Y" ]]; then
    return 0
  fi

  return 1
}

setup_de_to_run_via_xstartup() {
  warn_xstartup_will_be_overwriten
  generate_xstartup "$de_name"
}

generate_xstartup() {
  local de_name="$1"

  de_cmd_from_name

  cat <<-SCRIPT > "$xstartup_script"
    #!/bin/sh
    exec $de_cmd
SCRIPT
  chmod +x "$xstartup_script"
}

user_asked_to_select_de() {
  [[ "$action" = "select-de-and-start" ]]
}

debug() {
  if [ -z "$debug" ]; then return; fi

  echo "$@"
}

if user_asked_to_select_de || ! de_was_selected_on_previous_run; then
  detect_desktop_environments
  ask_user_to_choose_de
  debug "You selected $de_name desktop environment"
  if [[ "$de_name" != "$manual_xstartup_choice" ]]; then
    setup_de_to_run_via_xstartup
  fi
  remember_de_choice
fi
