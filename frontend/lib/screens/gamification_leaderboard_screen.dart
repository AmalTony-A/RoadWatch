import 'package:flutter/material.dart';

import '../config/app_config.dart';

class GamificationLeaderboardScreen extends StatefulWidget {
  const GamificationLeaderboardScreen({super.key});

  @override
  State<GamificationLeaderboardScreen> createState() => _GamificationLeaderboardScreenState();
}

class _GamificationLeaderboardScreenState extends State<GamificationLeaderboardScreen> {
  String _selectedLeaderboard = 'Top Reporters';

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
              '🎮 Gamification & Leaderboards',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Leaderboards + badges for reporters',
              style: TextStyle(color: AppConfig.skySlate.withValues(alpha: 0.8), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Leaderboard Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _LeaderboardButton('Top Reporters', _selectedLeaderboard == 'Top Reporters', () {
                    setState(() => _selectedLeaderboard = 'Top Reporters');
                  }),
                  const SizedBox(width: 8),
                  _LeaderboardButton('Active Contributors', _selectedLeaderboard == 'Active Contributors', () {
                    setState(() => _selectedLeaderboard = 'Active Contributors');
                  }),
                  const SizedBox(width: 8),
                  _LeaderboardButton('Verified Reports', _selectedLeaderboard == 'Verified Reports', () {
                    setState(() => _selectedLeaderboard = 'Verified Reports');
                  }),
                  const SizedBox(width: 8),
                  _LeaderboardButton('This Month', _selectedLeaderboard == 'This Month', () {
                    setState(() => _selectedLeaderboard = 'This Month');
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // User Stats Card
            _buildUserStatsCard(context),
            const SizedBox(height: 24),

            // Top 3 Podium
            _buildPodium(context),
            const SizedBox(height: 24),

            // Full Leaderboard
            _buildFullLeaderboard(context),
            const SizedBox(height: 24),

            // Badges Section
            _buildBadgesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConfig.deepNavy.withValues(alpha: 0.15), AppConfig.deepNavy.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConfig.deepNavy.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppConfig.deepNavy.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                '👤',
                style: TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Stats',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppConfig.deepNavy,
                      ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Expanded(
                      child: _StatItem('Rank', '#47', AppConfig.deepNavy),
                    ),
                    Expanded(
                      child: _StatItem('Points', '2,850', AppConfig.safeGreen),
                    ),
                    Expanded(
                      child: _StatItem('Reports', '23', AppConfig.cautionYellow),
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

  Widget _buildPodium(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Performers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppConfig.deepNavy,
              ),
        ),
        const SizedBox(height: 16),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd Place
            Expanded(
              child: _PodiumPlace(
                rank: 2,
                name: 'Sarah Chen',
                points: 4250,
                height: 120,
                medal: '🥈',
              ),
            ),
            SizedBox(width: 8),
            // 1st Place
            Expanded(
              child: _PodiumPlace(
                rank: 1,
                name: 'Rajesh Kumar',
                points: 4890,
                height: 160,
                medal: '🥇',
              ),
            ),
            SizedBox(width: 8),
            // 3rd Place
            Expanded(
              child: _PodiumPlace(
                rank: 3,
                name: 'Priya Singh',
                points: 3950,
                height: 100,
                medal: '🥉',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullLeaderboard(BuildContext context) {
    final reporters = _generateReporters();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Leaderboard',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppConfig.deepNavy,
              ),
        ),
        const SizedBox(height: 16),
        ...reporters.asMap().entries.map((entry) {
          final index = entry.key;
          final reporter = entry.value;
          return _LeaderboardRow(
            rank: index + 4,
            name: reporter['name'] as String,
            points: reporter['points'] as int,
            reports: reporter['reports'] as int,
            badge: reporter['badge'] as String?,
          );
        }),
      ],
    );
  }

  Widget _buildBadgesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Badges',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppConfig.deepNavy,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: const [
            _BadgeCard('🚀', 'Quick Start', 'Report 1 issue', true),
            _BadgeCard('⭐', 'Reporter Pro', 'Report 10 issues', true),
            _BadgeCard('👑', 'Legendary', 'Top 10 all-time', false),
            _BadgeCard('🎯', 'Accuracy Master', '95% verified', false),
            _BadgeCard('🔥', 'On Fire', '5 reports this week', true),
            _BadgeCard('💎', 'Elite Member', '500 total points', false),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _generateReporters() {
    return [
      {'name': 'Ananya Sharma', 'points': 3450, 'reports': 28, 'badge': '⭐'},
      {'name': 'Vikram Patel', 'points': 3200, 'reports': 25, 'badge': null},
      {'name': 'Neha Gupta', 'points': 2950, 'reports': 22, 'badge': null},
      {'name': 'Arjun Singh', 'points': 2750, 'reports': 20, 'badge': '🔥'},
      {'name': 'Meera Nair', 'points': 2500, 'reports': 18, 'badge': null},
      {'name': 'Others (420+)', 'points': 1200, 'reports': 8, 'badge': null},
    ];
  }
}

class _LeaderboardButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LeaderboardButton(this.label, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
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
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final int rank;
  final String name;
  final int points;
  final double height;
  final String medal;

  const _PodiumPlace({
    required this.rank,
    required this.name,
    required this.points,
    required this.height,
    required this.medal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConfig.deepNavy.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            medal,
            style: const TextStyle(fontSize: 32),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConfig.deepNavy.withValues(alpha: 0.3),
                AppConfig.deepNavy.withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: AppConfig.deepNavy.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppConfig.deepNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                '$points pts',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppConfig.deepNavy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final int points;
  final int reports;
  final String? badge;

  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.points,
    required this.reports,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppConfig.deepNavy.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppConfig.deepNavy,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Text(badge!, style: const TextStyle(fontSize: 14)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$reports reports',
                  style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          Text(
            '$points',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppConfig.deepNavy,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'pts',
            style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final bool unlocked;

  const _BadgeCard(this.emoji, this.title, this.description, this.unlocked);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? AppConfig.deepNavy.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? AppConfig.deepNavy.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: unlocked ? AppConfig.deepNavy : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: unlocked ? AppConfig.skySlate.withValues(alpha: 0.7) : Colors.grey.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
