# Shipping Estimates Cloud Function

Google Cloud Function that provides shipping cost estimates via Easyship API.

## Purpose

- **Security**: Keeps Easyship API token server-side
- **Rate Limiting**: Can add caching and rate limiting in the future
- **Cost Control**: Centralized place to manage shipping API calls

## Deployment

```powershellcd cloud-functions/shipping-estimates
.\deploy.ps1

```

This will deploy to your GCP project (`swapppo`) in `europe-west3` region.

## API

**Endpoint**: `POST https://europe-west3-swapppo.cloudfunctions.net/shipping-estimates`

**Request Body**:
```json
{
  "from_country": "US",
  "to_country": "US",
  "to_city": "New York",
  "to_postal_code": "10001",
  "to_state": "NY",
  "weight_kg": 1.0
}
```

**Response**:
```json
{
  "success": true,
  "estimate": {
    "cost": 15.50,
    "currency": "USD",
    "courier": "USPS"
  }
}
```

## Environment Variables

- `EASYSHIP_API_TOKEN`: Easyship API token (set during deployment)

## Deployed Function URL:
https://shipping-estimates-lgvrxvnupa-ey.a.run.app

## Add this URL to your frontend environment config:
EXPO_PUBLIC_SHIPPING_API_URL=https://shipping-estimates-lgvrxvnupa-ey.a.run.app 
