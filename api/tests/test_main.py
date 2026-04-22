"""
Unit tests for api/main.py.

redis.Redis is patched at module-import time so the real Redis client is
never constructed and no live Redis server is required.
"""
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

_mock_redis = MagicMock()

with patch("redis.Redis", return_value=_mock_redis):
    from main import app  # noqa: E402

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_redis_mock():
    """Reset call history before each test to prevent cross-test pollution."""
    _mock_redis.reset_mock()
    yield


def test_create_job_returns_job_id():
    """POST /jobs must respond 200 with a well-formed UUID job_id."""
    response = client.post("/jobs")

    assert response.status_code == 200
    body = response.json()
    assert "job_id" in body
    # UUID4 canonical string is exactly 36 characters (8-4-4-4-12 + 4 dashes)
    assert len(body["job_id"]) == 36


def test_create_job_writes_correct_redis_keys():
    """POST /jobs must enqueue the job id and set its initial status."""
    response = client.post("/jobs")
    job_id = response.json()["job_id"]

    _mock_redis.lpush.assert_called_once_with("job", job_id)
    _mock_redis.hset.assert_called_once_with(
        f"job:{job_id}", "status", "queued"
    )


def test_get_job_returns_decoded_status():
    """GET /jobs/{id} must return the job_id and the decoded status string."""
    _mock_redis.hget.return_value = b"completed"

    response = client.get("/jobs/abc-123")

    assert response.status_code == 200
    body = response.json()
    assert body["job_id"] == "abc-123"
    assert body["status"] == "completed"


def test_get_job_not_found():
    """GET /jobs/{id} must return an error when the Redis key is absent."""
    _mock_redis.hget.return_value = None

    response = client.get("/jobs/does-not-exist")

    assert response.status_code == 200
    assert response.json() == {"error": "not found"}


def test_each_job_gets_a_unique_id():
    """Two consecutive POST /jobs calls must produce distinct job_ids."""
    r1 = client.post("/jobs").json()["job_id"]
    r2 = client.post("/jobs").json()["job_id"]

    assert r1 != r2
