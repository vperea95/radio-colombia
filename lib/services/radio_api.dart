import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/station.dart';
import '../utils/text_utils.dart';

class RadioApiException implements Exception {
  const RadioApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cliente del directorio comunitario Radio Browser (https://www.radio-browser.info).
/// Es gratuito y no requiere API key.
class RadioApi {
  static const _servers = [
    'https://de1.api.radio-browser.info',
    'https://de2.api.radio-browser.info',
    'https://fi1.api.radio-browser.info',
    'https://all.api.radio-browser.info',
  ];
  static const _headers = {'User-Agent': 'RadioColombia/1.0'};

  String? _workingServer;

  Future<List<Station>> fetchColombianStations() async {
    const path = '/json/stations/search'
        '?countrycode=CO&hidebroken=true&order=clickcount&reverse=true&limit=1000';

    final servers = [
      if (_workingServer != null) _workingServer!,
      ..._servers.where((s) => s != _workingServer),
    ];

    Object? lastError;
    for (final server in servers) {
      try {
        final response = await http
            .get(Uri.parse('$server$path'), headers: _headers)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        _workingServer = server;
        return _clean(data.map((e) => Station.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        lastError = e;
      }
    }
    throw RadioApiException(
      'No se pudo cargar la lista de emisoras. Revisa tu conexión a internet. ($lastError)',
    );
  }

  /// Quita emisoras sin URL y duplicados (mismo nombre en la misma ciudad).
  List<Station> _clean(Iterable<Station> stations) {
    final seen = <String>{};
    final result = <Station>[];
    for (final station in stations) {
      if (station.name.isEmpty || station.streamUrl.isEmpty) continue;
      final nameKey = normalize(station.name).replaceAll(RegExp(r'[^a-z0-9]'), '');
      final key = nameKey.isEmpty ? station.id : '$nameKey|${normalize(station.state)}';
      if (!seen.add(key)) continue;
      result.add(station);
    }
    return result;
  }

  /// La API pide registrar cada reproducción; así mejora el ranking de emisoras.
  Future<void> registerClick(String stationId) async {
    final server = _workingServer ?? _servers.first;
    try {
      await http
          .get(Uri.parse('$server/json/url/$stationId'), headers: _headers)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // No es crítico si falla.
    }
  }
}
