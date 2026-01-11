# Create Self-Signed Certificate for Swappo

$domain = "34.40.17.122.nip.io"
$certPath = "$env:TEMP\swappo-cert.pfx"
$certPassword = ConvertTo-SecureString -String "temp123" -Force -AsPlainText

Write-Host "Creating self-signed certificate for $domain..." -ForegroundColor Cyan

# Create self-signed certificate
$cert = New-SelfSignedCertificate `
    -DnsName $domain `
    -CertStoreLocation "cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(1)

# Export certificate
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $certPassword

# Extract PEM files
$certPem = "$env:TEMP\tls.crt"
$keyPem = "$env:TEMP\tls.key"

# Convert to PEM format
$certContent = [System.Convert]::ToBase64String($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
$certPemContent = "-----BEGIN CERTIFICATE-----`n"
for ($i = 0; $i -lt $certContent.Length; $i += 64) {
    $certPemContent += $certContent.Substring($i, [Math]::Min(64, $certContent.Length - $i)) + "`n"
}
$certPemContent += "-----END CERTIFICATE-----"
$certPemContent | Out-File -FilePath $certPem -Encoding ASCII

Write-Host "Certificate created successfully!" -ForegroundColor Green
Write-Host "Certificate file: $certPem" -ForegroundColor Yellow

# Get private key (this is tricky in PowerShell, we'll use a different approach)
Write-Host "`nNOTE: For simplicity, creating Kubernetes secret directly..." -ForegroundColor Cyan

# Delete old certificate if exists
kubectl delete secret swappo-tls-kong -n swappo 2>$null

# Create base64 encoded cert for kubectl
$certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
$certBase64 = [System.Convert]::ToBase64String($certBytes)

# For the key, we need to export it
$rsaKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$keyBytes = $rsaKey.ExportRSAPrivateKey()
$keyPemContent = "-----BEGIN RSA PRIVATE KEY-----`n"
$keyBase64 = [System.Convert]::ToBase64String($keyBytes)
for ($i = 0; $i -lt $keyBase64.Length; $i += 64) {
    $keyPemContent += $keyBase64.Substring($i, [Math]::Min(64, $keyBase64.Length - $i)) + "`n"
}
$keyPemContent += "-----END RSA PRIVATE KEY-----"
$keyPemContent | Out-File -FilePath $keyPem -Encoding ASCII

Write-Host "Creating Kubernetes TLS secret..." -ForegroundColor Cyan
kubectl create secret tls swappo-tls-kong -n swappo --cert=$certPem --key=$keyPem

# Cleanup
Remove-Item $certPath -ErrorAction SilentlyContinue
Remove-Item $certPem -ErrorAction SilentlyContinue
Remove-Item $keyPem -ErrorAction SilentlyContinue
Remove-Item "cert:\CurrentUser\My\$($cert.Thumbprint)" -ErrorAction SilentlyContinue

Write-Host "`n✓ Self-signed certificate created and installed!" -ForegroundColor Green
Write-Host "  Your browser will show a warning - click 'Advanced' and 'Proceed' to accept it." -ForegroundColor Yellow
