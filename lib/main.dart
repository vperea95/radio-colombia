import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'player/radio_player.dart';
import 'screens/home_screen.dart';
import 'services/favorites_service.dart';
import 'services/radio_api.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = RadioApi();
  final favorites = FavoritesService();
  await favorites.load();

  RadioPlayer createPlayer() =>
      RadioPlayer(onStationStarted: (station) => api.registerClick(station.id));

  // El servicio de audio permite seguir escuchando con la pantalla apagada o
  // fuera de la app, y muestra controles en la notificación y en la pantalla
  // de bloqueo.
  RadioPlayer player;
  try {
    player = await AudioService.init(
      builder: createPlayer,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'co.radiocolombia.audio',
        androidNotificationChannelName: 'Reproducción de radio',
        androidNotificationOngoing: true,
      ),
    );
  } catch (e) {
    // Sin el servicio la radio solo suena con la app abierta, pero la app funciona.
    debugPrint('No se pudo iniciar el servicio de audio: $e');
    player = createPlayer();
  }

  runApp(RadioColombiaApp(api: api, favorites: favorites, player: player));
}

class RadioColombiaApp extends StatelessWidget {
  const RadioColombiaApp({
    super.key,
    required this.api,
    required this.favorites,
    required this.player,
  });

  final RadioApi api;
  final FavoritesService favorites;
  final RadioPlayer player;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Colombia',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(api: api, favorites: favorites, player: player),
    );
  }
}
