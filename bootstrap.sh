#!/usr/bin/env bash
# WSL2 Debian Bootstrap Script
# Idempotent: safe to run multiple times.
# Prerequisites: sudo access, GitHub SSH key configured.

set -euo pipefail

# ── Variables ─────────────────────────────────────────────────────────────────

DOTFILES_REPO="git@github.com:jstubbsdev/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
CODE_DIR="$HOME/Work"

# PHP version to install via phpenv.
# Check the FROM line in:
# https://github.com/fvp-mds/fvp-b2c-api/blob/master/build/images/b2c-base/Dockerfile
PHP_VERSION="8.2.28"

# ── Colours ───────────────────────────────────────────────────────────────────

RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'

# ── Helpers ───────────────────────────────────────────────────────────────────

log()     { echo -e "${CYAN}${BOLD}==>${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}  ✔${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}  ⚠${RESET}  $*"; }
skip()    { echo -e "  ${BOLD}↩${RESET}  $* (already done, skipping)"; }

command_exists() { command -v "$1" &>/dev/null; }

apt_install() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

# ── Prevent snap ──────────────────────────────────────────────────────────────

prevent_snap() {
    log "Preventing snap from being installed..."
    if [[ ! -f /etc/apt/preferences.d/no-snap ]]; then
        printf 'Package: snapd\nPin: release a=*\nPin-Priority: -10\n' \
            | sudo tee /etc/apt/preferences.d/no-snap > /dev/null
        success "snap blocked via apt preferences"
    else
        skip "snap already blocked"
    fi
}

# ── System update ─────────────────────────────────────────────────────────────

system_update() {
    log "Updating and upgrading system packages..."
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    success "System packages up to date"
}

# ── Core APT packages ─────────────────────────────────────────────────────────

install_apt_packages() {
    log "Installing core APT packages..."
    apt_install \
        curl \
        jq \
        htop \
        xinit \
        gpg \
        make \
        wget \
        unzip \
        git \
        python3 \
        python3-pip \
        python3-venv \
        python3-setuptools \
        libkrb5-dev \
        libssh-dev
    success "Core APT packages installed"
}

# ── Zsh + Oh My Zsh ───────────────────────────────────────────────────────────

install_zsh() {
    log "Installing zsh..."
    apt_install zsh

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        success "Oh My Zsh installed"
    else
        skip "Oh My Zsh"
    fi

    local current_shell
    current_shell=$(getent passwd "$USER" | cut -d: -f7)
    if [[ "$current_shell" != "$(command -v zsh)" ]]; then
        log "Setting zsh as default shell..."
        sudo chsh -s "$(command -v zsh)" "$USER"
        success "Default shell set to zsh (takes effect on next login)"
    else
        skip "zsh already default shell"
    fi
}

# ── NVM + Node ────────────────────────────────────────────────────────────────

install_nvm() {
    if [[ ! -d "$HOME/.nvm" ]]; then
        log "Installing nvm..."
        local nvm_version
        nvm_version=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
            | jq -r '.tag_name')
        curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
        success "nvm ${nvm_version} installed"
    else
        skip "nvm"
    fi

    # Load nvm for use in this script session
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    log "Installing latest active Node.js LTS..."
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
    success "Node.js $(node --version) set as default"
}

# ── GitHub Copilot CLI ────────────────────────────────────────────────────────

install_copilot() {
    log "Installing GitHub Copilot CLI..."

    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    if npm list -g --depth=0 2>/dev/null | grep -q '@github/copilot'; then
        skip "GitHub Copilot CLI"
    else
        npm install -g @github/copilot
        success "GitHub Copilot CLI installed"
    fi
}

# ── AWS CLI ───────────────────────────────────────────────────────────────────

install_aws_cli() {
    log "Installing AWS CLI..."
    if command_exists aws; then
        skip "AWS CLI ($(aws --version 2>&1 | head -1))"
        return
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o "$tmp_dir/awscliv2.zip"
    unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir"
    sudo "$tmp_dir/aws/install"
    rm -rf "$tmp_dir"
    success "AWS CLI installed: $(aws --version 2>&1 | head -1)"
}

# ── AWS SAM CLI ───────────────────────────────────────────────────────────────

