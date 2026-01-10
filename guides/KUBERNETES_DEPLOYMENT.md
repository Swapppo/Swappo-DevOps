# Kubernetes Deployment Guide for Swappo

This guide will walk you through deploying Swappo to Kubernetes using Docker Desktop's built-in Kubernetes cluster.

## What is Kubernetes?

Kubernetes (K8s) is a container orchestration platform that:
- **Manages containers** across multiple machines (or locally in Docker Desktop)
- **Auto-restarts** crashed containers
- **Scales** applications up/down based on load
- **Load balances** traffic across container replicas
- **Manages** storage, networking, secrets, and configuration

### Key Concepts

1. **Pod**: Smallest deployable unit (one or more containers)
2. **Deployment**: Manages multiple identical Pods (replicas)
3. **Service**: Exposes Pods to network traffic (like a load balancer)
4. **PersistentVolumeClaim (PVC)**: Requests storage for data that persists beyond Pod lifetime
5. **ConfigMap**: Stores non-sensitive configuration
6. **Secret**: Stores sensitive data (passwords, tokens) in base64
7. **Namespace**: Virtual cluster for organizing resources

## Prerequisites

### 1. Enable Kubernetes in Docker Desktop

1. Open **Docker Desktop**
2. Go to **Settings** → **Kubernetes**
3. Check **Enable Kubernetes**
4. Click **Apply & Restart**
5. Wait for the green "Kubernetes running" indicator

### 2. Verify Kubernetes is Running

```powershell
kubectl version --client
kubectl cluster-info
```

You should see:
```
Kubernetes control plane is running at https://kubernetes.docker.internal:6443
```

## Step 1: Build Docker Images

Before deploying to Kubernetes, you need to build Docker images for each service.

### Build All Services

Run these commands from the **root** of your Swappo project:

```powershell
# Auth Service
cd Swappo-Auth
docker build -t swappo-auth:latest .
cd ..

# Catalog Service
cd Swappo-Catalog
docker build -t swappo-catalog:latest .
cd ..

# Matchmaking Service
cd Swappo-Matchmaking
docker build -t swappo-matchmaking:latest .
cd ..

# Notifications Service
cd Swappo-Notifications
docker build -t swappo-notifications:latest .
cd ..

# Chat Service
cd Swappo-Chat
docker build -t swappo-chat:latest .
cd ..
```

### Verify Images

```powershell
docker images | Select-String "swappo"
```

You should see:
```
swappo-auth           latest    ...
swappo-catalog        latest    ...
swappo-matchmaking    latest    ...
swappo-notifications  latest    ...
swappo-chat           latest    ...
```

## Step 2: Deploy to Kubernetes

### Apply All Manifests

From the **root** of your project:

```powershell
kubectl apply -f k8s/
```

This applies all `.yaml` files in the `k8s/` directory in order:
1. **namespace.yaml** - Creates `swappo` namespace
2. **configmap.yaml** - Loads configuration
3. **secrets.yaml** - Loads passwords/tokens
4. **Database deployments** - Creates PostgreSQL instances
5. **Service deployments** - Creates application services

### Or Apply Step-by-Step

```powershell
# 1. Create namespace
kubectl apply -f k8s/namespace.yaml

# 2. Load configuration
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml

# 3. Deploy databases
kubectl apply -f k8s/auth-db.yaml
kubectl apply -f k8s/catalog-db.yaml
kubectl apply -f k8s/matchmaking-db.yaml
kubectl apply -f k8s/notifications-db.yaml
kubectl apply -f k8s/chat-db.yaml

# 4. Wait for databases to be ready (2-3 minutes)
kubectl wait --for=condition=ready pod -l app=auth-db -n swappo --timeout=300s
kubectl wait --for=condition=ready pod -l app=catalog-db -n swappo --timeout=300s
kubectl wait --for=condition=ready pod -l app=matchmaking-db -n swappo --timeout=300s
kubectl wait --for=condition=ready pod -l app=notifications-db -n swappo --timeout=300s
kubectl wait --for=condition=ready pod -l app=chat-db -n swappo --timeout=300s

# 5. Deploy services
kubectl apply -f k8s/auth-service.yaml
kubectl apply -f k8s/catalog-service.yaml
kubectl apply -f k8s/matchmaking-service.yaml
kubectl apply -f k8s/notifications-service.yaml
kubectl apply -f k8s/chat-service.yaml
```

## Step 3: Verify Deployment

### Check All Resources

```powershell
# View all resources in swappo namespace
kubectl get all -n swappo

# View pods (should show 2 replicas per service)
kubectl get pods -n swappo

# View services (should show LoadBalancer/ClusterIP)
kubectl get services -n swappo

# View persistent volume claims (storage)
kubectl get pvc -n swappo
```

### Check Pod Status

```powershell
# All pods should show "Running" status
kubectl get pods -n swappo
```

