# Agent Guidance: infra

- Explain each service's upstream and downstream dependency before adding it to Docker Compose.
- Keep Compose single-node and EC2-friendly.
- Avoid production HA, IAM, or secret-manager patterns.
- Prefer explicit health checks and named ports.
- Document service ownership and UI/API endpoints in the root README.
