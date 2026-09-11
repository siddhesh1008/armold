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

    # A stale RViz keeps the old robot_description and makes it look like an
    # edit did nothing, and a stale slider GUI fights over /joint_states.
    just stop

    echo "launching Armold simulation (gui={{gui}}) — Ctrl-C to stop"
    exec ros2 launch armold_description display.launch.py gui:={{gui}}

# `just rviz` still works and does the same thing.
alias rviz := run-simulation

# Stop every process the simulation starts (safe to run any time)
stop:
    #!/usr/bin/env bash
    set -uo pipefail
    # rviz2 and robot_state_publisher are C++ and exit on SIGTERM, so -x by name
    # is enough. joint_state_publisher_gui is Python sitting inside a Qt event
    # loop: the interpreter never gets scheduled to run rclpy's SIGTERM handler,
    # so it MATCHES pkill, reports success, and keeps running. Hence TERM first
    # for the well-behaved, then -9 for whatever ignored it.
    #
    # Matching on full command line is safe here only because just runs this
    # recipe from a temp file, so these patterns are not in this script's own
    # command line. The same pkill typed straight into a shell kills that shell.
    pkill -x rviz2 2>/dev/null || true
    pkill -x robot_state_pub 2>/dev/null || true
    pkill -f joint_state_publisher_gui 2>/dev/null || true
    pkill -f "ros2 launch armold_description" 2>/dev/null || true
    sleep 1
    pkill -9 -f joint_state_publisher_gui 2>/dev/null || true
    pkill -9 -f "ros2 launch armold_description" 2>/dev/null || true
    sleep 1
    # The ros2 CLI daemon caches the node graph and is itself a background
    # process. Without this, `ros2 node list` keeps reporting nodes whose
    # processes are long gone. It restarts automatically on the next ros2 call.
    ros2 daemon stop >/dev/null 2>&1 || true
    sleep 1

    # A SIGKILLed node never unmaps its Fast DDS shared memory, so /dev/shm fills
    # up with orphaned segments and a freshly started daemon re-discovers ghost
    # nodes from them. Remove only segments no live process still maps - fuser
    # returns non-zero when a file is unused - so any other ROS project running
    # on this machine is left strictly alone.
    for f in /dev/shm/fastrtps_* /dev/shm/sem.fastrtps_*; do
        [ -e "$f" ] || continue
        fuser -s "$f" 2>/dev/null || rm -f "$f"
    done
    left=$(pgrep -c -f "rviz2|joint_state_publisher_gui|robot_state_publisher" 2>/dev/null || true)
    echo "simulation stopped (${left:-0} related process(es) left)"

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
        # Parts whose file name covers two joints get one copy per joint, named
        # for that joint. The C-joint ships once but Armold uses it at J3 and at
        # J4, and a link called j3_j4_c_joint_2 is unreadable in a TF tree.
        case "$clean" in
            j3_j4_c_joint.stl)
                cp -n "$f" "$DEST/j3_c_joint.stl" && echo "  $base -> j3_c_joint.stl" || true
                cp -n "$f" "$DEST/j4_c_joint.stl" && echo "  $base -> j4_c_joint.stl" || true
                ;;
            j1_j5_mounting_bracket.stl)
                cp -n "$f" "$DEST/j1_mounting_bracket.stl" && echo "  $base -> j1_mounting_bracket.stl" || true
                cp -n "$f" "$DEST/j5_mounting_bracket.stl" && echo "  $base -> j5_mounting_bracket.stl" || true
                ;;
            *)
                cp -n "$f" "$DEST/$clean" && echo "  $base -> $clean" || true
                ;;
        esac
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
