#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
recipe="$repo_root/recipes/proton-vpn.yml"
repo_file="$repo_root/files/dnf/protonvpn-stable.repo"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ -f "$recipe" ]] || fail "missing Proton VPN recipe"
[[ -f "$repo_file" ]] || fail "missing Proton VPN repository configuration"
grep -Fqx '  - type: dnf' "$recipe" || fail "Proton VPN must use the image package manager"
grep -Fqx '        - protonvpn-stable.repo' "$recipe" || fail "recipe must load the Proton repository"
grep -Fqx '      cleanup: true' "$recipe" || fail "build repository must be cleaned up"
grep -Fqx '      install-weak-deps: false' "$recipe" || fail "CLI installation must disable weak dependencies"
grep -Fqx '        - proton-vpn-cli' "$recipe" || fail "recipe must install the official CLI"
! grep -Eq 'skip-unavailable: true|skip_if_unavailable *= *true' "$recipe" "$repo_file" \
    || fail "Proton VPN must be a required image package"

grep -Fqx 'baseurl=https://repo.protonvpn.com/fedora-$releasever-stable' "$repo_file" \
    || fail "Proton repository must follow the image Fedora release"
grep -Fqx 'enabled=1' "$repo_file" || fail "Proton repository must be enabled"
grep -Fqx 'gpgcheck=1' "$repo_file" || fail "Proton package signatures must be checked"
grep -Fqx 'gpgkey=https://repo.protonvpn.com/fedora-$releasever-stable/public_key.asc' "$repo_file" \
    || fail "Proton repository must use the official signing key"

for image in myos-sway-main myos-sway-nvidia myos-server-main myos-server-nvidia; do
    section=$(sed -n "/^### \`$image\`$/,/^### /p" "$repo_root/PACKAGES.md")
    grep -Fqx -- '- Proton VPN CLI' <<< "$section" \
        || fail "$image package inventory must include Proton VPN CLI"
done

echo "PASS: Proton VPN CLI package and signed repository configuration"
