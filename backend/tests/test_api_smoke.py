from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health():
    res = client.get("/health")
    assert res.status_code == 200
    payload = res.json()
    assert payload["ok"] is True


def test_get_road_data():
    res = client.get("/get-road-data")
    assert res.status_code == 200
    payload = res.json()
    assert "overview" in payload
    assert "roads" in payload
    assert len(payload["roads"]) > 0


def test_detect_damage_demo_image():
    res = client.post(
        "/detect-damage",
        json={"image_id": "demo_pothole_1.svg", "road_id": "road-001"},
    )
    assert res.status_code == 200
    payload = res.json()
    assert "detections" in payload
    assert "score" in payload
    assert payload["score"]["road_health_score"] <= 100


def test_generate_complaint():
    res = client.post(
        "/generate-complaint",
        json={
            "road_id": "road-001",
            "description": "Automated test complaint",
            "image_ref": "demo_pothole_1.svg",
            "location": {"lat": 12.9946, "lng": 80.2371},
        },
    )
    assert res.status_code == 200
    payload = res.json()
    assert payload["status"] == "Filed"
    assert "authority_ticket" in payload


def test_predict_risk():
    res = client.post(
        "/predict-risk",
        json={
            "road_id": "road-001",
            "weather_index": 0.71,
            "traffic_index": 0.84,
            "complaint_count_30d": 9,
        },
    )
    assert res.status_code == 200
    payload = res.json()
    assert payload["risk_level"] in {"Low", "Medium", "High"}


def test_api_info():
    res = client.get("/api-info")
    assert res.status_code == 200
    payload = res.json()
    assert "dataset_counts" in payload
    assert payload["dataset_counts"]["roads"] >= 60


def test_search_roads():
    res = client.get("/search-roads?q=GST")
    assert res.status_code == 200
    payload = res.json()
    assert isinstance(payload, list)
    assert len(payload) > 0


def test_roads_nearby():
    res = client.get("/roads-nearby?lat=12.99&lng=80.24&radius=5")
    assert res.status_code == 200
    payload = res.json()
    assert isinstance(payload, list)
    assert len(payload) > 0


def test_get_road_network_data_with_radius():
    res = client.get("/get-road-network-data?lat=13.0&lng=80.2&radius=60")
    assert res.status_code == 200
    payload = res.json()
    assert isinstance(payload, list)
    assert len(payload) > 0


def test_get_road_data_by_id():
    res = client.get("/get-road-data?road_id=road-001")
    assert res.status_code == 200
    payload = res.json()
    assert "road" in payload
    assert "nearby_network" in payload


def test_budget_pagination():
    res = client.get("/get-budget-data?page=1&limit=10")
    assert res.status_code == 200
    payload = res.json()
    assert isinstance(payload, list)
    assert len(payload) <= 10


def test_complaints_pagination():
    res = client.get("/complaints?page=1&limit=10")
    assert res.status_code == 200
    payload = res.json()
    assert isinstance(payload, list)
    assert len(payload) <= 10
