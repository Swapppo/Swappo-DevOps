# Kong API Gateway Integration Guide

## What You've Done So Far
✅ Installed Kong via Helm in the `kong` namespace  
✅ Kong LoadBalancer is running at: `34.40.17.122`

## What is Kong vs NGINX Ingress?

### NGINX Ingress (Your Old Setup)
- **Purpose**: Basic traffic routing
- **Features**: URL path routing, basic SSL/TLS, simple rewrites
- **Use Case**: Simple microservices routing

### Kong API Gateway (Your New Setup)
- **Purpose**: Full API Management Platform
- **Features**: Everything NGINX does PLUS:
  - 🔐 Authentication (API Keys, JWT, OAuth2, etc.)
  - ⏱️ Rate Limiting & Throttling
  - 📊 Analytics & Monitoring
  - 🔄 Request/Response Transformation
  - 💾 Caching
  - 🛡️ Security Plugins
  - 🔌 100+ Plugins for various needs

**Kong includes an Ingress Controller**, so it can completely replace NGINX.

## Migration Steps

### Step 1: Apply Kong Ingress Configuration
Replace your old NGINX ingress with Kong:

```powershell
# Apply Kong ingress (replaces your old ingress.yaml)
kubectl apply -f k8s-gke/kong-ingress.yaml

# Apply Kong plugins for advanced features
kubectl apply -f k8s-gke/kong-plugins.yaml
```

### Step 2: Verify Kong Ingress
```powershell
# Check if Kong ingress was created
kubectl get ingress -n swappo

# Check Kong services
kubectl get svc -n kong

# Get Kong external IP
kubectl get svc -n kong kong-gateway-proxy
```NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)                      AGE
kong-gateway-proxy   LoadBalancer   34.118.225.138   34.40.17.122   80:32518/TCP,443:32332/TCP   7m46s

You should see: `34.40.17.122` as your EXTERNAL-IP

### Step 3: Update DNS/Testing
Since Kong is on a different IP than your old NGINX:
- Old NGINX: `34.185.186.13`
- New Kong: `34.40.17.122`

**Option A: Use nip.io for testing**
```powershell
# Test with Kong's IP
curl http://34.40.17.122.nip.io/auth/health
curl http://34.40.17.122.nip.io/catalog/items
```

**Option B: Update your ingress to use Kong's IP**
1. Update [k8s-gke/kong-ingress.yaml](k8s-gke/kong-ingress.yaml) line 23 & 26:
   - Change `34.185.186.13.nip.io` to `34.40.17.122.nip.io`
2. Reapply: `kubectl apply -f k8s-gke/kong-ingress.yaml`

### Step 4: Remove Old NGINX Ingress (Once Kong Works)
```powershell
# Delete the old NGINX ingress
kubectl delete ingress swappo-ingress -n swappo

# Optional: Uninstall NGINX ingress controller if not needed
# Only do this if you installed it separately
# helm uninstall nginx-ingress -n ingress-nginx
```

## Understanding Kong Features

### 1. Rate Limiting (Already Configured)
Prevents abuse by limiting requests per user/IP:
- **Global**: 100 requests/minute, 5000/hour
- **Auth Service**: 20 requests/minute (stricter for login endpoints)

### 2. CORS (Already Configured)
Allows your frontend to make cross-origin requests to your APIs.

### 3. Logging (Already Configured)
Logs all requests to stdout (visible via `kubectl logs`).

### 4. Adding More Plugins

**Example: Add API Key Authentication**
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: api-key-auth
  namespace: swappo
plugin: key-auth
config:
  key_names:
    - apikey
```

Then annotate a service:
```yaml
# In your service definition
metadata:
  annotations:
    konghq.com/plugins: api-key-auth
```

**Example: Add Request Caching**
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: catalog-cache
  namespace: swappo
plugin: proxy-cache
config:
  strategy: memory
  cache_ttl: 300  # 5 minutes
  content_type:
    - application/json
```

