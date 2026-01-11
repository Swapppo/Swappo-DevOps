# Swappo Helm Chart

This Helm chart deploys the Swappo microservices platform to Google Kubernetes Engine (GKE).

## Overview

**Helm** is a package manager for Kubernetes that simplifies deployment and management of applications. Instead of managing multiple YAML files manually, Helm allows you to:

- ✅ Deploy entire application stack with one command
- ✅ Parameterize configurations using `values.yaml`
- ✅ Version and track releases
- ✅ Easy upgrades and rollbacks
- ✅ Reusable templates

## Prerequisites

1. **Helm 3.x** installed ([Install Guide](https://helm.sh/docs/intro/install/))
2. **kubectl** configured for your GKE cluster
3. **GitHub Container Registry** access configured (`ghcr-secret`)

## Quick Start

### 1. Install Helm (if not already installed)

```powershell
# Windows (using Chocolatey)
choco install kubernetes-helm

# Or download from: https://github.com/helm/helm/releases
```

### 2. Verify Helm Installation

```powershell
helm version
# Should show: version.BuildInfo{Version:"v3.x.x", ...}
```

### 3. Deploy with Helm

```powershell
# Navigate to project root
cd c:\Users\turkf\Pictures\mag2\RSO\Swappo

# Deploy using the script
.\scripts\deploy-helm.ps1

# OR manually:
helm install swappo ./swappo-helm -f ./swappo-helm/values.yaml -n swappo --create-namespace
```

## Chart Structure

```
swappo-helm/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default configuration values
├── templates/                 # Kubernetes resource templates
│   ├── namespace.yaml         # Namespace definition
│   ├── configmap.yaml         # ConfigMap for app settings
│   ├── secrets.yaml           # Secrets for Cloud SQL, GCS
│   ├── auth-service.yaml      # Auth microservice
│   ├── catalog-service.yaml   # Catalog microservice  
│   ├── chat-service.yaml      # Chat microservice
│   ├── matchmaking-service.yaml
│   ├── notifications-service.yaml
│   ├── rabbitmq.yaml          # Message queue
│   ├── kong-ingress.yaml      # API Gateway routing
│   ├── cluster-issuer.yaml    # TLS certificate issuer
│   └── _helpers.tpl           # Template helpers
└── .helmignore                # Files to exclude from chart
```

## Configuration

All configuration is centralized in [`values.yaml`](./values.yaml). Key sections:

### Global Settings
```yaml
global:
  namespace: swappo
  environment: production
  imageRegistry: ghcr.io/swapppo
```

### Service Configuration
```yaml
services:
  catalog:
    enabled: true
    replicas: 1
    image: swappo-catalog
    tag: latest
    port: 8000
```

### Cloud Configuration
```yaml
cloudSQL:
  instance: "swappo-435218:europe-west1:swappo-db"
  user: "swappo_user"
  
gcs:
  bucketName: "swappo-catalog-images"
```

## Common Operations

### Deploy Initial Release

```powershell
helm install swappo ./swappo-helm -f ./swappo-helm/values.yaml -n swappo --create-namespace
```

### Upgrade Existing Release

```powershell
# After modifying values.yaml or updating images
helm upgrade swappo ./swappo-helm -f ./swappo-helm/values.yaml -n swappo
```

### Check Release Status

```powershell
helm status swappo -n swappo
```

### List All Releases

```powershell
helm list -n swappo
```

### View Deployment History

```powershell
helm history swappo -n swappo
```

### Rollback to Previous Version

```powershell
# Rollback to previous revision
helm rollback swappo -n swappo

# Rollback to specific revision
helm rollback swappo 2 -n swappo
```

### Uninstall Release

```powershell
helm uninstall swappo -n swappo
```

### Dry-Run (Preview Without Deploying)

```powershell
helm install swappo ./swappo-helm -f ./swappo-helm/values.yaml --dry-run --debug
```

## Customizing Deployment

### Scaling Services

Edit `values.yaml`:
```yaml
services:
  catalog:
    replicas: 3  # Scale to 3 replicas
```

Then upgrade:
```powershell
helm upgrade swappo ./swappo-helm -f ./swappo-helm/values.yaml -n swappo
```

### Updating Image Tags

```yaml
services:
  catalog:
    tag: v2.0.0  # Update to new version
```

### Disabling Services

```yaml
services:
  matchmaking:
    enabled: false  # Temporarily disable
```

### Override Values from Command Line

```powershell
# Override specific values
helm upgrade swappo ./swappo-helm \
  --set services.catalog.replicas=3 \
  --set services.catalog.tag=v2.0.0 \
  -n swappo
```

## Monitoring Deployment

### Watch Pod Status

```powershell
kubectl get pods -n swappo -w
```

### View Logs

```powershell
# Specific service
kubectl logs -n swappo -l app=catalog-service -f

# All services
kubectl logs -n swappo -l app.kubernetes.io/instance=swappo -f
```

### View Events

```powershell
kubectl get events -n swappo --sort-by='.lastTimestamp'
```

## Helm vs Manual Deployment

### Before (Manual YAML)
```powershell
kubectl apply -f k8s-gke/namespace.yaml
kubectl apply -f k8s-gke/configmap.yaml
kubectl apply -f k8s-gke/secrets-cloudsql.yaml
kubectl apply -f k8s-gke/auth-service.yaml
kubectl apply -f k8s-gke/catalog-service.yaml
# ... 10 more files
```

### After (Helm)
```powershell
helm install swappo ./swappo-helm -f values.yaml -n swappo
```

## Migration from Manual Deployment

Your existing k8s-gke YAMLs are **NOT deleted**. The Helm chart is a templated version of them.

### Safe Migration Steps

1. **Keep existing deployment running**
2. **Test Helm in parallel namespace (optional)**:
   ```powershell
   helm install swappo-test ./swappo-helm -n swappo-test --create-namespace
   ```
3. **When confident, switch to Helm**:
   ```powershell
   # Delete manual resources
   kubectl delete -f k8s-gke/ -n swappo
   
   # Deploy with Helm
   helm install swappo ./swappo-helm -n swappo
   ```

## Troubleshooting

### Validate Chart Syntax

```powershell
helm lint ./swappo-helm
```

### Debug Template Rendering

```powershell
helm template swappo ./swappo-helm -f ./swappo-helm/values.yaml --debug
```

### Check Release Events

```powershell
kubectl get events -n swappo --field-selector involvedObject.name=catalog-service
```

### Helm Installation Issues

```powershell
# Verify Helm can connect to cluster
helm list -A

# Check Helm version
helm version
```

## Best Practices

✅ **Always use `--dry-run` before production deployment**
✅ **Version your Chart.yaml and values.yaml in Git**
✅ **Use `helm lint` to validate charts**
✅ **Test upgrades in non-production first**
✅ **Keep values.yaml parameterized, avoid hardcoding**
✅ **Use `helm history` to track changes**

## Additional Resources

- [Helm Official Docs](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Helm Chart Template Guide](https://helm.sh/docs/chart_template_guide/)

## Ticket Requirements ✅

This Helm chart satisfies the ticket requirements:

1. ✅ **Ustvarite Helm Charts za mikrostoritve** - Created complete Helm chart structure
2. ✅ **Parametrizirajte konfiguracije** - All configs parameterized in `values.yaml`
3. ✅ **Namestite in posodobite aplikacije s Helm Charts** - Deployment script and documentation provided

---

**Questions?** Check the deployment script at [`scripts/deploy-helm.ps1`](../scripts/deploy-helm.ps1)
