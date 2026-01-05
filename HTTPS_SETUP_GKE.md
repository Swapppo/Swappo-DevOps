# HTTPS Setup on GKE with nip.io

This guide explains how to set up HTTPS on GKE using nip.io (automatic wildcard DNS) and cert-manager with Let's Encrypt for free SSL certificates.

## ✅ Working Solution

**Current Setup:**
- **Domain**: `34.185.186.13.nip.io` (auto-resolves to LoadBalancer IP)
- **SSL**: Let's Encrypt production certificates via cert-manager
- **Ingress**: NGINX Ingress Controller
- **Endpoints**: All services accessible via HTTPS

## Prerequisites
- GKE cluster with NGINX Ingress Controller installed
- kubectl configured to access your cluster

## Step 1: Install cert-manager

cert-manager will automatically provision and manage SSL certificates from Let's Encrypt.

```powershell
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s
```

## Step 2: Get your LoadBalancer External IP

```powershell
# Get the external IP of your NGINX ingress controller
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Or if you haven't installed nginx ingress yet:
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

Wait for the `EXTERNAL-IP` to be assigned (it may take a few minutes).

## Step 3: Apply the ClusterIssuer

The ClusterIssuer is already created in `k8s-gke/cert-manager-issuer.yaml`. Apply it:

```powershell
kubectl apply -f k8s-gke/cert-manager-issuer.yaml
```

## Step 4: Update and Apply the Ingress

The ingress is configured to use nip.io with your LoadBalancer IP (`34.185.186.13.nip.io`).

**Current configuration:**
- Host: `34.185.186.13.nip.io`
- TLS enabled with automatic Let's Encrypt certificates
- ClusterIssuer: `letsencrypt-prod`

Apply the ingress:

```powershell
kubectl apply -f k8s-gke/ingress.yaml
```

## Step 5: Verify Certificate

```powershell
# Check certificate status
kubectl get certificate -n swappo

# Check certificate details
kubectl describe certificate swappo-tls -n swappo

# Check if certificate is ready
kubectl get certificaterequest -n swappo
```

## Step 6: Test Your Setup

Once the certificate is ready (status: True), test your endpoints:

```powershell
# Test all HTTPS endpoints
curl https://34.185.186.13.nip.io/auth/health
curl https://34.185.186.13.nip.io/catalog/health
curl https://34.185.186.13.nip.io/chat/health
curl https://34.185.186.13.nip.io/matchmaking/health
curl https://34.185.186.13.nip.io/notifications/health
```

All endpoints should return `{"status":"healthy"}` with HTTPS enabled.

## Troubleshooting

### Certificate not issuing
```powershell
# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager

# Check certificate order/challenge
kubectl get order,challenge -n swappo
kubectl describe challenge -n swappo
```

### DNS not resolving
Test nip.io resolution:
```powershell
nslookup 34.123.45.67.nip.io
```

### Let's Encrypt Rate Limits
If testing, use the staging environment first (already configured in the issuer).
Once everything works, switch to production issuer.

## Example Domain Structure

With external IP `34.185.186.13`, your live HTTPS endpoints are:
- `https://34.185.186.13.nip.io/auth/*`
- `https://34.185.186.13.nip.io/catalog/*`
- `https://34.185.186.13.nip.io/chat/*`
- `https://34.185.186.13.nip.io/matchmaking/*`
- `https://34.185.186.13.nip.io/notifications/*`

## Common Issues & Solutions

### Issue: DNS Query Timeout
**Problem**: Your ISP/VPN DNS server blocks external queries.  
**Solution**: Disconnect from VPN or use public DNS (Google 8.8.8.8, Cloudflare 1.1.1.1).

```powershell
# Test with public DNS
nslookup 34.185.186.13.nip.io 8.8.8.8
```

### Issue: DuckDNS Not Working
**Problem**: DuckDNS may have propagation delays or DNS issues.  
**Solution**: Use nip.io instead - it works immediately without configuration.

### Issue: Certificate Stays in "False" State
**Problem**: Let's Encrypt can't reach your ingress for HTTP-01 challenge.  
**Solution**: 
1. Ensure port 80 is open on your LoadBalancer
2. Verify DNS resolves correctly
3. Check challenge details: `kubectl describe challenge -n swappo`

## Why nip.io?

- ✅ **No registration required**
- ✅ **Instant DNS resolution**
- ✅ **Works with Let's Encrypt**
- ✅ **No propagation delays**
- ✅ **Free and reliable**

Format: `<IP>.nip.io` automatically resolves to `<IP>`
