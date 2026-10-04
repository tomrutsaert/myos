# vim: set ft=make :
# Desktop aggregate entrypoints.

install-all:
    @ujust _install-all set-locale,install-brew-all,install-flatpaks,install-sdkman,install-nvm,install-intellij,install-datagrip,install-zed,install-claude,install-codex,install-opencode,install-pi

update-all:
    @ujust _update-all true
