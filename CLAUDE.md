# Radio Colombia — contexto del proyecto

App móvil en Flutter para escuchar emisoras de radio colombianas en vivo, en celulares y tablets (Android; iOS preparado pero no se compila todavía).

Repositorio: https://github.com/vperea95/radio-colombia (rama `main`).

## Cómo trabajar con el usuario

- Responder siempre en español.
- El usuario trabaja en Windows, con `cmd`, en la carpeta `C:\Users\ANDRES\Downloads\radio_colombia\radio_colombia`.
- **No tiene Flutter ni Android SDK instalados localmente.** El APK se compila en GitHub Actions al hacer push a `main`. No proponer `flutter run` local salvo que el usuario decida instalar Flutter.
- Cuando haya que hacer pasos manuales (git, GitHub, instalar en el celular), darlos **uno a la vez** y en lenguaje simple.
- Para publicar cambios:
  ```bash
  git add .
  git commit -m "mensaje"
  git push
  ```
- Las advertencias `LF will be replaced by CRLF` al hacer `git add` son normales.

## Cómo se compila (importante)

El repositorio **no contiene** las carpetas `android/` ni `ios/`. El workflow `.github/workflows/compilar-apk.yml` hace esto en cada push:

1. Instala Java 17 y Flutter estable.
2. Ejecuta `flutter create --org co.radiocolombia --project-name radio_colombia --platforms=android .` para generar `android/` (no sobrescribe `lib/` ni `pubspec.yaml`) y borra `test/`.
3. Copia `plataforma/android/AndroidManifest.xml` sobre el manifest generado.
4. Toma la primera línea (`package ...`) del `MainActivity.kt` generado y le pega el resto de `plataforma/android/MainActivity.kt` (desde la línea 2). **Por eso la primera línea de `plataforma/android/MainActivity.kt` debe ser siempre la línea `package`.**
5. `flutter pub get` (si falla, `flutter pub upgrade --major-versions`).
6. `flutter build apk --release` y sube `app-release.apk` como artifact `radio-colombia-apk`.

Notas:
- Cualquier cambio nativo de Android va en `plataforma/android/` y, si hace falta, en el workflow.
- El APK se firma con la llave debug que se genera en cada ejecución, que es distinta cada vez. Por eso **hay que desinstalar la versión anterior antes de instalar una nueva** (si no, aparece "conflicto con paquete existente").
- GitHub Actions a veces se queda en "Waiting for a runner". Si pasan más de 15 minutos: Cancel workflow y luego Re-run all jobs.
- Avisos de "Node.js 20 deprecated" y "setup-java v4 deprecated" en Actions no afectan la compilación.

## Stack

- Flutter (SDK `^3.6.0`, Material 3, tema claro y oscuro según el sistema).
- `just_audio` (0.9.x): reproducción de streams (MP3/AAC/HLS) y metadatos ICY.
- `audio_service` (0.18.x): servicio en primer plano, notificación y controles en la pantalla de bloqueo. `RadioPlayer` es el `AudioHandler`.
- `audio_session`: foco de audio, llamadas y desconexión de audífonos.
- **No usar `just_audio_background`**: se traga los errores de conexión (nunca llegan a la app) y, ante cualquier corte, informa `playing: false`, lo que saca el servicio del primer plano (ver "Segundo plano en Android").
- `http`: cliente de la API.
- `shared_preferences`: favoritas (se guardan solo los IDs).
- Estado con `ChangeNotifier` + `ListenableBuilder` (sin provider ni riverpod). Las dependencias se pasan por constructor desde `main.dart`.

## Estructura

```
lib/
  main.dart                      AudioService.init con RadioPlayer como handler; crea RadioApi y FavoritesService
  theme.dart                     Colores de la bandera (AppColors) y FlagStripe bajo el AppBar
  models/station.dart            Modelo Station; fromJson de Radio Browser; deduce `department`
  services/radio_api.dart        Cliente Radio Browser con servidores de respaldo; limpia duplicados
  services/favorites_service.dart  Favoritas en SharedPreferences
  player/radio_player.dart       RadioPlayer (BaseAudioHandler + ChangeNotifier): estados, reconexión, notificación
  player/background_support.dart MethodChannel 'radio_colombia/background': locks, batería, ajustes, moveTaskToBack
  screens/home_screen.dart       Buscador, filtros (Favoritas, departamentos), lista o cuadrícula
  utils/text_utils.dart          normalize() (minúsculas y sin tildes) e initials()
  utils/departments.dart         Mapa de departamentos, alias y ciudades -> departamento
  widgets/                       station_tile, station_logo, mini_player, full_player_sheet,
                                 play_pause_button, equalizer_bars, background_help_sheet
plataforma/android/              AndroidManifest.xml y MainActivity.kt que copia el workflow
plataforma/ios/                  Fragmento de Info.plist (audio en segundo plano + http)
```

## Decisiones técnicas

**Fuente de emisoras.** Se usa la API de Radio Browser (gratuita, sin API key). La consulta es `/json/stations/search?countrycode=CO&hidebroken=true&order=clickcount&reverse=true&limit=1000`. Se prueban los servidores de1, de2, fi1 y all, y se recuerda el que funcionó. Se descartan emisoras sin URL y los duplicados con el mismo nombre normalizado en la misma ubicación. Al reproducir se llama a `/json/url/{uuid}` como cortesía, porque así lo pide la API.

