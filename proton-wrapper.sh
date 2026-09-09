#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wrapper_utils_sh="$script_dir/wrapper-utils.sh"

protontricks_app_id=com.github.Matoking.protontricks
readonly protontricks_app_id

configure_ps1=Configure.ps1
readonly configure_ps1

if [[ -f "$wrapper_utils_sh" ]]
then
    source "$wrapper_utils_sh"
else
    echo "Error: Required file $wrapper_utils_sh not found" >&2
    exit 1
fi

check_dep() {
    local -r target="$1"
    local -r name="${2:-$target}"

    if [[ "$target" == lib* ]]
    then
        ldconfig -p | grep -q "$target"
    else
        command -v "$target" >/dev/null 2>&1
    fi
    check_retval "Failed to locate <tt><small>$target</small></tt>\nPlease check that $name is installed."
}

bypass_steam_runtime() {
    if [ -n "$STEAM_RUNTIME" ]
    then
        "$STEAM_RUNTIME"/scripts/switch-runtime.sh --runtime='' -- "$@"
    else
        command "$@"
    fi
}

flatpak() {
    bypass_steam_runtime flatpak "$@"
}

python3() {
    bypass_steam_runtime python3 "$@"
}

resolve_config_dir_name() {
    case "$1" in
        DCS_*)
            echo DCS
            ;;
        Falcon_BMS*)
            echo Falcon_BMS
            ;;
        *)
            echo "$1"
            ;;
    esac
}

get_protontricks_verbs() {
    case "$1" in
        DCS_*)
            echo 'd3d_compiler47 vcrun2022'
            ;;
        F-22_ADF|Strike_Fighters)
            echo directplay
            ;;
        IL-2_GB)
            echo d3dcompiler_47
            ;;
    esac
}

if [ "$#" -lt 2 ]
then
    show_message error "Invalid launch arguments for $script_name\nUsage:\n<tt><small>$script_name &lt;profile.json&gt; %command%</small></tt>"
    exit 1
fi

resolve_cb_profile "$1"

shift

if [ -z "$SteamAppId" ]
then
    show_message error 'SteamAppId environment variable is not defined'
    exit 1
fi

show_progress 'Checking dependencies...'

check_dep python3 'Python 3'
check_dep libSDL2 SDL2

ensure_flatpak_app_installed "$protontricks_app_id" Protontricks

update_cb
launch_cb "$cb_profile_json"

show_progress 'Adding joystick overrides...'

reg_file=$(mktemp -p '' joysticks-XXXX.reg) &&
readonly reg_file &&
exec_on_exit "rm -f $reg_file" EXIT &&
python3 - <<'EOF' "$reg_file" &&
import ctypes
import ctypes.util
import sys

sdl2_path = ctypes.util.find_library("SDL2")
if not sdl2_path:
    raise RuntimeError("Could not find SDL2 library")

sdl = ctypes.CDLL(sdl2_path)

Uint16 = ctypes.c_uint16
Uint32 = ctypes.c_uint32
class SDL_JoystickGUID(ctypes.Structure):
    _fields_ = [("data", ctypes.c_uint8 * 16)]

sdl.SDL_Init.argtypes = [ctypes.c_uint32]
sdl.SDL_Init.restype = ctypes.c_int

sdl.SDL_Quit.argtypes = []
sdl.SDL_Quit.restype = None

sdl.SDL_NumJoysticks.argtypes = []
sdl.SDL_NumJoysticks.restype = ctypes.c_int

sdl.SDL_JoystickNameForIndex.argtypes = [ctypes.c_int]
sdl.SDL_JoystickNameForIndex.restype = ctypes.c_char_p

sdl.SDL_JoystickGetDeviceGUID.argtypes = [ctypes.c_int]
sdl.SDL_JoystickGetDeviceGUID.restype = SDL_JoystickGUID

sdl.SDL_GetJoystickGUIDInfo.argtypes = [SDL_JoystickGUID, ctypes.POINTER(Uint16), ctypes.POINTER(Uint16), ctypes.POINTER(Uint16), ctypes.POINTER(Uint16)]
sdl.SDL_GetJoystickGUIDInfo.restype = None

SDL_INIT_JOYSTICK = 0x00002000

if sdl.SDL_Init(SDL_INIT_JOYSTICK) != 0:
    print("SDL_Init failed:", sdl.SDL_GetError().decode("utf-8"))
    sys.exit(1)

