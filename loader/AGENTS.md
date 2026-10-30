# Agent Guidance: loader

- Target roughly 10 rows/sec for the Day 6 sustained load test.
- Include tagged rows traceable through SQL Server, Kafka, Iceberg, dbt, StarRocks, and PowerBI.
- Avoid real customer data or PII.
- Emit timestamps suitable for end-to-end latency measurement.
