import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/tennis_court.dart';
import 'providers/alarm_provider.dart';
import 'providers/court_provider.dart';
import 'widgets/custom_alarm_settings_dialog.dart';
import 'theme/court_colors.dart';
import 'theme/court_typography.dart';

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
  final OpeningType openingType;

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
    required this.openingType,
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
    if (widget.openingType == OpeningType.weekly) {
      // 주간 오픈: 간결하게 날짜만 표시
      return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
    } else {
      // 월간 오픈: 시간까지 표시
      return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]}) ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getColorForRemainingDays(int days) {
    return CourtColors.getColorForDays(days);
  }

  int _calculateRemainingDays(DateTime reservationDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reservationDay = DateTime(
        reservationDate.year, reservationDate.month, reservationDate.day);
    return reservationDay.difference(today).inDays;
  }

  String _formatOpenTime(DateTime date) {
    if (widget.openingType == OpeningType.weekly) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} 오픈';
    } else {
      return '매달 ${date.day}일 ${date.hour.toString().padLeft(2, '0')}시 ${date.minute.toString().padLeft(2, '0')}분 오픈';
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
    final isUrgent = remainingDays <= 1;
    final isWarning = remainingDays <= 7 && remainingDays > 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isUrgent
            ? CourtColors.urgentGradient
            : null,
        color: isUrgent
            ? null
            : isDark
                ? CourtColors.darkBgSecondary
                : CourtColors.lightBgSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? CourtColors.urgentLight
              : isWarning
                  ? CourtColors.ballYellow.withOpacity(0.4)
                  : isDark
                      ? CourtColors.hardCourtLight.withOpacity(0.3)
                      : CourtColors.courtLineGrey,
          width: isUrgent || isWarning ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUrgent
                ? CourtColors.urgent.withOpacity(0.4)
                : isWarning
                    ? CourtColors.ballYellow.withOpacity(0.2)
                    : isDark
                        ? CourtColors.darkBg.withOpacity(0.4)
                        : CourtColors.textGrey.withOpacity(0.08),
            blurRadius: isUrgent ? 20 : 12,
            offset: const Offset(0, 4),
            spreadRadius: isUrgent ? 2 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
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
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: widget.isFavorite
                                      ? CourtColors.ballYellow
                                      : CourtColors.textGrey.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    widget.isFavorite
                                        ? CupertinoIcons.star_fill
                                        : CupertinoIcons.star,
                                    color: widget.isFavorite
                                        ? CourtColors.hardCourt
                                        : CourtColors.textGrey,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.location,
                                style: CourtTypography.headline2.copyWith(
                                  color: isUrgent
                                      ? CourtColors.textLight
                                      : isDark
                                          ? CourtColors.textLight
                                          : CourtColors.textDark,
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
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? CourtColors.textLight.withOpacity(0.25)
                                  : _getColorForRemainingDays(remainingDays),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'D-$remainingDays',
                              style: CourtTypography.label1.copyWith(
                                color: isUrgent
                                    ? CourtColors.textLight
                                    : CourtColors.textLight,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: alarmSetting.hasAnyAlarm
                                    ? CourtColors.grass
                                    : CourtColors.textGrey.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: Icon(
                                      alarmSetting.hasAnyAlarm
                                          ? CupertinoIcons.bell_fill
                                          : CupertinoIcons.bell_slash,
                                      size: 22,
                                      color: alarmSetting.hasAnyAlarm
                                          ? CourtColors.textLight
                                          : CourtColors.textGrey,
                                    ),
                                  ),
                                  if (alarmSetting.hasAnyAlarm)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: CourtColors.urgent,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _getAlarmCount(alarmSetting)
                                                .toString(),
                                            style: CourtTypography.caption.copyWith(
                                              color: CourtColors.textLight,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 18,
                        color: isUrgent
                            ? CourtColors.textLight.withOpacity(0.8)
                            : CourtColors.textGrey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(widget.reservationTime),
                        style: CourtTypography.headline3.copyWith(
                          color: isUrgent
                              ? CourtColors.textLight
                              : isDark
                                  ? CourtColors.textLight
                                  : CourtColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.openingType == OpeningType.weekly
                              ? CourtColors.clay
                              : CourtColors.grass,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.openingType == OpeningType.weekly
                                  ? CupertinoIcons.arrow_2_circlepath
                                  : CupertinoIcons.calendar_badge_plus,
                              size: 14,
                              color: CourtColors.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.openingType == OpeningType.weekly
                                  ? '매일 오픈'
                                  : '예약일',
                              style: CourtTypography.label2.copyWith(
                                color: CourtColors.textLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.clock,
                        size: 16,
                        color: isUrgent
                            ? CourtColors.textLight.withOpacity(0.7)
                            : CourtColors.textGrey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatOpenTime(widget.reservationTime),
                        style: CourtTypography.body2.copyWith(
                          color: isUrgent
                              ? CourtColors.textLight.withOpacity(0.9)
                              : CourtColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Scoreboard-style timer
                  _buildScoreboardTimer(isDark, isUrgent),
                  const SizedBox(height: 50),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CupertinoButton(
                padding: const EdgeInsets.all(0),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onLaunchURL(widget.bookingUrl);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: isUrgent
                        ? LinearGradient(
                            colors: [
                              CourtColors.textLight.withOpacity(0.3),
                              CourtColors.textLight.withOpacity(0.2),
                            ],
                          )
                        : CourtColors.grassGradient,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUrgent
                            ? CourtColors.textLight.withOpacity(0.2)
                            : CourtColors.grass.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.sportscourt,
                        color: isUrgent
                            ? CourtColors.textLight
                            : CourtColors.textLight,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '예약하기',
                        style: CourtTypography.button1.copyWith(
                          color: isUrgent
                              ? CourtColors.textLight
                              : CourtColors.textLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.arrow_right_circle_fill,
                        color: isUrgent
                            ? CourtColors.textLight
                            : CourtColors.textLight,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreboardTimer(bool isDark, bool isUrgent) {
    final days = widget.remainingTime.inDays;
    final hours = widget.remainingTime.inHours % 24;
    final minutes = widget.remainingTime.inMinutes % 60;
    final seconds = widget.remainingTime.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isUrgent
            ? CourtColors.urgent.withOpacity(0.1)
            : isDark
                ? CourtColors.darkBgTertiary
                : CourtColors.lightBgTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? CourtColors.urgent
              : CourtColors.grass.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.timer,
            size: 20,
            color: isUrgent
                ? CourtColors.textLight
                : CourtColors.grass,
          ),
          const SizedBox(width: 8),
          Text(
            _formatTimeRemaining(days, hours, minutes, seconds),
            style: CourtTypography.headline2.copyWith(
              color: isUrgent
                  ? CourtColors.textLight
                  : isDark
                      ? CourtColors.textLight
                      : CourtColors.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeRemaining(int days, int hours, int minutes, int seconds) {
    if (days > 0) {
      return '$days일 ${hours}시간 ${minutes}분 ${seconds}초';
    } else if (hours > 0) {
      return '$hours시간 ${minutes}분 ${seconds}초';
    } else if (minutes > 0) {
      return '${minutes}분 ${seconds}초';
    } else {
      return '${seconds}초';
    }
  }

  Widget _buildSimpleTimeUnit({
    required int value,
    required String label,
    required Color color,
    required bool isDark,
    required bool isUrgent,
  }) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: CourtTypography.timer1.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 48,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: CourtTypography.label2.copyWith(
            color: isUrgent
                ? CourtColors.urgent.withOpacity(0.8)
                : isDark
                    ? CourtColors.textLight.withOpacity(0.7)
                    : CourtColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeUnit({
    required int value,
    required String label,
    required Color color,
    required bool isDark,
    required bool isUrgent,
    bool isSmall = false,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 8 : 12,
            vertical: isSmall ? 8 : 12,
          ),
          decoration: BoxDecoration(
            gradient: isUrgent
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CourtColors.textLight.withOpacity(0.2),
                      CourtColors.textLight.withOpacity(0.1),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUrgent
                  ? CourtColors.textLight.withOpacity(0.4)
                  : color.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isUrgent
                    ? CourtColors.textLight.withOpacity(0.1)
                    : color.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: (isSmall ? CourtTypography.timer3 : CourtTypography.timer2)
                .copyWith(
              color: isUrgent ? CourtColors.textLight : color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: CourtTypography.caption.copyWith(
            color: isUrgent
                ? CourtColors.textLight.withOpacity(0.7)
                : CourtColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for tennis court line pattern
class CourtLinePainter extends CustomPainter {
  final bool isDark;

  CourtLinePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? CourtColors.courtLine.withOpacity(0.03)
          : CourtColors.textDark.withOpacity(0.03)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw court lines pattern
    // Horizontal lines
    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.7),
      paint,
    );

    // Vertical center line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Diagonal lines for decorative effect
    final dashedPaint = Paint()
      ..color = isDark
          ? CourtColors.ballYellow.withOpacity(0.02)
          : CourtColors.grass.withOpacity(0.02)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width * 0.3, size.height),
      dashedPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width, size.height),
      dashedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
