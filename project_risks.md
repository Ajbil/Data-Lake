# Project Risks

| Risk | Impact | Likelihood | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Iceberg Kafka Connect sink maturity blocks Raw writes | Day 3/4 delay | Medium | Escalate to Spark Structured Streaming fallback | Data engineering |
| CDC retention exceeded during outage | Data gap or re-snapshot | Medium | Set retention to 7 days and monitor lag | DBA/data engineering |
| Schema evolution breaks Raw ingestion | Connector failure | Medium | Test additive column scenario | Data engineering |
| Single-node MinIO disk fills | Iceberg commit failures | Medium | Monitor disk and run low-space test safely | Platform |
| PowerBI driver mismatch | Demo delay | Medium | Validate MySQL driver early on Day 5 | BI/analytics |
| StarRocks external catalog config friction | Query delay | Medium | Validate catalog with simple count before dbt | Analytics platform |
| POC scope creep | Missed milestone | High | Keep exclusions explicit and update decisions only when approved | POC lead |
| Confluent Avro converter not bundled in Debezium Connect image | Schema Registry remains unused by CDC topics | Medium | Decide before Day 3 whether to add a custom Connect image or keep JSON-with-schema for POC Raw ingestion | Data engineering |
| Iceberg sink plugin not bundled in Debezium Connect image | Kafka Connect sink path requires extra packaging | Medium | Day 3 installs Apache Iceberg sink dependencies through Maven; choose mounted plugin path or custom Connect image before production design | Data engineering |
