# Deploy Swappo to Google Cloud Kubernetes (Cheapest Option)

## Cost Optimization Strategy
- **GKE Autopilot**: Only pay for pod resources (no node fees)
- **Region**: europe-west3 (Frankfurt - closest to Slovenia)
- **Resource limits**: Minimal CPU/memory per pod
- **Estimated cost**: ~$25-35/month for 5 microservices + databases

## Prerequisites
1. Google Cloud account with billing enabled
2. gcloud CLI installed: https://cloud.google.com/sdk/docs/install
3. kubectl installed
4. GitHub Container Registry images built via CI/CD

## Step 1: Install gcloud CLI (if not installed)


### Windows:
```powershell
# Download and run installer from:
# https://cloud.google.com/sdk/docs/install#windows

# After installation, initialize:
gcloud init
```

## Step 2: Create GKE Autopilot Cluster

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com

# Create Autopilot cluster (Best for Slovenia)
gcloud container clusters create-auto swappo-cluster \
    --region=europe-west3 \
    --release-channel=stable

# This takes ~5-10 minutes
```

### Alternative: Standard Cluster (slightly more control)
```bash
# If you need more control, use standard cluster with minimal resources
gcloud container clusters create swappo-cluster \
    --zone=us-central1-a \
    --num-nodes=2 \
    --machine-type=e2-micro \
    --disk-size=10GB \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=3
```

## Step 3: Configure kubectl

```bash
# Get credentials for your cluster
gcloud container clusters get-credentials swappo-cluster --region=europe-west3

# Verify connection
kubectl get nodes
```

## Step 4: Create GitHub Container Registry Secret

```bash
# Create a Personal Access Token (PAT) from GitHub:
# 1. Go to https://github.com/settings/tokens
# 2. Generate new token (classic)
# 3. Select scopes: read:packages
# 4. Copy the token

# Create Kubernetes secret for pulling images
kubectl create secret docker-registry ghcr-secret 
    --docker-server=ghcr.io 
    --docker-username=filipturk 
    --docker-password=<GITHUB_PAT_TOKEN>
    --docker-email=filip.t.turk@gmail.com 
    --namespace=swappo
```

## Step 5: Update Kubernetes Manifests for GKE

The manifests need minor adjustments:
- Remove NodePort (use ClusterIP)
- Use GKE Ingress instead of local ingress
- Add resource limits for cost control

See updated manifests in `k8s-gke/` directory.

## Step 6: Deploy to GKE

```bash
# Apply all manifests
kubectl apply -f k8s-gke/namespace.yaml
kubectl apply -f k8s-gke/secrets.yaml
kubectl apply -f k8s-gke/configmap.yaml

# Deploy databases
kubectl apply -f k8s-gke/auth-db.yaml
kubectl apply -f k8s-gke/catalog-db.yaml
kubectl apply -f k8s-gke/chat-db.yaml
kubectl apply -f k8s-gke/matchmaking-db.yaml
kubectl apply -f k8s-gke/notifications-db.yaml

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=auth-db -n swappo --timeout=180s

# Deploy services
kubectl apply -f k8s-gke/auth-service.yaml
kubectl apply -f k8s-gke/catalog-service.yaml
kubectl apply -f k8s-gke/chat-service.yaml
kubectl apply -f k8s-gke/matchmaking-service.yaml
kubectl apply -f k8s-gke/notifications-service.yaml

# Deploy ingress (for external access)
kubectl apply -f k8s-gke/ingress.yaml
```

## Step 7: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n swappo

# Check services
kubectl get svc -n swappo

# Check ingress for external IP (takes 5-10 minutes)
kubectl get ingress -n swappo
```

## Step 8: Access Your Application

```bash
# Get the external IP address
kubectl get ingress swappo-ingress -n swappo

# Your services will be available at:
# http://<EXTERNAL-IP>/api/v1/auth/*
# http://<EXTERNAL-IP>/api/v1/catalog/*
# http://<EXTERNAL-IP>/api/v1/chat/*
# http://<EXTERNAL-IP>/api/v1/matchmaking/*
# http://<EXTERNAL-IP>/api/v1/notifications/*
```

## Cost Monitoring

```bash
# View current resource usage
kubectl top pods -n swappo
kubectl top nodes

# Check GKE dashboard for cost estimates:
# https://console.cloud.google.com/kubernetes
```

## Cleanup (when done testing)

```bash
# Delete the cluster to stop charges
gcloud container clusters delete swappo-cluster --region=europe-west3
```

## Next Steps: Continuous Deployment

To auto-deploy on every successful build, add this to your GitHub Actions workflows:

```yaml
# Add to .github/workflows/ci.yml after the build job
deploy:
  needs: build
  runs-on: ubuntu-latest
  if: github.ref == 'refs/heads/main'
  steps:
    - uses: google-github-actions/auth@v1
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - uses: google-github-actions/get-gke-credentials@v1
      with:
        cluster_name: swappo-cluster
        location: europe-west3
    
    - name: Deploy to GKE
      run: |
        kubectl rollout restart deployment/auth-service -n swappo
```

## Troubleshooting

### Pods not starting:
```bash
kubectl describe pod <pod-name> -n swappo
kubectl logs <pod-name> -n swappo
```

### Image pull errors:
```bash
# Verify secret exists
kubectl get secrets -n swappo

# Recreate secret if needed
kubectl delete secret ghcr-secret -n swappo
# Then create again with correct credentials
```

### Out of memory:
```bash
# GKE Autopilot will auto-scale, but you can adjust resource requests
# Edit deployment manifests to reduce resources
```
---

## Frontend Deployment (Firebase Hosting)

Your React Native/Expo frontend can be deployed as a web app to Firebase Hosting.

See detailed instructions: **[Swappo-FE/FIREBASE_DEPLOYMENT.md](Swappo-FE/FIREBASE_DEPLOYMENT.md)**

### Quick Start:

```powershell
# Install Firebase CLI
npm install -g firebase-tools

# Navigate to frontend
cd Swappo-FE

# Login and initialize
firebase login
firebase init hosting

# Build and deploy
npx expo export --platform web
firebase deploy --only hosting
```
Project Console: https://console.firebase.google.com/project/swappo-a34df/overview
Your app will be live at: `https://swappo-a34df.web.app`

**Important**: Update backend CORS settings to allow requests from your Firebase domain.