import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/station.dart';
import '../player/background_support.dart';
import '../player/radio_player.dart';
import '../services/favorites_service.dart';
import '../services/radio_api.dart';
import '../theme.dart';
import '../utils/text_utils.dart';
import '../widgets/background_help_sheet.dart';
import '../widgets/full_player_sheet.dart';
import '../widgets/mini_player.dart';
import '../widgets/station_tile.dart';

typedef _Department = ({String key, String label, int count});

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.favorites,
    required this.player,
  });

  final RadioApi api;
  final FavoritesService favorites;
  final RadioPlayer player;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  late final AppLifecycleListener _lifecycle;

  List<Station> _stations = const [];
  List<_Department> _departments = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _departmentKey;
  bool _onlyFavorites = false;

  /// Android puede cortar la radio para ahorrar batería.
  bool _backgroundRestricted = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkBackground);
    _checkBackground();
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkBackground() async {
    final restricted = !await BackgroundSupport.isIgnoringBatteryOptimizations();
    if (mounted && restricted != _backgroundRestricted) {
      setState(() => _backgroundRestricted = restricted);
    }
  }

  Future<void> _openBackgroundHelp() async {
    await showBackgroundHelp(context);
    await _checkBackground();
  }

  void _onStationTap(Station station) {
    widget.player.togglePlay(station);
    maybeShowBackgroundHelp(context).then((_) => _checkBackground());
  }

  /// Atrás no cierra la app si hay una emisora: la manda al fondo y sigue sonando.
  Future<void> _onBack() async {
    if (widget.player.current != null && await BackgroundSupport.moveTaskToBack()) {
      return;
    }
    await SystemNavigator.pop();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _stations.isEmpty;
      _error = null;
    });
    try {
      final stations = await widget.api.fetchColombianStations();
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _departments = _buildDepartments(stations);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is RadioApiException ? e.message : 'Ocurrió un error inesperado.';
      if (_stations.isNotEmpty) {
        // Ya hay una lista: se mantiene y solo se avisa.
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      } else {
        setState(() {
          _loading = false;
          _error = message;
        });
      }
    }
  }

  static List<_Department> _buildDepartments(List<Station> stations) {
    final counts = <String, int>{};
    for (final station in stations) {
      if (station.department.isEmpty) continue;
      counts[station.department] = (counts[station.department] ?? 0) + 1;
    }
    final list = <_Department>[
      for (final entry in counts.entries)
        (key: entry.key, label: entry.key, count: entry.value),
    ];
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  List<Station> get _visibleStations {
    final query = normalize(_query);
    return _stations.where((station) {
      if (_onlyFavorites && !widget.favorites.isFavorite(station.id)) return false;
      if (_departmentKey != null && station.department != _departmentKey) return false;
      if (query.isEmpty) return true;
      return normalize(station.name).contains(query) ||
          normalize(station.state).contains(query) ||
          normalize(station.department).contains(query) ||
          station.tags.any((tag) => normalize(tag).contains(query));
    }).toList();
  }

  void _openFullPlayer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FullPlayerSheet(player: widget.player, favorites: widget.favorites),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenable = Listenable.merge([widget.player, widget.favorites]);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Radio Colombia'),
          actions: [
            if (BackgroundSupport.isAndroid)
              IconButton(
                tooltip: 'Escuchar con la pantalla apagada',
                onPressed: _openBackgroundHelp,
                icon: Badge(
                  isLabelVisible: _backgroundRestricted,
                  smallSize: 8,
                  child: const Icon(Icons.battery_saver_outlined),
                ),
              ),
            IconButton(
              tooltip: 'Actualizar lista',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(4),
            child: FlagStripe(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Buscar emisora, ciudad o género',
                leading: const Icon(Icons.search_rounded),
                elevation: const WidgetStatePropertyAll(0),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Borrar búsqueda',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            _buildFilters(),
            Expanded(
              child: ListenableBuilder(
                listenable: listenable,
                builder: (context, _) => _buildContent(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: widget.player,
          builder: (context, _) => MiniPlayer(player: widget.player, onOpen: _openFullPlayer),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    Widget spaced(Widget chip) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: chip);

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          spaced(FilterChip(
            avatar: Icon(
              _onlyFavorites ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: _onlyFavorites ? AppColors.red : null,
            ),
            label: const Text('Favoritas'),
            selected: _onlyFavorites,
            showCheckmark: false,
            onSelected: (value) => setState(() => _onlyFavorites = value),
          )),
          spaced(ChoiceChip(
            label: const Text('Todo el país'),
            selected: _departmentKey == null,
            showCheckmark: false,
            onSelected: (_) => setState(() => _departmentKey = null),
          )),
          for (final department in _departments)
            spaced(ChoiceChip(
              label: Text('${department.label} (${department.count})'),
              selected: _departmentKey == department.key,
              showCheckmark: false,
              onSelected: (selected) =>
                  setState(() => _departmentKey = selected ? department.key : null),
            )),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const _CenteredMessage(loading: true, title: 'Cargando emisoras…');
    }
    if (_error != null) {
      return _CenteredMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Sin conexión con el directorio',
        message: _error,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }

    final stations = _visibleStations;
    if (stations.isEmpty) {
      final noFavoritesYet = _onlyFavorites && _query.isEmpty && _departmentKey == null;
      return _CenteredMessage(
        icon: noFavoritesYet ? Icons.favorite_border : Icons.search_off_rounded,
        title: noFavoritesYet ? 'Aún no tienes favoritas' : 'Sin resultados',
        message: noFavoritesYet
            ? 'Toca el corazón de una emisora para guardarla aquí.'
            : 'Prueba con otro nombre, ciudad o género.',
      );
    }

    final player = widget.player;
    Widget tile(Station station) => StationTile(
          station: station,
          isCurrent: player.isCurrent(station),
          status: player.isCurrent(station) ? player.status : PlayerStatus.idle,
          isFavorite: widget.favorites.isFavorite(station.id),
          onTap: () => _onStationTap(station),
          onFavorite: () => widget.favorites.toggle(station.id),
        );

    const padding = EdgeInsets.fromLTRB(12, 4, 12, 24);

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Celular: lista. Tablet o celular horizontal: cuadrícula.
          if (constraints.maxWidth < 600) {
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount: stations.length,
              itemBuilder: (_, i) => tile(stations[i]),
            );
          }
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisExtent: 92,
              crossAxisSpacing: 8,
            ),
            itemCount: stations.length,
            itemBuilder: (_, i) => tile(stations[i]),
          );
        },
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.title,
    this.message,
    this.icon,
    this.action,
    this.loading = false,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator()
            else if (icon != null)
              Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
