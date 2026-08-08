# merge_CTLD.ps1 - Local build script for CTLD.lua
# Output: UTF-8 WITHOUT BOM (required by DCS Lua engine).
# Compatible with PowerShell 5 and 7.
# Usage: powershell -ExecutionPolicy Bypass -File tools/build/merge_CTLD.ps1
#        ... -VersionSuffix a1b2c3d   (dev build: stamps ctld.VERSION as <version>-<suffix>)

param(
    # Appended to ctld.VERSION, in the header *and* in the merged source, so `--version`,
    # the install report and the DCS log all name the same build. Used by the dev-build
    # workflow with the commit hash (FEAT-DEV-BUILD-CHANNEL); empty for a local or release
    # build, which must keep the version as written in src/CTLD_config.lua.
    [string]$VersionSuffix = ""
)

$ErrorActionPreference = "Stop"

# The suffix lands inside a Lua string literal: keep it to characters that cannot close it
# or break the line.
if ($VersionSuffix -and $VersionSuffix -notmatch '^[A-Za-z0-9._-]+$') {
    Write-Host "[ERROR] -VersionSuffix must match ^[A-Za-z0-9._-]+$ (got '$VersionSuffix')."
    exit 1
}

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
# Composed one segment at a time: a literal "..\.." is a Windows-only path, and this script also
# runs on the Linux runner that tests ctld-tools (CHORE-UNTRACK-BUILT-ENGINE).
$repoRoot    = Resolve-Path (Join-Path (Join-Path $scriptDir "..") "..")
$listFile    = Join-Path $scriptDir "listToMerge.txt"
$srcDir      = Join-Path $repoRoot  "src"
$outFile     = Join-Path $repoRoot  "CTLD.lua"
$distDir     = Join-Path $repoRoot  "dist"
$userCfgSrc  = Join-Path $srcDir    "CTLD_userConfig.lua"
$userCfgDest = Join-Path $distDir   "CTLD_userConfig.lua"

$ctldToolsDir = Join-Path (Join-Path $repoRoot "tools") "ctld-tools"
$configYaml   = Join-Path $srcDir   "CTLD_config.yaml"

# Synchronise the i18n dictionary files with ctld.tr() keys found in src/.
# Runs in -Apply mode: appends missing keys as empty stubs, prefixes stale keys.
# The build continues even when stubs are added — fill translations in a follow-up commit.
$dictScript = Join-Path $scriptDir "generate_i18n_dicts.ps1"
Write-Host "Syncing i18n dictionaries (generate_i18n_dicts.ps1 -Apply)..."
# generate_i18n_dicts.ps1 is a PowerShell script: it signals failure by throwing (caught
# below under $ErrorActionPreference = "Stop"), not via $LASTEXITCODE — which a .ps1 call
# leaves untouched, so it must not be inspected here.
try {
    & $dictScript -Apply
}
catch {
    Write-Host "[ERROR] i18n dict sync failed: $_"
    exit 1
}

# Auto-translate empty i18n stubs via Claude API (local only, requires ANTHROPIC_API_KEY).
# Non-blocking: any error prints a WARNING and the build continues.
if ($env:ANTHROPIC_API_KEY) {
    $translateScript = Join-Path $scriptDir "translate_i18n.py"
    $pythonCmd = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } `
                 elseif (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } `
                 else { $null }
    if (-not $pythonCmd) {
        Write-Host "[WARNING] ANTHROPIC_API_KEY is set but Python not found -- skipping i18n auto-translate."
    } elseif (-not (Test-Path $translateScript)) {
        Write-Host "[WARNING] translate_i18n.py not found at $translateScript -- skipping i18n auto-translate."
    } else {
        Write-Host "Translating i18n stubs (translate_i18n.py)..."
        & $pythonCmd $translateScript
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[WARNING] translate_i18n.py exited with code $LASTEXITCODE -- stubs remain empty."
        }
    }
}

# UTF-8 without BOM encoder (works on PS 5 and PS 7)
$utf8NoBOM = [System.Text.UTF8Encoding]::new($false)

