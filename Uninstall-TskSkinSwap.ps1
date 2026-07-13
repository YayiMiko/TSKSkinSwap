[CmdletBinding()]
param(
    [string]$GamePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [ValidateSet('Disable', 'Full')]
    [string]$Mode = 'Disable'
)

$ErrorActionPreference = 'Stop'
$pluginDirectory = Join-Path $GamePath 'BepInEx\plugins\TskSkinSwap'
$configDirectory = Join-Path $GamePath 'BepInEx\config\TskSkinSwap'
$bepInExCore = Join-Path $GamePath 'BepInEx\core\BepInEx.Unity.IL2CPP.dll'
$installStatePath = Join-Path $PSScriptRoot '.install-state.json'
$bepInExArchive = Join-Path $PSScriptRoot '.tools\BepInEx-Unity.IL2CPP-win-x64-6.0.0-pre.2.zip'
$bepInExSha256 = '616ec7eb06cf11b2a0000e8fcef04d1b12bb58e84a2e0bdac9523234fc193ceb'

function Get-OtherBepInExAddons {
    $excludedRoot = [IO.Path]::GetFullPath($pluginDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $files = @()
    foreach ($relativeRoot in @('BepInEx\plugins', 'BepInEx\patchers')) {
        $root = Join-Path $GamePath $relativeRoot
        if (Test-Path $root) {
            $files += Get-ChildItem $root -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { -not [IO.Path]::GetFullPath($_.FullName).StartsWith($excludedRoot, [StringComparison]::OrdinalIgnoreCase) }
        }
    }
    return @($files)
}

function Test-LegacyTskBepInExInstall {
    $loaderFiles = @('.doorstop_version', 'doorstop_config.ini', 'winhttp.dll')
    $hasLoader = -not ($loaderFiles | Where-Object { -not (Test-Path (Join-Path $GamePath $_)) })
    $hasInstallerArchive = (Test-Path $bepInExArchive) -and
        ((Get-FileHash -LiteralPath $bepInExArchive -Algorithm SHA256).Hash -eq $bepInExSha256)
    return $hasLoader -and $hasInstallerArchive -and (Test-Path $bepInExCore) -and
        (@(Get-OtherBepInExAddons).Count -eq 0)
}

if (Get-Process twinkle_starknightsX -ErrorAction SilentlyContinue) {
    throw 'The game is running. Close it before uninstalling TskSkinSwap.'
}

$bepInExInstalledByTskSkinSwap = $false
if (Test-Path $installStatePath) {
    try {
        $state = Get-Content $installStatePath -Raw | ConvertFrom-Json
        if ($state.schemaVersion -ne 1 -or $null -eq $state.bepInExInstalledByTskSkinSwap) {
            throw 'Unsupported install state.'
        }
        $bepInExInstalledByTskSkinSwap = $state.bepInExInstalledByTskSkinSwap -eq $true
    } catch {
        $bepInExInstalledByTskSkinSwap = Test-LegacyTskBepInExInstall
    }
} else {
    $bepInExInstalledByTskSkinSwap = Test-LegacyTskBepInExInstall
}

$otherAddons = @(Get-OtherBepInExAddons)

if (Test-Path $pluginDirectory) {
    Remove-Item -LiteralPath $pluginDirectory -Recurse -Force
}
if (Test-Path $configDirectory) {
    Remove-Item -LiteralPath $configDirectory -Recurse -Force
}

$generatedDirectory = Join-Path $PSScriptRoot 'generated'
if (Test-Path $generatedDirectory) {
    Remove-Item -LiteralPath $generatedDirectory -Recurse -Force
}

if ($Mode -eq 'Full') {
    $sourceCheckout = Test-Path (Join-Path $PSScriptRoot '.git')
    if ($bepInExInstalledByTskSkinSwap -and $otherAddons.Count -eq 0) {
        foreach ($path in @(
            (Join-Path $GamePath 'BepInEx'),
            (Join-Path $GamePath 'dotnet'),
            (Join-Path $GamePath '.doorstop_version'),
            (Join-Path $GamePath 'changelog.txt'),
            (Join-Path $GamePath 'doorstop_config.ini'),
            (Join-Path $GamePath 'winhttp.dll')
        )) {
            if (Test-Path $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }
        Write-Host 'BepInEx was removed because it was installed by TskSkinSwap and no other add-ons use it.'
    } elseif ($otherAddons.Count -gt 0) {
        Write-Host 'BepInEx was preserved because other add-ons are installed:'
        $otherAddons | ForEach-Object { Write-Host "  $($_.FullName)" }
    } else {
        Write-Host 'BepInEx was preserved because it existed before TskSkinSwap.'
    }

    $localPaths = if ($sourceCheckout) {
        @('downloaded', 'generated', 'src\bin', 'src\obj', '__pycache__')
    } else {
        @('.tools', 'downloaded', 'artifacts', '__pycache__', 'src\bin', 'src\obj')
    }
    foreach ($relativePath in $localPaths) {
        $path = Join-Path $PSScriptRoot $relativePath
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
    if (Test-Path $installStatePath) {
        Remove-Item -LiteralPath $installStatePath -Force
    }

    if ($sourceCheckout) {
        Write-Host 'A Git checkout was detected. The source repository and development tools were preserved.'
    }

    Write-Host 'TskSkinSwap was completely uninstalled. Original game files and the Unity cache were not changed.'
} else {
    Write-Host 'TskSkinSwap was disabled. Downloaded resources and local tools were preserved for reinstalling.'
}
