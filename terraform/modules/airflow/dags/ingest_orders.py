# Waits for new files, processes them into the staging.orders table, and moves them to processed/ or rejected/.

import csv
import io
from contextlib import closing
from datetime import date, datetime, timedelta
from decimal import Decimal, InvalidOperation

from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.amazon.aws.sensors.s3 import S3KeySensor
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.sdk import dag, task

from common.config import (
    DATA_BUCKET,
    DEFAULT_ARGS,
    MINIO_CONN_ID,
    ORDERS_PROCESSED_PREFIX,
    ORDERS_RAW_PREFIX,
    ORDERS_REJECTED_PREFIX,
    STAGING_ORDERS,
    WAREHOUSE_CONN_ID,
)

# csvs should be in this format
COLUMNS = ["order_id", "order_date", "customer", "product", "quantity", "unit_price"]

# PostgreSQL values validation
INT4_MIN, INT4_MAX = -(2**31), 2**31 - 1 #integer range for postgres
PRICE_MAX = Decimal("99999999.99")  # numeric(10,2)
CENT = Decimal("0.01")

# Idempotent DDL
CREATE_STAGING = """
CREATE SCHEMA IF NOT EXISTS staging;
CREATE TABLE IF NOT EXISTS staging.orders (
    order_id    integer       PRIMARY KEY,
    order_date  date          NOT NULL,
    customer    text          NOT NULL,
    product     text          NOT NULL,
    quantity    integer       NOT NULL CHECK (quantity > 0),
    unit_price  numeric(10,2) NOT NULL CHECK (unit_price >= 0),
    source_file text          NOT NULL,
    loaded_at   timestamptz   NOT NULL DEFAULT now()
);
"""

# Upsert on pkey, so a later file with the same order_id overwrites an earlier one.
UPSERT = """
INSERT INTO staging.orders (order_id, order_date, customer, product, quantity, unit_price, source_file)
VALUES (%s, %s, %s, %s, %s, %s, %s)
ON CONFLICT (order_id) DO UPDATE SET
    order_date  = EXCLUDED.order_date,
    customer    = EXCLUDED.customer,
    product     = EXCLUDED.product,
    quantity    = EXCLUDED.quantity,
    unit_price  = EXCLUDED.unit_price,
    source_file = EXCLUDED.source_file,
    loaded_at   = now()
"""


class InvalidFile(ValueError):
    "Raised when a file is not valid CSV or violates the schema."


def parse_orders(data: bytes) -> list[tuple]:
    try:
        text = data.decode("utf-8-sig") # this also strips Excel's BOM if present
    except UnicodeDecodeError as e:
        raise InvalidFile(f"not valid UTF-8: {e}") from e

    reader = csv.reader(io.StringIO(text), strict=True)
    rows, seen = [], set()
    try:
        header = next(reader, None)
        if header is None or [h.strip() for h in header] != COLUMNS:
            raise InvalidFile(f"header {header} != {COLUMNS}")

        for raw in reader:
            line = reader.line_num
            if not raw:  # blank line
                continue
            if len(raw) != len(COLUMNS):
                raise InvalidFile(f"line {line}: expected {len(COLUMNS)} fields, got {len(raw)}")
            raw = [field.strip() for field in raw]

            # type conversion
            try:
                order_id, quantity = int(raw[0]), int(raw[4])
                order_date = date.fromisoformat(raw[1])
                unit_price = Decimal(raw[5])
            except (ValueError, InvalidOperation) as e:
                raise InvalidFile(f"line {line}: {e}") from e

            customer, product = raw[2], raw[3]
            if not customer or not product:
                raise InvalidFile(f"line {line}: empty customer or product")
            # more validation, specifically for Decimal: is_finite() rejects NaN and Infinity
            if not unit_price.is_finite():
                raise InvalidFile(f"line {line}: unit_price {raw[5]!r} is not a number")
            if not INT4_MIN <= order_id <= INT4_MAX:
                raise InvalidFile(f"line {line}: order_id {order_id} out of integer range")
            if not 0 < quantity <= INT4_MAX:
                raise InvalidFile(f"line {line}: quantity {quantity} must be in 1..{INT4_MAX}")
            if not 0 <= unit_price <= PRICE_MAX:
                raise InvalidFile(f"line {line}: unit_price {unit_price} must be in 0..{PRICE_MAX}")
            # numeric(10,2) would silently round 9.999 to 10.00; prices must be whole cents.
            if unit_price != unit_price.quantize(CENT):
                raise InvalidFile(f"line {line}: unit_price {unit_price} has more than 2 decimals")
            # stop two rows with the same order_id being inserted
            if order_id in seen:
                raise InvalidFile(f"line {line}: duplicate order_id {order_id}")
            seen.add(order_id)
            rows.append((order_id, order_date, customer, product, quantity, unit_price))
    except csv.Error as e:
        raise InvalidFile(f"line {reader.line_num}: malformed CSV: {e}") from e

    if not rows:
        raise InvalidFile("no data rows")
    return rows


