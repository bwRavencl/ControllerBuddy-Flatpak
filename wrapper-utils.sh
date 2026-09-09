#!/bin/bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]
then
    echo "Error: $(basename "${BASH_SOURCE[0]}") is a library script and must be sourced, not executed directly." >&2
    exit 1
fi

if [[ "$OSTYPE" != linux* ]]
then
    echo 'Error: This script must be run in a GNU/Linux Bash environment.' >&2
    exit 1
fi

script_name=$(basename "${BASH_SOURCE[-1]}")
readonly script_name
cb_app_id=de.bwravencl.ControllerBuddy
readonly cb_app_id
cb_device_name='ControllerBuddy Joystick'
readonly cb_device_name

exec_on_exit() {
    local -r command="$1"

    on_exit_commands+=("$command")
}

pop_on_exit() {
    if [ "${#on_exit_commands[@]}" -gt 0 ]
    then
        unset 'on_exit_commands[-1]'
        on_exit_commands=("${on_exit_commands[@]}")
    fi
}

remove_on_exit() {
    local command="$1"

    local i
    for i in "${!on_exit_commands[@]}"
    do
        if [[ "${on_exit_commands[i]}" == "$command" ]]
        then
            unset "on_exit_commands[i]"
        fi
    done

    on_exit_commands=("${on_exit_commands[@]}")
}

on_exit() {
    local command
    for command in "${on_exit_commands[@]}"
    do
        echo "eval $command"
        eval "$command"
    done
}

trap on_exit EXIT

zenity() {
    flatpak run --command=zenity "$cb_app_id" --title="ControllerBuddy - $script_name" --width=450 "$@"
}

show_message() {
    local -r level="$1"
    local -r message="$2"

    close_progress

    local target_fd=1
    if [[ "$level" == error ]]
    then
        target_fd=2
    fi
    readonly target_fd

    zenity --"$level" --text="<b>${level^}</b>\n$message" ||
    echo -e "${level^}: $message" >&"$target_fd"
}

show_progress() {
    local -r text="$1"

    if [[ -z "$zenity_fd" ]]
    then
        exec {zenity_fd}> >(zenity --progress --pulsate --no-cancel --auto-close)
        exec_on_exit close_progress
    fi

    echo "# $text" >&"$zenity_fd"
}

close_progress() {
    if [[ -n "$zenity_fd" ]]
    then
        echo "100" >&"$zenity_fd"
        exec {zenity_fd}>&-
        unset zenity_fd
    fi

    remove_on_exit close_progress
}

check_retval() {
    local -r retval=$?
    local -r error_message="$1"

    if [ "$retval" -ne 0 ]
    then
        show_message error "$error_message"
        exit 1
    fi
}

resolve_cb_profile() {
    local -r profile_arg="$1"

    cb_profile="${profile_arg%.json}"
    cb_profile_json="/app/share/ControllerBuddy-Profiles/$cb_profile.json"

    flatpak run --command=test "$cb_app_id" -e "$cb_profile_json"
    check_retval "Profile does not exist: <tt><small>$cb_profile_json</small></tt>"
}

update_cb() {
    show_progress 'Updating ControllerBuddy...'

    flatpak update -y "$cb_app_id" ||
    show_message warning 'Failed to update ControllerBuddy via Flatpak'
}

launch_cb() {
    local -r cb_profile_json="$1"

    show_progress 'Launching ControllerBuddy...'

    flatpak run "$cb_app_id" -autostart local -profile "$cb_profile_json" -tray &
    local -r cb_pid=$!
    exec_on_exit 'killall -q ControllerBuddy'

    while true
    do
        show_progress "Waiting for $cb_device_name to show up..."

        local timeout=25
        local i=0
        local device_found=false

        while true
        do
            if grep -q "$cb_device_name" /proc/bus/input/devices
            then
                device_found=true
                break
            fi

            kill -0 "$cb_pid" 2>/dev/null
            check_retval 'ControllerBuddy failed to start or crashed unexpectedly.'

            if [ "$i" -ge "$timeout" ]
            then
                break
            fi

            sleep 1
            (( i++ ))
        done

        if [ "$device_found" = true ]
        then
            break
        fi

        close_progress
        zenity --question --text="The $cb_device_name did not show up within $timeout seconds.\n\nPlease check that a controller is connected." --ok-label=Retry --cancel-label=Abort || exit 1
    done
}

ensure_flatpak_app_installed() {
    local -r app_id="$1"
    local -r display_name="$2"

    if ! flatpak list --app | grep -q "$app_id"
    then
        show_progress "Installing $display_name..."

        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo &&
        flatpak install -y flathub "$app_id"
        check_retval "Failed to install $display_name via Flatpak"
    else
        show_progress "Updating $display_name..."

        flatpak update -y "$app_id" ||
        show_message warning "Failed to update $display_name via Flatpak"
    fi
}
