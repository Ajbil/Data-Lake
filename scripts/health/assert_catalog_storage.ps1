$ErrorActionPreference = "Stop"

# Existing writable-layer catalogs must be copied before Compose replaces them.
$catalog = docker ps -a --filter 'name=^/mbs-iceberg-rest$' --format '{{.Names}}'
if ($LASTEXITCODE -ne 0) { throw "Docker is unavailable; startup stopped." }
if ($catalog -eq "mbs-iceberg-rest") {
    $mounts = docker inspect mbs-iceberg-rest --format '{{json .Mounts}}' | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect catalog storage; startup stopped." }
    if (@($mounts | Where-Object Destination -eq "/catalog").Count -eq 0) {
        throw "Existing Iceberg catalog has no persistent storage. Back up and migrate it using docs/runbooks/02_poc_execution.md before startup; replacing it now would lose table registrations."
    }
}
