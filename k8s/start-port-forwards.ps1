# Kubernetes Port Forwarding Setup Script
# This script sets up port forwarding for all Swappo services
# Run this to access your services at localhost:8000, localhost:8001, etc.

Write-Host "Starting Kubernetes port forwarding for Swappo services..." -ForegroundColor Cyan
Write-Host ""

# Function to start port forwarding as background jobs
function Start-PortForward {
    param(
        [string]$ServiceName,
        [int]$LocalPort,
        [int]$ServicePort = 8000
    )
    
    $jobName = "portforward-$ServiceName"
    
    # Check if job already exists
    $existingJob = Get-Job -Name $jobName -ErrorAction SilentlyContinue
    if ($existingJob) {
        Write-Host "Port forward for $ServiceName already running" -ForegroundColor Yellow
        return
    }
    
    # Start port forwarding as background job
    Start-Job -Name $jobName -ScriptBlock {
        param($svc, $lp, $sp)
        kubectl port-forward -n swappo "svc/$svc" "${lp}:${sp}"
    } -ArgumentList $ServiceName, $LocalPort, $ServicePort | Out-Null
    
    Start-Sleep -Seconds 1
    Write-Host "[OK] $ServiceName forwarded to http://localhost:$LocalPort" -ForegroundColor Green
}

# Start port forwarding for all services
Start-PortForward -ServiceName "auth-service" -LocalPort 8000
Start-PortForward -ServiceName "catalog-service" -LocalPort 8001
Start-PortForward -ServiceName "matchmaking-service" -LocalPort 8002
Start-PortForward -ServiceName "notifications-service" -LocalPort 8003
Start-PortForward -ServiceName "chat-service" -LocalPort 8004

Write-Host ""
Write-Host "All services are now accessible:" -ForegroundColor Cyan
Write-Host "  Auth:          http://localhost:8000" -ForegroundColor White
Write-Host "  Catalog:       http://localhost:8001" -ForegroundColor White
Write-Host "  Matchmaking:   http://localhost:8002" -ForegroundColor White
Write-Host "  Notifications: http://localhost:8003" -ForegroundColor White
Write-Host "  Chat:          http://localhost:8004" -ForegroundColor White
Write-Host ""
Write-Host "To stop all port forwards:" -ForegroundColor Yellow
Write-Host "  Get-Job | Where-Object Name -like 'portforward-*' | Stop-Job | Remove-Job" -ForegroundColor Gray
Write-Host ""
Write-Host "To view port forward status:" -ForegroundColor Yellow
Write-Host "  Get-Job | Where-Object Name -like 'portforward-*'" -ForegroundColor Gray
Write-Host ""
Write-Host "Port forwards will run in the background." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to exit this script (port forwards will continue running)" -ForegroundColor Cyan
Write-Host ""

# Keep script running so user can see the output
Read-Host "Press Enter to continue (port forwards will keep running in background)"
