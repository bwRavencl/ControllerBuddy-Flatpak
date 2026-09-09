<!-- markdownlint-disable-file line-length -->
# ControllerBuddy-Flatpak

## 📖 Description

This repository provides the official Flatpak package for [ControllerBuddy](https://controllerbuddy.org), the highly advanced game controller mapping application.

In addition to the application itself, the package includes:

- Official [ControllerBuddy-Profiles](https://github.com/bwRavencl/ControllerBuddy-Profiles) located at `/app/share/ControllerBuddy-Profiles`
- Two helper scripts (`proton-wrapper.sh` and `dosbox-wrapper.sh`) to simplify integration with [Proton](https://github.com/ValveSoftware/Proton) and [DOSBox Staging](https://www.dosbox-staging.org)

## ⬇️ Installation

To install the ControllerBuddy Flatpak package, follow these steps:

1. Add the repository with the following command:

    ```sh
    flatpak remote-add --if-not-exists ControllerBuddy https://flatpak.controllerbuddy.org/index.flatpakrepo
    ```

2. Install the application by running:

    ```sh
    flatpak install -y ControllerBuddy de.bwravencl.ControllerBuddy
    ```

## 📜 Wrapper Scripts

The package includes two scripts (`proton-wrapper.sh` and `dosbox-wrapper.sh`) located under `/app/share/`. These enable seamless integration between ControllerBuddy, Steam/Proton games, and DOSBox Staging.
Using these scripts is optional.

> [!IMPORTANT]
> Although these scripts are delivered via Flatpak, they are intended to run inside the Steam Linux Runtime (Proton) or directly on the host system (DOSBox), rather than within the ControllerBuddy Flatpak container itself.

### ⚛️ Proton Wrapper

The `proton-wrapper.sh` script automates the following steps:

- Ensures the [Protontricks](https://github.com/matoking/protontricks) Flatpak is installed
- Disables native joysticks in the game's Proton prefix
- Updates the ControllerBuddy Flatpak
- Launches ControllerBuddy with the specified profile
- Ensures [PowerShell](https://github.com/powershell/powershell) is installed in the game's Proton prefix
- Runs the profile's configuration script within the game's Proton prefix
- Launches the game
- Shuts down ControllerBuddy when the game exits

To use it, add the following to the game's **Launch Options** in Steam (replace `<profile.js>` with the ControllerBuddy profile filename):

```sh
"$("$STEAM_RUNTIME"/scripts/switch-runtime.sh --runtime='' -- flatpak info -l de.bwravencl.ControllerBuddy)/files/share/proton-wrapper.sh" <profile.js> %command%
```

### 📺 DOSBox Wrapper

The `dosbox-wrapper.sh` script automates the following steps:

- Updates the ControllerBuddy Flatpak
- Launches ControllerBuddy with the specified profile
- Forces DOSBox to use the ControllerBuddy virtual joystick
- Overrides mouse sensitivity in DOSBox if `mouse_sensitivity` is provided
- Launches DOSBox
- Shuts down ControllerBuddy when DOSBox exits

Call the script as follows:

```sh
"$(flatpak info -l de.bwravencl.ControllerBuddy)/files/share/dosbox-wrapper.sh" <profile.js> <dosbox.conf> [mouse_sensitivity]
```

| Argument            | Description                                                      |
|---------------------|------------------------------------------------------------------|
| `profile.js`        | Filename of ControllerBuddy profile                              |
| `dosbox.conf`       | Path of DOSBox configuration file                                |
| `mouse_sensitivity` | Optional floating-point value setting the scale for mouse motion |

## ⚖️ License

[CC0 1.0 Universal](LICENSE)
