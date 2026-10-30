# Day 02 MinIO Iceberg Catalog

## Goal

Start MinIO, create the `lakehouse` bucket, and validate Iceberg REST catalog access.

## Why This Matters

MinIO stores Iceberg data and metadata. The Iceberg REST catalog connects table writers to StarRocks readers.

## Commands or Actions

- Added MinIO service to Docker Compose.
- Added one-shot `create-minio-bucket` service using `minio/mc`.
- Added Iceberg REST catalog service using `tabulario/iceberg-rest:1.6.0`.
- Started full Day 2 stack with `scripts/setup.ps1 start`.
- Verified bucket from inside the Docker network.
- Verified Iceberg REST config and namespaces endpoints.

## Evidence Captured

- MinIO API is mapped on `localhost:9000`.
- MinIO Console is mapped on `localhost:9001`.
- Bucket `lakehouse` exists.
- Iceberg REST is mapped on `localhost:8181`.
- `GET http://localhost:8181/v1/config` returns a valid response.
- `GET http://localhost:8181/v1/namespaces` returns an empty namespace list, confirming the catalog is reachable before any tables are created.
- Iceberg warehouse is configured as `s3://lakehouse/warehouse`.
- Iceberg REST is configured with MinIO endpoint `http://minio:9000` and path-style S3 access.

## Observations

- The bucket initializer is one-shot and exits successfully after creating `lakehouse`.
- Iceberg REST currently has no tables or namespaces, which is expected before the Day 3 Iceberg sink.
- MinIO object layout will be documented after the first Iceberg writes on Day 3.

## Issues and Follow-Ups

- Day 3 should create Raw Iceberg tables and verify Parquet/metadata files under the `lakehouse` bucket.
