#!/usr/bin/env bash
# Armold sim environment — Sweep Dynamics
#
# Source this before running any ROS command:
#     source ./setup_env.sh
# The `just` recipes do it for you.
#
# Two jobs:
#
# 1. Undo snap contamination. VS Code ships as a snap and exports GTK_PATH
#    pointing into /snap/code/<rev>/usr/lib/x86_64-linux-gnu/gtk-3.0. A GTK
#    module there carries a RUNPATH into /snap/core20, so the dynamic loader
#    resolves libpthread.so.0 against core20's glibc 2.31 instead of the system
#    glibc 2.39, and rviz2 dies at startup with:
#        symbol lookup error: undefined symbol: __libc_pthread_init
#    Clearing these variables restores normal library resolution.
#
# 2. Source ROS 2 and the workspace overlay with `set -u` suspended — ROS's own
#    setup.bash reads unbound variables (AMENT_TRACE_SETUP_FILES) and would
#    abort any caller running under `set -euo pipefail`.

unset GTK_PATH GTK_EXE_PREFIX GDK_PIXBUF_MODULE_FILE GDK_PIXBUF_MODULEDIR \
      GSETTINGS_SCHEMA_DIR GIO_MODULE_DIR

_armold_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_armold_distro="${ROS_DISTRO_TARGET:-jazzy}"

# remember whether the caller had `set -u`, then suspend it
_armold_had_u=0
case "$-" in *u*) _armold_had_u=1 ;; esac
set +u

# shellcheck disable=SC1090
source "/opt/ros/${_armold_distro}/setup.bash"

# overlay this workspace if it has been built
if [ -f "${_armold_dir}/install/setup.bash" ]; then
    # shellcheck disable=SC1091
    source "${_armold_dir}/install/setup.bash"
fi

if [ "$_armold_had_u" = 1 ]; then
    set -u
fi

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"

unset _armold_dir _armold_distro _armold_had_u
