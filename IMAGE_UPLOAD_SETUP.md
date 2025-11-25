# Image Upload Setup Guide

## Overview
The catalog service now supports actual image file uploads (PNG, JPEG, GIF, WebP) instead of just image URLs.

## Backend Changes

### New Features
- **Image Upload Endpoint**: `POST /upload-image`
  - Accepts multipart/form-data with image files
  - Validates file type and size (max 10MB)
  - Stores images in `/uploads` directory
  - Returns relative URL for the uploaded image

### Storage
- Images are stored in the `uploads/` directory
- Files are named with UUIDs to prevent conflicts
- Images are served as static files at `/uploads/{filename}`
- Persistent storage via Docker volume `catalog_uploads`

## Frontend Changes

### New Dependencies
Install the image picker package:
```bash
cd Swappo-FE
npx expo install expo-image-picker
```

### New Screen: UploadItemScreen
- Image picker integration with multi-select (up to 5 images)
- Image preview before upload
- Form validation
- Progress indication during upload

### Modified Components
- **ExploreScreen**: Now navigates to UploadItemScreen instead of modal
- **CatalogService**: Added `uploadImage()` method for file uploads

## Setup Instructions

### 1. Install Frontend Dependencies
```powershell
cd Swappo-FE
npx expo install expo-image-picker
```

### 2. Rebuild Backend Service
```powershell
cd ..
docker-compose up -d --build catalog_service
```

### 3. Update Navigation (App.tsx or Router)
Add the UploadItemScreen to your navigation stack:
```typescript
import { UploadItemScreen } from './screens/UploadItemScreen';

// In your navigator
<Stack.Screen name="UploadItem" component={UploadItemScreen} />
```

### 4. Permissions (Mobile)
The app will automatically request camera roll permissions when users try to upload images.

## Usage

### Uploading Images
1. Navigate to Explore screen
2. Tap "Upload New Item"
3. Tap the image picker area
4. Select up to 5 images
5. Fill in item details
6. Tap "Upload Item"

### API Example
```bash
# Upload an image
curl -X POST http://localhost:8001/upload-image \
  -F "file=@path/to/image.jpg"

# Response
{
  "image_url": "/uploads/123e4567-e89b-12d3-a456-426614174000.jpg"
}
```

## File Structure
```
Swappo-Catalog/
├── uploads/              # Uploaded images (gitignored)
│   └── *.jpg/png/...
├── main.py              # Added upload endpoint
└── requirements.txt     # Added Pillow

Swappo-FE/
├── screens/
│   ├── UploadItemScreen.tsx   # NEW: Image upload UI
│   └── ExploreScreen.tsx      # Modified: Navigation
└── services/
    └── catalog.service.ts     # Added uploadImage()
```

## Production Considerations

### For Production Deployment:
1. **Cloud Storage**: Replace local file storage with cloud storage (S3, Azure Blob, etc.)
2. **CDN**: Use a CDN for serving images
3. **Image Optimization**: Add automatic resizing/compression
4. **Moderation**: Implement image content moderation
5. **Rate Limiting**: Add upload rate limits
6. **Authentication**: Verify user auth on upload endpoint

### Example Cloud Storage Integration (Azure Blob):
```python
from azure.storage.blob import BlobServiceClient

async def upload_to_azure(file_content, filename):
    blob_service = BlobServiceClient.from_connection_string(conn_str)
    blob_client = blob_service.get_blob_client(container="images", blob=filename)
    blob_client.upload_blob(file_content)
    return blob_client.url
```

## Troubleshooting

### Images not appearing?
- Check that catalog service is running: `docker ps`
- Verify uploads directory exists: `docker exec swappo_catalog_service ls -la uploads`
- Check image URLs use correct base URL

### Upload failing?
- Verify file size < 10MB
- Check file type is PNG/JPEG/GIF/WebP
- Look at container logs: `docker logs swappo_catalog_service`

### Permissions error on mobile?
- Go to device Settings → App → Swappo → Permissions
- Enable "Photos" or "Media" permission

## Testing

### Manual Testing
1. Start services: `docker-compose up -d`
2. Start frontend: `cd Swappo-FE && npm start`
3. Navigate to Explore → Upload New Item
4. Select images and create item
5. Verify image appears in feed

### API Testing
```bash
# Test image upload
curl -X POST http://localhost:8001/upload-image \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@test-image.jpg"

# View uploaded image
# Open: http://localhost:8001/uploads/{returned-filename}
```

## Notes
- Images persist in Docker volume even after container restart
- Guest users can upload items (uses guest-user-dev ID)
- Images are validated before saving (PIL.Image.verify)
- Unique filenames prevent overwrites
