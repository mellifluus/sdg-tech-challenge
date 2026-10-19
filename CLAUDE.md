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

### Orchestrator (optional extension)

SDG removed the orchestrator from the challenge to keep it simple, but confirmed it can be added.
The plan is **Apache Airflow**:

- [ ] Airflow (webserver/api-server, scheduler, `LocalExecutor`) deployed by Terraform in
      `terraform/platform`, same single-command `make up`.
- [ ] Metadata stored in the existing `airflow` PostgreSQL database; DAG output written to the
      `warehouse` database.
- [ ] Airflow connections to MinIO (S3, app user) and `warehouse` injected via env vars from
      Terraform — no credentials in DAG code.
- [ ] DAGs mounted from a repo folder (`dags/`), Airflow logs persisted on a volume.
- [ ] UI reachable from the host; Airflow metrics scraped by Prometheus (StatsD exporter) and
      a basic Grafana panel/alert for failed DAG runs.
- [ ] Tests: DAGs import without errors, and an end-to-end DAG run succeeds in `make test`.

Example DAGs (a consulting company running data/analytics/AI pipelines for clients):

1. **`ingest_orders`** — waits for new CSVs in `data-bucket/raw/orders/`, validates the schema,
   loads them into `warehouse.staging.orders` (idempotent upsert on `order_id`), then moves the
   file to `processed/` (or `rejected/` on failure).
2. **`sales_kpis_daily`** — triggered by `ingest_orders` (Airflow Dataset); builds mart tables
   (daily revenue, revenue per customer/product) for client BI dashboards.
3. **`data_quality_checks`** — row counts, nulls, duplicates and freshness on staging/mart
   tables; fails (and alerts) when a check is violated.
4. **`ml_feature_export`** — weekly; computes customer features (recency, frequency, monetary
   value) from the warehouse and writes a dated Parquet snapshot to `data-bucket/features/`
   for model training.

## AI usage rule (mandatory)

AI use is allowed but must be documented. **After every prompt in this project, append an entry
to `PROMPTS.md`**: a `<details>` dropdown whose `<summary>` is `#N · short topic`, containing the
prompt verbatim in a `> **Prompt**` blockquote, then `**Answer**` and Claude's answer. Separate
entries with `---` and add a row to the index table at the top. Keep entries chronological,
numbered, and never edit past entries' content. Answer user's question as concisely as possible by default. Claude's role here is
more like an assistant than an agentic developer. Override this default behaviour if asked by the user.

## Architecture graph rule

`README.md` holds a Mermaid graph of the stack. **On every prompt, check whether the changes
(containers, networks, volumes, ports, connections) require updating the graph**, and update it
if so. The graph shows **only the deployed architecture**: no test scripts, CI jobs or other
tooling.
