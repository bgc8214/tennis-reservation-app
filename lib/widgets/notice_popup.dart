import 'package:flutter/cupertino.dart';
import '../models/notice.dart';

class NoticePopup extends StatelessWidget {
  final Notice notice;
  final VoidCallback onConfirm;

  const NoticePopup({
    Key? key,
    required this.notice,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
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
        CupertinoDialogAction(
          child: const Text('확인'),
          onPressed: onConfirm,
        ),
      ],
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
      default:
        emoji = '💡';
    }
    return Text(
      emoji,
      style: const TextStyle(fontSize: 40),
    );
  }
} 