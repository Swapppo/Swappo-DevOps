# Swappo - Microservices Setup

This repository contains the Swappo application with microservices architecture.

## Architecture

- **Auth Service**: Port 8000 - Handles user authentication and authorization
- **Catalog Service**: Port 8001 - Manages item listings and catalog
- **Matchmaking Service**: Port 8002 - Manages trade offers and matches
- **Notifications Service**: Port 8003 - Handles user notifications
- **Chat Service**: Port 8004 - Enables messaging between users
- **Auth Database**: PostgreSQL on port 5435
- **Catalog Database**: PostgreSQL on port 5433
- **Matchmaking Database**: PostgreSQL on port 5434
- **Notifications Database**: PostgreSQL on port 5436
- **Chat Database**: PostgreSQL on port 5437
- **PgAdmin**: Port 5050 (optional, use `--profile tools` to start)

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Node.js (for frontend development)

### Running the Services

1. **Start all services:**
   ```powershell
   docker-compose up -d
   ```

2. **Start services with PgAdmin:**
   ```powershell
   docker-compose --profile tools up -d
   ```

3. **View logs:**
   ```powershell
   docker-compose logs -f
   ```

4. **Stop all services:**
   ```powershell
   docker-compose down
   ```

5. **Stop and remove volumes (clean slate):**
   ```powershell
   docker-compose down -v
   ```

### Service URLs

- **Auth Service API**: http://localhost:8000
  - API Docs: http://localhost:8000/docs
  - Health Check: http://localhost:8000/health

- **Catalog Service API**: http://localhost:8001
  - API Docs: http://localhost:8001/docs
  - Health Check: http://localhost:8001/health

- **Matchmaking Service API**: http://localhost:8002
  - API Docs: http://localhost:8002/docs
  - Health Check: http://localhost:8002/health

- **Notifications Service API**: http://localhost:8003
  - API Docs: http://localhost:8003/docs
  - Health Check: http://localhost:8003/health

- **Chat Service API**: http://localhost:8004
  - API Docs: http://localhost:8004/docs
  - Health Check: http://localhost:8004/health

- **PgAdmin** (if started with tools profile): http://localhost:5050
  - Email: admin@swappo.com
  - Password: admin

### Environment Variables

Create a `.env` file in the root directory to override default values:

```env
# Auth Service
SECRET_KEY=your-production-secret-key
REFRESH_SECRET_KEY=your-production-refresh-secret-key
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Database passwords (change in production)
AUTH_DB_PASSWORD=swappo_password
CATALOG_DB_PASSWORD=swappo_pass
```

### Frontend Configuration

The frontend should connect to:
- **Auth endpoints**: `http://localhost:8000/api/v1/auth/*`
- **Catalog endpoints**: `http://localhost:8001/api/v1/catalog/*`
- **Matchmaking endpoints**: `http://localhost:8002/api/v1/offers/*`
- **Notifications endpoints**: `http://localhost:8003/api/v1/notifications/*`
- **Chat endpoints**: `http://localhost:8004/api/v1/chat-rooms/*` and `http://localhost:8004/api/v1/messages/*`

For development, update your frontend API configuration to point to these URLs.

### Database Access

**Auth Database:**
- Host: localhost
- Port: 5432
- Database: swappo_auth
- User: swappo
- Password: swappo_password

**Catalog Database:**
- Host: localhost
- Port: 5433
- Database: swappo_catalog
- User: swappo_user
- Password: swappo_pass

**Matchmaking Database:**
- Host: localhost
- Port: 5434
- Database: swappo_matchmaking
- User: swappo_user
- Password: swappo_pass

**Notifications Database:**
- Host: localhost
- Port: 5436
- Database: swappo_notifications
- User: swappo_user
- Password: swappo_pass

**Chat Database:**
- Host: localhost
- Port: 5437
- Database: swappo_chat
- User: swappo_user
- Password: swappo_pass

### Troubleshooting

**Port conflicts:**
If ports 8000, 8001, 5432, or 5433 are already in use, modify the port mappings in `docker-compose.yml`.

**Database connection issues:**
Ensure the databases are healthy before the services start. Check logs with:
```powershell
docker-compose logs auth_db
docker-compose logs catalog_db
```

**Rebuild services after code changes:**
```powershell
docker-compose up -d --build
```

**View running containers:**
```powershell
docker-compose ps
```

### Development Workflow

1. Start the services with `docker-compose up -d`
2. Make changes to your code
3. Rebuild specific service: `docker-compose up -d --build auth_service`
4. Or rebuild all: `docker-compose up -d --build`

### Production Considerations

Before deploying to production:

1. Change all default passwords in environment variables
2. Use proper secret management (Azure Key Vault, AWS Secrets Manager, etc.)
3. Remove development volume mounts
4. Configure proper logging
5. Set up monitoring and health checks
6. Use HTTPS/TLS for all connections
7. Implement rate limiting and security headers
8. Review and harden database security settings

## Project Structure

```
Swappo/
├── docker-compose.yml          # Main orchestration file
├── Swappo-Auth/               # Authentication microservice
│   ├── app/
│   ├── Dockerfile
│   └── requirements.txt
├── Swappo-Catalog/            # Catalog microservice
│   ├── database.py
│   ├── main.py
│   ├── models.py
│   ├── Dockerfile
│   └── requirements.txt
├── Swappo-Matchmaking/        # Matchmaking microservice
│   ├── database.py
│   ├── main.py
│   ├── models.py
│   ├── Dockerfile
│   └── requirements.txt
├── Swappo-Notifications/      # Notifications microservice
│   ├── database.py
│   ├── main.py
│   ├── models.py
│   ├── Dockerfile
│   └── requirements.txt
├── Swappo-Chat/               # Chat microservice
│   ├── database.py
│   ├── main.py
│   ├── models.py
│   ├── Dockerfile
│   └── requirements.txt
└── Swappo-FE/                 # Frontend application
    └── ...
```

## Microservice Communication

The microservices communicate with each other:
- **Matchmaking → Notifications**: Sends notifications when trade offers are accepted/rejected
- **Matchmaking → Chat**: Creates chat rooms when trade offers are accepted
- **Chat → Notifications**: Sends notifications when new messages arrive

## Support

For issues or questions, please refer to individual service README files:
- [Auth Service](./Swappo-Auth/README.md)
- [Catalog Service](./Swappo-Catalog/README.md)
- [Matchmaking Service](./Swappo-Matchmaking/README.md)
- [Notifications Service](./Swappo-Notifications/README.md)
- [Chat Service](./Swappo-Chat/README.md)
- [Frontend](./Swappo-FE/README.md)
