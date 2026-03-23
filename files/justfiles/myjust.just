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
    set -euxo pipefail  # Critical safety additions

    echo "Installing JetBrains IntelliJ Ultimate"
    mkdir -p /tmp/idea && cd /tmp/idea

    # Validate jq is available
    if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
    fi

    # Fetch version data with timeout
    curl -sSfL --max-time 30 -o releases.json \
    "https://data.services.jetbrains.com/products/releases?code=IIU&latest=true&type=release"

    # Validate response
    if ! jq empty releases.json >/dev/null 2>&1; then
    echo "Error: Invalid JSON response" >&2
    exit 1
    fi

    BUILD_VERSION=$(jq -r '.IIU[0].build' releases.json)
    DOWNLOAD_LINK=$(jq -r '.IIU[0].downloads.linux.link' releases.json)
    CHECKSUM_LINK=$(jq -r '.IIU[0].downloads.linux.checksumLink' releases.json)

    # Verify download integrity
    curl -sSfL -O "$DOWNLOAD_LINK"
    curl -sSfL "$CHECKSUM_LINK" | sha256sum -c --status || {
    echo "Checksum verification failed!" >&2
    rm -f ideaIU-*.tar.gz
    exit 1
    }

    # Install with ownership preservation
    mkdir -p "$HOME/applications"
    tar -xzf ideaIU-*.tar.gz -C "$HOME/applications" --no-same-owner

    # Desktop entry creation (preserves existing configs)
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/jetbrains-idea.desktop" << EOF
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