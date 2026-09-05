#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
policy_script="$repo_root/files/scripts/signing-policy.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ -x "$policy_script" ]] \
    || fail "the shared signing-policy build script must be executable"
command -v yq >/dev/null \
    || fail "yq is required to inspect generated registry configuration"

repositories=(
    ghcr.io/tomrutsaert/myos-server-main
    ghcr.io/tomrutsaert/myos-server-nvidia
    ghcr.io/tomrutsaert/myos-sway-main
    ghcr.io/tomrutsaert/myos-sway-nvidia
)
images=(myos-server-main myos-server-nvidia myos-sway-main myos-sway-nvidia)

test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

for image in "${images[@]}"; do
    root="$test_dir/$image"
    policy="$root/etc/containers/policy.json"
    key_path="/etc/pki/containers/$image.pub"
    registries_dir="$root/etc/containers/registries.d"
    registry_namespace=ghcr.io/tomrutsaert
    [[ "$image" != myos-server-main ]] || registry_namespace=localhost
    generated_config="$registries_dir/${registry_namespace##*/}-$image.yaml"
    mkdir -p "$(dirname -- "$policy")" "$(dirname -- "$root$key_path")" \
        "$(dirname -- "$generated_config")"
    printf 'shared test key\n' > "$root$key_path"
    cat > "$policy" <<'EOF'
{
  "default": [{"type": "reject"}],
  "transports": {
    "docker": {
      "": [{"type": "insecureAcceptAnything"}],
      "quay.io/example/unchanged": [{"type": "insecureAcceptAnything"}]
    },
    "dir": {"": [{"type": "insecureAcceptAnything"}]}
  }
}
EOF
    for repository in "${repositories[@]}"; do
        tmp="$policy.tmp"
        jq --arg repository "$repository" \
            '.transports.docker[$repository] = [{"type":"insecureAcceptAnything"}]' \
            "$policy" > "$tmp"
        mv "$tmp" "$policy"
    done
    tmp="$policy.tmp"
    jq --arg repository "${repositories[0]}:latest" \
        '.transports.docker[$repository] = [{"type":"insecureAcceptAnything"}]' \
        "$policy" > "$tmp"
    mv "$tmp" "$policy"
    cat > "$generated_config" <<EOF
docker:
  $registry_namespace/$image:
    use-sigstore-attachments: true
EOF

    IMAGE_NAME="$image" IMAGE_REGISTRY="$registry_namespace" \
        "$policy_script" "$root"

    jq -e '.default == [{"type":"reject"}]' "$policy" >/dev/null \
        || fail "$image must preserve the rejecting default policy"
    jq -e '.transports.docker["quay.io/example/unchanged"] == [{"type":"insecureAcceptAnything"}]' \
        "$policy" >/dev/null \
        || fail "$image must preserve unrelated policy scopes"
    jq -e '.transports.dir[""] == [{"type":"insecureAcceptAnything"}]' "$policy" >/dev/null \
        || fail "$image must preserve unrelated transports"

    for repository in "${repositories[@]}"; do
        jq -e --arg repository "$repository" --arg key "$key_path" '
            .transports.docker[$repository] == [{
                "type": "sigstoreSigned",
                "keyPath": $key,
                "signedIdentity": {"type": "matchRepository"}
            }]
        ' "$policy" >/dev/null \
            || fail "$image must require the shared cosign key for $repository"
        matching_configs=0
        for registry_config in "$registries_dir"/*.yaml; do
            if yq -e ".docker.\"$repository\".\"use-sigstore-attachments\" == true" \
                "$registry_config" >/dev/null 2>&1; then
                ((matching_configs += 1))
            fi
        done
        [[ $matching_configs -eq 1 ]] \
            || fail "$image must enable sigstore attachments exactly once for $repository"
    done

    jq -e --argjson repositories "$(printf '%s\n' "${repositories[@]}" | jq -R . | jq -s .)" '
        [.transports.docker | keys[] as $scope | $repositories[] as $repository |
          select(
            $scope | startswith($repository + ":") or
                     startswith($repository + "@") or
                     startswith($repository + "/")
          )] | length == 0
    ' "$policy" >/dev/null \
        || fail "$image must remove narrower policy scopes that could bypass verification"
    [[ -e "$generated_config" ]] \
        || fail "$image must preserve the signing module's generated repository config"
done

missing_key_root="$test_dir/missing-key"
missing_key_policy="$missing_key_root/etc/containers/policy.json"
mkdir -p "$missing_key_root/etc/containers/registries.d"
cat > "$missing_key_policy" <<'EOF'
{"default":[{"type":"reject"}],"transports":{"docker":{}}}
EOF
cat > "$missing_key_root/etc/containers/registries.d/tomrutsaert-myos-server-main.yaml" <<'EOF'
docker:
  ghcr.io/tomrutsaert/myos-server-main:
    use-sigstore-attachments: true
EOF
policy_before=$(sha256sum "$missing_key_policy")
if IMAGE_NAME=myos-server-main IMAGE_REGISTRY=ghcr.io/tomrutsaert \
    "$policy_script" "$missing_key_root" >/dev/null 2>&1; then
    fail "policy installation must fail when BlueBuild's shared signing key is missing"
fi
[[ $(sha256sum "$missing_key_policy") == "$policy_before" ]] \
    || fail "a missing signing key must leave the existing policy unchanged"

echo "PASS: every image trusts all four signed MyOS repositories"
