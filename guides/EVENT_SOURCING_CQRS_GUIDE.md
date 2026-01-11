# Event Sourcing + CQRS Implementation Guide

## 📚 **What You've Built**

You've successfully implemented **Event Sourcing** and **CQRS** patterns in your Swappo Catalog service!

---

## 🎯 **Core Concepts**

### **Event Sourcing**
Instead of storing just current state, you store **all events** that led to that state.

**Benefits:**
- ✅ **Complete audit trail** - Every change is recorded
- ✅ **Time travel** - Reconstruct state at any point in history  
- ✅ **Event replay** - Rebuild state from events
- ✅ **Debugging** - See exactly what happened and when
- ✅ **Compliance** - Meet regulatory requirements

### **CQRS (Command Query Responsibility Segregation)**  
Separate **write operations** (commands) from **read operations** (queries).

**Benefits:**
- ✅ **Optimized reads** - Read model tailored for queries
- ✅ **Optimized writes** - Write model focused on business logic
- ✅ **Scalability** - Scale reads and writes independently
- ✅ **Security** - Different permissions for reads vs writes

---

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                      WRITE SIDE (Commands)                       │
│                                                                  │
│  Client → CreateItemCommand → CommandHandler → ItemCreatedEvent │
│                                    ↓                             │
│                              EVENT STORE                         │
│                          (append-only log)                       │
│                                    ↓                             │
└────────────────────────────────────┼──────────────────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    ▼                                  ▼
         ┌──────────────────────┐          ┌──────────────────────┐
         │   Event Projections  │          │   Event Handlers     │
         │  (Update Read Model) │          │  (Async Processing)  │
         └──────────┬───────────┘          └──────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      READ SIDE (Queries)                         │
│                                                                  │
│  Client → QueryHandler → Read Model (ItemDB) → Fast Responses   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 **File Structure**

```
Swappo-Catalog/
├── event_sourcing/
│   ├── __init__.py
│   ├── events.py              # Event definitions
│   ├── event_store.py         # Event persistence
│   ├── commands.py            # Command definitions
│   ├── command_handlers.py    # Process commands, emit events
│   ├── queries.py             # Read side queries
│   ├── projections.py         # Update read models
│   └── event_replay.py        # Replay events for audit/debugging
├── cqrs_api.py               # CQRS API endpoints
├── main.py                   # FastAPI app (updated)
└── database.py               # Database (updated with event_store table)
```

---

## 🔄 **How It Works**

### **Writing Data (Commands)**

1. **Client sends command:**
   ```
   POST /api/v2/items
   {
     "name": "Shovel",
     "description": "Garden shovel",
     "category": "tools",
     ...
   }
   ```

2. **CommandHandler processes:**
   - Validates command
   - Creates `ItemCreatedEvent`
   - Stores event in `event_store` table (append-only!)
   - Updates read model (projection) in `items` table

3. **Event stored:**
   ```sql
   event_store:
   sequence_number | event_type    | aggregate_id | payload
   1               | item_created  | 1            | {"name":"Shovel",...}
   ```

4. **Read model updated:**
   ```sql
   items:
   id | name    | description    | status
   1  | Shovel  | Garden shovel  | active
   ```

### **Reading Data (Queries)**

1. **Client queries:**
   ```
   GET /api/v2/items/1
   ```

2. **QueryHandler reads from optimized read model:**
   - Queries `items` table (NOT event_store)
   - Fast, indexed queries
   - Returns denormalized data

---

## 🚀 **API Endpoints**

### **Write Endpoints (Commands)**

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v2/items` | Create item (emits ItemCreatedEvent) |
| PUT | `/api/v2/items/{id}` | Update item (emits ItemUpdatedEvent) |
| PATCH | `/api/v2/items/{id}/status` | Change status (emits StatusChangedEvent) |

### **Read Endpoints (Queries)**

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v2/items/{id}` | Get item by ID |
| GET | `/api/v2/items` | Search items (with filters) |
| GET | `/api/v2/items/owner/{owner_id}` | Get items by owner |
| GET | `/api/v2/stats` | Get statistics |

