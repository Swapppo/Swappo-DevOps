# Install Loki Stack for Centralized Logging
# This installs Loki (log storage) + Promtail (log collector)

Write-Host "Installing Loki Stack for centralized logging..." -ForegroundColor Cyan
Write-Host ""

# Add Grafana Helm repo
Write-Host "Adding Grafana Helm repository..." -ForegroundColor Yellow
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

Write-Host ""
Write-Host "Installing Loki stack in swappo namespace..." -ForegroundColor Yellow

# Install Loki stack with custom values
helm install loki grafana/loki-stack `
  --namespace swappo `
  --set promtail.enabled=false `
  --set loki.persistence.enabled=true `
  --set loki.persistence.size=10Gi `
  --set grafana.enabled=false

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Loki stack installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Waiting for pods to be ready..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    Write-Host ""
    Write-Host "Checking pod status:" -ForegroundColor Cyan
    kubectl get pods -n swappo -l app=loki
    kubectl get pods -n swappo -l app=promtail
    
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Add Loki as a data source in Grafana" -ForegroundColor White
    Write-Host "   URL: http://loki:3100" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Port-forward Grafana to access it:" -ForegroundColor White
    Write-Host "   kubectl port-forward -n swappo svc/grafana 3000:80" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Get Grafana admin password:" -ForegroundColor White
    Write-Host '   kubectl get secret --namespace swappo grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }' -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Failed to install Loki stack. Check the error above." -ForegroundColor Red
}
