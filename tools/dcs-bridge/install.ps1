# install.ps1 - Install/upgrade VEAF-dcs-bridge into a project-local venv.
# Creates tools/dcs-bridge/venv/ (gitignored) so `.mcp.json` can reference dcs-client
# by a portable path (${CLAUDE_PROJECT_DIR}) instead of relying on the system PATH.
# Usage: powershell -ExecutionPolicy Bypass -File tools/dcs-bridge/install.ps1

param(
    # Package source. Defaults to the develop branch of the public repo (no release
    # published yet). Once a `published-v*` tag exists, switch this to a versioned
    # git ref (e.g. "git+https://github.com/VEAF/VEAF-dcs-bridge.git@published-v0.7.0")
    # or, if published to PyPI, simply "dcs-bridge".
    [string]$Source = "git+https://github.com/VEAF/VEAF-dcs-bridge.git@develop"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvDir   = Join-Path $scriptDir "venv"
$venvPy    = Join-Path $venvDir "Scripts\python.exe"
$dcsClient = Join-Path $venvDir "Scripts\dcs-client.exe"

$pythonCmd = Get-Command py -ErrorAction SilentlyContinue
if (-not $pythonCmd) { $pythonCmd = Get-Command python -ErrorAction SilentlyContinue }
if (-not $pythonCmd) {
    Write-Error "No Python interpreter found on PATH (tried 'py' and 'python'). Install Python 3.11+ first."
    exit 1
}

if (-not (Test-Path $venvPy)) {
    Write-Host "Creating venv at $venvDir ..."
    & $pythonCmd.Source -m venv $venvDir
}

Write-Host "Installing $Source ..."
& $venvPy -m pip install --upgrade pip --quiet
& $venvPy -m pip install --upgrade $Source

if (-not (Test-Path $dcsClient)) {
    Write-Error "Install completed but dcs-client.exe was not found at $dcsClient"
    exit 1
}

Write-Host ""
Write-Host "OK - dcs-client installed at $dcsClient"
Write-Host "Next steps:"
Write-Host "  1. Copy dcs-client.yaml.template (from the dcs-serve host) to dcs-client.yaml at the repo root,"
Write-Host "     set api_key to match dcs-serve.yaml. dcs-client.yaml is gitignored (machine-local secret)."
Write-Host "  2. Start dcs-serve on the machine hosting the live DCS mission."
Write-Host "  3. The dcs-bridge MCP server (tools/dcs-bridge/venv) is wired in .mcp.json - restart Claude Code"
Write-Host "     to pick it up if this is the first install."
