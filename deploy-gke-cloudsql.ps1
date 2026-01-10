# Deploy All Services with Cloud SQL
# Run this script to deploy all microservices to GKE with Cloud SQL

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Deploying Swappo Microservices with Cloud SQL" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan

# Check if namespace exists
Write-Host "`n[1/8] Checking namespace..." -ForegroundColor Yellow
kubectl get namespace swappo 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating namespace..." -ForegroundColor Yellow
    kubectl apply -f k8s-gke/namespace.yaml
}
Write-Host "✓ Namespace ready" -ForegroundColor Green

# Apply ConfigMap
Write-Host "`n[2/8] Applying ConfigMap..." -ForegroundColor Yellow
kubectl apply -f k8s-gke/configmap.yaml
Write-Host "✓ ConfigMap applied" -ForegroundColor Green

# Apply Secrets
Write-Host "`n[3/8] Applying Secrets..." -ForegroundColor Yellow
kubectl apply -f k8s-gke/secrets-cloudsql.yaml
Write-Host "✓ Secrets applied" -ForegroundColor Green

# Deploy Auth Service
Write-Host "`n[4/8] Deploying Auth Service..." -ForegroundColor Yellow
kubectl apply -f k8s-gke/auth-service.yaml
Write-Host "✓ Auth Service deployed" -ForegroundColor Green

# Deploy Catalog Service
Write-Host "`n[5/8] Deploying Catalog Service..." -ForegroundColor Yellow
kubectl apply -f k8s-gke/catalog-service.yaml
Write-Host "✓ Catalog Service deployed" -ForegroundColor Green

# Deploy Chat Service
Write-Host "`n[6/8] Deploying Chat Service..." -ForegroundColor Yellow
kubectl apply -f k8s-gke/chat-service.yaml
Write-Host "✓ Chat Service deployed" -ForegroundColor Green

# Deploy Matchmaking Service
Write-Host "`n[7/8] Deploying Matchmaking Service..." -ForegroundColor Yellow
kubectl apply -f k8s-gke/matchmaking-service.yaml
Write-Host "✓ Matchmaking Service deployed" -ForegroundColor Green

# Deploy Notifications Service
Write-Host "`n[8/8] Deploying Notifications Service..." -ForegroundColor Yellow
kubectl apply -f k8s-gke/notifications-service.yaml
Write-Host "✓ Notifications Service deployed" -ForegroundColor Green

# Apply Ingress
Write-Host "`n[FINAL] Applying Ingress..." -ForegroundColor Yellow
kubectl apply -f k8s-gke/ingress.yaml
Write-Host "✓ Ingress applied" -ForegroundColor Green

# Wait for pods to be ready
Write-Host "`n" + "=" * 80 -ForegroundColor Cyan
Write-Host "Waiting for pods to be ready..." -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Cyan

Start-Sleep -Seconds 5

kubectl get pods -n swappo

Write-Host "`n" + "=" * 80 -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan

Write-Host "`nServices deployed:" -ForegroundColor Green
Write-Host "  ✓ Auth Service (with Cloud SQL)" -ForegroundColor White
Write-Host "  ✓ Catalog Service (with Cloud SQL + GCS)" -ForegroundColor White
Write-Host "  ✓ Chat Service (with Cloud SQL)" -ForegroundColor White
Write-Host "  ✓ Matchmaking Service (with Cloud SQL)" -ForegroundColor White
Write-Host "  ✓ Notifications Service (with Cloud SQL)" -ForegroundColor White

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Monitor pod status: kubectl get pods -n swappo -w" -ForegroundColor White
Write-Host "  2. Check logs: kubectl logs -n swappo -l app=catalog-service -c catalog-service" -ForegroundColor White
Write-Host "  3. Check Cloud SQL Proxy: kubectl logs -n swappo -l app=catalog-service -c cloud-sql-proxy" -ForegroundColor White
Write-Host "  4. Get services: kubectl get svc -n swappo" -ForegroundColor White
Write-Host "  5. Get ingress: kubectl get ingress -n swappo" -ForegroundColor White

Write-Host "`n" + "=" * 80 -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
