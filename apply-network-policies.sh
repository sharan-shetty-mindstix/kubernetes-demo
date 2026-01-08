#!/bin/bash

# Script to apply all network policies in the correct order
# This ensures proper network policy configuration for the platform-dev namespace

set -e

NAMESPACE="platform-dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Applying network policies to namespace: $NAMESPACE"
echo "================================================"

# Step 1: Apply deny-all policies first (default-deny security model)
echo ""
echo "Step 1: Applying deny-all policies..."
kubectl apply -f "$SCRIPT_DIR/k8s/backend/deny-all-ingress.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend/deny-all-egress.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/database/postgres-deny-all.yaml"

# Step 2: Apply DNS egress policies (required for service discovery)
echo ""
echo "Step 2: Applying DNS egress policies..."
kubectl apply -f "$SCRIPT_DIR/k8s/backend/allow-dns-egress.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend/backend-allow-dns.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/frontend/frontend-allow-dns.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/database/postgres-allow-dns.yaml"

# Step 3: Apply application-specific network policies
echo ""
echo "Step 3: Applying application-specific network policies..."
kubectl apply -f "$SCRIPT_DIR/k8s/backend/allow-frontend-egress-backend.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend/allow-frontend-to-backend.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend/allow-postgres-egress.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/database/postgres-allow-backend.yaml"

# Step 4: Apply ingress controller network policies
echo ""
echo "Step 4: Applying ingress controller network policies..."
kubectl apply -f "$SCRIPT_DIR/k8s/frontend/allow-ingress-to-frontend.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend/allow-ingress-to-backend.yaml"

echo ""
echo "================================================"
echo "All network policies applied successfully!"
echo ""
echo "Verifying network policies..."
kubectl get networkpolicies -n $NAMESPACE