If a pod shows **Pending**, **CrashLoopBackOff**, or **Error**:

```powershell
# Get detailed info
kubectl describe pod <pod-name> -n swappo

# View logs
kubectl logs <pod-name> -n swappo

# Example:
kubectl logs auth-service-5d8f9c7b6d-xk2pm -n swappo
```

## Step 4: Access Your Services

### Get Service URLs

```powershell
kubectl get services -n swappo
```

You'll see something like:

```
NAME                    TYPE           EXTERNAL-IP   PORT(S)
auth-service            LoadBalancer   localhost     8000:30001/TCP
catalog-service         LoadBalancer   localhost     8000:30002/TCP
matchmaking-service     LoadBalancer   localhost     8000:30003/TCP
notifications-service   ClusterIP      None          8000/TCP
chat-service            LoadBalancer   localhost     8000:30004/TCP
```

### Access External Services

Since we're using Docker Desktop Kubernetes, LoadBalancer services are accessible at:

- **Auth**: `http://localhost:30001`
- **Catalog**: `http://localhost:30002`
- **Matchmaking**: `http://localhost:30003`
- **Chat**: `http://localhost:30004`

**Note**: The ports (30001, 30002, etc.) are randomly assigned by Kubernetes. Check `kubectl get services -n swappo` for actual ports.

### Test Health Endpoints

```powershell
# Test auth service
curl http://localhost:30001/health

# Test catalog service
curl http://localhost:30002/health
```

## Step 5: Update Frontend Configuration

Update your React Native app's API URLs to point to Kubernetes services.

In `Swappo-FE/config/api.config.ts`:

```typescript
export const API_CONFIG = {
  AUTH_SERVICE: 'http://localhost:30001',
  CATALOG_SERVICE: 'http://localhost:30002',
  MATCHMAKING_SERVICE: 'http://localhost:30003',
  CHAT_SERVICE: 'http://localhost:30004',
};
```

**Replace port numbers** with actual values from `kubectl get services -n swappo`.

## Common Commands

### View Logs

```powershell
# Real-time logs for a pod
kubectl logs -f <pod-name> -n swappo

# Logs for all replicas of a service
kubectl logs -l app=auth-service -n swappo
```

### Restart a Service

```powershell
# Delete pods (they'll auto-recreate)
kubectl rollout restart deployment auth-service -n swappo
```

### Scale Services

```powershell
# Increase replicas to 3
kubectl scale deployment auth-service --replicas=3 -n swappo

# Decrease to 1
kubectl scale deployment auth-service --replicas=1 -n swappo
```

### Access Pod Shell

```powershell
# Open bash shell in a pod
kubectl exec -it <pod-name> -n swappo -- /bin/bash

# Example: Access database
kubectl exec -it auth-db-0 -n swappo -- psql -U swappo -d swappo_auth
```

### Delete Everything

```powershell
# Delete all resources in namespace
kubectl delete namespace swappo
```

## Troubleshooting

### Pods Not Starting

1. **Check logs**:
   ```powershell
   kubectl logs <pod-name> -n swappo
   ```

2. **Check events**:
   ```powershell
   kubectl get events -n swappo --sort-by='.lastTimestamp'
   ```

3. **Describe pod**:
   ```powershell
   kubectl describe pod <pod-name> -n swappo
   ```

### Database Connection Issues

- Ensure databases are running:
  ```powershell
  kubectl get pods -n swappo | Select-String "db"
  ```

- Check database logs:
  ```powershell
  kubectl logs auth-db-0 -n swappo
  ```

### Image Not Found

If you see `ImagePullBackOff` or `ErrImagePull`:

1. Verify image exists:
   ```powershell
   docker images | Select-String "swappo"
   ```

2. Rebuild image:
   ```powershell
   cd Swappo-Auth
   docker build -t swappo-auth:latest .
   ```

3. Restart deployment:
   ```powershell
   kubectl rollout restart deployment auth-service -n swappo
   ```

## Differences from Docker Compose

| Docker Compose | Kubernetes |
|----------------|------------|
| `docker-compose up` | `kubectl apply -f k8s/` |
| `docker-compose down` | `kubectl delete -f k8s/` |
| `docker-compose logs` | `kubectl logs` |
| `docker-compose ps` | `kubectl get pods` |
| Single machine | Multi-machine (but Docker Desktop is single) |
| Simple YAML | More complex, but more powerful |
| No built-in scaling | Auto-scaling with replicas |
| Container restart on crash | Pod restart + health checks |

## Next Steps

1. **Monitoring**: Install Prometheus/Grafana for metrics
2. **Logging**: Install ELK stack for centralized logs
3. **CI/CD**: Automate builds and deployments
4. **Production**: Deploy to cloud Kubernetes (AKS, EKS, GKE)
5. **Ingress Controller**: Use NGINX Ingress for better routing

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Desktop Kubernetes](https://docs.docker.com/desktop/kubernetes/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
