#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
netbird_recipe="$repo_root/recipes/netbird.yml"
install_script="$repo_root/files/scripts/netbird-install.sh"
repo_file="$repo_root/files/dnf/netbird.repo"
tmpfiles_config="$repo_root/files/tmpfiles.d/myos-netbird.conf"
obsolete_service_dropin="$repo_root/files/systemd/netbird.service.d/log-directory.conf"
packages_doc="$repo_root/PACKAGES.md"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

active_recipes=(
    recipe-myos-sway-main.yml
    recipe-myos-sway-nvidia.yml
)
packages=(netbird netbird-ui gtk4 webkitgtk6.0 xdg-utils)

[[ -f "$netbird_recipe" ]] || fail "missing dedicated NetBird recipe"
[[ -x "$install_script" ]] || fail "missing executable NetBird install script"
[[ -f "$repo_file" ]] || fail "missing checked-in NetBird repository file"
[[ -f "$tmpfiles_config" ]] || fail "missing NetBird tmpfiles configuration"
[[ ! -e "$obsolete_service_dropin" ]] \
    || fail "NetBird must not rely on LogsDirectory to create its stdout parent"

mapfile -t image_recipes < <(find "$repo_root/recipes" -maxdepth 1 -type f -name 'recipe-*.yml' -printf '%f\n' | sort)
[[ "${image_recipes[*]}" == "${active_recipes[*]}" ]] \
    || fail "image recipe inventory must contain only: ${active_recipes[*]}"

for recipe in "${active_recipes[@]}"; do
    count=$(grep -Fxc '  - from-file: netbird.yml' "$repo_root/recipes/$recipe" || true)
    [[ "$count" -eq 1 ]] || fail "$recipe must include netbird.yml exactly once"
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
grep -Fq 'tmpfiles_source=/tmp/files/tmpfiles.d/myos-netbird.conf' "$install_script" \
    || fail "NetBird installer does not reference the tmpfiles configuration"
grep -Fq 'tmpfiles_destination=/usr/lib/tmpfiles.d/myos-netbird.conf' "$install_script" \
    || fail "NetBird installer does not target the vendor tmpfiles directory"
grep -Fq "install -Dm0644 -- \"\$tmpfiles_source\" \"\$tmpfiles_destination\"" "$install_script" \
    || fail "NetBird installer does not install the tmpfiles configuration"

expected_tmpfiles='d /var/log/netbird 0755 root root -'
[[ $(cat "$tmpfiles_config") == "$expected_tmpfiles" ]] \
    || fail "NetBird tmpfiles configuration does not provision its log directory"

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
for image in myos-sway-main myos-sway-nvidia; do
    section=$(sed -n "/^### \`$image\`$/,/^### /p" "$packages_doc")
    grep -Fqx -- '- NetBird' <<< "$section" || fail "$image membership does not include NetBird"
done

echo "PASS: NetBird package, repository, service, and image membership configuration"
