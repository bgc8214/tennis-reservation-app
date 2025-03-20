import 'package:cloud_firestore/cloud_firestore.dart';

class Notice {
  final String id;
  final String title;
  final String content;
  final String type;  // 'normal', 'update', 'event' 등
  final DateTime createdAt;
  final bool isActive;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.isActive,
  });

  factory Notice.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Notice(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      type: data['type'] ?? 'normal',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
} 