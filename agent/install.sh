#!/bin/bash

# VPS Monitor Agent Installation Script

# Default values
DEFAULT_SERVER_ADDRESS="http://localhost"
DEFAULT_NODE_TYPE="GENERIC"
DEFAULT_INSTANCE_ID=$(hostname)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --server-address)
        SERVER_ADDRESS="$2"
        shift
        shift
        ;;
        --node-type)
        NODE_TYPE="$2"
        shift
        shift
        ;;
        --instance-id)
        INSTANCE_ID="$2"
        shift
        shift
        ;;
        --services)
        SERVICES_TO_MONITOR="$2"
        shift
        shift
        ;;
        *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Set defaults if not provided
SERVER_ADDRESS=${SERVER_ADDRESS:-$DEFAULT_SERVER_ADDRESS}
NODE_TYPE=${NODE_TYPE:-$DEFAULT_NODE_TYPE}
INSTANCE_ID=${INSTANCE_ID:-$DEFAULT_INSTANCE_ID}

echo "Installing VPS Monitor Agent..."
echo "Server Address: $SERVER_ADDRESS"
echo "Node Type: $NODE_TYPE"
echo "Instance ID: $INSTANCE_ID"
echo "Services to Monitor: $SERVICES_TO_MONITOR"

# Create installation directory
sudo mkdir -p /opt/vps-monitor/bin
sudo mkdir -p /opt/vps-monitor/configs

# Copy scripts
sudo cp "$(dirname "$0")/node-metrics.sh" /opt/vps-monitor/bin/
sudo chmod +x /opt/vps-monitor/bin/node-metrics.sh

# Create config file
cat > /tmp/node-metrics.conf << EOF
INSTANCE_ID="$INSTANCE_ID"
NODE_TYPE="$NODE_TYPE"
SERVER_ADDRESS="$SERVER_ADDRESS"
LOG_PATH="/var/log"
PUSH_INTERVAL="15s"
MONITOR_DOCKER="true"
SERVICES_TO_MONITOR="$SERVICES_TO_MONITOR"
MONITOR_SERVICES="true"
EOF

sudo mv /tmp/node-metrics.conf /opt/vps-monitor/configs/

# Download and install Promtail
echo "Installing Promtail for log shipping..."
PROMTAIL_VERSION="2.8.0"
wget -q -O /tmp/promtail.zip "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
unzip -q /tmp/promtail.zip -d /tmp
sudo mv /tmp/promtail-linux-amd64 /opt/vps-monitor/bin/promtail
sudo chmod +x /opt/vps-monitor/bin/promtail

# Create Promtail configuration
cat > /tmp/promtail-config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /opt/vps-monitor/configs/positions.yaml

clients:
  - url: ${SERVER_ADDRESS}:3100/loki/api/v1/push

scrape_configs:
  - job_name: node_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: node_logs
          instance_id: ${INSTANCE_ID}
          node_type: ${NODE_TYPE}
          __path__: /var/log/*.log
EOF

sudo mv /tmp/promtail-config.yml /opt/vps-monitor/configs/

# Create systemd service for node-metrics
cat > /tmp/node-metrics.service << EOF
[Unit]
Description=VPS Node Metrics Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/vps-monitor/bin/node-metrics.sh
Restart=always
RestartSec=10
Environment="INSTANCE_ID=$INSTANCE_ID"
Environment="NODE_TYPE=$NODE_TYPE"
Environment="SERVER_ADDRESS=$SERVER_ADDRESS"

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/node-metrics.service /etc/systemd/system/

# Create systemd service for Promtail
cat > /tmp/promtail.service << EOF
[Unit]
Description=Promtail Log Shipper
After=network.target

[Service]
Type=simple
ExecStart=/opt/vps-monitor/bin/promtail -config.file=/opt/vps-monitor/configs/promtail-config.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/promtail.service /etc/systemd/system/

# Reload systemd, enable and start services
sudo systemctl daemon-reload
sudo systemctl enable node-metrics.service promtail.service
sudo systemctl start node-metrics.service promtail.service

echo "VPS Monitor Agent installation completed!"
echo "Node metrics service and Promtail log shipper are now running."
