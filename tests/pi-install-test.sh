#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
just_bin=$(command -v just)
justfile="$repo_root/files/justfiles/myjust.just"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

cat > "$test_dir/pi-stub" <<'PI'
#!/bin/bash
printf '%s\n' "pi $*" >> "$COMMAND_LOG"
[[ "$*" == --version ]] || exit 97
[[ "${FAIL_TOOL:-}" != pi ]] || exit 23
printf '1.0.0\n'
PI
cat > "$test_dir/npm-stub" <<'NPM'
#!/bin/bash
printf '%s\n' "npm $*" "npm-path $0" >> "$COMMAND_LOG"
[[ "$*" == 'install -g --ignore-scripts --no-fund --no-audit @earendil-works/pi-coding-agent' ]] || exit 97
[[ "${FAIL_TOOL:-}" != npm ]] || exit 23
/bin/cp "$PI_STUB" "${0%/*}/pi"
NPM
cat > "$test_dir/curl-stub" <<'CURL'
#!/bin/bash
printf '%s\n' 'unexpected curl' >> "$COMMAND_LOG"
exit 97
CURL
chmod +x "$test_dir/"*-stub

for scenario in system-install nvm-install existing nvm-existing nvm-failure npm-failure version-failure; do
    home="$test_dir/$scenario"
    bin="$home/bin"
    mkdir -p "$bin"
    command_log="$home/commands"
    : > "$command_log"
    ln -s /bin/bash "$bin/bash"
    cp "$test_dir/npm-stub" "$bin/npm"
    cp "$test_dir/curl-stub" "$bin/curl"
    fail_tool=''
    case "$scenario" in
        existing) cp "$test_dir/pi-stub" "$bin/pi" ;;
        nvm-install|nvm-existing|nvm-failure|npm-failure|version-failure)
            mkdir -p "$home/.nvm/bin"
            cp "$test_dir/npm-stub" "$home/.nvm/bin/npm"
            cat > "$home/.nvm/nvm.sh" <<'NVM'
nvm() {
    printf '%s\n' "nvm $*" >> "$COMMAND_LOG"
    [[ "$*" == 'use default' ]] || return 97
    [[ "${FAIL_TOOL:-}" != nvm ]] || return 23
    export NVM_BIN="$NVM_DIR/bin"
    export PATH="$NVM_BIN:$PATH"
}
NVM
            case "$scenario" in
                nvm-existing) cp "$test_dir/pi-stub" "$home/.nvm/bin/pi" ;;
                nvm-failure) fail_tool=nvm ;;
                npm-failure) fail_tool=npm ;;
                version-failure) fail_tool=pi ;;
            esac
            ;;
    esac
    status=0
    env -i HOME="$home" PATH="$bin" COMMAND_LOG="$command_log" \
        PI_STUB="$test_dir/pi-stub" FAIL_TOOL="$fail_tool" \
        "$just_bin" --justfile "$justfile" install-pi \
        </dev/null > "$home/output" 2>&1 || status=$?
    if [[ "$scenario" == *-failure ]]; then
        [[ "$status" -ne 0 ]] || fail "recipe must fail ($scenario)"
        ! grep -q '^Pi installed' "$home/output" \
            || fail "recipe must not announce success ($scenario)"
    else
        [[ "$status" -eq 0 ]] || fail "recipe must succeed ($scenario): $(cat "$home/output")"
    fi
    ! grep -q '^unexpected ' "$command_log" \
        || fail "recipe must not invoke an interactive installer ($scenario)"
    if [[ "$scenario" == existing || "$scenario" == nvm-existing ]]; then
        expected_log='pi --version'
        [[ "$scenario" != nvm-existing ]] || expected_log=$'nvm use default\npi --version'
        [[ $(cat "$command_log") == "$expected_log" ]] \
            || fail "existing Pi must be left untouched"
        grep -Fqx 'Pi is already installed: 1.0.0' "$home/output" \
            || fail "existing Pi must be reported"
        continue
    fi
    if [[ "$scenario" != system-install ]]; then
        [[ $(head -1 "$command_log") == 'nvm use default' ]] \
            || fail "recipe must select NVM default first ($scenario)"
    fi
    if [[ "$scenario" == nvm-failure ]]; then
        [[ $(wc -l < "$command_log") -eq 1 ]] \
            || fail "failed NVM selection must stop before installation"
        continue
    fi
    grep -Fqx 'npm install -g --ignore-scripts --no-fund --no-audit @earendil-works/pi-coding-agent' "$command_log" \
        || fail "recipe must install Pi non-interactively ($scenario)"
    npm_path="$home/.nvm/bin/npm"
    [[ "$scenario" != system-install ]] || npm_path="$bin/npm"
    grep -Fqx "npm-path $npm_path" "$command_log" \
        || fail "recipe must use the selected Node runtime ($scenario)"
    if [[ "$scenario" == npm-failure ]]; then
        ! grep -q '^pi ' "$command_log" || fail "failed installation must stop before version check"
    else
        grep -Fqx 'pi --version' "$command_log" \
            || fail "recipe must verify installation ($scenario)"
    fi
    if [[ "$scenario" != *-failure ]]; then
        grep -Fqx 'Pi installed: 1.0.0' "$home/output" \
            || fail "successful installation must be reported ($scenario)"
    fi
done

echo 'PASS: headless Pi installation, existing installs, runtime selection and failures'