def move(s3: S3Hook, key: str, prefix: str) -> str:
    dest = prefix + key.removeprefix(ORDERS_RAW_PREFIX)
    s3.copy_object(key, dest, source_bucket_name=DATA_BUCKET, dest_bucket_name=DATA_BUCKET)
    s3.delete_objects(DATA_BUCKET, [key])
    return dest


@dag(
    schedule=timedelta(minutes=15),  # check for new files every 15 mins
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args=DEFAULT_ARGS,
    tags=["ingestion", "orders"],
)
def ingest_orders():
    wait_for_files = S3KeySensor(
        task_id="wait_for_files",
        aws_conn_id=MINIO_CONN_ID,
        bucket_name=DATA_BUCKET,
        bucket_key=f"{ORDERS_RAW_PREFIX}*.csv",
        wildcard_match=True,
        mode="reschedule",
        poke_interval=30,
        timeout=10 * 60,
        soft_fail=True, # no new file is not a failure
    )

    create_staging = SQLExecuteQueryOperator(
        task_id="create_staging_table",
        conn_id=WAREHOUSE_CONN_ID,
        sql=CREATE_STAGING,
    )

    @task
    def list_new_files() -> list[str]:
        # list all new files and sort
        keys = S3Hook(MINIO_CONN_ID).list_keys(DATA_BUCKET, prefix=ORDERS_RAW_PREFIX) or []
        return sorted(k for k in keys if k.endswith(".csv"))

    @task(map_index_template="{{ key }}", max_active_tis_per_dagrun=1)
    def process_file(key: str) -> dict:
        s3 = S3Hook(MINIO_CONN_ID)
        data = s3.get_key(key, DATA_BUCKET).get()["Body"].read()
        try:
            rows = parse_orders(data)
        except InvalidFile as e:
            dest = move(s3, key, ORDERS_REJECTED_PREFIX)
            return {"key": key, "status": "rejected", "reason": str(e), "moved_to": dest}

        # transaction, either all rows are inserted or none.
        hook = PostgresHook(postgres_conn_id=WAREHOUSE_CONN_ID)
        with closing(hook.get_conn()) as conn:
            with conn.cursor() as cur:
                cur.executemany(UPSERT, [(*row, key) for row in rows])
            conn.commit()

        dest = move(s3, key, ORDERS_PROCESSED_PREFIX)
        return {"key": key, "status": "loaded", "rows": len(rows), "moved_to": dest}

    # retries=0: a retry would read the same results and fail the same way.
    @task(retries=0)
    def check_rejections(results: list[dict]) -> None:
        # fail only after all files have been processed and if there is a rejection
        rejected = [r for r in results if r["status"] == "rejected"]
        if rejected:
            details = "; ".join(f"{r['key']}: {r['reason']}" for r in rejected)
            raise ValueError(f"{len(rejected)} file(s) rejected: {details}")

    keys = list_new_files()
    wait_for_files >> create_staging >> keys
    results = process_file.expand(key=keys)
    check_rejections(results)


ingest_orders()
