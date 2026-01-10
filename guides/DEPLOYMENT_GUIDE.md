# Swappo Deployment Guide

## Environment Overview

### Development (Local Kubernetes)
- **Ingress URL**: http://localhost
- **Frontend**: Local Expo dev server or web build
- **Backend**: Local Kubernetes cluster (Docker Desktop/Minikube)
- **Database**: PostgreSQL pods in local cluster
- **Environment File**: `.env.development`

### Production (GKE)
- **Ingress URL**: https://34.185.186.13.nip.io
- **Frontend**: Firebase Hosting (https://swappo-a34df.web.app)
- **Backend**: Google Kubernetes Engine
- **Database**: PostgreSQL pods in GKE cluster
- **Environment File**: `.env.production`

---

## API Endpoint Structure

Both environments use the **same URL structure** through nginx ingress:

```
Base URL + Service Prefix + API Path
```

### Examples:
- **Auth**: `{BASE_URL}/auth/api/v1/auth/login`
- **Catalog**: `{BASE_URL}/catalog/items/feed`
- **Matchmaking**: `{BASE_URL}/matchmaking/api/v1/offers`
- **Chat**: `{BASE_URL}/chat/api/v1/chat-rooms`
- **Notifications**: `{BASE_URL}/notifications/api/v1/notifications/{userId}`

**Development**: `http://localhost/catalog/items/feed`
**Production**: `https://34.185.186.13.nip.io/catalog/items/feed`

---

## Frontend Configuration

The frontend uses centralized API configuration in `config/api.config.ts` that reads from environment variables:

```typescript
BASE_URL: ENV.API_BASE_URL  // Loaded from .env.development or .env.production
```

### Running Frontend Locally (Against Local Backend)
```powershell
# Development mode (uses .env.development)
npm run start

# Web build for local testing (uses .env.development)
npx expo export --platform web
npx serve dist
```

### Deploying Frontend to Production (Against GKE Backend)
```powershell
# Uses .env.production automatically
.\deploy-web.ps1
```

---

## Backend Deployment

### Local Kubernetes Deployment

1. **Ensure nginx ingress controller is installed:**
   ```powershell
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   ```

2. **Deploy all services:**
   ```powershell
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/secrets.yaml
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/
   ```

3. **Verify ingress:**
   ```powershell
   kubectl get ingress -n swappo
   curl http://localhost/catalog/health
   ```

### GKE (Production) Deployment

1. **Update Docker images (if code changed):**
   ```powershell
   # Build and push new images
   cd Swappo-Catalog
   docker build -t gcr.io/swappo-rso/catalog-service:latest .
   docker push gcr.io/swappo-rso/catalog-service:latest
   
   # Repeat for other services...
   ```

2. **Apply Kubernetes manifests:**
   ```powershell
   kubectl apply -f k8s-gke/
   ```

3. **Restart deployments to pull latest images:**
   ```powershell
   kubectl rollout restart deployment/catalog-service -n swappo
   kubectl rollout restart deployment/auth-service -n swappo
   # etc...
   ```

---

## Key Differences: k8s vs k8s-gke

| Feature | k8s (Local) | k8s-gke (Production) |
|---------|-------------|----------------------|
| **Ingress Host** | `localhost` | `34.185.186.13.nip.io` |
| **TLS/HTTPS** | No | Yes (cert-manager + Let's Encrypt) |
| **Security Context** | ✅ Added (catalog) | ✅ Added (catalog) |
| **Image Registry** | ghcr.io/filipTurk | ghcr.io/swapppo |
| **Ingress Controller** | nginx (manual install) | nginx (GKE pre-installed) |
| **Load Balancer** | NodePort/HostPort | GCP Load Balancer |
| **Cert Manager** | Not needed | Required (cluster-issuer.yaml) |

---

## Deployment Scripts

### Local Development Script
Create `deploy-local.ps1`:
```powershell
# Deploy to local Kubernetes for development
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/

# Wait for deployments
kubectl wait --for=condition=available --timeout=120s deployment --all -n swappo

# Show status
kubectl get all -n swappo
```

### Production Deployment Script
Use existing `update-and-deploy-local.ps1` or create `deploy-gke.ps1`:
```powershell
# Deploy to GKE for production
kubectl apply -f k8s-gke/

# Restart deployments to pull latest images
kubectl rollout restart deployment --all -n swappo

# Monitor rollout
kubectl rollout status deployment/catalog-service -n swappo

# Show status
kubectl get all -n swappo
```

---

## Troubleshooting

### Frontend points to wrong backend
- Check which `.env` file Expo is using
- Development mode auto-loads `.env.development`
- Production builds use `.env.production`
- Use `console.log(ENV.API_BASE_URL)` to verify

### Local ingress not working
```powershell
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress configuration
kubectl describe ingress swappo-ingress -n swappo

# Test directly to service (bypass ingress)
kubectl port-forward svc/catalog-service 8001:8000 -n swappo
curl http://localhost:8001/health
```

### Permission denied on uploads (Catalog service)
- Ensure security context is set in deployment YAML
- Verify PVC is properly mounted
```powershell
kubectl describe pod -l app=catalog-service -n swappo
kubectl exec -it deployment/catalog-service -n swappo -- ls -la /app/uploads
```

### HTTPS/Mixed content errors
- Development (HTTP): Normal, expected
- Production (HTTPS): All API calls must use HTTPS base URL

---

## Quick Reference

### Check Pod Logs
```powershell
kubectl logs -l app=catalog-service -n swappo --tail=50
```

### Restart a Service
```powershell
kubectl rollout restart deployment/catalog-service -n swappo
```

### Get Ingress IP
```powershell
# Local
kubectl get ingress -n swappo

# GKE
kubectl get ingress -n swappo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

### Test Endpoints
```powershell
# Local
curl http://localhost/catalog/health
curl http://localhost/auth/api/v1/health

# Production
curl https://34.185.186.13.nip.io/catalog/health
curl https://34.185.186.13.nip.io/auth/api/v1/health
```
