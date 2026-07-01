# SWG Maya 2024 Plugin

Maya 2024 plugin package for SWG asset import/export work.

This package includes the Maya plugin, required helper executables, the installer, and documentation.

## Install

From the package folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install_SWGMayaPlugin.ps1
```

For a nonstandard Maya install:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install_SWGMayaPlugin.ps1 -MayaLocation "D:\Autodesk\Maya2024"
```

The installer looks for Maya 2024 through `-MayaLocation`, `MAYA_LOCATION`, Autodesk registry entries, and normal Autodesk install folders. It fails closed if it cannot find a compatible Maya 2024 install.

The installer writes:

- `Documents\maya\modules\SWGMaya2024Port.mod`
- `Documents\maya\modules\SWGMaya2024Port\plug-ins\SwgMaya2024PortPlugin.mll`
- `Documents\maya\modules\SWGMaya2024Port\tools\` with required helper executables
- `Documents\maya\modules\SWGMaya2024Port\docs\` with this README and HELP file

## Load In Maya

```mel
loadPlugin "SwgMaya2024PortPlugin.mll";
swgPort_openStaticPackageQueueUi;
swgPort_openHelp;
```

The operator UI exposes:

- Export
- Import
- Blend Shapes
- POB Tools
- Settings

## Included Runtime Files

The release package contains:

- `Install_SWGMayaPlugin.ps1`
- `plug-ins\SwgMaya2024PortPlugin.mll`
- `tools\swg_nvtristrip32\swg_nvtristrip32.exe`
- `tools\swg_ati_texture32\swg_ati_texture32.exe`
- `docs\README.md`
- `docs\HELP.md`

## Verified Scope

This build is a release candidate for the verified source-faithful scope. The plugin keeps unproven paths source-shaped, fixture-gated, or fail-closed instead of silently claiming byte-equivalence.

Verified areas include:

- static MSH import/export for the controlled source-backed fixture scope
- skeletal MGN writer core for the controlled original-exporter fixture scope
- shader/template package fidelity for the proven corpus
- skeleton and SAT export for controlled fixture scopes
- animation export for controlled compressed and uncompressed single/two-joint `.ans` fixture scopes
- animation import for source-parsed KFAT/CKAT `.ans` joint rotation/translation keys onto matching Maya skeleton joints, including replacement of existing rotate/translate animation keys when importing another `.ans` onto the same skeleton
- helper-gated legacy texture compression path
- POB import/export tools for the verified fixture-backed scope

## Scope Boundaries

The Import tab's `.ans` option imports source-parsed KFAT/CKAT animation channels onto matching Maya joints. Load or import the matching skeleton first, then pass/select its root group so `.ans` transform names can resolve. Importing another `.ans` onto the same skeleton replaces existing rotate/translate animation keys on matching joints. Unresolved or ambiguous skeleton targets fail closed instead of creating a partial animation.

The build does not claim broad source-faithful output where original source behavior or original exporter fixture bytes have not proved it. Optional follow-up areas include broader POB/static hierarchy fixture breadth and broader animation fixture breadth.
