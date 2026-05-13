class Contractor {
  final String id;
  final String name;
  final String company;
  final String projectStatus;
  final double overallRating;
  final int totalReviews;
  final List<ContractorReview> reviews;
  final String trustedBadge; // 'gold', 'silver', 'bronze', or ''
  final double publicTransparencyScore;
  final int complaintCount;
  final List<String> roadsManaged;
  final String profileImageUrl;

  const Contractor({
    required this.id,
    required this.name,
    required this.company,
    required this.projectStatus,
    required this.overallRating,
    required this.totalReviews,
    required this.reviews,
    this.trustedBadge = '',
    required this.publicTransparencyScore,
    required this.complaintCount,
    required this.roadsManaged,
    this.profileImageUrl = '',
  });

  String get ratingColor {
    if (overallRating >= 4.0) return 'green';
    if (overallRating >= 2.5) return 'yellow';
    return 'red';
  }

  factory Contractor.fromJson(Map<String, dynamic> json) {
    return Contractor(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      company: json['company'] as String? ?? '',
      projectStatus: json['project_status'] as String? ?? 'Ongoing',
      overallRating: (json['overall_rating'] as num?)?.toDouble() ?? 3.5,
      totalReviews: json['total_reviews'] as int? ?? 0,
      reviews: ((json['reviews'] as List?) ?? [])
          .map((r) => ContractorReview.fromJson(r as Map<String, dynamic>))
          .toList(),
      trustedBadge: json['trusted_badge'] as String? ?? '',
      publicTransparencyScore: (json['public_transparency_score'] as num?)?.toDouble() ?? 0.0,
      complaintCount: json['complaint_count'] as int? ?? 0,
      roadsManaged: List<String>.from(json['roads_managed'] as List? ?? []),
      profileImageUrl: json['profile_image_url'] as String? ?? '',
    );
  }
}

class ContractorReview {
  final String id;
  final String userId;
  final String userName;
  final int rating;
  final String sentiment; // 'positive', 'neutral', 'negative'
  final String reviewText;
  final String emotionEmoji; // '😊', '😐', '😠'
  final String timestamp;
  final bool isSpamDetected;
  final int helpfulCount;
  final String? imageUrl;

  const ContractorReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.sentiment,
    required this.reviewText,
    required this.emotionEmoji,
    required this.timestamp,
    this.isSpamDetected = false,
    this.helpfulCount = 0,
    this.imageUrl,
  });

  factory ContractorReview.fromJson(Map<String, dynamic> json) {
    return ContractorReview(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Anonymous',
      rating: json['rating'] as int? ?? 3,
      sentiment: json['sentiment'] as String? ?? 'neutral',
      reviewText: json['review_text'] as String? ?? '',
      emotionEmoji: json['emotion_emoji'] as String? ?? '😐',
      timestamp: json['timestamp'] as String? ?? '',
      isSpamDetected: json['is_spam_detected'] as bool? ?? false,
      helpfulCount: json['helpful_count'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class ContractorPerformanceMetric {
  final String month;
  final double averageRating;
  final int reviewCount;
  final int complaintCount;

  const ContractorPerformanceMetric({
    required this.month,
    required this.averageRating,
    required this.reviewCount,
    required this.complaintCount,
  });
}
