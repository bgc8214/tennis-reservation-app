import 'package:flutter/cupertino.dart';
import '../models/notice.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show navigatorKey;

class NoticePopup extends StatelessWidget {
  final Notice notice;
  final VoidCallback onConfirm;

  static const String androidStoreUrl = 'https://play.google.com/store/apps/details?id=com.boss.tennis_app&hl=ko';
  static const String iosStoreUrl = 'https://apps.apple.com/kr/app/%EC%BD%94%ED%8A%B8%EC%95%8C%EB%9E%8C/id6740774383';

  const NoticePopup({
    Key? key,
    required this.notice,
    required this.onConfirm,
  }) : super(key: key);

  Future<void> _launchStoreUrl() async {
    final url = Platform.isIOS ? iosStoreUrl : androidStoreUrl;
    final uri = Uri.parse(url);
    
    try {
      // 업데이트 공지는 스토어로 이동할 때 읽음 처리하지 않음
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // 스토어로 이동 후 팝업은 닫음
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }
    } catch (e) {
      debugPrint('스토어 URL 실행 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 업데이트 공지일 경우 뒤로가기 버튼 비활성화
      onWillPop: () async => notice.type != 'update',
      child: CupertinoAlertDialog(
        title: Column(
          children: [
            _buildTypeIcon(),
            const SizedBox(height: 8),
            Text(
              notice.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Text(
            notice.content,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          if (notice.type == 'update')
            CupertinoDialogAction(
              child: const Text(
                '업데이트',
                style: TextStyle(
                  color: CupertinoColors.activeBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _launchStoreUrl,
            )
          else
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: onConfirm,
            ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon() {
    String emoji;
    switch (notice.type) {
      case 'update':
        emoji = '🆕';
        break;
      case 'event':
        emoji = '🎉';
        break;
      case 'notice':
        emoji = '📢';
        break;
      case 'urgent':
        emoji = '⚠️';
        break;
      default:
        emoji = '💡';
    }
    return Text(
      emoji,
      style: const TextStyle(fontSize: 40),
    );
  }
} 