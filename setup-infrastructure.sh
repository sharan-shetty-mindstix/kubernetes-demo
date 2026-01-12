#!/bin/bash

# Complete infrastructure setup script
# This script sets up the entire Kubernetes infrastructure from scratch
# Run this after: minikube stop && minikube delete

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="platform-dev"

echo "================================================"
echo "Kubernetes Infrastructure Setup Script"
echo "================================================"
echo ""

# Step 1: Start Minikube with Calico CNI
echo "Step 1: Starting Minikube with Calico CNI..."
minikube start --cni=calico

echo "Waiting for Minikube to be ready..."
sleep 10

# Verify minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo "Error: Minikube failed to start"
    exit 1
fi

echo "✓ Minikube started successfully"
echo ""

# Verify Calico pods are running
echo "Waiting for Calico pods to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=120s || true
echo "✓ Calico CNI is ready"
echo ""

# Step 2: Create Namespace
echo "Step 2: Creating namespace..."
kubectl apply -f "$SCRIPT_DIR/k8s/namespaces/dev.yaml"
echo "✓ Namespace $NAMESPACE created"
echo ""

# Step 3: Apply ConfigMaps and Secrets
echo "Step 3: Applying ConfigMaps and Secrets..."
if [ -f "$SCRIPT_DIR/config/backend-config-dev.yaml" ]; then
    kubectl apply -f "$SCRIPT_DIR/config/backend-config-dev.yaml" -n "$NAMESPACE"
    echo "✓ Backend ConfigMap applied"
else
    echo "⚠ Warning: backend-config-dev.yaml not found in config/ directory"
fi

if [ -f "$SCRIPT_DIR/config/postgres-secret.yaml" ]; then
    kubectl apply -f "$SCRIPT_DIR/config/postgres-secret.yaml" -n "$NAMESPACE"
    echo "✓ PostgreSQL Secret applied"
else
    echo "⚠ Warning: postgres-secret.yaml not found in config/ directory"
fi
echo ""

# Step 4: Build Docker Images
echo "Step 4: Building Docker images..."
echo "Configuring shell to use Minikube Docker daemon..."
eval $(minikube docker-env)

echo "Building backend image..."
cd "$SCRIPT_DIR/backend"
docker build -t backend-demo:latest . || {
    echo "Error: Failed to build backend image"
    exit 1
}
echo "✓ Backend image built successfully"

echo "Building frontend image..."
cd "$SCRIPT_DIR/frontend"
docker build -t frontend-demo:latest . || {
    echo "Error: Failed to build frontend image"
    exit 1
}
echo "✓ Frontend image built successfully"

cd "$SCRIPT_DIR"
echo ""

# Step 5: Deploy Database (PostgreSQL)
echo "Step 5: Deploying PostgreSQL..."
kubectl apply -f "$SCRIPT_DIR/k8s/database/postgres-statefulset.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/database/postgres-service.yaml"

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n "$NAMESPACE" --timeout=300s || {
    echo "⚠ Warning: PostgreSQL may not be fully ready yet"
}
echo "✓ PostgreSQL deployed"
echo ""

# Step 6: Deploy Backend Application
echo "Step 6: Deploying backend application..."
kubectl apply -f "$SCRIPT_DIR/k8s/backend/backend-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend/backend-service.yaml"

echo "Waiting for backend pods to be ready..."
kubectl wait --for=condition=ready pod -l app=backend -n "$NAMESPACE" --timeout=180s || {
    echo "⚠ Warning: Backend pods may not be fully ready yet"
}
echo "✓ Backend deployed"
echo ""

# Step 7: Deploy Frontend Application
echo "Step 7: Deploying frontend application..."
kubectl apply -f "$SCRIPT_DIR/k8s/frontend/frontend-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/frontend/frontend-service.yaml"

echo "Waiting for frontend pods to be ready..."
kubectl wait --for=condition=ready pod -l app=frontend -n "$NAMESPACE" --timeout=120s || {
    echo "⚠ Warning: Frontend pods may not be fully ready yet"
}
echo "✓ Frontend deployed"
echo ""

# Step 8: Install Kubernetes Addons
echo "Step 8: Installing Kubernetes addons..."
echo "Enabling metrics-server..."
minikube addons enable metrics-server

echo "Enabling ingress addon..."
minikube addons enable ingress

echo "Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s || {
    echo "⚠ Warning: Ingress controller may not be fully ready yet"
}
echo "✓ Addons enabled"
echo ""

# Step 9: Configure Ingress
echo "Step 9: Configuring ingress..."
kubectl apply -f "$SCRIPT_DIR/k8s/frontend/frontend-ingress.yaml"
echo "✓ Ingress configured"
echo ""

# Step 10: Deploy Autoscaling and Disruption Budgets
echo "Step 10: Deploying autoscaling and disruption budgets..."
kubectl apply -f "$SCRIPT_DIR/k8s/backend/backend-hpa.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend/backend-pdb.yaml"
echo "✓ HPA and PDB deployed"
echo ""

# Step 11: Apply Network Policies
echo "Step 11: Applying network policies..."
if [ -f "$SCRIPT_DIR/apply-network-policies.sh" ]; then
    bash "$SCRIPT_DIR/apply-network-policies.sh"
else
    echo "⚠ Warning: apply-network-policies.sh not found, skipping network policies"
fi
echo ""

# Final Status
echo "================================================"
echo "Infrastructure Setup Complete!"
echo "================================================"
echo ""
echo "Current Status:"
echo "---------------"
kubectl get pods -n "$NAMESPACE"
echo ""
kubectl get services -n "$NAMESPACE"
echo ""
kubectl get ingress -n "$NAMESPACE"
echo ""
kubectl get networkpolicies -n "$NAMESPACE"
echo ""

# Get minikube IP for ingress
MINIKUBE_IP=$(minikube ip)
echo "To access the application:"
echo "1. Add to /etc/hosts: $MINIKUBE_IP frontend.local"
echo "2. Access: http://frontend.local"
echo ""
echo "Or use port-forward:"
echo "kubectl port-forward -n $NAMESPACE service/frontend-service 8080:80"
echo ""
