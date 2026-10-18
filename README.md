# SDG Tech Challenge — Local Data Platform

Local data platform built with **Terraform + Docker**: MinIO object storage and PostgreSQL.

## Architecture

```mermaid
flowchart TB
    subgraph docker["Docker"]
        direction LR
        subgraph sdg-data["sdg-data network"]
            minio["minio<br/>(MinIO server)"]
            bootstrap["minio-bootstrap<br/>(one-shot mc job)"]
            postgres["postgres<br/>(PostgreSQL server)"]
            pg_bootstrap["postgres-bootstrap<br/>(one-shot psql job)"]
            tests["tests/run.sh<br/>(ephemeral mc / psql containers)"]
        end
        subgraph sdg-monitoring["sdg-monitoring network"]
        end
        minio_vol[("sdg-minio-data<br/>volume")]
        pg_vol[("sdg-postgres-data<br/>volume")]
    end
    host(["Host"])

    host -- ":9000 API / :9001 Console" --> minio
    bootstrap -- "buckets, policy, app user" --> minio
    minio --- minio_vol
    host -- ":5432" --> postgres
    pg_bootstrap -- "roles, databases, grants" --> postgres
    postgres --- pg_vol
    tests -. "checks, fixture upload" .-> minio
    tests -. "checks, e2e load" .-> postgres
```

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
- **E2E**: streams the fixture out of the bucket into `warehouse.e2e_orders` (truncate + load
  in one transaction) and checks the row count and total.
