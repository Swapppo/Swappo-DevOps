# Swappo Development vs Production Setup - Quick Reference

## 🎯 The Solution

Your Swappo app now has **two separate deployment configurations** that mirror each other in structure but use different endpoints.

---

## 📁 File Structure

```
Swappo/
├── k8s/                      # ← Local Kubernetes (Development)
│   ├── ingress.yaml         # host: localhost
│   ├── catalog-service.yaml # + security context
│   └── ...
│
├── k8s-gke/                  # ← GKE Kubernetes (Production)
│   ├── ingress.yaml         # host: 34.185.186.13.nip.io (HTTPS)
│   ├── catalog-service.yaml # + security context
│   ├── cluster-issuer.yaml  # cert-manager for TLS
│   └── ...
│
├── Swappo-FE/
│   ├── .env.development     # ← NEW! http://localhost
│   ├── .env.production      # ← EXISTING https://34.185.186.13.nip.io
│   └── config/api.config.ts # Uses ENV.API_BASE_URL from env files
│
├── deploy-local.ps1         # ← NEW! Deploy to local K8s
├── deploy-gke.ps1           # ← NEW! Deploy to GKE
└── deploy-web.ps1           # ← EXISTING Deploy frontend to Firebase
```

---

## 🔄 Workflow Overview

### Development Workflow (Local)

```powershell
# 1. Deploy backend to local Kubernetes
.\deploy-local.ps1
# → Deploys to http://localhost via nginx ingress
# → Uses k8s/ folder

# 2. Run frontend in development mode
cd Swappo-FE
npm start
# → Auto-loads .env.development
# → Points to http://localhost
# → Opens Metro bundler for React Native/Web
```

**Frontend sees**: `http://localhost/catalog/items/feed`

---

### Production Workflow (GKE + Firebase)

```powershell
# 1. Deploy backend to GKE
.\deploy-gke.ps1
# → Deploys to https://34.185.186.13.nip.io via nginx ingress
# → Uses k8s-gke/ folder
# → Restarts deployments to pull latest Docker images

# 2. Deploy frontend to Firebase
cd Swappo-FE
.\deploy-web.ps1
# → Uses .env.production
# → Points to https://34.185.186.13.nip.io
# → Deploys to https://swappo-a34df.web.app
```

**Frontend sees**: `https://34.185.186.13.nip.io/catalog/items/feed`

---

## 🔑 Key Points

### ✅ What's Now Consistent

Both dev and prod use **identical URL structure**:
- `/auth/api/v1/...`
- `/catalog/items/...`
- `/matchmaking/api/v1/...`
- `/chat/api/v1/...`
- `/notifications/api/v1/...`

The **only difference** is the base URL:
- Dev: `http://localhost`
- Prod: `https://34.185.186.13.nip.io`

### ✅ What Changed

1. **Added `.env.development`** for local development
2. **Updated k8s/catalog-service.yaml** with security context (fixes upload permissions)
3. **Created deployment scripts** (`deploy-local.ps1` and `deploy-gke.ps1`)
4. **Created DEPLOYMENT_GUIDE.md** with comprehensive instructions

### ✅ Frontend API Configuration

The frontend automatically picks the right environment:

```typescript
// config/env.config.ts loads the right .env file
export const ENV = {
  API_BASE_URL: process.env.EXPO_PUBLIC_API_BASE_URL,
  ENVIRONMENT: process.env.EXPO_PUBLIC_ENVIRONMENT,
}

// config/api.config.ts uses it
export const API_CONFIG = {
  BASE_URL: ENV.API_BASE_URL,  // Changes based on environment
  AUTH_BASE_URL: ENV.API_BASE_URL,
  CATALOG_BASE_URL: ENV.API_BASE_URL,
  // ...
}
```

---

## 🚀 Common Commands

### Check Backend Status

```powershell
# Local
kubectl get all -n swappo
kubectl get ingress -n swappo
curl http://localhost/catalog/health

# Production (GKE)
kubectl get all -n swappo
kubectl get ingress -n swappo
curl https://34.185.186.13.nip.io/catalog/health
```

### View Logs

```powershell
kubectl logs -l app=catalog-service -n swappo --tail=50
kubectl logs -l app=auth-service -n swappo --tail=50
```

### Restart a Service

```powershell
kubectl rollout restart deployment/catalog-service -n swappo
```

---

## ❓ FAQ

### How does the frontend know which environment to use?

**Development mode** (`npm start`): Expo auto-loads `.env.development`
**Production build** (`npx expo export`): Expo auto-loads `.env.production` (based on `NODE_ENV=production`)

### Do I need to change code when switching between dev and prod?

**No!** The environment files handle everything. Your code uses `ENV.API_BASE_URL` which automatically changes.

### What if I want to test the production build locally?

```powershell
# Build with production settings
cd Swappo-FE
npx expo export --platform web

# Serve locally
npx serve dist
# Opens on http://localhost:3000 but will call PRODUCTION API (https://34.185.186.13.nip.io)
```

### Can I test against production API from local frontend?

Yes! Temporarily edit `.env.development`:
```env
EXPO_PUBLIC_API_BASE_URL=https://34.185.186.13.nip.io
EXPO_PUBLIC_ENVIRONMENT=development
```
Then run `npm start` and you'll hit production backend.

### Do both environments need separate databases?

**Yes!** Each environment has its own PostgreSQL pods:
- Local: `auth-db`, `catalog-db`, etc. running in local cluster
- Production: `auth-db`, `catalog-db`, etc. running in GKE

They are completely isolated.

---

## 🎉 Summary

You now have a **clean separation** between development and production:

| Aspect | Development | Production |
|--------|-------------|------------|
| **Backend** | Local K8s (localhost) | GKE (34.185.186.13.nip.io) |
| **Frontend** | Metro dev server | Firebase Hosting |
| **Protocol** | HTTP | HTTPS |
| **Deploy Script** | `.\deploy-local.ps1` | `.\deploy-gke.ps1` + `.\deploy-web.ps1` |
| **Config Folder** | `k8s/` | `k8s-gke/` |
| **Env File** | `.env.development` | `.env.production` |
| **Databases** | Local PostgreSQL pods | GKE PostgreSQL pods |
| **URL Structure** | **Identical** ✅ | **Identical** ✅ |

**Both environments use the same URL patterns**, just with different base URLs. This makes your code portable and predictable!