install_aws_sam() {
    log "Installing AWS SAM CLI..."
    if command_exists sam; then
        skip "AWS SAM CLI ($(sam --version))"
        return
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local sam_url
    sam_url=$(curl -fsSL https://api.github.com/repos/aws/aws-sam-cli/releases/latest \
        | jq -r '.assets[] | select(.name == "aws-sam-cli-linux-x86_64.zip") | .browser_download_url')
    curl -fsSL "$sam_url" -o "$tmp_dir/aws-sam-cli.zip"
    unzip -q "$tmp_dir/aws-sam-cli.zip" -d "$tmp_dir/sam-install"
    sudo "$tmp_dir/sam-install/install"
    rm -rf "$tmp_dir"
    success "AWS SAM CLI installed: $(sam --version)"
}

# ── Granted CLI ───────────────────────────────────────────────────────────────

install_granted() {
    log "Installing Granted CLI..."

    if [[ ! -f /usr/share/keyrings/common-fate-linux.gpg ]]; then
        wget -qO- https://apt.releases.commonfate.io/gpg \
            | sudo gpg --dearmor -o /usr/share/keyrings/common-fate-linux.gpg
    fi

    if [[ ! -f /etc/apt/sources.list.d/common-fate.list ]]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/common-fate-linux.gpg] https://apt.releases.commonfate.io stable main" \
            | sudo tee /etc/apt/sources.list.d/common-fate.list > /dev/null
        sudo apt-get update -qq
    fi

    apt_install granted

    if command_exists granted; then
        success "Granted CLI installed"
    fi

    log "Configuring Granted registry..."
    if granted registry list 2>/dev/null | grep -q 'etv'; then
        skip "Granted registry 'etv'"
    else
        granted registry add \
            -n etv \
            -p "users/james.stubbs@everyonetv.co.uk" \
            -u "git@github.com:everyonetv/granted-registry.git" \
            || warn "Could not add Granted registry (may need to run manually after login)"
        success "Granted registry 'etv' added"
    fi
}

# ── phpenv + PHP ──────────────────────────────────────────────────────────────

install_phpenv() {
    log "Installing phpenv build dependencies..."
    apt_install \
        autoconf \
        pkg-config \
        libxml2-dev \
        libssl-dev \
        libsqlite3-dev \
        libbz2-dev \
        libcurl4-openssl-dev \
        libpng-dev \
        libjpeg-dev \
        libonig-dev \
        libreadline-dev \
        libtidy-dev \
        libxslt-dev \
        libzip-dev

    export PHPENV_ROOT="$HOME/.phpenv"

    if [[ ! -d "$PHPENV_ROOT" ]]; then
        log "Installing phpenv..."
        git clone git@github.com:phpenv/phpenv.git "$PHPENV_ROOT"
        success "phpenv cloned"
    else
        skip "phpenv"
    fi

    if [[ ! -d "$PHPENV_ROOT/plugins/php-build" ]]; then
        log "Installing php-build plugin..."
        git clone git@github.com:php-build/php-build.git "$PHPENV_ROOT/plugins/php-build"
        success "php-build installed"
    else
        skip "php-build"
    fi

    # Make phpenv available for the rest of this script
    export PATH="$PHPENV_ROOT/bin:$PHPENV_ROOT/shims:$PATH"
    eval "$(phpenv init -)"

    if phpenv versions | grep -q "$PHP_VERSION"; then
        skip "PHP $PHP_VERSION"
    else
        log "Installing PHP $PHP_VERSION (compiles from source — this will take a while)..."
        PHP_BUILD_CONFIGURE_OPTS="--with-openssl" phpenv install "$PHP_VERSION"
        phpenv global "$PHP_VERSION"
        success "PHP $PHP_VERSION installed and set as global"
    fi
}

# ── Docker ────────────────────────────────────────────────────────────────────

install_docker() {
    log "Installing Docker..."
    if command_exists docker; then
        skip "Docker ($(docker --version))"
    else
        local tmp_script
        tmp_script=$(mktemp)
        curl -fsSL https://get.docker.com -o "$tmp_script"
        sudo sh "$tmp_script"
        rm "$tmp_script"
        success "Docker installed: $(docker --version)"
    fi

    if ! docker compose version &>/dev/null 2>&1; then
        log "Installing Docker Compose plugin..."
        apt_install docker-compose-plugin
        success "Docker Compose installed: $(docker compose version)"
    else
        skip "Docker Compose ($(docker compose version))"
    fi

    if ! groups "$USER" | grep -qw 'docker'; then
        log "Adding $USER to the docker group..."
        sudo usermod -aG docker "$USER"
        success "User added to docker group (takes effect on next login)"
    else
        skip "User already in docker group"
    fi
}