**Departamentos.** Los datos de ubicación son inconsistentes ("Cali", "Valle", "Valle del Cauca" o vacío). `findDepartment()` busca, en este orden:
1. El campo `state`, contra departamentos, alias y ciudades.
2. El nombre de la emisora, solo contra ciudades.
3. Las etiquetas, solo contra ciudades.

La coincidencia es por palabra completa y prueba primero las claves más largas, para que "norte de santander" gane sobre "santander". Los chips de filtro usan `station.department`.

**Reproductor (`RadioPlayer`).**
- Es a la vez el `AudioHandler` de audio_service y el `ChangeNotifier` de la UI. Los botones de la notificación, la pantalla de bloqueo y los audífonos llaman a sus `play()`, `pause()` y `stop()`.
- Estados: `idle`, `loading`, `playing`, `paused`, `error`.
- `_wantsPlaying` indica si el usuario quiere escuchar; `_interrupted`, si está en pausa por una llamada.
- Si la emisora ya llegó a sonar (`_hasPlayed`) y se cae, se reconecta sola hasta 12 veces, con una espera de `min(2*n, 15)` segundos. Mientras tanto la UI muestra "Reconectando…". Una emisora que nunca conectó muestra el error de inmediato.
- Vigilancia: si no empieza a sonar en 30 s (primera conexión) o se queda cargando 20 s (ya había sonado), se trata como corte.
- `_loadId` descarta resultados de cargas viejas. El error `PlatformException('abort')` de just_audio (otra carga reemplazó a la anterior) se ignora.
- Si la pausa dura más de 30 s, o si la conexión se cayó, al reanudar se recarga la fuente para volver al vivo.
- `ProcessingState.completed` se trata como un corte de señal.
- Interrupciones (`AudioPlayer(handleInterruptions: false)` y `audio_session`): llamada → pausa y reanuda sola al colgar; otra app de música → pausa normal; audífonos desconectados → pausa.

**Segundo plano en Android (causa real del corte).** Al salir del primer plano (`stopForeground`), Android borra el permiso que la app ganó cuando el usuario tocó "play", y luego **no deja volver a entrar al primer plano desde segundo plano** (`ForegroundServiceStartNotAllowedException`, Android 12+; ver `ActiveServices.java`). Con `just_audio_background`, cualquier microcorte de red informaba `playing: false`, el servicio salía del primer plano y la reconexión ya no podía recuperarlo; además los errores no llegaban a la app, así que no se reconectaba. Regla actual: **mientras `_wantsPlaying` sea verdadero, a audio_service se le informa `playing: true`** (con `buffering` si está reconectando o en una llamada), y nunca `idle` salvo al detener. Solo una pausa del usuario o un error definitivo informan `playing: false`; reanudar desde la app, la notificación, la pantalla de bloqueo o los audífonos sí está permitido por Android.

Además: `PARTIAL_WAKE_LOCK` y `WifiLock` (`WIFI_MODE_FULL_HIGH_PERF`) mientras se quiere escuchar (objeto `PlaybackLocks` en `MainActivity.kt`); `MainActivity` hereda de `AudioServiceActivity`; el botón Atrás en la pantalla principal llama a `moveTaskToBack` si hay emisora (no cierra la app); la primera vez que se reproduce, si la app tiene optimización de batería, se abre `BackgroundHelpSheet`, que pide `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` y da pasos según la marca (`Build.MANUFACTURER`). El ícono de batería del AppBar abre la misma guía y muestra un punto rojo si falta el permiso. No hace falta pedir `POST_NOTIFICATIONS`: las notificaciones de sesiones multimedia están exentas. El manifest declara `usesCleartextTraffic=true`, porque muchas emisoras transmiten por http, además de los permisos de foreground service `mediaPlayback`, `WAKE_LOCK`, `POST_NOTIFICATIONS` y `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.

**UI.**
- Ancho menor a 600 px: lista. Desde 600 px: `GridView` con `maxCrossAxisExtent` de 380.
- Mini reproductor en `bottomNavigationBar`; al tocarlo abre `FullPlayerSheet`.
- Los logos que fallan muestran las iniciales sobre un color derivado del nombre.
- `EqualizerBars` respeta la opción de reducir animaciones.
- Textos de la UI en español y en tono simple.

## Estado actual

- v1 compilada e instalada. Funcionaba, pero había pocas emisoras en Cali y la radio se cortaba con la pantalla apagada.
- v2 ("Mejoras: Cali y segundo plano"): compilada con éxito en Actions, pero la radio **seguía cortándose** con la pantalla apagada y al salir de la app (los wake/wifi locks no atacaban la causa real).
- v3 (segundo plano reescrito con audio_service directo): ver "Segundo plano en Android". Falta confirmar en el dispositivo.

## Pendientes e ideas

- Llave de firma fija: crear un keystore, guardarlo en GitHub Secrets y firmar en el workflow, para poder actualizar sin desinstalar y sin perder favoritas.
- Permitir agregar emisoras propias por URL, guardadas localmente, para las que no estén en Radio Browser.
- Ícono y nombre definitivos de la app.
- Compilación para iOS: requiere un runner macOS y una cuenta de Apple Developer.
- Las emisoras grandes nacionales (Caracol, RCN, Olímpica) suelen no tener ciudad en Radio Browser. Se podría considerar una lista curada.
