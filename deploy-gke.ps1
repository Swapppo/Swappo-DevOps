# Deploy Swappo to Google Kubernetes Engine (Production)
# This script deploys all microservices to GKE

Write-Host "🚀 Deploying Swappo to GKE (Production)..." -ForegroundColor Cyan

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kubectl is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check if connected to GKE cluster
try {
    $currentContext = kubectl config current-context
    Write-Host "✅ Connected to cluster: $currentContext" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot connect to Kubernetes cluster. Have you run 'gcloud container clusters get-credentials'?" -ForegroundColor Red
    exit 1
}

Write-Host "`n📦 Deploying Kubernetes resources to GKE..." -ForegroundColor Cyan

# Apply all GKE configurations
Write-Host "  → Applying all manifests..." -ForegroundColor Gray
kubectl apply -f k8s-gke/

Write-Host "`n🔄 Restarting deployments to pull latest images..." -ForegroundColor Cyan
kubectl rollout restart deployment/auth-service -n swappo
kubectl rollout restart deployment/catalog-service -n swappo
kubectl rollout restart deployment/chat-service -n swappo
kubectl rollout restart deployment/matchmaking-service -n swappo
kubectl rollout restart deployment/notifications-service -n swappo

Write-Host "`n⏳ Monitoring rollout status..." -ForegroundColor Cyan
kubectl rollout status deployment/auth-service -n swappo
kubectl rollout status deployment/catalog-service -n swappo
kubectl rollout status deployment/chat-service -n swappo
kubectl rollout status deployment/matchmaking-service -n swappo
kubectl rollout status deployment/notifications-service -n swappo

Write-Host "`n📊 Deployment Status:" -ForegroundColor Cyan
kubectl get all -n swappo

Write-Host "`n🌐 Ingress Configuration:" -ForegroundColor Cyan
kubectl get ingress -n swappo

$ingressIP = kubectl get ingress swappo-ingress -n swappo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
if ($ingressIP) {
    Write-Host "`n✅ Production deployment complete!" -ForegroundColor Green
    Write-Host "`n🔗 Access your application at:" -ForegroundColor Yellow
    Write-Host "  API: https://$ingressIP.nip.io" -ForegroundColor Cyan
    Write-Host "  Frontend: https://swappo-a34df.web.app" -ForegroundColor Cyan
    Write-Host "`n📝 Test endpoints:" -ForegroundColor Yellow
    Write-Host "  curl https://$ingressIP.nip.io/catalog/health" -ForegroundColor Gray
    Write-Host "  curl https://$ingressIP.nip.io/auth/api/v1/health" -ForegroundColor Gray
} else {
    Write-Host "`n⚠️  Deployment complete, but ingress IP not available yet. Check back in a few minutes." -ForegroundColor Yellow
}

Write-Host "`n💡 Tip: Monitor logs with 'kubectl logs -l app=catalog-service -n swappo --tail=50'" -ForegroundColor Cyan
