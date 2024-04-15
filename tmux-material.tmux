#!/usr/bin/env bash
export LC_ALL=en_US.UTF-8

#current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_tmux_option() {
    local option=$1
    local default_value=$2
    local option_value=$(tmux show-option -gqv "$option")
    if [ -z "$option_value" ]; then
        echo $default_value
    else
        echo $option_value
    fi
}

l_sep=$(get_tmux_option "@tmux-material-left-sep" )
r_sep=$(get_tmux_option "@tmux-material-right-sep" )
IFS=' ' read -r -a lplugins <<<"$(get_tmux_option '@tmux-material-left-plugins' '')"
IFS=' ' read -r -a rplugins <<<"$(get_tmux_option '@tmux-material-right-plugins' 'git directory')"
compact=$(get_tmux_option "@tmux-material-compact" false)
div=" █" #div="" #div="" #div=" █" #div=" █"
BG=default
window_status_icon_enable="yes"
window_icon_pos="right"
status_icon_pos="left"
theme_file="$HOME/.cache/ags/user/generated/material_colors.scss"

#while IFS='=' read -r key val; do
while IFS=': ' read -r key val; do
  ## Skip over lines containing comments.
  ## (Lines starting with '#').
  #[ "${key##\#*}" ] || continue
  ## '$key' stores the key.
  ## '$val' stores the value.
  #eval "$key"="$val"
  key="${key//\$/}"
  eval "$key"="$val"

done < $theme_file

variables=("primary" "primaryContainer" "secondary" "secondaryContainer" "tertiary" "tertiaryContainer")

for var in "${variables[@]}"; do
  eval "${var}_box"="#[fg=\$on${var^}]#[bg=\$${var}]#[nobold]#[nounderscore]#[noitalics]"
  eval "${var}_lsep"="#[fg=\${${var}}]#[bg=\$BG]#[nobold]#[nounderscore]#[noitalics]${l_sep}"
  eval "${var}_rsep"="#[fg=\${${var}}]#[bg=\$BG]#[nobold]#[nounderscore]#[noitalics]${r_sep}"
done

declare -A default_plugins=(
    ["git"]="#(git -C #{pane_current_path} rev-parse --abbrev-ref HEAD)"
    #["git"]="#(gitmux #{pane_current_path})"
    #["git"]="#{simple_git_status}"
    ["directory"]="#(basename #{d:pane_current_path})/#{b:pane_current_path}"
    ["session"]="#S"
)

declare -A plugin_colors=(
    ["git"]="secondary"
    ["directory"]="secondary"
    ["window"]="secondary"
)

declare -A plugin_icons=(
    ["git"]=""
    ["directory"]=""
    ["session"]=""
)

set_options() {
    #tmux set-option -g status-interval 60
    tmux set-option -g status-left-length 100
    tmux set-option -g status-right-length 100
    tmux set-option -g status-left ""
    tmux set-option -g status-right ""

    tmux set-option -g pane-active-border-style "fg=$primary"
    tmux set-option -g pane-border-style "fg=${outlineVariant}"

    tmux set-option -g message-style "fg=${onSecondaryContainer},bg=default,align=centre"
    tmux set-option -g status-style "fg=${onSecondaryContainer},bg=default,align=centre"

    tmux set -g status-justify left

    #tmux set-window-option -g window-status-activity-style "bold"
    #tmux set-window-option -g window-status-bell-style "bold"
    #tmux set-window-option -g window-status-current-style "bold"
}

format_builder() {
  local content_left=$1
  local content_right=$2
  local format=$3
  local is_container=$4

  if [ $is_container -eq 0 ]; then
    eval local format_left="\${${format}Container_lsep}\${${format}Container_box}\${content_left}"
    eval local format_div="#[fg=\$${format}]#[bg=\$${format}Container]\$div"
    eval local format_right="\${${format}_box}\${content_right}\${${format}_rsep}"
  else
    eval local format_left="\${${format}_lsep}\${${format}_box}\${content_left}"
    eval local format_div="#[fg=\$${format}Container]#[bg=\$${format}]\$div"
    eval local format_right="\${${format}Container_box}\${content_right}\${${format}Container_rsep}"
  fi

  echo "${format_left}${format_div}${format_right}"
}

session() {
    side=$1
    plugin="session"
    script=${default_plugins[$plugin]}

    if [ $status_icon_pos = "left" ]; then
      status_format=$(format_builder "${plugin_icons[$plugin]}" "${script}" "secondary" 0)
      status_format_prefix=$(format_builder "${plugin_icons[$plugin]}" "${script}" "tertiary" 0)
    else
      status_format=$(format_builder "${script}" "${plugin_icons[$plugin]}" "secondary" 0)
      status_format_prefix=$(format_builder "${script}" "${plugin_icons[$plugin]}" "tertiary" 0)
    fi

    if [ "$side" == "left" ]; then
      tmux set-option -ga status-left "#{?client_prefix,${status_format_prefix} ,${status_format} }"
    else
      tmux set-option -ga status-right "#{?client_prefix, ${status_format_prefix}, ${status_format}}"
    fi
}

status_bar() {
    side=$1
    if [ "$side" == "left" ]; then
        plugins=("${lplugins[@]}")
    else
        plugins=("${rplugins[@]}")
    fi

    for plugin_index in "${!plugins[@]}"; do
        plugin="${plugins[$plugin_index]}"
        if [ -z "${plugin_colors[$plugin]}" ]; then
            continue
        fi

        script=${default_plugins[$plugin]}

        if [ $status_icon_pos = "left" ]; then
          status_format=$(format_builder "${plugin_icons[$plugin]}" "${script}" "${plugin_colors[$plugin]}" 0)
        else
          status_format=$(format_builder "${script}" "${plugin_icons[$plugin]}" "${plugin_colors[$plugin]}" 0)
        fi

        if [ "$side" == "left" ]; then
          tmux set-option -ga status-left "#{?#{!=:${script},},${status_format} ,}"
        else
          tmux set-option -ga status-right "#{?#{!=:${script},}, ${status_format},}"
        fi
    done
}

window_list() {
    if [ "$window_status_icon_enable" = "yes" ]; then
      local window_status=""
      window_status+="#{?window_active,,}"
      window_status+="#{?window_last_flag,,}"
      window_status+="#{?window_zoomed_flag, 󰁌,}"
      window_status+="#{?window_marked_flag, 󰃀,}"
      window_status+="#{?window_silence_flag, 󰂛,}"
      window_status+="#{?window_bell_flag, 󰂞,}"
      window_status+="#{?window_activity_flag, 󱅫,}"
    else
      local window_status=" #F" #!~[*-]MZ
    fi

    if [ $window_icon_pos = "left" ]; then
      window_format=$(format_builder "#I" "#W${window_status}" "secondary" 1)
      window_current_format=$(format_builder "#I" "#W${window_status}" "primary" 1)
    else
      window_format=$(format_builder "#W${window_status}" "#I" "secondary" 1)
      window_current_format=$(format_builder "#W${window_status}" "#I" "primary" 1)
    fi

    tmux set-window-option -g window-status-format "${window_format}"
    tmux set-window-option -g window-status-current-format "${window_current_format}"
}

main() {
    set_options
    status_bar "left"
    window_list
    status_bar "right"
    session "right"
}

main
