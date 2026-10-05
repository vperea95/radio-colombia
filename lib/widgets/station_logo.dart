import 'package:flutter/material.dart';

import '../models/station.dart';
import '../utils/text_utils.dart';

/// Logo de la emisora; si no tiene o no carga, muestra sus iniciales.
class StationLogo extends StatelessWidget {
  const StationLogo({super.key, required this.station, this.size = 56, this.radius = 12});

  final Station station;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = _InitialsAvatar(name: station.name, size: size);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: station.favicon.isEmpty
            ? fallback
            : ColoredBox(
                color: Colors.white,
                child: Image.network(
                  station.favicon,
                  fit: BoxFit.contain,
                  cacheWidth: (size * pixelRatio).round(),
                  errorBuilder: (_, __, ___) => fallback,
                  loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
                ),
              ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = (name.hashCode % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.45, 0.42).toColor();
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}
