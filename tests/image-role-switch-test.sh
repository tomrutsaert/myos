#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
justfiles_dir="$repo_root/files/justfiles"
common_justfile="$justfiles_dir/myjust.just"

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

# Both directions must live in the shared justfile. A role-specific justfile would
# strand the system: the server image could never reach the desktop entrypoint.
for recipe in switch-to-server switch-to-desktop; do
    grep -Eq "^$recipe:" "$common_justfile" \
        || fail "$recipe must be defined in the shared justfile"
    for role_justfile in "$justfiles_dir/myjust-desktop.just" "$justfiles_dir/myjust-server.just"; do
        ! grep -Eq "^$recipe:" "$role_justfile" \
            || fail "$recipe must not be role-specific in $(basename "$role_justfile")"
    done
done
grep -Eq '^_switch-role from to target:' "$common_justfile" \
    || fail "the shared switch helper must take from, to, and target parameters"

server_switch=$(recipe_body switch-to-server "$common_justfile")
desktop_switch=$(recipe_body switch-to-desktop "$common_justfile")
helper=$(recipe_body '_switch-role from to target' "$common_justfile")

grep -Fq '_switch-role sway server multi-user.target' <<< "$server_switch" \
    || fail "switch-to-server must select the server image and the multi-user default target"
grep -Fq '_switch-role server sway graphical.target' <<< "$desktop_switch" \
    || fail "switch-to-desktop must select the Sway image and the graphical default target"

grep -Fq 'bootc switch --enforce-container-sigpolicy' <<< "$helper" \
    || fail "role switching must enforce the installed container signature policy"
grep -Fq 'systemctl set-default {{target}}' <<< "$helper" \
    || fail "role switching must align the default systemd target with the new role"

# The image supplies /etc/systemd/system/display-manager.service from /usr/etc, so the
# ostree merge adds and drops it per role. Deleting it locally would persist as a local
# deletion and leave a later Sway deployment with no greeter.
! grep -Eq 'display-manager' <<< "$helper$server_switch$desktop_switch" \
    || fail "role switching must leave the image-managed display-manager alias alone"

# The sibling reference is derived from the booted image so NVIDIA hosts keep their variant.
! grep -Eq 'myos-(sway|server)-(main|nvidia)' <<< "$helper" \
    || fail "the switch helper must derive the target image instead of hardcoding a variant"
# This is the literal just template expression, not a shell expansion in the test.
# shellcheck disable=SC2016
grep -Fq '${current/myos-{{from}}-/myos-{{to}}-}' <<< "$helper" \
    || fail "the switch helper must rewrite only the role segment of the booted reference"

grep -Fq 'ujust switch-to-server' "$repo_root/README.md" \
    || fail "README.md must document the role switch entrypoints"

# Run the rendered private recipe with command shims so the test exercises the
# same shell that ujust invokes without touching the host deployment.
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mock_bin="$test_dir/bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/rpm-ostree" <<'EOF'
#!/usr/bin/env bash
printf '{"deployments":[{"booted":true,"container-image-reference":"%s"}]}\n' \
    "$RPM_OSTREE_REFERENCE"
