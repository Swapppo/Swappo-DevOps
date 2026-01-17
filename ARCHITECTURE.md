# Swappo - Architecture Schema

## Overview
Swappo is a microservices-based trading platform built on Google Kubernetes Engine (GKE) with event-driven architecture, implementing modern cloud-native patterns.

---

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              EXTERNAL USERS                                      │
│                     (Mobile App / Web Browser)                                   │
└────────────────────────────────┬────────────────────────────────────────────────┘
                                 │ HTTPS/TLS
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CERT-MANAGER + LET'S ENCRYPT                             │
│                         (Automatic SSL Certificates)                             │
└────────────────────────────────┬────────────────────────────────────────────────┘
                                 │ HTTPS
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           KONG API GATEWAY                                       │
│                      (LoadBalancer: 34.40.17.122)                               │
│                                                                                  │
│  Features: Authentication, Rate Limiting, CORS, Request/Response Logging        │
│  Protocols: HTTP/HTTPS, WebSocket                                               │
└───┬─────────────┬─────────────┬─────────────┬─────────────┬────────────────────┘
    │             │             │             │             │
    │ HTTP        │ HTTP        │ HTTP/       │ HTTP        │ HTTP
    │             │             │ WebSocket   │             │
    ▼             ▼             ▼             ▼             ▼
┌────────┐   ┌────────┐   ┌────────┐   ┌──────────┐   ┌──────────┐
│ Auth   │   │Catalog │   │ Chat   │   │Matchmake │   │Notifica- │
│Service │   │Service │   │Service │   │Service   │   │tions     │
│:8000   │   │:8000   │   │:8000   │   │:8000     │   │Service   │
│+proxy  │   │:50051  │   │+proxy  │   │+proxy    │   │:8000     │
│        │   │+proxy  │   │        │   │          │   │+proxy    │
└────┬───┘   └───┬────┘   └───┬────┘   └─────┬────┘   └────┬─────┘
     │           │            │    │         │             │
     │PostgreSQL │PostgreSQL  │    │         │PostgreSQL   │PostgreSQL
     │           │            │    │  gRPC   │             │
     │           │            │    │         │             │
     │           │            │    └────┐    │             │
     │           │            │         │    │             │
     │           │ HTTPS/     │         │    │AMQP         │AMQP
     │           │ gRPC       │         │    │Pub          │Sub
     │           ▼            │         │    │             │
     │      ┌─────────┐       │         │    ▼             │
     │      │ GCS     │       │ HTTP+   │┌─────────────────────┐
     │      │Bucket   │       │ Retry   ││   RabbitMQ          │
     │      │(Images) │       │         ││ Message Broker      │
     │      └─────────┘       │    ┌────┤│  (Queue:            │
     │                        │    │    ││notifications_queue) │
     │                        ▼    ▼    │└─────────────────────┘
     │                                  │
     │         (Circuit Breaker for Chat calls)
     │
     └─────────┬─────────┬──────────┬───────────┬──────────┘
               │         │          │           │
               ▼         ▼          ▼           ▼
          ┌────────────────────────────────────────────┐
          │    Google Cloud SQL (PostgreSQL 15)        │
          │    Instance: swapppo:europe-west3:swappo-db│
          ├────────────────────────────────────────────┤
          │ DB: swappo_auth          (Auth Service)    │
          │ DB: swappo_catalog       (Catalog Service) │
          │ DB: swappo_chat          (Chat Service)    │
          │ DB: swappo_matchmaking   (Matchmaking)     │
          │ DB: swappo_notifications (Notifications)   │
          └────────────────────────────────────────────┘
               ▲         ▲          ▲           ▲
               │         │          │           │
          Cloud SQL Proxy sidecar containers in each pod

┌─────────────────────────────────────────────────────────────────────────────────┐
│                      MONITORING & OBSERVABILITY STACK                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Prometheus  │───▶│  Grafana    │    │ Loki        │◀───│ Fluent Bit  │     │
│  │ (Metrics)   │    │(Dashboards) │    │(Logs)       │    │(Collector)  │     │
│  └──────▲──────┘    └─────────────┘    └─────────────┘    └──────▲──────┘     │
│         │                                                          │             │
│         └──────────────────────────────────────────────────────────┘             │
│                    (Scraping /metrics endpoints)                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CLOUD FUNCTIONS (Serverless)                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │  Shipping Estimates Function (GCP Cloud Functions)                       │    │
│  │  Trigger: HTTP, Language: Python                                         │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CI/CD PIPELINE                                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│  GitHub Actions → Build Docker Images → Push to GHCR → Deploy to GKE via Helm   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Component Breakdown

