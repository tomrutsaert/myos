# vim: set ft=make :
# This file can be modified downstream to add custom just commands

# --- install-all (runs everything) ---

install-all:
    #!/usr/bin/bash
    set -euo pipefail
    just set-locale
    just add-user-to-groups
    just fix-docker
    just fix-network-priority
    just install-brew-all
    just install-flatpaks
    just install-sdkman
    just install-nvm
    just install-intellij
    just install-datagrip
    echo "All installations complete."

# --- system ---

set-locale:
    #!/usr/bin/bash
    set -euo pipefail
    sudo localectl set-x11-keymap us pc104 '' altgr-intl
    echo "Locale set to us/pc104/altgr-intl."
    localectl

add-user-to-groups:
    sudo usermod -a -G libvirt $(whoami)
    sudo usermod -a -G docker $(whoami)

fix-docker:
    sudo groupadd -f docker
    sudo usermod -a -G docker $(whoami)
    sudo systemctl restart docker.service
    sudo systemctl restart docker.socket

fix-network-priority:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Current connections:"
    nmcli -t -f NAME,TYPE,DEVICE connection show --active
    echo ""
    read -rp "Enter connection name to set lower priority (metric 40): " conn
    nmcli connection modify "$conn" ipv4.route-metric 40
    nmcli connection up "$conn"
    echo "Route metric for '$conn' set to 40."

# --- brew ---

