class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint({required this.lat, required this.lng});

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class RoadSegment {
  final String id;
  final String name;
  final String ward;
  final List<GeoPoint> polyline;
  final int roadHealthScore;
  final String color;
  final int nearbyIssues;
  final int recentComplaints;

  const RoadSegment({
    required this.id,
    required this.name,
    required this.ward,
    required this.polyline,
    required this.roadHealthScore,
    required this.color,
    required this.nearbyIssues,
    required this.recentComplaints,
  });

  factory RoadSegment.fromJson(Map<String, dynamic> json) {
    return RoadSegment(
      id: json['id'] as String,
      name: json['name'] as String,
      ward: json['ward'] as String,
      polyline: (json['polyline'] as List<dynamic>)
          .map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      roadHealthScore: json['road_health_score'] as int,
      color: json['color'] as String,
      nearbyIssues: json['nearby_issues'] as int,
      recentComplaints: json['recent_complaints'] as int,
    );
  }
}
