class ChatReply {
  const ChatReply({required this.reply, required this.suggestions});

  final String reply;
  final List<String> suggestions;

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    final suggestions = json['suggestions'];
    return ChatReply(
      reply: json['reply'] as String? ?? '',
      suggestions: suggestions is List
          ? suggestions.whereType<String>().toList()
          : const [],
    );
  }
}

class ChatBubble {
  ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}
