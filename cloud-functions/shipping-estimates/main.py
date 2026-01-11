"""
Google Cloud Function for Shipping Estimates
Calculates shipping costs based on weight, distance, and carrier
"""

import os
import json
from flask import jsonify
import functions_framework


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
    
    # Health check endpoint
    if request.method == 'GET':
        return (jsonify({
            'status': 'healthy',
            'service': 'shipping-estimates',
            'version': '1.0.0',
            'message': 'Cloud Function is running. Send POST with shipping details.'
        }), 200, headers)
    
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
        to_city = request_json.get('to_city', 'Unknown')
        to_postal_code = request_json.get('to_postal_code', '')
        to_state = request_json.get('to_state', '')
        weight_kg = float(request_json.get('weight_kg', 1.0))
        
        print(f"📦 Calculating shipping: {from_country} → {to_country}, {weight_kg}kg")
        
        # Calculate shipping cost based on realistic pricing
        base_cost = 8.0
        weight_cost = weight_kg * 6.50
        
        # Regional pricing
        eu_countries = ['SI', 'HR', 'AT', 'IT', 'DE', 'FR', 'ES', 'NL', 'BE', 'PL', 'CZ', 'SK']
        
        if from_country == to_country:
            # Domestic shipping
            zone_cost = 0.0
            courier = 'National Post'
            delivery_days = '2-3 days'
        elif from_country in eu_countries and to_country in eu_countries:
            # EU shipping
            zone_cost = 12.0
            courier = 'DHL Express EU'
            delivery_days = '3-5 days'
        elif to_country == 'US' or from_country == 'US':
            # US international
            zone_cost = 25.0
            courier = 'FedEx International'
            delivery_days = '5-7 days'
        else:
            # Other international
            zone_cost = 30.0
            courier = 'UPS Worldwide'
            delivery_days = '7-10 days'
        
        total_cost = round(base_cost + weight_cost + zone_cost, 2)
        
        result = {
            'success': True,
            'estimate': {
                'cost': total_cost,
                'currency': 'USD',
                'courier': courier,
                'delivery_days': delivery_days
            },
            'details': {
                'from_country': from_country,
                'to_country': to_country,
                'to_city': to_city,
                'postal_code': to_postal_code,
                'weight_kg': weight_kg,
                'breakdown': {
                    'base_cost': base_cost,
                    'weight_cost': round(weight_cost, 2),
                    'zone_cost': zone_cost
                }
            }
        }
        
        print(f"✅ Estimate: ${total_cost} via {courier} ({delivery_days})")
        
        return (jsonify(result), 200, headers)
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return (jsonify({
            'success': False,
            'error': str(e)
        }), 500, headers)
