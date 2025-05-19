import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NoticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _viewedNoticesKey = 'viewed_notices';

  // 버전 비교 헬퍼 메서드
  bool isVersionLower(String currentVersion, String targetVersion) {
    List<int> current = currentVersion.split('.').map(int.parse).toList();
    List<int> target = targetVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      int currentPart = i < current.length ? current[i] : 0;
      int targetPart = i < target.length ? target[i] : 0;
      
      if (currentPart < targetPart) return true;
      if (currentPart > targetPart) return false;
    }
    return false;
  }

  Future<List<Notice>> getActiveNotices() async {
    try {
      debugPrint('공지사항 조회 시작');
      final querySnapshot = await _firestore
          .collection('notices')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('조회된 공지사항 개수: ${querySnapshot.docs.length}');
      
      final notices = querySnapshot.docs.map((doc) {
        debugPrint('공지사항 문서 ID: ${doc.id}');
        debugPrint('공지사항 데이터: ${doc.data()}');
        return Notice.fromFirestore(doc);
      }).toList();

      debugPrint('변환된 공지사항 개수: ${notices.length}');
      return notices;
    } catch (e, stackTrace) {
      debugPrint('공지사항 조회 중 오류 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return [];
    }
  }

  Future<List<String>> getViewedNoticeIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedIds = prefs.getStringList(_viewedNoticesKey) ?? [];
      debugPrint('읽은 공지사항 ID 목록: $viewedIds');
      return viewedIds;
    } catch (e) {
      debugPrint('읽은 공지사항 ID 조회 중 오류: $e');
      return [];
    }
  }

  Future<void> markNoticeAsViewed(String noticeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedNotices = await getViewedNoticeIds();
      if (!viewedNotices.contains(noticeId)) {
        viewedNotices.add(noticeId);
        await prefs.setStringList(_viewedNoticesKey, viewedNotices);
        debugPrint('공지사항 읽음 처리 완료: $noticeId');
      }
    } catch (e) {
      debugPrint('공지사항 읽음 처리 중 오류: $e');
    }
  }

  Future<Notice?> getUnviewedNotice() async {
    try {
      debugPrint('미확인 공지사항 조회 시작');
      final activeNotices = await getActiveNotices();
      final viewedNoticeIds = await getViewedNoticeIds();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint('활성화된 공지사항 수: ${activeNotices.length}');
      debugPrint('읽은 공지사항 수: ${viewedNoticeIds.length}');
      debugPrint('현재 앱 버전: $currentVersion');

      // 먼저 업데이트 공지가 있는지 확인
      for (var notice in activeNotices) {
        debugPrint('공지사항 확인 중 - ID: ${notice.id}, 타입: ${notice.type}, 제목: ${notice.title}');
        
        // 업데이트 공지 처리
        if (notice.type == 'update' && notice.minVersion != null) {
          debugPrint('업데이트 공지 발견: ${notice.id}, 필요 버전: ${notice.minVersion}');
          if (isVersionLower(currentVersion, notice.minVersion!)) {
            debugPrint('업데이트 필요: 현재 버전($currentVersion) < 필요 버전(${notice.minVersion})');
            return notice;
          }
          debugPrint('업데이트 불필요: 현재 버전($currentVersion) >= 필요 버전(${notice.minVersion})');
          continue;
        }

        // 일반 공지 처리
        if (!viewedNoticeIds.contains(notice.id)) {
          debugPrint('미확인 일반 공지사항 발견: ${notice.id}');
          return notice;
        }
      }
      
      debugPrint('미확인 공지사항 없음');
      return null;
    } catch (e, stackTrace) {
      debugPrint('미확인 공지사항 조회 중 오류 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return null;
    }
  }
} 