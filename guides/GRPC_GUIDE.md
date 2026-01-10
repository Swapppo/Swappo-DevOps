# gRPC Implementation: Catalog ↔ Matchmaking

This document describes the gRPC communication between Catalog and Matchmaking services.

## Overview

The Matchmaking service uses gRPC to communicate with the Catalog service to:
- Validate that items exist before creating trade offers
- Check if items are active (not archived/swapped)
- Verify item ownership (proposer owns offered items, receiver owns requested items)
- Fetch item details for display in trade offers

## Architecture

```
┌─────────────────────┐         gRPC          ┌─────────────────────┐
│  Matchmaking        │ ──────────────────>   │  Catalog Service    │
│  Service            │    Port 50051         │                     │
│                     │                       │  - gRPC Server      │
│  - gRPC Client      │                       │  - Database Access  │
│  - Validates items  │                       │  - Item Management  │
└─────────────────────┘                       └─────────────────────┘
```

## Proto Definition

Location: `Swappo-Catalog/protos/catalog.proto`

### Services

**CatalogService**
- `GetItem(GetItemRequest) → ItemResponse` - Get single item by ID
- `GetItems(GetItemsRequest) → GetItemsResponse` - Batch fetch items
- `ValidateItems(ValidateItemsRequest) → ValidateItemsResponse` - Check existence, status, ownership

### Messages

**ItemResponse** - Complete item details
- id, name, description, category
- image_urls, location_lat, location_lon
- owner_id, status, created_at, updated_at

**ValidateItemsResponse** - Item validation results
- item_id, exists, is_active, owner_id

## Implementation

### Catalog Service (gRPC Server)

**Files:**
- `grpc_server.py` - gRPC server implementation
- `catalog_pb2.py` - Generated protobuf messages (auto-generated)
- `catalog_pb2_grpc.py` - Generated gRPC stubs (auto-generated)

**Port:** 50051 (internal cluster communication)

**Server Lifecycle:**
- Started automatically when FastAPI app starts (in lifespan context manager)
- Runs concurrently with FastAPI HTTP server
- Handles multiple concurrent gRPC requests via ThreadPoolExecutor

### Matchmaking Service (gRPC Client)

**Files:**
- `grpc_client.py` - gRPC client wrapper
- `catalog_pb2.py` - Generated protobuf messages (auto-generated)
- `catalog_pb2_grpc.py` - Generated gRPC stubs (auto-generated)

**Connection:** `catalog-service:50051` (Kubernetes service DNS)

**Usage Example:**
```python
from grpc_client import get_catalog_client

# Get client instance
catalog_client = get_catalog_client()

# Validate items before creating trade offer
validations = catalog_client.validate_items([1, 2, 3])

for v in validations:
    if not v["exists"]:
        print(f"Item {v['item_id']} not found")
    elif not v["is_active"]:
        print(f"Item {v['item_id']} is not active")
```

## Trade Offer Validation Flow

When creating a trade offer in Matchmaking service:

1. **Receive Request** - proposer_id, receiver_id, offered_item_ids, requested_item_ids
2. **gRPC Validation** - Call `ValidateItems` with all item IDs
3. **Check Existence** - Ensure all items exist in catalog
4. **Check Status** - Ensure all items are active
5. **Check Ownership** - Verify:
   - Proposer owns all offered items
   - Receiver owns all requested items
6. **Create Offer** - If all validations pass, create trade offer in DB

**Error Responses:**
- `404 NOT_FOUND` - Items don't exist
- `400 BAD_REQUEST` - Items are inactive
- `403 FORBIDDEN` - Wrong item ownership
- `503 SERVICE_UNAVAILABLE` - Catalog service is down

## Kubernetes Configuration

### Catalog Service (k8s-gke/catalog-service.yaml)

```yaml
ports:
- name: http
  containerPort: 8000  # FastAPI HTTP
- name: grpc
  containerPort: 50051 # gRPC server

service:
  ports:
  - name: http
    port: 8000
    targetPort: 8000
  - name: grpc
    port: 50051
    targetPort: 50051
```

### Service Discovery

Matchmaking connects to Catalog via Kubernetes DNS:
- Service name: `catalog-service`
- Namespace: `swappo`
- Full DNS: `catalog-service.swappo.svc.cluster.local:50051`
- Short form: `catalog-service:50051` (same namespace)

