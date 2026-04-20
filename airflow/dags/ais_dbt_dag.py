from datetime import datetime, timedelta

from airflow.sdk import DAG
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig
from cosmos.profiles import ClickhouseUserPasswordProfileMapping

profile_config = ProfileConfig(
    profile_name="ais_transformations",
    target_name="dev",
    profile_mapping=ClickhouseUserPasswordProfileMapping(
        conn_id="clickhouse_default",
        profile_args={
            "schema": "ais_db",
        }
    )
)

with DAG(
    dag_id="ais_transformations",
    start_date=datetime(2026, 4, 20),
    schedule=timedelta(minutes=15),
    catchup=False,
    default_args={
        "retries": 1,
        "retry_delay": timedelta(minutes=1),
    }
) as dag:

    dbt_tg = DbtTaskGroup(
        group_id="dbt_transformations",
        project_config=ProjectConfig("/opt/airflow/dbt"),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            dbt_executable_path="/usr/local/bin/dbt",
        ),
    )
