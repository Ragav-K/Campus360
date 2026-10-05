import 'dart:io';

import 'package:campus360/features/campus_map/providers/location_providers.dart';
import 'package:campus360/features/campus_map/providers/navigation_providers.dart';
import 'package:campus360/core/services/tile_cache.dart';
import 'package:campus360/features/admin/screens/survey_screen.dart';
import 'package:campus360/models/campus_location.dart';
import 'package:campus360/models/campus_path.dart';
import 'package:campus360/repositories/path_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Widget tests for the survey screen's Paths tab.
///
/// The tab edits the walking network the whole map depends on, and every edit
/// is destructive in a way that is invisible until someone tries to navigate —
/// so what these check is mostly that the screen *says* what an action will do
/// before it does it.
///
/// Rendering needs two overrides: the tile cache, pointed at a temp directory
/// so it doesn't go through `path_provider`'s plugin channel (absent in a test,
/// which would leave the tab on its spinner forever), and the repository, so
/// saves never reach Firestore. The tiles themselves fail to load here and are
/// meant to — a blank tile is the honest offline state.

/// Records what would have been written, so a test can assert on the graph an
/// action produced rather than on the words in a snackbar.
class _FakePathRepository implements PathRepository {
  _FakePathRepository(this._graph);

  CampusGraph _graph;
  CampusGraph? saved;

  @override
  Future<CampusGraph> fetchGraph() async => _graph;

  @override
  Future<void> saveGraph(CampusGraph graph) async {
    saved = graph;
    _graph = graph;
  }

  @override
  Stream<CampusGraph> watchGraph() => Stream.value(_graph);

  @override
  Future<void> setLocationCoordinates({
    required String locationId,
    required double lat,
    required double lng,
    required double accuracyMetres,
  }) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _lat = 11.0766;
const _lng = 77.1421;

// ~55 m apart: far enough that each dot lands on its own part of the test
// viewport, so a tap picks the one it means.
PathNode _node(String id, int step) =>
    PathNode(id: id, lat: _lat + step * 0.0005, lng: _lng + step * 0.0005);

/// a — b — c, a straight run of three.
/// Finds one point's dot on the map.
Finder _dot(String nodeId) => find.byKey(ValueKey('path-node-$nodeId'));

/// Selects a point by invoking the dot's own tap callback.
///
/// Not `tester.tap`: flutter_map positions its layers with a transform that
/// render geometry and hit testing disagree about in a test, so a tap aimed at
/// a dot's visible centre lands nowhere. That makes the *gesture* untestable
/// here — it is only proven on a device — but everything the callback then does
/// is exactly what these tests are for.
Future<void> _tapDot(WidgetTester tester, String nodeId) async {
  final detector = tester.widget<GestureDetector>(
    find.descendant(of: _dot(nodeId), matching: find.byType(GestureDetector)),
  );
  detector.onTap!();
  await _settle(tester);
}

CampusGraph _run() => CampusGraph(
      nodes: [_node('a', 0), _node('b', 1), _node('c', 2)],
      edges: const [(a: 'a', b: 'b'), (a: 'b', b: 'c')],
    );

Future<void> _pumpPathsTab(
  WidgetTester tester, {
  required CampusGraph graph,
  _FakePathRepository? repository,
}) async {
  final repo = repository ?? _FakePathRepository(graph);
  final cache = TileCache.forDirectory(Directory.systemTemp.createTempSync('campus360_tiles'));

  // A phone-shaped surface, so the map gets real estate and the action panel
  // below it isn't squeezed over the dots.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pathRepositoryProvider.overrideWithValue(repo),
        tileCacheProvider.overrideWith((_) async => cache),
        campusGraphProvider.overrideWith((_) => Stream.value(graph)),
        mappedLocationsProvider.overrideWithValue(const <CampusLocation>[]),
        positionStreamProvider.overrideWith((_) => const Stream<Position>.empty()),
        allLocationsProvider.overrideWith((_) => Stream.value(const <CampusLocation>[])),
      ],
      child: const MaterialApp(home: SurveyScreen()),
    ),
  );

  // Land on the Paths tab.
  await tester.tap(find.text('Paths'));
  await _settle(tester);
}

