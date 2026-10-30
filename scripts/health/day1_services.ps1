$ErrorActionPreference = "Stop"

Write-Host "Docker Compose services:"
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml ps

Write-Host "`nSchema Registry:"
try {
    Invoke-RestMethod -Uri http://localhost:8081/subjects -TimeoutSec 5 | ConvertTo-Json -Compress
} catch {
    Write-Host "Schema Registry not ready: $($_.Exception.Message)"
}

Write-Host "`nKafka Connect:"
try {
    Invoke-RestMethod -Uri http://localhost:8083/connectors -TimeoutSec 5 | ConvertTo-Json -Compress
} catch {
    Write-Host "Kafka Connect not ready: $($_.Exception.Message)"
}

Write-Host "`nKafka UI:"
try {
    $response = Invoke-WebRequest -UseBasicParsing http://localhost:8080 -TimeoutSec 5
    Write-Host "Kafka UI HTTP status: $($response.StatusCode)"
} catch {
    Write-Host "Kafka UI not ready: $($_.Exception.Message)"
}
