import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda en el dispositivo los IDs de las emisoras favoritas.
class FavoritesService extends ChangeNotifier {
  static const _key = 'favorite_station_ids';

  final Set<String> _ids = {};
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(_prefs!.getStringList(_key) ?? const []);
    notifyListeners();
  }

  bool isFavorite(String id) => _ids.contains(id);

  Future<void> toggle(String id) async {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
    await _prefs?.setStringList(_key, _ids.toList());
  }
}
