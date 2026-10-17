# SDG Tech Challenge — Cloud Engineer (Data Infrastructure)

Technical challenge from SDG Group: build a local data platform with **Terraform + Docker**. The
evaluation focuses on IaC, automated deployment, component integration, methodology and how the
solution is presented — completeness is not mandatory, but structure and reasoning are.

## Stack

- **Docker** as the runtime (containers, networks, volumes).
- **Terraform** (version pinned in `.terraform-version`, use `tfenv`) orchestrating the whole stack.
- **MinIO** — S3-compatible object storage.
- **PostgreSQL** — holds an orchestrator's metadata *and* acts as the destination database.

## Acceptance criteria

- [ ] Terraform manages container lifecycle, internal networks and volumes.
- [ ] Whole stack deploys reproducibly with a **single command**.
- [ ] MinIO API reachable on port **9000**, Web Console on port **9001**.
- [ ] MinIO ready to receive data with persistent storage.
- [ ] A bucket named **`data-bucket`** exists in MinIO (required for validation).
- [ ] PostgreSQL instance serving both orchestrator metadata and destination data.

### Nice to have

- [ ] CI/CD pipeline config (GitHub Actions / GitLab CI) automating the Terraform lifecycle.
- [ ] Platform monitoring.
- [ ] Data persistence: DB data and files survive container destroy/recreate.

## AI usage rule (mandatory)

AI use is allowed but must be documented. **After every prompt in this project, append an entry
to `PROMPTS.md`** containing the prompt verbatim (as the `<summary>` of a `<details>` dropdown)
and Claude's answer inside the dropdown. Keep entries chronological, numbered, and never edit
past entries.
