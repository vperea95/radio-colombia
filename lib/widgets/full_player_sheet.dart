import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../player/radio_player.dart';
import '../services/favorites_service.dart';
import '../theme.dart';
import 'equalizer_bars.dart';
import 'play_pause_button.dart';
import 'station_logo.dart';

/// Reproductor completo, en una hoja inferior.
class FullPlayerSheet extends StatelessWidget {
  const FullPlayerSheet({super.key, required this.player, required this.favorites});

  final RadioPlayer player;
  final FavoritesService favorites;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, favorites]),
      builder: (context, _) {
        final station = player.current;
        if (station == null) {
          return const SizedBox(height: 120, child: Center(child: Text('No hay nada sonando')));
        }

        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        final isFavorite = favorites.isFavorite(station.id);
        final isError = player.status == PlayerStatus.error;
        final logoSize = math.min(MediaQuery.sizeOf(context).width * 0.55, 220.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StationLogo(station: station, size: logoSize, radius: 28),
                  const SizedBox(height: 24),
                  _LiveBadge(active: player.isPlaying),
                  const SizedBox(height: 12),
                  Text(
                    station.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    station.subtitle,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      player.statusLabel,
                      key: ValueKey(player.statusLabel),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        color: isError ? scheme.error : scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: isFavorite ? 'Quitar de favoritas' : 'Agregar a favoritas',
                        iconSize: 28,
                        onPressed: () => favorites.toggle(station.id),
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? AppColors.red : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      PlayPauseButton(player: player, size: 76),
                      const SizedBox(width: 20),
                      IconButton(
                        tooltip: 'Detener',
                        iconSize: 28,
                        onPressed: () {
                          Navigator.of(context).pop();
                          player.stop();
                        },
                        icon: const Icon(Icons.stop_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_down_rounded),
                      Expanded(
                        child: Slider(
                          value: player.volume.clamp(0.0, 1.0),
                          onChanged: player.setVolume,
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded),
                    ],
                  ),
                  if (station.technicalInfo.isNotEmpty)
                    Text(
                      station.technicalInfo,
                      style: text.labelSmall?.copyWith(color: scheme.outline),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = active ? Colors.white : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.red : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            const EqualizerBars(color: Colors.white, size: 12)
          else
            Icon(Icons.radio_rounded, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            'En vivo',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
