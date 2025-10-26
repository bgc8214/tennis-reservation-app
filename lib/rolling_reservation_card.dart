import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/tennis_court.dart';
import 'providers/alarm_provider.dart';
import 'providers/court_provider.dart';
import 'widgets/custom_alarm_settings_dialog.dart';

class RollingReservationCard extends StatefulWidget {
  final String location;
  final DateTime todayTargetDate;
  final DateTime nextOpenTime;
  final String bookingUrl;
  final bool isFavorite;
  final Function(String) onLaunchURL;
  final VoidCallback onToggleFavorite;

  const RollingReservationCard({
    Key? key,
    required this.location,
    required this.todayTargetDate,
    required this.nextOpenTime,
    required this.bookingUrl,
    required this.isFavorite,
    required this.onLaunchURL,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  State<RollingReservationCard> createState() => _RollingReservationCardState();
}

class _RollingReservationCardState extends State<RollingReservationCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}/${date.day}(${weekdays[date.weekday - 1]})';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}일 ${duration.inHours % 24}시간 ${duration.inMinutes % 60}분';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}시간 ${duration.inMinutes % 60}분 ${duration.inSeconds % 60}초';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}분 ${duration.inSeconds % 60}초';
    } else {
      return '${duration.inSeconds}초';
    }
  }

  int _getAlarmCount(dynamic alarmSetting) {
    int count = 0;
    if (alarmSetting.oneDayBefore) count++;
    if (alarmSetting.oneHourBefore) count++;
    count += (alarmSetting.customTimes.length as num).toInt();
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final alarmProvider = context.watch<AlarmProvider>();
    final alarmSetting = alarmProvider.getAlarmSetting(widget.location);
    final now = DateTime.now();
    final isOpenNow = now.isAfter(widget.nextOpenTime);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: _buildCard(context, isDark, alarmSetting, isOpenNow),
        ),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, bool isDark, dynamic alarmSetting, bool isOpenNow) {
    final alarmProvider = context.watch<AlarmProvider>();
    final tomorrow = widget.todayTargetDate.add(const Duration(days: 1));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? CupertinoColors.darkBackgroundGray
            : CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: isDark
            ? Border.all(
                color: CupertinoColors.systemGrey4.darkColor, width: 0.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? CupertinoColors.black.withOpacity(0.3)
                : CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더: 이름, 즐겨찾기, 알람
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                widget.onToggleFavorite();
                              },
                              child: Icon(
                                widget.isFavorite
                                    ? CupertinoIcons.star_fill
                                    : CupertinoIcons.star,
                                color: widget.isFavorite
                                    ? CupertinoColors.systemYellow
                                    : CupertinoColors.systemGrey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.location,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final courtProvider = context.read<CourtProvider>();
                          final court =
                              courtProvider.getCourtByName(widget.location);
                          if (court != null) {
                            final newSetting =
                                await showCustomAlarmSettingsDialog(
                              context,
                              widget.location,
                              alarmSetting,
                            );
                            if (newSetting != null) {
                              await alarmProvider.updateAlarmSetting(
                                widget.location,
                                newSetting,
                                court,
                              );

                              // 알람 설정 완료 메시지
                              if (context.mounted) {
                                final count = _getAlarmCount(newSetting);
                                HapticFeedback.mediumImpact();
                                showCupertinoDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (context) => CupertinoAlertDialog(
                                    title: const Text('알람 설정 완료'),
                                    content: Text(
                                      count > 0
                                          ? '$count개의 알람이 설정되었습니다'
                                          : '모든 알람이 해제되었습니다',
                                    ),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text('확인'),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Text(
                              alarmSetting.hasAnyAlarm ? '🔔' : '🔕',
                              style: TextStyle(
                                fontSize: 24,
                                color: alarmSetting.hasAnyAlarm
                                    ? CupertinoColors.activeGreen
                                    : CupertinoColors.systemGrey,
                              ),
                            ),
                            if (alarmSetting.hasAnyAlarm)
                              Positioned(
                                right: -6,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: CupertinoColors.destructiveRed,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    _getAlarmCount(alarmSetting).toString(),
                                    style: const TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 롤링 예약 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🔄',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '매일 롤링 예약',
                          style: TextStyle(
                            color: CupertinoColors.systemPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 오늘 예약 가능 날짜
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOpenNow
                          ? CupertinoColors.activeGreen.withOpacity(0.1)
                          : CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isOpenNow ? '🎯 지금 예약 가능' : '📅 다음 예약',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isOpenNow
                                    ? CupertinoColors.activeGreen
                                    : CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOpenNow
                              ? '${_formatDate(widget.todayTargetDate)} 코트'
                              : '${_formatDate(tomorrow)} 코트 (내일 ${_formatTime(widget.nextOpenTime)})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 카운트다운 (오픈 전일 때만)
                  if (!isOpenNow) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '⏰ 다음 오픈까지',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemBlue,
                            ),
                          ),
                          Text(
                            _formatDuration(widget.nextOpenTime.difference(DateTime.now())),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 롤링 시스템 안내
                  Text(
                    '매일 ${_formatTime(widget.nextOpenTime)}에 7일 후 코트 오픈',
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CupertinoButton(
                padding: const EdgeInsets.all(0),
                onPressed: () => widget.onLaunchURL(widget.bookingUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: CupertinoColors.activeGreen,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '예약하기',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
