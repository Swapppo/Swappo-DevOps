# Install Grafana for log visualization
Write-Host "Installing Grafana..." -ForegroundColor Cyan

helm install grafana grafana/grafana `
  --namespace swappo `
  --set persistence.enabled=true `
  --set persistence.size=5Gi `
  --set adminPassword=admin123 `
  --set service.type=LoadBalancer `
  --set datasources."datasources\.yaml".apiVersion=1 `
  --set datasources."datasources\.yaml".datasources[0].name=Loki `
  --set datasources."datasources\.yaml".datasources[0].type=loki `
  --set datasources."datasources\.yaml".datasources[0].url=http://loki:3100 `
  --set datasources."datasources\.yaml".datasources[0].access=proxy `
  --set datasources."datasources\.yaml".datasources[0].isDefault=true

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Grafana installed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Waiting for LoadBalancer IP..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30
    
    $ip = kubectl get svc -n swappo grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    
    Write-Host ""
    Write-Host "Grafana URL: http://$ip" -ForegroundColor Yellow
    Write-Host "Username: admin" -ForegroundColor White
    Write-Host "Password: admin123" -ForegroundColor White
    Write-Host ""
    Write-Host "Loki datasource is pre-configured!" -ForegroundColor Green
}
