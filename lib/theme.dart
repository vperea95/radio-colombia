import 'package:flutter/material.dart';

/// Colores de la bandera de Colombia.
class AppColors {
  static const yellow = Color(0xFFFCD116);
  static const blue = Color(0xFF003893);
  static const red = Color(0xFFCE1126);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: brightness,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}

/// Franja amarilla, azul y roja que identifica la app.
class FlagStripe extends StatelessWidget {
  const FlagStripe({super.key, this.height = 4});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: ColoredBox(color: AppColors.yellow)),
          Expanded(child: ColoredBox(color: AppColors.blue)),
          Expanded(child: ColoredBox(color: AppColors.red)),
        ],
      ),
    );
  }
}
