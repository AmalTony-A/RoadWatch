import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_config.dart';
import '../../models/road_segment.dart';

class MapProvider extends ChangeNotifier {
  List<Polyline> polylines = <Polyline>[];
  List<Marker> markers = <Marker>[];
  String _roadsCacheKey = '';

  Color _roadColor(String color) => AppConfig.healthColorFromText(color);

  bool _isValidLatLng(double lat, double lng) {
    // Basic sanity bounds for world coordinates.
    if (lat.abs() < 1e-6 && lng.abs() < 1e-6) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    return true;
  }

  bool _isLikelyOffshoreOutlier(double lat, double lng) {
    // Chennai-specific guardrail: points far east of the coastline frequently
    // come from noisy mock data and appear in the ocean.
    return lat >= 12.7 && lat <= 13.3 && lng > 80.275;
  }

  void updateFromRoads(List<RoadSegment> roads) {
    final key = '${roads.length}:${roads.map((r) => r.id).join(',')}';
    if (key == _roadsCacheKey) return;
    _roadsCacheKey = key;

    polylines = roads
        .map((road) => Polyline(
              points: road.polyline.map((e) => LatLng(e.lat, e.lng)).toList(),
              strokeWidth: 5,
              color: _roadColor(road.color),
            ))
        .toList(growable: false);

    markers = roads.map((road) {
      final candidates = road.polyline
          .where((p) => _isValidLatLng(p.lat, p.lng) && !_isLikelyOffshoreOutlier(p.lat, p.lng))
          .toList(growable: false);

      if (candidates.isEmpty) {
        return null; // skip roads with no trustworthy coordinates
      }

      // Use centroid for a more stable and representative marker location.
      final avgLat = candidates.map((p) => p.lat).reduce((a, b) => a + b) / candidates.length;
      final avgLng = candidates.map((p) => p.lng).reduce((a, b) => a + b) / candidates.length;
      final markerPoint = LatLng(avgLat, avgLng);

      return Marker(
        point: markerPoint,
        width: 36,
        height: 36,
        child: Tooltip(
          message: '${road.name}\nScore ${road.roadHealthScore} | Issues ${road.nearbyIssues} | Complaints ${road.recentComplaints}',
          child: Icon(
            Icons.location_on,
            color: _roadColor(road.color),
            size: 30,
          ),
        ),
      );
    }).whereType<Marker>().toList(growable: false);

    // If called during the build phase this would cause a reentrant
    // setState-markNeedsBuild error. Defer notification until after
    // the current frame when needed.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

}
