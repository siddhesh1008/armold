#!/usr/bin/env bash
#
# Armold — system readiness check.
# Verifies this machine can build and render the sim. Read-only; changes nothing.
# Exit 0 = ready, 1 = blocking problem found.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROS_DISTRO_TARGET="jazzy"

# capture before setup_env.sh scrubs it, so the snap check below sees the truth
ORIG_GTK_PATH="${GTK_PATH:-}"

if [ -t 1 ]; then
    BOLD=$'\033[1m'; RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RST=$'\033[0m'
else
    BOLD=""; RED=""; GRN=""; YLW=""; RST=""
fi

FAILED=0
WARNED=0
pass() { printf "  ${GRN}pass${RST}  %-22s %s\n" "$1" "${2:-}"; }
fail() { printf "  ${RED}FAIL${RST}  %-22s %s\n" "$1" "${2:-}"; FAILED=$((FAILED+1)); }
warn() { printf "  ${YLW}warn${RST}  %-22s %s\n" "$1" "${2:-}"; WARNED=$((WARNED+1)); }
head_() { printf "\n${BOLD}%s${RST}\n" "$1"; }

printf "${BOLD}Armold system check${RST}\n"

# ---------- host ----------
head_ "Host"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "${VERSION_ID:-}" = "24.04" ]; then
        pass "os" "$PRETTY_NAME"
    else
        warn "os" "${PRETTY_NAME:-unknown} (ROS 2 $ROS_DISTRO_TARGET targets Ubuntu 24.04)"
    fi
else
    fail "os" "cannot identify distribution"
fi
pass "cpu" "$(nproc) cores"
pass "memory" "$(free -h | awk '/^Mem:/{printf "%s available of %s", $7, $2}')"
DISK_FREE=$(df -BG --output=avail "$REPO_DIR" | tail -1 | tr -d ' G')
if [ "${DISK_FREE:-0}" -lt 10 ]; then
    warn "disk" "${DISK_FREE}G free — builds may fail"
else
    pass "disk" "${DISK_FREE}G free"
fi

# ---------- ROS ----------
head_ "ROS 2"
if [ -d "/opt/ros/$ROS_DISTRO_TARGET" ]; then
    pass "install" "/opt/ros/$ROS_DISTRO_TARGET"
    # shellcheck disable=SC1091
    source "$REPO_DIR/setup_env.sh"
else
    fail "install" "/opt/ros/$ROS_DISTRO_TARGET missing — run ./bootstrap.sh"
    printf "\n${RED}Cannot continue without ROS 2.${RST}\n"
    exit 1
fi

for pkg in rviz2 robot_state_publisher joint_state_publisher_gui xacro urdf \
           ros2_control ros2_controllers; do
    if [ -d "/opt/ros/$ROS_DISTRO_TARGET/share/$pkg" ]; then
        pass "$pkg"
    else
        fail "$pkg" "missing — run ./bootstrap.sh"
    fi
done

# ---------- build tooling ----------
head_ "Build tooling"
for tool in colcon rosdep cmake g++ python3 git; do
    if command -v "$tool" >/dev/null 2>&1; then
        pass "$tool" "$(command -v "$tool")"
    else
        fail "$tool" "not found — run ./bootstrap.sh"
    fi
done
if [ -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    pass "rosdep sources"
else
    fail "rosdep sources" "not initialized — run: sudo rosdep init && rosdep update"
fi

# ---------- graphics ----------
head_ "Graphics"
printf "  %-6s %-22s %s\n" "" "session" "${XDG_SESSION_TYPE:-unknown} (DISPLAY=${DISPLAY:-unset})"
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    fail "display" "no DISPLAY or WAYLAND_DISPLAY — RViz needs a graphical session"
else
    pass "display" "available"
fi

# The snap-GTK trap: VS Code's snap exports GTK_PATH into /snap, whose GTK module
# has a RUNPATH into /snap/core20. That resolves libpthread against glibc 2.31
# instead of the system glibc, and rviz2 dies at startup. setup_env.sh clears it.
if [[ "$ORIG_GTK_PATH" == *"/snap/"* ]]; then
    warn "snap GTK_PATH" "detected — always launch via setup_env.sh / just recipes"
else
    pass "snap GTK_PATH" "clean"
fi

# ---------- live render test ----------
head_ "RViz render test"
if command -v rviz2 >/dev/null 2>&1; then
    RVIZ_LOG=$(mktemp)
    ( unset GTK_PATH GTK_EXE_PREFIX GDK_PIXBUF_MODULE_FILE GDK_PIXBUF_MODULEDIR \
            GSETTINGS_SCHEMA_DIR GIO_MODULE_DIR
      timeout 12 rviz2 ) > "$RVIZ_LOG" 2>&1
    RC=$?
    GL_LINE=$(grep -o "OpenGl version: .*" "$RVIZ_LOG" | head -1)
    if [ "$RC" -eq 124 ] && [ -n "$GL_LINE" ]; then
        pass "rviz2 launch" "$GL_LINE"
    elif [ "$RC" -eq 124 ]; then
        warn "rviz2 launch" "started but reported no OpenGL version"
    else
        fail "rviz2 launch" "exited $RC — see below"
        sed 's/^/        /' "$RVIZ_LOG" | tail -6
    fi
    rm -f "$RVIZ_LOG"
else
    fail "rviz2 launch" "rviz2 not on PATH"
fi

# ---------- summary ----------
printf "\n"
if [ "$FAILED" -gt 0 ]; then
    printf "${RED}${BOLD}%d check(s) failed${RST}"  "$FAILED"
    [ "$WARNED" -gt 0 ] && printf ", %d warning(s)" "$WARNED"
    printf " — run ./bootstrap.sh\n\n"
    exit 1
fi
printf "${GRN}${BOLD}System ready.${RST}"
[ "$WARNED" -gt 0 ] && printf " %d warning(s) above." "$WARNED"
printf "\n\n"
