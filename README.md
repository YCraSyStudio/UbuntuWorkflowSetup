# UbuntuWorkflowSetup

Interactive .NET installer to prepare an Ubuntu machine with development,
productivity, and GNOME extension applications.

The script lets you choose which components to install and automates updating
the system, configuring repositories, installing packages, and some post-install
cleanup tasks.

## Requirements

- Ubuntu 24.04 or later.
- An account with `sudo` privileges.
- An Internet connection.
- An interactive terminal to use the application selector.

The installer only supports Ubuntu. Before making any changes it checks the
operating system and stops the execution if the version is not compatible.

## Usage

Download the executable for your architecture from [GitHub Releases](https://github.com/YCraSyStudio/UbuntuWorkflowSetup/releases).
Choose `linux-x64` for x86-64 or `linux-arm64` for ARM64. The executable includes
the .NET runtime and the installer scripts. Bash and the Ubuntu system utilities
are used to install the selected applications.

For example, on x86-64:

```bash
chmod +x ubuntu-workflow-setup-linux-x64.bin
./ubuntu-workflow-setup-linux-x64.bin
```

### Build from source

With the .NET 10 SDK installed, clone the repository and publish for your architecture:

```bash
git clone https://github.com/YCraSyStudio/UbuntuWorkflowSetup.git
cd UbuntuWorkflowSetup
```

Publish and run the installer:

```bash
dotnet publish installer/UbuntuWorkflowSetup.csproj -c Release -r linux-x64 -o ./publish
./publish/ubuntu-workflow-setup
```

Pushing a version tag such as `v1.0.0` runs the smoke test on both architectures
and publishes the two binaries to GitHub Releases.

When it starts you will be asked for your `sudo` password and the application
selector will appear.

## Selector controls

| Key | Action |
| --- | --- |
| `↑` / `↓` | Move through the options |
| Mouse wheel | Move through the options |
| `Space` | Select or deselect an option |
| `T` | Select all |
| `N` | Deselect all |
| `Enter` | Confirm the selection and start |

All options are selected by default. Node.js and GNOME Extension Manager include
indented dependent options in the menu. When you select a dependency its parent
component is also selected.

If you run it without an interactive terminal, the installer selects every
application automatically.

## Available applications

### Development tools

- Docker
- .NET SDK
- MySQL
- PostgreSQL (server and client)
- Unity Hub
- Visual Studio Code
- DBeaver
- Bruno, for exploring and testing APIs
- Node.js
  - npm
  - Angular CLI
  - npm-check-updates
- ChatGPT
- GitHub CLI
- Atlassian CLI
- QEMU/KVM with Virtual Machine Manager, to create and manage virtual machines

### Productivity

- yEd
- Chromium
- Google Chrome
- Telegram Desktop

### Other

- GNOME Extension Manager
  - Copyous
  - Dash to Panel

## What the installer does

After confirming the selection, the script:

1. Updates the Ubuntu packages.
2. Removes some unwanted preinstalled applications.
3. Installs the required base tools.
4. Configures the external repositories of the selected applications.
5. Installs the APT packages and Snap applications.
6. Installs and configures the selected Node.js tools.
7. Installs the selected ChatGPT, yEd, and GNOME extensions.
8. Enables the Docker, MySQL, PostgreSQL services, and the libvirt socket when applicable.
9. Removes packages that are no longer needed.
10. Shows the installed versions and offers to reboot the machine.

## Important notices

The script modifies the system and uses `sudo`. Before running it, keep in mind
that:

- It updates all packages with `apt upgrade`.
- It removes Firefox, GNOME documentation, Yelp, and Vim if they are installed.
- It runs `apt autoremove --purge` at the end.
- If you select Docker, it adds the current user to the `docker` group.
- If you select QEMU/KVM, it installs the available QEMU system package
  (`qemu-system-x86` on current releases, or `qemu-kvm` on older ones) together
  with `qemu-utils`, `libvirt-daemon-system`, `libvirt-clients`, and
  `virt-manager` from Ubuntu, and adds the current user to the `libvirt` and
  `kvm` groups.
- It downloads software and repository keys from their official providers.
- The NVM installation runs a script downloaded from the Internet.
- ChatGPT installs the official ChatGPT `.deb` package for `amd64` or `arm64`,
  which configures the OpenAI repository for future updates. The preview version
  supports Ubuntu Desktop 24.04 LTS and 26.04 LTS; see the
  [official Linux documentation](https://learn.chatgpt.com/docs/linux/linux-app).

Review the code and back up your work before using it on an important machine.
The installer shows a separate confirmation before rebooting.

## Configurable versions

You can change some versions using environment variables. For example:

```bash
DOTNET_VERSION=10.0 NODE_VERSION=26 ./publish/ubuntu-workflow-setup
```

Available variables:

| Variable | Default value |
| --- | --- |
| `DOTNET_VERSION` | `10.0` |
| `NODE_VERSION` | `26` |
| `NVM_VERSION` | `v0.40.8` |
| `NPM_MAJOR_VERSION` | `12` |
| `ANGULAR_MAJOR_VERSION` | `22` |
| `NCU_MAJOR_VERSION` | `23` |
| `YED_VERSION` | `3.25.1` |

## After installation

Depending on the chosen options, you may need to:

- Log out to apply the Docker group membership and load the GNOME extensions.
- Check in Extension Manager that the extensions are enabled.
- Sign in to Visual Studio Code to sync its settings.
- Open ChatGPT from the application menu and sign in with your account.
- Install the Unity editor from Unity Hub.
- Open the PostgreSQL console with `sudo -u postgres psql` to create users and
  databases. The version available in the Ubuntu repositories is installed.
- For QEMU/KVM, log out and back in to apply the `libvirt` and `kvm` groups.
  Then open Virtual Machine Manager (`virt-manager`) and create a virtual machine
  with an Ubuntu ISO. The ISO and the virtual machine are chosen from the manager
  after the tools are installed. KVM acceleration requires hardware
  virtualization enabled in BIOS/UEFI.

## Troubleshooting

If the process is interrupted, fix the reported error and run `bash main.sh`
again. The main operations check whether certain components are already
installed or configured, so the script can be run again.

To check for syntax errors without modifying the system:

```bash
bash -n main.sh src/*.sh
```
