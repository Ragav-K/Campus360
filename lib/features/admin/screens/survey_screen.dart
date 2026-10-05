import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/campus_location.dart';
import '../../../models/campus_path.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../../campus_map/providers/location_providers.dart';
import '../../campus_map/providers/navigation_providers.dart';
import '../../campus_map/widgets/campus_map_view.dart';

/// Admin tool for recording real campus coordinates and the walking network.
///
/// The whole map depends on this: until someone walks the campus with it,
/// locations have no position and nothing can be navigated to.
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unmapped = ref.watch(unmappedCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus survey'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: unmapped == 0 ? 'Places' : 'Places ($unmapped left)'),
            const Tab(text: 'Paths'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_PlacesTab(), _PathsTab()],
      ),
    );
  }
}

/// Stand at a place, tap the button, its coordinates are recorded.
class _PlacesTab extends ConsumerStatefulWidget {
  const _PlacesTab();

  @override
  ConsumerState<_PlacesTab> createState() => _PlacesTabState();
}

class _PlacesTabState extends ConsumerState<_PlacesTab> {
  String? _busyId;

  Future<void> _record(CampusLocation location) async {
    setState(() => _busyId = location.id);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final position = await ref.read(locationServiceProvider).currentPosition();

      // A vague fix is worse than none — it would put the pin in the wrong
      // building and look authoritative doing it.
      if (position.accuracy > AppConfig.surveyMaxAccuracyMetres) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'GPS is only accurate to ${position.accuracy.round()} m right now. '
              'Move into the open and try again.',
            ),
          ),
        );
        return;
      }

      await ref.read(pathRepositoryProvider).setLocationCoordinates(
            locationId: location.id,
            lat: position.latitude,
            lng: position.longitude,
            accuracyMetres: position.accuracy,
          );

      messenger.showSnackBar(
        SnackBar(
          content: Text('${location.name} recorded (±${position.accuracy.round()} m)'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(allLocationsProvider);

    return AsyncValueView<List<CampusLocation>>(
      value: locations,
      onRetry: () => ref.invalidate(allLocationsProvider),
      empty: (_) => const EmptyState(
        icon: Icons.place_outlined,
        title: 'No campus locations',
        message: 'Add locations first, then record where they are.',
      ),
      data: (items) => ListView.separated(
        padding: const EdgeInsets.all(Gap.lg),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => Gap.h12,
        itemBuilder: (context, i) {
          if (i == 0) return const _SurveyHelp();
          final location = items[i - 1];
          return _PlaceRow(
            location: location,
            busy: _busyId == location.id,
            onRecord: () => _record(location),
          );
        },
      ),
    );
  }
}

class _SurveyHelp extends StatelessWidget {
  const _SurveyHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: Radii.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 19, color: theme.colorScheme.primary),
          Gap.w12,
          Expanded(
            child: Text(
              'Walk to each place and tap "Record here". Stand outside the '
              'entrance in the open — GPS is poor next to walls and indoors. '
              'Fixes worse than ${AppConfig.surveyMaxAccuracyMetres.round()} m are rejected.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.location, required this.busy, required this.onRecord});

  final CampusLocation location;
  final bool busy;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapped = location.hasCoordinates;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.md,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            mapped ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: mapped ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  mapped
                      ? '${location.lat!.toStringAsFixed(5)}, ${location.lng!.toStringAsFixed(5)}'
                      : 'Not recorded',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Gap.w8,
          CButton(
            label: mapped ? 'Redo' : 'Record here',
            loading: busy,
            variant: mapped ? CButtonVariant.text : CButtonVariant.outlined,
            expand: false,
            onPressed: onRecord,
          ),
        ],
      ),
    );
  }
}

/// The walking network: drop points as you walk, and fix the ones that landed
/// in the wrong place.
///
/// Shown on the map rather than as a list of coordinates. A stray point is
/// invisible as "11.07661, 77.14203" and obvious as a dot sitting inside a
/// building, and joining two paths at a junction is a spatial judgement that a
/// list cannot support.
class _PathsTab extends ConsumerStatefulWidget {
  const _PathsTab();

  @override
  ConsumerState<_PathsTab> createState() => _PathsTabState();
}

/// What the next tap on a point means.
enum _TapMode { select, join, disconnect }

class _PathsTabState extends ConsumerState<_PathsTab> {
  final _mapController = MapController();

  bool _busy = false;

  /// Node the next drop connects to. Cleared by "Start a new path" so a
  /// separate walkway doesn't get joined to the previous one through a wall.
  String? _lastNodeId;

