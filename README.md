# Armold

Simulation for the **Armold** robotic arm by Sweep Dynamics. ROS 2 Jazzy, visualized in RViz.

> **Mesh files are not included.** Armold is a paid design. This repository holds
> the simulation code and the folder structure, but no geometry — see
> [Meshes and CAD geometry](#meshes-and-cad-geometry) for how to obtain it.

## Setting up a new machine

```bash
git clone https://github.com/siddhesh1008/armold.git ~/armold && cd ~/armold
./bootstrap.sh      # installs ROS 2 Jazzy, sim packages, and `just`
just doctor         # confirm the machine can build and render
just build
just rviz
```

`bootstrap.sh` is the only script you run by hand, and only once per machine.
Everything after that is a `just` recipe. Both are safe to re-run.

The sim will build and RViz will open without the meshes. To see the actual arm
geometry you also need the purchased mesh files — see the next section.

## Meshes and CAD geometry

Armold is a **commercial design by Sweep Dynamics**, sold under licence. The mesh
and CAD files are the product, so they are deliberately kept out of this
repository. What you get here is everything around them: the URDF, launch files,
controllers, and the build tooling.

### Obtaining the geometry

**[Purchase the Armold design from Sweep Dynamics](https://www.sweepdynamics.com/products/8446143070242)**

Buying the design gets you the mesh and CAD files that this repository omits.

### Installing it

The folders are already in the repo — only the files inside them are missing.
Drop your purchased meshes into place:

```
src/armold_description/meshes/
├── visual/      detailed meshes used for rendering
└── collision/   simplified meshes used for collision checking
```

The URDF refers to them by the standard package path, so no path edits are needed:

```xml
<mesh filename="package://armold_description/meshes/visual/base_link.stl"/>
```

Then rebuild:

```bash
just rebuild
just rviz
```

### Why you cannot accidentally commit them

`.gitignore` excludes mesh and CAD formats repo-wide — `.stl`, `.dae`, `.obj`,
`.step`, `.sldprt`, `.f3d` and friends. The folders survive in git through
`.gitkeep` files, so the structure is version-controlled while the geometry never
leaves your machine. If some asset genuinely is shareable, add it deliberately
with `git add -f`.

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
src/                colcon workspace root
  armold_description/
    meshes/
      visual/       (empty in git — purchased geometry goes here)
      collision/    (empty in git — purchased geometry goes here)
```

`build/`, `install/`, and `log/` are colcon output and are git-ignored. The
`meshes/` folders are tracked but their contents are not; see
[Meshes and CAD geometry](#meshes-and-cad-geometry).

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

## Licence and ownership

The **Armold** design — its geometry, mesh files, and CAD sources — is the
property of **Sweep Dynamics** and is licensed to purchasers. It is not covered by
this repository and is not redistributable.

The simulation code in this repository is published without a licence file, which
means all rights are reserved by default. Contact Sweep Dynamics for usage terms.
