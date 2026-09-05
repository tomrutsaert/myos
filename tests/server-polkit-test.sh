#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
rule="$repo_root/files/server/usr/share/polkit-1/rules.d/60-myos-server-inhibit.rules"
server_module="$repo_root/recipes/packages-server.yml"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ -f "$rule" ]] || fail "server sleep-inhibitor polkit rule is missing"
command -v node >/dev/null 2>&1 \
    || fail "node is required to execute the polkit rule test"
grep -Fqx '      - source: server' "$server_module" \
    || fail "server files must be copied by the server-only recipe module"

for image in myos-server-main myos-server-nvidia; do
    grep -Fqx '  - from-file: packages-server.yml' "$repo_root/recipes/recipe-$image.yml" \
        || fail "$image must include the server polkit rule"
done
for image in myos-sway-main myos-sway-nvidia; do
    ! grep -Fq 'from-file: packages-server.yml' "$repo_root/recipes/recipe-$image.yml" \
        || fail "$image must not include server polkit policy"
done

node - "$rule" <<'JS'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

let authorize;
const polkit = {
    Result: { YES: "yes" },
    addRule: rule => { authorize = rule; }
};
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8"), { polkit });
assert.equal(typeof authorize, "function", "rule must register an authorization callback");

const wheelRemoteUser = {
    active: false,
    local: false,
    isInGroup: group => group === "wheel"
};
const nonWheelRemoteUser = {
    active: false,
    local: false,
    isInGroup: () => false
};
const check = (id, subject) => authorize({ id }, subject);

for (const id of [
    "org.freedesktop.login1.inhibit-block-sleep",
    "org.freedesktop.login1.inhibit-block-idle"
]) {
    assert.equal(check(id, wheelRemoteUser), polkit.Result.YES,
        `remote wheel user must be authorized for ${id}`);
    assert.equal(check(id, nonWheelRemoteUser), undefined,
        `non-wheel user must retain the default authorization for ${id}`);
}

for (const id of [
    "org.freedesktop.login1.suspend",
    "org.freedesktop.login1.power-off",
    "org.freedesktop.login1.power-off-ignore-inhibit",
    "org.freedesktop.login1.inhibit-block-shutdown",
    "org.freedesktop.systemd1.manage-units"
]) {
    assert.equal(check(id, wheelRemoteUser), undefined,
        `rule must not authorize unrelated action ${id}`);
}
JS

echo "PASS: server wheel users receive only sleep and idle inhibitor authorization"
