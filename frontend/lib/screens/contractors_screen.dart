import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/contractor.dart';
import '../providers/app_state.dart';
import '../screens/contractor_rating_form_screen.dart';

class ContractorsScreen extends StatefulWidget {
  const ContractorsScreen({super.key});

  @override
  State<ContractorsScreen> createState() => _ContractorsScreenState();
}

class _ContractorsScreenState extends State<ContractorsScreen> {
  late TextEditingController _searchController;
  String _sortBy = 'highest_rated';
  final Set<String> _hoveredContractorIds = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final searchQuery = _searchController.text;
    final contractors = searchQuery.isEmpty
        ? state.getContractorsSortedBy(_sortBy)
        : state.searchContractors(searchQuery);

    return ListView(
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
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contractor Directory',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'View contractor ratings, reviews, and project history.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Search Bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search contractors...',
            prefixIcon: const Icon(Icons.search, color: AppConfig.deepNavy),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
        const SizedBox(height: 16),

        // Sort/Filter Options
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSortChip('Highest Rated', 'highest_rated'),
              const SizedBox(width: 8),
              _buildSortChip('Most Complaints', 'most_complaints'),
              const SizedBox(width: 8),
              _buildSortChip('Recently Reviewed', 'recently_reviewed'),
              const SizedBox(width: 8),
              _buildSortChip('Trusted Badges', 'trusted_badge'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stats Overview
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Contractors',
                value: state.contractors.length.toString(),
                icon: Icons.business,
                color: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Avg Rating',
                value: state.contractors.isEmpty
                    ? 'N/A'
                    : '${(state.contractors.fold<double>(0, (sum, c) => sum + c.overallRating) / state.contractors.length).toStringAsFixed(1)}/5',
                icon: Icons.star,
                color: AppConfig.cautionYellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Contractors List
        if (contractors.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No contractors found matching "$searchQuery"'),
            ),
          )
        else
          ...contractors.map((contractor) => _buildContractorCard(context, contractor)),
      ],
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = value;
          });
        }
      },
      backgroundColor: Colors.white,
      selectedColor: AppConfig.deepNavy,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppConfig.deepNavy,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppConfig.deepNavy.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppConfig.deepNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractorCard(BuildContext context, Contractor contractor) {
    final ratingColor = _getRatingColor(contractor.overallRating);
    final isHovered = _hoveredContractorIds.contains(contractor.id);

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hoveredContractorIds.add(contractor.id);
        });
      },
      onExit: (_) {
        setState(() {
          _hoveredContractorIds.remove(contractor.id);
        });
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showContractorDetail(context, contractor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(bottom: 12, top: isHovered ? 4 : 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xFFFAFBFC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? AppConfig.deepNavy : const Color(0xFFE2E8F0),
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered
                    ? AppConfig.deepNavy.withValues(alpha: 0.12)
                    : AppConfig.deepNavy.withValues(alpha: 0.04),
                blurRadius: isHovered ? 20 : 12,
                offset: Offset(0, isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                contractor.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isHovered ? AppConfig.deepNavy : AppConfig.deepNavy,
                                  letterSpacing: isHovered ? 0.3 : 0,
                                ),
                              ),
                            ),
                            if (contractor.trustedBadge.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: contractor.trustedBadge == 'gold'
                                      ? const Color(0xFFFFD700)
                                      : contractor.trustedBadge == 'silver'
                                          ? const Color(0xFFC0C0C0)
                                          : const Color(0xFFCD7F32),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '✓ ${contractor.trustedBadge.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contractor.company,
                          style: TextStyle(
                            fontSize: 12,
                            color: isHovered ? AppConfig.deepNavy.withValues(alpha: 0.7) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rating Badge - Animated
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? ratingColor.withValues(alpha: 0.15)
                          : ratingColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: isHovered
                          ? Border.all(color: ratingColor, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          contractor.overallRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: isHovered ? 20 : 18,
                            fontWeight: FontWeight.w800,
                            color: ratingColor,
                          ),
                        ),
                        const Text(
                          '/5',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Project Status & Complaints
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                    icon: Icons.construction,
                    label: contractor.projectStatus,
                    color: _getStatusColor(contractor.projectStatus),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    icon: Icons.warning,
                    label: '${contractor.complaintCount} complaints',
                    color: contractor.complaintCount > 3 ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reviews',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contractor.totalReviews.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppConfig.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Roads Managed',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contractor.roadsManaged.length.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppConfig.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transparency',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${contractor.publicTransparencyScore.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppConfig.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return const Color(0xFF10B981); // green
    if (rating >= 2.5) return const Color(0xFFF59E0B); // yellow
    return const Color(0xFFEF4444); // red
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF3B82F6);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _showContractorDetail(BuildContext context, Contractor contractor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _buildContractorDetail(
          scrollController,
          contractor,
        ),
      ),
    );
  }

  Widget _buildContractorDetail(ScrollController scrollController, Contractor contractor) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Contractor Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contractor.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppConfig.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contractor.company,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getRatingColor(contractor.overallRating).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.star, color: _getRatingColor(contractor.overallRating)),
                  const SizedBox(height: 4),
                  Text(
                    contractor.overallRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _getRatingColor(contractor.overallRating),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Rate Now Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.deepNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close the modal
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ContractorRatingFormScreen(
                    contractor: contractor,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.rate_review),
            label: const Text(
              'Rate This Contractor',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Reviews Section
        const Text(
          'Recent Reviews',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppConfig.deepNavy,
          ),
        ),
        const SizedBox(height: 12),
        if (contractor.reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No reviews yet'),
          )
        else
          ...contractor.reviews.map((review) => _buildReviewCard(review)),
      ],
    );
  }

  Widget _buildReviewCard(ContractorReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.emotionEmoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppConfig.deepNavy,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            Icons.star,
                            size: 12,
                            color: i < review.rating ? Colors.amber : const Color(0xFFE2E8F0),
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          review.sentiment,
                          style: TextStyle(
                            fontSize: 10,
                            color: review.sentiment == 'positive'
                                ? const Color(0xFF10B981)
                                : review.sentiment == 'negative'
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.reviewText,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
