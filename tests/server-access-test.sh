#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
server_module="$repo_root/recipes/packages-server.yml"
firewall_script="$repo_root/files/scripts/server-firewall-setup.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ -x "$firewall_script" ]] || fail "missing executable server firewall setup script"
grep -Fqx '      - server-firewall-setup.sh' "$server_module" \
    || fail "packages-server.yml must invoke the server firewall setup script"

for recipe in recipe-myos-server-main.yml recipe-myos-server-nvidia.yml; do
    grep -Fqx '  - from-file: packages-server.yml' "$repo_root/recipes/$recipe" \
        || fail "$recipe must import packages-server.yml"
done
for recipe in recipe-myos-sway-main.yml recipe-myos-sway-nvidia.yml; do
    ! grep -Fq 'from-file: packages-server.yml' "$repo_root/recipes/$recipe" \
        || fail "$recipe must not import the server firewall configuration"
done

mkdir -p "$tmp_dir/bin"
cat > "$tmp_dir/bin/firewall-offline-cmd" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MYOS_FIREWALL_TEST_LOG"
MOCK
chmod +x "$tmp_dir/bin/firewall-offline-cmd"

log="$tmp_dir/firewall.log"
env PATH="$tmp_dir/bin:/usr/bin:/bin" MYOS_FIREWALL_TEST_LOG="$log" "$firewall_script"
[[ $(cat "$log") == '--add-service=mosh' ]] \
    || fail "server firewall setup must add only the mosh service to the default zone"

! grep -Eq -- '--(remove-service|add-port|remove-port|zone=)|systemctl|firewall-cmd' "$firewall_script" \
    || fail "server firewall setup must not alter zones, unrelated ports, or firewalld state"
grep -Fq 'default zone' "$repo_root/PACKAGES.md" \
    || fail "PACKAGES.md must document the default-zone mosh firewall policy"

echo "PASS: server mosh firewall access is configured offline and server-only"
