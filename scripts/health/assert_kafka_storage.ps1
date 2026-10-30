$ErrorActionPreference = "Stop"

$name = docker ps -a --filter 'name=^/mbs-kafka$' --format '{{.Names}}'
if ($LASTEXITCODE -ne 0) { throw "Docker is unavailable; startup stopped." }
if ($name -eq "mbs-kafka") {
    $broker = docker inspect mbs-kafka | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect Kafka storage; startup stopped." }
    $setting = $broker.Config.Env | Where-Object { $_ -like 'KAFKA_LOG_DIRS=*' }
    $logDir = ($setting -split '=', 2)[1]
    $mount = @($broker.Mounts | Where-Object {
        $_.Name -eq 'mbs-poc_kafka-data' -and $_.Destination -eq $logDir
    })
    if ([string]::IsNullOrWhiteSpace($logDir) -or $mount.Count -ne 1) {
        throw "Kafka logs are not stored in the named kafka-data volume. Back up and migrate the existing broker logs before startup. See docs/decisions/007_kafka_log_storage.md."
    }
}
