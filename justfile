# Armold — robotic arm simulation (Sweep Dynamics)
#
# Every task in this project is a recipe here. Run `just` to see them all.
# On a brand-new machine, run ./bootstrap.sh once first.

set shell := ["bash", "-euc"]

export ROS_DISTRO_TARGET := "jazzy"

# Show all available commands
default:
    @just --list --unsorted

# ---------------------------------------------------------------- setup ----

# One-time system setup: installs ROS 2, sim packages, and tooling
setup:
    @./bootstrap.sh

# Install/refresh ROS dependencies declared in src/*/package.xml
deps:
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    if [ -z "$(find src -name package.xml -print -quit 2>/dev/null)" ]; then
        echo "no packages in src/ yet — nothing to resolve"
        exit 0
    fi
    rosdep install --from-paths src --ignore-src -y --rosdistro "$ROS_DISTRO"

# ---------------------------------------------------------------- build ----

# Build the whole workspace
build:
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    colcon build --symlink-install --event-handlers console_cohesion+

# Build a single package, e.g. `just build-pkg armold_description`
build-pkg pkg:
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    colcon build --symlink-install --packages-select {{pkg}} \
        --event-handlers console_cohesion+

# Remove all build artifacts
clean:
    rm -rf build install log
    @echo "cleaned: build/ install/ log/"

# Clean then build from scratch
rebuild: clean build

# ---------------------------------------------------------------- run ------

# Build and open the Armold simulation in RViz (gui=false hides the sliders)
run-simulation gui="true": build
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    #   just run-simulation             sliders on (default)
    #   just run-simulation gui=false   no slider window

    if ! ros2 pkg prefix armold_description >/dev/null 2>&1; then
        echo "armold_description is not on the ROS package path." >&2
        echo "Try: just rebuild" >&2
        exit 1
    fi

    # A stale RViz from a previous run keeps the old robot_description and makes
    # it look like an edit did nothing. Clear any leftovers before launching.
    # rviz2 and robot_state_publisher are C++ binaries, so -x matches them by
    # name; joint_state_publisher_gui is a python script, so its process name is
    # "python3" and only a full-cmdline match finds it. Matching cmdline is safe
    # here because just runs this recipe from a temp file, so the pattern text is
    # not in this script's own command line.
    for name in rviz2 robot_state_pub; do
        pkill -x "$name" 2>/dev/null || true
    done
    pkill -f joint_state_publisher_gui 2>/dev/null || true
    pkill -f "ros2 launch armold_description" 2>/dev/null || true
    sleep 1

    echo "launching Armold simulation (gui={{gui}}) — Ctrl-C to stop"
    exec ros2 launch armold_description display.launch.py gui:={{gui}}

# `just rviz` still works and does the same thing.
alias rviz := run-simulation

# Print the parsed URDF (catches xacro errors fast)
urdf:
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    xacro src/armold_description/urdf/armold.urdf.xacro

# Validate the URDF and show the link/joint tree
check-urdf:
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    xacro src/armold_description/urdf/armold.urdf.xacro > /tmp/armold.urdf
    check_urdf /tmp/armold.urdf

# Copy purchased meshes into the package, normalising names for package:// paths
import-meshes src="~/Downloads/Armold/Print-Ready Orientation":
    #!/usr/bin/env bash
    set -euo pipefail
    # Names are lowercased and spaces become underscores, because spaces in a
    # package:// URI break URDF parsing. Meshes stay git-ignored either way.
    SRC="{{src}}"
    DEST=src/armold_description/meshes/visual
    if [ ! -d "$SRC" ]; then echo "no such folder: $SRC" >&2; exit 1; fi
    shopt -s nullglob nocaseglob
    n=0
    for f in "$SRC"/*.stl; do
        base="$(basename "$f" .stl)"
        clean="$(echo "$base" | tr '[:upper:]' '[:lower:]' \
                 | sed 's/[^a-z0-9]\+/_/g; s/^_//; s/_$//').stl"
        cp -n "$f" "$DEST/$clean" && echo "  $base -> $clean" || true
        n=$((n+1))
    done
    echo "$n mesh file(s) in $SRC"

# ---------------------------------------------------------------- test -----

# Run the workspace test suite
test: build
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    colcon test --event-handlers console_direct+
    colcon test-result --verbose

# ---------------------------------------------------------------- info -----

# Verify this machine can build and render the sim
doctor:
    @./scripts/doctor.sh

# Show the active ROS environment
env:
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    echo "ROS_DISTRO      $ROS_DISTRO"
    echo "ROS_DOMAIN_ID   ${ROS_DOMAIN_ID:-0}"
    echo "RMW             ${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp (default)}"
    echo "workspace       $(pwd)"
    echo "packages        $(colcon list --names-only 2>/dev/null | tr '\n' ' ')"

# List the running ROS graph (nodes and topics)
graph:
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    echo "--- nodes ---";  ros2 node list  || true
    echo "--- topics ---"; ros2 topic list || true
