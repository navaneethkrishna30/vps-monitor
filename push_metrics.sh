#!/bin/bash

# Script to push a simple status metric to Prometheus Pushgateway

set -euo pipefail

PUSHGATEWAY_URL="${1:?Provide Pushgateway URL (e.g., http://your-monitor-server:9091)}"
NODE_TYPE="${2:?Provide Node Type (e.g., NEXUS, BLESS)}"
INSTANCE_ID="${3:?Provide unique Instance ID (e.g., vps-hostname or service-id)}"
STATUS="${4:?Provide Status (1 for active, 0 for inactive)}"

METRIC_NAME="vps_node_status"
JOB_NAME="vps_nodes"

# Validate status
if [[ ! "$STATUS" =~ ^(0|1)$ ]]; then
  echo "Error: Status must be 0 (inactive) or 1 (active)." >&2
  exit 1
fi

# Prepare the metric payload
# Using process substitution to feed the metric line to curl via stdin
# Format: <metric_name>{<label1>="<value1>",<label2>="<value2>"} <value>
metric_payload() {
  cat <<EOF
# TYPE ${METRIC_NAME} gauge
${METRIC_NAME}{node_type="${NODE_TYPE}", instance="${INSTANCE_ID}"} ${STATUS}
EOF
}

# Push the metric to Pushgateway
# Grouping key is {job="${JOB_NAME}", instance="${INSTANCE_ID}"} to ensure metrics replace correctly for this instance.
TARGET_URL="${PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}/instance/${INSTANCE_ID}"

echo "Pushing metric to ${TARGET_URL}"
metric_payload | curl --silent --show-error --data-binary @- "${TARGET_URL}"

if [ $? -eq 0 ]; then
  echo "Metric pushed successfully."
else
  echo "Error: Failed to push metric." >&2
  exit 1
fi

exit 0
