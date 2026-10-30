param(
    [string]$Python = ".\.venv\Scripts\python.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Python)) {
    throw "Expected Python virtualenv at $Python. Run the earlier bootstrap first or create .venv."
}

Write-Host "Installing dbt-starrocks dependencies..."
& $Python -m pip install -r requirements-day4.txt
if ($LASTEXITCODE -ne 0) {
    throw "dbt dependency install failed with exit code $LASTEXITCODE."
}

Write-Host "dbt dependencies are ready."
