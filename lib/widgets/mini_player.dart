import 'package:flutter/material.dart';

import '../player/radio_player.dart';
import 'play_pause_button.dart';
import 'station_logo.dart';

/// Barra inferior con la emisora actual. Al tocarla abre el reproductor completo.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.player, required this.onOpen});

  final RadioPlayer player;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final station = player.current;
    if (station == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isError = player.status == PlayerStatus.error;

    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 2,
                child: player.isLoading ? const LinearProgressIndicator(minHeight: 2) : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    StationLogo(station: station, size: 48, radius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            player.statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: isError ? scheme.error : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PlayPauseButton(player: player, size: 44),
                    IconButton(
                      tooltip: 'Detener',
                      onPressed: player.stop,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
