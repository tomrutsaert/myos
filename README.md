# MyOS [![Build status](https://github.com/tomrutsaert/myos/actions/workflows/build.yml/badge.svg)](https://github.com/tomrutsaert/myos/actions/workflows/build.yml)

MyOS is a pair of Fedora 44 bootc images with a shared Sway desktop and development tools:

- myos-sway-main
- myos-sway-nvidia

Use `myos-sway-main` on the AMD system. The laptop uses `myos-sway-nvidia`, which adds the NVIDIA base image and Sway compatibility overlay.

## Installation

Switch an existing Fedora Atomic or bootc system to the image appropriate for its hardware. The MyOS signing policy is not present during the first switch from stock Fedora, so do not enforce it on that initial switch:

```bash
sudo bootc switch ghcr.io/tomrutsaert/myos-sway-main:latest
sudo systemctl reboot
```

After booting MyOS, upgrades and image switches can enforce the installed signing policy:

```bash
sudo bootc upgrade
sudo bootc switch --enforce-container-sigpolicy ghcr.io/tomrutsaert/myos-sway-nvidia:latest
sudo systemctl reboot
```

The `latest` tag tracks the newest build of the Fedora version pinned in each recipe; it does not automatically move to a new Fedora major version.

## Building an ISO

Build an installer ISO locally with the [BlueBuild CLI](https://blue-build.org/how-to/generate-iso/):

```bash
sudo bluebuild generate-iso --iso-name myos-sway-main.iso image ghcr.io/tomrutsaert/myos-sway-main
```

Replace the image name when building the NVIDIA variant.

## Verifying signatures

Images are signed with [Sigstore cosign](https://docs.sigstore.dev/cosign/). Verify an image with the public key in this repository:

```bash
cosign verify --key cosign.pub ghcr.io/tomrutsaert/myos-sway-main:latest
```
