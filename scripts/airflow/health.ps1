param(
    [string]$EnvFile = ".env",
    [int]$TimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$ComposeFile = Join-Path $RepoRoot "infra/docker-compose/docker-compose.yml"
$ResolvedEnvFile = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $RepoRoot $EnvFile }
$DagId = "mbs_daily_operations_report"
$RunId = "health_$([guid]::NewGuid().ToString('N'))"
$RunDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")

Push-Location $RepoRoot
try {
    Write-Host "Checking Airflow containers..."
    docker compose --env-file $ResolvedEnvFile -f $ComposeFile ps airflow-db airflow-webserver airflow-scheduler
    if ($LASTEXITCODE -ne 0) {
        throw "Airflow container status check failed with exit code $LASTEXITCODE."
    }

    Write-Host "`nListing MBS DAG..."
    docker exec mbs-airflow-scheduler bash -lc "airflow dags list | grep mbs_daily_operations_report"
    if ($LASTEXITCODE -ne 0) {
        throw "MBS Airflow DAG was not found."
    }

    Write-Host "`nUnpausing MBS DAG..."
    docker exec mbs-airflow-scheduler bash -lc "airflow dags unpause mbs_daily_operations_report"
    if ($LASTEXITCODE -ne 0) {
        throw "MBS Airflow DAG could not be unpaused."
    }

    Write-Host "`nTriggering scheduler-managed verification run $RunId..."
    docker exec mbs-airflow-scheduler airflow dags trigger --run-id $RunId $DagId
    if ($LASTEXITCODE -ne 0) {
        throw "Airflow verification run could not be triggered."
    }

    # Scheduler-managed runs obey the DAG's max_active_runs=1, including during health checks.
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $runsJson = docker exec mbs-airflow-scheduler airflow dags list-runs -d $DagId --start-date $RunDate --output json
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read Airflow verification run $RunId."
        }
        $run = ($runsJson | Out-String | ConvertFrom-Json) | Where-Object { $_.run_id -eq $RunId }
        $state = if ($run) { $run.state } else { "not visible yet" }
        Write-Host "Airflow verification run ${RunId}: $state"
        if ($state -eq "success") {
            Write-Host "`nAirflow Daily Operations Report verification complete."
            return
        }
        if ($state -eq "failed") {
            throw "Airflow verification run $RunId failed. Task logs: /opt/airflow/logs/dag_id=$DagId/run_id=$RunId/task_id=run_dbt_daily_operations_report/ in mbs-airflow-scheduler. See docs/runbooks/03_airflow_failures.md; the UI at http://localhost:8088 is optional."
        }
        if ((Get-Date) -ge $deadline) {
            throw "Timed out waiting for Airflow run $RunId after $TimeoutSeconds seconds. Last state: $state. Inspect the run before retrying."
        }
        Start-Sleep -Seconds 10
    } while ($true)
}
finally {
    Pop-Location
}
