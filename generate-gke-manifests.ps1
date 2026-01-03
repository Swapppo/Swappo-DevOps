# Generate GKE-Optimized Kubernetes Manifests
# This script creates cost-optimized versions of your K8s manifests for GKE

param(
    [string]$GithubOrg = "swapppo"  # Lowercase organization name for GHCR
)

Write-Host "Generating GKE-optimized Kubernetes manifests..." -ForegroundColor Cyan
Write-Host ""

# Ensure k8s-gke directory exists
$gkeDir = "k8s-gke"
if (-not (Test-Path $gkeDir)) {
    New-Item -ItemType Directory -Path $gkeDir | Out-Null
}

# Copy and update manifests
$services = @("auth", "catalog", "chat", "matchmaking", "notifications")

# Copy namespace, configmap, secrets (no changes needed)
Copy-Item "k8s\namespace.yaml" "$gkeDir\namespace.yaml" -Force
Copy-Item "k8s\configmap.yaml" "$gkeDir\configmap.yaml" -Force
Copy-Item "k8s\secrets.yaml" "$gkeDir\secrets.yaml" -Force

Write-Host "[OK] Copied base configuration files" -ForegroundColor Green

# Generate service deployments with minimal resources
foreach ($service in $services) {
    $serviceFile = "$service-service.yaml"
    $content = Get-Content "k8s\$serviceFile" -Raw
    
    # Replace image path with lowercase org name (GHCR converts to lowercase)
    $content = $content -replace 'ghcr\.io/[^/]+/', "ghcr.io/$GithubOrg/"
    
    # Update for GKE
    $content = $content -replace 'replicas: 2', 'replicas: 1'  # Reduce replicas
    $content = $content -replace 'type: NodePort', 'type: ClusterIP'  # Remove NodePort
    
    # Add imagePullSecrets after spec:
    $content = $content -replace '(spec:\s+containers:)', "spec:`n      imagePullSecrets:`n      - name: ghcr-secret`n      containers:"
    
    # Add resource limits after ports section
    $resourceLimits = @"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
"@
    $content = $content -replace '(\s+- containerPort: 8000)', "`$1`n$resourceLimits"
    
    # Remove nodePort lines
    $content = $content -replace '\s+nodePort:.*\n', ""
    
    $content | Out-File "$gkeDir\$serviceFile" -Encoding utf8 -NoNewline
    Write-Host "[OK] Generated $serviceFile" -ForegroundColor Green
}

# Generate database deployments with minimal resources
foreach ($service in $services) {
    $dbFile = "$service-db.yaml"
    $content = Get-Content "k8s\$dbFile" -Raw
    
    # Add PGDATA environment variable to use subdirectory (fixes GKE volume mount issue)
    $content = $content -replace '(- name: POSTGRES_USER\s+value: [^\r\n]+)', "`$1`n        - name: PGDATA`n          value: /var/lib/postgresql/data/pgdata"
    
    # Add resource limits for databases
    $dbResources = @"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
"@
    $content = $content -replace '(\s+- containerPort: 5432)', "`$1`n$dbResources"
    
    # Change to ClusterIP
    $content = $content -replace 'type: NodePort', 'type: ClusterIP'
    $content = $content -replace '\s+nodePort:.*\n', ""
    
    $content | Out-File "$gkeDir\$dbFile" -Encoding utf8 -NoNewline
    Write-Host "[OK] Generated $dbFile" -ForegroundColor Green
}

# Create GKE-specific ingress
$ingressContent = @"
# GKE Ingress for External Access
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: swappo-ingress
  namespace: swappo
  annotations:
    kubernetes.io/ingress.class: "gce"  # Use GKE ingress
    kubernetes.io/ingress.global-static-ip-name: "swappo-ip"  # Optional: reserve static IP
spec:
  rules:
  - http:
      paths:
      - path: /api/v1/auth/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: auth-service
            port:
              number: 8000
      - path: /api/v1/catalog/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: catalog-service
            port:
              number: 8000
      - path: /api/v1/chat/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: chat-service
            port:
              number: 8000
      - path: /api/v1/matchmaking/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: matchmaking-service
            port:
              number: 8000
      - path: /api/v1/notifications/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: notifications-service
            port:
              number: 8000
"@

$ingressContent | Out-File "$gkeDir\ingress.yaml" -Encoding utf8 -NoNewline
Write-Host "[OK] Generated ingress.yaml" -ForegroundColor Green

Write-Host ""
Write-Host "[SUCCESS] GKE manifests generated in $gkeDir/" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Create GKE cluster (see GKE-DEPLOYMENT.md)" -ForegroundColor White
Write-Host "2. Create ghcr-secret for image pulls" -ForegroundColor White
Write-Host "3. Deploy: kubectl apply -f k8s-gke/" -ForegroundColor White
