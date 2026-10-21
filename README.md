# SDG Tech Challenge — Local Data Platform

Local data platform built with **Terraform + Docker**: MinIO object storage and PostgreSQL.

## Architecture

```mermaid
flowchart TB
    subgraph docker["Docker"]
        direction LR
        subgraph sdg-data["sdg-data network (foundation)"]
            minio["minio<br/>(MinIO server, also on sdg-monitoring)"]
            bootstrap["minio-bootstrap<br/>(one-shot mc job)"]
            postgres["postgres<br/>(PostgreSQL server)"]
            pg_bootstrap["postgres-bootstrap<br/>(one-shot psql job)"]
            subgraph airflow["Airflow (LocalExecutor)"]
                af_init["airflow-init<br/>(one-shot db migrate)"]
                af_api["airflow-api-server<br/>(UI, REST API)"]
                af_sched["airflow-scheduler<br/>(runs tasks)"]
                af_dagp["airflow-dag-processor<br/>(parses DAGs)"]
            end
        end
        subgraph sdg-monitoring["sdg-monitoring network (foundation)"]
            prometheus["prometheus<br/>(metrics, monitoring network only)"]
            pg_exporter["postgres-exporter<br/>(also on sdg-data)"]
            grafana["grafana<br/>(dashboards, alerts)"]
        end
        minio_vol[("sdg-minio-data<br/>volume (foundation)")]
        pg_vol[("sdg-postgres-data<br/>volume (foundation)")]
        prom_vol[("sdg-prometheus-data<br/>volume (foundation)")]
        grafana_vol[("sdg-grafana-data<br/>volume (foundation)")]
        af_logs_vol[("sdg-airflow-logs-data<br/>volume (foundation)")]
    end
    host(["Host"])

    host -- ":9000 API / :9001 Console" --> minio
    bootstrap -- "buckets, policy, app user" --> minio
    minio --- minio_vol
    host -- ":5432" --> postgres
    pg_bootstrap -- "roles, databases, grants" --> postgres
    postgres --- pg_vol
    host -- ":9090 UI / API" --> prometheus
    prometheus --- prom_vol
    prometheus -- "scrape /minio/v2/metrics" --> minio
    prometheus -- "scrape :9187" --> pg_exporter
    pg_exporter -- "pg_monitor role" --> postgres
    host -- ":3000 UI" --> grafana
    grafana -- "PromQL datasource" --> prometheus
    grafana --- grafana_vol
    host -- ":8080 UI / API" --> af_api
    af_init -- "schema migrations" --> postgres
    airflow -- "metadata (airflow DB)" --> postgres
    af_sched -- "execution API" --> af_api
    af_sched -- "DAG tasks: S3 as app user" --> minio
    af_sched -- "DAG tasks: warehouse DB" --> postgres
    af_api --- af_logs_vol
    af_sched --- af_logs_vol
    af_dagp --- af_logs_vol
```

Two Terraform root modules with separate states: `terraform/foundation` (networks, volumes,
credentials) and `terraform/platform` (images, containers, bootstrap jobs), which reads the
foundation outputs through `terraform_remote_state`. `make up` applies both, `make down` destroys
only the platform so data survives, and `make nuke` destroys both.

## Testing

`make test` (or `./tests/run.sh`) runs integration checks against the deployed stack. It reads
config from `terraform output` and runs `mc` / `psql` in throwaway containers on the stack
network. It needs `docker`, `terraform`, `jq` and `curl`. The exit code is the number of failed
checks, so it can run as-is in CI.

- **MinIO**: API and Console health, `data-bucket` exists with versioning on, the app user
  uploads `tests/fixtures/orders.csv` and the copy in the bucket matches it (sha256), and the
  app user is denied bucket creation and admin operations.
- **PostgreSQL**: the server is ready, and each role can connect to its own database and is
  denied the other one.
- **Prometheus**: ready, all scrape targets `up`, `pg_up == 1`, MinIO reports online nodes
  (polled for ~60s so the first scrape can land), and a container on `sdg-monitoring` cannot
  reach PostgreSQL directly.
- **Grafana**: healthy, anonymous API access rejected, Prometheus datasource healthy, the
  overview dashboard is provisioned, and every rule in `grafana-alerts.yml` is loaded.
- **Airflow**: the api-server is up and reports the metadata DB, scheduler and dag-processor
  as healthy (polled), anonymous API access is rejected, and the admin user gets a token
  that the API accepts.
- **E2E**: streams the fixture out of the bucket into `warehouse.e2e_orders` (truncate + load
  in one transaction) and checks the row count and total.

`make test-persistence` (or `./tests/persistence.sh`) checks that data survives the containers.
It writes a marker to MinIO (object), PostgreSQL (row) and Grafana (annotation), and notes a
timestamp Prometheus has samples for. Then it runs `make down` and `make up`, checks that every
container was recreated while the foundation volumes stayed, and reads each marker back. It
restarts the stack, so `make test` doesn't run it.