  String? _selectedId;
  _TapMode _mode = _TapMode.select;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Every edit follows the same shape: re-read the stored graph, transform it,
  /// write it back. Re-reading matters — the graph is one document, so editing
  /// a copy that went stale while the screen was open would silently discard
  /// whatever was surveyed in the meantime.
  Future<void> _edit(
    CampusGraph Function(CampusGraph graph) transform, {
    required String success,
  }) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(pathRepositoryProvider);
      await repo.saveGraph(transform(await repo.fetchGraph()));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dropNode({required bool connect}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final position = await ref.read(locationServiceProvider).currentPosition();
      if (position.accuracy > AppConfig.surveyMaxAccuracyMetres) {
        messenger.showSnackBar(
          SnackBar(content: Text('GPS only ±${position.accuracy.round()} m — move into the open.')),
        );
        return;
      }

      final repo = ref.read(pathRepositoryProvider);
      final graph = await repo.fetchGraph();

      final id = 'n${DateTime.now().millisecondsSinceEpoch}';
      final node = PathNode(id: id, lat: position.latitude, lng: position.longitude);
      final joinTo = connect ? _lastNodeId : null;

      await repo.saveGraph(graph.withNode(node, connectTo: joinTo));

      if (!mounted) return;
      setState(() {
        _lastNodeId = id;
        _selectedId = id;
        _mode = _TapMode.select;
      });
      _mapController.move(LatLng(node.lat, node.lng), _mapController.camera.zoom);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            joinTo != null
                ? 'Point added and joined to the last one'
                : 'Point added — start of a new path',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onNodeTap(PathNode node, CampusGraph graph) {
    final anchor = _selectedId;

    switch (_mode) {
      case _TapMode.select:
        setState(() => _selectedId = node.id == _selectedId ? null : node.id);

      case _TapMode.join:
        if (anchor == null || anchor == node.id) {
          setState(() => _mode = _TapMode.select);
          return;
        }
        setState(() => _mode = _TapMode.select);
        if (graph.hasEdge(anchor, node.id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Those two are already connected')),
          );
          return;
        }
        _edit(
          (g) => g.withEdge(anchor, node.id),
          success: 'Points joined — they can now be walked between',
        );

      case _TapMode.disconnect:
        if (anchor == null || anchor == node.id) {
          setState(() => _mode = _TapMode.select);
          return;
        }
        setState(() => _mode = _TapMode.select);
        _edit(
          (g) => g.withoutEdge(anchor, node.id),
          success: 'Connection removed',
        );
    }
  }

  Future<void> _deleteSelected(CampusGraph graph) async {
    final id = _selectedId;
    if (id == null) return;

    final connections = graph.neighboursOf(id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this point?'),
        content: Text(
          connections == 0
              ? 'It is not connected to anything, so nothing else changes.'
              : 'Its $connections connection${connections == 1 ? '' : 's'} will go too. '
                  'If it sits mid-path, the path will be split in two and routing '
                  'will no longer cross it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _selectedId = null;
      _mode = _TapMode.select;
      // Dropping the next point must not try to join to something deleted.
      if (_lastNodeId == id) _lastNodeId = null;
    });
    await _edit((g) => g.withoutNode(id), success: 'Point deleted');
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(campusGraphProvider);

    return AsyncValueView<CampusGraph>(
      value: graph,
      onRetry: () => ref.invalidate(campusGraphProvider),
      data: _buildBody,
    );
  }

  Widget _buildBody(CampusGraph graph) {
    final theme = Theme.of(context);
    final selected = _selectedId == null ? null : graph.nodeById(_selectedId!);
    final position = ref.watch(positionStreamProvider).valueOrNull;
    final tileCache = ref.watch(tileCacheProvider).valueOrNull;

    // A selection that was deleted (here or by another surveyor) must not leave
    // the action panel acting on a point that no longer exists.
    if (_selectedId != null && selected == null && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedId = null);
      });
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (tileCache == null)
                const Center(child: CircularProgressIndicator())
              else
                CampusMapView(
                  tileCache: tileCache,
                  mapController: _mapController,
                  locations: ref.watch(mappedLocationsProvider),
                  graph: graph,
                  selectedNodeId: selected?.id,
                  highlightedNodeIds:
                      selected == null ? const {} : graph.neighboursOf(selected.id),
                  onNodeTap: _busy ? null : (node) => _onNodeTap(node, graph),
                  position: position,
                ),