### 1. Frontend Layer

#### **Swappo-FE** (Mobile & Web Application)
- **Technology**: React Native + Expo
- **Platforms**: iOS, Android, Web
- **Communication**: 
  - REST API (HTTP/HTTPS) to backend via Kong Gateway
  - WebSocket connections for real-time chat
- **Features**:
  - User authentication
  - Item catalog browsing (swipe feed)
  - Trade offer management
  - Real-time chat
  - Push notifications

---

### 2. API Gateway Layer

#### **Kong API Gateway**
- **Type**: Ingress Controller + API Gateway
- **IP**: 34.40.17.122 (LoadBalancer)
- **Protocol**: HTTP/HTTPS (TLS 1.2+)
- **Features**:
  - **Authentication**: JWT validation
  - **Rate Limiting**: 
    - Global: 500 req/min, 20,000 req/hour
    - Auth service: 20 req/min (stricter)
  - **CORS**: Cross-origin request handling
  - **Request/Response Transformation**
  - **Logging**: All requests logged to stdout
  - **Routing**: Path-based routing to microservices
- **Plugins**:
  - Rate Limiting Plugin
  - CORS Plugin
  - File Log Plugin
  - JWT Plugin (optional)

#### **Cert-Manager + Let's Encrypt**
- **Purpose**: Automatic SSL/TLS certificate provisioning
- **Certificate Authority**: Let's Encrypt
- **Domain**: 34.185.186.13.nip.io (nip.io for automatic DNS)
- **Protocol**: ACME HTTP-01 challenge

---

### 3. Microservices Layer

#### **3.1 Auth Service**
- **Port**: 8000
- **Protocol**: HTTP/REST
- **Technology**: Python (FastAPI), PostgreSQL
- **Database**: auth-postgres
- **Endpoints**:
  - POST `/api/v1/auth/register` - User registration
  - POST `/api/v1/auth/login` - JWT-based login
  - POST `/api/v1/auth/refresh` - Token refresh
  - GET `/api/v1/auth/me` - Current user info
  - PUT `/api/v1/auth/profile` - Update profile
  - POST `/api/v1/auth/change-password` - Password change
- **Features**:
  - JWT tokens (access + refresh)
  - Password hashing (bcrypt)
  - User profile with shipping address
  - Prometheus metrics

#### **3.2 Catalog Service**
- **Port**: 8000 (REST), 50051 (gRPC)
- **Protocols**: 
  - HTTP/REST
  - gRPC (for inter-service communication)
  - GraphQL
- **Technology**: Python (FastAPI), PostgreSQL, gRPC
- **Database**: catalog-postgres
- **External Storage**: Google Cloud Storage (GCS) for images
- **Endpoints**:
  - POST `/items` - Create item listing
  - GET `/items/feed` - Smart matching feed (location-based)
  - GET `/items/{id}` - Get item details
  - PUT `/items/{id}` - Update item
  - DELETE `/items/{id}` - Soft delete item
  - POST `/upload-image` - Upload item image to GCS
- **gRPC Services**:
  - `ValidateItems()` - Called by Matchmaking service
  - `GetItemsByIds()` - Batch item retrieval
- **Features**:
  - Event Sourcing / CQRS support
  - Haversine distance calculation for location filtering
  - Smart feed algorithm
  - Multi-protocol support (REST + GraphQL + gRPC)
  - Image upload to GCS

#### **3.3 Chat Service**
- **Port**: 8000
- **Protocols**: 
  - HTTP/REST
  - WebSocket (for real-time messaging)
- **Technology**: Python (FastAPI), PostgreSQL
- **Database**: chat-postgres
- **Dependencies**: 
  - Notifications Service (HTTP) - sends push notifications (with retry)
- **Endpoints**:
  - POST `/api/v1/chat-rooms` - Create chat room
  - GET `/api/v1/chat-rooms` - List user's rooms
  - POST `/api/v1/messages` - Send message
  - GET `/api/v1/messages` - Get messages
  - PATCH `/api/v1/messages/{id}` - Mark as read
- **Communication**:
  - HTTP POST to Notifications Service (with retry logic: 3 attempts)
- **Features**:
  - Automatic room creation on trade acceptance
  - Unread message tracking
  - Real-time messaging via WebSocket
  - Message status tracking
  - **Retry Logic**: Exponential backoff for notification delivery

