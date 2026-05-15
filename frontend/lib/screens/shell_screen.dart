import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../features/accountability/accountability_screen.dart';
import '../features/budget/budget_forecasting_screen.dart';
import '../features/capture/capture_screen.dart';
import '../features/chatbot/chatbot_screen.dart';
import '../features/comparison/comparison_charts_screen.dart';
import '../features/complaints/complaints_screen.dart';
import '../features/gamification/gamification_leaderboard_screen.dart';
import '../features/map/map_screen.dart';
import '../features/intelligence/intelligence_screen.dart';
import '../features/maintenance/maintenance_scheduler_screen.dart';
import '../features/statistics/statistics_screen.dart';
import '../screens/contractors_screen.dart';
import '../screens/home_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  bool _requestedLiveLocation = false;

  static const _screens = [
    HomeScreen(),
    CaptureScreen(),
    ChatbotScreen(),
    ComplaintsScreen(),
    StatisticsScreen(),
    ComparisonChartsScreen(),
    AccountabilityScreen(),
    IntelligenceScreen(),
    MaintenanceSchedulerScreen(),
    ContractorsScreen(),
    BudgetForecastingScreen(),
    GamificationLeaderboardScreen(),
  ];

  static const _labels = ['Home', 'Capture', 'Assistant', 'Complaints', 'Statistics', 'Comparison', 'Accountability', 'Intelligence', 'Maintenance', 'Contractors', 'Budget', 'Gamification'];

  static const _icons = [
    Icons.map_rounded,
    Icons.camera_alt_rounded,
    Icons.chat_bubble_rounded,
    Icons.task_alt_rounded,
    Icons.bar_chart_rounded,
    Icons.compare_arrows_rounded,
    Icons.verified_user_rounded,
    Icons.insights_rounded,
    Icons.build_circle_rounded,
    Icons.person_rounded,
    Icons.trending_up_rounded,
    Icons.emoji_events_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _restoreLastScreen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requestedLiveLocation) {
        return;
      }
      _requestedLiveLocation = true;
      context.read<AppState>().requestLiveLocation();
    });
  }

  Future<void> _restoreLastScreen() async {
    final appState = context.read<AppState>();
    final lastIndex = await appState.localStorage.getLastScreenIndex();
    if (mounted && lastIndex != _index) {
      setState(() {
        _index = lastIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isWide = MediaQuery.sizeOf(context).width >= 1080;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.scaffoldBackgroundColor : null,
          gradient: isDark
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFF7FAFC), Color(0xFFEAF0F7), Color(0xFFFDFEFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: SafeArea(
          child: isWide
              ? Row(
                  children: [
                    _Sidebar(
                      currentIndex: _index,
                      isOnline: appState.isOnline,
                      realtimeLabel: appState.realtimeStatusLabel,
                      onDestinationSelected: (value) {
                        setState(() => _index = value);
                        appState.localStorage.saveLastScreenIndex(value);
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color ?? theme.colorScheme.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: _screens[_index],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : _screens[_index],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              elevation: 16,
              selectedIndex: _index,
              onDestinationSelected: (value) {
                setState(() => _index = value);
                context.read<AppState>().localStorage.saveLastScreenIndex(value);
              },
              indicatorColor: AppConfig.deepNavy.withValues(alpha: 0.12),
              destinations: _labels.asMap().entries.map((entry) {
                final index = entry.key;
                return NavigationDestination(
                  icon: Icon(_icons[index]),
                  label: entry.value,
                );
              }).toList(),
            ),
      floatingActionButton: appState.isOnline
          ? null
          : FloatingActionButton.extended(
              onPressed: () => appState.syncOfflineData(),
              backgroundColor: AppConfig.cautionYellow,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Offline Data'),
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final bool isOnline;
  final String realtimeLabel;
  final ValueChanged<int> onDestinationSelected;

  const _Sidebar({
    required this.currentIndex,
    required this.isOnline,
    required this.realtimeLabel,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sidebarHeight = MediaQuery.sizeOf(context).height - 40;
    final theme = Theme.of(context);

    return Container(
      width: 288,
      height: sidebarHeight,
      margin: const EdgeInsets.fromLTRB(20, 20, 0, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onSurface.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF102A43), Color(0xFF1D4E89)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.route_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RoadWatch AI',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'Civic road intelligence',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatusChip(label: isOnline ? 'Online' : 'Offline', active: isOnline, icon: Icons.cloud_done_rounded),
          const SizedBox(height: 8),
          _StatusChip(label: realtimeLabel, active: realtimeLabel.contains('connected'), icon: Icons.wifi_tethering_rounded),
          const SizedBox(height: 18),
          _SidebarItem(icon: Icons.map_rounded, label: 'Home', selected: currentIndex == 0, onTap: () => onDestinationSelected(0)),
          _SidebarItem(icon: Icons.camera_alt_rounded, label: 'Capture', selected: currentIndex == 1, onTap: () => onDestinationSelected(1)),
          _SidebarItem(icon: Icons.chat_bubble_rounded, label: 'Assistant', selected: currentIndex == 2, onTap: () => onDestinationSelected(2)),
          _SidebarItem(icon: Icons.task_alt_rounded, label: 'Complaints', selected: currentIndex == 3, onTap: () => onDestinationSelected(3)),
          _SidebarItem(icon: Icons.bar_chart_rounded, label: 'Statistics', selected: currentIndex == 4, onTap: () => onDestinationSelected(4)),
          _SidebarItem(icon: Icons.compare_arrows_rounded, label: 'Comparison', selected: currentIndex == 5, onTap: () => onDestinationSelected(5)),
          _SidebarItem(icon: Icons.verified_user_rounded, label: 'Accountability', selected: currentIndex == 6, onTap: () => onDestinationSelected(6)),
          _SidebarItem(icon: Icons.insights_rounded, label: 'Intelligence', selected: currentIndex == 7, onTap: () => onDestinationSelected(7)),
          _SidebarItem(icon: Icons.build_circle_rounded, label: 'Maintenance', selected: currentIndex == 8, onTap: () => onDestinationSelected(8)),
          _SidebarItem(icon: Icons.person_rounded, label: 'Contractors', selected: currentIndex == 9, onTap: () => onDestinationSelected(9)),
          _SidebarItem(icon: Icons.trending_up_rounded, label: 'Budget', selected: currentIndex == 10, onTap: () => onDestinationSelected(10)),
          _SidebarItem(icon: Icons.emoji_events_rounded, label: 'Gamification', selected: currentIndex == 11, onTap: () => onDestinationSelected(11)),
        ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;

  const _StatusChip({required this.label, required this.active, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: active ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12) : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: active ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
