#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
recipes_dir="$repo_root/recipes"
justfiles_dir="$repo_root/files/justfiles"
common_justfile="$justfiles_dir/myjust.just"
desktop_justfile="$justfiles_dir/myjust-desktop.just"
server_justfile="$justfiles_dir/myjust-server.just"
server_packages="$recipes_dir/packages-server.yml"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

recipe_body() {
    local recipe=$1 file=$2
    awk -v recipe="$recipe" '
        $0 == recipe ":" { in_recipe=1; next }
        in_recipe && /^[^[:space:]#][^:]*:/ { exit }
        in_recipe { print }
    ' "$file"
}

[[ -f "$desktop_justfile" ]] || fail "missing desktop aggregate justfile"
[[ -f "$server_justfile" ]] || fail "missing server aggregate justfile"

for image in myos-sway-main myos-sway-nvidia; do
    recipe="$recipes_dir/recipe-$image.yml"
    grep -Fqx '  - from-file: just-desktop.yml' "$recipe" \
        || fail "$image must import the desktop ujust entrypoints"
    ! grep -Fq 'from-file: just-server.yml' "$recipe" \
        || fail "$image must not import server ujust entrypoints"
done
for image in myos-server-main myos-server-nvidia; do
    recipe="$recipes_dir/recipe-$image.yml"
    grep -Fqx '  - from-file: just-server.yml' "$recipe" \
        || fail "$image must import the server ujust entrypoints"
    ! grep -Fq 'from-file: just-desktop.yml' "$recipe" \
        || fail "$image must not import desktop ujust entrypoints"
done

desktop_install=$(recipe_body install-all "$desktop_justfile")
server_install=$(recipe_body install-all "$server_justfile")
desktop_update=$(recipe_body update-all "$desktop_justfile")
server_update=$(recipe_body update-all "$server_justfile")

for step in set-locale add-user-to-groups fix-docker fix-network-priority install-brew-all \
    install-sdkman install-nvm install-claude install-codex install-opencode install-pi; do
    grep -Fwq "$step" <<< "$server_install" || fail "server install-all must include $step"
done
for step in install-flatpaks install-intellij install-datagrip install-zed; do
    grep -Fwq "$step" <<< "$desktop_install" || fail "desktop install-all must include $step"
    ! grep -Fwq "$step" <<< "$server_install" || fail "server install-all must exclude $step"
done
# install-brew-all is intentionally retained on servers and includes the font casks.
grep -Fwq 'install-brew-fonts' <<< "$(recipe_body install-brew-all "$common_justfile")" \
    || fail "server Homebrew aggregate must retain font installation"

grep -Fq '_update-all true' <<< "$desktop_update" \
    || fail "desktop update-all must enable shared Flatpak updates"
grep -Fq '_update-all false' <<< "$server_update" \
    || fail "server update-all must disable shared Flatpak updates"
! grep -Fiq 'flatpak' <<< "$server_update" \
    || fail "server update-all must not invoke Flatpak"
mapfile -t update_implementations < <(grep -hE '^_update-all [^:]+:' "$justfiles_dir"/*.just)
[[ ${#update_implementations[@]} -eq 1 ]] \
    || fail "the large update implementation must have one shared definition"

server_remove_packages=$(awk '
    /^    remove:$/ { in_remove=1; next }
    in_remove && /^      packages:$/ { next }
    in_remove && /^[[:space:]]*#/ { next }
    in_remove && /^        - / { sub(/^        - /, ""); print; next }
    in_remove { exit }
' "$server_packages")
for package in flatpak flatpak-spawn; do
    grep -Fqx "$package" <<< "$server_remove_packages" \
        || fail "server package module must explicitly remove inherited $package"
done
for unit in flatpak-system-updates.service flatpak-system-updates.timer \
    flatpak-user-updates.service flatpak-user-updates.timer; do
    grep -Fqx "        - $unit" "$server_packages" \
        || fail "server package module must mask inherited $unit"
done

# A server update routes through the false branch, where the only Flatpak command is guarded.
common_update=$(recipe_body '_update-all update_flatpaks' "$common_justfile")
grep -Fq 'if [[ "{{update_flatpaks}}" == "true" ]]' <<< "$common_update" \
    || fail "shared Flatpak update must be role-gated"
[[ $(grep -Fc 'flatpak update' <<< "$common_update") -eq 1 ]] \
    || fail "shared updater must contain exactly one role-gated Flatpak invocation"

echo "PASS: role-specific ujust routing and aggregates"
