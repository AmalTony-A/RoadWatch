import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

random.seed(42)

DATA_DIR = Path(__file__).resolve().parent.parent / "app" / "data"

# Chennai wards and realistic road names
WARD_ROADS = {
    "Adyar": [
        "Sardar Patel Road", "LB Road", "Kasturba Nagar 1st Main", "Adyar Bridge Road",
        "Gandhi Mandapam Road", "Rajiv Gandhi Salai Extension", "Theosophical Society Road",
        "Ellaiamman Colony Road", "Srinagar Colony Main", "Kottur Gardens Road"
    ],
    "Perungudi": [
        "Old Mahabalipuram Road (OMR)", "Perungudi Industrial Estate Road", "Kamakoti Nagar Main",
        "Thirumalai Nagar 2nd Street", "Rajiv Gandhi Salai (Tidel Stretch)", "Mettukuppam Road",
        "Okkiyam Thoraipakkam Road", "Perungudi Railway Station Road", "Velachery Main Road Extension",
        "Jayendra Saraswathi Street"
    ],
    "Velachery": [
        "Velachery Main Road", "Vijayanagar Main Road", "Taramani Link Road", "Velachery Bypass Road",
        "Gurusamy Nagar Road", "Dhandeeswaram Main Road", "Ram Nagar South Extn", "Annai Indira Nagar Road",
        "Lakshmi Nagar 1st Main", "Srinivasa Nagar Colony Road"
    ],
    "Guindy": [
        "GST Road - Guindy Junction", "Anna Salai (Mount Road)", "Butt Road", "Ekkattuthangal Main Road",
        "Guindy Industrial Estate Road", "Little Mount Road", "Saidapet West Bridge Road",
        "Race View Colony Lane", "Kamarajar Salai Extension", "Chennai Airport Link Road"
    ],
    "Thiruvanmiyur": [
        "ECR Link Road", "Thiruvanmiyur East Coast Road", "Lattice Bridge Road", "Ranga Road",
        "Valmiki Nagar Main Road", "Kamarajar Salai (Thiruvanmiyur)", "Jaya Nagar 1st Street",
        "Venkateswara Nagar Road", "Brahma Avenue", "Chennai Bypass Connector"
    ],
    "Kotturpuram": [
        "Kotturpuram Inner Ring", "Gandhi Mandapam Salai", "Chamiers Road Extension",
        "Kottur Gardens Link", "Adyar River Bank Road", "Anna University Road",
        "Raja Annamalaipuram Main", "Pudukottai Colony Road", "Dr. MGR Road Extension", "Santhome High Road"
    ],
    "Teynampet": [
        "TTK Road", "Greams Road", "Haddows Road", "Nungambakkam High Road",
        "College Road", "Cathedral Road", "Bishop Garden Road", "Cenotaph Road",
        "Luz Church Road", "Alwarpet Main Road"
    ],
    "Anna Nagar": [
        "2nd Avenue", "3rd Avenue", "Shanthi Colony Main Road", "Anna Nagar East 5th Street",
        "Padi Flyover Road", "Blue Star Main Road", "Anna Nagar West Boulevard",
        "Tower Park Road", "Roundana Road", "12th Main Road"
    ],
    "T Nagar": [
        "Usman Road", "Pondy Bazaar", "North Usman Road", "South Usman Road",
        "G.N. Chetty Road", "Thyagaraya Road", "Venkatanarayana Road", "Burkit Road",
        "Mahalakshmi Street", "Ranganathan Street"
    ],
    "Mylapore": [
        "Luz Church Road", "Royapettah High Road", "Kutchery Road", "R.K. Mutt Road",
        "Greenways Road", "Bhashyam Road", "Thirumayilai Station Road", "Mandaveli Street",
        "C.P. Ramaswamy Road", "Dr. Radhakrishnan Salai"
    ],
    "Royapettah": [
        "Royapettah High Road", "Whites Road", "Ethiraj Salai", "Pycrofts Road",
        "Bharathi Salai", "Arya Gowda Road", "Gowdia Mutt Road", "Peters Road",
        "Venkatachalam Road", "New College Road"
    ],
    "Nungambakkam": [
        "Nungambakkam High Road", "College Road", "Sterling Road", "Valluvar Kottam High Road",
        "Harrington Road", "Khader Nawaz Khan Road", "Bazullah Road", "Gangai Amman Koil Street",
        "Venus Colony 1st Main", "Thousand Lights Road"
    ],
}

