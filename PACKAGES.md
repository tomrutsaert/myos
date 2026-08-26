# Intended image packages

This file documents packages explicitly layered by the MyOS recipes and important packages expected from the base images. Both retained images use Fedora 44 and the same shared Sway layers; the NVIDIA image adds its hardware-specific overlay.

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

Expected from the base images:

- `procps-ng`
- `curl`
- `file`
- `which`
- `vim`
- `openssh-server`

### Per-user Homebrew CLI tools

Homebrew CLI tools are managed by the global `ujust install-brew-cli-tools` recipe rather than layered or baked into the immutable image. Lima is installed per-user through Homebrew by this ujust recipe.

Selected host-development formulae:

- `difftastic`
- `lima`
- `mise`
- `mkcert`
- `mosh`
- `ttyd`
- `ydiff`

### Voice input

Layered by `recipes/voxtype.yml`:

- `voxtype` v0.7.5 from the pinned upstream RPM
- `wtype`

Download and configure the per-user model with `ujust voxtype-setup` (or the equivalent `blujust voxtype-setup`).

### Docker

Layered by `recipes/docker.yml`:

- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`
- `podman`

### Virtualization

Layered by `recipes/virtualization.yml`:

- `virt-install`
- `libvirt-daemon-config-network`
- `libvirt-daemon-kvm`
- `libvirt-daemon-driver-qemu`
- `qemu-kvm`
- `qemu-img`
- `virtiofsd`
- `edk2-ovmf`
- `virt-manager`
- `virt-viewer`
- `guestfs-tools`
- `python3-libguestfs`

### Tailscale

Layered by `recipes/tailscale.yml`:

- `tailscale`

### NetBird

Layered by `recipes/netbird.yml` from NetBird's official RPM repository:

- `netbird`
- `netbird-ui`
- `gtk4`
- `webkitgtk6.0`
- `xdg-utils`

## Sway package groups

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

Expected from the base images:

- `wireplumber`
- `polkit`

### Multimedia codecs

Layered by `recipes/multimedia.yml`:

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

Fedora 44 uses `mesa-va-drivers-freeworld` for the current RPM Fusion Mesa restricted-codec support.

### Sway NVIDIA overlay

Layered by `recipes/sway-nvidia.yml` for `myos-sway-nvidia` only:

- `libva-nvidia-driver`
- `/usr/libexec/myos-sway-nvidia-env` with wlroots/NVIDIA session compatibility settings

NVIDIA driver and akmod packages come from `ghcr.io/blue-build/base-images/fedora-base-nvidia:44`. Secure Boot deployments may require key or MOK enrollment for NVIDIA kernel modules.

## Final images

### `myos-sway-main`

Base image: `ghcr.io/blue-build/base-images/fedora-base:44`

Included groups:

- Sway desktop
- Multimedia codecs
- Workstation tools
- Voice input
- Docker
- Virtualization
- Tailscale
- NetBird

### `myos-sway-nvidia`

Base image: `ghcr.io/blue-build/base-images/fedora-base-nvidia:44`

Included groups:

- Sway desktop
- Sway NVIDIA overlay
- Multimedia codecs
- Workstation tools
- Voice input
- Docker
- Virtualization
- Tailscale
- NetBird

NVIDIA driver support is inherited from the BlueBuild NVIDIA base image. MyOS layers only Sway-specific NVIDIA compatibility and VA-API support.