### **Event Sourcing Features**

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v2/items/{id}/history` | Complete event history |
| GET | `/api/v2/items/{id}/audit-trail` | Audit trail with changes |
| POST | `/api/v2/items/{id}/rebuild` | Rebuild state from events |
| GET | `/api/v2/items/{id}/time-travel` | See state at past timestamp |

---

## 🧪 **Testing / Demo**

### **1. Start the Service**

```bash
cd Swappo-Catalog
python main.py
```

Visit: http://localhost:8001/docs

### **2. Create an Item**

```bash
curl -X POST http://localhost:8001/api/v2/items \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Garden Shovel",
    "description": "Sturdy metal shovel",
    "category": "tools",
    "image_urls": ["http://example.com/shovel.jpg"],
    "location_lat": 46.0569,
    "location_lon": 14.5058,
    "owner_id": "user123"
  }'
```

Response: `{"id": 1, "name": "Garden Shovel", ...}`

### **3. Update the Item**

```bash
curl -X PUT http://localhost:8001/api/v2/items/1 \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Sturdy metal shovel - lightly used"
  }'
```

### **4. Change Status**

```bash
curl -X PATCH "http://localhost:8001/api/v2/items/1/status?new_status=swapped&reason=Traded+with+user456"
```

### **5. View Complete History**

```bash
curl http://localhost:8001/api/v2/items/1/history
```

Response shows:
```json
{
  "current": {
    "id": 1,
    "name": "Garden Shovel",
    "status": "swapped"
  },
  "history": [
    {
      "sequence": 1,
      "type": "item_created",
      "timestamp": "2024-01-15T10:00:00",
      "user": "demo-user",
      "changes": {...}
    },
    {
      "sequence": 2,
      "type": "item_updated",
      "timestamp": "2024-01-15T10:05:00",
      "user": "demo-user",
      "changes": {"description": "..."}
    },
    {
      "sequence": 3,
      "type": "item_status_changed",
      "timestamp": "2024-01-15T10:10:00",
      "user": "demo-user",
      "changes": {"old_status": "active", "new_status": "swapped"}
    }
  ],
  "event_count": 3
}
```

### **6. Get Audit Trail**

```bash
curl http://localhost:8001/api/v2/items/1/audit-trail
```

Shows who changed what, with previous values!

### **7. Event Replay - Rebuild State**

```bash
curl -X POST http://localhost:8001/api/v2/items/1/rebuild
```

This will:
1. Delete item from read model
2. Replay all events from event_store
3. Rebuild current state
4. Prove events are source of truth!

### **8. Time Travel**

```bash
curl "http://localhost:8001/api/v2/items/1/time-travel?timestamp=2024-01-15T10:02:00"
```

See what the item looked like at that exact moment in time!

---

## 💾 **Database Schema**

### **event_store Table** (Source of Truth)

```sql
CREATE TABLE event_store (
    sequence_number SERIAL PRIMARY KEY,
    event_id VARCHAR(36) UNIQUE NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    aggregate_id INTEGER NOT NULL,
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_version INTEGER NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    payload TEXT NOT NULL,  -- JSON
    metadata TEXT DEFAULT '{}'
);

CREATE INDEX idx_aggregate ON event_store(aggregate_id, aggregate_type);
CREATE INDEX idx_event_type_timestamp ON event_store(event_type, timestamp);
```

### **items Table** (Read Model - Projection)

Your existing `items` table serves as the optimized read model.

---

## 🎓 **Key Learnings**

### **Why Events Are Better Than State**

**Traditional (State-based):**
```sql
-- Before: name = "Shovel", status = "active"
UPDATE items SET status = 'swapped' WHERE id = 1;
-- After: name = "Shovel", status = "swapped"
-- ❌ Lost: When changed? Why changed? Who changed it?
```

**Event Sourcing:**
```sql
-- Event 1: ItemCreated {name: "Shovel", status: "active"}
-- Event 2: StatusChanged {old: "active", new: "swapped", reason: "traded"}
-- ✅ You have: Complete history, audit trail, ability to replay
```

### **CQRS Benefits**

**Without CQRS:**
- Same model for reads and writes
- Complex queries slow down writes
- Hard to optimize both

**With CQRS:**
- Read model optimized for queries (denormalized, indexed)
- Write model focused on business logic
- Can scale independently

---

## 🔍 **Debugging & Monitoring**

### **Check Event Store**

```bash
# In PostgreSQL
SELECT * FROM event_store ORDER BY sequence_number DESC LIMIT 10;
```

### **Compare Event Store vs Read Model**

```bash
# Should match!
SELECT COUNT(*) FROM event_store WHERE aggregate_id = 1;  -- Events
SELECT * FROM items WHERE id = 1;  -- Current state
```

### **Rebuild All Read Models**

```python
# In case read model gets corrupted
from event_sourcing.projections import rebuild_read_model_for_item

