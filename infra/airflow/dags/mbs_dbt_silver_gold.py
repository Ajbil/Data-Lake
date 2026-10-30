from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator


DBT_COMMAND = """
set -euo pipefail
export PATH="/home/airflow/.local/bin:${PATH}"
cd /opt/airflow/dbt
dbt run --project-dir /opt/airflow/dbt --profiles-dir /opt/airflow/dbt --target dev
dbt test --project-dir /opt/airflow/dbt --profiles-dir /opt/airflow/dbt --target dev
"""


with DAG(
    dag_id="mbs_daily_operations_report",
    description="Build Daily Operations Report Silver and Gold models from StarRocks/Iceberg every 5 minutes.",
    start_date=datetime(2026, 5, 1),
    schedule_interval="*/5 * * * *",
    catchup=False,
    dagrun_timeout=timedelta(minutes=10),
    max_active_runs=1,
    tags=["mbs", "dbt", "starrocks", "daily-operations-report"],
) as dag:
    run_dbt = BashOperator(
        task_id="run_dbt_daily_operations_report",
        bash_command=DBT_COMMAND,
        env={
            "DBT_PROFILES_DIR": "/opt/airflow/dbt",
            "STARROCKS_DBT_HOST": "starrocks-fe",
            "STARROCKS_MYSQL_PORT": "9030",
            "STARROCKS_CATALOG": "default_catalog",
            "STARROCKS_SCHEMA": "analytics",
            "STARROCKS_USER": "root",
            "STARROCKS_PASSWORD": "",
        },
    )