/// Pumps a few frames instead of `pumpAndSettle`.
///
/// The map never goes quiet in a test: the tile provider keeps retrying fetches
/// that cannot succeed here, so `pumpAndSettle` waits for an idle frame that
/// never comes and times out. Everything these tests touch is laid out within a
/// couple of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Paths tab', () {
    testWidgets('an empty network explains what to do rather than showing a blank map',
        (tester) async {
      await _pumpPathsTab(tester, graph: CampusGraph(nodes: const [], edges: const []));

      expect(find.textContaining('No paths yet'), findsOneWidget);
      expect(find.text('0 points · 0 connections'), findsOneWidget);
    });

    testWidgets('counts the network it is editing', (tester) async {
      await _pumpPathsTab(tester, graph: _run());

      expect(find.text('3 points · 2 connections'), findsOneWidget);
      expect(find.textContaining('No paths yet'), findsNothing);
    });

    testWidgets('offers dropping a point and starting a separate path', (tester) async {
      await _pumpPathsTab(tester, graph: _run());

      expect(find.text('Drop point here'), findsOneWidget);
      expect(find.text('Start a new path'), findsOneWidget);
    });

    testWidgets('draws a tappable dot for every point on the network', (tester) async {
      await _pumpPathsTab(tester, graph: _run());

      expect(_dot('a'), findsOneWidget);
      expect(_dot('b'), findsOneWidget);
      expect(_dot('c'), findsOneWidget);
    });

    testWidgets('selecting a point offers the editing actions', (tester) async {
      await _pumpPathsTab(tester, graph: _run());

      await _tapDot(tester, 'a');

      expect(find.text('Join to…'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Continue from here'), findsOneWidget);
    });

    testWidgets('a selected point says how many connections it has', (tester) async {
      await _pumpPathsTab(tester, graph: _run());

      // 'b' is the middle of the run, so it has two.
      await _tapDot(tester, 'b');

      // Matched with the panel's own wording: "2 connections" alone also
      // appears in the network summary above the buttons.
      expect(find.textContaining('2 connections, shown in amber'), findsOneWidget);
    });

    testWidgets('an unconnected point is called out as unroutable', (tester) async {
      await _pumpPathsTab(
        tester,
        graph: CampusGraph(nodes: [_node('a', 0)], edges: const []),
      );

      await _tapDot(tester, 'a');

      // A point nothing connects to is invisible as a defect but silently
      // unroutable, so the panel has to say so.
      expect(find.textContaining('Not connected to anything'), findsOneWidget);
      expect(find.text('Disconnect…'), findsNothing);
    });

    testWidgets('deleting warns that a mid-path point splits the path', (tester) async {
      await _pumpPathsTab(tester, graph: _run());

      await _tapDot(tester, 'b');
      await tester.tap(find.text('Delete'));
      await _settle(tester);

      expect(find.text('Delete this point?'), findsOneWidget);
      expect(find.textContaining('2 connections will go too'), findsOneWidget);
      expect(
        find.textContaining('path will be split in two'),
        findsOneWidget,
        reason: 'the consequence is invisible on the map until someone tries to navigate',
      );
    });

    testWidgets('cancelling the delete writes nothing', (tester) async {
      final repo = _FakePathRepository(_run());
      await _pumpPathsTab(tester, graph: _run(), repository: repo);

      await _tapDot(tester, 'b');
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await tester.tap(find.text('Keep'));
      await _settle(tester);

      expect(repo.saved, isNull);
    });

    testWidgets('confirming the delete removes the point and its edges', (tester) async {
      final repo = _FakePathRepository(_run());
      await _pumpPathsTab(tester, graph: _run(), repository: repo);

      await _tapDot(tester, 'b');
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      // The dialog's Delete, not the panel button behind it.
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')),
      );
      await _settle(tester);

      final saved = repo.saved;
      expect(saved, isNotNull);
      expect(saved!.nodes.map((n) => n.id), ['a', 'c']);
      expect(saved.edges, isEmpty, reason: 'both edges touched the deleted point');
    });

    testWidgets('joining asks which point to join to before doing anything', (tester) async {
      final repo = _FakePathRepository(_run());
      await _pumpPathsTab(tester, graph: _run(), repository: repo);

      await _tapDot(tester, 'a');
      await tester.tap(find.text('Join to…'));
      await _settle(tester);

      expect(find.textContaining('Tap the point to join this one to'), findsOneWidget);
      expect(repo.saved, isNull, reason: 'nothing is written until the second point is chosen');
    });

    testWidgets('joining two points writes the new edge', (tester) async {
      final repo = _FakePathRepository(_run());
      await _pumpPathsTab(tester, graph: _run(), repository: repo);

      await _tapDot(tester, 'a');
      await tester.tap(find.text('Join to…'));
      await _settle(tester);
      await _tapDot(tester, 'c'); // the second point of the join

      final saved = repo.saved;
      expect(saved, isNotNull);
      expect(saved!.hasEdge('a', 'c'), isTrue);
      expect(saved.nodes.length, 3, reason: 'joining adds no points');
    });
  });
}
