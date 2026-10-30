# EC2 Setup Runbook

## Purpose

Prepare a single EC2 host for the POC stack without using managed AWS services.

## Recommended Host

- Instance: `m6i.2xlarge` or `t3.2xlarge`.
- CPU/RAM: 8 vCPU and 32 GB RAM.
- Disk: 100 GB+ EBS.
- OS: Linux host preferred for Docker Compose stability.
- Access: SSH for operators and inbound ports only from trusted IP ranges.

## Why Single-Node Docker Compose

Docker Compose keeps the POC reproducible and inexpensive. It connects the documentation phase to the implementation phase by letting each service be introduced incrementally.

Previous stage: repository documentation and service contracts.

Next stage: service implementation under `infra/docker-compose`.

## Required Software

- Docker Engine.
- Docker Compose plugin.
- Git if this folder becomes a repository.
- SQL client for validation.
- MySQL-compatible client for StarRocks validation.

## Setup Checklist

1. Provision EC2 with the recommended size.
2. Attach and mount sufficient EBS storage.
3. Install Docker and Compose.
4. Confirm `docker compose version`.
5. Clone or copy this workspace.
6. Copy `.env.example` to `.env` during implementation.
7. Open only required demo/operator ports.
8. Start services in dependency order once implementation files exist.

## Evidence

- Docker and Compose versions.
- Disk size/free space.
- Security group summary.
- Host DNS/IP used by PowerBI.
