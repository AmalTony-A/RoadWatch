import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _pendingComplaintsKey = 'pending_complaints';
  static const _pendingDetectionsKey = 'pending_detections';

  Future<List<Map<String, dynamic>>> getPendingComplaints() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_pendingComplaintsKey);
    if (payload == null || payload.isEmpty) {
      return [];
    }
    final list = jsonDecode(payload) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
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
    return list.cast<Map<String, dynamic>>();
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
}
