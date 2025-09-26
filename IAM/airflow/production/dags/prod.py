from airflow.decorators import dag, task
from datetime import datetime, timedelta
import time

default_args = {
    'owner': 'airflow',
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

@dag(
    dag_id='test_sleep_dag_decorators',
    description='A simple test DAG using decorators that sleeps for 10 seconds',
    default_args=default_args,
    schedule=None,  # run manually
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['test'],
)
def test_sleep_dag():
    @task()
    def sleep_10_seconds():
        print("Sleeping for 10 seconds...")
        time.sleep(10)
        print("Done sleeping!")

    sleep_10_seconds()

test_sleep_dag()