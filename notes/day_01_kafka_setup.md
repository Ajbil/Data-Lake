# Day 01 Kafka Setup

## Goal

Start Kafka, Schema Registry, Kafka Connect, and Kafka UI.

## Why This Matters

Kafka is the buffer between Debezium and lake ingestion. Schema Registry supports Avro contracts, and Kafka UI gives operators immediate visibility.

## Commands or Actions

- Added Docker Compose services for Kafka, Schema Registry, Kafka Connect, and Kafka UI.
- Attempted `bitnami/kafka:3.7`; Docker Hub did not have that tag available.
- Switched Kafka to `confluentinc/cp-kafka:7.6.1` to align with `confluentinc/cp-schema-registry:7.6.1`.
- Ran `docker compose --env-file .env -f infra/docker-compose/docker-compose.yml up -d`.
- Ran `scripts/health/day1_services.ps1`.
- Listed Kafka topics from the Kafka container.
- Checked Kafka Connect connector plugins.

## Evidence Captured

- Containers are up: `mbs-kafka`, `mbs-schema-registry`, `mbs-kafka-connect`, `mbs-kafka-ui`, and `mbs-sqlserver`.
- Schema Registry is reachable on `http://localhost:8081`; subjects are currently empty, which is expected before Debezium registration.
- Kafka Connect is reachable on `http://localhost:8083`; `/connectors` returns an empty list before connector registration.
- Kafka UI returns HTTP 200 on `http://localhost:8080`.
- Kafka topics exist: `__consumer_offsets`, `_schemas`, `mbs_connect_configs`, `mbs_connect_offsets`, and `mbs_connect_statuses`.
- Kafka Connect exposes `io.debezium.connector.sqlserver.SqlServerConnector` version `2.7.4.Final`.

## Observations

- Kafka Connect is running with JSON converters for the Day 1 baseline. Schema Registry is already present for the POC's Avro direction.
- Day 2 should decide whether to switch Connect converters to Confluent Avro converters or keep worker defaults JSON and configure converters per Debezium connector, depending on what the Debezium image supports.
- Docker access on this Windows host requires elevated Docker engine access.

## Issues and Follow-Ups

- The original Bitnami Kafka tag was unavailable and was replaced with Confluent Kafka.
- Schema Registry has no subjects yet because no source connector has published schemas.
