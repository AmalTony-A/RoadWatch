import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import 'capture_screen.dart';
import 'chatbot_screen.dart';
import 'complaints_screen.dart';
import 'home_screen.dart';
import 'intelligence_screen.dart';

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
    IntelligenceScreen(),
  ];

  static const _labels = ['Home', 'Capture', 'Assistant', 'Complaints', 'Intelligence'];

  static const _icons = [
    Icons.map_rounded,
    Icons.camera_alt_rounded,
    Icons.chat_bubble_rounded,
    Icons.task_alt_rounded,
    Icons.insights_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requestedLiveLocation) {
        return;
      }
      _requestedLiveLocation = true;
      context.read<AppState>().requestLiveLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isWide = MediaQuery.sizeOf(context).width >= 1080;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
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
                      onDestinationSelected: (value) => setState(() => _index = value),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConfig.deepNavy.withValues(alpha: 0.08),
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
              onDestinationSelected: (value) => setState(() => _index = value),
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
    return Container(
      width: 288,
      margin: const EdgeInsets.fromLTRB(20, 20, 0, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: AppConfig.deepNavy.withValues(alpha: 0.07),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: AppConfig.deepNavy,
                          ),
                    ),
                    Text(
                      'Civic road intelligence',
                      style: TextStyle(
                        color: AppConfig.skySlate.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
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
          Expanded(
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              indicatorColor: AppConfig.deepNavy.withValues(alpha: 0.10),
              minWidth: 80,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.map_rounded), label: Text('Home')),
                NavigationRailDestination(icon: Icon(Icons.camera_alt_rounded), label: Text('Capture')),
                NavigationRailDestination(icon: Icon(Icons.chat_bubble_rounded), label: Text('Assistant')),
                NavigationRailDestination(icon: Icon(Icons.task_alt_rounded), label: Text('Complaints')),
                NavigationRailDestination(icon: Icon(Icons.insights_rounded), label: Text('Intelligence')),
              ],
            ),
          ),
        ],
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
        color: active ? const Color(0xFFEAF8EF) : const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: active ? AppConfig.safeGreen : AppConfig.cautionYellow),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppConfig.safeGreen : const Color(0xFF9A6A00),
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
