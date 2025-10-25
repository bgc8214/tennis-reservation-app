import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';
  bool _notificationPermission = false;
  bool _exactAlarmPermission = false;
  final TextEditingController _suggestionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _checkPermissions();
  }

  @override
  void dispose() {
    _suggestionController.dispose();
    super.dispose();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  Future<void> _checkPermissions() async {
    final notificationStatus = await Permission.notification.status;
    setState(() {
      _notificationPermission = notificationStatus.isGranted;
      // exactAlarm은 Android 전용이므로 항상 true로 표시
      _exactAlarmPermission = true;
    });
  }

  void _openAppSettings() async {
    await openAppSettings();
  }

  void _openGithub() async {
    final uri = Uri.parse('https://github.com/anthropics/claude-code/issues');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitSuggestion(String suggestion) async {
    if (suggestion.trim().isEmpty) {
      _showAlert('입력 오류', '건의사항을 입력해주세요.');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('suggestions').add({
        'suggestion': suggestion,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showAlert('감사합니다!', '소중한 의견이 전달되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        _showAlert('오류', '전송 중 오류가 발생했습니다. 다시 시도해주세요.');
      }
    }
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuggestionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              '테니스장 추가 건의',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              height: 120,
              child: CupertinoTextField(
                controller: _suggestionController,
                placeholder: '추가를 원하는 테니스장이나 건의사항을 적어주세요',
                maxLines: null,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text(
                '취소',
                style: TextStyle(
                  color: CupertinoColors.destructiveRed,
                ),
              ),
              onPressed: () {
                _suggestionController.clear();
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              child: const Text(
                '보내기',
                style: TextStyle(
                  color: CupertinoColors.activeBlue,
                ),
              ),
              onPressed: () {
                final suggestion = _suggestionController.text;
                _suggestionController.clear();
                Navigator.pop(context);
                _submitSuggestion(suggestion);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('설정'),
        previousPageTitle: '뒤로',
        backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
      ),
      child: SafeArea(
        child: ListView(
          children: [
            // 알림 설정
            _buildSection(
              '알림',
              [
                _buildInfoTile(
                  '알림 권한',
                  _notificationPermission ? '허용됨' : '거부됨',
                  icon: _notificationPermission
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.xmark_circle_fill,
                  iconColor: _notificationPermission
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.destructiveRed,
                  onTap: _openAppSettings,
                ),
                _buildInfoTile(
                  '정확한 알람',
                  _exactAlarmPermission ? '허용됨' : '거부됨',
                  icon: _exactAlarmPermission
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.xmark_circle_fill,
                  iconColor: _exactAlarmPermission
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.destructiveRed,
                  onTap: _openAppSettings,
                ),
              ],
            ),
            // 앱 정보
            _buildSection(
              '앱 정보',
              [
                _buildInfoTile(
                  '버전',
                  _version,
                  icon: CupertinoIcons.info_circle,
                ),
                _buildInfoTile(
                  '테니스장 추가 건의',
                  '추가를 원하는 테니스장이나 건의사항',
                  icon: CupertinoIcons.plus_bubble,
                  onTap: _showSuggestionDialog,
                ),
              ],
            ),
            // 기타
            _buildSection(
              '기타',
              [
                _buildInfoTile(
                  '오픈소스 라이선스',
                  '사용된 라이브러리',
                  icon: CupertinoIcons.doc_text,
                  onTap: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('오픈소스 라이선스'),
                        content: const Text(
                            'Flutter, Provider, Firebase, table_calendar 등의 오픈소스 라이브러리를 사용합니다.'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('확인'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),
            // 앱 정보 푸터
            Center(
              child: Column(
                children: [
                  const Text(
                    '코트알람',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v$_version',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Made with ❤️ for Tennis Players',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildInfoTile(
    String title,
    String? subtitle, {
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final brightness = CupertinoTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? CupertinoColors.darkBackgroundGray
              : CupertinoColors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? CupertinoColors.systemGrey5.darkColor
                  : CupertinoColors.systemGrey5,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: iconColor ?? CupertinoColors.systemGrey,
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
