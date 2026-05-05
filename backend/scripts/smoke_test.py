import json
import os

import httpx


BASE_URL = os.getenv("ROADWATCH_API_URL", "http://localhost:8001")


def print_result(name: str, status: int, payload: dict | list | str):
    print(f"[{name}] status={status}")
    if isinstance(payload, (dict, list)):
        print(json.dumps(payload, indent=2)[:800])
    else:
        print(payload)
    print("-" * 60)


def main():
    with httpx.Client(timeout=10.0) as client:
        res = client.get(f"{BASE_URL}/health")
        print_result("health", res.status_code, res.json())

        res = client.get(f"{BASE_URL}/get-road-data")
        road_data = res.json()
        print_result("get-road-data", res.status_code, road_data)

        res = client.post(
            f"{BASE_URL}/detect-damage",
            json={"image_id": "demo_pothole_1.svg", "road_id": "road-001"},
        )
        detect_payload = res.json()
        print_result("detect-damage", res.status_code, detect_payload)

        res = client.post(
            f"{BASE_URL}/generate-complaint",
            json={
                "road_id": "road-001",
                "description": "Smoke test complaint",
                "image_ref": "demo_pothole_1.svg",
                "location": {"lat": 12.9946, "lng": 80.2371},
            },
        )
        print_result("generate-complaint", res.status_code, res.json())

        res = client.post(
            f"{BASE_URL}/predict-risk",
            json={
                "road_id": "road-001",
                "weather_index": 0.71,
                "traffic_index": 0.84,
                "complaint_count_30d": 9,
            },
        )
        print_result("predict-risk", res.status_code, res.json())

        res = client.post(
            f"{BASE_URL}/chat",
            json={"query": "How much budget was allocated here?", "road_id": "road-001", "history": []},
        )
        print_result("chat", res.status_code, res.json())


if __name__ == "__main__":
    main()
