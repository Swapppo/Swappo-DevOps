"""
Google Cloud Function for Easyship Shipping Estimates
Fetches shipping rates from Easyship API
"""

import os
import json
import requests
from flask import jsonify
import functions_framework

EASYSHIP_API_BASE = 'https://public-api-sandbox.easyship.com'
EASYSHIP_API_TOKEN = os.environ.get('EASYSHIP_API_TOKEN', 'sand_EpFMtejumXrSb5vfzWU1dL3b5RvXhSrujjurgRt/RAE=')


@functions_framework.http
def get_shipping_estimate(request):
    """
    HTTP Cloud Function to get shipping cost estimates
    
    Request JSON body:
    {
        "from_country": "US",  // Optional, defaults to "US"
        "to_country": "US",    // Required
        "to_city": "New York", // Optional
        "to_postal_code": "10001", // Optional
        "to_state": "NY",      // Optional
        "weight_kg": 1.0       // Optional, defaults to 1
    }
    
    Response:
    {
        "success": true,
        "estimate": {
            "cost": 15.50,
            "currency": "USD",
            "courier": "USPS"
        }
    }
    """
    
    # Enable CORS
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)
    
    headers = {
        'Access-Control-Allow-Origin': '*'
    }
    
    try:
        # Parse request
        request_json = request.get_json(silent=True)
        if not request_json:
            return (jsonify({
                'success': False,
                'error': 'Request body must be JSON'
            }), 400, headers)
        
        # Extract parameters
        from_country = request_json.get('from_country', 'US')
        to_country = request_json.get('to_country', 'US')
        to_city = request_json.get('to_city')
        to_postal_code = request_json.get('to_postal_code')
        to_state = request_json.get('to_state')
        weight_kg = float(request_json.get('weight_kg', 1.0))
        
        print(f"📦 Fetching shipping estimate: {from_country} → {to_country}, {weight_kg}kg")
        
        # Build Easyship API request
        easyship_request = {
            'origin_country_alpha2': from_country,
            'destination_country_alpha2': to_country,
            'taxes_duties_paid_by': 'Sender',
            'is_insured': False,
            'items': [{
                'actual_weight': weight_kg,
                'height': 10,
                'width': 10,
                'length': 10,
                'declared_currency': 'USD',
                'declared_customs_value': 50
            }]
        }
        
        if to_city:
            easyship_request['destination_city'] = to_city
        if to_postal_code:
            easyship_request['destination_postal_code'] = to_postal_code
        if to_state:
            easyship_request['destination_state'] = to_state
        
        # Call Easyship API
        response = requests.post(
            f'{EASYSHIP_API_BASE}/rates',
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {EASYSHIP_API_TOKEN}'
            },
            json=easyship_request,
            timeout=10
        )
        
        if not response.ok:
            print(f"❌ Easyship API error: {response.status_code} - {response.text}")
            return (jsonify({
                'success': False,
                'error': f'Easyship API error: {response.status_code}'
            }), 500, headers)
        
        data = response.json()
        rates = data.get('rates', [])
        
        if not rates:
            print("⚠️ No shipping rates available")
            return (jsonify({
                'success': False,
                'error': 'No shipping rates available'
            }), 404, headers)
        
        # Get cheapest rate
        cheapest = min(rates, key=lambda r: r['total_charge'])
        
        result = {
            'success': True,
            'estimate': {
                'cost': cheapest['total_charge'],
                'currency': cheapest['currency'],
                'courier': cheapest['courier_name']
            }
        }
        
        print(f"✅ Estimate: ${cheapest['total_charge']} via {cheapest['courier_name']}")
        
        return (jsonify(result), 200, headers)
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return (jsonify({
            'success': False,
            'error': str(e)
        }), 500, headers)
