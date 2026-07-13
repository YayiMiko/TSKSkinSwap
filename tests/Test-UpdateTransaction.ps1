$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "TskSkinSwap-transaction-$([Guid]::NewGuid().ToString('N'))"

function New-TransactionCase {
    param([string]$Name)

    $root = Join-Path $testRoot $Name
    $script:pluginConfigRoot = Join-Path $root 'config'
    $script:pluginDirectory = Join-Path $root 'plugins'
    $staging = Join-Path $root 'staging'
    New-Item -ItemType Directory -Force -Path $pluginConfigRoot, $pluginDirectory, $staging | Out-Null

    $result = [ordered]@{
        MappingTarget = Join-Path $pluginConfigRoot 'mappings.json'
        PluginTarget = Join-Path $pluginDirectory 'TskSkinSwap.dll'
        StagedMapping = Join-Path $staging 'mappings.json'
        StagedPlugin = Join-Path $staging 'TskSkinSwap.dll'
    }
    Set-Content -LiteralPath $result.MappingTarget -Value 'old-mapping' -Encoding ASCII
    Set-Content -LiteralPath $result.PluginTarget -Value 'old-plugin' -Encoding ASCII
    Set-Content -LiteralPath $result.StagedMapping -Value 'new-mapping' -Encoding ASCII
    Set-Content -LiteralPath $result.StagedPlugin -Value 'new-plugin' -Encoding ASCII
    return [pscustomobject]$result
}

function Assert-Content {
    param([string]$Path, [string]$Expected)
    $actual = (Get-Content -LiteralPath $Path -Raw).Trim()
    if ($actual -ne $Expected) {
        throw "Expected '$Expected' in $Path, received '$actual'."
    }
}

try {
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repositoryRoot 'Update-TskSkinSwap.ps1'),
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count) {
        throw 'Update-TskSkinSwap.ps1 did not parse.'
    }
    $function = $ast.Find({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Install-StagedFiles'
    }, $true)
    Invoke-Expression $function.Extent.Text

    $success = New-TransactionCase 'success'
    Install-StagedFiles -MappingPath $success.StagedMapping -PluginPath $success.StagedPlugin
    Assert-Content $success.PluginTarget 'new-plugin'
    Assert-Content $success.MappingTarget 'new-mapping'

    $rollback = New-TransactionCase 'rollback'
    $lock = [IO.File]::Open($rollback.MappingTarget, 'Open', 'Read', 'None')
    $failed = $false
    try {
        Install-StagedFiles -MappingPath $rollback.StagedMapping -PluginPath $rollback.StagedPlugin
    } catch {
        $failed = $true
    } finally {
        $lock.Dispose()
    }
    if (-not $failed) {
        throw 'The locked mapping did not trigger rollback.'
    }
    Assert-Content $rollback.PluginTarget 'old-plugin'
    Assert-Content $rollback.MappingTarget 'old-mapping'
    Write-Host 'Update transaction tests passed.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path $resolved -Leaf).StartsWith('TskSkinSwap-transaction-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
