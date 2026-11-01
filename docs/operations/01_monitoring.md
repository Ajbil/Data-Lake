# Monitoring Operations

Historical proposal, not a deployed stack. Current Compose does not install
Prometheus, Grafana, Loki or a log collector. The implemented checks use connector
task status, Raw/SQL queries and Airflow/dbt logs; see the
[recovery guide](../runbooks/03_airflow_failures.md). The tools/dashboards below are
older planning context and would need a new review before implementation.

## Purpose

Provide lightweight POC observability without turning this work into a production monitoring project.

## Monitoring Philosophy

The primary debugging tools remain Kafka UI, Airflow UI, MinIO Console, StarRocks FE UI, and service logs. Prometheus, Grafana, Loki, and Promtail centralize basic health signals and logs.

## Why These Tools

| Tool | Why chosen | Receives from | Supports next |
| --- | --- | --- | --- |
| Prometheus | Pull-based metrics collection that is easy to self-host. | Service/exporter metrics | Grafana health panels |
| Grafana | Common dashboard surface for metrics and logs. | Prometheus and Loki | Operator demo visibility |
| Loki | Lightweight log aggregation paired with Grafana. | Promtail | Faster failure diagnosis |
| Promtail | Simple log shipper for container logs. | Docker/container logs | Loki queries |

## Minimum Dashboards

- Container/service up status.
- Kafka Connect connector health if metrics are exposed.
- Kafka topic lag if practical.
- MinIO bucket/object health if metrics are exposed.
- StarRocks FE/BE availability.
- Airflow scheduler and DAG status if practical.
- Loki log search by service/container.

## Alerting

No production alerting is required. Visible dashboard panels and runbook checks are enough for the POC.

## Evidence

- Screenshot of Grafana health dashboard.
- Screenshot of Loki logs for one restart/failure scenario.
- Notes on missing or intentionally skipped metrics.
