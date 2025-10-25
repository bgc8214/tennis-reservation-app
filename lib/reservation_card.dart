import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/alarm_provider.dart';
import 'providers/court_provider.dart';
import 'widgets/custom_alarm_settings_dialog.dart';

class ReservationCard extends StatefulWidget {
  final String location;
  final DateTime reservationTime;
  final Duration remainingTime;
  final String bookingUrl;
  final Map<String, Map<String, bool>> alarmSettings;
  final bool isFavorite;
  final Function(bool, bool) onAlarmSettingsChanged;
  final Function(String) onLaunchURL;
  final VoidCallback onToggleFavorite;

  const ReservationCard({
    Key? key,
    required this.location,
    required this.reservationTime,
    required this.remainingTime,
    required this.bookingUrl,
    required this.alarmSettings,
    required this.isFavorite,
    required this.onAlarmSettingsChanged,
    required this.onLaunchURL,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  State<ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<ReservationCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

    // 펄스 애니메이션 (D-1 이하일 때 사용)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    return '${duration.inDays}일 ${duration.inHours % 24}시간 ${duration.inMinutes % 60}분 ${duration.inSeconds % 60}초';
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]}) ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getColorForRemainingDays(int days) {
    if (days <= 1) {
      return CupertinoColors.destructiveRed;
    } else if (days <= 7) {
      return CupertinoColors.systemYellow;
    } else {
      return CupertinoColors.activeGreen;
    }
  }

  int _calculateRemainingDays(DateTime reservationDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reservationDay = DateTime(
        reservationDate.year, reservationDate.month, reservationDate.day);
    return reservationDay.difference(today).inDays;
  }

  String _formatOpenTime(DateTime date) {
    return '매달 ${date.day}일 ${date.hour.toString().padLeft(2, '0')}시 ${date.minute.toString().padLeft(2, '0')}분 오픈';
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
    final remainingDays = _calculateRemainingDays(widget.reservationTime);
    final brightness = CupertinoTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final alarmProvider = context.watch<AlarmProvider>();
    final alarmSetting = alarmProvider.getAlarmSetting(widget.location);

    // D-1 이하일 때 펄스 효과 적용
    final shouldPulse = remainingDays <= 1;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: shouldPulse
              ? ScaleTransition(
                  scale: _pulseAnimation,
                  child: _buildCard(context, remainingDays, isDark, alarmSetting),
                )
              : _buildCard(context, remainingDays, isDark, alarmSetting),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, int remainingDays, bool isDark,
      dynamic alarmSetting) {
    final alarmProvider = context.watch<AlarmProvider>();
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _getColorForRemainingDays(remainingDays)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'D-$remainingDays',
                              style: TextStyle(
                                color:
                                    _getColorForRemainingDays(remainingDays),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final courtProvider =
                                  context.read<CourtProvider>();
                              final court = courtProvider
                                  .getCourtByName(widget.location);
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
                                      builder: (context) =>
                                          CupertinoAlertDialog(
                                        title: const Text('알람 설정 완료'),
                                        content: Text(
                                          count > 0
                                              ? '$count개의 알람이 설정되었습니다'
                                              : '모든 알람이 해제되었습니다',
                                        ),
                                        actions: [
                                          CupertinoDialogAction(
                                            child: const Text('확인'),
                                            onPressed: () =>
                                                Navigator.pop(context),
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
                                        _getAlarmCount(alarmSetting)
                                            .toString(),
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        _formatDate(widget.reservationTime),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '예약일',
                          style: TextStyle(
                            color: CupertinoColors.systemBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatOpenTime(widget.reservationTime),
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '남은 시간: ${_formatDuration(widget.remainingTime)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? CupertinoColors.white
                          : CupertinoColors.black,
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