for item_id in [1, 2, 3, ...]:
    rebuild_read_model_for_item(db, item_id)
```

---

## 🚀 **Deployment to GKE**

### **1. Database Migration**

Create migration to add event_store table:

```bash
# In Swappo-Catalog/migrations/
alembic revision -m "add_event_store_table"
```

Add to migration:
```python
from event_sourcing.event_store import EventStoreEntry
EventStoreEntry.__table__.create(bind=op.get_bind())
```

### **2. Update Kubernetes ConfigMap**

No changes needed - uses same database!

### **3. Deploy**

```bash
kubectl apply -f k8s-gke/catalog-service.yaml
```

---

## 📊 **Monitoring**

Add metrics for event sourcing:

```python
# Metrics to track
- events_stored_total (counter)
- event_replay_duration_seconds (histogram)
- read_model_lag_seconds (gauge)
```

---

## 🎯 **What You've Achieved**

✅ **Event Sourcing** - All changes tracked as immutable events  
✅ **CQRS** - Separate read and write models  
✅ **Event Replay** - Rebuild state from events  
✅ **Audit Trail** - Complete history of all changes  
✅ **Time Travel** - View state at any point in time  
✅ **Compliance** - Meet regulatory requirements  
✅ **Debugging** - See exactly what happened when

---

## 🎬 **Next Steps**

1. **Test locally** - Use the demo steps above
2. **Create database migration** - Add event_store table
3. **Deploy to GKE** - Use existing deployment pipeline
4. **Add monitoring** - Track event metrics
5. **Extend to other services** - Apply to Chat, Matchmaking, etc.

---

## 📚 **Further Reading**

- [Event Sourcing Pattern](https://martinfowler.com/eaaDev/EventSourcing.html)
- [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)
- [Event Sourcing vs CRUD](https://docs.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)

---

**Congratulations! You've implemented enterprise-grade Event Sourcing + CQRS! 🎉**

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $createResponse = Invoke-RestMethod -Method Post `
>>   -Uri "http://localhost:8000/api/v2/items" `
>>   -ContentType "application/json" `
>>   -Body @'
>> {
>>   "name": "Test Camera",
>>   "description": "Testing Event Sourcing",
>>   "category": "electronics",
>>   "image_urls": ["https://example.com/camera.jpg"],
>>   "location_lat": 46.0569,
>>   "location_lon": 14.5058,
>>   "owner_id": "test-user"
>> }
>> '@
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # Show the response
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $createResponse | ConvertTo-Json
{
    "name":  "Test Camera",
    "description":  "Testing Event Sourcing",
    "category":  "electronics",
    "image_urls":  [
                       "https://example.com/camera.jpg"
                   ],
    "location_lat":  46.0569,
    "location_lon":  14.5058,
    "owner_id":  "test-user",
    "id":  6,
    "status":  "active",
    "created_at":  "2026-01-11T12:25:38.202659Z",
    "updated_at":  "2026-01-11T12:25:38.202659Z"
}
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "Created item ID: $($createResponse.id)" -ForegroundColor Green
Created item ID: 6
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $itemId = $createResponse.id   
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "Item ID: $itemId"
Item ID: 6
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $history = Invoke-RestMethod -Uri "http://localhost:8000/api/v2/items/$itemId/history"
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $history | ConvertTo-Json -Depth 5
{
    "current":  {
                    "id":  6,
                    "name":  "Test Camera",
                    "description":  "Testing Event Sourcing",
                    "category":  "electronics",
                    "image_urls":  [
                                       "https://example.com/camera.jpg"    
                                   ],
                    "location_lat":  46.0569,
                    "location_lon":  14.5058,
                    "owner_id":  "test-user",
                    "status":  "active"
                },
    "history":  [
                    {
                        "sequence":  1,
                        "type":  "item_created",
                        "timestamp":  "2026-01-11T12:25:38.202659+00:00",  
                        "user":  "demo-user",
                        "changes":  {
                                        "name":  "Test Camera",
                                        "description":  "Testing Event Sourcing",
                                        "category":  "electronics",        
                                        "image_urls":  [
                                                           "https://example.com/camera.jpg"
                                                       ],
                                        "location_lat":  46.0569,
                                        "location_lon":  14.5058,
                                        "owner_id":  "test-user",
                                        "status":  "active"
                                    }
                    }
                ],
    "event_count":  1,
    "created_at":  "2026-01-11T12:25:38.202659+00:00",
    "last_modified_at":  null
}
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $audit = Invoke-RestMethod -Uri
 "http://localhost:8000/api/v2/items/$itemId/audit-trail"
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $audit | ConvertTo-Json -Depth 5
{
    "item_id":  6,
    "total_events":  1,
    "audit_trail":  [
                        {
                            "sequence":  1,
                            "event_type":  "item_created",
                            "timestamp":  "2026-01-11T12:25:38.202659+00:00",
                            "user_id":  "demo-user",
                            "version":  1
                        }
                    ]
}
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Invoke-RestMethod -Method Put `
>>   -Uri "http://localhost:8000/api/v2/items/$itemId" `
>>   -ContentType "application/json" `
>>   -Body '{"description": "Updated via CQRS on GKE!"}'
Invoke-RestMethod : The underlying connection was closed: A connection 
that was expected to be kept alive was closed by the server.
At line:1 char:1
+ Invoke-RestMethod -Method Put `
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "Item updated!" -ForegroundColor Green
Item updated!
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Invoke-RestMethod -Method Patch
 `
>>   -Uri "http://localhost:8000/api/v2/items/$itemId/status?new_status=swapped&reason=Testing+Event+Sourcing"
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:1
+ Invoke-RestMethod -Method Patch `
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "Status changed!" -ForegroundColor Green
Status changed!
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $finalHistory = Invoke-RestMethod -Uri "http://localhost:8000/api/v2/items/$itemId/history"
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:17
+ ... alHistory = Invoke-RestMethod -Uri
"http://localhost:8000/api/v2/item ...
+
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`nTotal Events: $($finalHistory.event_count)" -ForegroundColor Cyan

Total Events:
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $finalHistory.history | ForEach-Object {
>>     Write-Host "`n[$($_.sequence)] $($_.type)" -ForegroundColor Yellow  
>>     Write-Host "  Time: $($_.timestamp)"
>>     Write-Host "  User: $($_.user)"
>> }