CONTRACTORS = [
    "Metro CivilWorks Pvt Ltd", "South Corridor Infra LLP", "Urban Paving Consortium",
    "National Highway Repairs Co", "Bayline Roads and Bridges", "Green Patch Engineering",
    "L&T Construction Ltd", "Dilip Buildcon Ltd", "IRB Infrastructure", "GMR Highways",
    "Ashoka Buildcon", "KMC Constructions", "Ramky Infrastructure", "Sadbhav Engineering",
    "PNC Infratech", "Monte Carlo Ltd", "J Kumar Infraprojects", "NCC Urban",
    "Capacit'e Infraprojects", "Man Infraconstruction"
]

COMPLAINT_TEMPLATES = [
    "Multiple deep potholes near bus stop causing bike skids.",
    "Long transverse crack expanding after rain.",
    "Cluster of medium potholes near signal line.",
    "Severe road depression causing waterlogging during rains.",
    "Broken edge and shoulder erosion on left side.",
    "Patchwork quality poor, dislodged within 2 weeks.",
    "Manhole cover protruding above road surface.",
    "Missing road markings and faded zebra crossing.",
    "Speed breaker unmarked, causing vehicle damage.",
    "Drainage overflow making road slippery and dangerous.",
    "Illegal parking obstructing half the road width.",
    "Street light poles in middle of carriageway after expansion.",
    "Open trench left uncovered by contractor.",
    "Gravel and debris scattered across lanes.",
    "Rutting and shoving visible on entire stretch.",
    "Culvert slab cracked, structural integrity compromised.",
    "Utility cut not restored properly.",
    "Reflectors and signboards damaged/missing.",
    "Bridge approach settlement creating bumps.",
    "Kerbs broken and dislocated at multiple locations."
]

STATUS_TIMELINES = {
    "Filed": [("Filed", "Complaint filed with location and image")],
    "Sent": [
        ("Filed", "Complaint auto-filed from RoadWatch AI"),
        ("Sent", "Complaint sent to department"),
    ],
    "Delivered": [
        ("Filed", "Complaint auto-filed from RoadWatch AI"),
        ("Sent", "Complaint sent to department"),
        ("Delivered", "Complaint letter delivered to the department inbox"),
    ],
    "Read": [
        ("Filed", "Complaint auto-filed from RoadWatch AI"),
        ("Sent", "Complaint sent to department"),
        ("Delivered", "Complaint letter delivered to the department inbox"),
        ("Read", "Authority opened the complaint letter for review"),
    ],
    "In Progress": [
        ("Filed", "Complaint auto-filed from RoadWatch AI"),
        ("Sent", "Complaint sent to department"),
        ("Delivered", "Complaint letter delivered to the department inbox"),
        ("Read", "Authority opened the complaint letter for review"),
        ("In Progress", "Zonal engineer assigned for inspection"),
    ],
    "Resolved": [
        ("Filed", "Complaint auto-filed from RoadWatch AI"),
        ("Sent", "Complaint sent to department"),
        ("Delivered", "Complaint letter delivered to the department inbox"),
        ("Read", "Authority opened the complaint letter for review"),
        ("In Progress", "Zonal engineer assigned for inspection"),
        ("Resolved", "Repair work completed and verified"),
    ],
}


def random_polyline(center_lat, center_lng, length=3):
    pts = []
    lat, lng = center_lat, center_lng
    for i in range(length):
        pts.append({"lat": round(lat, 4), "lng": round(lng, 4)})
        lat += random.uniform(-0.004, 0.004)
        lng += random.uniform(-0.004, 0.004)
    return pts


