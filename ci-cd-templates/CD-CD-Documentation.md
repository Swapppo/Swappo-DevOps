# 🚀 Swappo CI/CD Setup - Step by Step

**Simple guide to get CI/CD working for your microservices**

---

## ⚡ Quick Understanding

- **CI/CD runs on GitHub** (not your PC)
- **Builds Docker images** automatically when you push code
- **Stores images** in GitHub Container Registry (ghcr.io)
- **You deploy manually** to your local Kubernetes (or enable auto-deploy for cloud later)

---

## 📋 Prerequisites

- ✅ Git repositories on GitHub for each service
- ✅ Docker installed locally
- ✅ Kubernetes running (Docker Desktop or cloud)
- ✅ GitHub account

---

## 🎯 Step-by-Step Setup

### STEP 1: Update Your GitHub Username

**In this workspace, replace `YOUR_GITHUB_USERNAME` with your actual GitHub username:**

```powershell
# Run this in PowerShell (replace with YOUR username):
$username = "your-github-username"

(Get-Content ci-cd-templates\docker-compose.integration.yml) -replace 'YOUR_GITHUB_USERNAME', $username | Set-Content ci-cd-templates\docker-compose.integration.yml
(Get-Content ci-cd-templates\versions.yml) -replace 'YOUR_GITHUB_USERNAME', $username | Set-Content ci-cd-templates\versions.yml
(Get-Content update-and-deploy-local.ps1) -replace 'YOUR_GITHUB_USERNAME', $username | Set-Content update-and-deploy-local.ps1
```

---

### STEP 2: Copy CI/CD Workflows to Each Service Repository

**For each Python service (Auth, Catalog, Chat, Matchmaking, Notifications):**

If your services are in **separate Git repositories**:

```bash
cd /path/to/your/Swappo-Auth-Repo
mkdir -p .github/workflows

# Copy the workflow file (it's already in your Swappo-Auth folder)
# Just commit it:
git add .github/workflows/ci.yml
git commit -m "Add CI/CD pipeline"
git push origin main
```

If your services are in **this monorepo** (all in Swappo folder):

- ✅ **Already done!** Each service has `.github/workflows/ci.yml`
- Just push each service folder to its separate Git repo

**For Frontend:**

```bash
cd /path/to/your/Swappo-FE-Repo
git add .github/workflows/ci.yml
git commit -m "Add CI/CD pipeline"
git push origin main
```

---

### STEP 3: Enable GitHub Container Registry

**Do this for EACH service repository:**

1. Go to GitHub: `https://github.com/YOUR_USERNAME/Swappo-Auth`
2. Click **Settings** → **Actions** → **General**
3. Scroll to "Workflow permissions"
4. Select: ✅ **"Read and write permissions"**
5. Check: ✅ **"Allow GitHub Actions to create and approve pull requests"**
6. Click **Save**

**Repeat for:** Swappo-Catalog, Swappo-Chat, Swappo-Matchmaking, Swappo-Notifications, Swappo-FE

---

### STEP 4: Test CI/CD Pipeline

**Push code to trigger the pipeline:**

```bash
# In any service repo
cd Swappo-Auth
git add .
git commit -m "Test CI/CD pipeline"
git push origin main
```

**Watch it run:**

1. Go to GitHub: `https://github.com/YOUR_USERNAME/Swappo-Auth`
2. Click **Actions** tab
3. See your workflow running!
4. Wait for ✅ green checkmark

**What happens:**
- ✅ Code is tested
- ✅ Docker image is built
- ✅ Image pushed to `ghcr.io/YOUR_USERNAME/swappo-auth:latest`

---

### STEP 5: Update Kubernetes Manifests (One-time Setup)

**Update your K8s manifests to pull from GitHub Container Registry:**

```powershell
# Run this script to update all K8s manifests at once:
cd k8s

# For each service file, change the image line
# FROM: image: swappo-auth:latest
# TO:   image: ghcr.io/YOUR_USERNAME/swappo-auth:latest
```

**Or update manually:**

