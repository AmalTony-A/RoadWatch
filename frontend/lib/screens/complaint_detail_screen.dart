import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/complaint.dart';
import '../providers/app_state.dart';
// complaint_detail_screen now uses the LiveComplaintTracker widget.
// import '../widgets/complaint_timeline.dart';
import '../widgets/live_complaint_tracker.dart';

class ComplaintDetailScreen extends StatelessWidget {
  final String complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    ComplaintItem complaint;
    try {
      complaint = appState.complaints.firstWhere((c) => c.id == complaintId);
    } catch (_) {
      if (appState.latestComplaint != null) {
        complaint = appState.latestComplaint!;
      } else if (appState.complaints.isNotEmpty) {
        complaint = appState.complaints.first;
      } else {
        throw Exception('No complaints available');
      }
    }
    // Theme reference not needed here; LiveComplaintTracker handles styling.
    // final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint tracker'),
        leading: kIsWeb
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary.withValues(alpha: 0.96), theme.colorScheme.secondary.withValues(alpha: 0.92)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
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
                          Text(
                            complaint.id,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            complaint.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              const _InfoPill(icon: Icons.access_time_rounded, label: 'Estimated: 11 May, 2026', color: Colors.white),
                              _InfoPill(icon: Icons.place_rounded, label: '${complaint.lat.toStringAsFixed(3)}, ${complaint.lng.toStringAsFixed(3)}', color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.white, size: 44),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LiveComplaintTracker(complaint: complaint),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
