#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}Calla Desktop Environment — Dependency Installer${NC}"
echo ""

# ── Official repo packages ─────────────────────────────────────────────────────

PACMAN_REQUIRED=(
    xorg-server
    pipewire-pulse
    brightnessctl
    inotify-tools
    picom
    maim
    xclip
    papirus-icon-theme
    noto-fonts
    noto-fonts-cjk
    noto-fonts-extra
    playerctl
)

PACMAN_OPTIONAL=(
    nemo                      # File manager
    network-manager-applet    # Network tray applet (nm-applet)
    polkit-gnome              # Polkit authentication agent
    cbatticon                 # Battery tray icon
    blueman                   # Bluetooth manager
    xdg-user-dirs             # Generates standard home directories
)

# ── AUR packages ───────────────────────────────────────────────────────────────

AUR_REQUIRED=(
    awesome-git               # AwesomeWM (git build — required for latest API)
    noto-color-emoji-fontconfig  # Fontconfig rules for color emoji rendering
    lua-pam-git               # Lua PAM bindings (used for lockscreen auth)
)

AUR_OPTIONAL=(
    st                        # Simple terminal emulator
    vim-gtk3                  # Vim with GTK3/clipboard support
)

# ── AUR helper setup ───────────────────────────────────────────────────────────

AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
fi

if [ -z "$AUR_HELPER" ]; then
    echo -e "${YELLOW}No AUR helper found (yay/paru). Installing yay...${NC}"
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay-install
    (cd /tmp/yay-install && makepkg -si --noconfirm)
    rm -rf /tmp/yay-install
    AUR_HELPER="yay"
    echo -e "${GREEN}yay installed.${NC}"
    echo ""
fi

echo -e "${CYAN}Using AUR helper: ${BOLD}$AUR_HELPER${NC}"
echo ""

# ── Install required packages ──────────────────────────────────────────────────

echo -e "${BOLD}Installing required packages (official repos)...${NC}"
sudo pacman -S --needed --noconfirm "${PACMAN_REQUIRED[@]}"

echo ""
echo -e "${BOLD}Installing required packages (AUR)...${NC}"
$AUR_HELPER -S --needed --noconfirm "${AUR_REQUIRED[@]}"

# ── Optional packages ──────────────────────────────────────────────────────────

echo ""
echo -e "${YELLOW}Optional packages:${NC}"
echo "  Official repos: ${PACMAN_OPTIONAL[*]}"
echo "  AUR:            ${AUR_OPTIONAL[*]}"
echo ""
read -rp "Install optional packages? [y/N] " opt_answer

if [[ "$opt_answer" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BOLD}Installing optional packages (official repos)...${NC}"
    sudo pacman -S --needed --noconfirm "${PACMAN_OPTIONAL[@]}"

    echo ""
    echo -e "${BOLD}Installing optional packages (AUR)...${NC}"
    $AUR_HELPER -S --needed --noconfirm "${AUR_OPTIONAL[@]}"
else
    echo "Skipping optional packages."
fi

# ── Done ───────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}All dependencies installed successfully.${NC}"
echo -e "Install Calla with: ${CYAN}sudo pacman -U calla-*.pkg.tar.zst${NC}"
