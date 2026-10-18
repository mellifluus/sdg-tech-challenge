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
        end
        subgraph sdg-monitoring["sdg-monitoring network"]
        end
        minio_vol[("sdg-minio-data<br/>volume")]
    end
    host(["Host"])

    host -- ":9000 API / :9001 Console" --> minio
    bootstrap -- "buckets, policy, app user" --> minio
    minio --- minio_vol
```
