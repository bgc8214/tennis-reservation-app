import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tennis_court.dart';

class CourtProvider with ChangeNotifier {
  List<TennisCourt> _courts = [];
  bool _isLoading = false;
  String? _error;

  List<TennisCourt> get courts => _courts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<TennisCourt> get visibleCourts =>
      _courts.where((court) => court.visible).toList();

  Future<void> fetchCourts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('tennis_courts').get();
      _courts = snapshot.docs
          .map((doc) => TennisCourt.fromFirestore(doc.data()))
          .toList();

      // 예약 시간순으로 정렬
      _courts.sort((a, b) => a
          .getNextReservationDate()
          .compareTo(b.getNextReservationDate()));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('테니스 코트 정보 가져오기 실패: $e');
    }
  }

  TennisCourt? getCourtByName(String name) {
    try {
      return _courts.firstWhere((court) => court.name == name);
    } catch (e) {
      return null;
    }
  }
}
