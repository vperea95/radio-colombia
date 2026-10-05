import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'player/radio_player.dart';
import 'screens/home_screen.dart';
import 'services/favorites_service.dart';
import 'services/radio_api.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Permite seguir escuchando con la pantalla apagada y muestra
  // controles en la notificación y en la pantalla de bloqueo.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'co.radiocolombia.audio',
    androidNotificationChannelName: 'Reproducción de radio',
    androidNotificationOngoing: true,
  );

  final api = RadioApi();
  final favorites = FavoritesService();
  await favorites.load();
  final player = RadioPlayer(
    onStationStarted: (station) => api.registerClick(station.id),
  );

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
