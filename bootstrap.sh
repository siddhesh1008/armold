#!/usr/bin/env bash
#
# Armold — zero-to-running bootstrap (Sweep Dynamics)
#
# The ONLY script you run by hand on a fresh machine:
#     ./bootstrap.sh
#
# It installs everything the project needs (ROS 2 Jazzy, build tooling, and the
# `just` command runner). After it finishes, every other task is a `just` recipe:
#     just build
#     just rviz
#
# Safe to re-run: every step checks before it installs.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROS_DISTRO_TARGET="jazzy"
UBUNTU_TARGET="24.04"

# ---------- output helpers ----------
if [ -t 1 ]; then
    BOLD=$'\033[1m'; RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RST=$'\033[0m'
else
    BOLD=""; RED=""; GRN=""; YLW=""; RST=""
fi
step() { printf "\n${BOLD}==> %s${RST}\n" "$*"; }
ok()   { printf "  ${GRN}OK${RST}    %s\n" "$*"; }
skip() { printf "  ${GRN}have${RST}  %s\n" "$*"; }
warn() { printf "  ${YLW}warn${RST}  %s\n" "$*"; }
die()  { printf "  ${RED}FAIL${RST}  %s\n" "$*" >&2; exit 1; }

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "^install ok installed$"
}

need_sudo() {
    if ! sudo -n true 2>/dev/null; then
        printf "  %s\n" "sudo password required for package installation"
    fi
}

# ---------- 0. sanity ----------
step "Checking host"
[ -f /etc/os-release ] || die "not a Linux system with /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
ok "$PRETTY_NAME ($(uname -m))"
if [ "${VERSION_ID:-}" != "$UBUNTU_TARGET" ]; then
    warn "expected Ubuntu $UBUNTU_TARGET for ROS 2 $ROS_DISTRO_TARGET; found ${VERSION_ID:-unknown}"
    warn "continuing, but package availability is not guaranteed"
fi

# ---------- 1. base tooling ----------
step "Base tooling"
APT_BASE=(curl gnupg lsb-release ca-certificates software-properties-common
          build-essential cmake git python3-pip)
MISSING=()
for p in "${APT_BASE[@]}"; do
    pkg_installed "$p" || MISSING+=("$p")
