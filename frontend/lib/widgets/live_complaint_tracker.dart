import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/complaint.dart';
import '../screens/map_fullscreen.dart';

class LiveComplaintTracker extends StatefulWidget {
  final ComplaintItem complaint;

  const LiveComplaintTracker({super.key, required this.complaint});

  @override
  State<LiveComplaintTracker> createState() => _LiveComplaintTrackerState();
}

class _LiveComplaintTrackerState extends State<LiveComplaintTracker> {
  int _rating = 0;

  static const List<String> _flow = [
    'Complaint Submitted',
    'Complaint Verified',
    'Assigned to Road Department',
    'Engineer Inspection Started',
    'Repair Team Dispatched',
    'Pothole Repair In Progress',
    'Quality Check',
    'Complaint Resolved',
  ];

  static const List<int> _featuredSteps = [0, 2, 5, 7];

  String _formatTime(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return DateFormat('dd MMM, HH:mm').format(dt);
    } catch (_) {
      return ts;
    }
  }

  String _estimatedCompletion(ComplaintItem complaint) {
    final lastStatus = complaint.timeline.isNotEmpty ? complaint.timeline.last.status : complaint.status;
    if (lastStatus.toLowerCase().contains('resolved')) {
      return 'Completed';
    }
    try {
      final dt = complaint.timeline.isNotEmpty ? DateTime.parse(complaint.timeline.first.at) : DateTime.now();
      final est = dt.add(const Duration(days: 2));
      return DateFormat('dd MMM, yyyy').format(est.toLocal());
    } catch (_) {
      return 'TBD';
    }
  }

  bool _isCompleted(String step, Set<String> completedStatuses) {
    final lower = step.toLowerCase();
    return completedStatuses.any((s) => s.toLowerCase().contains(lower.split(' ').first));
  }

  Widget _statusChip(BuildContext context, String label, {required bool active}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.primary.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? theme.colorScheme.primary.withValues(alpha: 0.20) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: active ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _brokenMediaCard(ThemeData theme, String message, {IconData icon = Icons.image_not_supported_rounded}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surface.withValues(alpha: 0.96)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoCard(BuildContext context, {required String label, String? url}) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
        gradient: LinearGradient(
          colors: [theme.colorScheme.surface, theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _brokenMediaCard(theme, '$label image unavailable', icon: Icons.photo_outlined),
            )
          else
            _brokenMediaCard(theme, 'No $label image yet', icon: Icons.photo_camera_front_rounded),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineDot(BuildContext context, {required bool completed}) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 16,
      backgroundColor: completed ? Colors.green.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        completed ? Icons.check_rounded : Icons.circle,
        size: 14,
        color: completed ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.42),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complaint = widget.complaint;
    final completedStatuses = complaint.timeline.map((e) => e.status).toSet();
    final estimated = _estimatedCompletion(complaint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.surface, theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _statusChip(context, 'Live tracker', active: true),
                        const SizedBox(width: 8),
                        _statusChip(context, complaint.status, active: complaint.status.toLowerCase() != 'resolved'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(complaint.id, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      complaint.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChip(context, 'Expected by $estimated', active: false),
                        _statusChip(context, '${complaint.lat.toStringAsFixed(3)}, ${complaint.lng.toStringAsFixed(3)}', active: false),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary.withValues(alpha: 0.16), theme.colorScheme.secondary.withValues(alpha: 0.16)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.14)),
                ),
                child: Icon(Icons.verified_rounded, color: theme.colorScheme.primary, size: 44),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: _featuredSteps.map((index) {
              final label = _flow[index];
              final completed = _isCompleted(label, completedStatuses);
              return Expanded(
                child: Column(
                  children: [
                    _timelineDot(context, completed: completed),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MapFullScreen(initialCenter: LatLng(complaint.lat, complaint.lng)),
                        ),
                      );
                    },
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
                        boxShadow: [
                          BoxShadow(
                            color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          IgnorePointer(
                            ignoring: true,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(complaint.lat, complaint.lng),
                                initialZoom: 15.0,
                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                              ),
                              children: [
                                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(complaint.lat, complaint.lng),
                                      width: 36,
                                      height: 36,
                                      child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 34),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Tap to open map',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Photos', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _photoCard(context, label: 'Before', url: complaint.imageRef ?? complaint.complaintLetter),
                        _photoCard(context, label: 'After', url: complaint.complaintLetter),
                        _photoCard(context, label: 'Report', url: null),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifications', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: complaint.timeline.reversed.take(4).map((e) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
                            child: Icon(Icons.notifications_rounded, size: 16, color: theme.colorScheme.primary),
                          ),
                          title: Text(e.status, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Text(_formatTime(e.at), style: theme.textTheme.bodySmall),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Feedback', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (i) {
                        return IconButton(
                          onPressed: () => setState(() => _rating = i + 1),
                          icon: Icon(
                            i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
