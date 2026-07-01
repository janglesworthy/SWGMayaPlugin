# SWG Maya 2024 Plugin Help

## Open The Tools

Load the plugin and open the main window:

```mel
loadPlugin "SwgMaya2024PortPlugin.mll";
swgPort_openStaticPackageQueueUi;
```

Open this help file from Maya:

```mel
swgPort_openHelp;
```

The plugin also adds an `SWG` menu to Maya with:

- Open SWG Maya Exporter
- Open Help
- Plugin Info

## Main Window

The main window is organized into five tabs:

- `Export`: writes SWG asset formats from the current Maya scene or selection.
- `Import`: imports SWG asset formats into the current Maya scene.
- `Blend Shapes`: lists blendShape nodes and exposes sliders for their targets.
- `POB Tools`: tags selected scene objects with portal-building authoring roles.
- `Settings`: sets output directories and author metadata used by exporter commands.

Use `Show Command` before running an operation when you want to inspect the exact MEL command that will be executed.

## Common Paths

`Extract Root` should point to the root of an extracted SWG client tree. It is used to resolve referenced assets, textures, shader templates, skeletons, SAT files, POB cell appearances, and wearable/loadout references.

Typical extract-root layout:

```text
C:/UE5_Projects/SWGExtract/
  appearance/
  shader/
  texture/
  textureRenderer/
  effect/
```

`Base Output` in the Settings tab is the root output folder for export commands. Applying it creates the expected SWG-style subfolders for appearance, shader, texture, animation, skeleton, and log output.

## Import Tab

Choose the asset type, pick one or more source files, set the required options, then click `Run Import`.

### Portal Building (.pob)

Use this for complete portal building imports. Required fields:

- `Source`: one or more `.pob` files.
- `Extract Root`: required so referenced cell appearances, floors, shaders, textures, and portal data can resolve.

Useful options:

- `Root Group`: optional name for the imported hierarchy root.
- `Normal Maps`: enables normal-map preview hookups where supported.
- `Object Normals`: enables object-space normal preview behavior.
- `Skip Preview`: skips viewport material preview creation when you only need geometry/metadata.

### Static Appearance (.apt/.lod/.cmp)

Use this for static appearance hierarchies. Required fields:

- `Source`: `.apt`, `.lod`, or `.cmp`.
- `Extract Root`: required so child appearances and `.msh` leaves can resolve.

The importer rebuilds the hierarchy and imports referenced static mesh leaves.

### Static Mesh (.msh)

Use this for direct static mesh import. Required fields:

- `Source`: one or more `.msh` files.

Important options:

- `Source Shader Buckets` unchecked: imports as combined component meshes with shader face assignments.
- `Source Shader Buckets` checked: imports separate shader-bucket meshes, useful for inspecting source material grouping.
- `Normal Maps`: enables normal-map preview hookups.
- `Object Normals`: enables object-space normal preview behavior.
- `Skip Preview`: skips viewport material preview creation.

Direct `.msh` import does not need an extract root for geometry, but texture and shader preview resolution benefits from one.

### MGN / LMG Skeletal Mesh Generator (.mgn/.lmg)

Use this for skeletal mesh generator files. Required fields:

- `Source`: one or more `.mgn` or `.lmg` files.

Useful options:

- `Create Skeletons`: creates skeletons referenced by the mesh generator.
- `Create Meshes`: creates mesh geometry.
- `Share Skeletons`: reuses matching skeletons across imports.
- `Root Group`: optional target group or skeleton root.
- `Normal Maps`, `Object Normals`, and `Skip Preview` control viewport material preview behavior.

### Skeletal Appearance Template (.sat)

Use this to import a SAT and its referenced skeletal mesh/skeleton data. Required fields:

- `Source`: `.sat`.
- `Extract Root`: required so SAT references can resolve.

Use `Create Skeletons`, `Create Meshes`, and `Share Skeletons` to control how much of the SAT dependency graph is built in the scene.

### Client Data File Wearables (.cdf)

Use this to import wearable data from a CDF. Required fields:

- `Source`: `.cdf`.
- `Extract Root`: required so wearable appearances can resolve.

Use the MGN/SAT options to control skeleton and mesh creation.

### Character Loadout (.iff)

Use this to import character loadout appearances. Required fields:

- `Source`: loadout `.iff`.
- `Extract Root`: required.
- `Player Template`: required treefile path for the player template.

Optional:

- `Appearance Table`: use when the loadout needs an explicit table path.

### Skeleton (.skt)

Use this for direct skeleton import. Required fields:

- `Source`: `.skt`.

Set `Root Group` when you want the skeleton under a named group.

### Animation (.ans)

Use this to apply ANS animation keys to an existing matching Maya skeleton. Required fields:

- `Source`: `.ans`.
- `Root Group`: the imported skeleton root or a group containing the matching skeleton.

Workflow:

1. Import or load the matching skeleton first.
2. Select or enter the skeleton root/group in `Root Group`.
3. Import the `.ans`.
4. Play the Maya timeline.

The importer applies source-parsed rotation and translation channels to matching Maya joints. Importing another `.ans` onto the same skeleton replaces existing rotate/translate animation keys on matching joints before applying the new animation. If the skeleton target is missing or ambiguous, the command fails instead of applying a partial animation.

## Export Tab

Select the scene object or hierarchy to export, choose the export type, set the output path when required, then click `Run Export`.

### Static Mesh (.msh)

Exports the selected static mesh hierarchy.

Recommended:

- Select the root transform for the object.
- Set `POB Output` to the `.msh` destination when using direct command output.
- Use `Show Command` to confirm the selected target and output path.