EOF
cat > "$mock_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == get-default ]] || exit 2
printf '%s\n' "$SYSTEMD_DEFAULT_TARGET"
EOF
cat > "$mock_bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$COMMAND_LOG"
EOF
chmod +x "$mock_bin"/*

render_helper() {
    local from=$1 to=$2 target=$3 output=$4
    recipe_body '_switch-role from to target' "$common_justfile" \
        | sed 's/^    //' \
        | sed -e "s/{{from}}/$from/g" -e "s/{{to}}/$to/g" -e "s/{{target}}/$target/g" \
        > "$output"
    chmod +x "$output"
}

run_switch() {
    local script=$1 reference=$2 default_target=$3 input=${4:-y}
    : > "$test_dir/commands"
    printf '%s\n' "$input" | env \
        PATH="$mock_bin:$PATH" \
        RPM_OSTREE_REFERENCE="$reference" \
        SYSTEMD_DEFAULT_TARGET="$default_target" \
        COMMAND_LOG="$test_dir/commands" \
        "$script" > "$test_dir/output" 2> "$test_dir/error"
}

server_helper="$test_dir/switch-to-server"
desktop_helper="$test_dir/switch-to-desktop"
render_helper sway server multi-user.target "$server_helper"
render_helper server sway graphical.target "$desktop_helper"

run_switch "$server_helper" \
    'ostree-image-signed:docker://ghcr.io/tomrutsaert/myos-sway-nvidia:latest' \
    graphical.target
grep -Fqx 'bootc switch --enforce-container-sigpolicy ghcr.io/tomrutsaert/myos-server-nvidia:latest' "$test_dir/commands" \
    || fail "signed rpm-ostree references must switch to a plain sibling NVIDIA reference"
grep -Fqx 'systemctl set-default multi-user.target' "$test_dir/commands" \
    || fail "switching to server must set multi-user.target"

run_switch "$desktop_helper" \
    'ostree-unverified-registry:ghcr.io/tomrutsaert/myos-server-main:latest' \
    multi-user.target
grep -Fqx 'bootc switch --enforce-container-sigpolicy ghcr.io/tomrutsaert/myos-sway-main:latest' "$test_dir/commands" \
    || fail "unsigned rpm-ostree references must switch to a plain sibling main reference"
grep -Fqx 'systemctl set-default graphical.target' "$test_dir/commands" \
    || fail "switching to desktop must set graphical.target"

run_switch "$server_helper" \
    'ostree-image-signed:docker://ghcr.io/tomrutsaert/myos-server-nvidia' \
    graphical.target ''
! grep -Fq 'bootc switch' "$test_dir/commands" \
    || fail "an already-selected role must not stage the image again"
grep -Fqx 'systemctl set-default multi-user.target' "$test_dir/commands" \
    || fail "an already-selected untagged role must repair a stale default target"

assert_rejected() {
    local reference=$1 requirement=$2
    : > "$test_dir/commands"
    if printf 'y\n' | env \
        PATH="$mock_bin:$PATH" \
        RPM_OSTREE_REFERENCE="$reference" \
        SYSTEMD_DEFAULT_TARGET=graphical.target \
        COMMAND_LOG="$test_dir/commands" \
        "$server_helper" > "$test_dir/output" 2> "$test_dir/error"; then
        fail "$requirement"
    fi
    [[ ! -s "$test_dir/commands" ]] \
        || fail "rejecting $reference must not make privileged changes"
}

for reference in \
    'ostree-unverified-image:docker://ghcr.io/tomrutsaert/myos-sway-main:latest' \
    'ostree-unverified-image:registry:ghcr.io/tomrutsaert/myos-sway-main:latest' \
    'ostree-image-signed:registry:ghcr.io/tomrutsaert/myos-sway-main:latest'; do
    run_switch "$server_helper" "$reference" graphical.target
    grep -Fqx 'bootc switch --enforce-container-sigpolicy ghcr.io/tomrutsaert/myos-server-main:latest' "$test_dir/commands" \
        || fail "valid long-form rpm-ostree reference must switch to a plain sibling reference: $reference"
done

assert_rejected \
    'ostree-unverified-registry:ghcr.io/tomrutsaert/myos-sway-main/other:latest' \
    'unexpected repositories must be rejected'
assert_rejected \
    'ostree-unverified-image:containers-storage:ghcr.io/tomrutsaert/myos-sway-main:latest' \
    'unexpected transport prefixes must be rejected'
assert_rejected \
    'ostree-image-signed:docker://ghcr.io/tomrutsaert/myos-sway-main@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
    'a digest from the current role must not be reused for its sibling image'

echo "PASS: bidirectional image role switching"
