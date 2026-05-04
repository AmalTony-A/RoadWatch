class DemoDataService {
  static List<Map<String, dynamic>> roadNetworkPayload() {
    return [
      {
        'id': 'nh-45',
        'name': 'NH 45',
        'type': 'NH',
        'route': 'Chennai - Guduvanchery - Chengalpattu - Villupuram - Trichy - Dindigul',
        'districts': ['Chennai', 'Chengalpattu', 'Villupuram', 'Tiruchirappalli', 'Dindigul'],
        'length_km': 368,
        'year': 1956,
        'contractor': 'Dilip Buildcon Ltd.',
        'budget_crore': 3312,
        'condition': 'Good',
        'issues': ['Urban Encroachments', 'Minor Cracks', 'Widening pending'],
        'summary': 'NH | Good | 368 km',
      },
      {
        'id': 'sh-49',
        'name': 'State Highway 49',
        'type': 'SH',
        'route': 'Chennai - Mahabalipuram Coastal Belt',
        'districts': ['Chennai', 'Chengalpattu'],
        'length_km': 65,
        'year': 1984,
        'contractor': 'Tamil Nadu Roads Board',
        'budget_crore': 820,
        'condition': 'Moderate',
        'issues': ['Surface wear', 'Monsoon patchwork', 'Drainage issues'],
        'summary': 'SH | Moderate | 65 km',
      },
      {
        'id': 'mdr-001',
        'name': 'Sardar Patel Road Connector',
        'type': 'MDR',
        'route': 'Adyar - Saidapet link road',
        'districts': ['Chennai'],
        'length_km': 12,
        'year': 1998,
        'contractor': 'Metro CivilWorks Pvt Ltd.',
        'budget_crore': 54,
        'condition': 'Poor',
        'issues': ['Potholes', 'Broken shoulders', 'Drain cover damage'],
        'summary': 'MDR | Poor | 12 km',
      },
      {
        'id': 'mdr-002',
        'name': 'OMR - Tidel Stretch',
        'type': 'MDR',
        'route': 'Perungudi - Taramani service road',
        'districts': ['Chennai'],
        'length_km': 9,
        'year': 2004,
        'contractor': 'South Corridor Infra LLP',
        'budget_crore': 71,
        'condition': 'Moderate',
        'issues': ['Lane markings faded', 'Small cracks'],
        'summary': 'MDR | Moderate | 9 km',
      },
      {
        'id': 'mrd-003',
        'name': 'Guindy Inner Ring',
        'type': 'MDR',
        'route': 'Guindy - Kotturpuram connector',
        'districts': ['Chennai'],
        'length_km': 7,
        'year': 2010,
        'contractor': 'Smart Urban Infra',
        'budget_crore': 41,
        'condition': 'Good',
        'issues': ['Occasional congestion'],
        'summary': 'MDR | Good | 7 km',
      },
    ];
  }

  static Map<String, dynamic> roadPayload() {
    return {
      'overview': {
        'overall_score': 58,
        'total_roads': 6,
        'red_roads': 2,
        'yellow_roads': 2,
        'green_roads': 2,
      },
      'roads': [
        {
          'id': 'road-001',
          'name': 'Sardar Patel Road',
          'ward': 'Adyar',
          'polyline': [
            {'lat': 12.9928, 'lng': 80.2297},
            {'lat': 12.9941, 'lng': 80.2364},
            {'lat': 12.9968, 'lng': 80.2438}
          ],
          'road_health_score': 38,
          'color': 'red',
          'nearby_issues': 14,
          'recent_complaints': 9
        },
        {
          'id': 'road-002',
          'name': 'OMR - Tidel Stretch',
          'ward': 'Perungudi',
          'polyline': [
            {'lat': 12.9764, 'lng': 80.2496},
            {'lat': 12.9708, 'lng': 80.2522},
            {'lat': 12.9651, 'lng': 80.2549}
          ],
          'road_health_score': 61,
          'color': 'yellow',
          'nearby_issues': 7,
          'recent_complaints': 5
        },
        {
          'id': 'road-004',
          'name': 'GST Road - Guindy Junction',
          'ward': 'Guindy',
          'polyline': [
            {'lat': 13.0085, 'lng': 80.2042},
            {'lat': 13.0032, 'lng': 80.2021},
            {'lat': 12.9987, 'lng': 80.1998}
          ],
          'road_health_score': 46,
          'color': 'red',
          'nearby_issues': 12,
          'recent_complaints': 11
        },
        {
          'id': 'road-005',
          'name': 'ECR Link Road',
          'ward': 'Thiruvanmiyur',
          'polyline': [
            {'lat': 12.9846, 'lng': 80.2622},
            {'lat': 12.9799, 'lng': 80.2668},
            {'lat': 12.9754, 'lng': 80.2717}
          ],
          'road_health_score': 74,
          'color': 'green',
          'nearby_issues': 4,
          'recent_complaints': 2
        }
      ],
      'recent_complaints': [
        {
          'id': 'cmp-2026-0001',
          'road_id': 'road-001',
          'description': 'Multiple deep potholes near bus stop causing bike skids.',
          'image_ref': 'demo_pothole_1.jpg',
          'location': {'lat': 12.9946, 'lng': 80.2371},
          'timestamp': '2026-04-28T08:41:00Z',
          'status': 'In Progress',
          'authority_ticket': 'CCMC-11408',
          'recommended_department': 'Highways Department',
          'routing_reason': 'Pothole repair and road surfacing issues are handled by highways.',
          'complaint_letter': 'Please inspect and repair the potholes near the bus stop on Sardar Patel Road.',
          'sent_to_authority': true,
          'delivered_to_authority': true,
          'read_by_authority': false,
          'sent_at': '2026-04-28T09:05:00Z',
          'delivered_at': '2026-04-28T09:15:00Z',
          'read_at': null,
          'timeline': [
            {
              'status': 'Filed',
              'at': '2026-04-28T08:41:00Z',
              'note': 'Complaint auto-filed from RoadWatch AI'
            },
            {
              'status': 'Sent',
              'at': '2026-04-28T09:05:00Z',
              'note': 'Complaint sent to Highways Department'
            },
            {
              'status': 'Delivered',
              'at': '2026-04-28T09:15:00Z',
              'note': 'Complaint letter delivered to the department inbox'
            }
          ]
        }
      ],
      'intelligence': {
        'damage_trends': [
          {'month': 'Jan', 'issues': 42},
          {'month': 'Feb', 'issues': 57},
          {'month': 'Mar', 'issues': 61},
          {'month': 'Apr', 'issues': 74},
          {'month': 'May', 'issues': 69}
        ],
        'budget_vs_condition': [
          {'road_id': 'road-001', 'allocated_inr': 5000000, 'score': 38},
          {'road_id': 'road-004', 'allocated_inr': 6300000, 'score': 46}
        ],
        'repair_frequency': [
          {'road_id': 'road-001', 'repairs_last_12m': 2},
          {'road_id': 'road-004', 'repairs_last_12m': 3}
        ],
        'prediction_text':
            'Sardar Patel Road may deteriorate further in 19 days if monsoon traffic remains high.'
      }
    };
  }

  static List<Map<String, dynamic>> budgetPayload() {
    return [
      {
        'road_id': 'road-001',
        'project_id': 'CHN-2025-ADY-11',
        'allocated_inr': 5000000,
        'spent_inr': 4700000,
        'contractor': 'Metro CivilWorks Pvt Ltd',
        'last_repair_date': '2025-12-03',
        'expected_score': 78,
        'actual_score': 38,
        'transparency_note':
            'Transparency alert: INR 5,000,000 allocated but score is 38/100'
      },
      {
        'road_id': 'road-002',
        'project_id': 'CHN-2025-PRG-07',
        'allocated_inr': 3500000,
        'spent_inr': 3260000,
        'contractor': 'South Corridor Infra LLP',
        'last_repair_date': '2025-11-18',
        'expected_score': 72,
        'actual_score': 61,
        'transparency_note':
            'Moderate mismatch between expected and AI-observed condition'
      }
    ];
  }
}
