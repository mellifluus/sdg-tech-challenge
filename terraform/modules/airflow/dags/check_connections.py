"""Manual smoke test: checks that Airflow can reach the warehouse and the MinIO bucket.

Both connections come from AIRFLOW_CONN_* env vars set by Terraform, so they don't appear in
the UI's Connections page. Trigger this DAG from the UI to resolve and use them for real.
"""

import pendulum
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.sdk import dag, get_current_context, task

from common.config import DATA_BUCKET, DEFAULT_ARGS, MINIO_CONN_ID, WAREHOUSE_CONN_ID


@dag(
    schedule=None,  # manual trigger only
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["smoke-test"],
)
def check_connections():
    @task
    def check_warehouse():
        hook = PostgresHook(postgres_conn_id=WAREHOUSE_CONN_ID)
        db, user, version = hook.get_first("SELECT current_database(), current_user, version()")
        print(f"Connected to database '{db}' as '{user}': {version}")

        # Write check; a temp table disappears with the session, so nothing is left behind.
        hook.run(
            [
                "CREATE TEMP TABLE airflow_smoke (id int)",
                "INSERT INTO airflow_smoke VALUES (1)",
            ],
            autocommit=True,
        )

    @task
    def check_minio():
        hook = S3Hook(aws_conn_id=MINIO_CONN_ID)
        if not hook.check_for_bucket(DATA_BUCKET):
            raise RuntimeError(f"Bucket '{DATA_BUCKET}' not found or not accessible")

        # Round-trip a small object: write, read back, delete.
        run_id = get_current_context()["run_id"]
        key = f"_smoke/{run_id}.txt"
        hook.load_string(run_id, key=key, bucket_name=DATA_BUCKET, replace=True)
        content = hook.read_key(key=key, bucket_name=DATA_BUCKET)
        hook.delete_objects(bucket=DATA_BUCKET, keys=[key])
        if content != run_id:
            raise RuntimeError(f"Read back '{content}', expected '{run_id}'")
        print(f"Wrote, read and deleted s3://{DATA_BUCKET}/{key}")

    check_warehouse()
    check_minio()


check_connections()
