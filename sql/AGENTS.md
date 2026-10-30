# Agent Guidance: sql

- Use database `mbs_poc`.
- Define exact schemas for `dbo.agents` and `dbo.kyc_completions` before enabling CDC.
- Set SQL Server CDC retention to 7 days.
- Keep seed data realistic but non-PII.
- Verification SQL must prove database CDC, table CDC, retention, and change table visibility.
