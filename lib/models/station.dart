/// Una emisora tal como la entrega la API de Radio Browser.
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.favicon = '',
    this.state = '',
    this.tags = const [],
    this.codec = '',
    this.bitrate = 0,
    this.votes = 0,
    this.isHls = false,
  });

  final String id;
  final String name;
  final String streamUrl;
  final String favicon;

  /// Departamento o ciudad reportada por la emisora.
  final String state;
  final List<String> tags;
  final String codec;
  final int bitrate;
  final int votes;
  final bool isHls;

  factory Station.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();
    int integer(String key) {
      final value = json[key];
      if (value is int) return value;
      return int.tryParse('$value') ?? 0;
    }

    final resolved = str('url_resolved');
    return Station(
      id: str('stationuuid'),
      name: str('name'),
      streamUrl: resolved.isNotEmpty ? resolved : str('url'),
      favicon: str('favicon'),
      state: str('state'),
      tags: str('tags')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      codec: str('codec'),
      bitrate: integer('bitrate'),
      votes: integer('votes'),
      isHls: integer('hls') == 1,
    );
  }

  /// Ej.: "Valle del Cauca, salsa, tropical".
  String get subtitle {
    final parts = <String>[if (state.isNotEmpty) state, ...tags.take(2)];
    return parts.isEmpty ? 'Colombia' : parts.join(', ');
  }

  /// Ej.: "MP3, 128 kbps".
  String get technicalInfo {
    final parts = <String>[
      if (codec.isNotEmpty) codec,
      if (bitrate > 0) '$bitrate kbps',
    ];
    return parts.join(', ');
  }
}
