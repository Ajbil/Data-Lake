param(
    [string]$EnvFile = ".env",
    [string]$SqlContainer = "mbs-sqlserver"
)

$ErrorActionPreference = "Stop"

function Import-DotEnv {
    param([string]$Path)

    Get-Content -Path $Path | ForEach-Object {
        if ($_ -match "^\s*#" -or $_ -notmatch "=") {
            return
        }
        $key, $value = $_ -split "=", 2
        [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), "Process")
    }
}

Import-DotEnv -Path $EnvFile

$sql = @"
USE mbs_poc;
SET NOCOUNT ON;

IF COL_LENGTH('dbo.agents', 'day6_schema_probe') IS NULL
BEGIN
    ALTER TABLE dbo.agents ADD day6_schema_probe NVARCHAR(50) NULL;
END;

EXEC sys.sp_executesql N'
UPDATE dbo.agents
SET day6_schema_probe = CONCAT(N''day6-schema-'', FORMAT(SYSUTCDATETIME(), ''yyyyMMddHHmmss'')),
    updated_at = SYSUTCDATETIME()
WHERE agent_id = 1;

SELECT agent_id, agent_code, day6_schema_probe, updated_at
FROM dbo.agents
WHERE agent_id = 1;
';
"@

$sql | docker exec -i $SqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $env:MSSQL_SA_PASSWORD -C -b
if ($LASTEXITCODE -ne 0) {
    throw "Agent schema-change scenario failed."
}

Write-Host "Agent schema-change scenario complete."
