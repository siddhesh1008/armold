# Meshes — not included in this repository

These folders are intentionally empty. Armold's mesh and CAD geometry is a paid
design owned by **Sweep Dynamics** and is not distributed here.

```
meshes/
├── visual/      detailed meshes used for rendering
└── collision/   simplified meshes used for collision checking
```

If you have purchased the design, drop the files into the folders above. The URDF
references them by the standard package path, so nothing else needs changing:

```xml
<mesh filename="package://armold_description/meshes/visual/base_link.stl"/>
```

Purchase and licensing details are in the [project README](../../../README.md).

**Note:** `.gitignore` excludes mesh and CAD formats repo-wide, so dropping the
files here will not accidentally commit them.
