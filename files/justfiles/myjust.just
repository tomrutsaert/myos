# vim: set ft=make :
# This file can be modified downstream to add custom just commands

add-user-to-groups:
    sudo usermod -a -G libvirt $(whoami)
    sudo usermod -a -G docker $(whoami)

fix-docker:
    sudo groupadd docker
    sudo usermod -a -G docker $(whoami)
    sudo systemctl restart docker.service
    sudo systemctl restart docker.socket

install-intellij:
    #!/usr/bin/bash
    echo "Get and install latest JetBrains Intellij Ultimate version"
    mkdir -p /tmp/idea && cd /tmp/idea
    curl -sSfL -o releases.json "https://data.services.jetbrains.com/products/releases?code=IIU&latest=true&type=release"
    BUILD_VERSION=$(jq -r '.IIU[0].build' ./releases.json)
    DOWNLOAD_LINK=$(jq -r '.IIU[0].downloads.linux.link' ./releases.json)
    CHECKSUM_LINK=$(jq -r '.IIU[0].downloads.linux.checksumLink' ./releases.json)
    echo "Installing Intellij ${BUILD_VERSION}"
    curl -sSfL -O "${DOWNLOAD_LINK}"
    curl -sSfL "${CHECKSUM_LINK}" | sha256sum -c
    mkdir -p $HOME/applications
    tar -xzf ideaIU-*.tar.gz -C $HOME/applications
    mkdir -p $HOME/.local/share/applications
    cat << EOF > $HOME/.local/share/applications/jetbrains-idea.desktop
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=IntelliJ IDEA Ultimate Edition
    Icon=$HOME/applications/idea-IU-${BUILD_VERSION}/bin/idea.svg
    Exec="$HOME/applications/idea-IU-${BUILD_VERSION}/bin/idea" %f
    Comment=Capable and Ergonomic IDE for JVM
    Categories=Development;IDE;
    Terminal=false
    StartupWMClass=jetbrains-idea
    StartupNotify=true
    EOF