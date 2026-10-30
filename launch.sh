#!/bin/sh

script=$(cat << 'EOF'
show_message() {
    local -r level="$1"
    local -r message="$2"

    flatpak run --command=zenity "$FLATPAK_ID" --"$level" --text="$message" --title=ControllerBuddy --width=450 --window-icon=/app/lib/ControllerBuddy.png
}

check_retval() {
    local -r retval=$?
    local -r error_message="$1"

    if [ "$retval" -ne 0 ]
    then
        show_message error "<b>Error:</b> $error_message"
        exit 1
    fi
}

uinput_accessible() {
    [ -r /dev/uinput ] && [ -w /dev/uinput ]
}

queue_file_update() {
    local -r file="$1"
    local -r content="$2"

    if [ "$(cat "$file" 2>/dev/null)" != "$content" ]
    then
        pending_updates+=("$file" "$content")
        pending_files+="\n<tt><small>$file</small></tt>"
    fi
}

if uinput_accessible
then
    exit 0
fi

pending_updates=()
pending_files=''

if [ ! -e /dev/uinput ]
then
    queue_file_update /etc/modules-load.d/controllerbuddy.conf uinput
fi
queue_file_update /etc/udev/rules.d/60-controllerbuddy.rules 'KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"'

if [ "${#pending_updates[@]}" -gt 0 ]
then
    show_message info "Please authenticate to allow the initialization of:$pending_files"

    command -v pkexec >/dev/null
    check_retval 'pkexec is not installed. Please restart this script after manually installing pkexec.'

    pkexec sh -c '
        while [ "$#" -gt 0 ]
        do
            mkdir -p "$(dirname "$1")" &&
            printf "%s\n" "$2" > "$1" || exit 1
            shift 2
        done

        modprobe uinput &&
        udevadm control --reload &&
        udevadm trigger --action=add --subsystem-match=misc --sysname-match=uinput &&
        udevadm settle
    ' sh "${pending_updates[@]}"
    check_retval 'Failed to configure the system for ControllerBuddy.'

    if ! uinput_accessible
    then
        show_message warning '<b>Important:</b> System configuration has been modified.\nPlease reboot your system!'
        exit 1
    fi
else
    show_message error '<b>Error:</b> ControllerBuddy cannot access <tt><small>/dev/uinput</small></tt>.'
    exit 1
fi
EOF
)
readonly script

flatpak-spawn --host --env=FLATPAK_ID="$FLATPAK_ID" bash -c "$script" || exit "$?"

CONTROLLER_BUDDY_PROFILES_DIR=/app/share/ControllerBuddy-Profiles exec ControllerBuddy "$@"
