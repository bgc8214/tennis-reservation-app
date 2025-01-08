import 'package:flutter/cupertino.dart';

import 'alarm_settings_dialog.dart';

class ReservationCard extends StatelessWidget {
  final String location;
  final DateTime reservationTime;
  final Duration remainingTime;
  final String bookingUrl;
  final Map<String, Map<String, bool>> alarmSettings;
  final Function(bool, bool) onAlarmSettingsChanged;
  final Function(String) onLaunchURL;

  const ReservationCard({
    Key? key,
    required this.location,
    required this.reservationTime,
    required this.remainingTime,
    required this.bookingUrl,
    required this.alarmSettings,
    required this.onAlarmSettingsChanged,
    required this.onLaunchURL,
  }) : super(key: key);

  String _formatDuration(Duration duration) {
    return '${duration.inDays}일 ${duration.inHours % 24}시간 ${duration.inMinutes % 60}분 ${duration.inSeconds % 60}초';
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]}) ${date.hour.toString().padLeft(2, '0')}:00';
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

  @override
  Widget build(BuildContext context) {
    final remainingDays = _calculateRemainingDays(reservationTime);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
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
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
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
                                color: _getColorForRemainingDays(remainingDays),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => showAlarmSettingsDialog(
                              context,
                              location,
                              alarmSettings[location]?['oneDayBefore'] ?? false,
                              alarmSettings[location]?['oneHourBefore'] ??
                                  false,
                              (oneDayBefore, oneHourBefore) {
                                onAlarmSettingsChanged(
                                    oneDayBefore, oneHourBefore);
                              },
                            ),
                            child: Text(
                              (alarmSettings[location]?['oneDayBefore'] ==
                                          true ||
                                      alarmSettings[location]
                                              ?['oneHourBefore'] ==
                                          true)
                                  ? '🔔'
                                  : '🔕',
                              style: TextStyle(
                                fontSize: 24,
                                color: (alarmSettings[location]
                                                ?['oneDayBefore'] ==
                                            true ||
                                        alarmSettings[location]
                                                ?['oneHourBefore'] ==
                                            true)
                                    ? CupertinoColors.activeGreen
                                    : CupertinoColors.systemGrey,
                              ),
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
                        _formatDate(reservationTime),
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
                        child: Text(
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
                    '매달 ${reservationTime.day}일 ${reservationTime.hour.toString().padLeft(2, '0')}:00 예약 오픈',
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '남은 시간: ${_formatDuration(remainingTime)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.black,
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
                onPressed: () => onLaunchURL(bookingUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeGreen,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '네이버 예약하기',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
