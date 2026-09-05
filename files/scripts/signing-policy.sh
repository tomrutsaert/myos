#!/usr/bin/env bash
set -euo pipefail

root=${1:-}
root=${root%/}
: "${IMAGE_NAME:?BlueBuild must export IMAGE_NAME}"
: "${IMAGE_REGISTRY:?BlueBuild must export IMAGE_REGISTRY}"
image_name_file=${IMAGE_NAME//\//_}
key_path="/etc/pki/containers/$image_name_file.pub"
policy_file="$root/etc/containers/policy.json"
registries_dir="$root/etc/containers/registries.d"
module_repository="$IMAGE_REGISTRY/$IMAGE_NAME"
module_registry_config="$registries_dir/${IMAGE_REGISTRY##*/}-$image_name_file.yaml"
shared_registry_config="$registries_dir/myos-repositories.yaml"
repositories=(
    ghcr.io/tomrutsaert/myos-server-main
    ghcr.io/tomrutsaert/myos-server-nvidia
    ghcr.io/tomrutsaert/myos-sway-main
    ghcr.io/tomrutsaert/myos-sway-nvidia
)

[[ -f "$root$key_path" ]] || {
    echo "Missing BlueBuild signing key: $key_path" >&2
    exit 1
}
[[ -f "$policy_file" ]] || {
    echo "Missing BlueBuild container policy: ${policy_file#"$root"}" >&2
    exit 1
}
[[ -f "$module_registry_config" ]] || {
    echo "Missing BlueBuild registry configuration: ${module_registry_config#"$root"}" >&2
    exit 1
}

tmp_policy=$(mktemp "$policy_file.XXXXXX")
tmp_registry=$(mktemp "$registries_dir/.myos-repositories.yaml.XXXXXX")
cleanup() {
    rm -f -- "$tmp_policy" "$tmp_registry"
}
trap cleanup EXIT

jq --arg key_path "$key_path" \
   --arg server_main "${repositories[0]}" \
   --arg server_nvidia "${repositories[1]}" \
   --arg sway_main "${repositories[2]}" \
   --arg sway_nvidia "${repositories[3]}" '
    if (.default | type) != "array" or
       (.transports | type) != "object" or
       (.transports.docker | type) != "object"
    then error("BlueBuild generated an invalid container policy")
    else
      [$server_main, $server_nvidia, $sway_main, $sway_nvidia] as $repositories |
      reduce $repositories[] as $repository (.;
        .transports.docker |= with_entries(
          select((
            .key == $repository or
            (.key | startswith($repository + ":")) or
            (.key | startswith($repository + "@")) or
            (.key | startswith($repository + "/"))
          ) | not)
        ) |
        .transports.docker[$repository] = [{
          "type": "sigstoreSigned",
          "keyPath": $key_path,
          "signedIdentity": {"type": "matchRepository"}
        }]
      )
    end
' "$policy_file" > "$tmp_policy"
chmod --reference="$policy_file" "$tmp_policy"

# The signing module already owns the current repository's entry. Add only the
# other MyOS repositories so containers/image never sees duplicate scopes.
{
    echo 'docker:'
    for repository in "${repositories[@]}"; do
        [[ "$repository" == "$module_repository" ]] && continue
        printf '  %s:\n' "$repository"
        echo '    use-sigstore-attachments: true'
    done
} > "$tmp_registry"
chmod 0644 "$tmp_registry"

mv -f -- "$tmp_policy" "$policy_file"
mv -f -- "$tmp_registry" "$shared_registry_config"
trap - EXIT

echo "Required signed images from all four MyOS repositories."
