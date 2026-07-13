#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
launcher="$repo_root/files/sway/usr/bin/myos-sway-session"
config="$repo_root/files/sway/usr/etc/sway/config"
recipe="$repo_root/recipes/sway.yml"
packages_documentation="$repo_root/PACKAGES.md"
tmp_dir=$(mktemp -d)
log_file="$tmp_dir/commands.log"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

assert_log_contains() {
    local expected="$1"

    grep -Fq -- "$expected" "$log_file" \
        || fail "missing command log entry: $expected"
}

assert_import_contract() {
    local config_path="$1" import_line required
    local -a import_lines=()

    mapfile -t import_lines < <(
        grep -E '^[[:space:]]*exec_always[[:space:]]+dbus-update-activation-environment[[:space:]]+--systemd([[:space:]]|$)' "$config_path" || true
    )
    [[ ${#import_lines[@]} -eq 1 ]] \
        || fail "expected one D-Bus/systemd import command in $config_path"
    import_line="${import_lines[0]}"

    for required in \
        WAYLAND_DISPLAY \
        DISPLAY \
        SWAYSOCK \
        XDG_CURRENT_DESKTOP=sway \
        XDG_SESSION_DESKTOP=sway \
        DESKTOP_SESSION=sway \
        XDG_SESSION_TYPE=wayland; do
        [[ " $import_line " == *" $required "* ]] \
            || fail "missing $required from $config_path activation import"
    done

    [[ " $import_line " != *" --all "* ]] \
        || fail "$config_path imports the broad activation environment"
}

mkdir -p "$tmp_dir/bin"

cat > "$tmp_dir/bin/systemctl" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
printf 'systemctl type=%s args=' "${XDG_SESSION_TYPE:-unset}" >> "$MYOS_SWAY_TEST_LOG"
printf '%q ' "$@" >> "$MYOS_SWAY_TEST_LOG"
printf '\n' >> "$MYOS_SWAY_TEST_LOG"
EOF

cat > "$tmp_dir/bin/systemd-run" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
printf 'systemd-run type=%s args=' "${XDG_SESSION_TYPE:-unset}" >> "$MYOS_SWAY_TEST_LOG"
printf '%q ' "$@" >> "$MYOS_SWAY_TEST_LOG"
printf '\n' >> "$MYOS_SWAY_TEST_LOG"
EOF

cat > "$tmp_dir/bin/dbus-update-activation-environment" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
printf 'dbus type=%s args=' "${XDG_SESSION_TYPE:-unset}" >> "$MYOS_SWAY_TEST_LOG"
printf '%q ' "$@" >> "$MYOS_SWAY_TEST_LOG"
printf '\n' >> "$MYOS_SWAY_TEST_LOG"
EOF

cat > "$tmp_dir/bin/sway" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
printf 'sway type=%s current=%s session=%s desktop=%s args=' \
    "${XDG_SESSION_TYPE:-unset}" \
    "${XDG_CURRENT_DESKTOP:-unset}" \
    "${XDG_SESSION_DESKTOP:-unset}" \
    "${DESKTOP_SESSION:-unset}" >> "$MYOS_SWAY_TEST_LOG"
printf '%q ' "$@" >> "$MYOS_SWAY_TEST_LOG"
printf '\n' >> "$MYOS_SWAY_TEST_LOG"
exit "${MYOS_SWAY_TEST_SWAY_STATUS:-0}"
EOF
chmod +x "$tmp_dir/bin/systemctl" \
    "$tmp_dir/bin/systemd-run" \
    "$tmp_dir/bin/dbus-update-activation-environment" \
    "$tmp_dir/bin/sway"

set +e
env -i \
    HOME="$tmp_dir/home" \
    PATH="$tmp_dir/bin" \
    XDG_RUNTIME_DIR="$tmp_dir/runtime" \
    XDG_SESSION_TYPE=tty \
    MYOS_SWAY_TEST_LOG="$log_file" \
    MYOS_SWAY_TEST_SWAY_STATUS=23 \
    /usr/bin/bash "$launcher" --test-sway-argument
sway_status=$?
set -e

[[ "$sway_status" -eq 23 ]] \
    || fail "launcher did not preserve Sway's exit status (got $sway_status)"
assert_log_contains 'sway type=wayland current=sway session=sway desktop=sway args=--test-sway-argument '
assert_log_contains 'systemctl type=wayland args=--user import-environment XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION XDG_SESSION_TYPE '
assert_log_contains 'dbus type=wayland args=--systemd XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION XDG_SESSION_TYPE '

assert_import_contract "$config"
grep -Eq '^[[:space:]]*-[[:space:]]+dbus-tools[[:space:]]*$' "$recipe" \
    || fail "Sway image does not install dbus-tools for dbus-update-activation-environment"
documented_package="- \`dbus-tools\`"
grep -Fqx -- "$documented_package" "$packages_documentation" \
    || fail "PACKAGES.md does not document Sway's dbus-tools dependency"

if grep -Eq 'systemctl[[:space:]]+--user[[:space:]]+(restart|try-restart|reload-or-restart)' "$config"; then
    fail "Sway config restarts user services instead of only importing the environment"
fi

echo "PASS: MyOS Sway session environment"
