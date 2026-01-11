# Configure Grafana with Prometheus and Loki datasources

$grafanaUrl = "http://34.159.79.120"
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin123"))

# Add Prometheus datasource
$prometheusPayload = @{
    name = "Prometheus"
    type = "prometheus"
    url = "http://prometheus:9090"
    access = "proxy"
    isDefault = $true
    jsonData = @{
        httpMethod = "POST"
        timeInterval = "30s"
    }
} | ConvertTo-Json

Write-Host "Adding Prometheus datasource to Grafana..."
try {
    $response = Invoke-RestMethod -Uri "$grafanaUrl/api/datasources" `
        -Method POST `
        -Headers @{
            "Authorization" = "Basic $auth"
            "Content-Type" = "application/json"
        } `
        -Body $prometheusPayload
    Write-Host "Prometheus datasource added successfully" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "Prometheus datasource already exists" -ForegroundColor Yellow
    } else {
        Write-Host "Failed to add Prometheus datasource: $_" -ForegroundColor Red
    }
}

# Verify Loki datasource exists (added earlier)
Write-Host ""
Write-Host "Verifying Loki datasource..."
try {
    $datasources = Invoke-RestMethod -Uri "$grafanaUrl/api/datasources" `
        -Method GET `
        -Headers @{"Authorization" = "Basic $auth"}
    
    $lokiExists = $datasources | Where-Object { $_.type -eq "loki" }
    if ($lokiExists) {
        Write-Host "Loki datasource exists" -ForegroundColor Green
    } else {
        Write-Host "Loki datasource not found, adding it..." -ForegroundColor Yellow
        $lokiPayload = @{
            name = "Loki"
            type = "loki"
            url = "http://loki:3100"
            access = "proxy"
            jsonData = @{
                maxLines = 1000
            }
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri "$grafanaUrl/api/datasources" `
            -Method POST `
            -Headers @{
                "Authorization" = "Basic $auth"
                "Content-Type" = "application/json"
            } `
            -Body $lokiPayload
        Write-Host "Loki datasource added" -ForegroundColor Green
    }
} catch {
    Write-Host "Error checking Loki datasource: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Datasource Configuration Complete ===" -ForegroundColor Cyan
Write-Host "Grafana URL: $grafanaUrl"
Write-Host "Username: admin"
Write-Host "Password: admin123"
Write-Host ""
Write-Host "Available datasources:"
Write-Host "  - Prometheus (metrics): http://prometheus:9090"
Write-Host "  - Loki (logs): http://loki:3100"