# Embed the canonical config YAML verbatim as a Lua string module (ctld.configDefault).
# The complete-config loader (FEAT-CONFIG-YAML-COMPLETE ticket 04) parses this string at
# runtime; this build step only makes it available. Merged after the i18n modules. The
# wrap (dynamic long-bracket level) lives in the ctld-tools core so the lot-3 MM export
# (ctld.configUser) reuses the exact same logic — see CTLD-TOOLS-CORE ticket 05.
$configDefaultLua = Join-Path $srcDir "CTLD_config_default_yaml.lua"
Write-Host "Embedding CTLD_config.yaml -> ctld.configDefault (ctld-tools embed)..."
Push-Location $ctldToolsDir
try {
    & poetry run ctld-tools embed --yaml $configYaml --out $configDefaultLua --var configDefault
    if ($LASTEXITCODE -ne 0) { throw "embed returned $LASTEXITCODE" }
}
catch {
    Write-Host "[ERROR] Could not embed CTLD_config.yaml via ctld-tools."
    Write-Host "        Run 'poetry install' in tools/ctld-tools first (needs Python + poetry)."
    Pop-Location
    exit 1
}
Pop-Location

# Extract ctld.VERSION from CTLD_config.lua
$configFile = Join-Path $srcDir "CTLD_config.lua"
$versionLine = Select-String -Path $configFile -Pattern 'ctld\.VERSION\s*=\s*"([^"]+)"' | Select-Object -First 1
$ctldVersion = if ($versionLine) { $versionLine.Matches[0].Groups[1].Value } else { "unknown" }
if ($VersionSuffix) { $ctldVersion = "$ctldVersion-$VersionSuffix" }
$buildDate = (Get-Date).ToString("yyyy-MM-dd")

# Accumulate all output in a StringBuilder for a single write
$sb = [System.Text.StringBuilder]::new()

$null = $sb.AppendLine('---@meta')
$null = $sb.AppendLine('---@diagnostic disable')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('--[[')
$null = $sb.AppendLine("    CTLD.lua - Combined Transport and Logistics Dispatcher for DCS World")
$null = $sb.AppendLine("    Version : $ctldVersion")
$null = $sb.AppendLine("    Built   : $buildDate")
$null = $sb.AppendLine("    Source  : https://github.com/VEAF/CTLD")
$null = $sb.AppendLine("    Licence : MIT")
$null = $sb.AppendLine("    DO NOT EDIT - generated by tools/build/merge_CTLD.ps1")
$null = $sb.AppendLine(']]')
$null = $sb.AppendLine('')

$warnings = 0
$merged   = 0

foreach ($line in (Get-Content $listFile)) {
    # Skip comment lines and blank lines
    if ($line -match '^\s*(--|$)') { continue }

    $file = Join-Path $srcDir $line
    if (-not (Test-Path $file)) {
        Write-Host "[WARNING] File not found in src/: $line"
        $warnings++
        continue
    }

    $text = [System.IO.File]::ReadAllText($file)
    # A dev build stamps the commit into the ctld.VERSION assignment itself, not only into the
    # header comment: `--version`, the install report and resources.ctld_version() all read the
    # assignment out of the built engine.
    if ($VersionSuffix) {
        $text = [regex]::Replace($text, '(ctld\.VERSION\s*=\s*")([^"]+)(")', ('${1}${2}-' + $VersionSuffix + '${3}'))
    }

    $null = $sb.AppendLine('-- ====================================================================================================')
    $null = $sb.AppendLine("-- Start : $line")
    $null = $sb.AppendLine($text)
    $null = $sb.AppendLine("-- End : $line")
    $merged++
}

# Single write - UTF-8 without BOM
[System.IO.File]::WriteAllText($outFile, $sb.ToString(), $utf8NoBOM)

$size = (Get-Item $outFile).Length
Write-Host ""
Write-Host "Merged  : $merged file(s)"
if ($warnings -gt 0) { Write-Host "Skipped : $warnings file(s) not found (warnings only)" }
Write-Host "Output  : $outFile ($size bytes)"

if ($merged -eq 0) {
    Write-Host "[ERROR] No files were merged - output is empty."
    exit 1
}

# Verify no BOM
$bytes = [System.IO.File]::ReadAllBytes($outFile)
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "[ERROR] BOM detected in output - aborting."
    exit 1
}

Write-Host "OK - no BOM detected."

# Copy CTLD_userConfig.lua to dist/ as a standalone MM template
if (-not (Test-Path $userCfgSrc)) {
    Write-Error "CTLD_userConfig.lua not found at '$userCfgSrc'. Ensure the source file exists before building."
    exit 1
}
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
Copy-Item -Path $userCfgSrc -Destination $userCfgDest -Force
Write-Host "Copied  : CTLD_userConfig.lua → dist/CTLD_userConfig.lua"
