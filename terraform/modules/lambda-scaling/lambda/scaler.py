"""EKS managed node group scaler.

Spec §12 — schedule-driven cost optimization. EventBridge invokes this Lambda
twice a day with {"action": "scale_up"} or {"action": "scale_down"}. Stateful
node groups are intentionally untouched: only the compute pool moves.

Environment variables (set by Terraform):
    CLUSTER_NAME       EKS cluster name
    NODE_GROUP_NAME    Managed node group name (default: compute-ng)
    MIN_SIZE           Min size on scale up
    DESIRED_SIZE       Desired size on scale up
    MAX_SIZE           Max size on scale up
"""

from __future__ import annotations

import logging
import os
from typing import Any

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

eks = boto3.client("eks")


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    action = (event or {}).get("action", "scale_up")
    cluster = os.environ["CLUSTER_NAME"]
    nodegroup = os.environ.get("NODE_GROUP_NAME", "compute-ng")

    if action == "scale_up":
        scaling = {
            "minSize": int(os.environ.get("MIN_SIZE", "1")),
            "desiredSize": int(os.environ.get("DESIRED_SIZE", "1")),
            "maxSize": int(os.environ.get("MAX_SIZE", "10")),
        }
    elif action == "scale_down":
        scaling = {"minSize": 0, "desiredSize": 0, "maxSize": int(os.environ.get("MAX_SIZE", "10"))}
    else:
        raise ValueError(f"Unknown action: {action!r} (expected scale_up or scale_down)")

    logger.info("Updating %s/%s to %s", cluster, nodegroup, scaling)

    response = eks.update_nodegroup_config(
        clusterName=cluster,
        nodegroupName=nodegroup,
        scalingConfig=scaling,
    )

    update = response.get("update", {})
    return {
        "status": "ok",
        "action": action,
        "cluster": cluster,
        "nodegroup": nodegroup,
        "scaling": scaling,
        "updateId": update.get("id"),
        "updateStatus": update.get("status"),
    }