#### **3.4 Matchmaking Service**
- **Port**: 8000
- **Protocol**: HTTP/REST
- **Technology**: Python (FastAPI), PostgreSQL, RabbitMQ, gRPC client
- **Database**: matchmaking-postgres
- **Dependencies**:
  - Catalog Service (gRPC) - item validation (with circuit breaker + retry)
  - Chat Service (HTTP) - chat room creation (with circuit breaker + retry)
  - Notifications Service (RabbitMQ) - async notifications
- **Endpoints**:
  - POST `/api/v1/offers` - Create trade offer
  - GET `/api/v1/offers` - List offers (filterable)
  - PATCH `/api/v1/offers/{id}` - Update offer status
  - GET `/api/v1/statistics/{user_id}` - Trade statistics
- **Communication Protocols**:
  - gRPC to Catalog Service (item validation with retry)
  - HTTP to Chat Service (with circuit breaker and retry)
  - AMQP to RabbitMQ (publish notifications)
- **Features**:
  - Multi-item trades (1:1, N:1, N:M)
  - Trade lifecycle: pending → accepted/rejected/cancelled → completed
  - **Circuit Breakers**: 
    - Catalog gRPC (opens after 5 failures, resets after 60s)
    - Chat HTTP (opens after 5 failures, resets after 60s)
  - **Retry Logic**: 3 attempts with exponential backoff (1-10s)
  - Async notification publishing to RabbitMQ

#### **3.5 Notifications Service**
- **Port**: 8000
- **Protocol**: HTTP/REST, AMQP
- **Technology**: Python (FastAPI), PostgreSQL, RabbitMQ
- **Database**: notifications-postgres
- **Message Queue**: RabbitMQ consumer
- **Endpoints**:
  - POST `/api/v1/notifications` - Create notification (HTTP)
  - GET `/api/v1/notifications/{user_id}` - Get user notifications
  - GET `/api/v1/notifications/{user_id}/unread-count` - Badge count
  - PATCH `/api/v1/notifications/mark-read` - Mark as read
- **Communication**:
  - RabbitMQ Consumer (AMQP) - consumes async messages
  - HTTP REST API for direct notification creation
- **Notification Types**:
  - trade_offer_received, trade_offer_accepted, trade_offer_rejected
  - trade_completed, new_message, item_liked, system
- **Features**:
  - Background RabbitMQ consumer
  - Manual message acknowledgment
  - Message requeue on failure
  - Unread count tracking

---

### 4. Data Layer

#### **Google Cloud SQL** (Managed PostgreSQL 15)
Instead of individual PostgreSQL pods, all microservices connect to a **single managed Google Cloud SQL instance** with separate databases:

- **Instance**: `swapppo:europe-west3:swappo-db`
- **Version**: PostgreSQL 15
- **Tier**: db-f1-micro (production should use db-n1-standard-1+)
- **Region**: europe-west3
- **Storage**: 10GB SSD with auto-increase
- **Connection**: Cloud SQL Proxy sidecar containers in each service pod
- **IP**: 34.185.220.40 (private IP)

**Database-per-Service Pattern:**

| Service | Database Name | User | Purpose |
|---------|---------------|------|---------|
| Auth | `swappo_auth` | swappo_user | Users, credentials, profiles |
| Catalog | `swappo_catalog` | swappo_user | Items, categories, event store |
| Chat | `swappo_chat` | swappo_user | Chat rooms, messages |
| Matchmaking | `swappo_matchmaking` | swappo_user | Trade offers, swipes |
| Notifications | `swappo_notifications` | swappo_user | Notifications, read status |

**Cloud SQL Proxy Architecture:**
- Each microservice pod runs a **Cloud SQL Proxy sidecar container**
- The proxy connects securely to Cloud SQL instance
- Application connects to `localhost:5432` (the proxy)
- Proxy handles authentication and encryption to Cloud SQL
- No need to manage connection strings or credentials in code

**Benefits:**
- ✅ Managed service (automatic backups, updates, scaling)
- ✅ High availability option available
- ✅ Automatic storage scaling
- ✅ Secure connections via Cloud SQL Proxy
- ✅ Centralized database management
- ✅ Cost-effective (single instance vs. multiple pods)

#### **Google Cloud Storage (GCS)**
- **Purpose**: Item image storage
- **Service**: Catalog Service
- **Protocol**: Google Cloud Storage API (HTTPS/gRPC)
- **Bucket**: Configured per environment

---

### 5. Message Broker

#### **RabbitMQ**
- **Version**: 3.12-management-alpine
- **Ports**: 
  - 5672 (AMQP protocol)
  - 15672 (Management UI)
