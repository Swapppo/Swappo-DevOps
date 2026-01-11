#!/bin/sh
# Test sending logs directly to Loki

curl -X POST http://loki:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [
      {
        "stream": {
          "namespace": "swappo",
          "app": "test",
          "pod": "manual-test"
        },
        "values": [
          ["'$(date +%s000000000)'", "=== MANUAL TEST LOG FROM CATALOG SERVICE ==="],
          ["'$(date +%s000000000)'", "This is a test to verify Loki is working"],
          ["'$(date +%s000000000)'", "ERROR: Test error message for testing"]
        ]
      }
    ]
  }'