## Monitoring Kong

### View Kong Logs
```powershell
# Gateway proxy logs
kubectl logs -n kong -l app.kubernetes.io/name=kong -f

# Controller logs
kubectl logs -n kong -l app=ingress-kong -f
```

### Check Plugin Status
```powershell
# List all plugins
kubectl get kongplugins -n swappo

# Describe a specific plugin
kubectl describe kongplugin global-rate-limit -n swappo
```

### Test Rate Limiting
```powershell
# Send rapid requests to trigger rate limit
for ($i=1; $i -le 150; $i++) {
    curl http://34.40.17.122/auth/health
}
```

You should see `429 Too Many Requests` after 100 requests.

## Architecture Comparison

### Before (NGINX)
```
Client → NGINX Ingress (34.185.186.13) → Services
         └─ Simple routing
```

### After (Kong)
```
Client → Kong Gateway (34.40.17.122) → Services
         ├─ Rate Limiting
         ├─ CORS
         ├─ Authentication (optional)
         ├─ Logging
         ├─ Caching (optional)
         └─ 100+ other plugins
```

## Common Use Cases

### 1. Protect Your Services from Abuse
Already done! Rate limiting is active.

### 2. Add API Key Authentication
```yaml
# Create a consumer
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: my-app
  namespace: swappo
  annotations:
    kubernetes.io/ingress.class: kong
username: my-app
credentials:
  - my-api-key

---
# Create an API key credential
apiVersion: configuration.konghq.com/v1
kind: KongCredential
metadata:
  name: my-api-key
  namespace: swappo
type: key-auth
consumerRef: my-app
config:
  key: my-super-secret-api-key-12345
```

### 3. Transform Requests/Responses
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: add-headers
  namespace: swappo
plugin: request-transformer
config:
  add:
    headers:
      - X-Service-Version:1.0
      - X-Gateway:Kong
```

### 4. Set Up JWT Validation
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: jwt-auth
  namespace: swappo
plugin: jwt
config:
  secret_is_base64: false
  key_claim_name: iss
```

## Troubleshooting

### Kong Not Routing Traffic
```powershell
# Check if ingress is created
kubectl get ingress -n swappo

# Check Kong pods are running
kubectl get pods -n kong

# Check service endpoints
kubectl get endpoints -n swappo
```

### 502 Bad Gateway
- Services might not be running
- Check: `kubectl get pods -n swappo`

### Rate Limit Not Working
```powershell
# Verify plugin is applied
kubectl get kongclusterplugins -n swappo

# Check plugin configuration
kubectl describe kongclusterplugin global-rate-limit -n swappo
```

### TLS Certificate Issues
```powershell
# Check cert-manager is working
kubectl get certificates -n swappo

# Check certificate status
kubectl describe certificate swappo-tls-kong -n swappo
```

## Next Steps

1. ✅ Apply Kong ingress and plugins
2. ✅ Test all your service endpoints through Kong
3. 🔄 Update your frontend to use Kong's IP (`34.40.17.122`)
4. 🗑️ Remove old NGINX ingress once Kong is stable
5. 📚 Explore Kong plugins: https://docs.konghq.com/hub/

## Useful Commands

```powershell
# View all Kong resources
kubectl get ingress,kongplugin,kongclusterplugin,kongconsumer -n swappo

# Watch Kong gateway logs
kubectl logs -n kong -l app.kubernetes.io/name=kong --follow

# Test an endpoint through Kong
curl http://34.40.17.122/auth/health

# Check rate limit headers
curl -I http://34.40.17.122/auth/health
# Look for: X-RateLimit-Remaining-Minute, X-RateLimit-Limit-Minute
```

## Resources
- [Kong Ingress Controller Docs](https://docs.konghq.com/kubernetes-ingress-controller/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)
- [Kong Rate Limiting](https://docs.konghq.com/hub/kong-inc/rate-limiting/)
