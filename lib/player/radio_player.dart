import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:just_audio/just_audio.dart';

import '../models/station.dart';
import 'background_support.dart';

enum PlayerStatus { idle, loading, playing, paused, error }

// Botones de la notificación, con los íconos que trae audio_service.
const _playControl = MediaControl(
  androidIcon: 'drawable/audio_service_play_arrow',
  label: 'Reproducir',
  action: MediaAction.play,
);
const _pauseControl = MediaControl(
  androidIcon: 'drawable/audio_service_pause',
  label: 'Pausar',
  action: MediaAction.pause,
);
const _stopControl = MediaControl(
  androidIcon: 'drawable/audio_service_stop',
  label: 'Detener',
  action: MediaAction.stop,
);

/// Controla la reproducción de la emisora actual, expone su estado a la UI y lo
/// publica en la notificación y en la pantalla de bloqueo (audio_service).
///
/// Regla clave para que la radio no se corte con la pantalla apagada: mientras
/// el usuario quiera escuchar, a audio_service se le informa `playing: true`,
/// aunque se esté reconectando o haya una llamada en curso. Si se le informara
/// una pausa, el servicio saldría del primer plano, Android no lo deja volver a
/// entrar desde segundo plano y al rato cierra la app.
class RadioPlayer extends BaseAudioHandler with ChangeNotifier {
  RadioPlayer({this.onStationStarted}) {
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
    _eventSub =
        _player.playbackEventStream.listen((_) {}, onError: _onStreamError);
    _icySub = _player.icyMetadataStream.listen(_onIcyMetadata);
    unawaited(_initAudioSession());
  }

  final void Function(Station station)? onStationStarted;

  // Las interrupciones (llamadas, audífonos) se manejan aquí y no en just_audio,
  // para no soltar el servicio en primer plano durante una llamada.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<PlaybackEvent> _eventSub;
  late final StreamSubscription<IcyMetadata?> _icySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  Station? _current;
  PlayerStatus _status = PlayerStatus.idle;
  String? _nowPlaying;
  String? _errorMessage;
  DateTime? _pausedAt;

  /// El usuario quiere escuchar (no pausó ni detuvo).
  bool _wantsPlaying = false;

  /// En pausa porque otra app pidió el audio un momento (por ejemplo, una llamada).
  bool _interrupted = false;

  /// La conexión se cayó; al reanudar hay que volver a conectar.
  bool _sourceBroken = false;

  /// La emisora actual llegó a sonar; solo entonces se reconecta sola si se cae.
  bool _hasPlayed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  /// Vigila que la emisora no se quede cargando para siempre.
  Timer? _stallTimer;

  /// Aumenta con cada carga, para ignorar el resultado de cargas anteriores.
  int _loadId = 0;

  /// Si la pausa dura más que esto, al reanudar se reconecta para volver al vivo.
  static const _liveReconnectAfter = Duration(seconds: 30);
  static const _maxReconnectAttempts = 12;
  static const _connectTimeout = Duration(seconds: 30);
  static const _stallTimeout = Duration(seconds: 20);

  Station? get current => _current;
  PlayerStatus get status => _status;
  bool get isPlaying => _status == PlayerStatus.playing;
  bool get isLoading => _status == PlayerStatus.loading;
  double get volume => _player.volume;

  /// Canción o programa actual, si la emisora lo transmite (metadatos ICY).
  String? get nowPlaying => _nowPlaying;

