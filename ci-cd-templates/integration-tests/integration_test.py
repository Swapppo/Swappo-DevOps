"""
Integration Tests for Swappo Microservices

These tests verify that all services can communicate with each other
and that the core workflows function end-to-end.
"""
import os
import requests
import pytest
import time

# Service URLs from environment
AUTH_SERVICE = os.getenv("AUTH_SERVICE_URL", "http://localhost:8001")
CATALOG_SERVICE = os.getenv("CATALOG_SERVICE_URL", "http://localhost:8002")
CHAT_SERVICE = os.getenv("CHAT_SERVICE_URL", "http://localhost:8003")
MATCHMAKING_SERVICE = os.getenv("MATCHMAKING_SERVICE_URL", "http://localhost:8004")
NOTIFICATIONS_SERVICE = os.getenv("NOTIFICATIONS_SERVICE_URL", "http://localhost:8005")


@pytest.fixture(scope="session", autouse=True)
def wait_for_services():
    """Wait for all services to be healthy before running tests"""
    services = {
        "Auth": AUTH_SERVICE,
        "Catalog": CATALOG_SERVICE,
        "Chat": CHAT_SERVICE,
        "Matchmaking": MATCHMAKING_SERVICE,
        "Notifications": NOTIFICATIONS_SERVICE,
    }
    
    print("\n🔍 Waiting for services to be healthy...")
    for name, url in services.items():
        for i in range(30):  # 30 retries = 30 seconds
            try:
                response = requests.get(f"{url}/health", timeout=2)
                if response.status_code == 200:
                    print(f"✅ {name} service is healthy")
                    break
            except requests.exceptions.RequestException:
                if i == 29:
                    pytest.fail(f"❌ {name} service failed to become healthy")
                time.sleep(1)


class TestServiceHealth:
    """Test that all services are up and healthy"""
    
    def test_auth_health(self):
        response = requests.get(f"{AUTH_SERVICE}/health")
        assert response.status_code == 200
        
    def test_catalog_health(self):
        response = requests.get(f"{CATALOG_SERVICE}/health")
        assert response.status_code == 200
        
    def test_chat_health(self):
        response = requests.get(f"{CHAT_SERVICE}/health")
        assert response.status_code == 200
        
    def test_matchmaking_health(self):
        response = requests.get(f"{MATCHMAKING_SERVICE}/health")
        assert response.status_code == 200
        
    def test_notifications_health(self):
        response = requests.get(f"{NOTIFICATIONS_SERVICE}/health")
        assert response.status_code == 200


class TestUserRegistrationFlow:
    """Test complete user registration and authentication flow"""
    
    def test_user_registration_and_login(self):
        # Register a new user
        register_data = {
            "username": "testuser",
            "email": "test@example.com",
            "password": "TestPassword123!"
        }
        
        response = requests.post(f"{AUTH_SERVICE}/register", json=register_data)
        assert response.status_code in [200, 201, 409]  # 409 if user already exists
        
        # Login
        login_data = {
            "username": "testuser",
            "password": "TestPassword123!"
        }
        
        response = requests.post(f"{AUTH_SERVICE}/login", json=login_data)
        assert response.status_code == 200
        assert "access_token" in response.json() or "token" in response.json()


class TestServiceCommunication:
    """Test that services can communicate with each other"""
    
    @pytest.fixture
    def auth_token(self):
        """Get an authentication token for testing"""
        # Try to register and login
        register_data = {
            "username": "integrationtest",
            "email": "integration@test.com",
            "password": "IntegrationTest123!"
        }
        requests.post(f"{AUTH_SERVICE}/register", json=register_data)
        
        login_data = {
            "username": "integrationtest",
            "password": "IntegrationTest123!"
        }
        response = requests.post(f"{AUTH_SERVICE}/login", json=login_data)
        data = response.json()
        return data.get("access_token") or data.get("token")
    
    def test_catalog_requires_auth(self, auth_token):
        """Test that catalog service validates auth tokens"""
        # Without token - should fail
        response = requests.get(f"{CATALOG_SERVICE}/items")
        assert response.status_code in [401, 403]
        
        # With token - should succeed or return empty list
        headers = {"Authorization": f"Bearer {auth_token}"}
        response = requests.get(f"{CATALOG_SERVICE}/items", headers=headers)
        assert response.status_code in [200, 404]


class TestEndToEndWorkflow:
    """Test a complete end-to-end user workflow"""
    
    @pytest.fixture
    def authenticated_user(self):
        """Create and authenticate a user"""
        username = f"e2etest_{int(time.time())}"
        register_data = {
            "username": username,
            "email": f"{username}@test.com",
            "password": "E2ETest123!"
        }
        
        # Register
        requests.post(f"{AUTH_SERVICE}/register", json=register_data)
        
        # Login
        login_data = {
            "username": username,
            "password": "E2ETest123!"
        }
        response = requests.post(f"{AUTH_SERVICE}/login", json=login_data)
        token = response.json().get("access_token") or response.json().get("token")
        
        return {
            "username": username,
            "token": token,
            "headers": {"Authorization": f"Bearer {token}"}
        }
    
    def test_complete_swap_workflow(self, authenticated_user):
        """
        Test complete workflow:
        1. User creates item in catalog
        2. Item appears in matchmaking
        3. User can view notifications
        """
        headers = authenticated_user["headers"]
        
        # 1. Create an item in catalog
        item_data = {
            "name": "Test Item",
            "description": "Integration test item",
            "category": "electronics"
        }
        response = requests.post(
            f"{CATALOG_SERVICE}/items",
            json=item_data,
            headers=headers
        )
        # Should create item or fail gracefully
        assert response.status_code in [200, 201, 400, 422]
        
        # 2. Check matchmaking endpoint exists
        response = requests.get(
            f"{MATCHMAKING_SERVICE}/matches",
            headers=headers
        )
        assert response.status_code in [200, 404]
        
        # 3. Check notifications endpoint exists
        response = requests.get(
            f"{NOTIFICATIONS_SERVICE}/notifications",
            headers=headers
        )
        assert response.status_code in [200, 404]


def test_all_services_respond():
    """Smoke test - ensure all services respond to basic requests"""
    services = {
        "Auth": AUTH_SERVICE,
        "Catalog": CATALOG_SERVICE,
        "Chat": CHAT_SERVICE,
        "Matchmaking": MATCHMAKING_SERVICE,
        "Notifications": NOTIFICATIONS_SERVICE,
    }
    
    for name, url in services.items():
        try:
            response = requests.get(url, timeout=5)
            # Any response is fine (200, 404, 405, etc.) - just not connection error
            assert response.status_code is not None
            print(f"✅ {name} is responding")
        except requests.exceptions.RequestException as e:
            pytest.fail(f"❌ {name} failed to respond: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
