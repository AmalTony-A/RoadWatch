import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';

class GamificationLeaderboardScreen extends StatefulWidget {
  const GamificationLeaderboardScreen({super.key});

  @override
  State<GamificationLeaderboardScreen> createState() => _GamificationLeaderboardScreenState();
}

class _GamificationLeaderboardScreenState extends State<GamificationLeaderboardScreen> {
  String _selectedLeaderboard = 'Top Reporters';
  final Set<String> _unlockedBadges = {'quick_start', 'reporter_pro', 'on_fire'};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(theme),
            const SizedBox(height: 20),
            _buildQuickStats(state),
            const SizedBox(height: 20),
            _buildLeaderboardSelector(),
            const SizedBox(height: 20),
            _buildProfileCard(context, state),
            const SizedBox(height: 24),
            _buildPodiumSection(context),
            const SizedBox(height: 24),
            _buildLeaderboardList(context),
            const SizedBox(height: 24),
            _buildBadgesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConfig.deepNavy.withValues(alpha: 0.96),
            const Color(0xFF143457),
            AppConfig.deepNavy.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppConfig.deepNavy.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Center(child: Text('🎮', style: TextStyle(fontSize: 34))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gamification & Leaderboards',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Climb the leaderboard, unlock badges, and celebrate wins.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(AppState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final statWidth = width < 700 ? width : (width - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: statWidth,
              child: const _QuickStatCard(
                icon: '⭐',
                label: 'Your Streak',
                value: '12 days',
                color: AppConfig.cautionYellow,
              ),
            ),
            SizedBox(
              width: statWidth,
              child: const _QuickStatCard(
                icon: '🏆',
                label: 'Rank',
                value: '#47',
                color: AppConfig.deepNavy,
              ),
            ),
            SizedBox(
              width: statWidth,
              child: _QuickStatCard(
                icon: '💎',
                label: 'Total Points',
                value: state.userPoints.toString(),
                color: AppConfig.safeGreen,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeaderboardSelector() {
    const chips = ['Top Reporters', 'Active Contributors', 'Verified Reports', 'This Month'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((label) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _HoverPillChip(
              label: label,
              selected: _selectedLeaderboard == label,
              onTap: () => setState(() => _selectedLeaderboard = label),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConfig.deepNavy.withValues(alpha: 0.16),
                      AppConfig.deepNavy.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(child: Text('👤', style: TextStyle(fontSize: 34))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Profile',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppConfig.deepNavy,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Expanded(child: _StatItem('Rank', '#47', AppConfig.deepNavy)),
                        Expanded(child: _StatItem('Points', '2,850', AppConfig.safeGreen)),
                        Expanded(child: _StatItem('Reports', '23', AppConfig.cautionYellow)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                icon: Icons.card_giftcard_rounded,
                label: 'Claim Reward',
                onTap: () {
                  state.addPoints(50);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🎁 +50 bonus points!')),
                  );
                },
              ),
              _ActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shared your achievement!')),
                  );
                },
              ),
              _ActionButton(
                icon: Icons.people_rounded,
                label: 'Challenge',
                onTap: () {
                  state.addPoints(25);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Challenge sent! +25 points')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🏆 Top Performers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppConfig.deepNavy,
              ),
        ),
        const SizedBox(height: 16),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _PodiumPlace(rank: 2, name: 'Sarah Chen', points: 4250, height: 124, medal: '🥈')),
            SizedBox(width: 10),
            Expanded(child: _PodiumPlace(rank: 1, name: 'Rajesh Kumar', points: 4890, height: 168, medal: '🥇')),
            SizedBox(width: 10),
            Expanded(child: _PodiumPlace(rank: 3, name: 'Priya Singh', points: 3950, height: 108, medal: '🥉')),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaderboardList(BuildContext context) {
    final reporters = _generateReporters();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Leaderboard',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🎖️ Available Badges',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
            ),
            Chip(
              backgroundColor: AppConfig.deepNavy.withValues(alpha: 0.08),
              label: Text('${_unlockedBadges.length}/6 Unlocked'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _BadgeCard(
              emoji: '🚀',
              title: 'Quick Start',
              description: 'Report 1 issue',
              unlocked: _unlockedBadges.contains('quick_start'),
              onTap: () => _unlockBadge(context, 'quick_start', '🚀 Quick Start badge unlocked!'),
            ),
            _BadgeCard(
              emoji: '⭐',
              title: 'Reporter Pro',
              description: 'Report 10 issues',
              unlocked: _unlockedBadges.contains('reporter_pro'),
              onTap: () => _unlockBadge(context, 'reporter_pro', '⭐ Reporter Pro badge unlocked!'),
            ),
            _BadgeCard(
              emoji: '👑',
              title: 'Legendary',
              description: 'Top 10 all-time',
              unlocked: _unlockedBadges.contains('legendary'),
              onTap: () => _unlockBadge(context, 'legendary', '👑 Legendary badge unlocked!'),
            ),
            _BadgeCard(
              emoji: '🎯',
              title: 'Accuracy Master',
              description: '95% verified',
              unlocked: _unlockedBadges.contains('accuracy_master'),
              onTap: () => _unlockBadge(context, 'accuracy_master', '🎯 Accuracy Master badge unlocked!'),
            ),
            _BadgeCard(
              emoji: '🔥',
              title: 'On Fire',
              description: '5 reports this week',
              unlocked: _unlockedBadges.contains('on_fire'),
              onTap: () => _unlockBadge(context, 'on_fire', '🔥 On Fire badge unlocked!'),
            ),
            _BadgeCard(
              emoji: '💎',
              title: 'Elite Member',
              description: '500 total points',
              unlocked: _unlockedBadges.contains('elite_member'),
              onTap: () => _unlockBadge(context, 'elite_member', '💎 Elite Member badge unlocked!'),
            ),
          ],
        ),
      ],
    );
  }

  void _unlockBadge(BuildContext context, String badgeId, String message) {
    setState(() => _unlockedBadges.add(badgeId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

class _HoverPillChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HoverPillChip({required this.label, required this.selected, required this.onTap});

  @override
  State<_HoverPillChip> createState() => _HoverPillChipState();
}

class _HoverPillChipState extends State<_HoverPillChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: FilterChip(
          label: Text(widget.label),
          selected: widget.selected,
          onSelected: (_) => widget.onTap(),
          backgroundColor: widget.selected
              ? AppConfig.deepNavy
              : (_hovered ? AppConfig.deepNavy.withValues(alpha: 0.12) : Colors.grey.shade100),
          selectedColor: AppConfig.deepNavy,
          labelStyle: TextStyle(
            color: widget.selected ? Colors.white : AppConfig.deepNavy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppConfig.deepNavy.withValues(alpha: _pressed ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppConfig.deepNavy.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _pressed ? 0.02 : 0.06),
                  blurRadius: _pressed ? 4 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: AppConfig.deepNavy),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatefulWidget {
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
  State<_LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<_LeaderboardRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hovered ? AppConfig.deepNavy.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovered ? AppConfig.deepNavy.withValues(alpha: 0.18) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.08 : 0.04),
              blurRadius: _hovered ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppConfig.deepNavy.withValues(alpha: 0.18),
                    AppConfig.deepNavy.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '#${widget.rank}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
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
                      Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      if (widget.badge != null) ...[
                        const SizedBox(width: 8),
                        Text(widget.badge!, style: const TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.reports} reports',
                    style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${widget.points}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                ),
                Text('pts', style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String description;
  final bool unlocked;
  final VoidCallback onTap;

  const _BadgeCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.onTap,
  });

  @override
  State<_BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<_BadgeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.unlocked
                ? AppConfig.deepNavy.withValues(alpha: _hovered ? 0.14 : 0.1)
                : Colors.grey.withValues(alpha: _hovered ? 0.14 : 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.unlocked
                  ? AppConfig.deepNavy.withValues(alpha: _hovered ? 0.4 : 0.22)
                  : Colors.grey.withValues(alpha: 0.18),
            ),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _hovered ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 160),
                child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: widget.unlocked ? AppConfig.deepNavy : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: widget.unlocked
                      ? AppConfig.skySlate.withValues(alpha: 0.75)
                      : Colors.grey.withValues(alpha: 0.6),
                ),
              ),
              if (!widget.unlocked) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppConfig.cautionYellow.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Locked',
                    style: TextStyle(fontSize: 8, color: AppConfig.cautionYellow, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PodiumPlace extends StatefulWidget {
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
  State<_PodiumPlace> createState() => _PodiumPlaceState();
}

class _PodiumPlaceState extends State<_PodiumPlace> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConfig.deepNavy.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(widget.medal, style: const TextStyle(fontSize: 30)),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: widget.height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppConfig.deepNavy.withValues(alpha: _hovered ? 0.36 : 0.28),
                        AppConfig.deepNavy.withValues(alpha: _hovered ? 0.12 : 0.08),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border.all(color: AppConfig.deepNavy.withValues(alpha: 0.22)),
                    boxShadow: [
                      if (_hovered)
                        BoxShadow(
                          color: AppConfig.deepNavy.withValues(alpha: 0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '#${widget.rank}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.points} pts',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_hovered)
              Positioned(
                top: 6,
                right: -4,
                child: Material(
                  color: Colors.transparent,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.deepNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                    label: const Text('Congratulate', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
