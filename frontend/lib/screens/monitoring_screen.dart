import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic> _dashboardStats = {};
  List<dynamic> _activityLog = [];
  Map<String, dynamic> _systemInfo = {};
  Map<String, dynamic> _complaintsBreakdown = {};
  bool _isLoading = false;
  String _selectedTab = 'overview';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      
      // Fetch dashboard stats
      if (_selectedTab == 'overview') {
        _dashboardStats = await appState.api.get('/api/admin/dashboard-stats') ?? {};
      } else if (_selectedTab == 'activity') {
        final res = await appState.api.get('/api/admin/activity-log?limit=100') ?? {};
        _activityLog = res['activities'] ?? [];
      } else if (_selectedTab == 'system') {
        _systemInfo = await appState.api.get('/api/admin/system-info') ?? {};
      } else if (_selectedTab == 'complaints') {
        _complaintsBreakdown = await appState.api.get('/api/admin/complaints-breakdown') ?? {};
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        // Header
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
                child: const Icon(Icons.dashboard_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Monitoring',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time backend activity tracking',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tab Buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _TabButton(
                label: 'Overview',
                isActive: _selectedTab == 'overview',
                onPressed: () {
                  setState(() => _selectedTab = 'overview');
                  _loadData();
                },
              ),
              const SizedBox(width: 10),
              _TabButton(
                label: 'Activity Log',
                isActive: _selectedTab == 'activity',
                onPressed: () {
                  setState(() => _selectedTab = 'activity');
                  _loadData();
                },
              ),
              const SizedBox(width: 10),
              _TabButton(
                label: 'Complaints',
                isActive: _selectedTab == 'complaints',
                onPressed: () {
                  setState(() => _selectedTab = 'complaints');
                  _loadData();
                },
              ),
              const SizedBox(width: 10),
              _TabButton(
                label: 'System',
                isActive: _selectedTab == 'system',
                onPressed: () {
                  setState(() => _selectedTab = 'system');
                  _loadData();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Refresh Button
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _loadData,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        const SizedBox(height: 20),

        // Content based on selected tab
        if (_isLoading)
          Padding(
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
                Text('Loading...', style: theme.textTheme.bodyMedium),
              ],
            ),
          )
        else if (_selectedTab == 'overview')
          _buildOverviewTab(theme)
        else if (_selectedTab == 'activity')
          _buildActivityTab(theme)
        else if (_selectedTab == 'complaints')
          _buildComplaintsTab(theme)
        else if (_selectedTab == 'system')
          _buildSystemTab(theme),
      ],
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    final stats = _dashboardStats;
    final complaints = stats['complaints'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard Statistics',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              label: 'Total Complaints',
              value: '${complaints['total'] ?? 0}',
              icon: Icons.feedback_rounded,
              color: theme.colorScheme.primary,
            ),
            _StatCard(
              label: 'Filed',
              value: '${complaints['filed'] ?? 0}',
              icon: Icons.assignment_rounded,
              color: Colors.orange,
            ),
            _StatCard(
              label: 'Sent',
              value: '${complaints['sent'] ?? 0}',
              icon: Icons.send_rounded,
              color: Colors.blue,
            ),
            _StatCard(
              label: 'Delivered',
              value: '${complaints['delivered'] ?? 0}',
              icon: Icons.local_shipping_rounded,
              color: Colors.green,
            ),
            _StatCard(
              label: 'Read',
              value: '${complaints['read'] ?? 0}',
              icon: Icons.mail_outline_rounded,
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityTab(ThemeData theme) {
    if (_activityLog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No activities logged yet',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activities',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ..._activityLog.take(50).map((activity) {
          final timestamp = DateTime.tryParse(activity['timestamp'] ?? '');
          final timeStr = timestamp != null
              ? DateFormat('MMM d, HH:mm:ss').format(timestamp)
              : 'Unknown time';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  width: 4,
                  color: _getActivityColor(activity['type']),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getActivityColor(activity['type']).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        activity['type'],
                        style: TextStyle(
                          fontSize: 0.8 * (theme.textTheme.bodySmall?.fontSize ?? 12),
                          fontWeight: FontWeight.w600,
                          color: _getActivityColor(activity['type']),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      timeStr,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activity['description'],
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildComplaintsTab(ThemeData theme) {
    final breakdown = _complaintsBreakdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complaints Breakdown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Overall',
          items: {
            'Total': '${breakdown['total'] ?? 0}',
          },
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'By Status',
          items: Map<String, String>.from(
            (breakdown['by_status'] as Map?)?.map((k, v) => MapEntry(k, '$v')) ?? {},
          ),
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Delivery Status',
          items: {
            'Sent': '${breakdown['by_sent_status']?['sent'] ?? 0}',
            'Not Sent': '${breakdown['by_sent_status']?['not_sent'] ?? 0}',
            'Delivered': '${breakdown['by_delivery']?['delivered'] ?? 0}',
            'Not Delivered': '${breakdown['by_delivery']?['not_delivered'] ?? 0}',
          },
        ),
      ],
    );
  }

  Widget _buildSystemTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Information',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Status',
          items: {
            'Demo Mode': '${_systemInfo['demo_mode'] ?? false ? 'ON' : 'OFF'}',
            'Database': '${_systemInfo['database_type'] ?? 'Unknown'}',
            'Connected': '${_systemInfo['database_connected'] ?? false ? 'Yes' : 'No'}',
          },
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Data Sources',
          items: Map<String, String>.from(
            (_systemInfo['data_sources'] as Map?)?.map((k, v) => MapEntry(k, '$v')) ?? {},
          ),
        ),
      ],
    );
  }

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'complaint':
        return Colors.orange;
      case 'detection':
        return Colors.blue;
      case 'prediction':
        return Colors.green;
      case 'upload':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? theme.colorScheme.primary : Colors.transparent,
        foregroundColor: isActive ? Colors.white : theme.colorScheme.primary,
        side: BorderSide(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.primary,
        ),
      ),
      child: Text(label),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Map<String, String> items;

  const _InfoCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...items.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  Text(
                    e.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