  String get statusLabel => switch (_status) {
        PlayerStatus.loading =>
          _reconnectAttempts > 0 ? 'Reconectando…' : 'Conectando…',
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

  /// Botón de reproducir de la notificación, la pantalla de bloqueo o los audífonos.
  @override
  Future<void> play() => resume();

  @override
  Future<void> pause() async {
    if (_current == null) return;
    _wantsPlaying = false;
    _interrupted = false;
    _cancelTimers();
    _pausedAt = DateTime.now();
    unawaited(BackgroundSupport.releaseLocks());
    if (_status != PlayerStatus.error) _status = PlayerStatus.paused;
    _changed();
    await _player.pause();
  }

  /// Reanuda la emisora actual. Si la pausa fue larga o la conexión se cayó,
  /// vuelve a conectar para seguir en vivo.
  Future<void> resume() async {
    final station = _current;
    if (station == null) return;
    _interrupted = false;
    if (_status == PlayerStatus.error) return _load(station);

    final pausedFor = _pausedAt == null
        ? Duration.zero
        : DateTime.now().difference(_pausedAt!);
    if (_sourceBroken ||
        pausedFor > _liveReconnectAfter ||
        _player.processingState == ProcessingState.idle) {
      _reconnectAttempts = 0;
      return _load(station, retry: _hasPlayed);
    }

    _pausedAt = null;
    _wantsPlaying = true;
    _status = PlayerStatus.loading;
    unawaited(BackgroundSupport.acquireLocks());
    _changed();
    _watchStall();
    _startPlayback(_loadId);
  }

  Future<void> retry() async {
    final station = _current;
    if (station != null) await _load(station);
  }

  @override
  Future<void> stop() async {
    _loadId++;
    _wantsPlaying = false;
    _interrupted = false;
    _sourceBroken = false;
    _cancelTimers();
    _reconnectAttempts = 0;
    _current = null;
    _status = PlayerStatus.idle;
    _nowPlaying = null;
    _errorMessage = null;
    _pausedAt = null;
    unawaited(BackgroundSupport.releaseLocks());
    // Con el estado "idle", audio_service quita la notificación y detiene el servicio.
    _changed();
    await _player.stop();
    try {
      await (await AudioSession.instance).setActive(false);
    } catch (_) {
      // No es crítico.
    }
  }

  /// La app se quitó de las recientes: si no está sonando, se cierra todo.
  @override
  Future<void> onTaskRemoved() async {
    if (!_wantsPlaying) await stop();
  }

  void setVolume(double value) {
    unawaited(_player.setVolume(value));
    notifyListeners();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _interruptionSub =
          session.interruptionEventStream.listen(_onInterruption);
      // Se desconectaron los audífonos: se pausa para que no suene por el parlante.
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        unawaited(pause());
      });
    } catch (e) {
      debugPrint('No se pudo configurar la sesión de audio: $e');
    }
  }

  Future<void> _load(Station station, {bool retry = false}) async {
    final loadId = ++_loadId;
    _cancelTimers();
    if (!retry) {
      _reconnectAttempts = 0;
      _hasPlayed = false;
      _nowPlaying = null;
    }
    final isNewItem = !retry || !isCurrent(station);
    _current = station;
    _status = PlayerStatus.loading;
    _errorMessage = null;
    _pausedAt = null;
    _wantsPlaying = true;
    _interrupted = false;
    _sourceBroken = false;
    unawaited(BackgroundSupport.acquireLocks());
    if (isNewItem) mediaItem.add(_mediaItemFor(station));
    _changed();
    _watchStall();

    try {
      final uri = Uri.parse(station.streamUrl);
      final AudioSource source =
          station.isHls ? HlsAudioSource(uri) : AudioSource.uri(uri);
      await _player.setAudioSource(source);

      // El usuario cambió de emisora o detuvo mientras cargaba.
      if (loadId != _loadId) return;
      if (!retry) onStationStarted?.call(station);
      // En pausa por el usuario o por una llamada: sonará al reanudar.
      if (!_wantsPlaying || _interrupted) return;
      _startPlayback(loadId);
    } on PlayerInterruptedException {
      // Se eligió otra emisora o se detuvo antes de terminar de cargar.
    } catch (e) {
      if (loadId != _loadId) return;
      debugPrint('Error al cargar ${station.name}: $e');
      _handleFailure(
          'No se pudo conectar con ${station.name}. Puede estar fuera del aire.');
    }
  }

  void _startPlayback(int loadId) {
    // play() solo termina cuando se pausa o falla, por eso no se espera.
    _player.play().catchError((Object e) {
      if (loadId == _loadId) {
        _handleFailure('Se perdió la conexión con la emisora.');
      }
    });
  }

  /// Si la emisora ya estaba sonando, intenta reconectar sola; si no, muestra el error.
  void _handleFailure(String message) {
    final station = _current;
    if (station == null) return;
    _sourceBroken = true;
    // En pausa (por el usuario o por una llamada): se reconecta al reanudar.
    if (!_wantsPlaying || _interrupted) return;
    if (_reconnectTimer?.isActive ?? false) return;
    _stallTimer?.cancel();

    if (!_hasPlayed || _reconnectAttempts >= _maxReconnectAttempts) {
      _setError(message);
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: math.min(2 * _reconnectAttempts, 15));
    debugPrint(
        'Reconectando ${station.name} en ${delay.inSeconds} s (intento $_reconnectAttempts)');
    // Se sigue informando "sonando" a la notificación: el servicio no sale del
    // primer plano mientras se reconecta.
    _status = PlayerStatus.loading;
    _errorMessage = null;
    _changed();
    _reconnectTimer = Timer(delay, () {
      if (isCurrent(station) && _wantsPlaying && !_interrupted) {
        unawaited(_load(station, retry: true));
      }
    });
  }

  /// Si la emisora no empieza a sonar a tiempo, se trata como un corte.
  void _watchStall() {
    _stallTimer?.cancel();
    final station = _current;
    if (station == null) return;
    final loadId = _loadId;
    _stallTimer = Timer(_hasPlayed ? _stallTimeout : _connectTimeout, () {
      if (loadId != _loadId || !isCurrent(station)) return;
      if (!_wantsPlaying || _interrupted || _status != PlayerStatus.loading) {
        return;
      }
      _handleFailure(_hasPlayed
          ? 'La señal de la emisora está muy débil.'
          : 'No se pudo conectar con ${station.name}. Puede estar fuera del aire.');
    });
  }

  void _onPlayerState(PlayerState state) {
    if (_current == null || _status == PlayerStatus.error || _interrupted) {
      return;
    }
    // Esperando para reconectar: se sigue mostrando "Reconectando…".
    if (_reconnectTimer?.isActive ?? false) return;

    switch (state.processingState) {
      case ProcessingState.completed:
        // En una radio en vivo, "terminó" significa que se cortó la señal.
        _handleFailure('La transmisión se interrumpió.');
      case ProcessingState.loading || ProcessingState.buffering:
        if (_wantsPlaying && _status != PlayerStatus.loading) {
          _setStatus(PlayerStatus.loading);
          _watchStall();
        }
      case ProcessingState.ready:
        if (state.playing) {
          _hasPlayed = true;
          _reconnectAttempts = 0;
          _sourceBroken = false;
          _stallTimer?.cancel();
          _setStatus(PlayerStatus.playing);
        } else if (!_wantsPlaying) {
          _setStatus(PlayerStatus.paused);
        }
      // Lista pero aún sin play(): se sigue mostrando "Conectando…".
      case ProcessingState.idle:
        break;
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    // just_audio avisa "abort" cuando se carga otra emisora antes de que la
    // anterior termine de conectar: no es una falla.
    if (error is PlatformException && error.code == 'abort') return;
    debugPrint('Error de reproducción: $error');
    _handleFailure('Se perdió la conexión con la emisora.');
  }

  void _onInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Android baja el volumen solo, por ejemplo con una notificación.
          break;
        case AudioInterruptionType.pause:
          // Otra app pidió el audio un momento (por ejemplo, una llamada). Se
          // pausa sin soltar el servicio, y al terminar se reanuda sola.
          if (_wantsPlaying && !_interrupted) {
            _interrupted = true;
            _cancelTimers();
            _pausedAt = DateTime.now();
            _status = PlayerStatus.paused;
            _changed();
            unawaited(_player.pause());
          }
        case AudioInterruptionType.unknown:
          // Otra app empezó a sonar: se pausa como si lo hubiera hecho el usuario.
          if (_wantsPlaying || _interrupted) unawaited(pause());
      }
    } else if (event.type == AudioInterruptionType.pause && _interrupted) {
      unawaited(resume());
    }
  }

  void _onIcyMetadata(IcyMetadata? metadata) {
    final title = metadata?.info?.title?.trim();
    final next = (title == null || title.isEmpty) ? null : title;
    if (next == _nowPlaying) return;
    _nowPlaying = next;
    final station = _current;
    if (station != null) mediaItem.add(_mediaItemFor(station));
    notifyListeners();
  }

  void _setError(String message) {
    _loadId++;
    _wantsPlaying = false;
    _interrupted = false;
    _cancelTimers();
    _status = PlayerStatus.error;
    _errorMessage = message;
    unawaited(BackgroundSupport.releaseLocks());
    _changed();
    // Se suelta la conexión para que no quede intentando en segundo plano.
    unawaited(_player.stop());
  }

  void _setStatus(PlayerStatus status) {
    if (_status == status) return;
    _status = status;
    _changed();
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _stallTimer?.cancel();
  }

  /// Avisa a la UI y actualiza la notificación.
  void _changed() {
    notifyListeners();
    _broadcastState();
  }

  /// Publica el estado en la notificación y en la pantalla de bloqueo.
  void _broadcastState() {
    if (_current == null) {
      playbackState.add(PlaybackState());
      return;
    }
    // Mientras se quiera escuchar se informa "sonando" (ver el comentario de la clase).
    final playing = _wantsPlaying;
    playbackState.add(PlaybackState(
      controls: [playing ? _pauseControl : _playControl, _stopControl],
      androidCompactActionIndices: const [0, 1],
      processingState: switch (_status) {
        PlayerStatus.playing => AudioProcessingState.ready,
        PlayerStatus.paused => _interrupted
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        PlayerStatus.loading => AudioProcessingState.buffering,
        PlayerStatus.error => AudioProcessingState.error,
        PlayerStatus.idle => AudioProcessingState.idle,
      },
      playing: playing,
      errorMessage: _status == PlayerStatus.error ? _errorMessage : null,
    ));
  }

  MediaItem _mediaItemFor(Station station) {
    final art = Uri.tryParse(station.favicon);
    final hasArt = art != null && (art.scheme == 'http' || art.scheme == 'https');
    return MediaItem(
      id: station.id,
      title: station.name,
      artist: _nowPlaying ??
          (station.state.isNotEmpty ? station.state : 'Colombia'),
      album: 'Radio Colombia',
      artUri: hasArt ? art : null,
    );
  }

  @override
  void dispose() {
    _cancelTimers();
    _stateSub.cancel();
    _eventSub.cancel();
    _icySub.cancel();
    _interruptionSub?.cancel();
    _noisySub?.cancel();
    _player.dispose();
    BackgroundSupport.releaseLocks();
    super.dispose();
  }
}
