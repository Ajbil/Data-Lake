param(
    [int]$PauseSeconds = 600,
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$ComposeFile = Join-Path $RepoRoot "infra/docker-compose/docker-compose.yml"
$ResolvedEnvFile = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $RepoRoot $EnvFile }

Write-Host "Stopping Kafka Connect for $PauseSeconds seconds..."
docker compose --env-file $ResolvedEnvFile -f $ComposeFile stop kafka-connect
if ($LASTEXITCODE -ne 0) {
    throw "Failed to stop Kafka Connect."
}

Start-Sleep -Seconds $PauseSeconds

Write-Host "Restarting Kafka Connect..."
docker compose --env-file $ResolvedEnvFile -f $ComposeFile up -d kafka-connect
if ($LASTEXITCODE -ne 0) {
    throw "Failed to restart Kafka Connect."
}

Write-Host "Kafka Connect pause/restart scenario complete."
