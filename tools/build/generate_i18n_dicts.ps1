# generate_i18n_dicts.ps1
# Scans all src/*.lua files for ctld.tr() calls and synchronises the
# 4 dictionary files (CTLD_i18n_en/fr/es/ko.lua).
#
# Rule: ctld.tr() keys are ALWAYS complete string literals.
# Variable parts use %1, %2 ... placeholders. Never build keys by concatenation.
# This guarantees 100% reliable static scan.
#
# Versioning policy:
#   Each dictionary has its own independent translation_version.
#   Dictionaries are maintained independently, possibly by different people.
#   Each dict's version is bumped when IT is modified (not when others change).
#   ctld.i18n_check() will flag version mismatches as a signal that a dict
#   may be lagging behind EN and needs review.
#
# Modes:
#   Default (no args) : dry-run — reports what would change, writes nothing.
#   -Apply            : applies changes to dict files on disk.
#
# Per-dict changes applied with -Apply:
#   MISSING keys    -> appended at end of file (EN: value=key, others: value="")
#   STALE keys      -> line prefixed with "-- STALE:" (not deleted — confirm manually)
#   SUPERSEDED keys -> commented-out line deleted (a live line for that key exists)
#   version bump    -> each modified dict gets its own version incremented, except when
#                      a SUPERSEDED purge is the only change (no translation content moved)
#
# Usage (from repo root or from build/):
#   .\build\generate_i18n_dicts.ps1           # dry-run
#   .\build\generate_i18n_dicts.ps1 -Apply    # apply

