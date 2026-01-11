# Swappo Helm Deployment Script
# This script deploys the Swappo microservices platform to GKE using Helm

Write-Host "Swappo Helm Deployment Script" -ForegroundColor Cyan
Write-Host "============================`n" -ForegroundColor Cyan

# Configuration
$RELEASE_NAME = "swappo"
$NAMESPACE    = "swappo"
$CHART_PATH   = "./swappo-helm"
$VALUES_FILE  = "./swappo-helm/values.yaml"

# Check if Helm is installed
Write-Host "Checking for Helm installation..." -ForegroundColor Yellow
try {
    $helmVersion = helm version --short 2>$null
    Write-Host "Helm is installed: $helmVersion`n" -ForegroundColor Green
} catch {
    Write-Host "Helm is not installed. Please install Helm first." -ForegroundColor Red
    Write-Host "Visit: https://helm.sh/docs/intro/install/`n" -ForegroundColor Yellow
    exit 1
}

# Check kubectl connection
Write-Host "Checking Kubernetes connection..." -ForegroundColor Yellow
try {
    $context = kubectl config current-context 2>$null
    Write-Host "Connected to context: $context`n" -ForegroundColor Green
} catch {
    Write-Host "Cannot connect to Kubernetes cluster.`n" -ForegroundColor Red
    exit 1
}

# Validate Helm chart
Write-Host "Validating Helm chart..." -ForegroundColor Yellow
helm lint $CHART_PATH
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nHelm chart validation failed.`n" -ForegroundColor Red
    exit 1
}
Write-Host "Chart validation passed.`n" -ForegroundColor Green

# Dry-run (optional)
Write-Host "Dry-run deployment (preview)..." -ForegroundColor Yellow
$dryRun = Read-Host "Do you want to see the rendered templates? (y/N)"
if ($dryRun -eq 'y' -or $dryRun -eq 'Y') {
    helm install $RELEASE_NAME $CHART_PATH `
        --values $VALUES_FILE `
        --dry-run `
        --debug
    Write-Host ""
}

# Confirm deployment
Write-Host "Ready to deploy." -ForegroundColor Yellow
Write-Host "Release name: $RELEASE_NAME"
Write-Host "Namespace:    $NAMESPACE"
Write-Host "Chart path:   $CHART_PATH`n"

$confirm = Read-Host "Continue with deployment? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Deployment cancelled.`n" -ForegroundColor Yellow
    exit 0
}

# Check if release already exists
Write-Host "Checking for existing release..." -ForegroundColor Yellow
$existingRelease = helm list -n $NAMESPACE -o json |
    ConvertFrom-Json |
    Where-Object { $_.name -eq $RELEASE_NAME }

if ($existingRelease) {
    Write-Host "Release '$RELEASE_NAME' already exists." -ForegroundColor Yellow
    $upgrade = Read-Host "Do you want to upgrade it? (y/N)"

    if ($upgrade -eq 'y' -or $upgrade -eq 'Y') {
        Write-Host "Upgrading release..." -ForegroundColor Cyan
        helm upgrade $RELEASE_NAME $CHART_PATH `
            --values $VALUES_FILE `
            --namespace $NAMESPACE

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nUpgrade successful.`n" -ForegroundColor Green
        } else {
            Write-Host "`nUpgrade failed.`n" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Deployment cancelled.`n" -ForegroundColor Yellow
        exit 0
    }
} else {
    # Fresh install - skip namespace creation (already exists)
    Write-Host "Installing Helm release..." -ForegroundColor Cyan
    helm install $RELEASE_NAME $CHART_PATH `
        --values $VALUES_FILE `
        --namespace $NAMESPACE `
        --skip-crds

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nInstallation successful.`n" -ForegroundColor Green
    } else {
        Write-Host "`nInstallation failed.`n" -ForegroundColor Red
        exit 1
    }
}

# Show deployment status
Write-Host "Deployment status:" -ForegroundColor Yellow
helm status $RELEASE_NAME -n $NAMESPACE

# Summary
Write-Host "`nDeployment Summary" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host "Release:   $RELEASE_NAME"
Write-Host "Namespace: $NAMESPACE"

Write-Host "`nUseful commands:" -ForegroundColor Yellow
Write-Host "helm list -n $NAMESPACE"
Write-Host "kubectl get pods -n $NAMESPACE"
Write-Host "kubectl get svc -n $NAMESPACE"
Write-Host "kubectl logs -n $NAMESPACE -l app=catalog-service"
Write-Host "helm upgrade $RELEASE_NAME $CHART_PATH -f $VALUES_FILE -n $NAMESPACE"
Write-Host "helm rollback $RELEASE_NAME -n $NAMESPACE"
Write-Host "helm uninstall $RELEASE_NAME -n $NAMESPACE"

Write-Host "`nDeployment complete.`n" -ForegroundColor Green