install-brew:
    #!/usr/bin/bash
    set -euo pipefail
    if command -v brew &>/dev/null || [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
      echo "Homebrew is already installed."
      exit 0
    fi
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo >> "$HOME/.bashrc"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.bashrc"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "Homebrew installed. Restart your shell or run: source ~/.bashrc"

install-brew-cli-tools:
    #!/usr/bin/bash
    set -euo pipefail
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "Installing CLI tools via Homebrew..."
    brew install \
      awscli \
      bash-completion@2 \
      btop \
      fd \
      ffmpeg-full \
      fzf \
      git \
      git-delta \
      imagemagick \
      lazygit \
      libheif \
      make \
      net-tools \
      neovim \
      nvtop \
      poppler \
      resvg \
      ripgrep \
      sevenzip \
      starship \
      stow \
      tmux \
      tree-sitter-cli \
      uv \
      yazi \
      zoxide
    # bashrc additions (idempotent)
    grep -q 'starship init bash' "$HOME/.bashrc" || echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
    grep -q 'zoxide init bash' "$HOME/.bashrc" || echo 'eval "$(zoxide init bash)"' >> "$HOME/.bashrc"
    grep -q 'bash_completion.sh' "$HOME/.bash_profile" 2>/dev/null || \
      echo '[[ -r "/home/linuxbrew/.linuxbrew/etc/profile.d/bash_completion.sh" ]] && . "/home/linuxbrew/.linuxbrew/etc/profile.d/bash_completion.sh"' >> "$HOME/.bash_profile"
    # tmux bash completion
    dir="${BASH_COMPLETION_DIR:-"${XDG_DATA_HOME:-"$HOME/.local/share"}/bash-completion"}/completions"
    mkdir -p "$dir"
    curl -fSsL "https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux" > "$dir/tmux"
    echo "CLI tools installed. Restart your shell or run: source ~/.bashrc"

install-brew-fonts:
    #!/usr/bin/bash
    set -euo pipefail
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "Installing Nerd Fonts via Homebrew..."
    brew install --cask \
      font-3270-nerd-font \
      font-fira-mono-nerd-font \
      font-inconsolata-go-nerd-font \
      font-inconsolata-lgc-nerd-font \
      font-inconsolata-nerd-font \
      font-monofur-nerd-font \
      font-overpass-nerd-font \
      font-ubuntu-mono-nerd-font \
      font-agave-nerd-font \
      font-arimo-nerd-font \
      font-anonymice-nerd-font \
      font-aurulent-sans-mono-nerd-font \
      font-bigblue-terminal-nerd-font \
      font-bitstream-vera-sans-mono-nerd-font \
      font-blex-mono-nerd-font \
      font-caskaydia-cove-nerd-font \
      font-code-new-roman-nerd-font \
      font-cousine-nerd-font \
      font-daddy-time-mono-nerd-font \
      font-dejavu-sans-mono-nerd-font \
      font-droid-sans-mono-nerd-font \
      font-fantasque-sans-mono-nerd-font \
      font-fira-code-nerd-font \
      font-go-mono-nerd-font \
      font-gohufont-nerd-font \
      font-hack-nerd-font \
      font-hasklug-nerd-font \
      font-heavy-data-nerd-font \
      font-hurmit-nerd-font \
      font-im-writing-nerd-font \
      font-iosevka-nerd-font \
      font-jetbrains-mono-nerd-font \
      font-lekton-nerd-font \
      font-liberation-nerd-font \
      font-meslo-lg-nerd-font \
      font-monoid-nerd-font \
      font-mononoki-nerd-font \
      font-mplus-nerd-font \
      font-noto-nerd-font \
      font-open-dyslexic-nerd-font \
      font-profont-nerd-font \
      font-proggy-clean-tt-nerd-font \
      font-roboto-mono-nerd-font \
      font-sauce-code-pro-nerd-font \
      font-shure-tech-mono-nerd-font \
      font-space-mono-nerd-font \
      font-terminess-ttf-nerd-font \
      font-tinos-nerd-font \
      font-ubuntu-nerd-font \
      font-victor-mono-nerd-font \
      font-fontawesome \
      font-symbols-only-nerd-font \
      font-noto-color-emoji
    echo "Fonts installed."

install-brew-all:
    #!/usr/bin/bash
    set -euo pipefail
    just install-brew
    just install-brew-cli-tools
    just install-brew-fonts
    echo "All Homebrew components installed."

# --- flatpaks ---

install-flatpaks:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Installing Flatpaks..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y --or-update \
      com.discordapp.Discord \
      com.github.tchx84.Flatseal \
      com.slack.Slack \
      com.spotify.Client \
      de.hohnstaedt.xca \
      it.mijorus.gearlever \
      org.gimp.GIMP \
      org.libreoffice.LibreOffice \
      org.telegram.desktop
    echo "Applying Slack flatpak fix..."
    sudo flatpak override com.slack.Slack \
      --socket=wayland \
      --socket=pulseaudio \
      --filesystem=home \
      --talk-name=org.freedesktop.impl.portal.* \
      --device=all
    echo "Flatpaks installed and Slack fix applied."

# --- dev tools ---

install-sdkman:
    #!/usr/bin/bash
    set -euxo pipefail
    if [ -d "$HOME/.sdkman" ]; then
      echo "SDKMAN already installed, updating..."
      source "$HOME/.sdkman/bin/sdkman-init.sh"
      sdk selfupdate || true
    else
      curl -s "https://get.sdkman.io" | bash
      source "$HOME/.sdkman/bin/sdkman-init.sh"
    fi
    sdk version
    sed -i 's/sdkman_auto_env=false/sdkman_auto_env=true/g' $HOME/.sdkman/etc/config
    sdk install maven || true
    sdk install jbang || true
    sdk install java $(sdk list java | grep -o '25\.[0-9.]*-amzn' | head -1) || true
    echo "SDKMAN installed with maven, jbang, and Amazon Corretto Java 25."

install-nvm:
    #!/usr/bin/bash
    set -euxo pipefail
    LATEST=$(curl -sSfL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST}/install.sh" | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --latest-npm
    nvm alias default $(node --version) || true
    echo "NVM installed with Node $(node --version) and npm $(npm --version)."

install-intellij:
    #!/usr/bin/bash
    set -euxo pipefail
    if ls $HOME/applications/idea-IU-* &>/dev/null; then
      echo "IntelliJ IDEA is already installed."
      exit 0
    fi
    mkdir -p /tmp/idea && cd /tmp/idea
    curl -sSfL --max-time 30 -o releases.json "https://data.services.jetbrains.com/products/releases?code=IIU&latest=true&type=release"
    BUILD_VERSION=$(jq -r '.IIU[0].build' ./releases.json)
    DOWNLOAD_LINK=$(jq -r '.IIU[0].downloads.linux.link' ./releases.json)
    CHECKSUM_LINK=$(jq -r '.IIU[0].downloads.linux.checksumLink' ./releases.json)
    echo "Installing IntelliJ IDEA Ultimate ${BUILD_VERSION}"
    curl -sSfL -O "${DOWNLOAD_LINK}"
    curl -sSfL "${CHECKSUM_LINK}" | sha256sum -c || {
      echo "Checksum verification failed!" >&2
      rm -f ideaIU-*.tar.gz
      exit 1
    }
    mkdir -p $HOME/applications
    tar -xzf ideaIU-*.tar.gz -C $HOME/applications --no-same-owner
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
    rm -rf /tmp/idea

install-datagrip:
    #!/usr/bin/bash
    set -euxo pipefail
    if ls $HOME/applications/DataGrip-* &>/dev/null; then
      echo "DataGrip is already installed."
      exit 0
    fi
    mkdir -p /tmp/datagrip && cd /tmp/datagrip
    curl -sSfL --max-time 30 -o releases.json "https://data.services.jetbrains.com/products/releases?code=DG&latest=true&type=release"
    BUILD_VERSION=$(jq -r '.DG[0].build' ./releases.json)
    DOWNLOAD_LINK=$(jq -r '.DG[0].downloads.linux.link' ./releases.json)
    CHECKSUM_LINK=$(jq -r '.DG[0].downloads.linux.checksumLink' ./releases.json)
    echo "Installing DataGrip ${BUILD_VERSION}"
    curl -sSfL -O "${DOWNLOAD_LINK}"
    curl -sSfL "${CHECKSUM_LINK}" | sha256sum -c || {
      echo "Checksum verification failed!" >&2
      rm -f datagrip-*.tar.gz
      exit 1
    }
    mkdir -p $HOME/applications
    tar -xzf datagrip-*.tar.gz -C $HOME/applications --no-same-owner
    mkdir -p $HOME/.local/share/applications
    cat << EOF > $HOME/.local/share/applications/jetbrains-datagrip.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=DataGrip
Icon=$HOME/applications/DataGrip-${BUILD_VERSION}/bin/datagrip.svg
Exec="$HOME/applications/DataGrip-${BUILD_VERSION}/bin/datagrip" %f
Comment=Database IDE by JetBrains
Categories=Development;IDE;Database;
Terminal=false
StartupWMClass=jetbrains-datagrip
StartupNotify=true
EOF
    rm -rf /tmp/datagrip
