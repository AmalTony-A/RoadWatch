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
