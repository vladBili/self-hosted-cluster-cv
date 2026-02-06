from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator


with DAG(
    dag_id='spark_test_dag',
    schedule_interval=None,
    catchup=False
) as dag:
    submit_spark_job = SparkKubernetesOperator(
        task_id="spark_test_submit_task",
        namespace="spark", 
        application_file="crds/test-spark.yaml",
        kubernetes_conn_id="kubernetes_default", 
        random_name_suffix = True,
        name = "spark-test-pod",
        get_logs=True,
        delete_on_termination=True, 
        dag=dag,
    )
