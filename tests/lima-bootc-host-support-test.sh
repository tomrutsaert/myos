#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
brew_justfile="$repo_root/files/justfiles/myjust.just"
docker_recipe="$repo_root/recipes/docker.yml"
virtualization_recipe="$repo_root/recipes/virtualization.yml"
packages_documentation="$repo_root/PACKAGES.md"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_list_item() {
    local file="$1" item="$2" description="$3"

    grep -Eq "^[[:space:]]*-[[:space:]]+${item}[[:space:]]*(\\\\)?[[:space:]]*$" "$file" \
        || fail "$description does not declare $item"
}

brew_recipe=$(awk '
    /^install-brew-cli-tools:/ { in_recipe=1; next }
    in_recipe && /^[^[:space:]#][^:]*:/ { exit }
    in_recipe { print }
' "$brew_justfile")

required_formulae=(difftastic lima mise mkcert mosh ttyd ydiff)
expected_formula_order=$(printf '%s\n' "${required_formulae[@]}")
for formula in "${required_formulae[@]}"; do
    grep -Eq "^[[:space:]]+${formula}([[:space:]]*\\\\)?[[:space:]]*$" <<<"$brew_recipe" \
        || fail "install-brew-cli-tools does not explicitly install $formula"
done
brew_formula_order=$(grep -E '^[[:space:]]+(difftastic|lima|mise|mkcert|mosh|ttyd|ydiff)([[:space:]]*\\)?[[:space:]]*$' <<<"$brew_recipe" \
    | sed -E 's/^[[:space:]]*([^[:space:]]+).*/\1/')
[[ "$brew_formula_order" == "$expected_formula_order" ]] \
    || fail "required Homebrew formulae are not alphabetized in install-brew-cli-tools"

assert_list_item "$docker_recipe" podman "Docker recipe"
for package in qemu-img virtiofsd edk2-ovmf qemu-kvm; do
    assert_list_item "$virtualization_recipe" "$package" "virtualization recipe"
done

for required_recipe in "$docker_recipe" "$virtualization_recipe"; do
    if grep -Eq '^[[:space:]]*skip-unavailable:[[:space:]]*true[[:space:]]*$' "$required_recipe"; then
        fail "$(basename "$required_recipe") silently skips unavailable required packages"
    fi
done

homebrew_documentation=$(awk '
    /^### Per-user Homebrew CLI tools$/ { in_section=1; next }
    in_section && /^### / { exit }
    in_section { print }
' "$packages_documentation")
[[ -n "$homebrew_documentation" ]] \
    || fail "PACKAGES.md is missing the per-user Homebrew CLI tools section"
for formula in "${required_formulae[@]}"; do
    grep -Fqx -- "- \`$formula\`" <<<"$homebrew_documentation" \
        || fail "PACKAGES.md does not document Homebrew formula $formula"
done
markdown_tick=$(printf '\140')
documented_formula_order=$(grep -E "^- ${markdown_tick}(difftastic|lima|mise|mkcert|mosh|ttyd|ydiff)${markdown_tick}$" <<<"$homebrew_documentation" \
    | sed -E "s/^- ${markdown_tick}([^${markdown_tick}]+).*/\\1/")
[[ "$documented_formula_order" == "$expected_formula_order" ]] \
    || fail "required Homebrew formulae are not alphabetized in PACKAGES.md"
for package in podman qemu-img virtiofsd edk2-ovmf qemu-kvm; do
    grep -Fqx -- "- \`$package\`" "$packages_documentation" \
        || fail "PACKAGES.md does not document Fedora package $package"
done
grep -Eiq 'Lima.*(per-user|per user)|(per-user|per user).*Lima' <<<"$homebrew_documentation" \
    || fail "PACKAGES.md does not describe Lima as a per-user install"
grep -Eiq 'Lima.*Homebrew|Homebrew.*Lima' <<<"$homebrew_documentation" \
    || fail "PACKAGES.md does not describe Lima as installed through Homebrew"
grep -Fq 'ujust install-brew-cli-tools' <<<"$homebrew_documentation" \
    || fail "PACKAGES.md does not identify the ujust Homebrew installation recipe"
grep -Eiq 'not[[:space:]]+(layered|baked)|(not|rather than).*(immutable image)' <<<"$homebrew_documentation" \
    || fail "PACKAGES.md does not distinguish Homebrew tools from image-layered packages"

mapfile -t image_recipes < <(find "$repo_root/recipes" -maxdepth 1 -type f -name 'recipe-*.yml' -print | sort)
[[ ${#image_recipes[@]} -gt 0 ]] || fail "no image recipes found"
for recipe in "${image_recipes[@]}"; do
    for shared_recipe in docker.yml virtualization.yml; do
        import_count=$(grep -Ec "^[[:space:]]*-[[:space:]]+from-file:[[:space:]]+${shared_recipe//./\\.}[[:space:]]*$" "$recipe" || true)
        [[ "$import_count" -eq 1 ]] \
            || fail "$(basename "$recipe") must import shared $shared_recipe exactly once"
    done
done

if grep -R -Eq '^[[:space:]]*-[[:space:]]+bootc-image-builder[[:space:]]*$' \
    "$repo_root/recipes"; then
    fail "bootc-image-builder must remain containerized rather than a host package"
fi

echo "PASS: Lima/bootc host support package and documentation contracts"
