import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';

class NoticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _viewedNoticesKey = 'viewed_notices';

  Future<List<Notice>> getActiveNotices() async {
    try {
      final querySnapshot = await _firestore
          .collection('notices')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Notice.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('공지사항 조회 중 오류 발생: $e');
      return [];
    }
  }

  Future<List<String>> getViewedNoticeIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_viewedNoticesKey) ?? [];
  }

  Future<void> markNoticeAsViewed(String noticeId) async {
    final prefs = await SharedPreferences.getInstance();
    final viewedNotices = await getViewedNoticeIds();
    if (!viewedNotices.contains(noticeId)) {
      viewedNotices.add(noticeId);
      await prefs.setStringList(_viewedNoticesKey, viewedNotices);
    }
  }

  Future<Notice?> getUnviewedNotice() async {
    try {
      final activeNotices = await getActiveNotices();
      final viewedNoticeIds = await getViewedNoticeIds();

      for (var notice in activeNotices) {
        if (!viewedNoticeIds.contains(notice.id)) {
          return notice;
        }
      }
      return null;
    } catch (e) {
      print('미확인 공지사항 조회 중 오류 발생: $e');
      return null;
    }
  }
} 