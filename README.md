# Armold

Simulation for the **Armold** robotic arm by Sweep Dynamics. ROS 2 Jazzy, visualized in RViz.

## Setting up a new machine

```bash
git clone <repo> ~/armold && cd ~/armold
./bootstrap.sh      # installs ROS 2 Jazzy, sim packages, and `just`
just doctor         # confirm the machine can build and render
just build
just rviz
```

`bootstrap.sh` is the only script you run by hand, and only once per machine.
Everything after that is a `just` recipe. Both are safe to re-run.

## Commands

Run `just` on its own to list everything.

| Command | What it does |
|---|---|
| `just setup` | One-time system setup (wraps `bootstrap.sh`) |
| `just doctor` | Verify the machine can build and render the sim |
| `just build` | Build the workspace |
| `just build-pkg <name>` | Build a single package |
| `just rebuild` | Clean, then build from scratch |
| `just clean` | Remove `build/`, `install/`, `log/` |
| `just deps` | Resolve ROS dependencies via rosdep |
| `just rviz` | Build and launch RViz with the arm |
| `just urdf` | Print the expanded URDF (fast xacro error check) |
| `just check-urdf` | Validate the URDF, print the link/joint tree |
| `just test` | Run the test suite |
| `just env` | Show the active ROS environment |
| `just graph` | List running nodes and topics |

## Automatic environment (direnv)

`bootstrap.sh` installs [direnv](https://direnv.net) and adds its shell hook. After
that, simply `cd`-ing into this folder loads the ROS 2 environment:

```
$ cd ~/armold
direnv: loading ~/armold/.envrc
armold: ROS 2 jazzy ready (domain 0)

$ ros2 topic list      # works — nothing sourced by hand
$ rviz2                # works
```

Leaving the folder unloads it again, so ROS never leaks into your other shells.

The rules live in [.envrc](.envrc). It sources `setup_env.sh` and watches both it
and `install/setup.bash`, so the workspace overlay is picked up automatically
after the first `just build`.

If you edit `.envrc`, direnv will ask you to re-approve it:

```bash
direnv allow
```

direnv is a convenience, not a requirement — the `just` recipes source the
environment themselves and work with or without it.

## Layout

```
bootstrap.sh        one-time system setup
justfile            every project command
setup_env.sh        ROS env + snap workaround (sourced, not executed)
.envrc              direnv: auto-loads the ROS env on cd
.gitattributes      LF normalization; meshes marked binary
scripts/
  doctor.sh         system readiness check
src/                ROS 2 packages live here (colcon workspace root)
```

`build/`, `install/`, and `log/` are colcon output and are git-ignored. `src/` is
currently empty apart from a `.gitkeep` — the `armold_description` package lands
there next.

## Note for VS Code users

VS Code installs as a snap and exports a `GTK_PATH` into `/snap`. The GTK module
there has a RUNPATH into `/snap/core20`, so the loader picks up core20's glibc 2.31
instead of the system glibc, and RViz dies at startup with
`undefined symbol: __libc_pthread_init`.

`setup_env.sh` clears those variables, and every `just` recipe sources it — so
running through `just` always works. Calling `rviz2` bare from a VS Code terminal
will crash unless direnv has loaded, or you `source ./setup_env.sh` first.

The same snap also exports `XDG_DATA_HOME` into `/snap/code/<rev>/.local/share`,
which is where direnv keeps its `.envrc` approvals. Because that path is pinned to
the snap revision, every VS Code update would silently revoke them — and approvals
made in a VS Code terminal would be invisible to a normal terminal, and vice versa.
The shell hook that `bootstrap.sh` installs resets `XDG_DATA_HOME` back to
`~/.local/share` when it points into `/snap`, so approvals persist and are shared
across both terminals.
