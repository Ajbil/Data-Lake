# Day 07 Linux Server Runner

## Goal

Run the POC on Ubuntu/EC2 without installing or using PowerShell.

## Why This Matters

The client-facing POC server should be easy to operate with native Linux tooling. PowerShell remains useful on Windows developer machines, but the server path should use Bash, Docker Compose, curl, and Python 3.

## Decisions

- Added `scripts/setup.sh` as the Linux command runner.
- Added `scripts/linux/common.sh` for shared Bash helpers.
- Kept `scripts/setup.ps1` unchanged for the Windows path.
- Made Avro/Schema Registry the primary Linux server validation path.
- Kept the Python Raw writer setup available as `bootstrap:day3`, but the server flow should prefer the Kafka Connect Iceberg sink for Avro-backed CDC topics.

## Gotchas

- The old PowerShell Day 3 health path uses the Python fallback writer, which expects JSON-decoded Kafka messages. That is not the right primary check for Avro-backed UAT-style CDC.
- After `plugin:avro` or `plugin:iceberg`, restart Kafka Connect so it loads the newly mounted jars.
- On Linux, run `chmod +x scripts/setup.sh` once after cloning if the executable bit is not preserved.
