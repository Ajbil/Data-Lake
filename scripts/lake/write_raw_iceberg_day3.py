import argparse
import json
import os
import time
from collections import defaultdict
from pathlib import Path
from typing import Any

import pyarrow as pa
from confluent_kafka import Consumer, KafkaError
from pyiceberg.catalog import load_catalog
from pyiceberg.exceptions import NamespaceAlreadyExistsError, NoSuchTableError, TableAlreadyExistsError
from pyiceberg.schema import Schema
from pyiceberg.types import IntegerType, LongType, NestedField, StringType


TOPIC_TO_TABLE = {
    "mbs_poc.mbs_poc.dbo.agents": ("raw", "agents_cdc"),
    "mbs_poc.mbs_poc.dbo.kyc_completions": ("raw", "kyc_completions_cdc"),
}


def read_dotenv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def env_value(dotenv: dict[str, str], key: str, default: str) -> str:
    return os.environ.get(key) or dotenv.get(key) or default


def load_offsets(path: Path) -> dict[str, int]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_offsets(path: Path, offsets: dict[str, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(offsets, indent=2, sort_keys=True), encoding="utf-8")


def offset_key(topic: str, partition: int) -> str:
    return f"{topic}:{partition}"


def raw_schema() -> Schema:
    return Schema(
        NestedField(1, "event_id", StringType(), required=True),
        NestedField(2, "source_table", StringType(), required=True),
        NestedField(3, "topic", StringType(), required=True),
        NestedField(4, "kafka_partition", IntegerType(), required=True),
        NestedField(5, "kafka_offset", LongType(), required=True),
        NestedField(6, "kafka_timestamp_ms", LongType(), required=False),
        NestedField(7, "kafka_key_json", StringType(), required=False),
        NestedField(8, "envelope_schema_json", StringType(), required=False),
        NestedField(9, "payload_json", StringType(), required=True),
        NestedField(10, "op", StringType(), required=False),
        NestedField(11, "before_json", StringType(), required=False),
        NestedField(12, "after_json", StringType(), required=False),
        NestedField(13, "source_json", StringType(), required=False),
        NestedField(14, "source_ts_ms", LongType(), required=False),
        NestedField(15, "debezium_ts_ms", LongType(), required=False),
        NestedField(16, "ingested_at_ms", LongType(), required=True),
        NestedField(17, "event_tag", StringType(), required=False),
    )


def arrow_schema() -> pa.Schema:
    return pa.schema(
        [
            pa.field("event_id", pa.string(), nullable=False),
            pa.field("source_table", pa.string(), nullable=False),
            pa.field("topic", pa.string(), nullable=False),
            pa.field("kafka_partition", pa.int32(), nullable=False),
            pa.field("kafka_offset", pa.int64(), nullable=False),
            pa.field("kafka_timestamp_ms", pa.int64(), nullable=True),
            pa.field("kafka_key_json", pa.string(), nullable=True),
            pa.field("envelope_schema_json", pa.string(), nullable=True),
            pa.field("payload_json", pa.string(), nullable=False),
            pa.field("op", pa.string(), nullable=True),
            pa.field("before_json", pa.string(), nullable=True),
            pa.field("after_json", pa.string(), nullable=True),
            pa.field("source_json", pa.string(), nullable=True),
            pa.field("source_ts_ms", pa.int64(), nullable=True),
            pa.field("debezium_ts_ms", pa.int64(), nullable=True),
            pa.field("ingested_at_ms", pa.int64(), nullable=False),
            pa.field("event_tag", pa.string(), nullable=True),
        ]
    )


def compact_json(value: Any) -> str | None:
    if value is None:
        return None
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def decode_json(raw: bytes | None) -> Any:
    if raw is None:
        return None
    text = raw.decode("utf-8")
    if text == "":
        return None
    return json.loads(text)


def build_row(msg: Any, ingested_at_ms: int) -> dict[str, Any]:
    value = decode_json(msg.value())
    key = decode_json(msg.key())

    payload = value.get("payload", {}) if isinstance(value, dict) else {}
    envelope_schema = value.get("schema") if isinstance(value, dict) else None
    before = payload.get("before")
    after = payload.get("after")
    source = payload.get("source") or {}
    source_table = source.get("table") or TOPIC_TO_TABLE[msg.topic()][1]
    _, kafka_timestamp_ms = msg.timestamp()

    event_tag = None
    if isinstance(after, dict):
        event_tag = after.get("event_tag")
    if event_tag is None and isinstance(before, dict):
        event_tag = before.get("event_tag")

    return {
        "event_id": f"{msg.topic()}-{msg.partition()}-{msg.offset()}",
        "source_table": str(source_table),
        "topic": msg.topic(),
        "kafka_partition": msg.partition(),
        "kafka_offset": msg.offset(),
        "kafka_timestamp_ms": kafka_timestamp_ms if kafka_timestamp_ms and kafka_timestamp_ms > 0 else None,
        "kafka_key_json": compact_json(key),
        "envelope_schema_json": compact_json(envelope_schema),
        "payload_json": compact_json(payload) or "{}",
        "op": payload.get("op"),
        "before_json": compact_json(before),
        "after_json": compact_json(after),
        "source_json": compact_json(source),
        "source_ts_ms": source.get("ts_ms"),
        "debezium_ts_ms": payload.get("ts_ms"),
        "ingested_at_ms": ingested_at_ms,
        "event_tag": event_tag,
    }


def load_iceberg_catalog(args: argparse.Namespace, dotenv: dict[str, str]) -> Any:
    return load_catalog(
        "mbs",
        type="rest",
        uri=args.catalog_uri,
        warehouse=args.warehouse,
        **{
            "s3.endpoint": args.s3_endpoint,
            "s3.access-key-id": env_value(dotenv, "MINIO_ROOT_USER", "minioadmin"),
            "s3.secret-access-key": env_value(dotenv, "MINIO_ROOT_PASSWORD", "minioadmin-local-only"),
            "s3.path-style-access": "true",
            "s3.region": "us-east-1",
        },
    )


def ensure_raw_tables(catalog: Any) -> dict[str, Any]:
    try:
        catalog.create_namespace("raw")
        print("Created Iceberg namespace raw.")
    except NamespaceAlreadyExistsError:
        pass

    tables = {}
    for table_identifier in TOPIC_TO_TABLE.values():
        try:
            tables[table_identifier[1]] = catalog.create_table(table_identifier, schema=raw_schema())
            print(f"Created Iceberg table {'.'.join(table_identifier)}.")
        except TableAlreadyExistsError:
            tables[table_identifier[1]] = catalog.load_table(table_identifier)
        except NoSuchTableError:
            tables[table_identifier[1]] = catalog.create_table(table_identifier, schema=raw_schema())
    return tables


def consume_rows(args: argparse.Namespace, checkpoint: dict[str, int]) -> tuple[dict[str, list[dict[str, Any]]], dict[str, int]]:
    consumer = Consumer(
        {
            "bootstrap.servers": args.bootstrap_servers,
            "group.id": args.group_id,
            "enable.auto.commit": False,
            "auto.offset.reset": "earliest",
        }
    )

    rows_by_table: dict[str, list[dict[str, Any]]] = defaultdict(list)
    next_offsets = dict(checkpoint)
    deadline = time.monotonic() + args.idle_seconds

    consumer.subscribe(list(TOPIC_TO_TABLE.keys()))
    try:
        while time.monotonic() < deadline:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                raise RuntimeError(msg.error())

            key = offset_key(msg.topic(), msg.partition())
            if msg.offset() < checkpoint.get(key, 0):
                continue

            table_name = TOPIC_TO_TABLE[msg.topic()][1]
            rows_by_table[table_name].append(build_row(msg, int(time.time() * 1000)))
            next_offsets[key] = max(next_offsets.get(key, 0), msg.offset() + 1)
            deadline = time.monotonic() + args.idle_seconds

            if args.max_messages and sum(len(rows) for rows in rows_by_table.values()) >= args.max_messages:
                break
    finally:
        consumer.close()

    return rows_by_table, next_offsets


def append_rows(tables: dict[str, Any], rows_by_table: dict[str, list[dict[str, Any]]]) -> int:
    total = 0
    for table_name, rows in rows_by_table.items():
        if not rows:
            continue
        arrow_table = pa.Table.from_pylist(rows, schema=arrow_schema())
        tables[table_name].append(arrow_table, snapshot_properties={"mbs.day": "3", "mbs.layer": "raw"})
        print(f"Appended {len(rows)} row(s) to raw.{table_name}.")
        total += len(rows)
    return total


def verify_event_tag(catalog: Any, event_tag: str) -> None:
    found = 0
    for _, table_name in TOPIC_TO_TABLE.values():
        table = catalog.load_table(("raw", table_name))
        arrow_table = table.scan().to_arrow()
        if "event_tag" not in arrow_table.column_names:
            continue
        event_tags = arrow_table.column("event_tag").to_pylist()
        count = sum(1 for value in event_tags if value == event_tag)
        print(f"Verification raw.{table_name}: event_tag={event_tag} count={count}")
        found += count

    if found == 0:
        raise RuntimeError(f"Did not find event_tag={event_tag} in Raw Iceberg tables.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Day 3 fallback writer from Kafka CDC topics to Raw Iceberg tables.")
    parser.add_argument("--env-file", default=".env")
    parser.add_argument("--bootstrap-servers", default="localhost:29092")
    parser.add_argument("--catalog-uri", default="http://localhost:8181")
    parser.add_argument("--s3-endpoint", default="http://localhost:9000")
    parser.add_argument("--warehouse", default="s3://lakehouse/warehouse")
    parser.add_argument("--checkpoint-file", default=".runtime/day3_offsets.json")
    parser.add_argument("--group-id", default="mbs-day3-iceberg-writer")
    parser.add_argument("--idle-seconds", type=int, default=8)
    parser.add_argument("--max-messages", type=int, default=0)
    parser.add_argument("--verify-event-tag")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    dotenv = read_dotenv(Path(args.env_file))
    checkpoint_path = Path(args.checkpoint_file)
    checkpoint = load_offsets(checkpoint_path)

    catalog = load_iceberg_catalog(args, dotenv)
    tables = ensure_raw_tables(catalog)
    rows_by_table, next_offsets = consume_rows(args, checkpoint)
    total = append_rows(tables, rows_by_table)

    if total > 0:
        save_offsets(checkpoint_path, next_offsets)
    print(f"Day 3 writer completed. Raw rows appended this run: {total}.")

    if args.verify_event_tag:
        verify_event_tag(catalog, args.verify_event_tag)


if __name__ == "__main__":
    main()
