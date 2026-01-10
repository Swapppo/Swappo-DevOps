# Auto-Deployment Setup Guide for GKE

## Overview
Auto-deployment workflows are now added to all microservices. When you push to the `main` branch:
1. CI/CD builds the Docker image
2. Pushes to GitHub Container Registry
3. **NEW:** Automatically restarts the deployment in GKE
4. Waits for rollout to complete
5. Cleans up failed pods

## Setup Required

### Step 1: Get GCP Service Account Key

You need a GCP service account with permissions to access your GKE cluster.

```powershell
# Get your current GCP project
gcloud config get-value project

# Create a service account for GitHub Actions
gcloud iam service-accounts create github-actions-deployer \
  --display-name="GitHub Actions Deployer"

# Get the service account email
$SA_EMAIL = "github-actions-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com"

# Grant necessary permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/container.developer"

# Create and download key
gcloud iam service-accounts keys create github-sa-key.json \
  --iam-account=$SA_EMAIL

# View the key content (you'll add this to GitHub)
Get-Content github-sa-key.json
```

### Step 2: Get GKE Cluster Info

```powershell
# Get your cluster name and zone
gcloud container clusters list

# Example output:
# NAME              LOCATION       MASTER_VERSION
# swappo-cluster    us-central1-a  1.28.x
```

### Step 3: Add Secrets to GitHub

For **EACH microservice repository**, add these secrets:

1. Go to GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these secrets:

| Secret Name | Value | How to Get |
|------------|-------|------------|
| `GCP_SA_KEY` | Full JSON content from `github-sa-key.json` | Copy entire file content |
| `GCP_PROJECT_ID` | Your GCP project ID | `gcloud config get-value project` |

**Repeat for all 5 services:**
- Swappo-Auth
- Swappo-Catalog  
- Swappo-Chat
- Swappo-Matchmaking
- Swappo-Notifications

### Step 4: Update Cluster Info in Workflows

If your cluster name/zone is different, update each `deploy.yml`:

```yaml
env:
  GKE_CLUSTER: YOUR_CLUSTER_NAME  # Change this
  GKE_ZONE: YOUR_CLUSTER_ZONE      # Change this (e.g., us-central1-a)
```

## How It Works

### Workflow Trigger
Runs automatically when you push to `main` branch:

```powershell
git add .
git commit -m "Update catalog service"
git push origin main
```

### Deployment Process

```
1. Push to GitHub
   ↓
2. CI/CD builds image (ci.yml runs)
   ↓
3. Pushes to ghcr.io
   ↓
4. Deploy workflow triggers (deploy.yml runs)
   ↓
5. Connects to GKE cluster
   ↓
6. Runs: kubectl rollout restart deployment/catalog-service
   ↓
7. Waits for new pods to be ready
   ↓
8. Cleans up old/failed pods
   ↓
9. ✅ Deployment complete!
```

### What Gets Deployed

The workflow restarts the deployment, which:
- Pulls the **latest** image from ghcr.io
- Creates new pods with the new code
- Waits for them to be healthy
- Terminates old pods
- Cleans up any CrashLoopBackOff pods

## Testing

### Manual Trigger
You can manually trigger deployment:

1. Go to GitHub repo → **Actions**
2. Click **Deploy to GKE**
3. Click **Run workflow** → **Run workflow**

### Verify Deployment

```powershell
# Watch the deployment
kubectl get pods -n swappo -w

# Check deployment status
kubectl rollout status deployment/catalog-service -n swappo

# View logs
kubectl logs -n swappo -l app=catalog-service --tail=100
```

## Troubleshooting

### Authentication Failed
**Error:** `Error: google-github-actions/auth failed`

**Fix:**
- Verify `GCP_SA_KEY` secret is added correctly (entire JSON)
- Check service account has `roles/container.developer` permission

### Cluster Not Found
**Error:** `ERROR: (gcloud.container.clusters.get-credentials) NOT_FOUND`

**Fix:**
- Update `GKE_CLUSTER` and `GKE_ZONE` in workflow
- Verify cluster exists: `gcloud container clusters list`

### Deployment Timeout
**Error:** `error: timed out waiting for the condition`

**Fix:**
- Check pod logs: `kubectl logs -n swappo -l app=catalog-service`
- May indicate application startup issue, not deployment issue

### Permission Denied
**Error:** `User "service-account" cannot get resource "deployments"`

**Fix:**
- Add RBAC permissions:
```powershell
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.admin"
```

## Rollback

If deployment fails, rollback:

```powershell
# Rollback to previous version
kubectl rollout undo deployment/catalog-service -n swappo

# Rollback to specific revision
kubectl rollout history deployment/catalog-service -n swappo
kubectl rollout undo deployment/catalog-service -n swappo --to-revision=2
```

## Security Best Practices

1. **Limit Service Account Permissions:** Only grant necessary roles
2. **Use Workload Identity (Advanced):** Instead of service account keys
3. **Rotate Keys Regularly:** Regenerate keys every 90 days
4. **Restrict Branch:** Only deploy from `main` (already configured)

## Advanced: Environment-Specific Deployment

To deploy different branches to different environments:

```yaml
# In deploy.yml
on:
  push:
    branches: 
      - main      # Production
      - develop   # Staging

jobs:
  deploy:
    steps:
      - name: Set environment
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "NAMESPACE=swappo-prod" >> $GITHUB_ENV
          else
            echo "NAMESPACE=swappo-staging" >> $GITHUB_ENV
          fi
```

## What's Next

After setup:
1. ✅ Push code to `main` 
2. ✅ Wait 3-5 minutes
3. ✅ Check pods: `kubectl get pods -n swappo`
4. ✅ Your changes are live!

No more manual `kubectl rollout restart` commands needed!
