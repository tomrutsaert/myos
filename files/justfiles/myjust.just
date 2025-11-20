# vim: set ft=make :
# This file can be modified downstream to add custom just commands

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
    com.slack.Slack \
    com.spotify.Client \
    de.hohnstaedt.xca \
    io.dbeaver.DBeaverCommunity \
    io.podman_desktop.PodmanDesktop \
    it.mijorus.gearlever \
    org.gimp.GIMP \
    org.libreoffice.LibreOffice \
    org.telegram.desktop \
    org.videolan.VLC

install-gnome-flatpaks:
    #!/usr/bin/bash
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub \
    com.mattjakeman.ExtensionManager \
    io.gitlab.adhami3310.Converter \
    io.gitlab.liferooter.TextPieces \
    org.gnome.Loupe \
    org.gnome.Papers \
    org.gnome.TextEditor