def generate_roads(n=60):
    roads = []
    all_names = []
    for ward, names in WARD_ROADS.items():
        for name in names:
            all_names.append((ward, name))
    random.shuffle(all_names)
    selected = all_names[:n]

    # Chennai rough bounds
    base_lats = [12.90, 12.95, 13.00, 13.05, 13.10]
    base_lngs = [80.15, 80.20, 80.25, 80.30]

    for i, (ward, name) in enumerate(selected, 1):
        base_lat = random.choice(base_lats) + random.uniform(-0.03, 0.03)
        base_lng = random.choice(base_lngs) + random.uniform(-0.03, 0.03)
        # Higher traffic areas (T Nagar, Guindy, Teynampet) get lower scores
        if ward in {"T Nagar", "Guindy", "Teynampet", "Nungambakkam"}:
            score = random.randint(28, 72)
        elif ward in {"Adyar", "Royapettah", "Mylapore"}:
            score = random.randint(45, 85)
        else:
            score = random.randint(55, 92)

        color = "red" if score < 50 else "yellow" if score < 75 else "green"
        nearby = random.randint(1, 18)
        recent = random.randint(0, nearby)

        roads.append({
            "id": f"road-{i:03d}",
            "name": name,
            "ward": ward,
            "polyline": random_polyline(base_lat, base_lng),
            "road_health_score": score,
            "color": color,
            "nearby_issues": nearby,
            "recent_complaints": recent,
        })
    return roads


def generate_budgets(roads):
    budgets = []
    for road in roads:
        allocated = random.choice([2_000_000, 2_800_000, 3_500_000, 4_200_000, 5_000_000, 5_500_000, 6_300_000, 7_500_000])
        spent = int(allocated * random.uniform(0.65, 0.98))
        expected = random.randint(70, 88)
        budgets.append({
            "road_id": road["id"],
            "project_id": f"CHN-2025-{road['ward'][:3].upper()}-{random.randint(1,99):02d}",
            "allocated_inr": allocated,
            "spent_inr": spent,
            "contractor": random.choice(CONTRACTORS),
            "last_repair_date": (datetime.now(timezone.utc) - timedelta(days=random.randint(30, 300))).strftime("%Y-%m-%d"),
            "expected_score": expected,
        })
    return budgets


def generate_complaints(roads, n=50):
    complaints = []
    statuses = list(STATUS_TIMELINES.keys())
    status_weights = [10, 8, 6, 5, 4, 3]  # More filed/sent than resolved
    now = datetime.now(timezone.utc)

    for i in range(1, n + 1):
        road = random.choice(roads)
        status = random.choices(statuses, weights=status_weights)[0]
        desc = random.choice(COMPLAINT_TEMPLATES)
        filed_at = now - timedelta(days=random.randint(1, 90), hours=random.randint(0, 23))

        timeline = []
        current = filed_at
        for st, note in STATUS_TIMELINES[status]:
            current += timedelta(hours=random.randint(1, 48))
            timeline.append({"status": st, "at": current.isoformat().replace("+00:00", "Z"), "note": note})

        lat = road["polyline"][0]["lat"] + random.uniform(-0.001, 0.001)
        lng = road["polyline"][0]["lng"] + random.uniform(-0.001, 0.001)

        sent = status in {"Sent", "Delivered", "Read", "In Progress", "Resolved"}
        delivered = status in {"Delivered", "Read", "In Progress", "Resolved"}
        read = status in {"Read", "In Progress", "Resolved"}

        complaints.append({
            "id": f"cmp-2026-{i:04d}",
            "road_id": road["id"],
            "description": desc,
            "image_ref": random.choice([None, f"demo_pothole_{random.randint(1,3)}.jpg", f"demo_crack_{random.randint(1,2)}.jpg"]),
            "location": {"lat": round(lat, 4), "lng": round(lng, 4)},
            "timestamp": filed_at.isoformat().replace("+00:00", "Z"),
            "status": status,
            "authority_ticket": f"CCMC-{random.randint(11000, 12999)}",
            "recommended_department": random.choice([
                "Greater Chennai Corporation - Road Works Division",
                "Tamil Nadu Highways Department",
                "Greater Chennai Corporation - Storm Water Drainage Division",
                "Greater Chennai Corporation - Electrical Wing",
                "Greater Chennai Corporation - Zonal Office"
            ]),
            "routing_reason": "Auto-routed based on road type and description keywords.",
            "complaint_letter": f"Please inspect and repair the reported issue on {road['name']}.",
            "sent_to_authority": sent,
            "delivered_to_authority": delivered,
            "read_by_authority": read,
            "sent_at": timeline[1]["at"] if len(timeline) > 1 and sent else None,
            "delivered_at": timeline[2]["at"] if len(timeline) > 2 and delivered else None,
            "read_at": timeline[3]["at"] if len(timeline) > 3 and read else None,
            "timeline": timeline,
        })
    return complaints


