$ErrorActionPreference = "Stop"
$guard = Join-Path $PSScriptRoot "assert_kafka_storage.ps1"
$health = Join-Path $PSScriptRoot "day3_verify_iceberg_sink_plugin.ps1"

function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    $message = ""
    try { & $Action } catch { $message = $_.Exception.Message }
    if ($message -notmatch $Pattern) { throw "Expected '$Pattern'; got '$message'." }
}

# These are the actual old/new broker layouts, without a live Docker dependency.
function docker {
    $global:LASTEXITCODE = 0
    if ($args[0] -eq "ps") { return "mbs-kafka" }
    if ($args[0] -ne "inspect") { throw "Unexpected Docker mutation in a storage check." }
    $dir = if ($global:MbsTestLegacy) { "/tmp/kraft-combined-logs" } else { "/var/lib/kafka/data" }
    $dest = if ($global:MbsTestLegacy) { "/bitnami/kafka" } else { "/var/lib/kafka/data" }
    return (@{
        Config = @{ Env = @("KAFKA_LOG_DIRS=$dir") }
        Mounts = @(@{ Name = "mbs-poc_kafka-data"; Destination = $dest })
    } | ConvertTo-Json -Depth 5)
}

function Invoke-RestMethod {
    param([string]$Uri, [int]$TimeoutSec)
    if ($Uri -like "*/connector-plugins") {
        return [pscustomobject]@{ class = "org.apache.iceberg.connect.IcebergSinkConnector"; version = "1.8.1" }
    }
    if ($Uri -like "*/connectors") { return $global:MbsTestNames }
    if ($Uri -like "*/status" -and $global:MbsTestNames.Count -gt 0) {
        return [pscustomobject]@{
            connector = [pscustomobject]@{ state = "RUNNING" }
            tasks = @([pscustomobject]@{ id = 0; state = $global:MbsTestTaskState; trace = "Caused by: test failure" })
        }
    }
    throw "No status found for connector: 404"
}

try {
    $global:MbsTestLegacy = $true
    Expect-Failure { & $guard } "logs are not stored"
    $global:MbsTestLegacy = $false
    & $guard
    Write-Host "PASS: unsafe old storage rejected; persistent storage accepted."

    $global:MbsTestNames = @()
    Expect-Failure { & $health } "required connectors are not registered"
    Write-Host "PASS: installed plugin with empty registrations gives a clear failure."

    # Reuse the canonical connector list; test status handling, not duplicated names.
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($health, [ref]$tokens, [ref]$errors)
    $assignment = $ast.Find({ param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$connectors'
    }, $true)
    $global:MbsTestNames = @("mbs-sqlserver-cdc") + @(Invoke-Expression $assignment.Right.Extent.Text)
    $global:MbsTestTaskState = "FAILED"
    Expect-Failure { & $health } "task 0 is FAILED"
    $global:MbsTestTaskState = "RUNNING"
    & $health
    Write-Host "PASS: failed tasks rejected; all healthy tasks accepted."
} finally {
    Remove-Variable -Scope Global -Name MbsTestLegacy, MbsTestNames, MbsTestTaskState -ErrorAction SilentlyContinue
}
