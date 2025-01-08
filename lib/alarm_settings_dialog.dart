import 'package:flutter/cupertino.dart';

void showAlarmSettingsDialog(BuildContext context, String location,
    bool oneDayBefore, bool oneHourBefore, Function(bool, bool) onAlarmSettingsChanged) {
  showCupertinoDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return CupertinoAlertDialog(
            title: const Text('알람 설정',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('예약 1일 전 알람', style: TextStyle(fontSize: 16)),
                    CupertinoSwitch(
                      value: oneDayBefore,
                      onChanged: (value) {
                        setState(() {
                          oneDayBefore = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('예약 1시간 전 알람', style: TextStyle(fontSize: 16)),
                    CupertinoSwitch(
                      value: oneHourBefore,
                      onChanged: (value) {
                        setState(() {
                          oneHourBefore = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  onAlarmSettingsChanged(oneDayBefore, oneHourBefore);
                  Navigator.of(context).pop();
                },
                child: const Text('저장',
                    style: TextStyle(color: CupertinoColors.activeGreen)),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('취소'),
              ),
            ],
          );
        },
      );
    },
  );
}
