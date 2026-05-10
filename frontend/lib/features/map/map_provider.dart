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

    markers = roads
        .map((road) => Marker(
              point: LatLng(road.polyline.first.lat, road.polyline.first.lng),
              width: 36,
              height: 36,
              child: Tooltip(
                message:
                    '${road.name}\nScore ${road.roadHealthScore} | Issues ${road.nearbyIssues} | Complaints ${road.recentComplaints}',
                child: Icon(
                  Icons.location_on,
                  color: _roadColor(road.color),
                  size: 30,
                ),
              ),
            ))
        .toList(growable: false);

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