### Portal Building (.pob)

Exports selected portal-building authoring data.

Recommended:

- Tag the scene first with `POB Tools`.
- Set `POB Output` to the target `.pob` path.
- Use `Fix POB CRC` only when repairing a known CRC mismatch.

### MGN Skeletal Mesh Generator (.mgn)

Exports a skeletal mesh generator from the selected skinned mesh/skeleton setup.

Recommended:

- Select the skinned mesh or its export root.
- Make sure skeleton and shader assignments are present.
- Use the Settings tab before export so output directories and author metadata are set.

### Skeleton (.skt)

Exports the selected Maya skeleton.

Recommended:

- Select the skeleton root joint.
- Confirm the skeleton template output directory in Settings.

### Animation (.ans)

Exports skeletal animation from the current scene.

Fields/options:

- `Animation`: animation name to write.
- `All Animations`: exports all configured animation entries where applicable.
- `No Compress`: writes uncompressed animation data.
- `Write .ans`: writes the `.ans` file.

Recommended:

- Load the target skeleton and animation in Maya.
- Set the timeline to the intended frame range.
- Use `Show Command` before the first export.

### Skeletal Appearance Template (.sat)

Exports a skeletal appearance template from the current skeletal setup.

Recommended:

- Export or confirm the skeleton and mesh generator paths first.
- Apply Settings before export.

## Blend Shapes Tab

Use this tab to inspect and adjust Maya blendShape targets.

Controls:

- `Refresh`: lists all blendShape nodes in the scene.
- `Load Sliders`: creates sliders for the selected blendShape node.
- `Zero Selected`: sets all target weights on the selected blendShape node to zero.

This tab is for Maya scene editing and preview. Exported blend-shape behavior depends on the selected export type and the data present on the scene nodes.

## POB Tools Tab

Use this tab to tag selected objects for portal-building export.

Roles:

- `Cell`
- `Portal List`
- `Portal`
- `Floor`
- `Collision`
- `Mesh Appearance`
- `Component`
- `Detail`
- `Light List`
- `hp_path`
- `hp_door`

Fields/options:

- `Index`: role index for the selected object.
- `Door Style`: optional door style metadata for door hardpoints.
- `Disabled`: marks the selected role as disabled.
- `Impassable`: marks the selected role as impassable.
- `Tag Selected`: writes the selected role metadata to the current Maya selection.
- `Show Command`: prints the command without applying it.

Typical POB workflow:

1. Build or import the building hierarchy.
2. Select objects that represent cells, portals, floors, collision, lights, and hardpoints.
3. Apply the matching role from `POB Tools`.
4. Export through the Export tab using `Portal Building (.pob)`.

## Settings Tab

Use Settings before export work.

Controls:

- `Base Output`: root folder used to derive SWG-style output directories.
- `Author`: author string written by export commands.
- `Apply Base`: applies the output root.
- `Apply Author`: applies the author value.
- `Show Settings`: prints the current directory settings.

## Command Reference

Open tools:

```mel
swgPort_openStaticPackageQueueUi;
swgPort_openHelp;
swgPort_info;
```

Direct import examples:

```mel
swgPort_importMsh -mshFile "C:/SWGExtract/appearance/mesh/example.msh" -extractRoot "C:/SWGExtract";
swgPort_importStaticAppearance -appearanceFile "C:/SWGExtract/appearance/example.apt" -extractRoot "C:/SWGExtract";
swgPort_importPortalBuilding -pobFile "C:/SWGExtract/appearance/building/example.pob" -extractRoot "C:/SWGExtract";
swgPort_importSkeleton -sktFile "C:/SWGExtract/appearance/skeleton/example.skt";
swgPort_importAnimation -ansFile "C:/SWGExtract/appearance/animation/example.ans" -rootGroup "swg_skeleton_import_grp";
```

Direct export examples:

```mel
swgPort_exportStaticMesh -interactive -outputFile "C:/SWGExport/appearance/mesh/example.msh";
swgPort_exportPortalBuilding -interactive -outputFile "C:/SWGExport/appearance/building/example.pob";
swgPort_exportSkeletalMeshGenerator -interactive;
swgPort_exportSkeleton -interactive;
swgPort_exportSkeletalAnimation -interactive "idle";
swgPort_exportSatFile -interactive;
```

Settings examples:

```mel
swgPort_setBaseDirectory -baseDirectory "C:/SWGExport";
swgPort_setAuthor "your_name";
swgPort_sourceSettings;
```

## Troubleshooting

If the UI says a command is missing, unload/reload the plugin and reopen the window:

```mel
unloadPlugin "SwgMaya2024PortPlugin.mll";
loadPlugin "SwgMaya2024PortPlugin.mll";
swgPort_openStaticPackageQueueUi;
```

If textures do not appear, check:

- `Extract Root` points to the extracted SWG client root.
- The referenced `shader`, `texture`, `textureRenderer`, and `effect` folders exist.
- `Skip Preview` is unchecked when you want viewport material preview.

If an animation import does nothing, check:

- The matching skeleton is already in the scene.
- `Root Group` points to the skeleton root or a group containing it.
- The joint names in the `.ans` can resolve to Maya joints.
- When switching animations, import the next `.ans` with the same skeleton root/group selected.

If a POB import is incomplete, check:

- `Extract Root` is set.
- Referenced cell appearances, floor files, and mesh files exist under the extracted tree.
- The Script Editor shows no missing-reference errors.

If export writes to the wrong folder, use `Settings > Apply Base`, then run `Show Settings`.

When in doubt, use `Show Command`, copy the command from the status area, and run it in the Script Editor so Maya shows the full command output.
