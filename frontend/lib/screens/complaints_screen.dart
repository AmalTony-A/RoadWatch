import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../widgets/complaint_timeline.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final TextEditingController _descriptionController = TextEditingController(
    text: 'Pothole causing safety hazard during peak traffic hours.',
  );

  Future<void> _fileComplaint() async {
    final state = context.read<AppState>();
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      return;
    }
    await state.fileComplaint(description: description);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint request processed.')),
      );
    }
  }

  Future<void> _sendLatestComplaint() async {
    final state = context.read<AppState>();
    await state.sendLatestComplaint();
  }

  Future<void> _markLatestComplaintRead() async {
    final state = context.read<AppState>();
    await state.markLatestComplaintRead();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF102A43), Color(0xFF1D4E89)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complaint Tracking',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Capture public issues, sync them instantly, and keep the workflow visible.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'File a structured complaint',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the issue in one concise sentence',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _fileComplaint,
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('File Complaint'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: appState.syncOfflineData,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sync queue'),
                  ),
                ],
              ),
              if (appState.lastMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConfig.safeGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    appState.lastMessage!,
                    style: const TextStyle(color: AppConfig.deepNavy, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (appState.latestComplaint != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppConfig.deepNavy.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI complaint routing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                ),
                const SizedBox(height: 10),
                Text(
                  appState.latestComplaint!.recommendedDepartment,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                ),
                const SizedBox(height: 6),
                Text(
                  appState.latestComplaint!.routingReason,
                  style: const TextStyle(color: AppConfig.skySlate),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: appState.latestComplaint!.sentToAuthority ? null : _sendLatestComplaint,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Send letter'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: appState.latestComplaint!.sentToAuthority && !appState.latestComplaint!.readByAuthority
                            ? _markLatestComplaintRead
                            : null,
                        icon: const Icon(Icons.mark_email_read_rounded),
                        label: const Text('Mark as read'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip('Filed', appState.latestComplaint!.status == 'Filed' || appState.latestComplaint!.status == 'In Progress'),
                    _statusChip('Sent', appState.latestComplaint!.sentToAuthority),
                    _statusChip('Delivered', appState.latestComplaint!.deliveredToAuthority),
                    _statusChip('Read', appState.latestComplaint!.readByAuthority),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Complaint timeline',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
        ),
        const SizedBox(height: 10),
        ...appState.complaints.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ComplaintTimeline(complaint: item),
          );
        }),
      ],
    );
  }

  Widget _statusChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppConfig.safeGreen.withValues(alpha: 0.14) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppConfig.safeGreen : AppConfig.skySlate,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
