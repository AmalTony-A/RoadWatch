class ComplaintTimelineEvent {
  final String status;
  final String at;
  final String note;

  const ComplaintTimelineEvent({
    required this.status,
    required this.at,
    required this.note,
  });

  factory ComplaintTimelineEvent.fromJson(Map<String, dynamic> json) {
    return ComplaintTimelineEvent(
      status: json['status'] as String,
      at: json['at'] as String,
      note: json['note'] as String,
    );
  }
}

class ComplaintItem {
  final String id;
  final String roadId;
  final String description;
  final String? imageRef;
  final double lat;
  final double lng;
  final String timestamp;
  final String status;
  final String authorityTicket;
  final String recommendedDepartment;
  final String routingReason;
  final String complaintLetter;
  final bool sentToAuthority;
  final bool deliveredToAuthority;
  final bool readByAuthority;
  final String? sentAt;
  final String? deliveredAt;
  final String? readAt;
  final List<ComplaintTimelineEvent> timeline;

  const ComplaintItem({
    required this.id,
    required this.roadId,
    required this.description,
    required this.imageRef,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.status,
    required this.authorityTicket,
    required this.recommendedDepartment,
    required this.routingReason,
    required this.complaintLetter,
    required this.sentToAuthority,
    required this.deliveredToAuthority,
    required this.readByAuthority,
    required this.sentAt,
    required this.deliveredAt,
    required this.readAt,
    required this.timeline,
  });

  factory ComplaintItem.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    return ComplaintItem(
      id: json['id'] as String,
      roadId: json['road_id'] as String,
      description: json['description'] as String,
      imageRef: json['image_ref'] as String?,
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
      timestamp: json['timestamp'] as String,
      status: json['status'] as String,
      authorityTicket: json['authority_ticket'] as String,
      recommendedDepartment: json['recommended_department'] as String? ?? 'Unassigned',
      routingReason: json['routing_reason'] as String? ?? 'Routing details unavailable',
      complaintLetter: json['complaint_letter'] as String? ?? '',
      sentToAuthority: json['sent_to_authority'] as bool? ?? false,
      deliveredToAuthority: json['delivered_to_authority'] as bool? ?? false,
      readByAuthority: json['read_by_authority'] as bool? ?? false,
      sentAt: json['sent_at'] as String?,
      deliveredAt: json['delivered_at'] as String?,
      readAt: json['read_at'] as String?,
      timeline: (json['timeline'] as List<dynamic>)
          .map((e) => ComplaintTimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
