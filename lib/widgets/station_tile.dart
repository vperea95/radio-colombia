import 'package:flutter/material.dart';

import '../models/station.dart';
import '../player/radio_player.dart';
import '../theme.dart';
import 'equalizer_bars.dart';
import 'station_logo.dart';

class StationTile extends StatelessWidget {
  const StationTile({
    super.key,
    required this.station,
    required this.isCurrent,
    required this.status,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  final Station station;
  final bool isCurrent;
  final PlayerStatus status;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final foreground = isCurrent ? scheme.onPrimaryContainer : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isCurrent ? scheme.primaryContainer : scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              StationLogo(station: station, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      station.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: foreground ?? scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent) _StatusIndicator(status: status),
              IconButton(
                tooltip: isFavorite ? 'Quitar de favoritas' : 'Agregar a favoritas',
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? AppColors.red : foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final PlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 32,
      child: Center(
        child: switch (status) {
          PlayerStatus.loading => const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          PlayerStatus.playing => EqualizerBars(color: scheme.primary),
          PlayerStatus.paused => Icon(Icons.pause_rounded, color: scheme.onPrimaryContainer),
          PlayerStatus.error => Icon(Icons.error_outline, color: scheme.error),
          PlayerStatus.idle => const SizedBox.shrink(),
        },
      ),
    );
  }
}
