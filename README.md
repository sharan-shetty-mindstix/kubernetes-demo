# Kubernetes Demo with Calico CNI and Network Policies

This project demonstrates a complete Kubernetes setup using Minikube with Calico CNI, implementing a zero-trust network security model through Network Policies. All resources are deployed in the `platform-dev` namespace.

## Architecture

- **Frontend**: Nginx-based web application (port 80)
- **Backend**: Node.js Express API (port 3000)
- **Database**: PostgreSQL StatefulSet (port 5432)
- **Namespace**: `platform-dev`

## Prerequisites

- Minikube installed
- kubectl configured
- Docker installed
- Calico CNI support

## Step-by-Step Setup Guide

### Step 1: Start Minikube with Calico CNI

```bash
# Start minikube with Calico as the CNI plugin
minikube start --cni=calico

# Verify minikube is running
minikube status

# Verify Calico pods are running
kubectl get pods -n kube-system | grep calico
```

### Step 2: Create Namespace

```bash
# Create the platform-dev namespace
kubectl apply -f k8s/namespaces/dev.yaml

# Verify namespace
kubectl get namespace platform-dev
```

### Step 3: Apply ConfigMaps and Secrets

**Note**: ConfigMaps and Secrets are already present in the repository but are gitignored for security reasons. They should be located in the `config/` and `secrets/` directories.

Apply them using:

```bash
# Apply backend ConfigMap
kubectl apply -f config/backend-config-dev.yaml -n platform-dev

# Apply PostgreSQL Secret
kubectl apply -f config/postgres-secret.yaml -n platform-dev
```

### Step 4: Build Docker Images

Configure your shell to use the Minikube Docker daemon so you can build images directly inside Minikube:
```bash
eval $(minikube docker-env)
```

```bash
# Build backend image
cd backend
docker build -t backend-demo:latest .
minikube image load backend-demo:latest

# Build frontend image
cd ../frontend
docker build -t frontend-demo:latest .
minikube image load frontend-demo:latest

cd ..
```

### Step 5: Deploy Database (PostgreSQL)

```bash
# Deploy PostgreSQL StatefulSet
kubectl apply -f k8s/database/postgres-statefulset.yaml

# Deploy PostgreSQL Service
kubectl apply -f k8s/database/postgres-service.yaml

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n platform-dev --timeout=300s
```

### Step 6: Deploy Backend Application

```bash
# Deploy backend deployment
kubectl apply -f k8s/backend/backend-deployment.yaml

# Deploy backend service
kubectl apply -f k8s/backend/backend-service.yaml

# Verify backend pods
kubectl get pods -n platform-dev -l app=backend
```

### Step 7: Deploy Frontend Application

```bash
# Deploy frontend deployment
kubectl apply -f k8s/frontend/frontend-deployment.yaml

# Deploy frontend service
kubectl apply -f k8s/frontend/frontend-service.yaml

# Verify frontend pods
kubectl get pods -n platform-dev -l app=frontend
```

### Step 8: Install Kubernetes Addons

```bash
# Enable metrics-server for HPA
minikube addons enable metrics-server

# Enable ingress addon (NGINX Ingress Controller)
minikube addons enable ingress

# Verify addons are enabled
minikube addons list

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
```

### Step 9: Configure Ingress

```bash
# Deploy frontend ingress
kubectl apply -f k8s/frontend/frontend-ingress.yaml

# Get ingress IP
kubectl get ingress -n platform-dev

# Add to /etc/hosts (or equivalent)
# Get minikube IP: minikube ip
# Add: <minikube-ip> frontend.local
```

### Step 10: Deploy Autoscaling and Disruption Budgets

```bash
# Deploy Horizontal Pod Autoscaler for backend
kubectl apply -f k8s/backend/backend-hpa.yaml

# Deploy Pod Disruption Budget for backend
kubectl apply -f k8s/backend/backend-pdb.yaml

# Verify HPA
kubectl get hpa -n platform-dev
```

### Step 11: Apply Network Policies

