#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
recipes_dir="$repo_root/recipes"
workflow="$repo_root/.github/workflows/build.yml"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

images=(myos-sway-main myos-sway-nvidia myos-server-main myos-server-nvidia)
recipe_files=()
for image in "${images[@]}"; do
    recipe_files+=("recipe-$image.yml")
done

mapfile -t actual_recipes < <(find "$recipes_dir" -maxdepth 1 -type f -name 'recipe-*.yml' -printf '%f\n' | sort)
mapfile -t expected_recipes < <(printf '%s\n' "${recipe_files[@]}" | sort)
[[ "${actual_recipes[*]}" == "${expected_recipes[*]}" ]] \
    || fail "recipe inventory must contain exactly the four documented images"

mapfile -t matrix_recipes < <(sed -n '/^[[:space:]]*recipe:$/,/^[[:space:]]*steps:$/p' "$workflow" \
    | sed -n 's/^[[:space:]]*- \(recipe-[^[:space:]]*\.yml\)$/\1/p' | sort)
[[ "${matrix_recipes[*]}" == "${expected_recipes[*]}" ]] \
    || fail "CI matrix must contain all four recipes exactly once"

assert_import() {
    local recipe=$1 module=$2
    [[ $(grep -Fxc "  - from-file: $module" "$recipe" || true) -eq 1 ]] \
        || fail "$(basename "$recipe") must import $module exactly once"
}

common_modules=(default-files.yml packages-common.yml docker.yml virtualization.yml tailscale.yml netbird.yml just.yml os-release.yml)
for recipe_file in "${recipe_files[@]}"; do
    recipe="$recipes_dir/$recipe_file"
    for module in "${common_modules[@]}"; do
        assert_import "$recipe" "$module"
    done
    grep -Fqx '  - type: initramfs' "$recipe" || fail "$recipe_file lacks initramfs"
    grep -Fqx '  - type: signing' "$recipe" || fail "$recipe_file lacks signing"
    assert_import "$recipe" signing-policy.yml
    awk '
        $0 == "  - type: signing" { signing=NR }
        $0 == "  - from-file: signing-policy.yml" { policy=NR }
        END { exit !(signing && policy == signing + 1) }
    ' "$recipe" || fail "$recipe_file must extend the generated policy immediately after signing"
done

sway_modules=(sway.yml multimedia.yml packages-sway.yml voxtype.yml virtualization-ui.yml netbird-ui.yml)
for image in myos-sway-main myos-sway-nvidia; do
    recipe="$recipes_dir/recipe-$image.yml"
    for module in "${sway_modules[@]}"; do
        assert_import "$recipe" "$module"
    done
done

server_remove_packages=$(awk '
    /^    remove:$/ { in_remove=1; next }
    in_remove && /^      packages:$/ { next }
    in_remove && /^[[:space:]]*#/ { next }
    in_remove && /^        - / { sub(/^        - /, ""); print; next }
    in_remove { exit }
' "$recipes_dir/packages-server.yml")
for image in myos-server-main myos-server-nvidia; do
    recipe="$recipes_dir/recipe-$image.yml"
    assert_import "$recipe" packages-server.yml
    grep -Fqx '        - sshd.service' "$recipes_dir/packages-common.yml" \
        || fail "common package module must enable sshd for every image"
    grep -Fqx '        - mosh' "$recipes_dir/packages-server.yml" \
        || fail "server package module must layer mosh"
    for browser_package in firefox firefox-langpacks; do
        grep -Fqx "$browser_package" <<< "$server_remove_packages" \
            || fail "server package module must remove inherited $browser_package"
    done
    for forbidden in "${sway_modules[@]}" sway-nvidia.yml; do
        ! grep -Fq "from-file: $forbidden" "$recipe" \
            || fail "$image must not import GUI/Sway module $forbidden"
    done
done

remount_dropin="$repo_root/files/system/usr/lib/systemd/system/systemd-remount-fs.service.d/10-skip-composefs.conf"
[[ -f "$remount_dropin" ]] \
    || fail "composefs remount guard must be in the files shared by every image"
grep -Fqx 'ConditionPathExists=!/run/ostree/.private/cfsroot-lower' "$remount_dropin" \
    || fail "remount guard must skip systemd-remount-fs only on composefs deployments"

server_target_script="$repo_root/files/scripts/server-default-target.sh"
[[ -x "$server_target_script" ]] \
    || fail "server default-target setup must be an executable image-build script"
grep -Fqx 'systemctl set-default multi-user.target' "$server_target_script" \
    || fail "server images must default to multi-user.target"
grep -Fqx '      - server-default-target.sh' "$recipes_dir/packages-server.yml" \
    || fail "server image configuration must run the default-target setup"

for image in myos-sway-main myos-server-main; do
    grep -Fqx 'base-image: ghcr.io/blue-build/base-images/fedora-base' "$recipes_dir/recipe-$image.yml" \
        || fail "$image must use fedora-base"
done
for image in myos-sway-nvidia myos-server-nvidia; do
    grep -Fqx 'base-image: ghcr.io/blue-build/base-images/fedora-base-nvidia' "$recipes_dir/recipe-$image.yml" \
        || fail "$image must use fedora-base-nvidia"
done
assert_import "$recipes_dir/recipe-myos-sway-nvidia.yml" sway-nvidia.yml
! grep -Fq 'from-file: sway-nvidia.yml' "$recipes_dir/recipe-myos-server-nvidia.yml" \
    || fail "NVIDIA server must not import the Sway NVIDIA overlay"

for recipe_file in "${recipe_files[@]}"; do
    grep -Fqx 'image-version: 44' "$recipes_dir/$recipe_file" || fail "$recipe_file must target Fedora 44"
done

for gui_package in codium darkman swappy fprintd-pam gnome-keyring-pam NetworkManager-openvpn-gnome ddcutil; do
    grep -Eq "^[[:space:]]*-[[:space:]]+${gui_package//./\\.}[[:space:]]*$" "$recipes_dir/packages-sway.yml" \
        || fail "packages-sway.yml must contain $gui_package"
    ! grep -Eq "^[[:space:]]*-[[:space:]]+${gui_package//./\\.}[[:space:]]*$" "$recipes_dir/packages-common.yml" "$recipes_dir/packages-server.yml" \
        || fail "$gui_package must not be common/server-layered"
done
for common_package in gcc make patch binutils git syncthing NetworkManager-openvpn openvpn wol; do
    grep -Eq "^[[:space:]]*-[[:space:]]+${common_package//./\\.}[[:space:]]*$" "$recipes_dir/packages-common.yml" \
        || fail "packages-common.yml must contain $common_package"
done

for gui_package in virt-manager virt-viewer; do
    grep -Eq "^[[:space:]]*-[[:space:]]+${gui_package}[[:space:]]*$" "$recipes_dir/virtualization-ui.yml" \
        || fail "virtualization-ui.yml must contain $gui_package"
    ! grep -Eq "^[[:space:]]*-[[:space:]]+${gui_package}[[:space:]]*$" "$recipes_dir/virtualization.yml" \
        || fail "$gui_package must not be in shared virtualization.yml"
done
! grep -Eq 'netbird-ui|gtk4|webkitgtk|xdg-utils' "$repo_root/files/scripts/netbird-install.sh" \
    || fail "shared NetBird installer must not install UI dependencies"

echo "PASS: four-image recipe structure and headless server boundaries"
