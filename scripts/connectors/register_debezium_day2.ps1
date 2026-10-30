param(
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

function Read-DotEnv {
    param([string]$Path)

    $values = @{}
    Get-Content -Path $Path | ForEach-Object {
        if ($_ -match "^\s*#" -or $_ -notmatch "=") {
            return
        }

        $key, $value = $_ -split "=", 2
        $values[$key.Trim()] = $value.Trim()
    }

    return $values
}

if (-not (Test-Path $EnvFile)) {
    throw "Expected $EnvFile to exist. Copy .env.example to .env first."
}

$envValues = Read-DotEnv -Path $EnvFile
if (-not $envValues.ContainsKey("MSSQL_HOST")) {
    $envValues["MSSQL_HOST"] = "sqlserver"
}
if (-not $envValues.ContainsKey("MSSQL_PORT")) {
    $envValues["MSSQL_PORT"] = "1433"
}
if (-not $envValues.ContainsKey("MSSQL_CAPTURE_DATABASES")) {
    $envValues["MSSQL_CAPTURE_DATABASES"] = "EKYC_ICICI,EKYC_ICICI_Archived"
}
if (-not $envValues.ContainsKey("KAFKA_TOPIC_PREFIX")) {
    $envValues["KAFKA_TOPIC_PREFIX"] = "mbs_poc"
}
$templatePath = "infra/kafka-connect/connectors/debezium-sqlserver-mbs-poc.template.json"
$body = Get-Content -Raw -Path $templatePath

foreach ($key in $envValues.Keys) {
    $body = $body.Replace("`${$key}", $envValues[$key])
}

$connectorName = "mbs-sqlserver-cdc"
$uri = "http://localhost:8083/connectors/$connectorName/config"

Write-Host "Registering Debezium connector $connectorName"
$registered = Invoke-RestMethod -Method Put -Uri $uri -Body $body -ContentType "application/json"
Write-Host "Registered $($registered.name); task assignments will appear after startup."
