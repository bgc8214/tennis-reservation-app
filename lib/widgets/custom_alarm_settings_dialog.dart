import 'package:flutter/cupertino.dart';
import '../models/alarm_setting.dart';

class CustomAlarmSettingsDialog extends StatefulWidget {
  final String courtName;
  final AlarmSetting initialSetting;

  const CustomAlarmSettingsDialog({
    Key? key,
    required this.courtName,
    required this.initialSetting,
  }) : super(key: key);

  @override
  State<CustomAlarmSettingsDialog> createState() =>
      _CustomAlarmSettingsDialogState();
}

class _CustomAlarmSettingsDialogState
    extends State<CustomAlarmSettingsDialog> {
  late AlarmSetting _currentSetting;
  final List<CustomAlarmTime> _customTimes = [];

  @override
  void initState() {
    super.initState();
    _currentSetting = widget.initialSetting;
    _customTimes.addAll(widget.initialSetting.customTimes);
  }

  void _addCustomTime() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('알림 시간 설정'),
        message: const Text('프리셋을 선택하거나 직접 설정하세요'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _customTimes.add(CustomAlarmTime(days: 3, hours: 0, minutes: 0));
              });
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.time, size: 20),
                SizedBox(width: 8),
                Text('3일 전'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _customTimes.add(CustomAlarmTime(days: 0, hours: 12, minutes: 0));
              });
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.time, size: 20),
                SizedBox(width: 8),
                Text('12시간 전'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _customTimes.add(CustomAlarmTime(days: 0, hours: 0, minutes: 30));
              });
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.time, size: 20),
                SizedBox(width: 8),
                Text('30분 전'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoModalPopup(
                context: context,
                builder: (context) => _CustomTimePickerDialog(
                  onTimeSelected: (customTime) {
                    setState(() {
                      _customTimes.add(customTime);
                    });
                  },
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.slider_horizontal_3, size: 20),
                SizedBox(width: 8),
                Text('직접 설정하기'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }

  void _removeCustomTime(int index) {
    setState(() {
      _customTimes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          '${widget.courtName} 알림 설정',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 기본 알림 옵션
          _buildSwitchRow(
            '예약 1일 전 알림',
            _currentSetting.oneDayBefore,
            (value) {
              setState(() {
                _currentSetting =
                    _currentSetting.copyWith(oneDayBefore: value);
              });
            },
          ),
          const SizedBox(height: 8),
          _buildSwitchRow(
            '예약 1시간 전 알림',
            _currentSetting.oneHourBefore,
            (value) {
              setState(() {
                _currentSetting =
                    _currentSetting.copyWith(oneHourBefore: value);
              });
            },
          ),
          const SizedBox(height: 16),
          // 커스텀 알림
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '커스텀 알림',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._customTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final time = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(time.displayText),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: () => _removeCustomTime(index),
                    child: const Icon(
                      CupertinoIcons.minus_circle_fill,
                      color: CupertinoColors.destructiveRed,
                      size: 20,
                    ),
                  ),
                ],
              ),
            );
          }),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            onPressed: _addCustomTime,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.add_circled, size: 20),
                SizedBox(width: 4),
                Text('커스텀 시간 추가'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '취소',
            style: TextStyle(color: CupertinoColors.destructiveRed),
          ),
        ),
        CupertinoDialogAction(
          onPressed: () {
            final newSetting =
                _currentSetting.copyWith(customTimes: _customTimes);
            Navigator.pop(context, newSetting);
          },
          child: const Text(
            '저장',
            style: TextStyle(color: CupertinoColors.activeBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow(
      String title, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CustomTimePickerDialog extends StatefulWidget {
  final Function(CustomAlarmTime) onTimeSelected;

  const _CustomTimePickerDialog({required this.onTimeSelected});

  @override
  State<_CustomTimePickerDialog> createState() =>
      _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<_CustomTimePickerDialog> {
  int _selectedDays = 0;
  int _selectedHours = 0;
  int _selectedMinutes = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const Text(
                  '알림 시간 설정',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final customTime = CustomAlarmTime(
                      days: _selectedDays,
                      hours: _selectedHours,
                      minutes: _selectedMinutes,
                    );
                    widget.onTimeSelected(customTime);
                    Navigator.pop(context);
                  },
                  child: const Text('추가'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController:
                        FixedExtentScrollController(initialItem: _selectedDays),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedDays = index;
                      });
                    },
                    children:
                        List.generate(30, (index) => Center(child: Text('$index'))),
                  ),
                ),
                const Text('일', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                        initialItem: _selectedHours),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedHours = index;
                      });
                    },
                    children:
                        List.generate(24, (index) => Center(child: Text('$index'))),
                  ),
                ),
                const Text('시간', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                        initialItem: _selectedMinutes ~/ 5),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedMinutes = index * 5;
                      });
                    },
                    children: List.generate(
                        12, (index) => Center(child: Text('${index * 5}'))),
                  ),
                ),
                const Text('분 전', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<AlarmSetting?> showCustomAlarmSettingsDialog(
  BuildContext context,
  String courtName,
  AlarmSetting initialSetting,
) {
  return showCupertinoDialog<AlarmSetting>(
    context: context,
    builder: (context) => CustomAlarmSettingsDialog(
      courtName: courtName,
      initialSetting: initialSetting,
    ),
  );
}
