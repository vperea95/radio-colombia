import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/station.dart';

enum PlayerStatus { idle, loading, playing, paused, error }

/// Controla la reproducción de la emisora actual y expone su estado a la UI.
class RadioPlayer extends ChangeNotifier {
  RadioPlayer({this.onStationStarted}) {
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
    _eventSub = _player.playbackEventStream.listen((_) {}, onError: _onStreamError);
    _icySub = _player.icyMetadataStream.listen(_onIcyMetadata);
  }

  final void Function(Station station)? onStationStarted;

  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<PlaybackEvent> _eventSub;
  late final StreamSubscription<IcyMetadata?> _icySub;

  Station? _current;
  PlayerStatus _status = PlayerStatus.idle;
  String? _nowPlaying;
  String? _errorMessage;
  DateTime? _pausedAt;

  /// Si la pausa dura más que esto, al reanudar se reconecta para volver al vivo.
  static const _liveReconnectAfter = Duration(seconds: 30);

  Station? get current => _current;
  PlayerStatus get status => _status;
  bool get isPlaying => _status == PlayerStatus.playing;
  bool get isLoading => _status == PlayerStatus.loading;
  double get volume => _player.volume;

  /// Canción o programa actual, si la emisora lo transmite (metadatos ICY).
  String? get nowPlaying => _nowPlaying;

  String get statusLabel => switch (_status) {
        PlayerStatus.loading => 'Conectando…',
        PlayerStatus.playing => _nowPlaying ?? 'En vivo',
        PlayerStatus.paused => 'En pausa',
        PlayerStatus.error => _errorMessage ?? 'No se pudo reproducir',
        PlayerStatus.idle => '',
      };

  bool isCurrent(Station station) => _current?.id == station.id;

  /// Toque en una emisora de la lista.
  Future<void> togglePlay(Station station) async {
    if (!isCurrent(station)) return _load(station);
    switch (_status) {
      case PlayerStatus.playing || PlayerStatus.loading:
        await pause();
      case PlayerStatus.paused:
        await resume();
      case PlayerStatus.error || PlayerStatus.idle:
        await _load(station);
    }
  }

  Future<void> pause() async {
    _pausedAt = DateTime.now();
    await _player.pause();
  }

  Future<void> resume() async {
    final station = _current;
    if (station == null) return;
    final pausedFor =
        _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
    if (pausedFor > _liveReconnectAfter) {
      await _load(station);
    } else {
      _pausedAt = null;
      _startPlayback(station);
    }
  }

  Future<void> retry() async {
    final station = _current;
    if (station != null) await _load(station);
  }

  Future<void> stop() async {
    _current = null;
    _status = PlayerStatus.idle;
    _nowPlaying = null;
    _errorMessage = null;
    _pausedAt = null;
    notifyListeners();
    await _player.stop();
  }

  void setVolume(double value) {
    unawaited(_player.setVolume(value));
    notifyListeners();
  }

  Future<void> _load(Station station) async {
    _current = station;
    _status = PlayerStatus.loading;
    _nowPlaying = null;
    _errorMessage = null;
    _pausedAt = null;
    notifyListeners();

    try {
      final uri = Uri.parse(station.streamUrl);
      final tag = MediaItem(
        id: station.id,
        title: station.name,
        artist: station.state.isNotEmpty ? station.state : 'Colombia',
        album: 'Radio Colombia',
        artUri: station.favicon.isNotEmpty ? Uri.tryParse(station.favicon) : null,
      );
      final AudioSource source = station.isHls
          ? HlsAudioSource(uri, tag: tag)
          : AudioSource.uri(uri, tag: tag);

      await _player.setAudioSource(source);

      // El usuario cambió de emisora o pausó mientras cargaba.
      if (!isCurrent(station) || _pausedAt != null) return;
      _startPlayback(station);
      onStationStarted?.call(station);
    } on PlayerInterruptedException {
      // Se eligió otra emisora antes de terminar de cargar: no es un error.
    } catch (e) {
      if (!isCurrent(station)) return;
      debugPrint('Error al cargar ${station.name}: $e');
      _setError('No se pudo conectar con ${station.name}. Puede estar fuera del aire.');
    }
  }

  void _startPlayback(Station station) {
    // play() solo termina cuando se pausa, por eso no se espera.
    _player.play().catchError((Object e) {
      if (isCurrent(station)) _setError('Se perdió la conexión con la emisora.');
    });
  }

  void _onPlayerState(PlayerState state) {
    if (_current == null || _status == PlayerStatus.error) return;

    if (state.processingState == ProcessingState.completed) {
      _setError('La transmisión se interrumpió.');
      return;
    }

    final next = switch (state.processingState) {
      ProcessingState.loading || ProcessingState.buffering => PlayerStatus.loading,
      ProcessingState.ready when state.playing => PlayerStatus.playing,
      // Listo pero aún sin play(): seguimos mostrando "Conectando…".
      ProcessingState.ready when _status == PlayerStatus.loading && _pausedAt == null =>
        PlayerStatus.loading,
      ProcessingState.ready => PlayerStatus.paused,
      _ => _status,
    };

    if (next != _status) {
      _status = next;
      notifyListeners();
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    debugPrint('Error de reproducción: $error');
    if (_current != null) _setError('Se perdió la conexión con la emisora.');
  }

  void _onIcyMetadata(IcyMetadata? metadata) {
    final title = metadata?.info?.title?.trim();
    final next = (title == null || title.isEmpty) ? null : title;
    if (next != _nowPlaying) {
      _nowPlaying = next;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _status = PlayerStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _eventSub.cancel();
    _icySub.cancel();
    _player.dispose();
    super.dispose();
  }
}
