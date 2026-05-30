#!/usr/bin/env bash
set -euo pipefail

# Setup Storages
redisName="redis7"

# Redis
[[ $(docker ps -a -f "name=$redisName" --format '{{.Names}}') == $redisName ]] ||
  docker run -d --restart unless-stopped -p "6379:6379" --name "$redisName" redis:7

pgName="postgres17"

# Postgres
[[ $(docker ps -a -f "name=$pgName" --format '{{.Names}}') == $pgName ]] ||
  docker run -d --restart unless-stopped -p "5432:5432" --name "$pgName" -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17

if ! op account get &>/dev/null; then
  echo "Por favor, faça login no 1Password CLI primeiro: op signin"
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Setup Configs
op document get "i3rjiohtbjyrqznaon4oia4el4" --out-file "$HOME/.ssh/dotfiles-key"
chmod 600 "$HOME/.ssh/dotfiles-key"

op item get "fe53jvhvfhdpiz65cpufmwvvqy" --fields private_key --reveal | sed '1d;$d' >"$HOME/.ssh/id_ed25519"
op item get "fe53jvhvfhdpiz65cpufmwvvqy" --fields public_key >"$HOME/.ssh/id_ed25519.pub"
chmod 600 "$HOME/.ssh/id_ed25519"
chmod 644 "$HOME/.ssh/id_ed25519.pub"

cd "$HOME"
[[ -d "$HOME/dotfiles" ]] || git clone git@github.com:SamuelFR7/new_dotfiles.git dotfiles
cd "$HOME/dotfiles"
git-crypt unlock "$HOME/.ssh/dotfiles-key"
rm -rf "$HOME/.config/btop"
stow btop
stow scripts
rm -rf "$HOME/.config/git"
stow git
rm -rf "$HOME/.config/ghostty"
stow ghostty
rm -rf "$HOME/.config/nvim"
stow nvim
stow ssh
stow starship
stow tmux
rm -f "$HOME/.zshrc"
stow zsh
rm -rf "$HOME/.config/hypr"
stow skills
stow claude

cd -