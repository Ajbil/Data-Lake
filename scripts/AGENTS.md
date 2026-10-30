# Agent Guidance: scripts

- Keep bootstrap, connector, and health-check scripts separate.
- Make scripts idempotent where practical.
- Fail loudly with clear messages.
- Do not hide connector failures behind opaque retries.
- Every script should have a matching runbook reference.