**Important**: Network policies are applied using a script that ensures the correct order. The script applies policies in this sequence:

1. Deny-all policies (default-deny security model)
2. DNS egress policies (required for service discovery)
3. Application-specific policies (frontend ↔ backend ↔ postgres)
4. Ingress controller policies (external access)

```bash
# Make the script executable
chmod +x apply-network-policies.sh

# Apply all network policies
./apply-network-policies.sh
```

The script will:
- Apply all deny-all policies first
- Apply DNS egress policies
- Apply application-specific network policies
- Apply ingress controller network policies
- Verify all policies were applied successfully

### Step 12: Verify Network Policies

```bash
# List all network policies
kubectl get networkpolicies -n platform-dev

# Describe specific network policies
kubectl describe networkpolicy deny-all-ingress -n platform-dev
kubectl describe networkpolicy deny-all-egress -n platform-dev

# Test connectivity from frontend to backend
kubectl exec -it <frontend-pod-name> -n platform-dev -- wget -O- http://backend-service:3000/healthz
```

### Step 13: Verify Application Functionality

```bash
# Check all pods are running
kubectl get pods -n platform-dev

# Check services
kubectl get services -n platform-dev

# Check ingress
kubectl get ingress -n platform-dev

# Access the application
curl http://frontend.local/api/healthz
```

## Network Policy Architecture

The network policies implement a **zero-trust network model** where:

- **Frontend pods**: Can egress to backend (port 3000) and DNS
- **Backend pods**: Can ingress from frontend and ingress controller, egress to PostgreSQL (port 5432) and DNS
- **PostgreSQL pods**: Can ingress from backend (port 5432) and egress to DNS only
- **All pods**: Deny-all by default, with explicit allow rules

### Network Policy Application Order

The `apply-network-policies.sh` script applies policies in the correct order:

1. **Deny-all policies** (ingress and egress) - Establishes default-deny security
2. **DNS egress policies** - Allows DNS resolution (required for service discovery)
3. **Application-specific policies** - Allows frontend ↔ backend ↔ postgres communication
4. **Ingress controller policies** - Allows external access via ingress

## Troubleshooting

### Check pod connectivity

```bash
# Test DNS resolution
kubectl exec -it <pod-name> -n platform-dev -- nslookup backend-service

# Test HTTP connectivity
kubectl exec -it <pod-name> -n platform-dev -- wget -O- http://backend-service:3000/healthz
```

### View network policy logs

```bash
# Check Calico logs
kubectl logs -n kube-system -l k8s-app=calico-node

# Check network policy events
kubectl get events -n platform-dev --field-selector involvedObject.kind=NetworkPolicy
```

### Common Issues

1. **DNS not working**: Ensure DNS egress policies are applied before other policies (handled by the script)
2. **Services unreachable**: Verify network policies allow traffic on correct ports
3. **Ingress not working**: Ensure ingress controller policies are applied (handled by the script)

## Cleanup

```bash
# Delete all resources in platform-dev namespace
kubectl delete namespace platform-dev

# Stop minikube
minikube stop

# Delete minikube cluster
minikube delete
```

## Project Structure

```
kubernetes-demo/
├── backend/              # Backend application
│   ├── Dockerfile
│   ├── package.json
│   └── src/
├── frontend/             # Frontend application
│   ├── Dockerfile
│   ├── index.html
│   └── app.js
├── k8s/                  # Kubernetes manifests
│   ├── backend/          # Backend resources and network policies
│   ├── frontend/         # Frontend resources and network policies
│   ├── database/        # PostgreSQL resources and network policies
│   └── namespaces/      # Namespace definitions
├── config/               # ConfigMaps (gitignored)
├── apply-network-policies.sh  # Script to apply all network policies
└── README.md
```

## Notes

- All resources are deployed in the `platform-dev` namespace
- ConfigMaps and Secrets are present but gitignored for security
- Network policies follow a default-deny, explicit-allow model
- Calico CNI is required for NetworkPolicy support
- Use the `apply-network-policies.sh` script to apply all network policies in the correct order
