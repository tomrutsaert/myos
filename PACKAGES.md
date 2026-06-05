# Intended image packages

This file documents the package set we expect to be present in the final images.

Packages under **Layered by recipes** are installed explicitly by BlueBuild recipe modules.
Packages under **Expected from base image** are intentionally not layered because recent builds showed them already present in the base image; keep them here so they are not forgotten if a base image changes.

## Shared package groups

### Workstation tools

Layered by `recipes/packages.yml`:

- `swappy`
- `syncthing`
- `codium`
- `darkman`
- `fprintd-pam`
- `gnome-keyring-pam`
- `gcc`
- `make`
- `patch`
- `binutils`
- `git`
- `ddcutil`
- `NetworkManager-openvpn`
- `NetworkManager-openvpn-gnome`
- `openvpn`

Expected from base image:

- `procps-ng`
- `curl`
- `file`
- `which`
- `wl-clipboard`
- `vim`
- `openssh-server`

### Docker

Layered by `recipes/docker.yml`:

- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`

### Virtualization

Layered by `recipes/virtualization.yml`:

- `virt-install`
- `libvirt-daemon-config-network`
- `libvirt-daemon-kvm`
- `libvirt-daemon-driver-qemu`
- `qemu-kvm`
- `virt-manager`
- `virt-viewer`
- `guestfs-tools`
- `python3-libguestfs`

### Tailscale

Layered by `recipes/tailscale.yml`:

- `tailscale`

### Niri desktop

Layered by `recipes/niri.yml`:

- `niri`
- `waybar`
- `mako`
- `network-manager-applet`
- `playerctl`
- `grim`
- `slurp`
- `xdg-desktop-portal-wlr`
- `xdg-desktop-portal-gnome`
- `alacritty`
- `kitty`
- `fuzzel`
- `swaylock`
- `swayidle`
- `swaybg`
- `greetd`
- `tuigreet`
- `xwayland-satellite`
- `brightnessctl`
- `xfce-polkit`
- `gnome-keyring`

Expected from base image:

- `wireplumber`
- `polkit`

## Final images

### `myos-niri-main`

Base image: `ghcr.io/blue-build/base-images/fedora-base:44`

Package groups expected in final image:

- Niri desktop
- Workstation tools
- Docker
- Virtualization
- Tailscale

### `myos-niri-nvidia`

Base image: `ghcr.io/blue-build/base-images/fedora-base-nvidia:44`

Package groups expected in final image:

- Niri desktop
- Workstation tools
- Docker
- Virtualization
- Tailscale

### `myos-sway-main`

Base image: `ghcr.io/wayblueorg/sway:43`

Package groups expected in final image:

- Workstation tools
- Docker
- Virtualization
- Tailscale

Sway itself and its desktop dependencies are inherited from the base image.

### `myos-sway-nvidia`

Base image: `ghcr.io/wayblueorg/sway-nvidia:43`

Package groups expected in final image:

- Workstation tools
- Docker
- Virtualization
- Tailscale

Sway, NVIDIA support, and their desktop dependencies are inherited from the base image.

### `myos-hyprland-main`

Base image: `ghcr.io/wayblueorg/hyprland:42`

Package groups expected in final image:

- Workstation tools
- Docker
- Virtualization

Hyprland itself and its desktop dependencies are inherited from the base image.

### `myos-hyprland-nvidia`

Base image: `ghcr.io/wayblueorg/hyprland-nvidia:42`

Package groups expected in final image:

- Workstation tools
- Docker
- Virtualization

Hyprland, NVIDIA support, and their desktop dependencies are inherited from the base image.
