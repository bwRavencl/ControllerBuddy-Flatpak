#!/bin/bash

script=$(cat << 'EOF'
function show_message() {
    local -r level="$1"
    local -r message="$2"

    flatpak run --command=zenity "$FLATPAK_ID" --"$level" --text="$message" --title=ControllerBuddy --width=450
}

function check_retval() {
    local -r retval=$?
    local -r error_message="$1"

    if [ "$retval" -ne 0 ]
    then
        show_message error "<b>Error:</b> $error_message"
        exit 1
    fi
}

function ensure_file_content() {
    local -r file="$1"
    local -r content="$2"

    if [ ! -f "$file" ] || [ "$(cat "$file" 2>/dev/null)" != "$content" ]
    then
        show_message info "Please authenticate to allow the initialization of: <tt><small>$file</small></tt>"
        which pkexec >/dev/null 2>/dev/null
        check_retval 'pkexec is not installed. Please restart this script after manually installing pkexec.'
        echo "$content" | pkexec tee "$file" >/dev/null 2>/dev/null
        check_retval "Failed to write file <tt><small>$file</small></tt>."
        reboot_required=true
    fi
}

ensure_file_content /etc/udev/rules.d/60-controllerbuddy.rules 'KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"'
ensure_file_content /etc/modules-load.d/controllerbuddy.conf uinput

if [ "$reboot_required" = true ]
then
    show_message warning '<b>Important:</b> System configuration has been modified.\nPlease reboot your system!'
    exit 1
fi
EOF
)
readonly script

if ! flatpak-spawn --host /bin/bash -c "FLATPAK_ID=$FLATPAK_ID ; $script"
then
    exit "$?"
fi

CONTROLLER_BUDDY_PROFILES_DIR=/app/share/ControllerBuddy-Profiles ControllerBuddy "$@"