done
if [ ${#MISSING[@]} -gt 0 ]; then
    need_sudo
    sudo apt-get update -qq
    sudo apt-get install -y "${MISSING[@]}"
    ok "installed: ${MISSING[*]}"
else
    skip "base tooling already present"
fi

# ---------- 2. ROS 2 ----------
step "ROS 2 $ROS_DISTRO_TARGET"
if [ -d "/opt/ros/$ROS_DISTRO_TARGET" ]; then
    skip "/opt/ros/$ROS_DISTRO_TARGET"
else
    warn "ROS 2 $ROS_DISTRO_TARGET not found — adding the OSRF apt repository"
    need_sudo
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/ros-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y "ros-${ROS_DISTRO_TARGET}-desktop"
    ok "installed ros-${ROS_DISTRO_TARGET}-desktop"
fi

# ---------- 3. ROS build/sim packages ----------
step "ROS packages for the Armold sim"
ROS_PKGS=(
    "ros-${ROS_DISTRO_TARGET}-rviz2"
    "ros-${ROS_DISTRO_TARGET}-robot-state-publisher"
    "ros-${ROS_DISTRO_TARGET}-joint-state-publisher"
    "ros-${ROS_DISTRO_TARGET}-joint-state-publisher-gui"
    "ros-${ROS_DISTRO_TARGET}-xacro"
    "ros-${ROS_DISTRO_TARGET}-urdf"
    "ros-${ROS_DISTRO_TARGET}-ros2-control"
    "ros-${ROS_DISTRO_TARGET}-ros2-controllers"
    python3-colcon-common-extensions
    python3-rosdep
    python3-vcstool
)
MISSING=()
for p in "${ROS_PKGS[@]}"; do
    pkg_installed "$p" || MISSING+=("$p")
done
if [ ${#MISSING[@]} -gt 0 ]; then
    need_sudo
    sudo apt-get install -y "${MISSING[@]}"
    ok "installed ${#MISSING[@]} package(s)"
else
    skip "all sim packages present"
fi

# ---------- 4. just ----------
step "just (command runner)"
if command -v just >/dev/null 2>&1; then
    skip "just $(just --version | awk '{print $2}')"
else
    need_sudo
    sudo apt-get install -y just
    ok "just $(just --version | awk '{print $2}')"
fi

# ---------- 5. direnv ----------
step "direnv (automatic environment loading)"
if command -v direnv >/dev/null 2>&1; then
    skip "direnv $(direnv version)"
else
    need_sudo
    sudo apt-get install -y direnv
    ok "direnv $(direnv version)"
fi

# The shell hook must sit at the end of the rc file, after anything else that
# touches PROMPT_COMMAND. Guarded by command -v so the rc file stays valid even
# if direnv is later removed.
HOOK_MARK="# direnv hook (added by armold bootstrap)"
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$RC" ] || continue
    case "$RC" in
        *.bashrc) SHELL_NAME=bash ;;
        *.zshrc)  SHELL_NAME=zsh  ;;
        *)        continue ;;
    esac
    if grep -qF "$HOOK_MARK" "$RC"; then
        skip "hook already in $(basename "$RC")"
    else
        {
            printf '\n%s\n' "$HOOK_MARK"
            printf '%s\n' '# VS Code ships as a snap and exports XDG_DATA_HOME into /snap/code/<rev>/...,'
            printf '%s\n' '# which is where direnv stores its .envrc approvals. That path changes on every'
            printf '%s\n' '# snap update, silently revoking them. Restore the real one.'
            printf '%s\n' 'case "${XDG_DATA_HOME:-}" in'
            printf '%s\n' '    */snap/*) export XDG_DATA_HOME="$HOME/.local/share" ;;'
            printf '%s\n' 'esac'
            printf 'command -v direnv >/dev/null 2>&1 && eval "$(direnv hook %s)"\n' "$SHELL_NAME"
        } >> "$RC"
        ok "hook added to $(basename "$RC")"
    fi
done

# Trust this workspace's .envrc (direnv refuses to load an unapproved one)
if [ -f "$REPO_DIR/.envrc" ]; then
    ( cd "$REPO_DIR" \
        && XDG_DATA_HOME="$HOME/.local/share" direnv allow . ) \
        && ok "direnv allow $REPO_DIR"
fi

# ---------- 6. rosdep ----------
step "rosdep"
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    need_sudo
    sudo rosdep init
    ok "rosdep initialized"
else
    skip "rosdep already initialized"
fi
rosdep update --rosdistro "$ROS_DISTRO_TARGET" 2>/dev/null | tail -1 || \
    warn "rosdep update failed (offline?) — retry later with: rosdep update"

# resolve declared dependencies of any packages already in src/
if [ -n "$(find "$REPO_DIR/src" -name package.xml -print -quit 2>/dev/null)" ]; then
    need_sudo
    # shellcheck disable=SC1090
    source "/opt/ros/$ROS_DISTRO_TARGET/setup.bash"
    rosdep install --from-paths "$REPO_DIR/src" --ignore-src -y \
        --rosdistro "$ROS_DISTRO_TARGET" && ok "workspace dependencies resolved"
else
    skip "no packages in src/ yet — nothing to resolve"
fi

# ---------- done ----------
printf "\n${BOLD}${GRN}Bootstrap complete.${RST}\n\n"
printf "  Next:\n"
printf "    just doctor    # verify this machine can render the sim\n"
printf "    just build     # build the workspace\n"
printf "    just rviz      # launch RViz\n\n"
