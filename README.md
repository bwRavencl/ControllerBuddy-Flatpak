<!-- markdownlint-disable-file line-length -->
# ControllerBuddy-Flatpak

## 📖 Description

This repository represents the official Flatpak package of [ControllerBuddy](https://controllerbuddy.org), the highly advanced game controller mapping application.

In addition to the application itself, the package includes a copy of the official [ControllerBuddy-Profiles](https://github.com/bwRavencl/ControllerBuddy-Profiles) located under `/app/share/ControllerBuddy-Profiles`.

## ⬇️ Installation

To install the ControllerBuddy Flatpak package, follow these steps:

1. Add the repositiory with the following command:

    ```sh
    flatpak remote-add --if-not-exists ControllerBuddy https://flatpak.controllerbuddy.org/index.flatpakrepo
    ```

2. Install the application by running:

    ```sh
    flatpak install de.bwravencl.ControllerBuddy
    ```

## ⚖️ License

[CC0 1.0 Universal](LICENSE)
