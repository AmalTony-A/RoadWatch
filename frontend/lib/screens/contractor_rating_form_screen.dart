import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/contractor.dart';
import '../providers/app_state.dart';

class ContractorRatingFormScreen extends StatefulWidget {
  final Contractor contractor;

  const ContractorRatingFormScreen({
    super.key,
    required this.contractor,
  });

  @override
  State<ContractorRatingFormScreen> createState() => _ContractorRatingFormScreenState();
}

class _ContractorRatingFormScreenState extends State<ContractorRatingFormScreen> {
  late TextEditingController _reviewController;
  int _selectedRating = 0;
  String _selectedEmoji = '';
  bool _isSubmitting = false;

  final Map<String, String> _emojiMap = {
    'positive': '😊',
    'neutral': '😐',
    'negative': '😠',
  };

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rate Contractor'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConfig.deepNavy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contractor Info Card
            Container(
              padding: const EdgeInsets.all(16),
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
                  Text(
                    widget.contractor.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppConfig.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.contractor.company,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: AppConfig.deepNavy),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.contractor.roadsManaged.length} roads managed',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Star Rating Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How would you rate this contractor?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRating = index + 1;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.star,
                            size: 48,
                            color: index < _selectedRating
                                ? AppConfig.cautionYellow
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _selectedRating == 0
                        ? 'Tap to rate'
                        : _getRatingLabel(_selectedRating),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getRatingColor(_selectedRating),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Emoji Feedback
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick reaction',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildEmojiButton('😊', 'Good', 'positive'),
                    _buildEmojiButton('😐', 'Average', 'neutral'),
                    _buildEmojiButton('😠', 'Poor', 'negative'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Text Feedback
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your feedback',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reviewController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Share your experience with this contractor...',
                    hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppConfig.deepNavy, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_reviewController.text.length}/500 characters',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Image Upload Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add proof (optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Image upload will be enabled in next update'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: AppConfig.deepNavy.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap to upload road photos',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Optional - shows road quality evidence',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFA0AEC0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submission Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Color(0xFF1E40AF), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: const Text(
                      'Your rating will be reviewed for spam and help improve contractor accountability.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E40AF),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.deepNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting || _selectedRating == 0 || _reviewController.text.trim().isEmpty
                    ? null
                    : _submitRating,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Rating',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConfig.deepNavy,
                  side: const BorderSide(color: AppConfig.deepNavy),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiButton(String emoji, String label, String sentiment) {
    final isSelected = _selectedEmoji == sentiment;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEmoji = isSelected ? '' : sentiment;
        });
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFEF08A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppConfig.cautionYellow : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppConfig.deepNavy : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Below Average';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return const Color(0xFF10B981);
    if (rating >= 3) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    if (_reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write some feedback')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate submission delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final appState = context.read<AppState>();
    final sentiment = _selectedEmoji.isEmpty
        ? (_selectedRating >= 4 ? 'positive' : _selectedRating == 3 ? 'neutral' : 'negative')
        : _getSentimentFromEmoji(_selectedEmoji);

    final emoji = _selectedEmoji.isEmpty ? _getEmojiFromRating(_selectedRating) : _emojiMap[_selectedEmoji]!;

    // Submit the review
    final newReview = ContractorReview(
      id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user-local-${DateTime.now().millisecondsSinceEpoch}',
      userName: 'You',
      rating: _selectedRating,
      sentiment: sentiment,
      reviewText: _reviewController.text,
      emotionEmoji: emoji,
      timestamp: DateTime.now().toIso8601String(),
      isSpamDetected: false,
      helpfulCount: 0,
    );

    // Add to app state (in a real app, this would go to the backend)
    appState.submitContractorReview(widget.contractor.id, newReview);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! Your rating has been submitted.'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );

    // Close the form
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate successful submission
      }
    });
  }

  String _getSentimentFromEmoji(String sentiment) {
    return sentiment;
  }

  String _getEmojiFromRating(int rating) {
    if (rating >= 4) return '😊';
    if (rating == 3) return '😐';
    return '😠';
  }
}
