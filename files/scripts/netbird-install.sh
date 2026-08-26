#!/usr/bin/env bash
set -euo pipefail

repo_source=/tmp/files/dnf/netbird.repo
repo_destination=/etc/yum.repos.d/netbird.repo
dropin_source=/tmp/files/systemd/netbird.service.d/log-directory.conf
dropin_destination=/etc/systemd/system/netbird.service.d/log-directory.conf
systemd_parent=/run/systemd
systemd_runtime=/run/systemd/system
created_systemd_parent=false
created_systemd_runtime=false

[[ ! -e "$repo_destination" ]] || {
    echo "Refusing to overwrite existing $repo_destination" >&2
    exit 1
}

cleanup() {
    rm -f -- "$repo_destination"
    if [[ "$created_systemd_runtime" == true ]]; then
        rmdir --ignore-fail-on-non-empty -- "$systemd_runtime"
    fi
    if [[ "$created_systemd_parent" == true ]]; then
        rmdir --ignore-fail-on-non-empty -- "$systemd_parent"
    fi
}
trap cleanup EXIT

install -Dm0644 -- "$repo_source" "$repo_destination"
if [[ ! -d "$systemd_parent" ]]; then
    mkdir -- "$systemd_parent"
    created_systemd_parent=true
fi
if [[ ! -d "$systemd_runtime" ]]; then
    mkdir -- "$systemd_runtime"
    created_systemd_runtime=true
fi

# Upstream's RPM runs `netbird service install/start` in %post. Make it select
# systemd while telling systemctl that this is an offline image build.
SYSTEMD_OFFLINE=1 dnf -y install \
    netbird \
    netbird-ui \
    gtk4 \
    webkitgtk6.0 \
    xdg-utils

# The generated unit writes stdout, stderr, and client logs below this path.
# Have systemd create it on every boot before setting up the service streams.
install -Dm0644 -- "$dropin_source" "$dropin_destination"
