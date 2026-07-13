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
- `xdg-desktop-portal-gtk`
- `alacritty`
- `kitty`
- `Thunar`
- `gvfs`
- `gvfs-mtp`
- `gvfs-smb`
- `gvfs-afc`
- `gvfs-gphoto2`
- `ffmpegthumbnailer`
- `tumbler`
- `fuzzel`
- `swaylock`
- `swayidle`
- `swaybg`
- `greetd`
- `tuigreet`
- `dbus-tools`
- `xwayland-satellite`
- `brightnessctl`
- `xfce-polkit`
- `gnome-keyring`

Expected from base image:

- `wireplumber`
- `polkit`
- `wl-clipboard`

### Sway desktop

Layered by `recipes/sway.yml`:

- `sway`
- `waybar`
- `mako`
- `network-manager-applet`
- `playerctl`
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

Expected from base image:

- `wireplumber`
- `polkit`

### Multimedia codecs

Layered by `recipes/multimedia.yml` for Sway images:

- RPM Fusion free release RPM for Fedora 44
- RPM Fusion nonfree release RPM for Fedora 44
- `ffmpeg`
- `gstreamer1-plugins-bad-freeworld`
- `gstreamer1-plugins-ugly`
- `gstreamer1-plugin-libav`
- `pipewire-libs-extra`
- `libheif-freeworld`
- `heif-pixbuf-loader` (virtual pixbuf-loader capability/provider accepted by BlueBuild)
- `libheif-tools`
- `mesa-va-drivers-freeworld`
- `libva-utils`
- `unrar`

Current Fedora 44/RPM Fusion Mesa restricted-codec support is provided by `mesa-va-drivers-freeworld`; `mesa-vdpau-drivers-freeworld` is not available as a separate package.

### Sway NVIDIA overlay

Layered by `recipes/sway-nvidia.yml` for `myos-sway-nvidia` only:

- `libva-nvidia-driver`
- `/usr/libexec/myos-sway-nvidia-env` with wlroots/NVIDIA session compatibility settings

NVIDIA driver and akmod packages are expected from `ghcr.io/blue-build/base-images/fedora-base-nvidia:44`, not layered by MyOS. Secure Boot deployments may still require key/MOK enrollment for NVIDIA kernel modules.

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

Base image: `ghcr.io/blue-build/base-images/fedora-base:44`

Package groups expected in final image:

- Sway desktop
- Multimedia codecs
- Workstation tools
- Docker
- Virtualization
- Tailscale

### `myos-sway-nvidia`

Base image: `ghcr.io/blue-build/base-images/fedora-base-nvidia:44`

Package groups expected in final image:

- Sway desktop
- Sway NVIDIA overlay
- Multimedia codecs
- Workstation tools
- Docker
- Virtualization
- Tailscale

NVIDIA driver support is inherited from the BlueBuild NVIDIA base image. MyOS layers only Sway-specific NVIDIA compatibility and VA-API support.

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
