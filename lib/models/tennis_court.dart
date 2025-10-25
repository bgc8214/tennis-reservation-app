class TennisCourt {
  final String name;
  final String bookingUrl;
  final int day;
  final int hour;
  final int minute;
  final bool visible;

  TennisCourt({
    required this.name,
    required this.bookingUrl,
    required this.day,
    required this.hour,
    required this.minute,
    this.visible = true,
  });

  factory TennisCourt.fromFirestore(Map<String, dynamic> data) {
    return TennisCourt(
      name: data['name'] ?? '',
      bookingUrl: data['bookingUrl'] ?? '',
      day: data['day'] ?? 1,
      hour: data['hour'] ?? 9,
      minute: data['minute'] ?? 0,
      visible: data['visible'] ?? true,
    );
  }

  DateTime getNextReservationDate() {
    final now = DateTime.now();
    var reservationDate = DateTime(now.year, now.month, day, hour, minute);
    if (now.isAfter(reservationDate)) {
      reservationDate = DateTime(now.year, now.month + 1, day, hour, minute);
    }
    return reservationDate;
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