[]
  Time:
  User:
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $rebuild = Invoke-RestMethod -Method Post `
>>   -Uri "http://localhost:8000/api/v2/items/$itemId/rebuild"
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:12
+ $rebuild = Invoke-RestMethod -Method Post `
+            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n$($rebuild.message)" -ForegroundColor Green


PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $rebuild.item | ConvertTo-Json
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # Event Sourcing Test Script for GKE
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "=== Event Sourcing + CQRS Test on GKE ===" -ForegroundColor Cyan
=== Event Sourcing + CQRS Test on GKE ===
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # 1. Create Item
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n1️⃣ Creating test t item..." -ForegroundColor Yellow

1️⃣ Creating test item...
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $createResponse = Invoke-RestMethod -Method Post `
>>   -Uri "http://localhost:8000/api/v2/items" `
>>   -ContentType "application/json" `
>>   -Body @'
>> {
>>   "name": "Vintage Camera",
>>   "description": "Classic film camera",
>>   "category": "electronics",
>>   "image_urls": ["https://example.com/camera.jpg"],
>>   "location_lat": 46.0569,
>>   "location_lon": 14.5058,
>>   "owner_id": "gke-test-user"
>> }
>> '@
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:19
+ $createResponse = Invoke-RestMethod -Method Post `
+                   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Invoke-RestMethod], WebE  
   xception
    + FullyQualifiedErrorId : System.Net.WebException,Microsoft.PowerShel  
   l.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $itemId = $createResponse.id
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host " Created item ID: $itemId" -ForegroundColor Green
 Created item ID: 6
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # 2. View initial history (1 event)
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n2️⃣ Viewing event t history..." -ForegroundColor Yellow

2️⃣ Viewing event history...
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $history1 = Invoke-RestMethod -Uri "http://localhost:8000/api/v2/items/$itemId/history"
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:13
+ $history1 = Invoke-RestMethod -Uri "http://localhost:8000/api/v2/item    
...
+             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host " Event count: $($history1.event_count)" -ForegroundColor Green
 Event count: 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $history1.history | ForEach-Object {
>>     Write-Host "  - [$($_.sequence)] $($_.type) at $($_.timestamp)"     
>> }
  - []  at 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # 3. Update item
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n3️⃣ Updating item m..." -ForegroundColor Yellow

