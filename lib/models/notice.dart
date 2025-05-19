import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Notice {
  final String id;
  final String title;
  final String content;
  final String type;  // 'normal', 'update', 'event' 등
  final DateTime createdAt;
  final bool isActive;
  final String? minVersion;      // 필요한 최소 버전
  final String? targetVersion;   // 업데이트 목표 버전

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.isActive,
    this.minVersion,
    this.targetVersion,
  });

  factory Notice.fromFirestore(DocumentSnapshot doc) {
    try {
      debugPrint('Notice 변환 시작 - 문서 ID: ${doc.id}');
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      debugPrint('문서 데이터: $data');

      final notice = Notice(
        id: doc.id,
        title: data['title'] as String? ?? '',
        content: data['content'] as String? ?? '',
        type: data['type'] as String? ?? 'normal',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isActive: data['isActive'] as bool? ?? false,
        minVersion: data['minVersion'] as String?,
        targetVersion: data['targetVersion'] as String?,
      );
      
      debugPrint('Notice 변환 완료: ${notice.toString()}');
      return notice;
    } catch (e, stackTrace) {
      debugPrint('Notice 변환 중 오류 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'minVersion': minVersion,
      'targetVersion': targetVersion,
    };
  }

  @override
  String toString() {
    return 'Notice{id: $id, title: $title, type: $type, isActive: $isActive, createdAt: $createdAt, minVersion: $minVersion, targetVersion: $targetVersion}';
  }
} 