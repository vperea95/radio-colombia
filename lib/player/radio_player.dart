import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/station.dart';
import 'playback_locks.dart';

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

  /// El usuario quiere escuchar (no pausó ni detuvo).
  bool _wantsPlaying = false;

  /// La emisora actual llegó a sonar; solo entonces se reconecta sola si se cae.
  bool _hasPlayed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  /// Si la pausa dura más que esto, al reanudar se reconecta para volver al vivo.
  static const _liveReconnectAfter = Duration(seconds: 30);
  static const _maxReconnectAttempts = 8;

  Station? get current => _current;
  PlayerStatus get status => _status;
  bool get isPlaying => _status == PlayerStatus.playing;
  bool get isLoading => _status == PlayerStatus.loading;
  double get volume => _player.volume;

  /// Canción o programa actual, si la emisora lo transmite (metadatos ICY).
  String? get nowPlaying => _nowPlaying;

  String get statusLabel => switch (_status) {
        PlayerStatus.loading => _reconnectAttempts > 0 ? 'Reconectando…' : 'Conectando…',
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
    _wantsPlaying = false;
    _reconnectTimer?.cancel();
    _pausedAt = DateTime.now();
    unawaited(PlaybackLocks.release());
    await _player.pause();
    // Si estaba esperando para reconectar, el reproductor no emite cambios.
    if (_player.processingState == ProcessingState.idle && _current != null) {
      _status = PlayerStatus.paused;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    final station = _current;
    if (station == null) return;
    final pausedFor =
        _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
    if (pausedFor > _liveReconnectAfter ||
        _player.processingState == ProcessingState.idle) {
      await _load(station);
    } else {
      _pausedAt = null;
      _wantsPlaying = true;
      unawaited(PlaybackLocks.acquire());
      _startPlayback(station);
    }
  }

  Future<void> retry() async {
    final station = _current;
    if (station != null) await _load(station);
  }

  Future<void> stop() async {
    _wantsPlaying = false;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _current = null;
    _status = PlayerStatus.idle;
    _nowPlaying = null;
    _errorMessage = null;
    _pausedAt = null;
    unawaited(PlaybackLocks.release());
    notifyListeners();
    await _player.stop();
  }

  void setVolume(double value) {
    unawaited(_player.setVolume(value));
    notifyListeners();
  }

  Future<void> _load(Station station, {bool reconnecting = false}) async {
    _reconnectTimer?.cancel();
    if (!reconnecting) {
      _reconnectAttempts = 0;
      _hasPlayed = false;
      _nowPlaying = null;
    }
    _current = station;
    _status = PlayerStatus.loading;
    _errorMessage = null;
    _pausedAt = null;
    _wantsPlaying = true;
    notifyListeners();
    unawaited(PlaybackLocks.acquire());

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
      if (!isCurrent(station) || !_wantsPlaying) return;
      _startPlayback(station);
      if (!reconnecting) onStationStarted?.call(station);
    } on PlayerInterruptedException {
      // Se eligió otra emisora antes de terminar de cargar: no es un error.
    } catch (e) {
      if (!isCurrent(station)) return;
      debugPrint('Error al cargar ${station.name}: $e');
      _handleFailure('No se pudo conectar con ${station.name}. Puede estar fuera del aire.');
    }
  }

  void _startPlayback(Station station) {
    // play() solo termina cuando se pausa, por eso no se espera.
    _player.play().catchError((Object e) {
      if (isCurrent(station)) _handleFailure('Se perdió la conexión con la emisora.');
    });
  }

  /// Si la emisora ya estaba sonando, intenta reconectar sola; si no, muestra el error.
  void _handleFailure(String message) {
    if (_reconnectTimer?.isActive ?? false) return;
    final station = _current;
    final canReconnect = station != null &&
        _wantsPlaying &&
        _hasPlayed &&
        _reconnectAttempts < _maxReconnectAttempts;

    if (!canReconnect) {
      _setError(message);
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: math.min(2 * _reconnectAttempts, 15));
    debugPrint('Reconectando ${station.name} en ${delay.inSeconds}s (intento $_reconnectAttempts)');
    _status = PlayerStatus.loading;
    _errorMessage = null;
    notifyListeners();
    _reconnectTimer = Timer(delay, () {
      if (isCurrent(station) && _wantsPlaying) _load(station, reconnecting: true);
    });
  }

  void _onPlayerState(PlayerState state) {
    if (_current == null || _status == PlayerStatus.error) return;

    if (state.processingState == ProcessingState.completed) {
      // En una radio en vivo, "terminó" significa que se cortó la señal.
      _handleFailure('La transmisión se interrumpió.');
      return;
    }

    final next = switch (state.processingState) {
      ProcessingState.loading || ProcessingState.buffering => PlayerStatus.loading,
      ProcessingState.ready when state.playing => PlayerStatus.playing,
      // Listo pero aún sin play(): seguimos mostrando "Conectando…".
      ProcessingState.ready when _status == PlayerStatus.loading && _wantsPlaying =>
        PlayerStatus.loading,
      ProcessingState.ready => PlayerStatus.paused,
      _ => _status,
    };

    if (next == PlayerStatus.playing) {
      _hasPlayed = true;
      _reconnectAttempts = 0;
    }

    if (next != _status) {
      _status = next;
      notifyListeners();
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    debugPrint('Error de reproducción: $error');
    if (_current != null) _handleFailure('Se perdió la conexión con la emisora.');
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
    _wantsPlaying = false;
    _status = PlayerStatus.error;
    _errorMessage = message;
    unawaited(PlaybackLocks.release());
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _stateSub.cancel();
    _eventSub.cancel();
    _icySub.cancel();
    _player.dispose();
    PlaybackLocks.release();
    super.dispose();
  }
}
