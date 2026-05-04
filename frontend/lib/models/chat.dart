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
  final Map<String, dynamic> citedData;

  const ChatResponse({required this.answer, required this.citedData});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: json['answer'] as String,
      citedData: json['cited_data'] as Map<String, dynamic>,
    );
  }
}
