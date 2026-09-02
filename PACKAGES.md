# Intended image packages

This file documents packages explicitly layered by the Fedora 44 MyOS recipes and important packages inherited from the base images. Recipe module names make the common, Sway-only, and server-only boundaries explicit.

## Common package groups

### Development and remote access

Layered by `recipes/packages-common.yml`:

- `syncthing`
- `gcc`
- `make`
- `patch`
- `binutils`
- `git`
- `NetworkManager-openvpn`
- `openvpn`

The shared module enables `sshd.service` and the per-user `syncthing.service`. Expected base-image utilities include `procps-ng`, `curl`, `file`, `which`, `vim`, and `openssh-server`.

### Per-user Homebrew CLI tools

Homebrew CLI tools are managed by the global `ujust install-brew-cli-tools` recipe rather than layered or baked into the immutable image. Lima is installed per-user through Homebrew by this ujust recipe. Both desktop and server `ujust install-all` run `install-brew-all`; the server aggregate intentionally retains the Homebrew Nerd Font casks as a user preference.

Selected host-development formulae:

- `difftastic`
- `lima`
- `mise`
- `mkcert`
- `mosh`
- `ttyd`
- `ydiff`

The existing ujust recipes also keep Claude Code, Codex, OpenCode, and Pi as per-user installs; no AI coding tool is baked into an image.

### Docker

Layered by `recipes/docker.yml`:

- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`
- `podman`

### Virtualization core

Layered by `recipes/virtualization.yml` in all images:

- `virt-install`
- `libvirt-daemon-config-network`
- `libvirt-daemon-kvm`
- `libvirt-daemon-driver-qemu`
- `qemu-kvm`
- `qemu-img`
- `virtiofsd`
- `edk2-ovmf`
- `guestfs-tools`
- `python3-libguestfs`

### Tailscale

Layered by `recipes/tailscale.yml`:

- `tailscale`

### NetBird

Layered by `recipes/netbird.yml` from NetBird's official RPM repository:

- `netbird`

The shared module enables `netbird.service`. Its graphical client and dependencies are isolated in `recipes/netbird-ui.yml` for Sway images:

- `netbird-ui`
- `gtk4`
- `webkitgtk6.0`
- `xdg-utils`

## Sway-only package groups

### Sway applications

Layered by `recipes/packages-sway.yml`:

- `swappy`
- `codium`
- `darkman`
- `fprintd-pam`
- `gnome-keyring-pam`
- `ddcutil`
- `NetworkManager-openvpn-gnome`

### Sway desktop

Layered by `recipes/sway.yml`:

- `sway`
- `waybar`
- `mako`
- `network-manager-applet`
- `playerctl`
- `pavucontrol`
- `blueman`
- `kitty`
- `fuzzel`
- `greetd`
- `tuigreet`
- `xfce-polkit`
- `gnome-keyring`
- `dbus-tools`
- `xdg-desktop-portal-wlr`
- `xdg-desktop-portal-gtk`
- `xorg-x11-server-Xwayland`
- `swaybg`
- `swayidle`
- `swaylock`
- `grim`
- `slurp`
- `wl-clipboard`
- `wlr-randr`
- `kanshi`
- `wev`
- `brightnessctl`
- `Thunar`
- `gvfs`
- `gvfs-smb`
- `gvfs-mtp`
- `gvfs-afc`
- `gvfs-gphoto2`
- `thunar-archive-plugin`
- `xarchiver`
- `ffmpegthumbnailer`
- `tumbler`
- `distrobox`
- `pamixer`
- `android-tools`

Expected from the base images: `wireplumber` and `polkit`.

### Multimedia codecs

`recipes/multimedia.yml` layers the RPM Fusion release packages plus `ffmpeg`, GStreamer codecs, PipeWire extras, HEIF support, Mesa VA-API restricted-codec support, `libva-utils`, and `unrar`.

### Voice input

Layered by `recipes/voxtype.yml` in Sway images only:

- `voxtype` v0.7.5 from the pinned upstream RPM
- `wtype`

Download and configure the per-user model with `ujust voxtype-setup` (or `blujust voxtype-setup`).

### Graphical virtualization

Layered by `recipes/virtualization-ui.yml` in Sway images only:

- `virt-manager`
- `virt-viewer`

### Sway NVIDIA overlay

Layered by `recipes/sway-nvidia.yml` for `myos-sway-nvidia` only:

- `libva-nvidia-driver`
- `/usr/libexec/myos-sway-nvidia-env` with wlroots/NVIDIA compatibility settings

NVIDIA driver and akmod packages come from `ghcr.io/blue-build/base-images/fedora-base-nvidia:44`. The NVIDIA server uses that same base but does not import this Sway overlay.

## Server-only package group

Layered by `recipes/packages-server.yml`:

- `mosh`

The same module removes the `firefox`, `firefox-langpacks`, `flatpak`, and `flatpak-spawn` packages inherited from the Fedora base, ensuring that no local browser or Flatpak tooling remains. It also disables and masks the inherited system and per-user Flatpak update units so they cannot invoke the removed CLI. Mosh is available immediately in server images while remaining in the per-user Homebrew recipe for all images. During image composition, `server-firewall-setup.sh` uses `firewall-offline-cmd --add-service=mosh` to enable only firewalld's predefined `mosh` service in the default zone; firewalld remains enabled and no unrelated ports are opened. Server recipes include no Sway, multimedia, Voxtype, graphical virtualization, or NetBird UI module.

Server `ujust install-all` retains locale setup, user groups, Docker and network setup, Homebrew CLI tools and fonts, SDKMAN, NVM, Claude Code, Codex, OpenCode, and Pi. It excludes Flatpaks, IntelliJ IDEA, DataGrip, and Zed. Server `ujust update-all` uses the shared updater for bootc, distroboxes, custom scripts, Homebrew, SDKMAN, Pi, global npm packages, and Claude Code, but does not invoke or require Flatpak. Sway aggregates retain the existing Flatpak installation/update and desktop development application steps.

## Final images

### `myos-sway-main`

Base: `ghcr.io/blue-build/base-images/fedora-base:44`

- Common development and remote-access stack
- Docker
- Virtualization core and UI
- Tailscale
- NetBird
- NetBird UI
- Sway desktop, applications, multimedia, and voice input

### `myos-sway-nvidia`

Base: `ghcr.io/blue-build/base-images/fedora-base-nvidia:44`

- Common development and remote-access stack
- Docker
- Virtualization core and UI
- Tailscale
- NetBird
- NetBird UI
- Sway desktop, applications, multimedia, and voice input
- Sway NVIDIA compatibility overlay

### `myos-server-main`

Base: `ghcr.io/blue-build/base-images/fedora-base:44`

- Common development and remote-access stack
- Docker
- Virtualization core
- Tailscale
- NetBird
- Layered mosh
- No Flatpak tooling, graphical desktop stack, or local browser

### `myos-server-nvidia`

Base: `ghcr.io/blue-build/base-images/fedora-base-nvidia:44`

- Common development and remote-access stack
- Docker
- Virtualization core
- Tailscale
- NetBird
- Layered mosh
- No Flatpak tooling, Sway NVIDIA overlay, graphical desktop stack, or local browser
