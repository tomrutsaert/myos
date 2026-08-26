#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
netbird_recipe="$repo_root/recipes/netbird.yml"
install_script="$repo_root/files/scripts/netbird-install.sh"
repo_file="$repo_root/files/dnf/netbird.repo"
packages_doc="$repo_root/PACKAGES.md"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

active_recipes=(
    recipe-myos-sway-main.yml
    recipe-myos-sway-nvidia.yml
    recipe-myos-niri-main.yml
    recipe-myos-niri-nvidia.yml
)
inactive_recipes=(
    recipe-myos-hyprland-main.yml
    recipe-myos-hyprland-nvidia.yml
)
packages=(netbird netbird-ui gtk4 webkitgtk6.0 xdg-utils)

[[ -f "$netbird_recipe" ]] || fail "missing dedicated NetBird recipe"
[[ -x "$install_script" ]] || fail "missing executable NetBird install script"
[[ -f "$repo_file" ]] || fail "missing checked-in NetBird repository file"

for recipe in "${active_recipes[@]}"; do
    count=$(grep -Fxc '  - from-file: netbird.yml' "$repo_root/recipes/$recipe" || true)
    [[ "$count" -eq 1 ]] || fail "$recipe must include netbird.yml exactly once"
done
for recipe in "${inactive_recipes[@]}"; do
    if grep -Fq 'from-file: netbird.yml' "$repo_root/recipes/$recipe"; then
        fail "$recipe must not include netbird.yml"
    fi
done

for package in "${packages[@]}"; do
    grep -Eq "(^|[[:space:]])${package//./\\.}([[:space:]]|$)" "$install_script" \
        || fail "NetBird installer does not install $package"
    grep -Fqx -- "- \`$package\`" "$packages_doc" \
        || fail "PACKAGES.md does not document $package"
done

grep -Fqx '        - netbird.service' "$netbird_recipe" \
    || fail "NetBird recipe does not enable netbird.service"
grep -Fq 'SYSTEMD_OFFLINE=1 dnf' "$install_script" \
    || fail "NetBird install does not suppress postinstall service startup during image build"
grep -Fq '/run/systemd/system' "$install_script" \
    || fail "NetBird install does not force the postinstall script to choose systemd"

expected_repo=$(cat <<'EOF'
[NetBird]
name=NetBird
baseurl=https://pkgs.netbird.io/yum/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
repo_gpgcheck=1
EOF
)
[[ $(cat "$repo_file") == "$expected_repo" ]] || fail "NetBird repository config differs from upstream"

grep -Fqx '### NetBird' "$packages_doc" || fail "PACKAGES.md lacks the NetBird package group"
for image in myos-sway-main myos-sway-nvidia myos-niri-main myos-niri-nvidia; do
    section=$(sed -n "/^### \`$image\`$/,/^### /p" "$packages_doc")
    grep -Fqx -- '- NetBird' <<< "$section" || fail "$image membership does not include NetBird"
done
for image in myos-hyprland-main myos-hyprland-nvidia; do
    section=$(sed -n "/^### \`$image\`$/,/^### /p" "$packages_doc")
    if grep -Fqx -- '- NetBird' <<< "$section"; then
        fail "$image membership must not include NetBird"
    fi
done

echo "PASS: NetBird package, repository, service, and image membership configuration"
