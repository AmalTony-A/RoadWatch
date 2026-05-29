class ChatItem {
  final String role;
  final String content;

  const ChatItem({required this.role, required this.content});

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }
}

class ChatResponse {
  final String answer;
  final bool allowed;
  final String topic;
  final String historySummary;
  final Map<String, dynamic> citedData;

  const ChatResponse({
    required this.answer,
    required this.allowed,
    required this.topic,
    required this.historySummary,
    required this.citedData,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: json['answer'] as String,
      allowed: json['allowed'] as bool? ?? true,
      topic: json['topic']?.toString() ?? '',
      historySummary: json['historySummary']?.toString() ?? '',
      citedData: json['cited_data'] as Map<String, dynamic>,
    );
  }
}
