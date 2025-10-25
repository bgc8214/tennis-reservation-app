import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteProvider with ChangeNotifier {
  Set<String> _favorites = {};

  Set<String> get favorites => _favorites;

  bool isFavorite(String courtName) => _favorites.contains(courtName);

  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList('favorites') ?? [];
      _favorites = Set<String>.from(favoritesJson);
      notifyListeners();
      debugPrint('즐겨찾기 로드 완료: $_favorites');
    } catch (e) {
      debugPrint('즐겨찾기 로드 실패: $e');
    }
  }

  Future<void> toggleFavorite(String courtName) async {
    if (_favorites.contains(courtName)) {
      _favorites.remove(courtName);
    } else {
      _favorites.add(courtName);
    }

    // SharedPreferences에 저장
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorites', _favorites.toList());
      notifyListeners();
      debugPrint('즐겨찾기 업데이트: $_favorites');
    } catch (e) {
      debugPrint('즐겨찾기 저장 실패: $e');
    }
  }

  List<String> sortCourts(List<String> courtNames) {
    return courtNames.toList()
      ..sort((a, b) {
        final aIsFavorite = _favorites.contains(a);
        final bIsFavorite = _favorites.contains(b);

        if (aIsFavorite && !bIsFavorite) return -1;
        if (!aIsFavorite && bIsFavorite) return 1;

        return 0;
      });
  }
}
