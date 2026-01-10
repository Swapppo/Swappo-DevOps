# Resilience Patterns: Circuit Breaker & Retry

This document describes the error tolerance mechanisms implemented across microservices.

## Overview

Implemented resilience patterns to handle failures gracefully:
- **Retry Pattern** - Automatically retry failed requests with exponential backoff
- **Circuit Breaker Pattern** - Prevent cascading failures by stopping calls to failing services

## Libraries Used

- **tenacity 8.2.3** - Retry logic with decorators
- **pybreaker 1.0.1** - Circuit breaker implementation

## Implementation by Service

### Matchmaking Service

#### gRPC Client (Catalog Service)

**File:** [grpc_client.py](Swappo-Matchmaking/grpc_client.py)

**Circuit Breaker Configuration:**
```python
catalog_circuit_breaker = CircuitBreaker(
    fail_max=5,           # Open after 5 consecutive failures
    timeout_duration=60,  # Stay open for 60 seconds
    name="catalog_grpc"
)
```

**Retry Configuration:**
```python
@retry(
    retry=retry_if_exception_type(grpc.RpcError),
    stop=stop_after_attempt(3),  # Retry up to 3 times
    wait=wait_exponential(multiplier=1, min=1, max=10)  # 1s, 2s, 4s, max 10s
)
```

**Protected Methods:**
- `get_item()` - Get single item with retry + circuit breaker
- `get_items()` - Batch fetch items with retry + circuit breaker  
- `validate_items()` - Validate items with retry + circuit breaker

**Behavior:**
1. First attempt fails → Wait 1s, retry (attempt 2)
2. Second attempt fails → Wait 2s, retry (attempt 3)
3. Third attempt fails → Raise exception
4. After 5 consecutive failures → Circuit opens for 60s
5. While open → Immediately reject calls with `CircuitBreakerError`
6. After 60s → Circuit half-open, allow 1 test call
7. If successful → Circuit closes, resume normal operation

#### HTTP Client (Chat & Notifications)

**File:** [http_client.py](Swappo-Matchmaking/http_client.py)

**Circuit Breakers:**
- `notification_circuit_breaker` - For notification service calls
- `chat_circuit_breaker` - For chat service calls

**Functions:**
- `send_notification_resilient()` - Send notification with retry
- `create_chat_room_resilient()` - Create chat room with retry

**Usage in main.py:**
```python
# Instead of direct httpx call
await send_notification_resilient(url, data)
await create_chat_room_resilient(url, data)
```

### Chat Service

**File:** [http_client.py](Swappo-Chat/http_client.py)

**Retry Configuration:**
```python
@retry(
    retry=retry_if_exception_type((httpx.RequestError, httpx.HTTPStatusError)),
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10),
    reraise=False  # Don't fail message sending if notification fails
)
```

