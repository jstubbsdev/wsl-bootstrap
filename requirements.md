# wsl-bootstrap requirements

My laptop runs Windows, with WSL2 (Debian). I want to create a "bootstrap" shell
(bash) script that I can run from a fresh WSL Debian install in case I need to
rebuild the WSL image.

High level requirements:

- Single bash (.sh) script 
- Install all the software I use (ideally via apt)
- Install my dotfiles (hosted on github)
- Be idempotent - if I run the installation script multiple times, it should
  only make changes if they haven't already been made
- Ideally be _one of_ the first things to run (i.e. not require many previous
  steps to run before it can be used)
- Be non-interactive. I just want to run it and have it do its thing.
- The script should follow best practices, and be easily maintainable by a human

I will be checking this directory into version control (GitHub), so I will clone
it and run it on the new WSL image. To that end, you can assume I will have set
up my GitHub ssh key.

All Git repositories are hosted on github.com.
When checking out with Git, please use ssh, not https.

Please ensure snap is at no point ever installed on this distro.

Before installing any software, please perform an `apt update` and `apt upgrade`
to ensure the latest versions of packages are installed.

## List of software

Where not specified, use apt install.

- curl
- jq
- zsh
  - set as default login shell
  - also include oh-my-zsh
- htop
- nvm (with latest active npm)
- copilot (via npm global - @github/copilot)
- aws cli (official installer - curl + zip + install)
- aws sam (official installer - GitHub release binary)
- granted cli (see instructions in Granted CLI section below)
- phpenv
- docker
  - add user to docker group so that it can be run without sudo
- docker compose (if not already included with docker)
- xinit
- gpg
- Jetbrains Toolbox
- make
- python3 (also include)
  - python3-pip
  - python3-venv
  - python3-setuptools
- libkrb5-dev
- libssh-dev
- bzip2 (required for building PHP)
- build-essential (required for building PHP)

## Directories

My work goes in `~/Work/` (CODE_DIR). All repository clones should go in there.

## Dotfiles

My dotfiles are here: /github.com/jstubbsdev/dotfiles.

The repository should be cloned into the home directory

## Clipboard integration (WSL ↔ Windows)

Download `win32yank.exe` from its GitHub releases
(https://github.com/equalsraf/win32yank) and place it on PATH (e.g.
`~/.local/bin/`). Neovim auto-detects win32yank and uses it as the clipboard
provider.

## Granted CLI

From: https://docs.commonfate.io/granted/getting-started#installing-the-cli

```
# install GPG
sudo apt update && sudo apt install gpg

# download the Common Fate Linux GPG key
wget -O- https://apt.releases.commonfate.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/common-fate-linux.gpg

# you can check the fingerprint of the key by running
# gpg --no-default-keyring --keyring /usr/share/keyrings/common-fate-linux.gpg --fingerprint
# the fingerprint of our Linux Releases key is 783A 4D1A 3057 4D2A BED0 49DD DE9D 631D 2D1D C944

# add the Common Fate APT repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/common-fate-linux.gpg] https://apt.releases.commonfate.io stable main" | sudo tee /etc/apt/sources.list.d/common-fate.list

# update your repositories
sudo apt update

# install Granted
sudo apt install granted
```

Verify with `granted -v`

### Add the registry

```
granted registry add \
  -n etv \
  -p users/james.stubbs@everyonetv.co.uk  \
  -u git@github.com:everyonetv/granted-registry.git
```

## phpenv

Install `phpenv` from https://github.com/phpenv/phpenv

Install required libraries for first PHP version:

```shell
sudo apt install autoconf \
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
```

Reference PHP version in https://github.com/fvp-mds/fvp-b2c-api/blob/master/build/images/b2c-base/Dockerfile#L1

Use referenced PHP version as first install:

```shell
phpenv install <version>
```

Verify installation:

```shell
$ phpenv global <version>
$ phpenv versions
* <version> (set by /home/etv/.phpenv/version)

$ php -v
PHP <version> (cli)
```

# JetBrains Toolbox

Navigate to https://www.jetbrains.com/toolbox-app/, download and install using
their instructions.
