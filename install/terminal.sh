# Terminal tools/apps
yay -S --needed --noconfirm \
  btop \
  jq \
  cargo \
  docker \
  docker-compose \
  ffmpegthumbnailer \
  doppler-cli-bin \
  fastfetch \
  git-crypt \
  github-cli \
  lazygit \
  less \
  libnotify \
  mise \
  neovim \
  node \
  npm \
  1password-cli \
  postgresql \
  php82 \
  php82-fpm \
  php82-gd \
  starship \
  stow \
  tmux \
  dust \
  eza \
  bat \
  fzf \
  wl-clipboard \
  ripgrep \
  fd \
  jdk17-openjdk \
  jdk21-openjdk \
  watchman-bin \
  zsh

# Java Setup
sudo archlinux-java set java-21-openjdk

## Tmux TPM
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

## Docker enable
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER
sudo systemctl enable --now docker

## Change shell to zsh
sudo usermod --shell /bin/zsh "$USER"

# Codex CLI
sudo npm i -g @openai/codex

# Mise Config
mise settings add idiomatic_version_file_enable_tools node
mise settings add idiomatic_version_file_enable_tools python
mise use -g node@lts

yay -S --needed --noconfirm \
  openssh