import os

from airflow.sdk import Asset

MINIO_CONN_ID = "minio"
WAREHOUSE_CONN_ID = "warehouse"
DATA_BUCKET = os.environ.get("SDG_DATA_BUCKET", "data-bucket")

ORDERS_RAW_PREFIX = "raw/orders/"
ORDERS_PROCESSED_PREFIX = "processed/orders/"
ORDERS_REJECTED_PREFIX = "rejected/orders/"

STAGING_ORDERS = Asset("warehouse.staging.orders")

DEFAULT_ARGS = {
    "owner": "data-platform",
    "retries": 1,
}
