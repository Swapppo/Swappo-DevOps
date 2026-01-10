# Deploy Shipping Estimates Cloud Function to GCP

$PROJECT_ID = "swapppo"
$REGION = "europe-west3"
$FUNCTION_NAME = "shipping-estimates"
$EASYSHIP_TOKEN = "sand_EpFMtejumXrSb5vfzWU1dL3b5RvXhSrujjurgRt/RAE="

Write-Host "Deploying Cloud Function: $FUNCTION_NAME" -ForegroundColor Cyan
Write-Host "Project: $PROJECT_ID" -ForegroundColor Gray
Write-Host "Region: $REGION" -ForegroundColor Gray
Write-Host ""

gcloud functions deploy $FUNCTION_NAME `
  --gen2 `
  --runtime=python311 `
  --region=$REGION `
  --source=. `
  --entry-point=get_shipping_estimate `
  --trigger-http `
  --allow-unauthenticated `
  --set-env-vars="EASYSHIP_API_TOKEN=$EASYSHIP_TOKEN" `
  --project=$PROJECT_ID `
  --memory=256MB `
  --timeout=30s

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Getting function URL..." -ForegroundColor Cyan

    $functionUrl = gcloud functions describe $FUNCTION_NAME `
        --gen2 `
        --region=$REGION `
        --project=$PROJECT_ID `
        --format="value(serviceConfig.uri)"

    Write-Host ""
    Write-Host "Function URL:" -ForegroundColor Green
    Write-Host $functionUrl -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Add this URL to your frontend environment config:" -ForegroundColor Cyan
    Write-Host "EXPO_PUBLIC_SHIPPING_API_URL=$functionUrl" -ForegroundColor Gray
}
else {
    Write-Host ""
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}
