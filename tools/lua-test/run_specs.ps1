# run_specs.ps1 — run the busted unit specs locally with plain Lua 5.1.
#
# Finds a Lua 5.1 interpreter, expands the spec list and calls run_specs.lua from the repo root
# (the specs use relative dofile paths, so the working directory matters).
#
#   powershell -ExecutionPolicy Bypass -File tools\lua-test\run_specs.ps1
#   powershell -ExecutionPolicy Bypass -File tools\lua-test\run_specs.ps1 zone     # name filter
#
# Set $env:LUA51 to point at a specific lua.exe. CI's busted remains the gate — see README.md.

param(
    [string]$Filter = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner   = Join-Path $PSScriptRoot "run_specs.lua"

# Candidate interpreters, in order of preference.
$candidates = @()
if ($env:LUA51) { $candidates += $env:LUA51 }
$candidates += "C:\Program Files (x86)\Lua\5.1\lua.exe"   # LuaForWindows, the usual one
$candidates += "lua5.1"
$candidates += "lua"

$lua = $null
foreach ($c in $candidates) {
    $resolved = $null
    if (Test-Path $c) {
        $resolved = $c
    } else {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { $resolved = $cmd.Source }
    }
    if (-not $resolved) { continue }
    # `lua -v` prints to stderr, which an ErrorActionPreference of Stop would turn into a
    # terminating error — hence the local override.
    $version = ""
    try {
        $ErrorActionPreference = "Continue"
        $version = (& $resolved -v 2>&1 | Out-String)
    } catch {
        $version = ""
    } finally {
        $ErrorActionPreference = "Stop"
    }
    if ($version -match "Lua 5\.1") { $lua = $resolved; break }
}

if (-not $lua) {
    Write-Host "[ERROR] No Lua 5.1 interpreter found."
    Write-Host "        Install LuaForWindows (or any lua 5.1) and/or set `$env:LUA51 to its lua.exe."
    Write-Host "        Anything newer than 5.1 will report failures DCS would never see."
    exit 1
}

$specDir = Join-Path $repoRoot "tests\ci\unit"
$specs = Get-ChildItem -Path $specDir -Filter "*.lua" | Sort-Object Name
if ($Filter) { $specs = $specs | Where-Object { $_.Name -like "*$Filter*" } }

if (-not $specs) {
    Write-Host "[ERROR] No spec matches filter '$Filter' in tests\ci\unit."
    exit 1
}

Push-Location $repoRoot
try {
    & $lua $runner "./" ($specs | ForEach-Object { "tests/ci/unit/$($_.Name)" })
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
