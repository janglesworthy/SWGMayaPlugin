# SWG Maya 2024 Plugin Help

## Install

Run the installer from the release package folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install_SWGMayaPlugin.ps1
```

The installer looks for Maya 2024 through `-MayaLocation`, `MAYA_LOCATION`, Autodesk registry entries, and normal Autodesk install folders. It fails closed if it cannot find a compatible Maya 2024 install.

The release package installs the compiled Maya plugin, required helper executables, this help file, the README, and the public installer script.

## Load In Maya

```mel
loadPlugin "SwgMaya2024PortPlugin.mll";
swgPort_openStaticPackageQueueUi;
```

## Main UI

The operator window has five public tabs:

- Export
- Import
- Blend Shapes
- POB Tools
- Settings

The package/debug/audit tooling used during development is intentionally not shipped in the public UI.

## Import Notes

`Animation (.ans)` imports source-parsed KFAT/CKAT joint animation channels onto matching Maya skeleton joints. Import or load the matching skeleton first, then use the skeleton root group; unresolved or ambiguous targets fail closed.

## Helper Executables

The plugin uses helper executables from the package `tools` folder:

- `swg_nvtristrip32.exe`
- `swg_ati_texture32.exe`

Keep these folders beside the plugin module. Do not move them unless you also set the matching tool override environment variables.