              if (graph.isEmpty)
                const Positioned(
                  left: Gap.lg,
                  right: Gap.lg,
                  top: Gap.lg,
                  child: _MapNotice(
                    icon: Icons.route_outlined,
                    text: 'No paths yet. Walk the footpaths and drop a point every '
                        'few metres, especially at junctions and doorways — routing '
                        'can only follow points that exist.',
                  ),
                ),

              if (_mode != _TapMode.select)
                Positioned(
                  left: Gap.lg,
                  right: Gap.lg,
                  top: Gap.lg,
                  child: _MapNotice(
                    icon: _mode == _TapMode.join ? Icons.link_rounded : Icons.link_off_rounded,
                    text: _mode == _TapMode.join
                        ? 'Tap the point to join this one to.'
                        : 'Tap a connected point to break the link.',
                    onCancel: () => setState(() => _mode = _TapMode.select),
                  ),
                ),
            ],
          ),
        ),

        Material(
          elevation: 8,
          color: theme.colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route_rounded, size: 19, color: theme.colorScheme.primary),
                      Gap.w8,
                      Expanded(
                        child: Text(
                          '${graph.nodes.length} points · ${graph.edges.length} connections',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_lastNodeId != null)
                        Text('joining as you walk', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  Gap.h12,
                  if (selected != null) ...[
                    _SelectedNodePanel(
                      node: selected,
                      connections: graph.neighboursOf(selected.id).length,
                      isDropAnchor: selected.id == _lastNodeId,
                      busy: _busy,
                      onContinueFromHere: () {
                        setState(() => _lastNodeId = selected.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('The next point will join to this one')),
                        );
                      },
                      onJoin: () => setState(() => _mode = _TapMode.join),
                      onDisconnect: () => setState(() => _mode = _TapMode.disconnect),
                      onDelete: () => _deleteSelected(graph),
                    ),
                    Gap.h12,
                  ],
                  CButton(
                    label: 'Drop point here',
                    icon: Icons.add_location_alt_outlined,
                    loading: _busy,
                    onPressed: () => _dropNode(connect: true),
                  ),
                  Gap.h8,
                  CButton(
                    label: 'Start a new path',
                    variant: CButtonVariant.outlined,
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() => _lastNodeId = null);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Next point starts a separate path'),
                              ),
                            );
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Actions for the point currently tapped on the map.
class _SelectedNodePanel extends StatelessWidget {
  const _SelectedNodePanel({
    required this.node,
    required this.connections,
    required this.isDropAnchor,
    required this.busy,
    required this.onContinueFromHere,
    required this.onJoin,
    required this.onDisconnect,
    required this.onDelete,
  });

  final PathNode node;
  final int connections;
  final bool isDropAnchor;
  final bool busy;
  final VoidCallback onContinueFromHere;
  final VoidCallback onJoin;
  final VoidCallback onDisconnect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: Radii.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.name.isEmpty
                ? '${node.lat.toStringAsFixed(5)}, ${node.lng.toStringAsFixed(5)}'
                : node.name,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            connections == 0
                ? 'Not connected to anything — nothing can route through it'
                : '$connections connection${connections == 1 ? '' : 's'}, shown in amber',
            style: theme.textTheme.bodySmall?.copyWith(
              color: connections == 0 ? theme.colorScheme.error : null,
            ),
          ),
          Gap.h8,
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              if (!isDropAnchor)
                _NodeAction(
                  icon: Icons.my_location_rounded,
                  label: 'Continue from here',
                  onPressed: busy ? null : onContinueFromHere,
                ),
              _NodeAction(icon: Icons.link_rounded, label: 'Join to…', onPressed: busy ? null : onJoin),
              if (connections > 0)
                _NodeAction(
                  icon: Icons.link_off_rounded,
                  label: 'Disconnect…',
                  onPressed: busy ? null : onDisconnect,
                ),
              _NodeAction(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                danger: true,
                onPressed: busy ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodeAction extends StatelessWidget {
  const _NodeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? scheme.error : null,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// A short instruction floated over the map.
class _MapNotice extends StatelessWidget {
  const _MapNotice({required this.icon, required this.text, this.onCancel});

  final IconData icon;
  final String text;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      borderRadius: Radii.md,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: theme.colorScheme.primary),
            Gap.w12,
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
            if (onCancel != null) ...[
              Gap.w8,
              GestureDetector(
                onTap: onCancel,
                child: Icon(Icons.close_rounded, size: 19, color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
