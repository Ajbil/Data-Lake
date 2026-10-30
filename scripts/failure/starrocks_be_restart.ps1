param(
    [int]$DownSeconds = 30,
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$ComposeFile = Join-Path $RepoRoot "infra/docker-compose/docker-compose.yml"
$ResolvedEnvFile = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $RepoRoot $EnvFile }

Write-Host "Stopping StarRocks BE for $DownSeconds seconds..."
docker compose --env-file $ResolvedEnvFile -f $ComposeFile stop starrocks-be
if ($LASTEXITCODE -ne 0) {
    throw "Failed to stop StarRocks BE."
}

Start-Sleep -Seconds $DownSeconds

Write-Host "Restarting StarRocks BE..."
docker compose --env-file $ResolvedEnvFile -f $ComposeFile up -d starrocks-be
if ($LASTEXITCODE -ne 0) {
    throw "Failed to restart StarRocks BE."
}

Write-Host "StarRocks BE restart scenario complete."
