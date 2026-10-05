import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tres barras animadas que indican que la emisora está sonando.
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({super.key, this.color, this.size = 20});

  final Color? color;
  final double size;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: widget.size / 5,
                  height: widget.size * _barHeight(i, reduceMotion),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _barHeight(int index, bool reduceMotion) {
    if (reduceMotion) return const [0.6, 1.0, 0.75][index];
    final wave = math.sin(_controller.value * 2 * math.pi + index * 2.1);
    return 0.3 + 0.7 * (wave + 1) / 2;
  }
}
