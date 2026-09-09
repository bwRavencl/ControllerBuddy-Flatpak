#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wrapper_utils_sh="$script_dir/wrapper-utils.sh"

dosbox_app_id=io.github.dosbox-staging
readonly dosbox_app_id

if [[ -f "$wrapper_utils_sh" ]]
then
    source "$wrapper_utils_sh"
else
    echo "Error: Required file $wrapper_utils_sh not found" >&2
    exit 1
fi

if [[ "$#" -lt 2 || "$#" -gt 3 ]]
then
    show_message error "Invalid launch arguments for $script_name\nUsage:\n<tt><small>$script_name &lt;profile.json&gt; &lt;dosbox.conf&gt; [mouse_sensitivity]</small></tt>"
    exit 1
fi

resolve_cb_profile "$1"

dosbox_conf="$2"
readonly dosbox_conf

if [ ! -f "$dosbox_conf" ]
then
    show_message error "DOSBox configuration file does not exist:\n<tt><small>$dosbox_conf</small></tt>"
    exit 1
fi

mouse_sensitivity="${3:-1.0}"
readonly mouse_sensitivity

if [[ ! "$mouse_sensitivity" =~ ^-?[0-9]*\.?[0-9]+$ ]]
then
    show_message error "Invalid mouse sensitivity value: <tt><small>$mouse_sensitivity</small></tt>\nThe value must be a valid floating-point number."
    exit 1
fi

update_cb
launch_cb "$cb_profile_json"

ensure_flatpak_app_installed "$dosbox_app_id" 'DOSBox Staging'

close_progress

cd "$(dirname "$dosbox_conf")" &&
SDL_JOYSTICK_DEVICE="/dev/input/$(awk -v RS='' "/Name=\"$cb_device_name\"/{match(\$0, /js[0-9]+/); print substr(\$0, RSTART, RLENGTH); exit}" /proc/bus/input/devices)" \
SDL_MOUSE_RELATIVE_SPEED_SCALE="$mouse_sensitivity" \
flatpak run "$dosbox_app_id" -conf "$dosbox_conf"
check_retval 'Failed to launch DOSBox'
