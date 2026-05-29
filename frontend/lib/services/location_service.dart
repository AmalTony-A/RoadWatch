import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';

class LocationService {
  Future<Position?> getLastKnownPosition() async {
    return Geolocator.getLastKnownPosition();
  }

  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<String?> reverseGeocodeDistrict(Position position) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/location/reverse').replace(
        queryParameters: {
          'lat': position.latitude.toString(),
          'lng': position.longitude.toString(),
        },
      );
      final response = await http.get(url, headers: const {'Accept': 'application/json'});
      if (response.statusCode != 200) {
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final district = payload['district']?.toString().trim() ?? '';
      return district.isEmpty ? null : district;
    } catch (_) {
      return null;
    }
  }
}