param(
    [switch]$Apply,
    [string]$SourceDir = "",
    [string]$DictDir   = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# One segment at a time: merge_CTLD.ps1 calls this script, and both now run on Linux too.
$repoRoot  = Resolve-Path (Join-Path (Join-Path $scriptDir "..") "..")

if ($SourceDir -eq "") { $SourceDir = Join-Path $repoRoot "src" }
if ($DictDir   -eq "") { $DictDir   = $SourceDir }

$DictFiles = [ordered]@{
    "en" = (Join-Path $DictDir "CTLD_i18n_en.lua")
    "fr" = (Join-Path $DictDir "CTLD_i18n_fr.lua")
    "es" = (Join-Path $DictDir "CTLD_i18n_es.lua")
    "ko" = (Join-Path $DictDir "CTLD_i18n_ko.lua")
}

$excludeNames = ($DictFiles.Values | ForEach-Object { Split-Path -Leaf $_ }) + @("CTLD_i18n.lua")

Write-Host ""
if ($Apply) {
    Write-Host "=== CTLD i18n dictionary sync — APPLY MODE ===" -ForegroundColor Cyan
} else {
    Write-Host "=== CTLD i18n dictionary sync — DRY RUN (use -Apply to write) ===" -ForegroundColor Yellow
}
Write-Host "Source dir : $SourceDir"
Write-Host ""

# =============================================================================
# Step 1: Collect all ctld.tr() keys from source (excluding dict files)
# =============================================================================
$sourceFiles = Get-ChildItem -Path $SourceDir -Recurse -Filter "*.lua" |
    Where-Object { $excludeNames -notcontains $_.Name }

$usedKeys = [System.Collections.Generic.HashSet[string]]::new()

foreach ($file in $sourceFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    # Keys are ALWAYS complete string literals — no concatenation allowed (see specs/i18n_rules.md)
    $found = [regex]::Matches($content, 'ctld\.tr\s*\(\s*"((?:[^"\\]|\\.)*)"')
    foreach ($m in $found) {
        [void]$usedKeys.Add($m.Groups[1].Value)
    }
}

$trKeyCount = $usedKeys.Count
Write-Host "Keys found via ctld.tr() in source: $trKeyCount"

# =============================================================================
# Step 1b: Collect the config catalogue's desc/name label values.
# These are i18n keys the loader translates at runtime via tr(v) on every
# desc/name at any depth — invisible to the ctld.tr("...") scan above, and no
# longer present as a generated Lua module (CTLD-TOOLS-CORE ticket 05: the build
# embeds the YAML string instead). Scan the YAML source of truth directly.
# =============================================================================
$configYaml = Join-Path $SourceDir "CTLD_config.yaml"
if (Test-Path $configYaml) {
    foreach ($line in (Get-Content $configYaml -Encoding UTF8)) {
        $m = [regex]::Match($line, '^\s*(?:-\s+)?(?:desc|name):\s*(.+?)\s*$')
        if (-not $m.Success) { continue }
        $val = $m.Groups[1].Value
        # Strip a surrounding pair of matching YAML quotes if present (values are
        # simple scalars today; this keeps parity if one ever gets quoted).
        if ($val.Length -ge 2 -and
            (($val[0] -eq '"'  -and $val[$val.Length - 1] -eq '"') -or
             ($val[0] -eq "'"  -and $val[$val.Length - 1] -eq "'"))) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        if ($val -ne "") { [void]$usedKeys.Add($val) }
    }
    Write-Host "Keys found via config YAML desc/name: $($usedKeys.Count - $trKeyCount)"
}

Write-Host "Total keys tracked: $($usedKeys.Count)"
Write-Host ""

# =============================================================================
# Helpers
# =============================================================================

$EntryPattern = 'ctld\.i18n\["[^"]+"\]\["((?:[^"\\]|\\.)*)"\]'

function Get-DictKeys([string]$filePath) {
    # A "-- STALE: " (or any "-- ") commented line is not a live entry - skipped, so a dead
    # key already marked stale doesn't keep being reported as present in this dictionary.
    return (Get-DictKeysByState $filePath $false)
}

function Get-DeadDictKeys([string]$filePath) {
    # The mirror of Get-DictKeys: the keys carried by commented-out entries only. A key found
    # by both is SUPERSEDED - a dead line left behind by a revival, which -Apply deletes.
    return (Get-DictKeysByState $filePath $true)
}

function Get-DictKeysByState([string]$filePath, [bool]$wantCommented) {
    $keys = [System.Collections.Generic.HashSet[string]]::new()
    if (-not (Test-Path $filePath)) { return $keys }
    foreach ($line in (Get-Content $filePath -Encoding UTF8)) {
        if ($line.TrimStart().StartsWith("--") -ne $wantCommented) { continue }
        $m = [regex]::Match($line, $EntryPattern)
        if ($m.Success) {
            [void]$keys.Add($m.Groups[1].Value)
        }
    }
    return $keys
}

function Get-DictVersion([string]$filePath) {
    $raw = Get-Content $filePath -Raw -Encoding UTF8
    if ($raw -match 'translation_version\s*=\s*"([^"]+)"') { return $Matches[1] }
    return "1.0"
}

function Bump-Version([string]$ver) {
    $parts = $ver.Split('.')
    if ($parts.Length -ge 2) {
        $parts[$parts.Length - 1] = ([int]$parts[$parts.Length - 1] + 1).ToString()
        return ($parts -join '.')
    }
    return $ver
}

# =============================================================================
# Step 2: Process each dict file independently
# =============================================================================
$anyApplied = $false

foreach ($lang in $DictFiles.Keys) {
    $filePath   = $DictFiles[$lang]
    $filename   = Split-Path -Leaf $filePath
    $dictKeys   = Get-DictKeys $filePath
    $deadKeys   = Get-DeadDictKeys $filePath
    $currentVer = Get-DictVersion $filePath

    $missing = @($usedKeys | Where-Object { -not $dictKeys.Contains($_) } | Sort-Object)
    $stale   = @($dictKeys  | Where-Object { -not $usedKeys.Contains($_) } | Sort-Object)
    # A commented entry whose key is also live: the dead half of a revived key, kept by
    # mistake. Inert at runtime, but a translator editing that line sees no effect.
    $superseded = @($deadKeys | Where-Object { $dictKeys.Contains($_) } | Sort-Object)

    Write-Host "--- $filename ($lang) | version $currentVer ---"

    if ($missing.Count -eq 0 -and $stale.Count -eq 0 -and $superseded.Count -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
        Write-Host ""
        continue
    }

    foreach ($k in $missing)    { Write-Host "  MISSING    : [$k]" -ForegroundColor Red }
    foreach ($k in $stale)      { Write-Host "  STALE      : [$k]" -ForegroundColor Yellow }
    foreach ($k in $superseded) { Write-Host "  SUPERSEDED : [$k]" -ForegroundColor DarkYellow }

    if (-not $Apply) {
        Write-Host ""
        continue
    }

    # ---- Apply changes ----
    $raw     = Get-Content $filePath -Raw -Encoding UTF8
    $changed = $false

    # Delete superseded lines: a commented-out entry for a key that also has a live line.
    # Matches the whole line (with its newline) only when it starts with "--" AND carries
    # this key's entry, so a commented __keep_en member — which has no ctld.i18n[...] entry
    # — is never touched. Every occurrence goes, not just the first.
    foreach ($k in $superseded) {
        $ek      = [regex]::Escape($k)
        $pattern = "(?m)^--.*ctld\.i18n\[`"$lang`"\]\[`"$ek`"\].*\r?\n"
        if ([regex]::IsMatch($raw, $pattern)) {
            $raw     = [regex]::Replace($raw, $pattern, '')
            $changed = $true
        }
    }

    # Mark stale keys: prefix the matching line with "-- STALE: "
    foreach ($k in $stale) {
        $ek      = [regex]::Escape($k)
        $pattern = "(?m)^(ctld\.i18n\[`"$lang`"\]\[`"$ek`"\].+)$"
        if ([regex]::IsMatch($raw, $pattern)) {
            $raw     = [regex]::Replace($raw, $pattern, '-- STALE: $1')
            $changed = $true
        }
    }

    # Append missing keys at end of file
    if ($missing.Count -gt 0) {
        $date  = (Get-Date).ToString("yyyy-MM-dd")
        $block = "`r`n--- Keys added by generate_i18n_dicts.ps1 on $date`r`n"
        foreach ($k in $missing) {
            if ($lang -eq "en") {
                $block += "ctld.i18n[`"en`"][`"$k`"] = `"$k`"`r`n"
            } else {
                $block += "ctld.i18n[`"$lang`"][`"$k`"] = `"`"`r`n"
            }
        }
        $raw    += $block
        $changed = $true
    }

    # Bump this dict's own version — but not when a purge is all that happened. The version
    # exists so ctld.i18n_check() can flag a dict lagging behind EN in *content*; deleting
    # inert comments moves no translation, and a bump would signal drift that did not occur.
    if ($changed) {
        $newVer = $currentVer
        if ($missing.Count -gt 0 -or $stale.Count -gt 0) {
            $newVer = Bump-Version $currentVer
            $raw    = [regex]::Replace($raw,
                '(translation_version\s*=\s*)"[^"]+"',
                "`$1`"$newVer`"")
        }

        [System.IO.File]::WriteAllText($filePath, $raw, [System.Text.UTF8Encoding]::new($false))
        Write-Host ("  APPLIED : {0} added, {1} staled, {2} purged | {3} -> {4}" -f `
            $missing.Count, $stale.Count, $superseded.Count, $currentVer, $newVer) -ForegroundColor Cyan
        $anyApplied = $true
    }

    Write-Host ""
}

# =============================================================================
# Summary
# =============================================================================
if (-not $Apply) {
    Write-Host "Dry run complete. Run with -Apply to apply changes." -ForegroundColor Yellow
} elseif ($anyApplied) {
    Write-Host "Sync complete. Fill in empty translations in modified dict files." -ForegroundColor Green
} else {
    Write-Host "All dictionaries are already in sync." -ForegroundColor Green
}
Write-Host ""
