#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script as root/sudo." >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot detect the operating system." >&2
  exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This bootstrap is intended for Ubuntu WSL. Detected: ${PRETTY_NAME:-unknown}." >&2
  exit 1
fi

case "${VERSION_ID:-}" in
  24.04 | 26.04) ;;
  *)
    echo "Warning: this bootstrap targets Ubuntu 24.04/26.04 LTS. Detected: ${PRETTY_NAME:-unknown}." >&2
    ;;
esac

is_wsl() {
  grep -qiE "(microsoft|wsl)" /proc/version /proc/sys/kernel/osrelease 2>/dev/null
}

enable_wsl_systemd() {
  if ! is_wsl; then
    return
  fi

  if [[ "$(cat /proc/1/comm 2>/dev/null)" == "systemd" ]]; then
    return
  fi

  local tmp
  tmp="$(mktemp)"

  if [[ -f /etc/wsl.conf ]]; then
    sudo awk '
      BEGIN { in_boot = 0; saw_boot = 0; saw_systemd = 0 }
      /^[[:space:]]*\[boot\][[:space:]]*$/ {
        if (in_boot && !saw_systemd) print "systemd=true"
        in_boot = 1
        saw_boot = 1
        saw_systemd = 0
        print
        next
      }
      /^[[:space:]]*\[/ {
        if (in_boot && !saw_systemd) print "systemd=true"
        in_boot = 0
      }
      in_boot && /^[[:space:]]*systemd[[:space:]]*=/ {
        print "systemd=true"
        saw_systemd = 1
        next
      }
      { print }
      END {
        if (in_boot && !saw_systemd) print "systemd=true"
        if (!saw_boot) {
          print ""
          print "[boot]"
          print "systemd=true"
        }
      }
    ' /etc/wsl.conf >"$tmp"
  else
    printf '[boot]\nsystemd=true\n' >"$tmp"
  fi

  sudo install -m 0644 "$tmp" /etc/wsl.conf
  rm -f "$tmp"
  WSL_SYSTEMD_WAS_CONFIGURED=1
}

WSL_SYSTEMD_WAS_CONFIGURED=0
enable_wsl_systemd

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  file \
  git \
  gnupg \
  gzip \
  lsb-release \
  procps \
  software-properties-common \
  sudo \
  tar \
  unzip \
  wget

sudo add-apt-repository -y universe

# Install terminal apps
source ./install/terminal.sh

cat <<'EOF'

Initial installation finished.

Next steps:
1. From Windows, run: wsl --shutdown
2. Start this Ubuntu distro again.
3. Run: ./post-install.sh
EOF

if [[ "$WSL_SYSTEMD_WAS_CONFIGURED" -eq 1 ]]; then
  cat <<'EOF'

systemd was enabled in /etc/wsl.conf during this run, so the WSL shutdown step is required before Docker can be started.
EOF
fi