- **Protocol**: AMQP 0.9.1
- **Pattern**: Publish-Subscribe with Work Queue
- **Queue**: `notifications` (durable)
- **Publisher**: Matchmaking Service
- **Consumer**: Notifications Service
- **Features**:
  - Message persistence (delivery_mode=2)
  - Manual acknowledgment
  - Automatic reconnection
  - QoS: 1 message at a time
  - 1Gi persistent storage

**Message Flow:**
```
Matchmaking Service → RabbitMQ → Notifications Service
   (Publisher)       (Queue)        (Consumer)
```

---

### 6. Monitoring & Observability Stack

#### **Prometheus**
- **Purpose**: Metrics collection and storage
- **Protocol**: HTTP (scraping /metrics endpoints)
- **Targets**: All microservices expose Prometheus metrics
- **Metrics**:
  - HTTP request counts, latencies
  - Database query performance
  - Custom business metrics (trades, messages, etc.)

#### **Grafana**
- **Purpose**: Metrics visualization and dashboards
- **Protocol**: HTTP
- **Data Source**: Prometheus
- **Dashboards**:
  - Service health
  - API performance
  - Database metrics
  - Business KPIs

#### **Loki + Fluent Bit**
- **Loki**: Log aggregation system
- **Fluent Bit**: Log collector and forwarder
- **Protocol**: HTTP
- **Features**:
  - Centralized logging
  - Log indexing by service/pod
  - Query interface via Grafana

---

### 7. Serverless Layer

#### **Google Cloud Functions**
- **Function**: Shipping Estimates
- **Trigger**: HTTP
- **Runtime**: Python 3.11+
- **Purpose**: Calculate shipping costs (serverless)
- **Protocol**: HTTPS

---

### 8. Infrastructure & Deployment

#### **Kubernetes (GKE)**
- **Platform**: Google Kubernetes Engine
- **Cluster**: Production cluster on GCP
- **Namespaces**: 
  - `swappo` - application services
  - `kong` - API Gateway
  - `monitoring` - observability stack
- **Resources**:
  - Deployments (stateless services)
  - ConfigMaps (configuration)
  - Secrets (credentials, API keys)
  - Services (ClusterIP, LoadBalancer)
  - Ingress (Kong)
  - Cloud SQL Proxy sidecars (database connections)

#### **Helm Charts**
- **Chart**: swappo-helm
- **Purpose**: Templated Kubernetes deployments
- **Features**:
  - Parameterized configurations
  - Environment-specific values
  - Release versioning
  - Easy upgrades/rollbacks

#### **CI/CD Pipeline**
- **Platform**: GitHub Actions
- **Flow**:
  1. Code commit → GitHub
  2. Build Docker images
  3. Push to GitHub Container Registry (GHCR)
  4. Deploy to GKE using Helm
  5. Health checks and smoke tests
- **Container Registry**: ghcr.io

---

## Communication Protocols Summary

| Source | Target | Protocol | Purpose | Resilience |
|--------|--------|----------|---------|-----------|
| Mobile/Web Client | Kong Gateway | HTTPS (TLS 1.2+) | API requests | Kong rate limiting |
| Mobile/Web Client | Chat Service | WebSocket (WSS) | Real-time messaging | - |
| Kong Gateway | All Services | HTTP | API routing | - |
| Cert-Manager | Let's Encrypt | ACME HTTP-01 | Certificate issuance | - |
| Matchmaking | Catalog | gRPC | Item validation | Circuit breaker + 3 retries |
| Matchmaking | Chat | HTTP | Chat room creation | Circuit breaker + 3 retries |
| Matchmaking | RabbitMQ | AMQP 0.9.1 | Publish notifications | Auto-reconnect |
| RabbitMQ | Notifications | AMQP 0.9.1 | Consume notifications | Manual ACK + requeue |
| Chat | Notifications | HTTP | Direct notification | 3 retries |
| All Services | Google Cloud SQL | PostgreSQL wire protocol | Database access via Cloud SQL Proxy | - |
| Catalog | GCS | gRPC/HTTPS | Image upload/download | - |
| Prometheus | All Services | HTTP | Metrics scraping | - |
| Fluent Bit | Loki | HTTP | Log forwarding | - |
| Grafana | Prometheus/Loki | HTTP | Data queries | - |

---

## Design Patterns Implemented

### Architectural Patterns
- **Microservices Architecture** - Independent, loosely coupled services
- **API Gateway Pattern** - Single entry point with Kong
- **Database per Service** - Each service owns its data
- **Event-Driven Architecture** - Async messaging with RabbitMQ
- **Circuit Breaker** - Resilient communication (Matchmaking → Chat)

### Communication Patterns
- **Synchronous**: HTTP/REST, gRPC
- **Asynchronous**: RabbitMQ (publish-subscribe)
- **Real-time**: WebSocket

