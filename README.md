# myos &nbsp; [![bluebuild build badge](https://github.com/tomrutsaert/myos/actions/workflows/build.yml/badge.svg)](https://github.com/tomrutsaert/myos/actions/workflows/build.yml)

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own
repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Available Images

- myos-sway-main
- myos-sway-nvidia
- myos-niri-main
- myos-niri-nvidia

## Installation

To switch an existing Fedora Atomic/bootc installation to MyOS, choose one of the images above.

When switching from official Fedora for the first time, the MyOS signing policy is not installed yet, so do the initial switch without enforcing the policy:

```bash
sudo bootc switch ghcr.io/tomrutsaert/myos-sway-main:latest
sudo systemctl reboot
```

After booting into MyOS, normal updates and later image switches should enforce the installed signing policy:

```bash
sudo bootc upgrade
sudo bootc switch --enforce-container-sigpolicy ghcr.io/tomrutsaert/myos-sway-nvidia:latest
sudo systemctl reboot
```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version
specified in the recipe, so you won't get accidentally updated to the next major version.

## ISO

you can also locally build an iso with bluebuild cli, and install this directly

```
sudo bluebuild generate-iso --iso-name myos-sway-main.iso image ghcr.io/tomrutsaert/myos-sway-main
```
more info: https://blue-build.org/how-to/generate-iso/

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You
can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/tomrutsaert/myos-sway-main:latest
```
