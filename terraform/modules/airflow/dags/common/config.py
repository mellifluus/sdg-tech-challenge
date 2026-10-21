import os

MINIO_CONN_ID = "minio"
WAREHOUSE_CONN_ID = "warehouse"
DATA_BUCKET = os.environ.get("SDG_DATA_BUCKET", "data-bucket")

DEFAULT_ARGS = {
    "owner": "data-platform",
    "retries": 1,
}
