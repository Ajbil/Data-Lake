# Agent Guidance: dbt

- Raw should be source definitions only.
- Silver should recreate the Daily Operations Report consolidated views from Raw CDC, using latest-state interpretation for entities and preserving event/log history where the report needs existence checks.
- Gold should expose `gold_daily_operations_report` for PowerBI.
- Add tests for key report fields, accepted label values, and relationships once models exist.
