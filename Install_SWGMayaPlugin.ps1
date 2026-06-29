param(
    [string]$MayaVersion = "2024",
    [string]$MayaLocation = "",
    [string]$PackageRoot = "",
    [string]$InstallRoot = "",
    [string]$ModuleFile = "",
    [switch]$NoBuild,
    [switch]$DistributionPackage,
    [switch]$ListMaya
)

$ErrorActionPreference = "Stop"

$PluginFileName = "SwgMaya2024PortPlugin.mll"
$PublicInstallerName = "Install_SWGMayaPlugin.ps1"
$ModuleName = "SWGMaya2024Port"
$ModuleVersion = "2026.06"

function Get-FullPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-UserDocumentsPath {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = Join-Path $env:USERPROFILE "Documents"
    }
    return $documents
}

function Test-MayaInstallPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $mayaExe = Join-Path $Path "bin\maya.exe"
    return (Test-Path -LiteralPath $mayaExe)
}

function Get-MayaVersionFromPath {
    param([string]$Path)

    $leaf = Split-Path -Leaf $Path
    if ($leaf -match "Maya\s*(\d{4})") {
        return $Matches[1]
    }
    if ($Path -match "Maya\s*(\d{4})") {
        return $Matches[1]
    }
    return ""
}

function New-MayaCandidate {
    param(
        [string]$Path,
        [string]$Source
    )

    $resolvedPath = Get-FullPath $Path
    return [pscustomobject]@{
        version = Get-MayaVersionFromPath -Path $resolvedPath
        path = $resolvedPath
        mayaExe = Join-Path $resolvedPath "bin\maya.exe"
        mayapyExe = Join-Path $resolvedPath "bin\mayapy.exe"
        source = $Source
    }
}

function Add-MayaCandidate {
    param(
        [System.Collections.ArrayList]$Candidates,
        [hashtable]$Seen,
        [string]$Path,
        [string]$Source
    )

    if (-not (Test-MayaInstallPath -Path $Path)) {
        return
    }

    $resolvedPath = Get-FullPath $Path
    $key = $resolvedPath.ToLowerInvariant()
    if ($Seen.ContainsKey($key)) {
        return
    }

    $Seen[$key] = $true
    [void]$Candidates.Add((New-MayaCandidate -Path $resolvedPath -Source $Source))
}

function Get-MayaInstallCandidates {
    $candidates = New-Object System.Collections.ArrayList
    $seen = @{}

    if (-not [string]::IsNullOrWhiteSpace($env:MAYA_LOCATION)) {
        Add-MayaCandidate -Candidates $candidates -Seen $seen -Path $env:MAYA_LOCATION -Source "MAYA_LOCATION"
    }

    $registryRoots = @(
        "HKLM:\SOFTWARE\Autodesk\Maya",
        "HKLM:\SOFTWARE\WOW6432Node\Autodesk\Maya"
    )
    $registryPropertyNames = @(
        "MAYA_INSTALL_LOCATION",
        "InstallPath",
        "Location",
        "SetupPath"
    )

    foreach ($registryRoot in $registryRoots) {
        if (-not (Test-Path -LiteralPath $registryRoot)) {
            continue
        }
        try {
            $registryItems = Get-ChildItem -LiteralPath $registryRoot -Recurse -ErrorAction SilentlyContinue
            foreach ($item in $registryItems) {
                try {
                    $properties = Get-ItemProperty -LiteralPath $item.PSPath -ErrorAction SilentlyContinue
                    foreach ($name in $registryPropertyNames) {
                        $property = $properties.PSObject.Properties[$name]
                        if ($property -ne $null -and $property.Value -is [string]) {
                            Add-MayaCandidate -Candidates $candidates -Seen $seen -Path $property.Value -Source "registry:$name"
                        }
                    }
                }
                catch {
                }
            }
        }
        catch {
        }
    }

    $programRoots = @(
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)}
    )

    foreach ($programRoot in $programRoots) {
        if ([string]::IsNullOrWhiteSpace($programRoot)) {
            continue
        }
        $autodeskRoot = Join-Path $programRoot "Autodesk"
        if (-not (Test-Path -LiteralPath $autodeskRoot)) {
            continue
        }
        Get-ChildItem -LiteralPath $autodeskRoot -Directory -Filter "Maya*" -ErrorAction SilentlyContinue | ForEach-Object {
            Add-MayaCandidate -Candidates $candidates -Seen $seen -Path $_.FullName -Source "program-files"
        }
    }

    return @($candidates | Sort-Object version,path)
}

