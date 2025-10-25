class AlarmSetting {
  final bool oneDayBefore;
  final bool oneHourBefore;
  final List<CustomAlarmTime> customTimes;

  AlarmSetting({
    this.oneDayBefore = false,
    this.oneHourBefore = false,
    this.customTimes = const [],
  });

  AlarmSetting copyWith({
    bool? oneDayBefore,
    bool? oneHourBefore,
    List<CustomAlarmTime>? customTimes,
  }) {
    return AlarmSetting(
      oneDayBefore: oneDayBefore ?? this.oneDayBefore,
      oneHourBefore: oneHourBefore ?? this.oneHourBefore,
      customTimes: customTimes ?? this.customTimes,
    );
  }

  bool get hasAnyAlarm =>
      oneDayBefore || oneHourBefore || customTimes.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'oneDayBefore': oneDayBefore,
      'oneHourBefore': oneHourBefore,
      'customTimes': customTimes.map((e) => e.toJson()).toList(),
    };
  }

  factory AlarmSetting.fromJson(Map<String, dynamic> json) {
    return AlarmSetting(
      oneDayBefore: json['oneDayBefore'] ?? false,
      oneHourBefore: json['oneHourBefore'] ?? false,
      customTimes: (json['customTimes'] as List<dynamic>?)
              ?.map((e) => CustomAlarmTime.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CustomAlarmTime {
  final int days;
  final int hours;
  final int minutes;

  CustomAlarmTime({
    this.days = 0,
    this.hours = 0,
    this.minutes = 0,
  });

  Duration get duration =>
      Duration(days: days, hours: hours, minutes: minutes);

  String get displayText {
    final parts = <String>[];
    if (days > 0) parts.add('$days일');
    if (hours > 0) parts.add('$hours시간');
    if (minutes > 0) parts.add('$minutes분');
    return parts.isEmpty ? '0분' : '${parts.join(' ')} 전';
  }

  Map<String, dynamic> toJson() {
    return {
      'days': days,
      'hours': hours,
      'minutes': minutes,
    };
  }

  factory CustomAlarmTime.fromJson(Map<String, dynamic> json) {
    return CustomAlarmTime(
      days: json['days'] ?? 0,
      hours: json['hours'] ?? 0,
      minutes: json['minutes'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomAlarmTime &&
          runtimeType == other.runtimeType &&
          days == other.days &&
          hours == other.hours &&
          minutes == other.minutes;

  @override
  int get hashCode => days.hashCode ^ hours.hashCode ^ minutes.hashCode;
}
