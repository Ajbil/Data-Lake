DROP CATALOG IF EXISTS iceberg_catalog;

CREATE EXTERNAL CATALOG iceberg_catalog
COMMENT "MBS POC Iceberg REST catalog on MinIO"
PROPERTIES
(
    "type" = "iceberg",
    "iceberg.catalog.type" = "rest",
    "iceberg.catalog.uri" = "http://iceberg-rest:8181",
    "iceberg.catalog.warehouse" = "${ICEBERG_WAREHOUSE}",
    "aws.s3.access_key" = "${MINIO_ROOT_USER}",
    "aws.s3.secret_key" = "${MINIO_ROOT_PASSWORD}",
    "aws.s3.endpoint" = "http://minio:9000",
    "aws.s3.region" = "us-east-1",
    "aws.s3.enable_path_style_access" = "true",
    "client.factory" = "com.starrocks.connector.iceberg.IcebergAwsClientFactory"
);
