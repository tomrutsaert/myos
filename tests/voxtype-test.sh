#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
setup_script="$repo_root/files/system/usr/libexec/myos-voxtype-setup"
justfile="$repo_root/files/justfiles/myjust.just"
voxtype_recipe="$repo_root/recipes/voxtype.yml"
readme="$repo_root/README.md"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_exact_bindings() {
    local output=$1 actual expected
    actual=$(grep '^bindsym ' "$output" || true)
    expected=$(cat <<'EOF'
bindsym --no-repeat $mod+v exec voxtype record start
bindsym --release $mod+v exec voxtype record stop
EOF
)
    [[ "$actual" == "$expected" ]] \
        || fail "output does not contain exactly the two recommended bindings: $output"
}

sway_recipes=(
    recipe-myos-sway-main.yml
    recipe-myos-sway-nvidia.yml
)
all_recipes=(
    "${sway_recipes[@]}"
    recipe-myos-server-main.yml
    recipe-myos-server-nvidia.yml
)

[[ -f "$voxtype_recipe" ]] || fail "missing dedicated voxtype recipe"
grep -Fqx '        - https://github.com/peteonrails/voxtype/releases/download/v0.7.5/voxtype-0.7.5-1.x86_64.rpm' "$voxtype_recipe" \
    || fail "voxtype recipe does not pin the v0.7.5 RPM URL"
grep -Fqx '        - wtype' "$voxtype_recipe" || fail "voxtype recipe does not install wtype"
for recipe in "${sway_recipes[@]}"; do
    count=$(grep -Fxc '  - from-file: voxtype.yml' "$repo_root/recipes/$recipe" || true)
    [[ "$count" -eq 1 ]] || fail "$recipe must include voxtype.yml exactly once"
done
for recipe in recipe-myos-server-main.yml recipe-myos-server-nvidia.yml; do
    ! grep -Fq 'from-file: voxtype.yml' "$repo_root/recipes/$recipe" \
        || fail "$recipe must not include the Sway-only Voxtype module"
done

mapfile -t matrix_recipes < <(sed -n '/^[[:space:]]*recipe:$/,/^[[:space:]]*steps:$/p' \
    "$repo_root/.github/workflows/build.yml" \
    | sed -n 's/^[[:space:]]*- \(recipe-[^[:space:]]*\.yml\)$/\1/p')
[[ "${matrix_recipes[*]}" == "${all_recipes[*]}" ]] \
    || fail "CI build matrix must contain only: ${all_recipes[*]}"