**Protected Function:**
- `send_notification_with_retry()` - Send notification with retry (doesn't fail message creation)

## Resilience Patterns Explained

### Retry Pattern

**When to use:**
- Transient network failures
- Temporary service unavailability
- Rate limiting errors (with backoff)

**Configuration:**
```python
@retry(
    retry=retry_if_exception_type(Exception),  # Which exceptions to retry
    stop=stop_after_attempt(3),                # Max retry attempts
    wait=wait_exponential(multiplier=1, min=1, max=10)  # Backoff strategy
)
```

**Backoff Strategy:**
- Exponential backoff prevents overwhelming failing services
- Wait time: attempt_number^2 * multiplier
- Example: 1s → 2s → 4s → 8s (capped at max)

### Circuit Breaker Pattern

**States:**
1. **Closed** (Normal) - Requests pass through normally
2. **Open** (Failing) - Requests immediately rejected, service given time to recover
3. **Half-Open** (Testing) - Allow 1 request to test if service recovered

**Benefits:**
- Prevents cascading failures across microservices
- Fails fast instead of wasting resources on doomed requests
- Gives failing service time to recover
- Reduces load on downstream services during incidents

**Workflow:**
```
Normal Operation (Closed)
    ↓ (5 consecutive failures)
Circuit Opens
    ↓ (wait 60s)
Half-Open (test 1 request)
    ↓ success → Closed
    ↓ failure → Open again
```

## Error Handling Strategy

### gRPC Calls (Matchmaking → Catalog)

**Critical path (trade offer validation):**
- Retry 3 times with exponential backoff
- Circuit breaker prevents flood during outage
- If all retries fail → Return HTTP 503 to client

**Example:**
```python
try:
    validations = catalog_client.validate_items([1, 2, 3])
except CircuitBreakerError:
    raise HTTPException(503, "Catalog service unavailable")
except grpc.RpcError:
    raise HTTPException(503, "Catalog service error")
```

### HTTP Calls (Service → Service)

**Non-critical path (notifications):**
- Retry 3 times
- If fails → Log error, don't fail main operation
- Circuit breaker prevents wasting resources

**Example:**
```python
# Notification failure doesn't fail message creation
await send_notification_with_retry(url, data)  # Returns True/False
# Message is still saved even if notification fails
```

## Monitoring & Observability

### Logs to Watch

**Circuit Breaker:**
- `⚠️ Circuit breaker is OPEN - Service is unavailable`
- Indicates service is consistently failing

**Retry:**
- Multiple log entries for same operation indicate retries
- Check for patterns of failures

**gRPC:**
- `✅ Connected to Catalog gRPC service at catalog-service:50051`
- `❌ gRPC error during item validation: <error>`

### Health Check Endpoints

Add circuit breaker state to health checks:
```python
@app.get("/health")
def health():
    return {
        "status": "healthy",
        "circuit_breakers": {
            "catalog_grpc": catalog_circuit_breaker.current_state,
            "notifications": notification_circuit_breaker.current_state
        }
    }
```

## Testing Resilience

### Test Circuit Breaker

**Simulate service failure:**
```powershell
# 1. Stop catalog service to simulate failure
kubectl scale deployment catalog-service -n swappo --replicas=0

# 2. Wait for pod to terminate
Start-Sleep -Seconds 5

# 3. Test circuit breaker - Create trade offers (triggers gRPC validate_items)
# Note: These will fail because catalog service is down, triggering retry + circuit breaker
for ($i=1; $i -le 6; $i++) {
    Write-Host "`nAttempt $i - Creating trade offer (will fail and retry)"
    
    $body = @{
        proposer_id = "user1"
        receiver_id = "user2"
        offered_item_ids = @(1)
        requested_item_ids = @(2)
        message = "Test circuit breaker"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://34.40.17.122.nip.io/matchmaking/api/v1/offers" `
        -Method POST `
        -ContentType "application/json" `
        -Body $body `
        -ErrorAction SilentlyContinue
    
    Start-Sleep -Seconds 3
}
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> kubectl logs -n swappo -l app=matchmaking-service --tail=100 | Select-String -Pattern "gRPC|retry|circuit|Circuit"
Defaulted container "matchmaking-service" out of: matchmaking-service, cloud-sql-proxy

  File "/app/grpc_client.py", line 164, in validate_items
    response = catalog_circuit_breaker.call(self.stub.ValidateItems, request)
    raise CircuitBreakerError(error_msg)
pybreaker.CircuitBreakerError: Timeout not elapsed yet, circuit breaker still open
ΓÜá∩╕Å Circuit breaker is OPEN - Catalog service is unavailable
    do = self.iter(retry_state=retry_state)
  File "/app/grpc_client.py", line 164, in validate_items
    response = catalog_circuit_breaker.call(self.stub.ValidateItems, request)
    raise CircuitBreakerError(error_msg)
pybreaker.CircuitBreakerError: Timeout not elapsed yet, circuit breaker still open



PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> kubectl logs -n swappo -l app=matchmaking-service --tail=200
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> kubectl logs -n swappo -l app=matchmaking-service --tail=200
Defaulted container "matchmaking-service" out of: matchmaking-service, cloud-sql-proxy
    do = self.iter(retry_state=retry_state)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 314, in iter
    return fut.result()
           ^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/concurrent/futures/_base.py", line 449, in result
    return self.__get_result()
           ^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/concurrent/futures/_base.py", line 401, in __get_result
    raise self._exception
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 382, in __call__
    result = fn(*args, **kwargs)
             ^^^^^^^^^^^^^^^^^^^
  File "/app/grpc_client.py", line 164, in validate_items
    response = catalog_circuit_breaker.call(self.stub.ValidateItems, request)
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 261, in call
    return self.state.call(func, *args, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 936, in call
    return self.before_call(func, *args, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 925, in before_call
    raise CircuitBreakerError(error_msg)
pybreaker.CircuitBreakerError: Timeout not elapsed yet, circuit breaker still open
INFO:     10.29.0.65:33038 - "GET /health HTTP/1.1" 200 OK
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
INFO:     10.29.0.35:60382 - "POST /api/v1/offers HTTP/1.1" 500 Internal Server Error
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  File "/usr/local/lib/python3.11/site-packages/uvicorn/protocols/http/httptools_impl.py", line 426, in run_asgi
    result = await app(  # type: ignore[func-returns-value]
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/uvicorn/middleware/proxy_headers.py", line 84, in __call__
    return await self.app(scope, receive, send)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/fastapi/applications.py", line 1054, in __call__     
    await super().__call__(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/applications.py", line 113, in __call__    
    await self.middleware_stack(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/middleware/errors.py", line 187, in __call__
    raise exc
  File "/usr/local/lib/python3.11/site-packages/starlette/middleware/errors.py", line 165, in __call__
    await self.app(scope, receive, _send)
  File "/usr/local/lib/python3.11/site-packages/starlette/middleware/cors.py", line 85, in __call__  
    await self.app(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/middleware/exceptions.py", line 62, in __call__
    await wrap_app_handling_exceptions(self.app, conn)(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 62, in wrapped_app
    raise exc
  File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 51, in wrapped_app
    await app(scope, receive, sender)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 715, in __call__
    await self.middleware_stack(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 735, in app
    await route.handle(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 288, in handle
    await self.app(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 76, in app
    await wrap_app_handling_exceptions(app, request)(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 62, in wrapped_app
    raise exc
  File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 51, in wrapped_app
    await app(scope, receive, sender)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 73, in app
    response = await f(request)
               ^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 301, in app
    raw_response = await run_endpoint_function(
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 212, in run_endpoint_function
    return await dependant.call(**values)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/app/main.py", line 217, in create_trade_offer
    validations = catalog_client.validate_items(all_item_ids)
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 289, in wrapped_f        
    return self(f, *args, **kw)
           ^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 379, in __call__
    do = self.iter(retry_state=retry_state)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 314, in iter
    return fut.result()
           ^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/concurrent/futures/_base.py", line 449, in result
    return self.__get_result()
           ^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/concurrent/futures/_base.py", line 401, in __get_result
    raise self._exception
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 382, in __call__
    result = fn(*args, **kwargs)
             ^^^^^^^^^^^^^^^^^^^
  File "/app/grpc_client.py", line 164, in validate_items
    response = catalog_circuit_breaker.call(self.stub.ValidateItems, request)
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 261, in call
    return self.state.call(func, *args, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 936, in call
    return self.before_call(func, *args, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 925, in before_call
    raise CircuitBreakerError(error_msg)
pybreaker.CircuitBreakerError: Timeout not elapsed yet, circuit breaker still open
INFO:     10.29.0.65:33050 - "GET /health HTTP/1.1" 200 OK
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
INFO:     10.29.0.35:56614 - "POST /api/v1/offers HTTP/1.1" 500 Internal Server Error
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  File "/usr/local/lib/python3.11/site-packages/uvicorn/protocols/http/httptools_impl.py", line 426, in run_asgi
    result = await app(  # type: ignore[func-returns-value]
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/uvicorn/middleware/proxy_headers.py", line 84, in __call__
    return await self.app(scope, receive, send)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/fastapi/applications.py", line 1054, in __call__     
    await super().__call__(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/applications.py", line 113, in __call__    
    await self.middleware_stack(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/middleware/errors.py", line 187, in __call__
    raise exc
  File "/usr/local/lib/python3.11/site-packages/starlette/middleware/errors.py", line 165, in __call__
    await self.app(scope, receive, _send)
  File "/usr/local/lib/python3.11/site-packages/starlette/middleware/cors.py", line 85, in __call__  
    await self.app(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/middleware/exceptions.py", line 62, in __call__
    await wrap_app_handling_exceptions(self.app, conn)(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 62, in wrapped_app
    raise exc
  File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 51, in wrapped_app
    await app(scope, receive, sender)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 715, in __call__
    await self.middleware_stack(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 735, in app
    await route.handle(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 288, in handle
    await self.app(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 76, in app
    await wrap_app_handling_exceptions(app, request)(scope, receive, send)
  File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 62, in wrapped_app
    raise exc
  File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 51, in wrapped_app
    await app(scope, receive, sender)
  File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 73, in app
    response = await f(request)
               ^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 301, in app
    raw_response = await run_endpoint_function(
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 212, in run_endpoint_function
    return await dependant.call(**values)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/app/main.py", line 217, in create_trade_offer
    validations = catalog_client.validate_items(all_item_ids)
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 289, in wrapped_f        
    return self(f, *args, **kw)
           ^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 379, in __call__
    do = self.iter(retry_state=retry_state)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 314, in iter
    return fut.result()
           ^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/concurrent/futures/_base.py", line 449, in result
    return self.__get_result()
           ^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/concurrent/futures/_base.py", line 401, in __get_result
    raise self._exception
  File "/usr/local/lib/python3.11/site-packages/tenacity/__init__.py", line 382, in __call__
    result = fn(*args, **kwargs)
             ^^^^^^^^^^^^^^^^^^^
  File "/app/grpc_client.py", line 164, in validate_items
    response = catalog_circuit_breaker.call(self.stub.ValidateItems, request)
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 261, in call
    return self.state.call(func, *args, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 936, in call
    return self.before_call(func, *args, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/pybreaker.py", line 925, in before_call
    raise CircuitBreakerError(error_msg)
pybreaker.CircuitBreakerError: Timeout not elapsed yet, circuit breaker still open
INFO:     10.29.0.65:60766 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:60782 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:60794 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:47230 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:47232 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:47234 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:46576 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:46584 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:46592 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:48280 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:48292 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:48298 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:44484 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:44496 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:44506 - "GET /health HTTP/1.1" 200 OK
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
# Expected behavior:
# Attempts 1-5: Each request retries 3 times (exponential backoff: 1s, 2s, 4s)
# Attempt 6: Circuit opens - immediate failure without retries

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> kubectl logs -n swappo -l app=matchmaking-service --tail=200
Defaulted container "matchmaking-service" out of: matchmaking-service, cloud-sql-proxy
INFO:     Started server process [1]
INFO:     Waiting for application startup.
Database tables created successfully!
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     10.29.0.65:44656 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:49252 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:49258 - "GET /health HTTP/1.1" 200 OK
✅ Connected to Catalog gRPC service at catalog-service:50051
❌ gRPC error validating items: <_InactiveRpcError of RPC that terminated with:
        status = StatusCode.UNAVAILABLE
        details = "failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)"
        debug_error_string = "UNKNOWN:Error received from peer  {grpc_message:"failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)", grpc_status:14}"
>
❌ gRPC error validating items: <_InactiveRpcError of RPC that terminated with:
        status = StatusCode.UNAVAILABLE
        details = "failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)"
        debug_error_string = "UNKNOWN:Error received from peer  {grpc_status:14, grpc_message:"failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)"}"
>
❌ gRPC error validating items: <_InactiveRpcError of RPC that terminated with:
        status = StatusCode.UNAVAILABLE
        details = "failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)"
        debug_error_string = "UNKNOWN:Error received from peer  {grpc_message:"failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)", grpc_status:14}"
>
❌ gRPC error during item validation: <_InactiveRpcError of RPC that terminated with:
        status = StatusCode.UNAVAILABLE
        details = "failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)"
        debug_error_string = "UNKNOWN:Error received from peer  {grpc_message:"failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)", grpc_status:14}"
>
INFO:     10.29.0.65:56220 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.35:41316 - "POST /api/v1/offers HTTP/1.1" 503 Service Unavailable
❌ gRPC error validating items: <_InactiveRpcError of RPC that terminated with:
        status = StatusCode.UNAVAILABLE
        details = "failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)"
        debug_error_string = "UNKNOWN:Error received from peer  {grpc_message:"failed to connect to all addresses; last error: UNKNOWN: ipv4:34.118.232.234:50051: Failed to connect to remote host: connect: Connection refused (111)", grpc_status:14}"
>
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
INFO:     10.29.0.65:56224 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.35:41316 - "POST /api/v1/offers HTTP/1.1" 503 Service Unavailable
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
INFO:     10.29.0.35:41316 - "POST /api/v1/offers HTTP/1.1" 503 Service Unavailable
INFO:     10.29.0.65:41606 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:41618 - "GET /health HTTP/1.1" 200 OK
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
INFO:     10.29.0.35:41316 - "POST /api/v1/offers HTTP/1.1" 503 Service Unavailable
INFO:     10.29.0.65:41628 - "GET /health HTTP/1.1" 200 OK
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
INFO:     10.29.0.35:41316 - "POST /api/v1/offers HTTP/1.1" 503 Service Unavailable
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
⚠️ Circuit breaker is OPEN - Catalog service is unavailable
INFO:     10.29.0.35:41316 - "POST /api/v1/offers HTTP/1.1" 503 Service Unavailable
INFO:     10.29.0.65:37536 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:37546 - "GET /health HTTP/1.1" 200 OK
INFO:     10.29.0.65:37562 - "GET /health HTTP/1.1" 200 OK

# 4. Restore catalog service
kubectl scale deployment catalog-service -n swappo --replicas=1

# 5. Wait 60s for circuit to half-open, then test recovery
Start-Sleep -Seconds 65
Write-Host "`nCircuit should be half-open now, testing recovery..."
Invoke-RestMethod -Uri "http://34.40.17.122.nip.io/matchmaking/api/v1/offers" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Invoke-RestMethod -Uri "http://34.40.17.122.nip.io/matchmaking/api/v1/offers" `
>>     -Method POST `
>>     -ContentType "application/json" `
>>     -Body $body
Invoke-RestMethod : {"detail":"Proposer does not own offered items: [1]"}
At line:1 char:1
+ Invoke-RestMethod -Uri "http://34.40.17.122.nip.io/matchmaking/api/v1 ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-  
   RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeRes  
   tMethodCommand

### Test Retry Logic

**Simpler test - Temporarily stop and start catalog service:**
```powershell
# 1. Scale down catalog briefly (simulates transient failure)
kubectl scale deployment catalog-service -n swappo --replicas=0

# 2. Immediately make request (will retry while service is down)
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 3
    kubectl scale deployment catalog-service -n swappo --replicas=1
}

# 3. Make request - should retry for ~7s (1s + 2s + 4s) then succeed when service comes back
$body = @{
    proposer_id = "user1"
    receiver_id = "user2"
    offered_item_ids = @(1)
    requested_item_ids = @(2)
    message = "Test retry"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://34.40.17.122.nip.io/matchmaking/api/v1/offers" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body

✅ Testing Complete!

You've successfully verified both resilience patterns:

Retry Pattern: Saw 3 retry attempts with exponential backoff (multiple "gRPC error validating items" in logs)
Circuit Breaker: Saw circuit open after 5 failures ("⚠️ Circuit breaker is OPEN") with fast-fail behavior
Your resilience implementation is working perfectly! The services now handle failures gracefully with automatic retries and circuit breakers preventing cascading failures.

# Expected: Request succeeds after retries as catalog service comes back online
# Watch logs to see retry attempts:
# kubectl logs -n swappo -l app=matchmaking-service --tail=50 -f

>> } | ConvertTo-Json
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Invoke-RestMethod -Uri "http://34.40.17.122.nip.io/matchmaking/api/v1/offers" `
>>     -Method POST `
>>     -ContentType "application/json" `
>>     -Body $body
Invoke-RestMethod : {"detail":"Catalog service unavailable"}
At line:1 char:1
+ Invoke-RestMethod -Uri "http://34.40.17.122.nip.io/matchmaking/api/v1 ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-  
   RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeRes  
   tMethodCommand
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> kubectl logs -n swappo -l app=matchmaking-service --tail=30 | Select-String -Pattern "gRPC error validating|retry"
Defaulted container "matchmaking-service" out of: matchmaking-service, cloud-sql-proxy

Γ¥î gRPC error validating items: <_InactiveRpcError of RPC that terminated with:
Γ¥î gRPC error validating items: <_InactiveRpcError of RPC that terminated with:


PS C:\Users\turkf\Pictures\mag2\RSO\Swappo>
```

**Alternative - Network delay test (requires tc tool in container):**
```bash
# Note: This may not work if tc is not installed in the pod
# Get pod name
POD=$(kubectl get pods -n swappo -l app=catalog-service -o jsonpath='{.items[0].metadata.name}')

# Introduce network delay (6 second delay will cause timeouts)
kubectl exec -n swappo $POD -c catalog-service -- tc qdisc add dev eth0 root netem delay 6000ms

# Make request (should retry and eventually timeout)
curl http://34.40.17.122.nip.io/matchmaking/api/v1/offers

# Remove delay
kubectl exec -n swappo $POD -c catalog-service -- tc qdisc del dev eth0 root
```

## Best Practices

### 1. Set Appropriate Timeouts
```python
async with httpx.AsyncClient(timeout=5.0) as client:
    # Don't use default infinite timeout
```

### 2. Differentiate Errors
```python
# Don't retry on client errors (4xx)
retry=retry_if_exception_type((httpx.RequestError, httpx.HTTPStatusError))

# But handle in except block
except httpx.HTTPStatusError as e:
    if e.response.status_code < 500:
        # Client error, don't retry
        raise
```

### 3. Set Realistic Retry Limits
```python
stop=stop_after_attempt(3)  # Good for API calls
stop=stop_after_attempt(10)  # Too many, wastes time
```

### 4. Use Exponential Backoff
```python
wait=wait_exponential(multiplier=1, min=1, max=10)
# NOT: wait=wait_fixed(1)  # Can overwhelm recovering service
```

### 5. Non-Critical Operations
```python
@retry(..., reraise=False)  # Don't fail parent operation
```

## Configuration Tuning

### Aggressive (Low Latency, Less Resilient)
```python
Circuit Breaker: fail_max=3, timeout_duration=30
Retry: stop_after_attempt(2), max=5
```

### Balanced (Default)
```python
Circuit Breaker: fail_max=5, timeout_duration=60
Retry: stop_after_attempt(3), max=10
```

### Conservative (High Resilience, Higher Latency)
```python
Circuit Breaker: fail_max=10, timeout_duration=120
Retry: stop_after_attempt(5), max=30
```

## Troubleshooting

### Circuit Breaker Stuck Open
**Symptoms:** All requests fail with `CircuitBreakerError`

**Solutions:**
1. Check if downstream service recovered: `kubectl get pods -n swappo`
2. Wait for timeout_duration (60s) to allow half-open state
3. Manually close circuit (restart pod): `kubectl rollout restart deployment/<service>`

### Excessive Retries
**Symptoms:** High latency, timeout errors

**Solutions:**
1. Reduce retry attempts: `stop_after_attempt(2)`
2. Reduce max wait time: `max=5`
3. Check if downstream service is consistently failing
4. Enable circuit breaker to fail fast

### Notifications Not Sent
**Symptoms:** No notifications received, no errors in logs

**Solutions:**
1. Check notification service logs: `kubectl logs -n swappo <notifications-pod>`
2. Verify circuit breaker state: Check health endpoint
3. Check retry logs: Look for "Failed to send notification" messages

## Future Enhancements

1. **Add Bulkhead Pattern** - Limit concurrent requests to prevent resource exhaustion
2. **Add Rate Limiting** - Protect services from being overwhelmed
3. **Add Fallback Responses** - Return cached/default data when service unavailable
4. **Add Metrics** - Track circuit breaker state changes, retry counts
5. **Add Distributed Tracing** - Visualize retry/circuit breaker behavior
6. **Add Adaptive Timeout** - Adjust timeouts based on historical latency

## References

- [tenacity Documentation](https://tenacity.readthedocs.io/)
- [pybreaker Documentation](https://github.com/danielfm/pybreaker)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Retry Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/retry)
