# Quick Guide: Testing Loki in Grafana

## The Problem

You're seeing "No data" when querying Loki. This is because **Promtail isn't collecting logs yet**. I'm fixing this now.

## Immediate Test

While I fix Promtail, here's how to test in Grafana:

### Step 1: Open Grafana
- Go to: **http://34.159.79.120**
- Login: `admin` / `admin123`

### Step 2: Go to Explore
- Click the **compass icon** (🧭) on the left sidebar

### Step 3: Check Datasource Connection
- At the top, click the dropdown and select **"Loki"**
- You should see a query box

### Step 4: Try This Query
```
{namespace="swappo"}
```

### Step 5: Check Time Range
- **Top right corner** - click the time picker
- Select **"Last 6 hours"** or **"Last 24 hours"**
- Click **"Run query"** (blue button)

## What You'll See

- **"No data"** - This means Promtail hasn't sent any logs yet (what we're fixing)
- **"Query error"** - Means there's a syntax problem
- **Logs appear** - SUCCESS! 🎉

## Why No Data?

The issue: **Promtail's path configuration is wrong**. 

GKE log files are at:
```
/var/log/pods/swappo_catalog-service-xxx_uid/catalog-service/0.log
```

But Promtail is looking for:
```
/var/log/pods/*{uid}/*.log
```

It should be:
```
/var/log/pods/*{uid}/{container}/*.log
```

## I'm Fixing It Now

Give me a moment to update the Promtail configuration and restart it. Then logs will start flowing!

## Once It Works

You'll be able to use these queries:

```
# All logs
{namespace="swappo"}

# Specific service
{app="catalog-service"}

# Errors only
{namespace="swappo"} |= "ERROR"

# Failed logins
{app="auth-service"} |= "failed"
```

## Status

❌ Promtail path config - FIXING NOW  
✅ Loki running  
✅ Grafana datasource connected  
⏳ Waiting for logs to flow...