def generate_risk_features(roads):
    rows = []
    for road in roads:
        score = road["road_health_score"]
        # Lower score => higher indices and more complaints
        weather = round(random.uniform(0.25, 0.95), 2)
        traffic = round(random.uniform(0.30, 0.98), 2)
        complaints_30d = random.randint(0, 18)
        deteriorated = 1 if (score < 55 or (weather > 0.7 and traffic > 0.7 and complaints_30d > 8)) else 0
        rows.append({
            "road_id": road["id"],
            "weather_index": weather,
            "traffic_index": traffic,
            "complaint_count_30d": complaints_30d,
            "deteriorated": deteriorated,
        })
    # Add some extra synthetic rows for model robustness
    for _ in range(10):
        rows.append({
            "road_id": f"road-x{random.randint(10,99)}",
            "weather_index": round(random.uniform(0.1, 0.95), 2),
            "traffic_index": round(random.uniform(0.1, 0.95), 2),
            "complaint_count_30d": random.randint(0, 20),
            "deteriorated": random.randint(0, 1),
        })
    return rows


def generate_demo_detections():
    return {
        "demo_pothole_1.svg": [
            {"label": "pothole", "confidence": 0.92, "severity": "high", "bbox": [102, 188, 254, 318]},
            {"label": "crack", "confidence": 0.79, "severity": "medium", "bbox": [320, 214, 470, 284]},
        ],
        "demo_pothole_1.jpg": [
            {"label": "pothole", "confidence": 0.92, "severity": "high", "bbox": [102, 188, 254, 318]},
            {"label": "crack", "confidence": 0.79, "severity": "medium", "bbox": [320, 214, 470, 284]},
        ],
        "demo_crack_2.svg": [
            {"label": "crack", "confidence": 0.88, "severity": "high", "bbox": [45, 220, 580, 290]},
        ],
        "demo_crack_2.jpg": [
            {"label": "crack", "confidence": 0.88, "severity": "high", "bbox": [45, 220, 580, 290]},
        ],
        "demo_good_road.svg": [],
        "demo_good_road.jpg": [],
        "demo_pothole_3.jpg": [
            {"label": "pothole", "confidence": 0.85, "severity": "medium", "bbox": [200, 240, 380, 340]},
            {"label": "pothole", "confidence": 0.71, "severity": "low", "bbox": [420, 260, 520, 320]},
        ],
    }


def main():
    roads = generate_roads(60)
    budgets = generate_budgets(roads)
    complaints = generate_complaints(roads, 50)
    risk_features = generate_risk_features(roads)
    demo_detections = generate_demo_detections()

    (DATA_DIR / "mock_roads.json").write_text(json.dumps(roads, indent=2), encoding="utf-8")
    (DATA_DIR / "mock_budget.json").write_text(json.dumps(budgets, indent=2), encoding="utf-8")
    (DATA_DIR / "mock_complaints.json").write_text(json.dumps(complaints, indent=2), encoding="utf-8")
    (DATA_DIR / "mock_risk_features.json").write_text(json.dumps(risk_features, indent=2), encoding="utf-8")
    (DATA_DIR / "demo_detections.json").write_text(json.dumps(demo_detections, indent=2), encoding="utf-8")

    print("Generated:")
    print(f"  mock_roads.json: {len(roads)} roads")
    print(f"  mock_budget.json: {len(budgets)} budgets")
    print(f"  mock_complaints.json: {len(complaints)} complaints")
    print(f"  mock_risk_features.json: {len(risk_features)} rows")
    print(f"  demo_detections.json: {len(demo_detections)} presets")


if __name__ == "__main__":
    main()
