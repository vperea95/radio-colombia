import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Funciones de Android que ayudan a que la radio siga sonando con la pantalla
/// apagada o fuera de la app. El código nativo está en MainActivity.kt.
class BackgroundSupport {
  static const _channel = MethodChannel('radio_colombia/background');
  static bool _locksHeld = false;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Mantiene la CPU y el Wi-Fi despiertos mientras se quiere escuchar.
  static Future<void> acquireLocks() async {
    if (_locksHeld) return;
    _locksHeld = true;
    await _invoke<void>('acquireLocks');
  }

  static Future<void> releaseLocks() async {
    if (!_locksHeld) return;
    _locksHeld = false;
    await _invoke<void>('releaseLocks');
  }

  /// Si es `false`, Android puede cortar la radio para ahorrar batería.
  static Future<bool> isIgnoringBatteryOptimizations() async =>
      await _invoke<bool>('isIgnoringBatteryOptimizations') ?? true;

  /// Abre la ventana del sistema para usar la batería sin restricciones.
  static Future<bool> requestIgnoreBatteryOptimizations() async =>
      await _invoke<bool>('requestIgnoreBatteryOptimizations') ?? false;

  /// Abre la pantalla "Información de la app" en los ajustes del sistema.
  static Future<bool> openAppSettings() async =>
      await _invoke<bool>('openAppSettings') ?? false;

  /// Manda la app al fondo como el botón de inicio, sin cerrarla.
  static Future<bool> moveTaskToBack() async =>
      await _invoke<bool>('moveTaskToBack') ?? false;

  /// Marca del celular en minúsculas, por ejemplo "xiaomi" o "samsung".
  static Future<String> manufacturer() async =>
      (await _invoke<String>('manufacturer') ?? '').toLowerCase();

  static Future<T?> _invoke<T>(String method) async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } catch (e) {
      debugPrint('BackgroundSupport.$method: $e');
      return null;
    }
  }
}
