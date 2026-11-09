# DVMProject software on Raspberry Pi 5

This folder provides a cautious installer and updater for the official [DVMProject dvmhost repository](https://github.com/DVMProject/dvmhost). It is for a Raspberry Pi 5 running Raspberry Pi OS or Debian (including Debian 13/Trixie), either 64-bit or 32-bit.

`dvmhost` and [dvmconsole](https://github.com/DVMProject/dvmconsole) are separate applications. The scripts install **dvmhost only**. The official dvmconsole source identifies it as a Windows WPF desktop application built with Visual Studio and .NET, and instructs users to select x86 (with separate x64 vocoder builds supported). It does not provide a Raspberry Pi OS/Linux build or installation method. For that reason, this folder deliberately does not claim to install dvmconsole on a Pi 5. Run dvmconsole on a supported Windows computer and point it at your configured DVM FNE as documented upstream.

It builds the official `master` branch natively and installs the project in the upstream-supported `/opt/dvm` location. It does **not** install modem firmware, change GPIO/serial/Bluetooth settings, open firewall ports, create a systemd service, or start the radio software. Those actions depend on your modem board and radio/network configuration.

## Before you begin

- Use a Raspberry Pi 5 with Raspberry Pi OS or Debian and internet access.
- Copy this whole folder to the Pi. Do not copy only one script: the two scripts use `libdvm.sh`.
- Do not run the scripts as a download pipe. Read them first, then run them from the copied folder.
- The install needs an account that can use `sudo`.

The scripts verify the Raspberry Pi 5 model, CPU architecture, and either Raspberry Pi OS or Debian before changing anything. They only install the documented build requirements: `build-essential`, `cmake`, `git`, `libasio-dev`, `libncurses-dev`, and `libssl-dev`.

## Install

In a terminal on the Pi, go to the copied folder and run:

```bash
chmod +x install-dvmhost.sh update-dvmhost.sh enable-dvmhost-service.sh
./install-dvmhost.sh
```

The installer clones the official source into `~/dvmproject/dvmhost`, writes logs under `~/dvmproject/logs`, builds it, and installs the binaries and upstream examples into `/opt/dvm`.

On the first install it creates `/opt/dvm/config.yml` from the official example. Open and configure that file before starting the host:

```bash
sudo nano /opt/dvm/config.yml
sudo /opt/dvm/bin/dvmhost -c /opt/dvm/config.yml
```

The sample configuration is not a ready-to-use radio configuration. Supply your own callsign, IDs, network endpoints, modem settings, and access controls.

## Update

Stop `dvmhost` first if you started it manually or via your own service. Then, from the same copied folder, run:

```bash
./update-dvmhost.sh
```

The updater refuses to proceed if `dvmhost` is running or if the local source checkout has uncommitted changes. It fast-forwards only from the official `DVMProject/dvmhost` `master` branch, rebuilds it, and preserves `/opt/dvm/config.yml`. Before it installs new binaries, it saves a timestamped copy of that configuration under `/opt/dvm/backups/`.

After an update, compare `/opt/dvm/config.example.yml` with your `config.yml` and read the upstream release notes before starting the host again. DVMProject provides `tools/config_annotator.py` for its `dvmhost` configuration; back up configuration first (the updater already does).

## Raspberry Pi modem hardware note

For an STM32 modem attached through the Pi GPIO serial port, DVMProject documents separate changes to Bluetooth, the serial getty, device-tree overlays, and the kernel command line. Those settings can disable Bluetooth or serial console access, and their paths vary by Raspberry Pi OS release. They are deliberately **not** made by these scripts. Follow the official [dvmhost Raspberry Pi preparation notes](https://github.com/DVMProject/dvmhost#raspberry-pi-preparation-notes) only when they apply to your exact modem.

## Start automatically at boot

After you have reviewed `/opt/dvm/config.yml`, configured `/opt/dvm/iden_table.dat` for your authorized RF plan, and connected the modem, run:

```bash
./enable-dvmhost-service.sh
```

This idempotent helper creates the restricted `dvmhost` service account, grants it serial-device access, sets the unchanged upstream-relative log and identity-table paths to `/opt/dvm`, and enables a systemd service for future boots. It backs up an existing service unit or configuration before changing either. It does not start dvmhost immediately, so a missing modem cannot make the setup appear to fail.

The service retries every 10 seconds if the modem is unavailable during boot. To start or check it after connecting the modem:

```bash
sudo systemctl start dvmhost.service
sudo systemctl status dvmhost.service --no-pager
```

## dvmconsole

The official [dvmconsole README](https://github.com/DVMProject/dvmconsole#building) specifies a Visual Studio solution, .NET, its `dvmvocoder` dependency, and a Windows-oriented x86/x64 build process. It also says dvmconsole connects to a DVM FNE and does not interface directly with base/mobile radios. Because no official Raspberry Pi OS path is published, there is no safe or supported Raspberry Pi installer/update script to generate for it.

## Sources and scope

- [Official DVMProject site](https://dvmproject.io/)
- [Official dvmhost README and build instructions](https://github.com/DVMProject/dvmhost#building)
- [Official dvmconsole README and build instructions](https://github.com/DVMProject/dvmconsole#building)
- [Official dvmhost releases](https://github.com/DVMProject/dvmhost/releases)

The scripts intentionally do not use `apt upgrade`, `dist-upgrade`, forced Git resets, recursive deletion, firmware flashing, or scheduled automatic updates.
