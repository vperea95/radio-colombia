import 'package:flutter/services.dart';

/// Pide a Android mantener el Wi-Fi y la CPU despiertos mientras suena la radio,
/// para que no se corte con la pantalla apagada. El código nativo está en MainActivity.kt.
class PlaybackLocks {
  static const _channel = MethodChannel('radio_colombia/locks');
  static bool _held = false;

  static Future<void> acquire() async {
    if (_held) return;
    _held = true;
    try {
      await _channel.invokeMethod<void>('acquire');
    } catch (_) {
      // En iOS no existe este canal; el sistema lo maneja solo.
    }
  }

  static Future<void> release() async {
    if (!_held) return;
    _held = false;
    try {
      await _channel.invokeMethod<void>('release');
    } catch (_) {}
  }
}
