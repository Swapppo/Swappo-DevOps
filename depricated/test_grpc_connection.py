#!/usr/bin/env python3
"""
Test gRPC connectivity from Matchmaking to Catalog service
Run this inside a matchmaking pod to verify gRPC is working
"""

import sys
sys.path.insert(0, '/app')

from grpc_client import get_catalog_client

def test_grpc():
    print("🧪 Testing gRPC connection to Catalog service...")
    
    try:
        client = get_catalog_client()
        
        # Test 1: Validate items (most likely to work even with no data)
        print("\n1️⃣ Testing ValidateItems RPC...")
        result = client.validate_items([1, 2, 999])
        print(f"✅ ValidateItems returned {len(result)} validations")
        for v in result:
            print(f"   - Item {v['item_id']}: exists={v['exists']}, active={v['is_active']}")
        
        # Test 2: Try to get an item
        print("\n2️⃣ Testing GetItem RPC...")
        item = client.get_item(1)
        if item:
            print(f"✅ GetItem returned: {item['name']}")
        else:
            print("⚠️  Item 1 not found (database might be empty)")
        
        # Test 3: Batch get items
        print("\n3️⃣ Testing GetItems RPC...")
        result = client.get_items([1, 2, 3])
        print(f"✅ GetItems returned {len(result['items'])} items")
        print(f"   Not found IDs: {result['not_found_ids']}")
        
        print("\n✅ All gRPC tests passed! Connection is working.")
        return True
        
    except Exception as e:
        print(f"\n❌ gRPC test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_grpc()
    sys.exit(0 if success else 1)
    
"""
PS C:\Users\turkf\Pictures\mag2\RSO\Swappo> kubectl exec -n swappo matchmaking-service-56f4685797-947cc -c matchmaking-service -- python /tmp/test_grpc.py
🧪 Testing gRPC connection to Catalog service...

1️⃣ Testing ValidateItems RPC...
✅ Connected to Catalog gRPC service at catalog-service:50051
✅ ValidateItems returned 3 validations
   - Item 1: exists=True, active=True
   - Item 2: exists=True, active=True
   - Item 999: exists=False, active=False

2️⃣ Testing GetItem RPC...
✅ GetItem returned: asd

3️⃣ Testing GetItems RPC...
✅ GetItems returned 3 items
   Not found IDs: []

✅ All gRPC tests passed! Connection is working.
"""