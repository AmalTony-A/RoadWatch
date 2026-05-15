import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../features/map/map_provider.dart';
import '../providers/app_state.dart';

class MapFullScreen extends StatelessWidget {
  final LatLng? initialCenter;

  const MapFullScreen({super.key, this.initialCenter});

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final state = context.watch<AppState>();
    final center = initialCenter ?? (state.currentPosition == null
      ? const LatLng(12.9919, 80.2338)
      : LatLng(state.currentPosition!.latitude, state.currentPosition!.longitude));

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: state.currentPosition == null ? 12.4 : 15.2,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          PolylineLayer(polylines: mapProvider.polylines),
          MarkerLayer(
            markers: [
              ...mapProvider.markers,
              Marker(
                point: center,
                width: 48,
                height: 48,
                child: const Icon(Icons.location_on_rounded, color: AppConfig.cautionYellow, size: 40),
              ),
              if (state.currentPosition != null)
                Marker(
                  point: LatLng(state.currentPosition!.latitude, state.currentPosition!.longitude),
                  width: 48,
                  height: 48,
                  child: const Icon(Icons.my_location_rounded, color: AppConfig.safeGreen),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
