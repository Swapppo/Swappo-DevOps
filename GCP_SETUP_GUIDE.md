# Google Cloud Platform Setup Guide

This guide walks you through setting up Google Cloud Storage and Google Cloud SQL for your Swappo application.

## Prerequisites

- Google Cloud Project created
- `gcloud` CLI installed and authenticated
- GKE cluster already running (which you have)
- Billing enabled on your GCP project

## Step 1: Set Environment Variables

```bash
$PROJECT_ID="swapppo"
$REGION="europe-west3"  # Change to your preferred region
$CLUSTER_NAME="swappo-cluster"
$GCS_BUCKET_NAME="swappo-images"
$DB_INSTANCE_NAME="swappo-db"
```

## Step 2: Enable Required APIs

```bash
gcloud services enable storage.googleapis.com --project="swapppo"
gcloud services enable sqladmin.googleapis.com --project="swapppo"
gcloud services enable servicenetworking.googleapis.com --project="swapppo"
```

## Step 3: Create Google Cloud Storage Bucket

### Create the bucket
```bash
gcloud storage buckets create gs://swappo-images 
    --project="swapppo" 
    --location="europe-west3" 
    --uniform-bucket-level-access
```

### Set lifecycle policy (optional - auto-delete old images)
Create a file `lifecycle.json`:
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 365,
          "matchesPrefix": ["catalog/"]
        }
      }
    ]
  }
}
```

Apply it:
```bash
gcloud storage buckets update gs://swappo-images --lifecycle-file=lifecycle.json
```

### Make bucket publicly readable (for public image access)
```bash
gcloud storage buckets add-iam-policy-binding gs://swappo-images 
    --member=allUsers 
    --role=roles/storage.objectViewer
```

## Step 4: Create Google Cloud SQL Instance

### Create PostgreSQL instance
```bash
gcloud sql instances create "swappo-db" 
    --project="swapppo"
    --database-version=POSTGRES_15 
    --tier=db-f1-micro 
    --region="europe-west3" 
    --storage-type=SSD 
    --storage-size=10GB 
    --storage-auto-increase 
    --backup-start-time=03:00 
    --maintenance-window-day=SUN 
    --maintenance-window-hour=4 
```

**Note:** For production, consider:
- `db-n1-standard-1` or higher tier
- Increase storage size
- Enable high availability with `--availability-type=REGIONAL`

### Set root password
```bash
gcloud sql users set-password postgres 
    --instance="swappo-db" 
    --password="Admin"
```

### Create database and user for catalog service
```bash
# Create database
gcloud sql databases create swappo_catalog 
    --instance=$DB_INSTANCE_NAME

# Create user
gcloud sql users create swappo_user 
    --instance=$DB_INSTANCE_NAME 
    --password="Admin"
```

### Repeat for other services
```bash
# Auth service
gcloud sql databases create swappo_auth --instance=$DB_INSTANCE_NAME
gcloud sql users create auth_user --instance=$DB_INSTANCE_NAME --password="Admin"

# Chat service
gcloud sql databases create swappo_chat --instance=$DB_INSTANCE_NAME
gcloud sql users create chat_user --instance=$DB_INSTANCE_NAME --password="Admin"

# Matchmaking service
gcloud sql databases create swappo_matchmaking --instance=$DB_INSTANCE_NAME
gcloud sql users create matchmaking_user --instance=$DB_INSTANCE_NAME --password="Admin"

# Notifications service
gcloud sql databases create swappo_notifications --instance=$DB_INSTANCE_NAME
gcloud sql users create notifications_user --instance=$DB_INSTANCE_NAME --password="Admin"
```

## Step 5: Get Cloud SQL Connection Info

```bash
# Get instance connection name
gcloud sql instances describe $DB_INSTANCE_NAME 
    --format="value(connectionName)"
# Output : swapppo:europe-west3:swappo-db

# Get private IP address
gcloud sql instances describe "swappo-db" 
    --format="value(ipAddresses[0].ipAddress)"
```
#  34.185.220.40

## Step 6: Set Up Workload Identity for GCS Access

This allows your GKE pods to access GCS without storing credentials.

### Create Google Service Account
```bash
gcloud iam service-accounts create swappo-gcs-sa 
    --project=$PROJECT_ID 
    --display-name="Swappo GCS Service Account"
```

### Grant Storage permissions
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID 
    --member="serviceAccount:swappo-gcs-sa@$PROJECT_ID.iam.gserviceaccount.com" 
    --role="roles/storage.objectAdmin"
```

### Bind to Kubernetes Service Account
```bash
# Get your GKE cluster credentials first
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# Create Kubernetes service account (already exists in your namespace.yaml)
kubectl create namespace swappo --dry-run=client -o yaml | kubectl apply -f -

# Bind GCP SA to K8s SA
gcloud iam service-accounts add-iam-policy-binding 
    swappo-gcs-sa@$PROJECT_ID.iam.gserviceaccount.com 
    --role roles/iam.workloadIdentityUser 
    --member "serviceAccount:$PROJECT_ID.svc.id.goog[swappo/default]"

# Annotate the Kubernetes service account
kubectl annotate serviceaccount default 
    --namespace swappo 
    iam.gke.io/gcp-service-account=swappo-gcs-sa@$PROJECT_ID.iam.gserviceaccount.com 
    --overwrite
```