## Code Generation

To regenerate protobuf/gRPC Python code:

**Linux/Mac:**
```bash
cd Swappo-Catalog
./generate_grpc.sh
```

**Windows:**
```powershell
cd Swappo-Catalog
.\generate_grpc.ps1
```

**Manual:**
```bash
python -m grpc_tools.protoc \
  -I./protos \
  --python_out=. \
  --grpc_python_out=. \
  ./protos/catalog.proto
```

## Testing

### Test gRPC Server

```python
import grpc
import catalog_pb2
import catalog_pb2_grpc

# Connect to server
channel = grpc.insecure_channel('localhost:50051')
stub = catalog_pb2_grpc.CatalogServiceStub(channel)

# Test GetItem
request = catalog_pb2.GetItemRequest(item_id=1)
response = stub.GetItem(request)
print(f"Item: {response.name}")

# Test ValidateItems
request = catalog_pb2.ValidateItemsRequest(item_ids=[1, 2, 3])
response = stub.ValidateItems(request)
for v in response.validations:
    print(f"Item {v.item_id}: exists={v.exists}, active={v.is_active}")
```

### Test via kubectl port-forward

```bash
# Forward gRPC port
kubectl port-forward -n swappo svc/catalog-service 50051:50051

# Run test script
python test_grpc.py
```

## Performance Benefits

### vs REST/HTTP
- **Faster:** Binary protocol (protobuf) vs JSON
- **Type-safe:** Schema-first design with code generation
- **Streaming:** Supports bidirectional streaming (not used yet)
- **Efficiency:** Smaller payload size, multiplexed connections

### vs Direct Database Access
- **Separation of concerns:** Matchmaking doesn't need catalog DB credentials
- **Data consistency:** Single source of truth in Catalog service
- **Security:** No direct DB exposure between services
- **Scalability:** Services can scale independently

## Monitoring

### Logs

**Catalog Service (gRPC Server):**
- `🚀 gRPC Server starting on [::]:50051`
- `⏹️ Shutting down gRPC server`

**Matchmaking Service (gRPC Client):**
- `✅ Connected to Catalog gRPC service at catalog-service:50051`
- `✅ All items validated via gRPC for trade offer`
- `❌ gRPC error during item validation: <error>`

### Health Checks

Check if gRPC port is open:
```bash
kubectl exec -n swappo <catalog-pod> -- nc -zv localhost 50051
```

Check service connectivity from Matchmaking:
```bash
kubectl exec -n swappo <matchmaking-pod> -- nc -zv catalog-service 50051
```

## Future Enhancements

1. **Add authentication** - mTLS or token-based auth
2. **Add streaming** - Stream item updates to Matchmaking
3. **Add caching** - Cache item details in Matchmaking with TTL
4. **Add metrics** - Prometheus metrics for gRPC calls
5. **Add tracing** - OpenTelemetry for distributed tracing
6. **Extend to other services** - Chat ↔ Auth, Notifications ↔ Auth

## Troubleshooting

### Common Issues

**"Cannot connect to catalog-service:50051"**
- Check if Catalog service is running: `kubectl get pods -n swappo`
- Check if port 50051 is exposed: `kubectl get svc catalog-service -n swappo`
- Check service DNS: `kubectl exec -n swappo <pod> -- nslookup catalog-service`

**"ModuleNotFoundError: No module named 'catalog_pb2'"**
- Run code generation: `python -m grpc_tools.protoc ...`
- Check if `catalog_pb2.py` exists in service directory

**"grpc.StatusCode.UNAVAILABLE"**
- Catalog service is down or restarting
- Network policy blocking traffic
- Check logs: `kubectl logs -n swappo <catalog-pod>`

**"Validation fails for valid items"**
- Check item status in database (must be "active")
- Verify owner_id matches proposer/receiver
- Check gRPC server logs for errors

## Dependencies

**Catalog Service:**
- grpcio==1.68.1
- grpcio-tools==1.68.1
- protobuf==5.29.2

**Matchmaking Service:**
- grpcio==1.68.1
- grpcio-tools==1.68.1
- protobuf==5.29.2

## References

- [gRPC Python Documentation](https://grpc.io/docs/languages/python/)
- [Protocol Buffers](https://developers.google.com/protocol-buffers)
- [Kubernetes Service DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
