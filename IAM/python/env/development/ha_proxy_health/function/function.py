import os
import socket
import boto3
import requests
from botocore.exceptions import ClientError

ssm = boto3.client("ssm")
route53 = boto3.client("route53")

def is_ip_reachable(ip, port=80, timeout=2):
    try:
        with socket.create_connection((ip, port), timeout):
            return True
    except:
        return False

def check_k8s(ip):
    try:
        response = requests.get(f"https://{ip}:6443/healthz", timeout=3, verify=False)
        return response.status_code == 200, response.text
    except Exception as e:
        return False, str(e)

def lambda_handler(event, context):
    hosted_zone = os.environ["HOSTED_ZONE"]
    record_name = os.environ["RECORD_NAME"]
    primary_ip = os.environ["PRIMARY_IP"]
    secondary_ip = os.environ["SECONDARY_IP"]
    workspace = os.environ["WORKSPACE"]
    cluster_phase_param = os.environ.get("CLUSTER_PHASE_PARAM", f"/kubernetes/{workspace}/k8s_phase")

    haproxy_nodes = [primary_ip, secondary_ip]

    # Get cluster phase
    try:
        phase = ssm.get_parameter(Name=cluster_phase_param)["Parameter"]["Value"]
    except ClientError as e:
        return {"status": "error", "message": f"Failed to get SSM param: {e}"}

    if phase == "preinit":
        for ip in haproxy_nodes:
            if is_ip_reachable(ip):
                try:
                    route53.change_resource_record_sets(
                        HostedZoneId=hosted_zone,
                        ChangeBatch={
                            "Comment": "Preinit: Set DNS to first reachable HAProxy",
                            "Changes": [{
                                "Action": "UPSERT",
                                "ResourceRecordSet": {
                                    "Name": record_name,
                                    "Type": "A",
                                    "TTL": 60,
                                    "ResourceRecords": [{"Value": ip}]
                                }
                            }]
                        }
                    )
                    return {"status": "success", "phase": "preinit", "selected_ip": ip}
                except ClientError as e:
                    return {"status": "error", "message": f"Route53 update failed: {e}"}
        return {"status": "error", "message": "No HAProxy nodes reachable during preinit"}

    elif phase == "postinit":
        for ip in haproxy_nodes:
            healthy, message = check_k8s(ip)
            if healthy:
                try:
                    route53.change_resource_record_sets(
                        HostedZoneId=hosted_zone,
                        ChangeBatch={
                            "Comment": "Postinit: Set DNS to healthy cluster",
                            "Changes": [{
                                "Action": "UPSERT",
                                "ResourceRecordSet": {
                                    "Name": record_name,
                                    "Type": "A",
                                    "TTL": 60,
                                    "ResourceRecords": [{"Value": ip}]
                                }
                            }]
                        }
                    )
                    return {"status": "success", "phase": "postinit", "selected_ip": ip}
                except ClientError as e:
                    return {"status": "error", "message": f"Route53 update failed: {e}"}
        return {"status": "error", "message": "No healthy Kubernetes cluster found"}

    else:
        return {"status": "error", "message": f"Unknown cluster phase: {phase}"}
