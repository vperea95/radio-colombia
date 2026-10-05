# Radio Colombia

App en Flutter para escuchar emisoras colombianas en vivo, en celulares y tablets (Android e iOS).

## Qué hace

- Lista las emisoras de Colombia desde Radio Browser, un directorio comunitario gratuito y sin API key.
- Buscador por nombre, ciudad o género (sin importar tildes).
- Filtro por departamento y lista de favoritas guardada en el dispositivo.
- Sigue sonando con la pantalla apagada o fuera de la app, con controles en la notificación y en la pantalla de bloqueo. Si la señal se cae, se reconecta sola.
- Incluye una guía para quitar las restricciones de batería según la marca del celular.
- Muestra la canción actual cuando la emisora la transmite.
- En celular usa una lista; en tablet o en horizontal, una cuadrícula.
- Si pausas más de 30 segundos, al reanudar se reconecta para volver al vivo.
- Tema claro y oscuro según el sistema.

## Instalación

Requiere Flutter 3.27 o superior.

1. Crea el proyecto (cambia `com.victor` por tu dominio invertido):

   ```bash
   flutter create --org com.victor --platforms=android,ios radio_colombia
   cd radio_colombia
   ```

2. Copia encima del proyecto `pubspec.yaml`, `analysis_options.yaml` y la carpeta `lib/` de este paquete (reemplaza lo existente).

3. Android:
   - Reemplaza `android/app/src/main/AndroidManifest.xml` por `plataforma/android/AndroidManifest.xml`.
   - Abre `android/app/src/main/kotlin/.../MainActivity.kt` y cambia la clase para que herede de `AudioServiceActivity`, como en `plataforma/android/MainActivity.kt`. Conserva tu línea `package`.

4. iOS: pega el contenido de `plataforma/ios/Info.plist-fragmento.xml` dentro del `<dict>` de `ios/Runner/Info.plist`.

5. Instala y ejecuta:

   ```bash
   flutter pub get
   flutter run
   ```

   Si `pub get` se queja de versiones, deja que Flutter elija las más recientes compatibles:

   ```bash
   flutter pub add just_audio audio_service audio_session http shared_preferences
   ```

## Generar el instalable

```bash
flutter build apk --release        # APK para instalar directo
flutter build appbundle --release  # Para publicar en Google Play
```

## Estructura

```
lib/
  main.dart                    Arranque y servicio de audio en segundo plano
  theme.dart                   Colores y franja de la bandera
  models/station.dart          Modelo de emisora
  services/radio_api.dart      Cliente de Radio Browser (con servidores de respaldo)
  services/favorites_service.dart  Favoritas en SharedPreferences
  player/radio_player.dart     Reproducción (just_audio) y notificación (audio_service)
  player/background_support.dart  Funciones de Android para el segundo plano
  screens/home_screen.dart     Pantalla principal
  widgets/                     Tarjeta de emisora, mini reproductor, reproductor completo
```

## Notas

- Los datos de Radio Browser los mantiene la comunidad. La app oculta las emisoras marcadas como caídas, pero alguna puede no conectar o haber cambiado su enlace.
- Si quieres una lista curada (solo ciertas emisoras), basta con reemplazar `fetchColombianStations()` por una lista fija de `Station`.
