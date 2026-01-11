# ✅ Centralized Logging - Successfully Deployed!

## What's Deployed

- **Loki**: Log storage and aggregation (running in namespace `swappo`)
- **Promtail**: Log collector (2 pods, one per GKE node)
- **Grafana**: Log visualization and alerting (http://34.159.79.120)

## Access Grafana

**URL**: http://34.159.79.120
**Username**: `admin`
**Password**: `admin123`

Loki datasource is already configured and ready to use!

## Quick Start Guide

### 1. View Logs in Grafana

1. Open http://34.159.79.120
2. Login with credentials above
3. Go to **Explore** (compass icon on left sidebar)
4. Datasource should already be set to **Loki**

### 2. Try These Queries

**View all logs from auth-service:**
```logql
{app="auth-service"}
```

**View all errors:**
```logql
{namespace="swappo"} |~ "ERROR|error|Error"
```

**View 500 errors:**
```logql
{namespace="swappo"} |= "500"
```

**View database errors:**
```logql
{namespace="swappo"} |~ "database|postgres|permission"
```

**Count errors by service:**
```logql
sum by (app) (count_over_time({namespace="swappo"} |= "ERROR" [5m]))
```

### 3. Create Your First Dashboard

1. Go to **Dashboards** → **New Dashboard** → **Add visualization**
2. Select **Loki** datasource
3. Enter query (e.g., `{namespace="swappo"}`)
4. Choose visualization type (Logs, Graph, Table, etc.)
5. Click **Apply** and **Save dashboard**

Or import the pre-made dashboard:
1. Go to **Dashboards** → **Import**
2. Upload `k8s-gke/grafana-dashboard-logs.json`
3. Click **Import**

### 4. Set Up Your First Alert

1. Go to **Alerting** → **Alert rules** → **New alert rule**
2. Set up query:
   - Datasource: Loki
   - Query: `sum(rate({namespace="swappo"} |= "ERROR" [5m]))`
3. Set condition: `IS ABOVE 0.1` (more than 6 errors/minute)
4. Configure evaluation: `For 5m`
5. Add contact point (email, Slack, webhook)
6. Save rule

### 5. Useful LogQL Examples

**Filter by multiple services:**
```logql
{app=~"auth-service|catalog-service"}
```

**Exclude debug logs:**
```logql
{namespace="swappo"} != "DEBUG"
```

**Parse JSON logs:**
```logql
{app="catalog-service"} | json
```

**Rate of logs per service:**
```logql
sum by (app) (rate({namespace="swappo"}[5m]))
```

**Failed login attempts:**
```logql
{app="auth-service"} |= "login" |= "failed"
```

## Recommended Alerts

### 1. High Error Rate
- **Query**: `sum(rate({namespace="swappo"} |~ "ERROR|error" [5m])) > 0.1`
- **Condition**: More than 6 errors per minute
- **Duration**: 5 minutes

### 2. HTTP 500 Errors
- **Query**: `sum(rate({namespace="swappo"} |= "500" [5m])) > 0.05`
- **Condition**: More than 3 errors per minute
- **Duration**: 3 minutes

### 3. Database Connection Failures
- **Query**: `sum(rate({namespace="swappo"} |~ "connection.*failed|database.*error" [5m])) > 0`
- **Condition**: Any database errors
- **Duration**: 1 minute

### 4. Authentication Failures
- **Query**: `sum(rate({app="auth-service"} |~ "authentication.*failed|invalid.*credentials" [5m])) > 1`
- **Condition**: More than 5 failed logins per minute
- **Duration**: 2 minutes

## Architecture

```
┌─────────────────────────────────────────────┐
│           GKE Autopilot Cluster              │
│                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Auth    │  │ Catalog  │  │   Chat   │  │
│  │ Service  │  │ Service  │  │ Service  │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │             │              │         │
│       └─────────────┼──────────────┘         │
│                     │ Logs                   │
│              ┌──────▼──────┐                 │
│              │  Promtail   │                 │
│              │ (DaemonSet) │                 │
│              └──────┬──────┘                 │
│                     │                        │
│              ┌──────▼──────┐                 │
│              │    Loki     │                 │
│              │ (Storage)   │                 │
│              └──────┬──────┘                 │
│                     │                        │
│              ┌──────▼──────┐                 │
│              │   Grafana   │◄────External    │
│              │ (Visualize) │    Access       │
│              └─────────────┘                 │
└───────────────────────────────────────────────┘
```

## Log Retention

- **Current**: 7 days (168 hours)
- **Storage**: 10Gi persistent volume

To change retention:
```powershell
helm upgrade loki grafana/loki-stack `
  --namespace swappo `
  --reuse-values `
  --set loki.config.table_manager.retention_period=336h  # 14 days
```

## Monitoring Resources

Check Loki and Promtail status:
```powershell
kubectl get pods -n swappo -l app=loki
kubectl get pods -n swappo -l app=promtail
kubectl logs -n swappo -l app=loki --tail=50
kubectl logs -n swappo -l app=promtail --tail=50
```

## Next Steps

- [ ] Create custom dashboards for each service
- [ ] Set up alert notification channels (Slack, email)
- [ ] Add structured JSON logging to your applications
- [ ] Create alert runbooks
- [ ] Set up log-based metrics in Prometheus
- [ ] Configure log sampling for high-volume services

## Cost Estimation

- **Loki Storage (10Gi)**: ~$1-2/month
- **Grafana LoadBalancer**: ~$10/month
- **Total**: ~$12/month

Much cheaper than Elasticsearch/Kibana which would cost $50-100+/month!

## Troubleshooting

### No logs appearing?
1. Check Promtail is running: `kubectl get pods -n swappo -l app=promtail`
2. Check Promtail logs: `kubectl logs -n swappo -l app=promtail`
3. Verify Loki is accessible: `kubectl get svc -n swappo loki`

### Grafana not loading?
1. Check pod status: `kubectl get pods -n swappo -l app.kubernetes.io/name=grafana`
2. Get LoadBalancer IP: `kubectl get svc -n swappo grafana`
3. Check logs: `kubectl logs -n swappo -l app.kubernetes.io/name=grafana`

### Queries returning no data?
1. Make sure you're querying the right time range
2. Verify labels exist: `{namespace="swappo"}`
3. Check if Promtail is collecting logs from your pods

## Documentation

- Full setup guide: `guides/CENTRALIZED_LOGGING_SETUP.md`
- Loki config: `k8s-gke/loki-values.yaml`
- Promtail config: `k8s-gke/promtail.yaml`
- Dashboard template: `k8s-gke/grafana-dashboard-logs.json`

---

**✅ Your centralized logging system is ready!**

Open http://34.159.79.120 and start exploring your logs! 🎉