# ── JetBrains Toolbox ─────────────────────────────────────────────────────────

install_jetbrains_toolbox() {
    log "Installing JetBrains Toolbox..."

    local install_dir="$HOME/.local/share/JetBrains/Toolbox/bin"

    if [[ -f "$install_dir/jetbrains-toolbox" ]]; then
        skip "JetBrains Toolbox"
        return
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local toolbox_url
    toolbox_url=$(curl -fsSL \
        "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
        | jq -r '.TBA[0].downloads.linux.link')
    curl -fsSL "$toolbox_url" -o "$tmp_dir/jetbrains-toolbox.tar.gz"
    tar -xzf "$tmp_dir/jetbrains-toolbox.tar.gz" -C "$tmp_dir"
    local extracted_dir
    extracted_dir=$(find "$tmp_dir" -maxdepth 1 -name 'jetbrains-toolbox-*' -type d | head -1)
    mkdir -p "$install_dir"
    cp "$extracted_dir/jetbrains-toolbox" "$install_dir/"
    chmod +x "$install_dir/jetbrains-toolbox"
    rm -rf "$tmp_dir"
    success "JetBrains Toolbox installed to $install_dir"
    warn "Run '$install_dir/jetbrains-toolbox' to complete first-time setup"
}

# ── win32yank (WSL ↔ Windows clipboard) ──────────────────────────────────────

install_win32yank() {
    log "Installing win32yank..."

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    if [[ -f "$bin_dir/win32yank.exe" ]]; then
        skip "win32yank"
        return
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local download_url
    download_url=$(curl -fsSL https://api.github.com/repos/equalsraf/win32yank/releases/latest \
        | jq -r '.assets[] | select(.name | test("win32yank-x64.zip")) | .browser_download_url')
    curl -fsSL "$download_url" -o "$tmp_dir/win32yank.zip"
    unzip -q "$tmp_dir/win32yank.zip" -d "$tmp_dir"
    cp "$tmp_dir/win32yank.exe" "$bin_dir/win32yank.exe"
    chmod +x "$bin_dir/win32yank.exe"
    rm -rf "$tmp_dir"
    success "win32yank installed to $bin_dir"
}

# ── Directories ───────────────────────────────────────────────────────────────

setup_directories() {
    log "Setting up work directory..."
    mkdir -p "$CODE_DIR"
    success "Work directory ready: $CODE_DIR"
}

# ── Dotfiles ──────────────────────────────────────────────────────────────────

install_dotfiles() {
    log "Installing dotfiles..."
    if [[ -d "$DOTFILES_DIR" ]]; then
        skip "Dotfiles (already at $DOTFILES_DIR)"
        return
    fi

    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    success "Dotfiles cloned to $DOTFILES_DIR"

    # Run a setup/install script if the dotfiles repo provides one
    for setup_script in "$DOTFILES_DIR/install.sh" "$DOTFILES_DIR/setup.sh"; do
        if [[ -f "$setup_script" ]]; then
            log "Running dotfiles setup: $setup_script"
            bash "$setup_script"
            success "Dotfiles setup complete"
            break
        fi
    done
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║      WSL2 Debian Bootstrap           ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${RESET}"

    prevent_snap
    system_update
    install_apt_packages
    install_zsh
    install_nvm
    install_copilot
    install_aws_cli
    install_aws_sam
    install_granted
    install_phpenv
    install_docker
    install_jetbrains_toolbox
    install_win32yank
    setup_directories
    install_dotfiles

    echo ""
    echo -e "${GREEN}${BOLD}Bootstrap complete! 🎉${RESET}"
    echo ""
    echo "Next steps:"
    echo "  • Log out and back in for docker group membership and zsh shell to take effect"
    echo "  • Run '$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox' to finish IDE setup"
    echo "  • Verify PHP: phpenv global ${PHP_VERSION} && php -v"
    echo ""
}

main "$@"
