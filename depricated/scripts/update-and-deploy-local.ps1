# Update K8s Manifests and Deploy to Local Kubernetes
# This script pulls the latest CI-built images and deploys to your local K8s cluster
#
# Usage: .\update-and-deploy-local.ps1

param(
    [string]$GithubUsername = "filipTurk",  # UPDATE THIS!
    [switch]$PullImages = $true,
    [switch]$Deploy = $true,
    [switch]$ShowLogs = $false
)

Write-Host "Swappo Local K8s Deployment" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "k8s")) {
    Write-Host "[ERROR] k8s directory not found" -ForegroundColor Red
    Write-Host "   Please run this script from the Swappo root directory" -ForegroundColor Yellow
    exit 1
}

# Check if GitHub username is set
if ($GithubUsername -eq "YOUR_GITHUB_USERNAME") {
    Write-Host "[WARNING] GitHub username not set!" -ForegroundColor Yellow
    $GithubUsername = Read-Host "Enter your GitHub username"
}

$services = @("auth", "catalog", "chat", "matchmaking", "notifications")
$registry = "ghcr.io"
$updatedServices = @()

# Pull latest images and track which ones are new
if ($PullImages) {
    Write-Host "Checking for updated images from $registry..." -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($service in $services) {
        $imageName = "$registry/$GithubUsername/swappo-${service}:latest"
        Write-Host "Checking $imageName..." -ForegroundColor White
        
        try {
            # Get current image ID if exists
            $currentImageId = docker images -q $imageName 2>$null
            
            # Pull latest
            docker pull $imageName 2>&1 | Out-Null
            
            # Get new image ID
            $newImageId = docker images -q $imageName
            
            if ($currentImageId -ne $newImageId) {
                Write-Host "  [UPDATED] New image available" -ForegroundColor Yellow
                $updatedServices += $service
            } else {
                Write-Host "  [UNCHANGED] Already up to date" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  [ERROR] Failed to pull $imageName" -ForegroundColor Red
            Write-Host "     Make sure you're logged in: docker login ghcr.io" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    if ($updatedServices.Count -gt 0) {
        Write-Host "[INFO] Services with updates: $($updatedServices -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] No service updates found - all images are current" -ForegroundColor Green
    }
    Write-Host ""
}

# Deploy to Kubernetes
if ($Deploy) {
    Write-Host "Deploying to Kubernetes..." -ForegroundColor Cyan
    Write-Host ""
    
    # First-time setup: Apply base infrastructure
    $infraFiles = @("namespace.yaml", "configmap.yaml", "secrets.yaml")
    foreach ($file in $infraFiles) {
        $filePath = "k8s\$file"
        if (Test-Path $filePath) {
            kubectl apply -f $filePath 2>&1 | Out-Null
        }
    }
    
    # Deploy databases (only if needed)
    $dbFiles = @("auth-db.yaml", "catalog-db.yaml", "chat-db.yaml", "matchmaking-db.yaml", "notifications-db.yaml")
    foreach ($file in $dbFiles) {
        $filePath = "k8s\$file"
        if (Test-Path $filePath) {
            kubectl apply -f $filePath 2>&1 | Out-Null
        }
    }
    
    # Only update services that have new images
    if ($updatedServices.Count -gt 0) {
        Write-Host "Updating deployments for changed services..." -ForegroundColor Cyan
        
        foreach ($service in $updatedServices) {
            $serviceFile = "$service-service.yaml"
            $filePath = "k8s\$serviceFile"
            
            if (Test-Path $filePath) {
                Write-Host "  Updating $service-service..." -ForegroundColor White
                kubectl apply -f $filePath
                
                # Force rollout restart to use new image
                kubectl rollout restart deployment/$service-service -n swappo 2>&1 | Out-Null
            }
        }
        
        Write-Host ""
        Write-Host "[OK] Updated services deployed" -ForegroundColor Green
        Write-Host ""
        
        # Wait only for updated deployments
        Write-Host "Waiting for updated deployments to be ready..." -ForegroundColor Cyan
        
        foreach ($service in $updatedServices) {
            Write-Host "  Checking $service-service..." -ForegroundColor Gray
            kubectl rollout status deployment/$service-service -n swappo --timeout=2m
        }
        
        Write-Host ""
        Write-Host "[SUCCESS] All updated deployments ready!" -ForegroundColor Green
    } else {
        Write-Host "[INFO] No services to update - skipping deployment" -ForegroundColor Green
        
        # Still apply ingress in case it changed
        if (Test-Path "k8s\ingress.yaml") {
            kubectl apply -f k8s\ingress.yaml 2>&1 | Out-Null
        }
    }
}

# Show status
Write-Host ""
Write-Host "Current Status:" -ForegroundColor Cyan
Write-Host ""

Write-Host "Pods:" -ForegroundColor Yellow
kubectl get pods -n swappo

Write-Host ""
Write-Host "Services:" -ForegroundColor Yellow
kubectl get svc -n swappo

if ($ShowLogs) {
    Write-Host ""
    Write-Host "Recent Logs:" -ForegroundColor Cyan
    
    foreach ($service in @("auth-service", "catalog-service")) {
        Write-Host ""
        Write-Host "--- $service ---" -ForegroundColor Yellow
        kubectl logs -n swappo deployment/$service --tail=10
    }
}

Write-Host ""
Write-Host "[SUCCESS] Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Quick commands:" -ForegroundColor Cyan
Write-Host "   View logs:    kubectl logs -f deployment/auth-service -n swappo" -ForegroundColor White
Write-Host "   Get pods:     kubectl get pods -n swappo" -ForegroundColor White
Write-Host "   Port forward: kubectl port-forward -n swappo svc/auth-service 8001:8000" -ForegroundColor White
Write-Host ""