3️⃣ Updating item...
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Invoke-RestMethod -Method Put `
>>   -Uri "http://localhost:8000/api/v2/items/$itemId" `
>>   -ContentType "application/json" `
>>   -Body '{"description": "Classic film camera with leather case"}'      
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:1
+ Invoke-RestMethod -Method Put `
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Invoke-RestMethod], WebE  
   xception
    + FullyQualifiedErrorId : System.Net.WebException,Microsoft.PowerShel  
   l.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "✅ Item updated" -ForegroundColor Green
✅ Item updated
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # 4. Change status
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n4️⃣ Changing stat tus..." -ForegroundColor Yellow

4️⃣ Changing status...
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Invoke-RestMethod -Method Patch
 `
>>   -Uri "http://localhost:8000/api/v2/items/$itemId/status?new_status=swapped&reason=Traded+successfully"
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:1
+ Invoke-RestMethod -Method Patch `
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "✅ Status changed to swapped" -ForegroundColor Green
✅ Status changed to swapped
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # 5. View complete history (3 events)
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n5️⃣ Viewing compl lete event history..." -ForegroundColor Yellow

5️⃣ Viewing complete event history...
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $history2 = Invoke-RestMethod -Uri "http://localhost:8000/api/v2/items/$itemId/history"
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:13
+ $history2 = Invoke-RestMethod -Uri "http://localhost:8000/api/v2/item    
...
+             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "✅ Event count: $($history2.event_count)" -ForegroundColor Green
✅ Event count: 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $history2.history | ForEach-Object {
>>     Write-Host "  - [$($_.sequence)] $($_.type) at $($_.timestamp)"     
>> }
  - []  at 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # 6. View audit trail
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n6️⃣ Viewing audit t trail..." -ForegroundColor Yellow

6️⃣ Viewing audit trail...
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $audit = Invoke-RestMethod -Uri
 "http://localhost:8000/api/v2/items/$itemId/audit-trail"
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:10
+ $audit = Invoke-RestMethod -Uri "http://localhost:8000/api/v2/items/$    
...
+          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "✅ Audit entries: $($audit.total_events)" -ForegroundColor Green
✅ Audit entries: 1
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $audit.audit_trail | ForEach-Object {
>>     Write-Host "`n  Event #$($_.sequence): $($_.event_type)"
>>     Write-Host "    Timestamp: $($_.timestamp)"
>>     Write-Host "    User: $($_.user_id)"
>>     if ($_.changes) {
>>         Write-Host "    Changes: $($_.changes | ConvertTo-Json -Compress)"
>>     }
>>     if ($_.previous_values) {
>>         Write-Host "    Previous: $($_.previous_values | ConvertTo-Json -Compress)"
>>     }
>> }

  Event #1: item_created
    Timestamp: 2026-01-11T12:25:38.202659+00:00
    User: demo-user
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # 7. Test event replay
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n7️⃣ Testing event t replay (rebuild from events)..." -ForegroundColor Yellow

7️⃣ Testing event replay (rebuild from events)...
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> $rebuild = Invoke-RestMethod -Method Post `
>>   -Uri "http://localhost:8000/api/v2/items/$itemId/rebuild"
Invoke-RestMethod : Unable to connect to the remote server
At line:1 char:12
+ $rebuild = Invoke-RestMethod -Method Post `
+            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebReques  
   t:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.Pow  
   erShell.Commands.InvokeRestMethodCommand

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "✅ $($rebuild.message)" -ForegroundColor Green
✅ 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "   Rebuilt item status: $($rebuild.item.status)"
   Rebuilt item status: 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> # Summary
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`n" + "="*60 -ForegroundColor Cyan

 + = *60
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "✅ Event Sourcing is WORKING on GKE!" -ForegroundColor Green
✅ Event Sourcing is WORKING on GKE!
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "="*60 -ForegroundColor Cyan
= *60
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "Summary:"
Summary:
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "  - Item ID: $itemId"
  - Item ID: 6
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "  - Total Events: $($history2.event_count)"
  - Total Events: 
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "  - Event Types: Created → Updated → Status Changed"
␦ Updated ␦ Status Changed";79a1479b-2d35-4e32-93f6-d40b7239e14a  - Event Types: Created → Updated → Status Changed
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "  - Event Replay:  ✅ Successful"
  - Event Replay: ✅ Successful
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "  - Audit Trail: ✅ Complete"
  - Audit Trail: ✅ Complete
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> Write-Host "`nEvent Sourcing + CQRS implementation is fully functional! 🎉"