Edit `k8s/auth-service.yaml`:
```yaml
# Find this line (around line 20):
image: swappo-auth:latest

# Change to:
image: ghcr.io/YOUR_USERNAME/swappo-auth:latest
imagePullPolicy: Always
```

**Repeat for:** catalog-service.yaml, chat-service.yaml, matchmaking-service.yaml, notifications-service.yaml

---

### STEP 6: Login to GitHub Container Registry (One-time)

**Create a Personal Access Token:**

1. Go to GitHub: Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Name: "Docker Pull Token"
4. Select scopes: ✅ `read:packages`
5. Click "Generate token"
6. **Copy the token** (you won't see it again!)

**Login to ghcr.io:**

```powershell
# Replace YOUR_TOKEN with the token you just copied
echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

---

### STEP 7: Deploy to Local Kubernetes

**Option A: Use the Helper Script (Recommended)**

```powershell
# Update username in the script first:
# Edit update-and-deploy-local.ps1
# Change: $GithubUsername = "YOUR_GITHUB_USERNAME"
# To:     $GithubUsername = "your-actual-username"

# Then run:
.\update-and-deploy-local.ps1
```

**Option B: Manual Deployment**

```powershell
# Pull latest images
docker pull ghcr.io/YOUR_USERNAME/swappo-auth:latest
docker pull ghcr.io/YOUR_USERNAME/swappo-catalog:latest
docker pull ghcr.io/YOUR_USERNAME/swappo-chat:latest
docker pull ghcr.io/YOUR_USERNAME/swappo-matchmaking:latest
docker pull ghcr.io/YOUR_USERNAME/swappo-notifications:latest

# Deploy to Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/auth-db.yaml
kubectl apply -f k8s/catalog-db.yaml
kubectl apply -f k8s/chat-db.yaml
kubectl apply -f k8s/matchmaking-db.yaml
kubectl apply -f k8s/notifications-db.yaml
kubectl apply -f k8s/auth-service.yaml
kubectl apply -f k8s/catalog-service.yaml
kubectl apply -f k8s/chat-service.yaml
kubectl apply -f k8s/matchmaking-service.yaml
kubectl apply -f k8s/notifications-service.yaml
kubectl apply -f k8s/ingress.yaml

# Check status
kubectl get pods -n swappo
```

---

### STEP 8: Verify Everything Works

```powershell
# Check pods are running
kubectl get pods -n swappo

# Should see something like:
# NAME                         READY   STATUS    RESTARTS   AGE
# auth-service-xxx             1/1     Running   0          2m
# catalog-service-xxx          1/1     Running   0          2m
# ...

# Check logs
kubectl logs -f deployment/auth-service -n swappo

# Port forward to test locally
kubectl port-forward -n swappo svc/auth-service 8001:8000

# Test in browser or curl
curl http://localhost:8001/health
```

---

## 🔄 Daily Workflow (After Setup)

### When You Make Changes:

```bash
# 1. Make code changes
cd Swappo-Auth
# ... edit files ...

# 2. Commit and push
git add .
git commit -m "Add new feature"
git push origin main

# 3. Wait for CI/CD to build (2-5 minutes)
# Watch on GitHub Actions tab

# 4. Deploy to local K8s
.\update-and-deploy-local.ps1

# Done! ✅
```

---

## ☁️ Moving to Cloud (Future)

### When You're Ready for Cloud Kubernetes:

**Choose a provider:**
- Azure (AKS)
- AWS (EKS)  
- Google Cloud (GKE)
- DigitalOcean Kubernetes

**Setup steps:**

1. **Create Kubernetes cluster on cloud**

2. **Add cloud credentials to GitHub Secrets:**
   - Repo → Settings → Secrets → Actions → New repository secret

   For Azure:
   ```
   Name: AZURE_CREDENTIALS
   Value: (output from: az ad sp create-for-rbac --sdk-auth)
   ```

3. **Uncomment cloud deployment section in workflows:**
   
   Edit `.github/workflows/ci.yml` in each service:
   ```yaml
   # Find this section (around line 110):
   # deploy-to-k8s:
   #   name: Deploy to Kubernetes
   
   # Remove the # to uncomment all lines in that job
   ```

4. **Push code:**
   ```bash
   git push origin main
   # Now CI/CD will automatically deploy to cloud!
   ```

**That's it!** Same pipeline, just enabled cloud deployment.

---

## 📊 File Structure Reference

### What Goes Where:

```
YOUR_SERVICE_REPO (e.g., Swappo-Auth)
├── .github/
│   └── workflows/
│       └── ci.yml          ← Copy from Swappo-Auth/.github/workflows/ci.yml
├── app/
│   └── (your code)
├── Dockerfile              ← Must exist
├── requirements.txt        ← Must exist
└── tests/                  ← Optional but recommended

SWAPPO_MONOREPO (this folder)
├── k8s/                    ← Update images to use ghcr.io
│   ├── auth-service.yaml
│   ├── catalog-service.yaml
│   └── ...
└── update-and-deploy-local.ps1  ← Use this to deploy
```

---

## 🔧 Environment Variables & Secrets

### GitHub Secrets (for CI/CD):

**Already configured automatically:**
- `GITHUB_TOKEN` - Auto-provided by GitHub for pushing images

**For cloud deployment (add later):**
- `AZURE_CREDENTIALS` - For Azure AKS
- `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` - For AWS EKS
- `GCP_CREDENTIALS` - For Google GKE

**Add secrets at:** `https://github.com/YOUR_USERNAME/Swappo-Auth/settings/secrets/actions`

### Kubernetes Secrets (for your app):

**Already in your k8s/secrets.yaml:**
- Database credentials
- JWT secret keys
- API keys

**Apply them:**
```bash
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmap.yaml
```

---

## 🧪 Testing CI/CD Locally (Before Cloud)

### Test Integration Tests:

```powershell
# Make sure images are built first (push to GitHub and let CI build)
# Then run integration tests:

cd ci-cd-templates
docker-compose -f docker-compose.integration.yml up --abort-on-container-exit

# Should see all services start and tests pass
```

---

## ❓ Troubleshooting

### "Permission denied" on GitHub Actions
→ Check Step 3: Enable write permissions in repo settings

### "Can't pull images"
→ Check Step 6: Login to ghcr.io with token

### "Pods are in ImagePullBackOff"
→ Check Step 5: K8s manifests have correct ghcr.io image URLs
→ Check Step 6: Docker is logged into ghcr.io

### "Workflow not running"
→ Make sure `.github/workflows/ci.yml` is in the repo
→ Push to `main` or `develop` branch

### "Tests failing in CI"
→ Check if all dependencies are in `requirements.txt`
→ Look at GitHub Actions logs for details

---

## ✅ Checklist

Before you're done, make sure:

- [ ] Replaced `YOUR_GITHUB_USERNAME` everywhere
- [ ] Copied workflows to all 6 service repos
- [ ] Enabled "Read and write permissions" in all repos
- [ ] Created GitHub personal access token
- [ ] Logged into ghcr.io with token
- [ ] Updated K8s manifests to use ghcr.io images
- [ ] Tested: Push code → CI builds → Deploy locally
- [ ] Can see pods running: `kubectl get pods -n swappo`

---

## 🎉 You're Done!

You now have:
- ✅ Automated testing on every commit
- ✅ Docker images built in the cloud
- ✅ Images stored in ghcr.io
- ✅ Easy deployment to Kubernetes
- ✅ Ready for cloud when you need it

**Every time you push code, CI/CD builds a new image. Then run `.\update-and-deploy-local.ps1` to deploy it!**

---

## 📚 More Info (If Needed)

- [CI-CD-KUBERNETES-SUMMARY.md](CI-CD-KUBERNETES-SUMMARY.md) - Quick overview
- [K8S-DEPLOYMENT-GUIDE.md](K8S-DEPLOYMENT-GUIDE.md) - Detailed deployment strategies
- [CI-CD-FAQ.md](CI-CD-FAQ.md) - Common questions

**But you don't need these to get started!** Just follow the steps above. 🚀
