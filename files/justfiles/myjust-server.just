# vim: set ft=make :
# Server/headless aggregate entrypoints.

install-all:
    @ujust _install-all set-locale,add-user-to-groups,fix-docker,fix-network-priority,install-brew-all,install-sdkman,install-nvm,install-claude,install-codex,install-opencode,install-pi

update-all:
    @ujust _update-all false