for recipe in "${all_recipes[@]}"; do
    image=${recipe#recipe-}
    image=${image%.yml}
    grep -Fqx -- "- $image" "$readme" || fail "README does not list $image"
done

grep -Eq '^voxtype-setup:' "$justfile" || fail "installed global justfile lacks voxtype-setup"
grep -Fq '/usr/libexec/myos-voxtype-setup' "$justfile" || fail "voxtype-setup does not invoke the setup helper"
grep -Fq 'ujust voxtype-setup' "$repo_root/PACKAGES.md" || fail "documentation does not use the installed ujust entrypoint"
[[ -x "$setup_script" ]] || fail "voxtype setup helper is missing or not executable"

mkdir -p "$tmp_dir/bin"
cat > "$tmp_dir/bin/voxtype" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${VOXTYPE_TEST_EXPECTED_CONFIG:-}" ]]; then
    cmp -s "$VOXTYPE_TEST_EXPECTED_CONFIG" "$XDG_CONFIG_HOME/voxtype/config.toml"
fi
printf 'voxtype %s\n' "$*" >> "$VOXTYPE_TEST_LOG"
MOCK
cat > "$tmp_dir/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >> "$VOXTYPE_TEST_LOG"
if [[ "$*" == '--user list-unit-files voxtype.service --no-legend' && "${VOXTYPE_TEST_HAS_SERVICE:-0}" == 1 ]]; then
    printf 'voxtype.service enabled\n'
elif [[ "$*" == '--user enable --now voxtype.service' ]]; then
    exit "${VOXTYPE_TEST_ENABLE_STATUS:-0}"
fi
MOCK
chmod +x "$tmp_dir/bin/voxtype" "$tmp_dir/bin/systemctl"

missing_home="$tmp_dir/home-missing-voxtype"
missing_config="$tmp_dir/config-missing-voxtype"
mkdir -p "$missing_home" "$tmp_dir/empty-bin"
set +e
env -i HOME="$missing_home" XDG_CONFIG_HOME="$missing_config" PATH="$tmp_dir/empty-bin" \
    /usr/bin/bash "$setup_script" > "$tmp_dir/missing-voxtype.out" 2>&1
missing_status=$?
set -e
[[ "$missing_status" -ne 0 ]] || fail "setup succeeds when Voxtype is absent"
grep -Fq 'Voxtype is only available in MyOS Sway images' "$tmp_dir/missing-voxtype.out" \
    || fail "missing-Voxtype failure does not explain the Sway-only boundary"
[[ ! -e "$missing_config" ]] || fail "missing-Voxtype failure leaves config state"

run_setup() {
    local home=$1 config_home=$2 has_service=$3 output=$4 log=$5 enable_status=${6:-0}
    local expected_config=${7:-}
    env -i HOME="$home" XDG_CONFIG_HOME="$config_home" PATH="$tmp_dir/bin:/usr/bin:/bin" \
        VOXTYPE_TEST_HAS_SERVICE="$has_service" VOXTYPE_TEST_ENABLE_STATUS="$enable_status" \
        VOXTYPE_TEST_EXPECTED_CONFIG="$expected_config" VOXTYPE_TEST_LOG="$log" \
        "$setup_script" > "$output" 2>&1
}

legacy_config="$tmp_dir/legacy-config"
printf '[hotkey]\nenabled = false\n' > "$legacy_config"
expected_config="$tmp_dir/expected-config"
cat > "$expected_config" <<'EOF'
[hotkey]
enabled = false

[audio]
device = "default"
sample_rate = 16000
max_duration_secs = 60

[output]
mode = "type"
EOF

home_new="$tmp_dir/home-new"
mkdir -p "$home_new/.config/sway"
printf 'user sway config\n' > "$home_new/.config/sway/config"
log_new="$tmp_dir/new.log"
run_setup "$home_new" "$home_new/.config" 1 "$tmp_dir/new.out" "$log_new" 0 "$expected_config"
cmp -s "$expected_config" "$home_new/.config/voxtype/config.toml" \
    || fail "new config is not a complete v0.7.5-valid minimal config"
grep -Fqx 'voxtype setup --download' "$log_new" || fail "setup does not download the default Whisper model"
grep -Fqx 'systemctl --user enable --now voxtype.service' "$log_new" \
    || fail "setup does not enable the present user service"
assert_exact_bindings "$tmp_dir/new.out"
grep -Fqx 'user sway config' "$home_new/.config/sway/config" || fail "setup modified Sway config"

cp "$home_new/.config/voxtype/config.toml" "$tmp_dir/first-run-config"
run_setup "$home_new" "$home_new/.config" 1 "$tmp_dir/rerun.out" "$tmp_dir/rerun.log"
cmp -s "$tmp_dir/first-run-config" "$home_new/.config/voxtype/config.toml" \
    || fail "rerunning setup changed its generated config"
grep -Fqx 'user sway config' "$home_new/.config/sway/config" || fail "rerunning setup modified Sway config"
assert_exact_bindings "$tmp_dir/rerun.out"

home_legacy="$tmp_dir/home-legacy"
legacy_config_dir="$home_legacy/.config/voxtype"
legacy_config_file="$legacy_config_dir/config.toml"
mkdir -p "$legacy_config_dir"
cp "$legacy_config" "$legacy_config_file"
chmod 0640 "$legacy_config_file"
run_setup "$home_legacy" "$home_legacy/.config" 0 \
    "$tmp_dir/legacy.out" "$tmp_dir/legacy.log" 0 "$expected_config"
cmp -s "$expected_config" "$legacy_config_file" \
    || fail "setup did not migrate the exact legacy MyOS config"
[[ $(stat -c '%a' "$legacy_config_file") == 640 ]] \
    || fail "legacy config migration did not preserve its file mode"
[[ -z $(find "$legacy_config_dir" -maxdepth 1 -name '.config.toml.*' -print -quit) ]] \
    || fail "legacy config migration left a temporary file"
grep -Fqx 'voxtype setup --download' "$tmp_dir/legacy.log" \
    || fail "model setup did not proceed after legacy config migration"
assert_exact_bindings "$tmp_dir/legacy.out"

cp "$legacy_config_file" "$tmp_dir/migrated-config"
run_setup "$home_legacy" "$home_legacy/.config" 0 \
    "$tmp_dir/legacy-rerun.out" "$tmp_dir/legacy-rerun.log" 0 "$expected_config"
cmp -s "$tmp_dir/migrated-config" "$legacy_config_file" \
    || fail "rerunning setup changed the migrated config"
assert_exact_bindings "$tmp_dir/legacy-rerun.out"

home_near_match="$tmp_dir/home-near-match"
mkdir -p "$home_near_match/.config/voxtype"
printf '[hotkey]\nenabled = false\n# custom\n' > "$home_near_match/.config/voxtype/config.toml"
cp "$home_near_match/.config/voxtype/config.toml" "$tmp_dir/near-match-config"
run_setup "$home_near_match" "$home_near_match/.config" 0 \
    "$tmp_dir/near-match.out" "$tmp_dir/near-match.log"
cmp -s "$tmp_dir/near-match-config" "$home_near_match/.config/voxtype/config.toml" \
    || fail "setup changed a near-match custom config"
assert_exact_bindings "$tmp_dir/near-match.out"

home_existing="$tmp_dir/home-existing"
mkdir -p "$home_existing/.config/voxtype"
printf '# preserve me\n[hotkey]\nenabled = true\n' > "$home_existing/.config/voxtype/config.toml"
cp "$home_existing/.config/voxtype/config.toml" "$tmp_dir/original-config"
log_existing="$tmp_dir/existing.log"
run_setup "$home_existing" "$home_existing/.config" 0 "$tmp_dir/existing.out" "$log_existing"
cmp -s "$tmp_dir/original-config" "$home_existing/.config/voxtype/config.toml" \
    || fail "setup clobbered an existing config"
if grep -Fq 'enable --now voxtype.service' "$log_existing"; then
    fail "setup tried to enable an absent user service"
fi
assert_exact_bindings "$tmp_dir/existing.out"

home_xdg="$tmp_dir/home-xdg"
custom_config="$tmp_dir/custom-config"
run_setup "$home_xdg" "$custom_config" 0 "$tmp_dir/xdg.out" "$tmp_dir/xdg.log"
cmp -s "$expected_config" "$custom_config/voxtype/config.toml" \
    || fail "setup did not honor XDG_CONFIG_HOME"
[[ ! -e "$home_xdg/.config/voxtype/config.toml" ]] || fail "setup leaked into HOME instead of XDG_CONFIG_HOME"
assert_exact_bindings "$tmp_dir/xdg.out"

home_dir_link="$tmp_dir/home-dir-link"
external_dir="$tmp_dir/external-dir"
mkdir -p "$home_dir_link/.config" "$external_dir"
ln -s "$external_dir" "$home_dir_link/.config/voxtype"
: > "$tmp_dir/dir-link.log"
if run_setup "$home_dir_link" "$home_dir_link/.config" 0 "$tmp_dir/dir-link.out" "$tmp_dir/dir-link.log"; then
    fail "setup accepted a symlinked config directory"
fi
[[ ! -e "$external_dir/config.toml" ]] || fail "setup wrote through a symlinked config directory"
[[ ! -s "$tmp_dir/dir-link.log" ]] || fail "setup ran voxtype after refusing a symlinked config directory"

home_file_link="$tmp_dir/home-file-link"
external_file="$tmp_dir/external-file/config.toml"
mkdir -p "$home_file_link/.config/voxtype" "$(dirname -- "$external_file")"
ln -s "$external_file" "$home_file_link/.config/voxtype/config.toml"
: > "$tmp_dir/file-link.log"
if run_setup "$home_file_link" "$home_file_link/.config" 0 "$tmp_dir/file-link.out" "$tmp_dir/file-link.log"; then
    fail "setup accepted a broken config-file symlink"
fi
[[ ! -e "$external_file" ]] || fail "setup wrote through a broken config-file symlink"
[[ ! -s "$tmp_dir/file-link.log" ]] || fail "setup ran voxtype after refusing a config-file symlink"

home_enable_fail="$tmp_dir/home-enable-fail"
set +e
run_setup "$home_enable_fail" "$home_enable_fail/.config" 1 \
    "$tmp_dir/enable-fail.out" "$tmp_dir/enable-fail.log" 23
enable_status=$?
set -e
[[ "$enable_status" -eq 23 ]] || fail "setup did not preserve service enable failure status"
assert_exact_bindings "$tmp_dir/enable-fail.out"
grep -Fqx 'systemctl --user enable --now voxtype.service' "$tmp_dir/enable-fail.log" \
    || fail "service failure test did not attempt enablement"

for forbidden in rpm-ostree ydotool dotool evdev Vulkan ONNX '~'"/.local/bin" usermod groupadd; do
    if grep -Fq -- "$forbidden" "$setup_script" "$voxtype_recipe"; then
        fail "forbidden setup/install mechanism found: $forbidden"
    fi
done

echo "PASS: Voxtype recipe and setup behavior"
