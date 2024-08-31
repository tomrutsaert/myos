# vim: set ft=make :
# This file can be modified downstream to add custom just commands

# enable rootless docker for user
enable-rootless-docker-for-user:
    #!/usr/bin/bash
    /usr/bin/dockerd-rootless-setuptool.sh install
    mkdir -p ~/.config/docker/
    json='{
    "default-address-pools":
        [
        {"base":"10.2.0.0/16","size":24}
        ]
    }'
    echo "$json" | tee -a ~/.config/docker/daemon.json
    systemctl stop docker.service
    systemctl disable docker.service
    systemctl stop docker.socket
    systemctl disable docker.socket
    systemctl --user enable docker.service
    systemctl --user start docker.service
    systemctl --user restart docker.service
    echo 'export DOCKER_HOST=unix:///run/user/1000/docker.sock' >> ~/.bashrc

add-user-to-groups:
    sudo usermod -a -G libvirt $(whoami)
    sudo usermod -a -G docker $(whoami)