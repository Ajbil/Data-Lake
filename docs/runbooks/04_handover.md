# Handover Runbook

## Purpose

Prepare the Day 7 handover so another engineer can run the POC without help.

## Why This Exists

The POC is not only a stack. It is a reproducible story: source change, CDC capture, event movement, lake storage, transformation, serving, and BI consumption.

Previous stage: completed implementation, notes, screenshots, and failure tests.

Next stage: CAW Engineering Team review and production-readiness discussion.

## Handover Checklist

- Root README has clean-clone or clean-copy instructions.
- `.env.example` lists all required variables without real secrets.
- `lessons_learned.md` is filled in.
- `dba_questions.md` has open DBA items.
- `project_risks.md` reflects actual risks found during the POC.
- Screenshots are collected in `screenshots/`.
- Failure-test results are recorded in `notes/day_06_failure_tests.md`.
- Latency results are recorded in `notes/day_06_latency_results.md`.
- PowerBI screenshot is captured.
- 5-10 minute demo recording is completed.

## 30-Minute Walkthrough Outline

1. Architecture and scope boundaries.
2. Why each technology was chosen and how it connects to the next stage.
3. Live or recorded source-row-to-PowerBI demo.
4. Raw CDC preservation in Iceberg.
5. dbt Silver/Gold modeling approach.
6. StarRocks and PowerBI connection details.
7. Monitoring and operational checks.
8. Failure-test results.
9. Risks, DBA questions, and production gaps.
10. Recommendation on whether to continue, adjust, or stop.
