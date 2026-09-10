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

# Launch RViz with the Armold model and joint sliders
rviz: build
    #!/usr/bin/env bash
    set -euo pipefail
    source ./setup_env.sh
    if ros2 pkg prefix armold_description >/dev/null 2>&1; then
        ros2 launch armold_description display.launch.py
    else
        echo "armold_description not built yet — opening a bare RViz session."
        rviz2
    fi

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
