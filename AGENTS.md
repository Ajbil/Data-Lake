# Agent Guidance

## Prime Directive

This is a documentation-first POC scaffold. Do not add implementation code, Docker Compose services, connector JSON, SQL scripts, dbt models, or Airflow DAGs until the documentation and agent guidance are complete and reviewed.

## Scope Boundaries

- Preserve `Data_lake_poc_new_architecture.png`.
- Leave any existing `data_lake` folder untouched if it appears later.
- Keep the POC focused on SQL Server CDC, Debezium, Kafka, Kafka Connect, MinIO, Iceberg, dbt, StarRocks, Airflow, PowerBI, and lightweight monitoring.
- Do not add chatbot/LLM, RBAC, HA, DR, production IAM/secrets, Excel ingestion, or PII tokenization unless scope changes.

## Documentation Requirements

Every technology decision must explain why it is selected, what feeds it, what depends on it, what proves it works, and what fallback exists if it blocks progress.

## Implementation Guardrails

- Prefer small, reviewable files.
- Keep secrets in `.env`, never committed docs/config.
- Make EC2 and local assumptions explicit.
- Document every port change.
- Record same-day gotchas in `notes/`.

## Acceptance Mindset

The POC is successful only if another engineer can follow the README and reproduce the end-to-end path without tribal knowledge.
