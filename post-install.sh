#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script as root/sudo." >&2
  exit 1
fi

require_command() {
  local name="$1"

  if ! command -v "$name" &>/dev/null; then
    echo "Missing required command: $name. Run ./init.sh first." >&2
    exit 1
  fi
}

ensure_systemd() {
  if [[ "$(cat /proc/1/comm 2>/dev/null)" != "systemd" ]]; then
    cat >&2 <<'EOF'
systemd is not active.

If this is Ubuntu WSL, run this from Windows:
  wsl --shutdown

Then start the distro again and rerun ./post-install.sh.
EOF
    exit 1
  fi
}

ensure_docker() {
  sudo groupadd -f docker
  sudo usermod -aG docker "$USER"
  sudo systemctl enable --now docker

  if ! docker info &>/dev/null; then
    cat >&2 <<'EOF'
Docker is running, but this user session cannot access it yet.

Exit Ubuntu WSL, run this from Windows:
  wsl --shutdown

Then start the distro again and rerun ./post-install.sh.
EOF
    exit 1
  fi
}

ensure_container() {
  local name="$1"
  shift

  if docker ps -a --format '{{.Names}}' | grep -Fxq "$name"; then
    docker start "$name" >/dev/null
  else
    docker run -d --restart unless-stopped --name "$name" "$@"
  fi
}

setup_storage() {
  local redis_name="redis7"
  local pg_name="postgres17"

  ensure_container "$redis_name" -p "6379:6379" redis:7
  ensure_container "$pg_name" -p "5432:5432" -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17
}

setup_dotfiles() {
  if ! op account get &>/dev/null; then
    echo "Please sign in to the 1Password CLI first: op signin" >&2
    exit 1
  fi

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

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
  rm -rf "$HOME/.config/nvim"
  stow nvim
  stow ssh
  stow starship
  stow tmux
  rm -f "$HOME/.zshrc"
  stow zsh
  stow skills
  stow claude
}

require_command docker
require_command git
require_command git-crypt
require_command op
require_command stow

ensure_systemd
ensure_docker
setup_storage
setup_dotfiles
