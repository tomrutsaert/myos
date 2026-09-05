# MyOS [![Build status](https://github.com/tomrutsaert/myos/actions/workflows/build.yml/badge.svg)](https://github.com/tomrutsaert/myos/actions/workflows/build.yml)

MyOS provides four Fedora 44 bootc development images:

- myos-sway-main
- myos-sway-nvidia
- myos-server-main
- myos-server-nvidia

The Sway images are graphical workstations. The server images are headless: they contain no window manager, desktop stack, or local browser and are intended for SSH/mosh access and browser-hosted services. Choose a `-nvidia` image only on NVIDIA hardware. The NVIDIA server inherits its drivers from the NVIDIA base image but does not include the Sway NVIDIA compatibility overlay.

All images retain the shared development/build tools, Docker/Podman, libvirt/QEMU, Tailscale, NetBird, global ujust recipes, defaults, OS release metadata, initramfs generation, and signing. Mosh is layered in server images for immediate remote access, with its predefined firewalld service enabled in the default zone; the per-user Homebrew flow remains available on every image. AI coding tools are not baked into any image and remain per-user installs through the existing ujust recipes.

`ujust install-all` and `ujust update-all` are role-aware. Sway images retain the Flatpak and desktop application steps. Server images run the headless development setup and shared non-Flatpak updates without installing or invoking Flatpak; their Homebrew aggregate intentionally still installs Nerd Fonts as a user preference.

## Installation

Switch an existing Fedora Atomic or bootc system to the image appropriate for its role and hardware. The MyOS signing policy is not present during the first switch from stock Fedora, so do not enforce it on that initial switch:

```bash
sudo bootc switch ghcr.io/tomrutsaert/myos-server-main:latest
sudo systemctl reboot
```

After booting MyOS, upgrades and image switches can enforce the installed signing policy:

```bash
sudo bootc upgrade
sudo bootc switch --enforce-container-sigpolicy ghcr.io/tomrutsaert/myos-sway-nvidia:latest
sudo systemctl reboot
```

The `latest` tag tracks the newest build of Fedora 44 pinned in each recipe; it does not automatically move to a new Fedora major version.

## Switching roles

All four images carry entrypoints for moving between the desktop and server roles. Each one
derives the sibling image from the booted reference, so an NVIDIA host stays on its
variant, and each aligns the default systemd target with the new role:

```bash
ujust switch-to-server
ujust switch-to-desktop
sudo systemctl reboot
```

The default target matters because `/etc/systemd/system/default.target` is local state
that survives a switch. A server deployment left on `graphical.target` still boots and
still serves SSH, but it chases a greeter the image no longer contains. Leave
`/etc/systemd/system/display-manager.service` alone; the image supplies it, so the ostree
merge adds and removes it with the role.

## Building an ISO

Build an installer ISO locally with the [BlueBuild CLI](https://blue-build.org/how-to/generate-iso/):

```bash
sudo bluebuild generate-iso --iso-name myos-server-main.iso image ghcr.io/tomrutsaert/myos-server-main
```

Replace the image name with any of the four variants as needed.

## Verifying signatures

Images are signed with [Sigstore cosign](https://docs.sigstore.dev/cosign/). Verify an image with the public key in this repository:

```bash
cosign verify --key cosign.pub ghcr.io/tomrutsaert/myos-server-main:latest
```
