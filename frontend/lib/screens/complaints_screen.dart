import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/complaint.dart';
import '../models/road_network_item.dart';
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
  final ScrollController _scrollController = ScrollController();
  String _selectedDistrict = 'ALL';
  int _displayedComplaintsCount = 10;

  String _roadUniqueKey(RoadNetworkItem road) {
    final id = road.id.trim();
    if (id.isNotEmpty) {
      return '${id}_${road.name.trim()}';
    }
    return '${road.name.trim()}_${road.route.trim()}_${road.districts.join('|')}';
  }

  List<RoadNetworkItem> _uniqueRoads(List<RoadNetworkItem> roads) {
    final byKey = <String, RoadNetworkItem>{};
    for (final road in roads) {
      byKey.putIfAbsent(_roadUniqueKey(road), () => road);
    }
    return byKey.values.toList(growable: false);
  }

  void _syncRoadSelection(AppState state, List<RoadNetworkItem> roadOptions) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || roadOptions.isEmpty) {
        return;
      }

      final selectedRoad = state.selectedRoadNetwork;
      final desiredRoad = selectedRoad != null && roadOptions.any((road) => road.id == selectedRoad.id)
          ? selectedRoad
          : roadOptions.first;

      if (state.selectedRoadNetwork?.id != desiredRoad.id) {
        state.selectRoadNetworkItem(desiredRoad);
      }
    });
  }

  Future<void> _fileComplaint() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      return;
    }
    await state.fileComplaint(description: description);
    if (mounted) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      messenger.showSnackBar(
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
  void dispose() {
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    final districtOptions = ['ALL', ...appState.roadNetworkDistricts];
    final effectiveDistrict = _selectedDistrict == 'AUTO'
        ? (appState.liveSuggestedDistrict ?? 'ALL')
        : _selectedDistrict;
    final roadOptions = _uniqueRoads(appState.roadsForDistrict(effectiveDistrict == 'AUTO' ? 'ALL' : effectiveDistrict));
    final selectedRoad = appState.selectedRoadNetwork;
    final liveDistrict = appState.liveSuggestedDistrict;
    // Debug: log dropdown state to terminal to diagnose duplicate/value issues
    // (removed in production once issue is resolved)
    // ignore: avoid_print
    print('ComplaintsScreen: selectedRoad=${selectedRoad?.id ?? 'null'} type=${selectedRoad?.runtimeType} roadOptions=${roadOptions.length}');

    if (appState.currentPosition != null && _selectedDistrict == 'AUTO') {
      _syncRoadSelection(appState, roadOptions);
    }

    final complaints = appState.complaints;
    final filedCount = complaints.where((c) => c.status == 'Filed' || c.status == 'In Progress').length;
    final sentCount = complaints.where((c) => c.sentToAuthority).length;
    final deliveredCount = complaints.where((c) => c.deliveredToAuthority).length;
    final readCount = complaints.where((c) => c.readByAuthority).length;

    return ListView(
      controller: _scrollController,
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _CountCard(label: 'Total complaints', value: '${complaints.length}', icon: Icons.list_alt_rounded, color: theme.colorScheme.primary),
            _CountCard(label: 'Filed / Draft', value: '$filedCount', icon: Icons.pending_actions_rounded, color: theme.colorScheme.tertiary),
            _CountCard(label: 'Sent', value: '$sentCount', icon: Icons.send_rounded, color: theme.colorScheme.secondary),
            _CountCard(label: 'Delivered', value: '$deliveredCount', icon: Icons.local_shipping_rounded, color: AppConfig.cautionYellow),
            _CountCard(label: 'Read', value: '$readCount', icon: Icons.mark_email_read_rounded, color: AppConfig.safeGreen),
          ],
        ),
        const SizedBox(height: 16),
        if (appState.latestComplaint != null)
          _ComplaintTrackerCard(
            complaint: appState.latestComplaint!,
            onSend: appState.latestComplaint!.sentToAuthority ? null : _sendLatestComplaint,
            onMarkRead: appState.latestComplaint!.sentToAuthority && !appState.latestComplaint!.readByAuthority ? _markLatestComplaintRead : null,
          ),
        if (appState.latestComplaint != null) const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File a structured complaint',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDistrict,
                      decoration: const InputDecoration(labelText: 'District'),
                      items: districtOptions
                          .map(
                            (district) => DropdownMenuItem(
                              value: district,
                              child: Text(district == 'ALL' ? 'All districts' : district),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        final nextDistrict = value;
                        final nextRoadOptions = _uniqueRoads(appState.roadsForDistrict(nextDistrict));
                        setState(() => _selectedDistrict = nextDistrict);
                        if (nextRoadOptions.isNotEmpty) {
                          appState.selectRoadNetworkItem(nextRoadOptions.first);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: (() {
                        if (selectedRoad == null) return null;
                        final key = _roadUniqueKey(selectedRoad);
                        final matches = roadOptions.where((r) => _roadUniqueKey(r) == key).length;
                        return matches == 1 ? key : null;
                      })(),
                      decoration: const InputDecoration(labelText: 'Road'),
                      items: roadOptions
                          .map(
                            (road) => DropdownMenuItem<String>(
                              key: ValueKey(_roadUniqueKey(road)),
                              value: _roadUniqueKey(road),
                              child: Text(road.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        final road = roadOptions.firstWhere((r) => _roadUniqueKey(r) == value);
                        appState.selectRoadNetworkItem(road);
                        if (_selectedDistrict == 'ALL' && road.districts.isNotEmpty) {
                          setState(() => _selectedDistrict = road.districts.first);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  selectedRoad != null
                      ? 'Filing against: ${selectedRoad.name} (district: ${selectedRoad.districts.isNotEmpty ? selectedRoad.districts.first : 'all'})'
                      : 'Select a road to file a complaint.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (appState.lastMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    appState.lastMessage!,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'All complaints',
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (complaints.isEmpty)
          appState.isLoading
              ? Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Loading complaints...', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                )
              : _EmptyComplaintsState(onCreate: _fileComplaint)
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...complaints.take(_displayedComplaintsCount).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ComplaintTimeline(complaint: item),
                );
              }),
              if (_displayedComplaintsCount < complaints.length) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _displayedComplaintsCount += 10;
                      });
                    },
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(
                      'Load more (${complaints.length - _displayedComplaintsCount} remaining)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

}

class _CountCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CountCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.72), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ComplaintTrackerCard extends StatelessWidget {
  final ComplaintItem complaint;
  final VoidCallback? onSend;
  final VoidCallback? onMarkRead;

  const _ComplaintTrackerCard({required this.complaint, required this.onSend, required this.onMarkRead});

  Widget _chip(BuildContext context, String label, bool active) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.secondary.withValues(alpha: 0.14) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? theme.colorScheme.secondary : theme.colorScheme.onSurface.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  int _stageIndex() {
    if (complaint.readByAuthority) {
      return 3;
    }
    if (complaint.deliveredToAuthority) {
      return 2;
    }
    if (complaint.sentToAuthority) {
      return 1;
    }
    return 0;
  }

  String _prettyDate(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) {
      return value;
    }
    return DateFormat('dd MMM, HH:mm').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stageIndex = _stageIndex();
    final stageLabels = ['Filed', 'Sent', 'Delivered', 'Read'];
    final stageIcons = [Icons.assignment_rounded, Icons.send_rounded, Icons.local_shipping_rounded, Icons.mark_email_read_rounded];
    final stageColors = [theme.colorScheme.tertiary, theme.colorScheme.secondary, AppConfig.cautionYellow, AppConfig.safeGreen];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onSurface.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live complaint tracker', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(complaint.id, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.72))),
                  ],
                ),
              ),
              _chip(context, complaint.status, true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(stageLabels.length, (index) {
              final active = index <= stageIndex;
              final color = active ? stageColors[index] : theme.colorScheme.onSurface.withValues(alpha: 0.28);
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Container(height: 3, color: index == 0 ? Colors.transparent : (index <= stageIndex ? stageColors[index] : theme.colorScheme.surfaceContainerHighest))),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: active ? color.withValues(alpha: 0.16) : theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 1.2),
                          ),
                          child: Icon(stageIcons[index], size: 14, color: color),
                        ),
                        Expanded(child: Container(height: 3, color: index == stageLabels.length - 1 ? Colors.transparent : (index < stageIndex ? stageColors[index + 1] : theme.colorScheme.surfaceContainerHighest))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(stageLabels[index], style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(complaint.description, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, 'Dept: ${complaint.recommendedDepartment}', false),
              _chip(context, 'Ticket: ${complaint.authorityTicket}', false),
              _chip(context, complaint.sentToAuthority ? 'Sent' : 'Queued', complaint.sentToAuthority),
              _chip(context, complaint.readByAuthority ? 'Read' : 'In review', complaint.readByAuthority),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            complaint.routingReason,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.74)),
          ),
          const SizedBox(height: 6),
          Text(
            'Filed ${_prettyDate(complaint.timestamp)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send to authority'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMarkRead,
                  icon: const Icon(Icons.mark_email_read_rounded),
                  label: const Text('Mark read'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyComplaintsState extends StatelessWidget {
  final Future<void> Function() onCreate;

  const _EmptyComplaintsState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No complaints tracked yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('File one complaint and it will appear here with live status updates.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.72))),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => onCreate(),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Create complaint'),
          ),
        ],
      ),
    );
  }
}
