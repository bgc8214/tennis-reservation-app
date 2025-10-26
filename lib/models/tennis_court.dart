enum OpeningType {
  monthly,  // 한달에 한번 (매월 특정일에 오픈)
  weekly,   // 일주일마다 (매일 7일 후 예약 오픈)
}

class TennisCourt {
  final String name;
  final String bookingUrl;
  final int day;
  final int hour;
  final int minute;
  final bool visible;
  final OpeningType openingType;

  TennisCourt({
    required this.name,
    required this.bookingUrl,
    required this.day,
    required this.hour,
    required this.minute,
    this.visible = true,
    this.openingType = OpeningType.monthly,
  });

  factory TennisCourt.fromFirestore(Map<String, dynamic> data) {
    // openingType 파싱
    OpeningType type = OpeningType.monthly;
    if (data['openingType'] != null) {
      if (data['openingType'] == 'weekly') {
        type = OpeningType.weekly;
      } else if (data['openingType'] == 'monthly') {
        type = OpeningType.monthly;
      }
    }

    return TennisCourt(
      name: data['name'] ?? '',
      bookingUrl: data['bookingUrl'] ?? '',
      day: data['day'] ?? 1,
      hour: data['hour'] ?? 9,
      minute: data['minute'] ?? 0,
      visible: data['visible'] ?? true,
      openingType: type,
    );
  }

  DateTime getNextReservationDate() {
    final now = DateTime.now();

    if (openingType == OpeningType.weekly) {
      // 롤링 예약: 다음 오픈 시간 (오늘 or 내일 00:00)
      final todayOpen = DateTime(now.year, now.month, now.day, hour, minute);
      if (now.isBefore(todayOpen)) {
        return todayOpen; // 오늘 아직 오픈 전
      } else {
        return todayOpen.add(const Duration(days: 1)); // 내일 오픈
      }
    } else {
      // 기존 월간 로직
      var reservationDate = DateTime(now.year, now.month, day, hour, minute);
      if (now.isAfter(reservationDate)) {
        reservationDate = DateTime(now.year, now.month + 1, day, hour, minute);
      }
      return reservationDate;
    }
  }

  // 롤링 예약 전용: 오늘 예약 가능한 날짜 (7일 후)
  DateTime getTodayReservationTargetDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TennisCourt &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
