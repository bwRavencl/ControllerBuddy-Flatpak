#!/bin/bash

script=$(cat << 'EOF'
function show_message() {
    flatpak run --command=zenity "$FLATPAK_ID" --window-icon /app/share/icons/hicolor/scalable/apps/"$FLATPAK_ID".svg --"$1" --text "$2" --width 450
}

function check_retval() {
    if [ "$?" -ne 0 ]
    then
        show_message error "<b>Error:</b> $1"
        exit 1
    fi
}

function ensure_file_content() {
    if [ ! -f "$1" ] || [ "$(cat "$1" 2>/dev/null)" != "$2" ]
    then
        show_message info "Please authenticate to allow the initialization of: <tt><small>$1</small></tt>"
        which pkexec >/dev/null 2>/dev/null
        check_retval 'pkexec is not installed. Please restart this script after manually installing pkexec.'
        echo "$2" | pkexec tee "$1" >/dev/null 2>/dev/null
        check_retval "Failed to write file <tt><small>$1</small></tt>."
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

if ! flatpak-spawn --host /bin/bash -c "FLATPAK_ID=$FLATPAK_ID ; $script"
then
    exit "$?"
fi

CONTROLLER_BUDDY_PROFILES_DIR=/app/share/ControllerBuddy-Profiles ControllerBuddy "$@"
