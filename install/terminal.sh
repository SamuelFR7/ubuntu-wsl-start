#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

install_vendor_repositories() {
  sudo install -m 0755 -d /etc/apt/keyrings

  # Docker Engine
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  # GitHub CLI
  sudo curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  # 1Password CLI
  curl -sS https://downloads.1password.com/linux/keys/1password.asc |
    sudo gpg --batch --yes --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
    sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol |
    sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc |
    sudo gpg --batch --yes --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

  # Doppler CLI
  curl -sLf --retry 3 --tlsv1.2 --proto "=https" https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key |
    sudo gpg --batch --yes --dearmor --output /usr/share/keyrings/doppler-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" |
    sudo tee /etc/apt/sources.list.d/doppler-cli.list >/dev/null

  # Mise
  curl -fSs https://mise.en.dev/gpg-key.pub |
    sudo tee /etc/apt/keyrings/mise-archive-keyring.asc >/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.en.dev/deb stable main" |
    sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
}

install_apt_packages() {
  local packages=(
    1password-cli
    bat
    btop
    build-essential
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
    doppler
    eza
    fd-find
    fzf
    gh
    git-crypt
    jq
    less
    mise
    neovim
    nodejs
    npm
    openjdk-17-jdk
    openjdk-21-jdk
    openssh-client
    php-cli
    php-fpm
    php-gd
    postgresql-client
    ripgrep
    stow
    tmux
    zsh
  )

  sudo apt-get update

  if apt-cache show lazygit &>/dev/null; then
    packages+=(lazygit)
  fi

  sudo apt-get install -y "${packages[@]}"
}

install_rustup() {
  if ! command -v rustup &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi

  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env"
  fi
}

install_dust() {
  if command -v dust &>/dev/null; then
    return
  fi

  cargo install du-dust
}

install_starship() {
  if command -v starship &>/dev/null; then
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  curl -fsSL https://starship.rs/install.sh -o "$tmp_dir/install-starship.sh"
  sudo sh "$tmp_dir/install-starship.sh" --yes --bin-dir /usr/local/bin
  rm -rf "$tmp_dir"
}

install_lazygit() {
  local arch release_json asset_url tmp_dir

  if command -v lazygit &>/dev/null; then
    return
  fi

  case "$(dpkg --print-architecture)" in
    amd64) arch="x86_64" ;;
    arm64) arch="arm64" ;;
    *)
      echo "lazygit is essential but has no configured binary mapping for architecture: $(dpkg --print-architecture)" >&2
      return 1
      ;;
  esac

  release_json="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest)"
  asset_url="$(
    jq -r --arg arch "$arch" '.assets[] | select(.name | test("linux_" + $arch + "\\.tar\\.gz$"; "i")) | .browser_download_url' <<<"$release_json" |
      head -n 1
  )"

  if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
    echo "Could not find a lazygit Linux $arch release asset." >&2
    return 1
  fi

  tmp_dir="$(mktemp -d)"
  curl -fsSL "$asset_url" -o "$tmp_dir/lazygit.tar.gz"
  tar -xzf "$tmp_dir/lazygit.tar.gz" -C "$tmp_dir"
  sudo install -m 0755 "$tmp_dir/lazygit" /usr/local/bin/lazygit
  rm -rf "$tmp_dir"
}

install_fastfetch() {
  if command -v fastfetch &>/dev/null; then
    return
  fi

  local arch release_json asset_url tmp_dir

  case "$(dpkg --print-architecture)" in
    amd64) arch="amd64" ;;
    arm64) arch="aarch64" ;;
    *)
      echo "fastfetch not installed: no configured official release asset for architecture $(dpkg --print-architecture)." >&2
      return
      ;;
  esac

  release_json="$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest)"
  asset_url="$(
    jq -r --arg asset "fastfetch-linux-${arch}.deb" '.assets[] | select(.name == $asset) | .browser_download_url' <<<"$release_json" |
      head -n 1
  )"

  if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
    echo "fastfetch not installed: no official GitHub .deb asset found for Linux $arch." >&2
    return
  fi

  tmp_dir="$(mktemp -d)"
  curl -fsSL "$asset_url" -o "$tmp_dir/fastfetch.deb"
  sudo apt-get install -y "$tmp_dir/fastfetch.deb"
  rm -rf "$tmp_dir"
}

install_homebrew() {
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
  fi

  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
      eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    fi
  fi

  if ! command -v brew &>/dev/null; then
    echo "Homebrew installation finished, but brew is not available on PATH." >&2
    return 1
  fi

  cat <<'EOF' | sudo tee /etc/profile.d/homebrew.sh >/dev/null
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
EOF

  brew list watchman &>/dev/null || brew install watchman
}

configure_java() {
  local java21_dir
  java21_dir="$(find /usr/lib/jvm -maxdepth 1 -type d -name 'java-21-openjdk-*' | head -n 1)"

  if [[ -n "$java21_dir" && -x "$java21_dir/bin/java" ]]; then
    sudo update-alternatives --set java "$java21_dir/bin/java"
    sudo update-alternatives --set javac "$java21_dir/bin/javac"
  fi
}

configure_command_aliases() {
  mkdir -p "$HOME/.local/bin"

  if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi

  if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
}

configure_tmux() {
  [[ -d "$HOME/.tmux/plugins/tpm" ]] || git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
}

configure_docker_group() {
  sudo groupadd -f docker
  sudo usermod -aG docker "$USER"
}

configure_shell() {
  sudo usermod --shell "$(command -v zsh)" "$USER"
}

configure_mise_and_codex() {
  export PATH="$HOME/.local/share/mise/shims:$PATH"

  mise settings add idiomatic_version_file_enable_tools node || true
  mise settings add idiomatic_version_file_enable_tools python || true
  mise use -g node@lts
  mise exec node@lts -- npm install -g @openai/codex
  mise reshim node || true
}

install_vendor_repositories
install_apt_packages
install_rustup
install_dust
install_starship
install_lazygit
install_fastfetch
install_homebrew
configure_java
configure_command_aliases
configure_tmux
configure_docker_group
configure_shell
configure_mise_and_codex

# Not installed:
# - ffmpegthumbnailer, libnotify, wl-clipboard: skipped because this WSL bootstrap avoids desktop-adjacent tools.
# - postgresql server: skipped to avoid a local service competing with the Docker postgres17 container; postgresql-client is installed.
# - snap packages: intentionally unsupported by this bootstrap.
