# Centralized Logging Setup Guide

This guide sets up centralized logging using **Loki + Promtail + Grafana** for all Swappo microservices.

## Architecture

- **Promtail**: Collects logs from all pods and sends to Loki
- **Loki**: Stores and indexes logs efficiently
- **Grafana**: Visualizes logs and creates alerts

## Why Loki?

- ✅ Lightweight (doesn't index full text like Elasticsearch)
- ✅ Integrates seamlessly with existing Grafana
- ✅ Perfect for Kubernetes
- ✅ Cost-effective storage
- ✅ Fast queries using labels

## Step 1: Add Grafana Helm Repository

```powershell
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

## Step 2: Install Loki Stack

This installs Loki + Promtail in one command:

```powershell
# Create values file for Loki stack
helm install loki grafana/loki-stack `
  --namespace swappo `
  --set loki.persistence.enabled=true `
  --set loki.persistence.size=10Gi `
  --set promtail.enabled=true `
  --set grafana.enabled=false `
  --set loki.config.table_manager.retention_deletes_enabled=true `
  --set loki.config.table_manager.retention_period=168h
```

**What this does:**
- Installs Loki (log storage)
- Installs Promtail (log collector on each node)
- Enables persistent storage for logs
- Sets log retention to 7 days (168h)
- Reuses your existing Grafana

## Step 3: Verify Installation

```powershell
# Check pods
kubectl get pods -n swappo -l app=loki
kubectl get pods -n swappo -l app=promtail

# Check services
kubectl get svc -n swappo -l app=loki
```

You should see:
- 1 Loki pod running
- Multiple Promtail pods (one per node)

## Step 4: Configure Grafana Data Source

Add Loki as a data source in Grafana:

```powershell
# Get Grafana password
kubectl get secret --namespace swappo grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Port-forward Grafana
kubectl port-forward -n swappo svc/grafana 3000:80
```

Open http://localhost:3000 and login with:
- Username: `admin`
- Password: (from command above)

### Add Loki Data Source:
1. Go to **Configuration** → **Data Sources**
2. Click **Add data source**
3. Select **Loki**
4. Set URL: `http://loki:3100`
5. Click **Save & Test**

## Step 5: Query Logs in Grafana

### Example LogQL Queries:

**View all logs from auth-service:**
```logql
{app="auth-service"}
```

**View error logs from all services:**
```logql
{namespace="swappo"} |= "ERROR"
```

**View 500 errors:**
```logql
{namespace="swappo"} |= "500"
```

**View logs from catalog-service in last 5 minutes:**
```logql
{app="catalog-service"}
```

**View database errors:**
```logql
{namespace="swappo"} |~ "database|postgres|sql"
```

## Step 6: Create Log Dashboards

### Quick Dashboard Setup:

1. In Grafana, go to **Dashboards** → **New Dashboard**
2. Add panel with query:
   ```logql
   sum by (app) (rate({namespace="swappo"}[5m]))
   ```
3. This shows log rate per service

### Recommended Panels:

1. **Log Volume by Service** (rate of logs)
2. **Error Rate** (count of ERROR/WARN logs)
3. **Recent Errors** (table of latest errors)
4. **HTTP Status Codes** (500, 404, etc.)
5. **Slow Requests** (requests > 1s)

## Step 7: Set Up Alerts

### Alert 1: High Error Rate

Create alert for services with high error rates:

1. Go to **Alerting** → **Alert rules** → **New alert rule**
2. Set query:
   ```logql
   sum(rate({namespace="swappo"} |~ "ERROR|error|Error"[5m])) > 0.1
   ```
3. Set conditions:
   - Threshold: 0.1 (more than 6 errors per minute)
   - Duration: 5m
4. Add notification channel (email, Slack, etc.)

### Alert 2: Service Unavailable (500 Errors)

```logql
sum(rate({namespace="swappo"} |= "500"[5m])) > 0.05
```

### Alert 3: Database Connection Failures

```logql
sum(rate({namespace="swappo"} |~ "connection.*failed|database.*error"[5m])) > 0
```

### Alert 4: Authentication Failures

```logql
sum(rate({app="auth-service"} |~ "authentication.*failed|invalid.*credentials"[5m])) > 1
```

## Step 8: Configure Retention and Storage

By default, logs are kept for 7 days. To change:

```powershell
helm upgrade loki grafana/loki-stack `
  --namespace swappo `
  --reuse-values `
  --set loki.config.table_manager.retention_period=336h  # 14 days
```

## Step 9: View Logs from CLI (Optional)

Install LogCLI for command-line log queries:

```powershell
# Port-forward Loki
kubectl port-forward -n swappo svc/loki 3100:3100

# Query logs (install logcli first from https://github.com/grafana/loki/releases)
logcli query '{app="auth-service"}' --addr=http://localhost:3100
```

## Common LogQL Patterns

### Filter by service:
```logql
{app="catalog-service"}
```

### Filter by multiple services:
```logql
{app=~"auth-service|catalog-service"}
```

### Search for specific text:
```logql
{namespace="swappo"} |= "login"
```

### Search with regex:
```logql
{namespace="swappo"} |~ "error|failed|exception"
```

### Exclude debug logs:
```logql
{namespace="swappo"} != "DEBUG"
```

### Count errors per service:
```logql
sum by (app) (count_over_time({namespace="swappo"} |= "ERROR" [5m]))
```

### Parse JSON logs:
```logql
{app="catalog-service"} | json | line_format "{{.message}}"
```

## Best Practices

1. **Add structured logging to your apps**:
   ```python
   import logging
   import json
   
   logging.basicConfig(
       format='{"timestamp":"%(asctime)s","level":"%(levelname)s","service":"%(name)s","message":"%(message)s"}',
       level=logging.INFO
   )
   ```

2. **Use consistent labels**:
   - `app` for service name
   - `environment` for prod/dev
   - `namespace` for k8s namespace

3. **Monitor log volume**:
   - High log volume = high costs
   - Reduce DEBUG logs in production

4. **Set up log sampling** for high-traffic services

## Troubleshooting

### Promtail not collecting logs?
```powershell
kubectl logs -n swappo -l app=promtail --tail=50
```

### Loki not receiving logs?
```powershell
kubectl logs -n swappo -l app=loki --tail=50
```

### Check Promtail config:
```powershell
kubectl get configmap -n swappo promtail -o yaml
```

## Cost Estimation

- **Storage**: ~$0.10/GB/month (GKE persistent disk)
- **For 10GB logs/day with 7-day retention**: ~$7/month
- **Much cheaper than Elasticsearch** (which needs more resources)

## Next Steps

1. ✅ Install Loki + Promtail
2. ✅ Add Loki to Grafana
3. ✅ Create log dashboard
4. ✅ Set up alerts
5. 🔄 Update apps with structured JSON logging
6. 🔄 Create saved queries for common issues
7. 🔄 Document alert runbooks

## Useful Resources

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Cheat Sheet](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Alerts](https://grafana.com/docs/grafana/latest/alerting/)
