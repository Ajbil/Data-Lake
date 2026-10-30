param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
)

$ErrorActionPreference = "Stop"

$venvPython = Join-Path $RepoRoot ".venv/Scripts/python.exe"
$requirements = Join-Path $RepoRoot "requirements-day3.txt"

if (-not (Test-Path $requirements)) {
    throw "Missing Day 3 requirements file: $requirements"
}

if (-not (Test-Path $venvPython)) {
    $bundledPython = Join-Path $env:USERPROFILE ".cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"

    if (Test-Path $bundledPython) {
        & $bundledPython -m venv (Join-Path $RepoRoot ".venv")
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 -m venv (Join-Path $RepoRoot ".venv")
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        & python -m venv (Join-Path $RepoRoot ".venv")
    } else {
        throw "Python 3 was not found. Install Python 3 or run from the Codex desktop runtime."
    }
}

& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r $requirements

Write-Host "Day 3 Python environment is ready at .venv."
