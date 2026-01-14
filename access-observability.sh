#!/bin/bash

# Script to access Prometheus and Grafana in browser
# This script will set up port-forwarding for both services

echo "================================================"
echo "Observability Stack Access"
echo "================================================"
echo ""
echo "Starting port-forwarding for Prometheus and Grafana..."
echo ""
echo "Press Ctrl+C to stop port-forwarding"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Stopping port-forwarding..."
    kill $GRAFANA_PID $PROMETHEUS_PID 2>/dev/null
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start Grafana port-forward in background
echo "Starting Grafana port-forward (http://localhost:3000)..."
kubectl port-forward -n observability service/prometheus-grafana 3000:80 > /dev/null 2>&1 &
GRAFANA_PID=$!

# Start Prometheus port-forward in background
echo "Starting Prometheus port-forward (http://localhost:9090)..."
kubectl port-forward -n observability service/prometheus-kube-prometheus-prometheus 9090:9090 > /dev/null 2>&1 &
PROMETHEUS_PID=$!

# Wait a moment for port-forwarding to start
sleep 2

echo ""
echo "✓ Port-forwarding started successfully!"
echo ""
echo "Access the services:"
echo "-------------------"
echo "Grafana:    http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Prometheus: http://localhost:9090"
echo ""
echo "Press Ctrl+C to stop port-forwarding"
echo ""

# Wait for user interrupt
wait
