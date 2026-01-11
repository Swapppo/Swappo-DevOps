# Swappo Helm Quick Reference

## 🚀 Quick Commands

### Deploy
```powershell
# Using deployment script (recommended)
.\scripts\deploy-helm.ps1

# Manual deployment
helm install swappo ./swappo-helm -f ./swappo-helm/values.yaml -n swappo --create-namespace
```

### Update
```powershell
# Upgrade existing release
helm upgrade swappo ./swappo-helm -f ./swappo-helm/values.yaml -n swappo

# Update specific values
helm upgrade swappo ./swappo-helm --set services.catalog.replicas=3 -n swappo
```

### Check Status
```powershell
# Release status
helm status swappo -n swappo

# List releases
helm list -n swappo

# View history
helm history swappo -n swappo
```

### Rollback
```powershell
# Rollback to previous version
helm rollback swappo -n swappo

# Rollback to specific revision
helm rollback swappo 2 -n swappo
```

### Debug
```powershell
# Validate chart
helm lint ./swappo-helm

# Dry-run (preview)
helm install swappo ./swappo-helm --dry-run --debug

# Render templates
helm template swappo ./swappo-helm -f ./swappo-helm/values.yaml
```

### Remove
```powershell
helm uninstall swappo -n swappo
```

## 📝 Common Customizations

### Scale Services
Edit [`values.yaml`](./values.yaml):
```yaml
services:
  catalog:
    replicas: 3
```

### Update Image Version
```yaml
services:
  catalog:
    tag: v2.0.0
```

### Disable Service
```yaml
services:
  matchmaking:
    enabled: false
```

## 🎯 Ticket Requirements Met

✅ Helm Charts created for all microservices  
✅ Configurations parameterized in `values.yaml`  
✅ Deploy and update scripts provided  

## 📚 Documentation

- Full guide: [README.md](./README.md)
- Deployment script: [`scripts/deploy-helm.ps1`](../scripts/deploy-helm.ps1)
- Official Helm docs: https://helm.sh/docs/
