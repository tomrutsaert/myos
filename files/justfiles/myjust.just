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

install-flatpaks:
    #!/usr/bin/bash
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub \
    com.discordapp.Discord \
    com.github.wwmm.easyeffects \
    com.github.tchx84.Flatseal \
    com.mattjakeman.ExtensionManager \
    com.jeffser.Alpaca \
    com.microsoft.Edge \
    com.nextcloud.desktopclient.nextcloud \
    com.slack.Slack \
    com.spotify.Client \
    de.hohnstaedt.xca \
    dev.zed.Zed \
    io.dbeaver.DBeaverCommunity \
    io.podman_desktop.PodmanDesktop \
    io.gitlab.adhami3310.Converter \
    io.gitlab.liferooter.TextPieces \
    it.mijorus.gearlever \
    org.chromium.Chromium \
    org.geany.Geany \
    org.gimp.GIMP \
    org.gnome.Loupe \
    org.gnome.Papers \
    org.gnome.TextEditor \
    org.kde.kolourpaint \
    org.libreoffice.LibreOffice \
    org.mozilla.firefox \
    org.telegram.desktop \
    org.videolan.VLC
