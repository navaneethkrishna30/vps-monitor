#!/bin/bash

# Load configuration from environment variables or config file
INSTANCE_ID=${INSTANCE_ID:-$(cat /opt/vps-monitor/configs/node-metrics.conf | grep INSTANCE_ID | cut -d'"' -f2)}
NODE_TYPE=${NODE_TYPE:-$(cat /opt/vps-monitor/configs/node-metrics.conf | grep NODE_TYPE | cut -d'"' -f2)}
SERVER_ADDRESS=${SERVER_ADDRESS:-$(cat /opt/vps-monitor/configs/node-metrics.conf | grep SERVER_ADDRESS | cut -d'"' -f2)}
LOG_PATH=${LOG_PATH:-"/var/log"}
PUSH_INTERVAL=${PUSH_INTERVAL:-"15s"}
MONITOR_DOCKER=${MONITOR_DOCKER:-"true"}
SERVICES_TO_MONITOR=${SERVICES_TO_MONITOR:-$(cat /opt/vps-monitor/configs/node-metrics.conf | grep SERVICES_TO_MONITOR | cut -d'"' -f2)}
MONITOR_SERVICES=${MONITOR_SERVICES:-$(cat /opt/vps-monitor/configs/node-metrics.conf | grep MONITOR_SERVICES | cut -d'"' -f2)}

echo "Starting node metrics service with:"
echo "Instance ID: $INSTANCE_ID"
echo "Node Type: $NODE_TYPE"
echo "Server Address: $SERVER_ADDRESS"
echo "Log Path: $LOG_PATH"
echo "Push Interval: $PUSH_INTERVAL"

# Function to push metrics to Pushgateway
push_metrics() {
    local status=$1
    local node_name=$2
    
    # Create temporary file for metrics
    local temp_file=$(mktemp)
    
    # Write metrics to temporary file
    cat > "$temp_file" << EOF
# HELP node_status Node status (1=active, 0=inactive)
# TYPE node_status gauge
node_status{instance_id="$INSTANCE_ID", node_type="$NODE_TYPE", node_name="$node_name", status="active"} $status
EOF

    # Push metrics to Pushgateway
    curl -s --data-binary @"$temp_file" "$SERVER_ADDRESS:9091/metrics/job/node_metrics/instance_id/$INSTANCE_ID/node_type/$NODE_TYPE/node_name/$node_name"
    
    # Remove temporary file
    rm "$temp_file"
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    local status=0
    
    if systemctl is-active --quiet "$service_name"; then
        status=1
    fi
    
    push_metrics $status "$service_name"
    echo "$(date): Service $service_name status: $status" >> "$LOG_PATH/${service_name}.log"
}

# Function to check if a Docker container is running
check_docker_container() {
    local container_name=$1
    local status=0
    
    if [ "$(docker ps -q -f name=$container_name)" ]; then
        status=1
    fi
    
    push_metrics $status "$container_name"
    echo "$(date): Container $container_name status: $status" >> "$LOG_PATH/${container_name}.log"
}

# Main loop
while true; do
    # Check services if enabled
    if [ "$MONITOR_SERVICES" = "true" ] && [ ! -z "$SERVICES_TO_MONITOR" ]; then
        IFS=',' read -ra SERVICES <<< "$SERVICES_TO_MONITOR"
        for service in "${SERVICES[@]}"; do
            check_service "$service"
        done
    fi
    
    # Check Docker containers if enabled
    if [ "$MONITOR_DOCKER" = "true" ]; then
        # Get list of running containers
        containers=$(docker ps --format "{{.Names}}")
        
        # Check each container
        for container in $containers; do
            check_docker_container "$container"
        done
    fi
    
    # Sleep for the specified interval
    sleep "$PUSH_INTERVAL"
done
