#!/bin/bash

script=$(cat << 'EOF'
function check_pkexec_installed() {
    which pkexec >/dev/null 2>/dev/null
    check_retval 'pkexec is not installed. Please restart this script after manually installing pkexec.'
}

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

function add_line_if_missing() {
    if [ ! -f "$1" ] || ! grep -qxF "$2" "$1"
    then
        show_message info "Please authenticate to add missing line\n<tt><small>$2</small></tt>\nto file <tt><small>$1</small></tt>."
        check_pkexec_installed
        echo "$2" | pkexec tee -a "$1" >/dev/null 2>/dev/null
        check_retval "Failed to write file <tt><small>$1</small></tt>."
        reboot_required=true
    fi
}

cb_group=controllerbuddy
if ! getent group "$cb_group" >/dev/null
then
    show_message info "Please authenticate to create the '$cb_group' group."
    check_pkexec_installed
    pkexec groupadd -f "$cb_group"
    check_retval "Failed to create the '$cb_group' group."
    reboot_required=true
fi

if ! id -nGz "$USER" | grep -qzxF "$cb_group"
then
    show_message info "Please authenticate to add user '$USER' to the '$cb_group' group."
    check_pkexec_installed
    pkexec gpasswd -a "$USER" "$cb_group"
    check_retval "Failed to add user '$USER' to the '$cb_group' group."
    reboot_required=true
fi

add_line_if_missing '/etc/udev/rules.d/99-controllerbuddy.rules' 'KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="controllerbuddy"'
add_line_if_missing '/etc/modules-load.d/uinput.conf' 'uinput'

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
