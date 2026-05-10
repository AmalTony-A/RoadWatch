import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _pendingComplaintsKey = 'pending_complaints';
  static const _pendingDetectionsKey = 'pending_detections';
  static const _lastKnownLocationKey = 'last_known_location';

  Future<List<Map<String, dynamic>>> getPendingComplaints() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_pendingComplaintsKey);
    if (payload == null || payload.isEmpty) {
      return [];
    }
    final list = jsonDecode(payload) as List<dynamic>;
    return list
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: true);
  }

  Future<void> addPendingComplaint(Map<String, dynamic> complaint) async {
    final current = await getPendingComplaints();
    current.add(complaint);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingComplaintsKey, jsonEncode(current));
  }

  Future<void> clearPendingComplaints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingComplaintsKey);
  }

  Future<List<Map<String, dynamic>>> getPendingDetections() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_pendingDetectionsKey);
    if (payload == null || payload.isEmpty) {
      return [];
    }
    final list = jsonDecode(payload) as List<dynamic>;
    return list
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: true);
  }

  Future<void> addPendingDetection(Map<String, dynamic> detectionRequest) async {
    final current = await getPendingDetections();
    current.add(detectionRequest);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingDetectionsKey, jsonEncode(current));
  }

  Future<void> clearPendingDetections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingDetectionsKey);
  }

  Future<void> saveLastKnownLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastKnownLocationKey,
      jsonEncode({
        'lat': lat,
        'lng': lng,
      }),
    );
  }

  Future<Map<String, double>?> getLastKnownLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_lastKnownLocationKey);
    if (payload == null || payload.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      return null;
    }
    final lat = decoded['lat'];
    final lng = decoded['lng'];
    if (lat is! num || lng is! num) {
      return null;
    }
    return {
      'lat': lat.toDouble(),
      'lng': lng.toDouble(),
    };
  }
}
