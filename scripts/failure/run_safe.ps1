param(
    [int]$ConnectPauseSeconds = 60,
    [int]$StarRocksDownSeconds = 30,
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

Write-Host "Running safe Day 6 failure scenarios..."

& (Join-Path $RepoRoot "scripts/failure/connect_pause.ps1") -PauseSeconds $ConnectPauseSeconds -EnvFile $EnvFile
& (Join-Path $RepoRoot "scripts/failure/schema_change_agents.ps1") -EnvFile $EnvFile
& (Join-Path $RepoRoot "scripts/failure/starrocks_be_restart.ps1") -DownSeconds $StarRocksDownSeconds -EnvFile $EnvFile

Write-Host "`nSafe Day 6 failure scenarios complete."
Write-Host "Manual/risk-gated scenarios remain: CDC retention exceeded and MinIO low-space simulation."
