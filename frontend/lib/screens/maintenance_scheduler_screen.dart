import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/road_segment.dart';
import '../providers/app_state.dart';

class MaintenanceSchedulerScreen extends StatefulWidget {
  const MaintenanceSchedulerScreen({super.key});

  @override
  State<MaintenanceSchedulerScreen> createState() => _MaintenanceSchedulerScreenState();
}

class _MaintenanceSchedulerScreenState extends State<MaintenanceSchedulerScreen> {
  String _filterType = 'All';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              '🔧 Maintenance Scheduler',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Schedule and track road maintenance activities',
              style: TextStyle(color: AppConfig.skySlate.withValues(alpha: 0.8), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Filters and Controls
            Row(
              children: [
                Expanded(
                  child: _buildFilterChip('All', _filterType == 'All', () => setState(() => _filterType = 'All')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterChip('Scheduled', _filterType == 'Scheduled', () => setState(() => _filterType = 'Scheduled')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterChip('In Progress', _filterType == 'In Progress', () => setState(() => _filterType = 'In Progress')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterChip('Completed', _filterType == 'Completed', () => setState(() => _filterType = 'Completed')),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Statistics Cards
            _buildStatsRow(context),
            const SizedBox(height: 24),

            // Maintenance Schedule List
            Consumer<AppState>(builder: (context, appState, _) {
              final roads = appState.roads;
              final maintenanceItems = _generateMaintenanceSchedule(roads);

              return Column(
                children: [
                  Text(
                    'Upcoming Maintenance',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppConfig.deepNavy,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ...maintenanceItems.map((item) => _MaintenanceCard(
                        date: item['date'] as DateTime,
                        roadName: item['road'] as String,
                        roadType: item['type'] as String,
                        status: item['status'] as String,
                        location: item['location'] as String,
                        contractor: item['contractor'] as String,
                        budget: item['budget'] as int,
                      )),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey[100],
      selectedColor: AppConfig.deepNavy.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppConfig.deepNavy : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Scheduled',
            value: '12',
            subtitle: 'This month',
            icon: Icons.calendar_today,
            color: AppConfig.deepNavy,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'In Progress',
            value: '8',
            subtitle: 'Active now',
            icon: Icons.construction,
            color: AppConfig.cautionYellow,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Completed',
            value: '45',
            subtitle: 'This quarter',
            icon: Icons.check_circle,
            color: AppConfig.safeGreen,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _generateMaintenanceSchedule(List<RoadSegment> roads) {
    final schedule = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 0; i < (roads.length ~/ 10).clamp(0, 15); i++) {
      final road = roads[i % roads.length];
      final statusOptions = ['Scheduled', 'In Progress', 'Completed'];
      final status = statusOptions[i % 3];

      schedule.add({
        'date': now.add(Duration(days: i * 3)),
        'road': road.name,
        'type': road.ward,
        'status': status,
        'location': road.ward,
        'contractor': 'Maintenance Team ${i % 5 + 1}',
        'budget': (40 + road.roadHealthScore + road.nearbyIssues + road.recentComplaints) * 5,
      });
    }

    return schedule;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppConfig.deepNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppConfig.skySlate.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatefulWidget {
  final DateTime date;
  final String roadName;
  final String roadType;
  final String status;
  final String location;
  final String contractor;
  final int budget;

  const _MaintenanceCard({
    required this.date,
    required this.roadName,
    required this.roadType,
    required this.status,
    required this.location,
    required this.contractor,
    required this.budget,
  });

  @override
  State<_MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends State<_MaintenanceCard> {
  bool _expanded = false;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return AppConfig.deepNavy;
      case 'In Progress':
        return AppConfig.cautionYellow;
      case 'Completed':
        return AppConfig.safeGreen;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.status,
                    style: TextStyle(
                      color: _getStatusColor(widget.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roadName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('MMM dd, yyyy').format(widget.date)} • ${widget.location}',
                        style: TextStyle(fontSize: 12, color: AppConfig.skySlate.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _DetailRow('Road Type', widget.roadType),
                  const SizedBox(height: 8),
                  _DetailRow('Contractor', widget.contractor),
                  const SizedBox(height: 8),
                  _DetailRow('Budget', '₹${widget.budget} Cr'),
                  const SizedBox(height: 8),
                  const _DetailRow('Duration', '7-14 days'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          child: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Update Status'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppConfig.skySlate.withValues(alpha: 0.7))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