# see: https://github.com/wine-mirror/wine/blob/master/dlls/hidclass.sys/device.c
device_strings = {
    (0x045E, 0x028E): "Controller (XBOX 360 For Windows)",
    (0x045E, 0x028F): "Controller (XBOX 360 For Windows)",
    (0x045E, 0x02D1): "Controller (Xbox One For Windows)",
    (0x045E, 0x02DD): "Controller (Xbox One For Windows)",
    (0x045E, 0x02E3): "Controller (Xbox One For Windows)",
    (0x045E, 0x02EA): "Controller (Xbox One For Windows)",
    (0x045E, 0x02FD): "Controller (Xbox One For Windows)",
    (0x045E, 0x0719): "Controller (XBOX 360 For Windows)",
    (0x045E, 0x0B00): "Controller (Xbox One For Windows)",
    (0x045E, 0x0B05): "Controller (Xbox One For Windows)",
    (0x045E, 0x0B12): "Controller (Xbox One For Windows)",
    (0x045E, 0x0B13): "Controller (Xbox One For Windows)",
    (0x054C, 0x05C4): "Wireless Controller",
    (0x054C, 0x09CC): "Wireless Controller",
    (0x054C, 0x0BA0): "Wireless Controller",
    (0x054C, 0x0CE6): "Wireless Controller",
    (0x054C, 0x0DF2): "Wireless Controller",
}

count = sdl.SDL_NumJoysticks()
joysticks = []

for i in range(count):
    name_ptr = sdl.SDL_JoystickNameForIndex(i)
    if not name_ptr:
        continue
    name = name_ptr.decode("utf-8")

    if name == "ControllerBuddy Joystick":
        continue

    guid = sdl.SDL_JoystickGetDeviceGUID(i)
    vendor = Uint16()
    product = Uint16()
    version = Uint16()
    crc16 = Uint16()
    sdl.SDL_GetJoystickGUIDInfo(guid, ctypes.byref(vendor), ctypes.byref(product), ctypes.byref(version), ctypes.byref(crc16))

    key = (vendor.value, product.value)
    if key in device_strings:
        name = device_strings[key]

    joysticks.append(name)

sdl.SDL_Quit()

if not joysticks:
    print("Error: No joysticks detected on this system.", file=sys.stderr)
    sys.exit(1)

def escape_reg_string(s: str) -> str:
    return s.replace('"', '""')

print("Found the following joysticks:")
for name in joysticks:
    print(f" {name}")

if len(sys.argv) > 1:
    path = sys.argv[1]
    with open(path, "w", encoding="utf-16") as f:
        f.write("\ufeffWindows Registry Editor Version 5.00\n\n")
        f.write("[HKEY_CURRENT_USER\\Software\\Wine\\DirectInput\\Joysticks]\n")
        for name in joysticks:
            safe_name = escape_reg_string(name)
            f.write(f"\"{safe_name}\"=\"disabled\"\n")
    print(f"Wrote registry file: {path}")
EOF

flatpak run --filesystem="$reg_file":ro "$protontricks_app_id" -c "wine reg import '$reg_file'" "$SteamAppId"
check_retval 'Failed to add joystick registry overrides'
rm -f "$reg_file"
pop_on_exit

cb_flatpak_dir=$(flatpak info -l "$cb_app_id")
check_retval 'Failed to retrieve Flatpak installation directory for ControllerBuddy'
readonly cb_flatpak_dir

configs_dir="$(realpath -s "$cb_flatpak_dir/../active/files/share/ControllerBuddy-Profiles")/configs"
readonly configs_dir

config_dir="$configs_dir/$(resolve_config_dir_name "$cb_profile")"
readonly config_dir

has_configure_ps1=false
if [ -f "$config_dir/$configure_ps1" ]
then
    has_configure_ps1=true
fi
readonly has_configure_ps1

read -r -a protontricks_verbs <<< "$(get_protontricks_verbs "$cb_profile")"
if [ "$has_configure_ps1" = true ]
then
    protontricks_verbs+=(powershell)
fi
readonly protontricks_verbs

if [ "${#protontricks_verbs[@]}" -gt 0 ]
then
    show_progress 'Running Protontricks...'

    flatpak run "$protontricks_app_id" "$SteamAppId" -- -q "${protontricks_verbs[@]}"
    check_retval 'Failed to install dependencies via Protontricks'
fi

if [ "$has_configure_ps1" = true ]
then
    show_progress 'Running configuration script...'

    (
        cd "$config_dir" &&
        WINEDEBUG=-all flatpak run --filesystem="$configs_dir" "$protontricks_app_id" -c "wine wineconsole pwsh $configure_ps1" "$SteamAppId"
    ) || show_message warning 'Failed to run configuration script'
fi

close_progress

"$@"
