# VPS Monitoring System

A comprehensive monitoring solution for your VPS nodes using Prometheus, Loki, Grafana, and Pushgateway.

## Overview

This monitoring system allows you to:
- Monitor the status (active/inactive) of services and Docker containers across multiple VPS instances
- Filter nodes by type (NEXUS, BLESS, T3RN, etc.) and instance ID
- View logs from all your nodes in a centralized Grafana dashboard
- Track trends in node uptime and status over time

## Architecture

The system consists of two main components:

1. **Server** (Central monitoring server):
   - Prometheus: Time-series database for storing metrics
   - Pushgateway: Endpoint for receiving metrics from nodes
   - Loki: Log aggregation system
   - Grafana: Visualization and dashboarding

2. **Agent** (Installed on each VPS):
   - Node Metrics Service: Collects and pushes metrics about services and Docker containers
   - Promtail: Ships logs to Loki

## Setup Instructions

### Server Setup

1. Clone this repository to your central monitoring server
2. Navigate to the server directory:
   ```
   cd vps-monitor/server
   ```
3. Start the monitoring stack:
   ```
   docker-compose up -d
   ```
4. Access Grafana at `http://your-server-ip:3000` (default credentials: admin/admin)

### Agent Setup

Install the monitoring agent on each VPS you want to monitor:

1. Copy the `agent` directory to your VPS
2. Run the installation script with appropriate parameters:
   ```
   cd agent
   chmod +x install.sh
   ./install.sh --server-address "http://your-server-ip" --node-type "NEXUS" --instance-id "vps1" --services "service1,service2"
   ```

Parameters:
- `--server-address`: Address of your central monitoring server
- `--node-type`: Type of node (NEXUS, BLESS, T3RN, etc.)
- `--instance-id`: Unique identifier for this VPS
- `--services`: Comma-separated list of services to monitor

## Configuration

### Agent Configuration

The agent configuration is stored in `/opt/vps-monitor/configs/node-metrics.conf` and includes:

- `INSTANCE_ID`: Unique identifier for the VPS
- `NODE_TYPE`: Type of node (NEXUS, BLESS, T3RN, etc.)
- `SERVER_ADDRESS`: Address of the central monitoring server
- `LOG_PATH`: Path to log files (default: /var/log)
- `PUSH_INTERVAL`: How often to push metrics (default: 15s)
- `MONITOR_DOCKER`: Whether to monitor Docker containers (true/false)
- `SERVICES_TO_MONITOR`: Comma-separated list of services to monitor
- `MONITOR_SERVICES`: Whether to monitor services (true/false)

### Server Configuration

- Prometheus configuration: `/server/prometheus/prometheus.yml`
- Loki configuration: `/server/loki/loki-config.yml`
- Grafana dashboards: `/server/grafana/dashboards/`

## Dashboard Usage

The Grafana dashboard provides:

1. **Node Status Overview**:
   - Total active nodes
   - Total inactive nodes
   - Total nodes

2. **Node Status by Type**:
   - Active nodes by type
   - Inactive nodes by type

3. **Node Logs**:
   - Centralized log view with filtering by instance ID and node type

Use the filters at the top of the dashboard to select specific node types or instance IDs.

## Retention and Scaling

- Prometheus is configured to retain metrics for 30 days by default
- Loki is configured to retain logs for 30 days by default
- Both can be scaled horizontally for larger deployments

## Troubleshooting

- Check agent logs: `journalctl -u node-metrics.service`
- Check Promtail logs: `journalctl -u promtail.service`
- Verify connectivity: `curl http://your-server-ip:9091` (Pushgateway)
- Verify metrics are being pushed: `curl http://your-server-ip:9090/api/v1/targets` (Prometheus)
