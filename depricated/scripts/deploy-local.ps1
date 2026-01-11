# Deploy Swappo to Local Kubernetes for Development
# This script deploys all microservices to your local Kubernetes cluster

Write-Host "Deploying Swappo to Local Kubernetes..." -ForegroundColor Cyan

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "kubectl is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# SAFETY CHECK: Verify we're NOT connected to GKE
$currentContext = kubectl config current-context 2>$null
if ($currentContext -like "*gke*") {
    Write-Host "" -ForegroundColor Red
    Write-Host "SAFETY CHECK FAILED!" -ForegroundColor Red
    Write-Host "You are currently connected to GKE: $currentContext" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "This script is for LOCAL deployment only." -ForegroundColor Yellow
    Write-Host "To deploy to GKE, use: .\deploy-gke.ps1" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "To switch to local cluster:" -ForegroundColor Cyan
    Write-Host "  kubectl config use-context docker-desktop" -ForegroundColor Gray
    Write-Host "  OR" -ForegroundColor Gray
    Write-Host "  kubectl config use-context minikube" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Yellow
    exit 1
}

Write-Host "Current context: $currentContext" -ForegroundColor Green

# Check if local cluster is running
try {
    kubectl cluster-info | Out-Null
    Write-Host "Kubernetes cluster is accessible" -ForegroundColor Green
} catch {
    Write-Host "Cannot connect to Kubernetes cluster. Is Docker Desktop/Minikube running?" -ForegroundColor Red
    exit 1
}

# Check if nginx ingress controller is installed
$ingressPods = kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers 2>$null
if (-not $ingressPods) {
    Write-Host "Nginx ingress controller not found. Installing..." -ForegroundColor Yellow
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    Write-Host "Waiting for ingress controller to be ready..." -ForegroundColor Yellow
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
    Write-Host "Ingress controller installed" -ForegroundColor Green
} else {
    Write-Host "Nginx ingress controller is running" -ForegroundColor Green
}

Write-Host "`nDeploying Kubernetes resources..." -ForegroundColor Cyan

# Apply configurations in order
Write-Host "  → Creating namespace..." -ForegroundColor Gray
kubectl apply -f k8s/namespace.yaml

Write-Host "  → Applying secrets..." -ForegroundColor Gray
kubectl apply -f k8s/secrets.yaml

Write-Host "  → Applying configmap..." -ForegroundColor Gray
kubectl apply -f k8s/configmap.yaml

Write-Host "  → Deploying databases..." -ForegroundColor Gray
kubectl apply -f k8s/auth-db.yaml
kubectl apply -f k8s/catalog-db.yaml
kubectl apply -f k8s/chat-db.yaml
kubectl apply -f k8s/matchmaking-db.yaml
kubectl apply -f k8s/notifications-db.yaml

Write-Host "  → Deploying services..." -ForegroundColor Gray
kubectl apply -f k8s/auth-service.yaml
kubectl apply -f k8s/catalog-service.yaml
kubectl apply -f k8s/chat-service.yaml
kubectl apply -f k8s/matchmaking-service.yaml
kubectl apply -f k8s/notifications-service.yaml

Write-Host "  → Configuring ingress..." -ForegroundColor Gray
kubectl apply -f k8s/ingress.yaml

Write-Host "`nWaiting for deployments to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=available --timeout=180s deployment --all -n swappo 2>$null

Write-Host "`nDeployment Status:" -ForegroundColor Cyan
kubectl get all -n swappo

Write-Host "`nIngress Configuration:" -ForegroundColor Cyan
kubectl get ingress -n swappo

Write-Host "`nLocal deployment complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Test endpoints: curl http://localhost/catalog/health" -ForegroundColor Gray
Write-Host "  2. Run frontend in dev mode: cd Swappo-FE; npm start" -ForegroundColor Gray
Write-Host "  3. Frontend will use .env.development (http://localhost)" -ForegroundColor Gray
Write-Host ""

Write-Host "Tip: Use \"kubectl logs -l app=catalog-service -n swappo\" to view logs" -ForegroundColor Cyan
