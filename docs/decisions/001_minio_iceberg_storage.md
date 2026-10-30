# Decision 001: Use MinIO for Iceberg Object Storage

## Status

Accepted for POC.

## Context

The POC needs S3-compatible object storage for Iceberg table data and metadata. The assumption is single-node EC2 Docker Compose with no managed AWS services.

## Decision

Use MinIO as the object storage layer and create a `lakehouse` bucket for the Iceberg warehouse.

Warehouse path:

```text
s3://lakehouse/warehouse
```

## Why MinIO

- Self-hostable and compatible with the no-managed-services assumption.
- S3 API makes the POC portable to future object storage.
- Easy to inspect through MinIO Console.
- Simple local and EC2 deployment.

## Pipeline Connection

Previous technology: Kafka Connect Iceberg sink or Spark fallback writes table files and metadata to MinIO.

Next technology: Iceberg REST catalog and StarRocks rely on MinIO objects to discover snapshots and scan data.

## Consequences

Positive:

- No paid license key or managed cloud dependency.
- Good demo visibility into object layout.
- Simple deployment.

Tradeoffs:

- Single-node MinIO is not HA.
- Disk pressure can block Iceberg commits.
- Credentials are POC-local and not production IAM.

## Follow-Up

During implementation, document the actual object layout after writes for both Raw tables.