function Resolve-MayaInstall {
    param(
        [string]$RequestedVersion,
        [string]$ExplicitLocation
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitLocation)) {
        if (-not (Test-MayaInstallPath -Path $ExplicitLocation)) {
            throw "Maya install not found at -MayaLocation '$ExplicitLocation'. Expected bin\maya.exe below that folder."
        }
        $candidate = New-MayaCandidate -Path $ExplicitLocation -Source "argument"
        if (-not [string]::IsNullOrWhiteSpace($RequestedVersion) -and
            -not [string]::IsNullOrWhiteSpace($candidate.version) -and
            $candidate.version -ne $RequestedVersion) {
            throw "This plugin is built for Maya $RequestedVersion, but -MayaLocation resolved to Maya $($candidate.version): $($candidate.path)"
        }
        return $candidate
    }

    $candidates = Get-MayaInstallCandidates
    if ($ListMaya) {
        $candidates | ConvertTo-Json -Depth 4 | Write-Output
    }

    $compatible = @($candidates | Where-Object { $_.version -eq $RequestedVersion })
    if ($compatible.Count -gt 0) {
        $preferred = @($compatible | Sort-Object @{ Expression = {
            if ($_.source -eq "MAYA_LOCATION") {
                return 0
            }
            if ($_.source -like "registry:*") {
                return 1
            }
            return 2
        } }, path)
        return $preferred[0]
    }

    $found = if ($candidates.Count -gt 0) {
        ($candidates | ForEach-Object { "$($_.version): $($_.path)" }) -join "; "
    }
    else {
        "none"
    }
    throw "No compatible Maya $RequestedVersion install was found. Found Maya installs: $found. Use -MayaLocation to point at the Maya $RequestedVersion install folder."
}

function Resolve-PackageLayout {
    param([string]$Root)

    $resolvedRoot = Get-FullPath $Root
    $packagedPlugin = Join-Path $resolvedRoot "plug-ins\$PluginFileName"
    if (Test-Path -LiteralPath $packagedPlugin) {
        return [pscustomobject]@{
            mode = "packaged"
            root = $resolvedRoot
            pluginSource = $packagedPlugin
            buildDir = ""
            toolsRoot = Join-Path $resolvedRoot "tools"
            docsRoot = Join-Path $resolvedRoot "docs"
            installerSource = Join-Path $resolvedRoot $PublicInstallerName
        }
    }

    $projectPlugin = Join-Path $resolvedRoot "maya2024_cleanroom_scaffold\build-vs2026\Release\$PluginFileName"
    return [pscustomobject]@{
        mode = "project"
        root = $resolvedRoot
        pluginSource = $projectPlugin
        buildDir = Join-Path $resolvedRoot "maya2024_cleanroom_scaffold\build-vs2026"
        toolsRoot = Join-Path $resolvedRoot "tools"
        docsRoot = $resolvedRoot
        installerSource = Join-Path $resolvedRoot $PublicInstallerName
    }
}

