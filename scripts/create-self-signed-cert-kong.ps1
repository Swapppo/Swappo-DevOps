# Create self-signed certificate for Kong ingress
# This will work immediately but browsers will show a security warning

$domain = "34.40.17.122.sslip.io"
$namespace = "swappo"

Write-Host "Creating self-signed certificate for $domain..." -ForegroundColor Cyan

# Create private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
    -keyout tls.key `
    -out tls.crt `
    -subj "/CN=$domain/O=Swappo"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Certificate created successfully" -ForegroundColor Green
    
    # Create Kubernetes TLS secret
    Write-Host "Creating Kubernetes secret..." -ForegroundColor Cyan
    kubectl create secret tls swappo-tls-kong `
        --key tls.key `
        --cert tls.crt `
        -n $namespace `
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Clean up local files
    Remove-Item tls.key, tls.crt
    
    Write-Host "`n✅ Self-signed certificate created!" -ForegroundColor Green
    Write-Host "Note: Browsers will show a security warning - this is expected for self-signed certs" -ForegroundColor Yellow
    Write-Host "You can safely bypass the warning to test your application" -ForegroundColor Yellow
} else {
    Write-Host "❌ Failed to create certificate. Make sure OpenSSL is installed." -ForegroundColor Red
    Write-Host "Install OpenSSL or use Git Bash which includes it." -ForegroundColor Yellow
}
