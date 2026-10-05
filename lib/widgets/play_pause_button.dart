import 'package:flutter/material.dart';

import '../player/radio_player.dart';

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, required this.player, this.size = 48});

  final RadioPlayer player;
  final double size;

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.play_arrow_rounded;
    String tooltip = 'Reproducir';
    VoidCallback? onPressed = player.current == null ? null : player.resume;

    switch (player.status) {
      case PlayerStatus.playing || PlayerStatus.loading:
        icon = Icons.pause_rounded;
        tooltip = 'Pausar';
        onPressed = player.pause;
      case PlayerStatus.error:
        icon = Icons.refresh_rounded;
        tooltip = 'Reintentar';
        onPressed = player.retry;
      case PlayerStatus.paused || PlayerStatus.idle:
        break;
    }

    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size * 0.55,
      style: IconButton.styleFrom(minimumSize: Size.square(size)),
      icon: Icon(icon),
    );
  }
}
