#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script as root/sudo." >&2
  exit 1
fi

# Upgrading
sudo pacman -Syu --noconfirm --needed base-devel

# Install yay
if ! command -v yay &>/dev/null; then
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  pushd /tmp/yay
  makepkg -si --noconfirm
  popd
fi

# Install terminal apps
source ./install/terminal.sh

read -rp "Ready to reboot for all settings to take effect? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] && sudo reboot