### Data Patterns
- **Event Sourcing** - Catalog service event store
- **CQRS** - Separate read/write models in Catalog

### Resilience Patterns
- **Circuit Breaker** - Prevents cascading failures (Matchmaking → Catalog gRPC, Matchmaking → Chat HTTP)
  - Opens after 5 consecutive failures
  - Reset timeout: 60 seconds
  - States: Closed → Open → Half-Open → Closed
- **Retry Logic** - Automatic retries with exponential backoff
  - 3 attempts maximum
  - Exponential backoff: 1s → 2s → 4s (max 10s)
  - Applied to: gRPC calls, HTTP calls, notification delivery
- **Message Queue** - Decouples services, ensures delivery
  - Durable queue with message persistence
  - Manual acknowledgment (ACK/NACK)
  - Message requeue on processing failure

### Security Patterns
- **JWT Authentication** - Stateless token-based auth
- **TLS/SSL Termination** - Encrypted communication
- **Rate Limiting** - Prevents abuse
- **CORS** - Secure cross-origin requests

---

## Network Flow Example: Creating a Trade Offer

```
1. User → Kong Gateway (HTTPS)
   POST /matchmaking/api/v1/offers

2. Kong → Matchmaking Service (HTTP)
   ├─ Rate limiting check
   ├─ JWT validation
   └─ Route to Matchmaking

3. Matchmaking → Catalog Service (gRPC with Circuit Breaker)
   ValidateItems(item_ids)
   ← Item validation response (or circuit open fallback)

4. Matchmaking → Cloud SQL Proxy → Google Cloud SQL (SQL)
   INSERT trade offer into swappo_matchmaking database

5. Matchmaking → RabbitMQ (AMQP)
   Publish notification event to queue

6. RabbitMQ → Notifications Service (AMQP - async)
   Consumer receives message from queue
   
7. Notifications → Cloud SQL Proxy → Google Cloud SQL (SQL)
   INSERT notification into swappo_notifications database
   ACK message to RabbitMQ

8. Matchmaking → Kong → User (HTTPS)
   ← Trade offer created response
```

---

## Scalability & High Availability

### Horizontal Scaling
- All microservices are stateless (can scale horizontally)
- Kubernetes Horizontal Pod Autoscaler (HPA) supported
- LoadBalancer distributes traffic across pods

### Data Persistence
- **Google Cloud SQL** with automatic backups and point-in-time recovery
- **RabbitMQ** with message persistence (durable queues)
- **GCS** for image redundancy and availability

### Fault Tolerance
- Multiple pod replicas for each service
- Health checks (liveness/readiness probes)
- Automatic pod restarts on failure
- Circuit breaker prevents cascade failures
- Message queue ensures no data loss

---

## Environment Configuration

The architecture supports multiple environments:
- **Development**: Local Kubernetes (Minikube/Docker Desktop)
- **Production**: Google Kubernetes Engine (GKE)

Both environments use identical architecture with different:
- Domain names
- Database instances
- Resource limits
- Scaling configurations

---

## Technology Stack Summary

| Layer | Technology |
|-------|-----------|
| **Frontend** | React Native, Expo, TypeScript |
| **API Gateway** | Kong (with Ingress Controller) |
| **Services** | Python (FastAPI), gRPC |
| **Database** | Google Cloud SQL (PostgreSQL 15) |
| **Database Connection** | Cloud SQL Proxy |
| **Message Broker** | RabbitMQ 3.12 |
| **Container Orchestration** | Kubernetes (GKE) |
| **Container Runtime** | Docker |
| **Package Manager** | Helm 3 |
| **SSL/TLS** | cert-manager + Let's Encrypt |
| **Monitoring** | Prometheus, Grafana, Loki |
| **Logging** | Fluent Bit |
| **Cloud Storage** | Google Cloud Storage |
| **Serverless** | Google Cloud Functions |
| **CI/CD** | GitHub Actions |
| **Container Registry** | GitHub Container Registry (GHCR) |

---

## Security Features

- ✅ **TLS/SSL encryption** for all external communication
- ✅ **JWT-based authentication** with refresh tokens
- ✅ **Rate limiting** to prevent abuse
- ✅ **CORS policies** for frontend security
- ✅ **API Gateway** as security boundary
- ✅ **Secrets management** via Kubernetes Secrets
- ✅ **Network policies** (service-to-service isolation)
- ✅ **Image security** with GCS access control

---

*This architecture schema was generated for the Swappo microservices trading platform.*
*Last updated: January 12, 2026*
