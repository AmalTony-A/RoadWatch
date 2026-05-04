class RoadNetworkItem {
  final String id;
  final String name;
  final String type;
  final String route;
  final List<String> districts;
  final int lengthKm;
  final int year;
  final String contractor;
  final int budgetCrore;
  final String condition;
  final List<String> issues;
  final String summary;

  const RoadNetworkItem({
    required this.id,
    required this.name,
    required this.type,
    required this.route,
    required this.districts,
    required this.lengthKm,
    required this.year,
    required this.contractor,
    required this.budgetCrore,
    required this.condition,
    required this.issues,
    required this.summary,
  });

  factory RoadNetworkItem.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const <String>[];
    }

    int asInt(dynamic value, {int fallback = 0}) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return RoadNetworkItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'MDR',
      route: json['route']?.toString() ?? '',
      districts: asStringList(json['districts']),
      lengthKm: asInt(json['length_km']),
      year: asInt(json['year']),
      contractor: json['contractor']?.toString() ?? '',
      budgetCrore: asInt(json['budget_crore']),
      condition: json['condition']?.toString() ?? 'Moderate',
      issues: asStringList(json['issues']),
      summary: json['summary']?.toString() ?? '',
    );
  }

  bool get isNationalHighway => type == 'NH';
  bool get isStateHighway => type == 'SH';
  bool get isDistrictRoad => type == 'MDR';
  bool get isChennaiRoad =>
      districts.contains('Chennai') || route.contains('Chennai') || contractor.contains('Chennai');

  int get healthScore {
    switch (condition) {
      case 'Good':
        return 84;
      case 'Moderate':
        return 61;
      case 'Poor':
        return 34;
      default:
        return 50;
    }
  }

  String get healthLabel {
    if (healthScore >= 80) {
      return 'Healthy';
    }
    if (healthScore >= 60) {
      return 'Watch';
    }
    return 'Critical';
  }
}