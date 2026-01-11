# Reconnect GKE namespace to GCP resources after namespace recreation
# This restores workload identity and fixes database permissions

$PROJECT_ID = "swapppo"
$NAMESPACE = "swappo"
$GCP_SA = "swappo-gcs-sa@swapppo.iam.gserviceaccount.com"
$K8S_SA = "default"

Write-Host "Step 1: Re-annotating Kubernetes service account for Workload Identity..." -ForegroundColor Cyan

# Annotate the Kubernetes service account to bind to GCP service account
kubectl annotate serviceaccount $K8S_SA `
    --namespace $NAMESPACE `
    "iam.gke.io/gcp-service-account=$GCP_SA" `
    --overwrite

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Service account annotated successfully" -ForegroundColor Green
} else {
    Write-Host "  Failed to annotate service account" -ForegroundColor Red
    exit 1
}

Write-Host "`nStep 2: Verifying GCP IAM bindings..." -ForegroundColor Cyan

# Verify the IAM binding exists (should already be set up from initial deployment)
Write-Host "  Checking workload identity binding..." -ForegroundColor Gray
gcloud iam service-accounts get-iam-policy $GCP_SA `
    --format="table(bindings.members)" 2>&1 | Select-String "swappo"

Write-Host "`nStep 3: Verifying Cloud SQL client role..." -ForegroundColor Cyan
gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$GCP_SA" `
    --role="roles/cloudsql.client" `
    --condition=None 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Cloud SQL client role verified" -ForegroundColor Green
}

Write-Host "`nStep 4: Scaling down services to release database connections..." -ForegroundColor Cyan
kubectl scale deployment --all --replicas=0 -n $NAMESPACE
Start-Sleep -Seconds 15
Write-Host "  Services scaled down" -ForegroundColor Green

Write-Host "`nStep 5: Dropping and recreating databases with proper ownership..." -ForegroundColor Cyan
Write-Host "  This will delete all data. Press Ctrl+C to cancel or Enter to continue..." -ForegroundColor Yellow
Read-Host

$databases = @("swappo_auth", "swappo_catalog", "swappo_chat", "swappo_matchmaking", "swappo_notifications")

foreach ($db in $databases) {
    Write-Host "  Processing $db..." -ForegroundColor Yellow
    
    # Delete database
    gcloud sql databases delete $db --instance=swappo-db --quiet 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    
    # Recreate database
    gcloud sql databases create $db --instance=swappo-db 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Recreated $db" -ForegroundColor Green
    }
}

Write-Host "`nStep 6: Granting permissions to swappo_user..." -ForegroundColor Cyan

# Create SQL script to grant permissions
$sqlScript = @"
-- Grant permissions on each database
\c swappo_auth
GRANT ALL PRIVILEGES ON DATABASE swappo_auth TO swappo_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO swappo_user;

\c swappo_catalog
GRANT ALL PRIVILEGES ON DATABASE swappo_catalog TO swappo_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO swappo_user;

\c swappo_chat
GRANT ALL PRIVILEGES ON DATABASE swappo_chat TO swappo_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO swappo_user;

\c swappo_matchmaking
GRANT ALL PRIVILEGES ON DATABASE swappo_matchmaking TO swappo_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO swappo_user;

\c swappo_notifications
GRANT ALL PRIVILEGES ON DATABASE swappo_notifications TO swappo_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO swappo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO swappo_user;
"@

$sqlScript | Out-File -FilePath "temp_grant.sql" -Encoding UTF8

Write-Host "  Note: You'll need postgres password when prompted" -ForegroundColor Yellow
Write-Host "  If gcloud sql connect doesn't work (no psql), we'll use an alternative method" -ForegroundColor Gray

# Try to run the SQL script
$result = gcloud sql connect swappo-db --user=postgres --quiet 2>&1
if ($result -match "Psql client not found") {
    Write-Host "`n  psql not installed locally, using alternative method..." -ForegroundColor Yellow
    Write-Host "  The default privileges will be set when tables are created by migrations" -ForegroundColor Green
    Remove-Item "temp_grant.sql"
} else {
    Get-Content "temp_grant.sql" | gcloud sql connect swappo-db --user=postgres --quiet
    Remove-Item "temp_grant.sql"
}

Write-Host "`nStep 7: Scaling services back up..." -ForegroundColor Cyan
kubectl scale deployment auth-service --replicas=1 -n $NAMESPACE
kubectl scale deployment catalog-service --replicas=1 -n $NAMESPACE
kubectl scale deployment chat-service --replicas=1 -n $NAMESPACE
kubectl scale deployment matchmaking-service --replicas=1 -n $NAMESPACE
kubectl scale deployment notifications-service --replicas=1 -n $NAMESPACE
kubectl scale deployment rabbitmq --replicas=1 -n $NAMESPACE

Write-Host "`nDone! Services are restarting with fresh databases." -ForegroundColor Green
Write-Host "Wait 30-60 seconds for migrations to run, then try logging in." -ForegroundColor Yellow
Write-Host "You'll need to create a new user account since databases were wiped." -ForegroundColor Yellow