function Get-Sha256Hex {
    param([string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hash = $sha256.ComputeHash($stream)
            return -join ($hash | ForEach-Object { $_.ToString("x2") })
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-RequiredFile {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $Path"
    }
}

function Copy-FileIfDifferent {
    param(
        [string]$Source,
        [string]$Destination
    )

    Assert-RequiredFile -Path $Source -Description "Source file"
    $destinationDir = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null

    $sourceFull = Get-FullPath $Source
    $destinationFull = Get-FullPath $Destination
    if ([string]::Equals($sourceFull, $destinationFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    Copy-Item -LiteralPath $sourceFull -Destination $destinationFull -Force
}

function Remove-ManagedInstallSubdirectory {
    param(
        [string]$InstallRootPath,
        [string]$ResolvedInstallRootPath,
        [string]$Name
    )

    $target = Join-Path $InstallRootPath $Name
    if (-not (Test-Path -LiteralPath $target)) {
        return
    }

    $resolvedTarget = (Resolve-Path -LiteralPath $target).Path
    $expectedTarget = Get-FullPath (Join-Path $ResolvedInstallRootPath $Name)
    if (-not [string]::Equals($resolvedTarget, $expectedTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected managed directory: $resolvedTarget"
    }

    try {
        Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    }
    catch {
        throw "Failed to replace managed directory '$resolvedTarget'. If Maya is running with this plugin loaded, unload SwgMaya2024PortPlugin.mll or close Maya, then rerun the installer. Original error: $($_.Exception.Message)"
    }
}

function Remove-ManagedInstallFile {
    param(
        [string]$InstallRootPath,
        [string]$ResolvedInstallRootPath,
        [string]$Name
    )

    $target = Join-Path $InstallRootPath $Name
    if (-not (Test-Path -LiteralPath $target)) {
        return
    }

    $resolvedTarget = (Resolve-Path -LiteralPath $target).Path
    $expectedTarget = Get-FullPath (Join-Path $ResolvedInstallRootPath $Name)
    if (-not [string]::Equals($resolvedTarget, $expectedTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected managed file: $resolvedTarget"
    }

    try {
        Remove-Item -LiteralPath $resolvedTarget -Force
    }
    catch {
        throw "Failed to replace managed file '$resolvedTarget'. If Maya is running with this plugin loaded, unload SwgMaya2024PortPlugin.mll or close Maya, then rerun the installer. Original error: $($_.Exception.Message)"
    }
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
    $PackageRoot = $ScriptRoot
}

if ($DistributionPackage) {
    if ($ListMaya) {
        Get-MayaInstallCandidates | ConvertTo-Json -Depth 4 | Write-Output
    }
    $MayaInstall = $null
}
else {
    $MayaInstall = Resolve-MayaInstall -RequestedVersion $MayaVersion -ExplicitLocation $MayaLocation
}
$Layout = Resolve-PackageLayout -Root $PackageRoot

if ($Layout.mode -eq "project" -and -not $NoBuild -and -not (Test-Path -LiteralPath $Layout.pluginSource)) {
    if ([string]::IsNullOrWhiteSpace($Layout.buildDir) -or -not (Test-Path -LiteralPath $Layout.buildDir)) {
        throw "Build directory not found for project package root: $($Layout.buildDir)"
    }
    cmake --build $Layout.buildDir --config Release
}

Assert-RequiredFile -Path $Layout.pluginSource -Description "Release plugin"
Assert-RequiredFile -Path $Layout.installerSource -Description "Public installer script"

$RequiredHelpers = @(
    (Join-Path $Layout.toolsRoot "swg_nvtristrip32\swg_nvtristrip32.exe"),
    (Join-Path $Layout.toolsRoot "swg_ati_texture32\swg_ati_texture32.exe")
)

foreach ($helper in $RequiredHelpers) {
    Assert-RequiredFile -Path $helper -Description "Required helper executable"
}

if ([string]::IsNullOrWhiteSpace($InstallRoot) -and $DistributionPackage) {
    $InstallRoot = Join-Path $ScriptRoot "release_staging\SWGMayaPlugin"
}

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path (Get-UserDocumentsPath) "maya\modules\$ModuleName"
}

if ([string]::IsNullOrWhiteSpace($ModuleFile) -and -not $DistributionPackage) {
    $ModuleFile = Join-Path (Get-UserDocumentsPath) "maya\modules\$ModuleName.mod"
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
$ResolvedInstallRoot = (Resolve-Path -LiteralPath $InstallRoot).Path
$ResolvedPackageRoot = Get-FullPath $Layout.root
$InstallingOverSourcePackage = [string]::Equals(
    $ResolvedInstallRoot,
    $ResolvedPackageRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)

if (-not $InstallingOverSourcePackage) {
    Remove-ManagedInstallSubdirectory -InstallRootPath $InstallRoot -ResolvedInstallRootPath $ResolvedInstallRoot -Name "plug-ins"
    Remove-ManagedInstallSubdirectory -InstallRootPath $InstallRoot -ResolvedInstallRootPath $ResolvedInstallRoot -Name "docs"
    Remove-ManagedInstallSubdirectory -InstallRootPath $InstallRoot -ResolvedInstallRootPath $ResolvedInstallRoot -Name "tools"
    Remove-ManagedInstallSubdirectory -InstallRootPath $InstallRoot -ResolvedInstallRootPath $ResolvedInstallRoot -Name "scripts"
    Remove-ManagedInstallFile -InstallRootPath $InstallRoot -ResolvedInstallRootPath $ResolvedInstallRoot -Name "install_manifest.json"
    Remove-ManagedInstallFile -InstallRootPath $InstallRoot -ResolvedInstallRootPath $ResolvedInstallRoot -Name "$ModuleName.mod"
}

$PluginTargetDir = Join-Path $InstallRoot "plug-ins"
$ToolsTargetDir = Join-Path $InstallRoot "tools"
$DocsTargetDir = Join-Path $InstallRoot "docs"

New-Item -ItemType Directory -Force -Path $PluginTargetDir | Out-Null
New-Item -ItemType Directory -Force -Path $ToolsTargetDir | Out-Null
New-Item -ItemType Directory -Force -Path $DocsTargetDir | Out-Null
if (-not $DistributionPackage) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ModuleFile) | Out-Null
}

$PluginTarget = Join-Path $PluginTargetDir $PluginFileName
Copy-FileIfDifferent -Source $Layout.pluginSource -Destination $PluginTarget

foreach ($helper in $RequiredHelpers) {
    $helperName = [System.IO.Path]::GetFileNameWithoutExtension($helper)
    $helperTargetDir = Join-Path $ToolsTargetDir $helperName
    New-Item -ItemType Directory -Force -Path $helperTargetDir | Out-Null
    Copy-FileIfDifferent -Source $helper -Destination (Join-Path $helperTargetDir ([System.IO.Path]::GetFileName($helper)))
}

$DocFiles = @(
    "README.md",
    "HELP.md"
)

foreach ($doc in $DocFiles) {
    $source = Join-Path $Layout.docsRoot $doc
    if (Test-Path -LiteralPath $source) {
        Copy-FileIfDifferent -Source $source -Destination (Join-Path $DocsTargetDir ([System.IO.Path]::GetFileName($doc)))
    }
}

Copy-FileIfDifferent -Source $Layout.installerSource -Destination (Join-Path $InstallRoot $PublicInstallerName)

if ($DistributionPackage) {
    Write-Host "Staged SWG Maya 2024 plugin distribution package:"
    Write-Host "  Package root: $InstallRoot"
    Write-Host "  Public installer: $(Join-Path $InstallRoot $PublicInstallerName)"
    Write-Host "  Plugin: $PluginTarget"
    Write-Host ""
    Write-Host "On the target machine, run:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\$PublicInstallerName"
    return
}

$MayaModuleRoot = (Resolve-Path -LiteralPath $InstallRoot).Path.Replace("\", "/")
$ModuleContent = @"
+ $ModuleName $ModuleVersion $MayaModuleRoot
PATH +:= plug-ins
MAYA_PLUG_IN_PATH +:= plug-ins
"@

Set-Content -LiteralPath $ModuleFile -Value $ModuleContent -Encoding ASCII

$PluginHash = Get-Sha256Hex -Path $PluginTarget
$HelperHashes = @{}
foreach ($helper in $RequiredHelpers) {
    $helperName = [System.IO.Path]::GetFileName($helper)
    $installedHelper = Join-Path (Join-Path $ToolsTargetDir ([System.IO.Path]::GetFileNameWithoutExtension($helper))) $helperName
    $HelperHashes[$helperName] = Get-Sha256Hex -Path $installedHelper
}

$Manifest = [ordered]@{
    kind = "swg-maya2024-port-install-manifest"
    installedUtc = (Get-Date).ToUniversalTime().ToString("o")
    installer = [ordered]@{
        script = $PublicInstallerName
        sourceMode = $Layout.mode
        packageRoot = (Get-FullPath $Layout.root)
    }
    maya = [ordered]@{
        requestedVersion = $MayaVersion
        detectedVersion = $MayaInstall.version
        location = $MayaInstall.path
        source = $MayaInstall.source
        mayaExe = $MayaInstall.mayaExe
        mayapyExe = $MayaInstall.mayapyExe
    }
    installRoot = (Resolve-Path -LiteralPath $InstallRoot).Path
    moduleFile = (Resolve-Path -LiteralPath $ModuleFile).Path
    pluginPath = (Resolve-Path -LiteralPath $PluginTarget).Path
    pluginSha256 = $PluginHash
    toolsPath = (Resolve-Path -LiteralPath $ToolsTargetDir).Path
    runtimeScripts = @()
    runtimeDataFiles = @()
    pythonSourceIncluded = $false
    sourceCodeFilesIncluded = $false
    helperSha256 = $HelperHashes
    launchMel = @(
        "loadPlugin `"$PluginFileName`";",
        "swgPort_openStaticPackageQueueUi;"
    )
}

$ManifestPath = Join-Path $InstallRoot "install_manifest.json"
$Manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

Write-Host "Detected Maya $($MayaInstall.version): $($MayaInstall.path)"
Write-Host "Installed SWG Maya 2024 port module:"
Write-Host "  Module file: $ModuleFile"
Write-Host "  Install root: $InstallRoot"
Write-Host "  Plugin: $PluginTarget"
Write-Host "  Manifest: $ManifestPath"
Write-Host ""
Write-Host "In Maya, run:"
Write-Host "  loadPlugin `"$PluginFileName`";"
Write-Host "  swgPort_openStaticPackageQueueUi;"
