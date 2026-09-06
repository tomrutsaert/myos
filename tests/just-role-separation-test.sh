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

# Execute the shared updater with an isolated HOME/PATH and stubbed commands.
# Redirect the fixed Homebrew path too, so even a host installation is unreachable.
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mock_bin="$test_dir/bin"
mkdir -p "$mock_bin"
for command in bash grep sort tail; do
    ln -s "$(command -v "$command")" "$mock_bin/$command"
done
cat > "$test_dir/stub" <<'STUB'
#!/bin/bash
name=${0##*/}
[[ "$name $*" == 'brew shellenv' ]] && exit 0
printf '%s\n' "$name $*" >> "$COMMAND_LOG"
[[ "$name" != "${FAIL_TOOL:-}" ]]
STUB
chmod +x "$test_dir/stub"
for command in sudo flatpak distrobox brew pi npm claude; do
    cp "$test_dir/stub" "$mock_bin/$command"
done

assert_once() {
    [[ $(grep -Fxc "$1" "$command_log" || true) -eq 1 ]] \
        || fail "updater must run '$1' exactly once ($scenario)"
}
assert_before() {
    local first second
    assert_once "$1"
    assert_once "$2"
    first=$(grep -Fnx "$1" "$command_log" | cut -d: -f1)
    second=$(grep -Fnx "$2" "$command_log" | cut -d: -f1)
    [[ "$first" -lt "$second" ]] \
        || fail "'$1' must precede '$2' ($scenario)"
}

for scenario in desktop server pi-failure npm-failure hook-failure absent-tools; do
    home="$test_dir/$scenario"
    command_log="$home/commands"
    mkdir -p "$home/scripts" "$home/.nvm" "$home/.sdkman/bin" "$home/selected-bin"
    : > "$command_log"
    cat > "$home/.nvm/nvm.sh" <<'NVM'
nvm() {
    printf '%s\n' "nvm $*" >> "$COMMAND_LOG"
    export NVM_BIN="$HOME/selected-bin"
}
NVM
    cat > "$home/.sdkman/bin/sdkman-init.sh" <<'SDK'
sdkman_selfupdate_feature=true
sdk() {
    printf '%s\n' "sdk $*" >> "$COMMAND_LOG"
    if [[ "$*" == 'list java' ]]; then printf '25.0.1-amzn\n'; fi
}
__sdk_upgrade() { printf '%s\n' 'sdk upgrade' >> "$COMMAND_LOG"; }
__sdk_install() { printf '%s\n' "sdk install $*" >> "$COMMAND_LOG"; }
SDK
    cat > "$home/selected-bin/pi" <<'PI'
#!/bin/bash
printf '%s\n' "selected-pi $*" >> "$COMMAND_LOG"
[[ "${FAIL_TOOL:-}" != pi ]]
PI
    chmod +x "$home/selected-bin/pi"
    for hook in update upgrade update.sh upgrade.sh; do
        cat > "$home/scripts/$hook" <<'HOOK'
#!/bin/bash
name=${0##*/}
printf '%s\n' "hook $name" >> "$COMMAND_LOG"
[[ "$name" != "${FAIL_HOOK:-}" ]]
HOOK
    done
    # Cover executable hooks and the bash fallback for non-executable scripts.
    chmod +x "$home/scripts/update" "$home/scripts/upgrade.sh"
    role=true
    fail_tool=''
    fail_hook=''
    case "$scenario" in
        server) role=false ;;
        pi-failure) fail_tool=pi ;;
        npm-failure) fail_tool=npm ;;
        hook-failure) fail_hook=update ;;
        absent-tools)
            rm -rf "$home/.nvm" "$home/.sdkman" "$home/scripts"
            ;;
    esac
    run_bin="$mock_bin"
    if [[ "$scenario" == absent-tools ]]; then
        run_bin="$test_dir/minimal-bin"
        mkdir -p "$run_bin"
        for command in bash grep sort tail sudo flatpak distrobox; do
            ln -s "$mock_bin/$command" "$run_bin/$command"
        done
    fi
    printf '%s\n' "$common_update" | sed -e 's/^    //' \
        -e "s/{{update_flatpaks}}/$role/g" \
        -e "s|/home/linuxbrew/.linuxbrew/bin/brew|$run_bin/brew|g" > "$home/update.sh"
    status=0
    env -i HOME="$home" PATH="$run_bin" COMMAND_LOG="$command_log" \
        FAIL_TOOL="$fail_tool" FAIL_HOOK="$fail_hook" \
        /bin/bash "$home/update.sh" > "$home/output" 2>&1 || status=$?
    case "$scenario" in
        *-failure)
            [[ "$status" -ne 0 ]] || fail "updater must aggregate failures ($scenario)"
            case "$scenario" in
                pi-failure) failure='Pi' ;;
                npm-failure) failure='global npm packages' ;;
                hook-failure) failure="custom script: $home/scripts/update" ;;
            esac
            grep -Fqx "Failed update step: $failure" "$home/output" \
                || fail "aggregate must identify the failed step ($scenario)"
            ;;
        *) [[ "$status" -eq 0 ]] || fail "updater must succeed ($scenario): $(cat "$home/output")" ;;
    esac
    for step in 'sudo -v' 'sudo bootc upgrade' 'distrobox upgrade -a'; do
        assert_once "$step"
    done
    if [[ "$role" == true ]]; then
        assert_once 'flatpak update -y'
    else
        ! grep -q '^flatpak ' "$command_log" || fail "server updater must not invoke Flatpak"
    fi
    if [[ "$scenario" == absent-tools ]]; then
        [[ $(wc -l < "$command_log") -eq 4 ]] || fail "missing optional tools must be skipped"
        continue
    fi
    for step in 'brew update' 'brew upgrade --yes' 'sdk selfupdate' 'sdk upgrade' \
        'sdk list java' 'sdk install java 25.0.1-amzn' 'sdk default java 25.0.1-amzn' \
        'nvm use default' 'npm update -g' 'selected-pi update' 'claude update'; do
        assert_once "$step"
        assert_before "$step" 'hook update'
    done
    assert_before 'nvm use default' 'npm update -g'
    assert_before 'npm update -g' 'selected-pi update'
    for hook in update upgrade update.sh upgrade.sh; do
        assert_once "hook $hook"
    done
    [[ $(grep -Ec '^(selected-pi|pi) update$' "$command_log") -eq 1 ]] \
        || fail "Pi must be updated exactly once in the selected runtime ($scenario)"
done

echo "PASS: updater ordering, failure continuation, optional tools and role gating"
