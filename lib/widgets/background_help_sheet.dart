import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../player/background_support.dart';

/// Abre la guía para que la radio siga sonando con la pantalla apagada.
Future<void> showBackgroundHelp(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const BackgroundHelpSheet(),
  );
}

/// La primera vez que se reproduce una emisora, si Android puede cortar la
/// radio para ahorrar batería, muestra la guía.
Future<void> maybeShowBackgroundHelp(BuildContext context) async {
  if (!BackgroundSupport.isAndroid) return;
  const key = 'background_help_shown';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(key) ?? false) return;
  if (await BackgroundSupport.isIgnoringBatteryOptimizations()) return;
  await prefs.setBool(key, true);
  if (!context.mounted) return;
  await showBackgroundHelp(context);
}

class BackgroundHelpSheet extends StatefulWidget {
  const BackgroundHelpSheet({super.key});

  @override
  State<BackgroundHelpSheet> createState() => _BackgroundHelpSheetState();
}

class _BackgroundHelpSheetState extends State<BackgroundHelpSheet> {
  late final AppLifecycleListener _lifecycle;
  bool? _batteryOk;
  String _brand = '';

  @override
  void initState() {
    super.initState();
    // Al volver de los ajustes del sistema se actualiza el estado.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final batteryOk = await BackgroundSupport.isIgnoringBatteryOptimizations();
    final brand = await BackgroundSupport.manufacturer();
    if (!mounted) return;
    setState(() {
      _batteryOk = batteryOk;
      _brand = brand;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tips = _tipsFor(_brand);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escuchar con la pantalla apagada',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Algunos celulares cierran las apps en segundo plano para ahorrar '
                'batería. Haz estos pasos una sola vez para que la radio no se '
                'corte al bloquear el celular o salir de la app.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              _Step(
                number: 1,
                done: _batteryOk == true,
                title: 'Batería sin restricciones',
                description: _batteryOk == true
                    ? 'Listo. Android ya no limita la app.'
                    : 'Toca «Permitir» y acepta en la ventana que aparece.',
                action: _batteryOk == false
                    ? FilledButton(
                        onPressed: BackgroundSupport.requestIgnoreBatteryOptimizations,
                        child: const Text('Permitir'),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _Step(
                number: 2,
                title: tips.title,
                description: tips.steps,
                action: OutlinedButton(
                  onPressed: BackgroundSupport.openAppSettings,
                  child: const Text('Abrir ajustes de la app'),
                ),
              ),
              const SizedBox(height: 12),
              const _Step(
                number: 3,
                title: 'No cierres la app desde Recientes',
                description: 'Para salir usa el botón de inicio o el de atrás: '
                    'la radio sigue sonando. Para apagarla, toca Detener.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Tips = ({String title, String steps});

/// Pasos según la marca, porque cada fabricante limita las apps a su manera.
_Tips _tipsFor(String brand) {
  bool isAny(List<String> names) => names.any(brand.contains);

  if (isAny(['xiaomi', 'redmi', 'poco'])) {
    return (
      title: 'En tu Xiaomi',
      steps: 'En los ajustes de la app, entra a «Ahorro de batería» y elige '
          '«Sin restricciones». Activa también «Inicio automático». En Recientes '
          'puedes dejar la app con candado.',
    );
  }
  if (brand.contains('samsung')) {
    return (
      title: 'En tu Samsung',
      steps: 'En los ajustes de la app, entra a «Batería» y elige «Sin '
          'restricciones». Si sigue cortándose: Ajustes > Batería > Límites de '
          'uso en segundo plano > «Apps que nunca entran en suspensión» y agrega '
          'Radio Colombia.',
    );
  }
  if (isAny(['huawei', 'honor'])) {
    return (
      title: 'En tu ${brand.contains('honor') ? 'Honor' : 'Huawei'}',
      steps: 'Ve a Ajustes > Batería > Inicio de aplicaciones, busca Radio '
          'Colombia, desactiva «Gestionar automáticamente» y deja activas las '
          'tres opciones.',
    );
  }
  if (isAny(['oppo', 'realme', 'oneplus'])) {
    return (
      title: 'En tu celular',
      steps: 'En los ajustes de la app, entra a «Uso de batería» y activa '
          '«Permitir actividad en segundo plano» y, si aparece, «Permitir '
          'inicio automático».',
    );
  }
  if (isAny(['vivo', 'iqoo'])) {
    return (
      title: 'En tu Vivo',
      steps: 'En los ajustes de la app, entra a «Batería» y permite el '
          '«Consumo alto en segundo plano».',
    );
  }
  if (isAny(['tecno', 'infinix', 'itel'])) {
    return (
      title: 'En tu celular',
      steps: 'En los ajustes de la app, entra a «Batería» y quita las '
          'restricciones. Activa también el «Inicio automático» (puede estar en '
          'la app Phone Master).',
    );
  }
  return (
    title: 'Ajustes del celular',
    steps: 'En los ajustes de la app, entra a «Batería» y elige «Sin '
        'restricciones» (o desactiva la optimización de batería).',
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.description,
    this.action,
    this.done = false,
  });

  final int number;
  final String title;
  final String description;
  final Widget? action;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: done ? scheme.primary : scheme.primaryContainer,
              child: done
                  ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
                  : Text(
                      '$number',
                      style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 12),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
