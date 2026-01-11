# Helm-Based Monitoring Stack

## Overview
All monitoring components have been successfully migrated to the Helm chart deployment:
- **Prometheus** - Metrics collection and storage
- **Loki** - Log aggregation and querying
- **Promtail** - Log shipping (DaemonSet on all nodes)
- **Grafana** - Visualization and dashboards

## Deployed Components

### Prometheus
- **Status**: ✅ Running (1/1)
- **Service**: prometheus.swappo.svc.cluster.local:9090
- **Storage**: 10Gi persistent volume
- **Retention**: 30d
- **Config Location**: swappo-helm/templates/prometheus.yaml
- **Scrape Targets**:
  - All pods with `prometheus.io/scrape: "true"` annotation
  - Service endpoints for auth, catalog, chat, matchmaking, notifications

### Loki
- **Status**: ✅ Running (1/1)
- **Service**: loki.swappo.svc.cluster.local:3100
- **Storage**: 10Gi persistent volume
- **Retention**: 168h (7 days)
- **Config Location**: swappo-helm/templates/loki.yaml
- **Components**:
  - Ingester with WAL enabled
  - Compactor for retention management
  - BoltDB shipper for index storage

### Promtail
- **Status**: ✅ Running (2/2 DaemonSet pods)
- **Config Location**: swappo-helm/templates/promtail.yaml
- **Log Sources**: /var/log/pods/** (GKE Autopilot compatible)
- **Target**: Loki at http://loki:3100

### Grafana
- **Status**: ✅ Running (standalone Helm deployment)
- **External URL**: http://34.159.79.120
- **Credentials**: admin / admin123
- **Datasources**:
  - Prometheus (default) - http://prometheus:9090
  - Loki - http://loki:3100

## Helm Chart Configuration

### Values (swappo-helm/values.yaml)
```yaml
prometheus:
  enabled: true
  image: prom/prometheus
  tag: latest
  retention: 30d
  persistence:
    enabled: true
    size: 10Gi

loki:
  enabled: true
  image: grafana/loki
  tag: 2.9.3
  retention: 168h
  persistence:
    enabled: true
    size: 10Gi

promtail:
  enabled: true
  image: grafana/promtail
  tag: 2.9.3
```

## Deployment Commands

### Deploy/Upgrade Full Stack
```powershell
helm upgrade swappo ./swappo-helm -n swappo
```

### Configure Grafana Datasources
```powershell
.\scripts\configure-grafana-datasources.ps1
```

### Check Monitoring Pods
```powershell
kubectl get pods -n swappo | Select-String "prometheus|loki|promtail"
```

### View Logs
```powershell
# Prometheus logs
kubectl logs -n swappo -l app=prometheus --tail=50

# Loki logs
kubectl logs -n swappo loki-0 --tail=50

# Promtail logs
kubectl logs -n swappo -l app=promtail --tail=50
```

## GKE Autopilot Compatibility

### Security Contexts
All pods run as non-root users:
- **Prometheus**: User 65534 with fsGroup 65534
- **Loki**: User 10001 with fsGroup 10001
- **Promtail**: Default restricted permissions

### Volume Mounts
- **Promtail** uses only `/var/log` hostPath (GKE Autopilot allowed)
- **Prometheus & Loki** use persistent volumes (no hostPath issues)

### Resource Requests
GKE Autopilot automatically manages resource requests/limits

## Key Fixes Applied

### Prometheus
- Added `securityContext` with fsGroup for volume permissions
- Configured persistent volume claims
- Set up service discovery for Kubernetes pods

### Loki
- Added `securityContext` for non-root execution
- Configured WAL directory: `/wal` (emptyDir volume)
- Added compactor working directory: `/loki/compactor`
- Fixed permission denied errors on startup

### Promtail
- Custom DaemonSet using GKE-compatible paths
- Removed hostPath for `/var/lib/docker/containers` (not allowed)
- Uses `/var/log` only for pod log collection

## Access URLs

- **Grafana UI**: http://34.159.79.120 (admin/admin123)
- **Prometheus UI**: Port-forward required
  ```powershell
  kubectl port-forward -n swappo svc/prometheus 9090:9090
  # Access at http://localhost:9090
  ```
- **Loki**: Query via Grafana (no direct UI)

## Next Steps

1. **Create Dashboards**:
   - Import Kubernetes cluster monitoring dashboard
   - Create custom dashboards for microservices
   - Set up log exploration panels

2. **Configure Alerts**:
   - Pod restart alerts
   - High error rate alerts
   - Resource usage alerts
   - Certificate expiration alerts

3. **Set Up Alertmanager** (optional):
   - Email notifications
   - Slack integration
   - PagerDuty integration

4. **Optimize Retention**:
   - Adjust based on storage usage
   - Configure downsampling for older metrics
   - Set up remote storage for long-term retention

## Troubleshooting

### Prometheus Not Starting
- Check PVC is bound: `kubectl get pvc -n swappo`
- Verify securityContext: `kubectl describe pod -n swappo -l app=prometheus`

### Loki CrashLoopBackOff
- Ensure /wal volume is mounted: `kubectl describe pod -n swappo loki-0`
- Check compactor directory exists: `kubectl logs -n swappo loki-0`

### Promtail Not Collecting Logs
- Verify DaemonSet is running on all nodes: `kubectl get pods -n swappo -l app=promtail -o wide`
- Check logs for permission errors: `kubectl logs -n swappo -l app=promtail`

### Grafana Datasource Connection Failed
- Verify service DNS: `kubectl exec -it <any-pod> -n swappo -- nslookup prometheus`
- Test connectivity: `kubectl exec -it <any-pod> -n swappo -- curl http://prometheus:9090/-/healthy`

## Current Helm Revision
**Revision**: 8
**Last Deployed**: 2026-01-11 17:59:13
**Status**: deployed
