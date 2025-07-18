import os
import requests
import boto3
from botocore.exceptions import ClientError

ssm = boto3.client("ssm")
route53 = boto3.client("route53")

def check_health(ip, phase):
    if phase == "preinit":
        url = f"http://{ip}:8080/health"
    elif phase == "postinit":
        url = f"https://{ip}:6443/healthz"
    else:
        return False, f"Unknown phase: {phase}"

    try:
        response = requests.get(url, timeout=3, verify=False)
        print(response.status_code)
        return response.status_code == 200, response.text
    except Exception as e:
        return False, str(e)

def lambda_handler(event, context):
    hosted_zone = os.environ["HOSTED_ZONE"]
    record_name = os.environ["RECORD_NAME"]
    primary_ip = os.environ["PRIMARY_IP"]
    secondary_ip = os.environ["SECONDARY_IP"]
    workspace = os.environ["WORKSPACE"]
    cluster_phase_param = os.environ.get("CLUSTER_PHASE_PARAM", f"/kubernetes/{workspace}/cluster_phase")

    haproxy_nodes = [primary_ip, secondary_ip]

    # Get cluster phase
    try:
        phase = ssm.get_parameter(Name=cluster_phase_param)["Parameter"]["Value"]
    except ClientError as e:
        return {"status": "error", "message": f"Failed to get SSM param: {e}"}

    if phase not in ("preinit", "postinit"):
        return {"status": "error", "message": f"Unknown cluster phase: {phase}"}

    for ip in haproxy_nodes:
        healthy, message = check_health(ip, phase)
        if healthy:
            try:
                route53.change_resource_record_sets(
                    HostedZoneId=hosted_zone,
                    ChangeBatch={
                        "Comment": f"{phase}: Set DNS to healthy endpoint",
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
                return {"status": "success", "phase": phase, "selected_ip": ip}
            except ClientError as e:
                return {"status": "error", "message": f"Route53 update failed: {e}"}

    return {"status": "error", "message": f"No healthy nodes found during {phase}"}
