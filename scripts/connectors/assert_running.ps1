param(
    [Parameter(Mandatory = $true)]
    [string[]]$Names
)

$ErrorActionPreference = "Stop"
foreach ($name in $Names) {
    $status = Invoke-RestMethod -Uri "http://localhost:8083/connectors/$name/status" -TimeoutSec 5
    if ($status.connector.state -ne "RUNNING" -or @($status.tasks).Count -eq 0) {
        throw "Connector '$name' is not ready (state=$($status.connector.state), tasks=$(@($status.tasks).Count)). Run health:iceberg before retrying the latency test."
    }
    foreach ($task in $status.tasks) {
        if ($task.state -ne "RUNNING") {
            $cause = @($task.trace -split "`n" | Where-Object { $_ -match '^Caused by:' }) | Select-Object -First 1
            if (-not $cause) { $cause = ($task.trace -split "`n")[0] }
            throw "Connector '$name' task $($task.id) is $($task.state). $cause Run health:iceberg before retrying the latency test."
        }
    }
}
