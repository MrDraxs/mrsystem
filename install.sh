#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# CHANGE THIS to the git repository that contains your config folders
# The repo must have this structure:
#
#   dwm/config.def.h
#   dmenu/config.def.h
#   st-sx/config.def.h
#
# Example:
#   CONFIG_REPO="https://github.com/yourusername/suckless-configs.git"
# ---------------------------------------------------------------------------
CONFIG_REPO="https://github.com/MrDraxs/mrsystem.git"

# Where sources will be placed
mkdir -p $HOME/.local/src/configs
SRC_DIR="${HOME}/.local/src"
CONFIG_DIR="${SRC_DIR}/configs"          # temporary clone of your config repo

# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[!]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] && error "Do not run as root."

# Detect distro
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
else
    error "Cannot detect distribution"
fi
info "Detected: $DISTRO_ID"

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
install_deps() {
    info "Installing dependencies..."

    case "$DISTRO_ID" in
        arch|manjaro|endeavouros|garuda)
            sudo pacman -Syu --needed --noconfirm \
                base-devel git \
                libx11 libxft libxinerama \
                imlib2 harfbuzz \
                xorg-server xorg-xinit
            ;;
        debian|ubuntu|linuxmint|pop|elementary|zorin|kali)
            sudo apt-get update
            sudo apt-get install -y \
                build-essential git \
                libx11-dev libxft-dev libxinerama-dev \
                libx11-xcb-dev libimlib2-dev libharfbuzz-dev libpcre2-dev \
                libfontconfig1-dev \
                xorg xinit
            ;;
        fedora|rhel|centos|rocky|almalinux)
            sudo dnf install -y \
                gcc make git \
                libX11-devel libXft-devel libXinerama-devel \
                imlib2-devel harfbuzz-devel pcre2-devel \
                fontconfig-devel \
                xorg-x11-server-Xorg xorg-x11-xinit
            ;;
        opensuse*|suse)
            sudo zypper refresh
            sudo zypper install -y \
                gcc make git \
                libX11-devel libXft-devel libXinerama-devel \
                imlib2-devel harfbuzz-devel \
                fontconfig-devel xorg-x11-server xinit
            ;;
        void)
            sudo xbps-install -Sy \
                base-devel git \
                libX11-devel libXft-devel libXinerama-devel \
                imlib2-devel harfbuzz-devel xorg
            ;;
        *)
            if [[ "$DISTRO_LIKE" == *"arch"* ]]; then
                sudo pacman -Syu --needed --noconfirm base-devel git libx11 libxft libxinerama imlib2 harfbuzz xorg-server xorg-xinit
            elif [[ "$DISTRO_LIKE" == *"debian"* || "$DISTRO_LIKE" == *"ubuntu"* ]]; then
                sudo apt-get update
                sudo apt-get install -y build-essential git libx11-dev libxft-dev libxinerama-dev \
                    libx11-xcb-dev libimlib2-dev libharfbuzz-dev libpcre2-dev libfontconfig1-dev xorg xinit
            elif [[ "$DISTRO_LIKE" == *"fedora"* || "$DISTRO_LIKE" == *"rhel"* ]]; then
                sudo dnf install -y gcc make git libX11-devel libXft-devel libXinerama-devel \
                    imlib2-devel harfbuzz-devel pcre2-devel fontconfig-devel xorg-x11-server-Xorg xorg-x11-xinit
            else
                error "Unsupported distro: $DISTRO_ID"
            fi
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Clone helper
# ---------------------------------------------------------------------------
clone_or_update() {
    local name="$1"
    local url="$2"
    local dir="$3"

    if [[ -d "$dir/.git" ]]; then
        info "Updating $name..."
        git -C "$dir" pull --ff-only || warn "Could not fast-forward $name"
    else
        info "Cloning $name..."
        git clone --depth 1 "$url" "$dir"
    fi
}

# ---------------------------------------------------------------------------
# Copy custom config.def.h → config.h
# ---------------------------------------------------------------------------
install_custom_config() {
    local name="$1"          # dwm | dmenu | st-sx
    local src="${CONFIG_DIR}/${name}/config.def.h"
    local dest="${SRC_DIR}/${name}/config.h"

    if [[ -f "$src" ]]; then
        info "Installing custom config for $name"
        cp "$src" "$dest"
    else
        warn "No custom config.def.h found for $name – using upstream default"
        if [[ -f "${SRC_DIR}/${name}/config.def.h" ]]; then
            cp "${SRC_DIR}/${name}/config.def.h" "$dest"
        else
            error "Missing config for $name"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Build & install
# ---------------------------------------------------------------------------
build_and_install() {
    local name="$1"
    local dir="${SRC_DIR}/${name}"

    info "Building $name..."
    cd "$dir"
    make clean
    make
    sudo make install
    cd "$SRC_DIR"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
install_deps

# 1. Clone official sources
clone_or_update "dwm"   "https://git.suckless.org/dwm"   "${SRC_DIR}/dwm"
clone_or_update "dmenu" "https://git.suckless.org/dmenu" "${SRC_DIR}/dmenu"
clone_or_update "st-sx" "https://github.com/veltza/st-sx.git" "${SRC_DIR}/st-sx"

# 2. Clone your config repository (contains the custom config.def.h files)
if [[ -z "$CONFIG_REPO" || "$CONFIG_REPO" == *"YOUR_USERNAME"* ]]; then
    error "Please set CONFIG_REPO at the top of the script to your config git repository"
fi
clone_or_update "configs" "$CONFIG_REPO" "$CONFIG_DIR"

# 3. Copy the config.def.h files into the source trees
install_custom_config "dwm"
install_custom_config "dmenu"
install_custom_config "st-sx"

# 4. Compile and install
build_and_install "dwm"
build_and_install "dmenu"
build_and_install "st-sx"

# Optional: copy any extra files from the config repo into ~/.config
mkdir -p "${HOME}/.config"
if [[ -d "${CONFIG_DIR}/.config" ]]; then
    info "Copying extra .config files..."
    cp -r "${CONFIG_DIR}/.config/"* "${HOME}/.config/" || true
fi

info "All done!"
echo
echo "Binaries  → /usr/local/bin/{dwm,dmenu,st}"
echo "Sources   → $SRC_DIR/{dwm,dmenu,st-sx}"
echo "Configs   → $CONFIG_DIR"
echo
echo "Add 'exec dwm' to ~/.xinitrc and run startx (or select dwm in your display manager)."