## Step 7: Set Up Cloud SQL Proxy (For GKE Access)

Add Cloud SQL Proxy sidecar to your deployments (see updated YAML files).

The connection string format:
```
postgresql://USER:PASSWORD@127.0.0.1:5432/DATABASE_NAME
```

## Step 8: Update Kubernetes Secrets

Update your secrets with new values:

```bash
kubectl create secret generic swappo-secrets `
    --namespace=swappo `
    --from-literal=postgres-password=Admin `
    --from-literal=jwt-secret=your-secret-key-change-in-production `
    --from-literal=gcs-bucket-name=swappo-images `
    --from-literal=gcp-project-id=swapppo `
    --from-literal=db-instance-connection-name=swapppo:europe-west3:swappo-db `
    --from-literal=catalog-db-password=Admin `
    --from-literal=auth-db-password=Admin `
    --from-literal=chat-db-password=Admin `
    --from-literal=matchmaking-db-password=Admin `
    --from-literal=notifications-db-password=Admin `
    --dry-run=client -o yaml | kubectl apply -f -
```

## Step 9: Cost Estimation

### Google Cloud Storage
- Storage: ~$0.020/GB/month (Standard)
- Operations: $0.05 per 10,000 writes, $0.004 per 10,000 reads
- **Estimate for 10,000 users with 5 photos each**: ~$1-3/month

### Cloud SQL (db-f1-micro)
- Instance: ~$10-15/month
- Storage: $0.17/GB/month
- **Estimate**: ~$12-20/month for starter

### Total Monthly Cost: ~$15-25/month for starter tier



## Troubleshooting

### Can't connect to Cloud SQL
1. Verify Cloud SQL Proxy is running in your pod
2. Check connection name is correct
3. Verify user/password are correct
4. Check firewall rules if using public IP

### GCS upload fails
1. Verify workload identity is configured
2. Check service account has storage.objectAdmin role
3. Verify bucket exists and is accessible

### Still seeing old pod database
1. Make sure you've updated the deployment YAMLs
2. Delete old deployments: `kubectl delete deployment catalog-db -n swappo`
3. Apply new manifests without the old DB pods

## Next Steps

1. Deploy updated catalog service with GCS integration
2. Test image uploads
3. Migrate existing data
4. Monitor costs in GCP Console
5. Set up alerts for unusual usage


**Verify Cloud Resources**:
   ```bash
   # Check Cloud SQL instance
   gcloud sql instances describe swappo-db
   
   # Check GCS bucket
   gcloud storage buckets describe gs://swappo-images
   ```

   

### Phase 3: Deploy Updated Services

1. **Update secrets**:
   ```bash
   # Edit secrets-cloudsql.yaml with your actual values
   kubectl apply -f k8s-gke/secrets-cloudsql.yaml
   ```

2. **Deploy catalog service with Cloud SQL**:
   ```bash
   kubectl apply -f k8s-gke/catalog-service-cloudsql.yaml
   ```

3. **Verify it's running**:
   ```bash
   kubectl get pods -n swappo -l app=catalog-service
   kubectl logs -n swappo -l app=catalog-service -c catalog-service
   kubectl logs -n swappo -l app=catalog-service -c cloud-sql-proxy
   ```

### Phase 4: Migrate Data to Cloud SQL

1. **Start Cloud SQL Proxy locally**:
   ```bash
   # Download Cloud SQL Proxy
   # Windows:
   curl -o cloud-sql-proxy.exe https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.x64.exe
   
   # Run proxy
   ./cloud-sql-proxy.exe swapppo:europe-west3:swappo-db
   ```

**Only after verifying everything works!**

```bash
# Delete old database deployments
kubectl delete deployment catalog-db -n swappo
kubectl delete deployment auth-db -n swappo
kubectl delete deployment chat-db -n swappo
kubectl delete deployment matchmaking-db -n swappo
kubectl delete deployment notifications-db -n swappo

# Delete old PVCs (this will delete the data!)
kubectl delete pvc catalog-postgres-pvc -n swappo
kubectl delete pvc auth-postgres-pvc -n swappo
kubectl delete pvc chat-postgres-pvc -n swappo
kubectl delete pvc matchmaking-postgres-pvc -n swappo
kubectl delete pvc notifications-postgres-pvc -n swappo

# Delete old services
kubectl delete service catalog-db -n swappo
kubectl delete service auth-db -n swappo
kubectl delete service chat-db -n swappo
kubectl delete service matchmaking-db -n swappo
kubectl delete service notifications-db -n swappo

```
# Grant Cloud SQL Client role to your service account
gcloud projects add-iam-policy-binding swapppo `
    --member="serviceAccount:swappo-gcs-sa@swapppo.iam.gserviceaccount.com" `
    --role="roles/cloudsql.client"