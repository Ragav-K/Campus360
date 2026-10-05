import 'package:campus360/models/campus_path.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nodes laid out around the real campus centre (11.0766, 77.1421).
///
///   a ---------------- b            (a→b direct, but long)
///   |                  |
///   c ------- d ------ e            (a→c→d→e→b, the detour)
///
/// Roughly 100 m per grid step.
const _step = 0.0009; // ~100 m of latitude

PathNode _n(String id, double dLat, double dLng) =>
    PathNode(id: id, lat: 11.0766 + dLat * _step, lng: 77.1421 + dLng * _step);

CampusGraph _grid() => CampusGraph(
      nodes: [
        _n('a', 0, 0),
        _n('b', 0, 4),
        _n('c', -1, 0),
        _n('d', -1, 2),
        _n('e', -1, 4),
      ],
      edges: const [
        (a: 'a', b: 'c'),
        (a: 'c', b: 'd'),
        (a: 'd', b: 'e'),
        (a: 'e', b: 'b'),
      ],
    );

void main() {
  group('haversineMetres', () {
    test('is zero for the same point', () {
      expect(haversineMetres(11.0766, 77.1421, 11.0766, 77.1421), closeTo(0, 0.001));
    });

    test('matches a known distance', () {
      // 0.001° of latitude ≈ 111.19 m anywhere on Earth.
      final d = haversineMetres(11.0766, 77.1421, 11.0776, 77.1421);
      expect(d, closeTo(111.2, 1.0));
    });

    test('is symmetric', () {
      final ab = haversineMetres(11.0766, 77.1421, 11.0790, 77.1450);
      final ba = haversineMetres(11.0790, 77.1450, 11.0766, 77.1421);
      expect(ab, closeTo(ba, 0.0001));
    });
  });

  group('nearestNode', () {
    test('snaps to the closest node', () {
      final graph = _grid();
      final near = graph.nearestNode(11.0766 + 0.0001, 77.1421 + 0.0001);
      expect(near?.id, 'a');
    });

    test('refuses to snap when nothing is within range', () {
      // Chennai, ~350 km away — must not snap onto the campus.
      expect(_grid().nearestNode(13.0827, 80.2707), isNull);
    });

    test('returns null on an empty graph', () {
      final empty = CampusGraph(nodes: const [], edges: const []);
      expect(empty.nearestNode(11.0766, 77.1421), isNull);
      expect(empty.isEmpty, isTrue);
    });
  });

  group('route', () {
    test('follows the only available path, not the straight line', () {
      final graph = _grid();
      final a = graph.nodeById('a')!;
      final b = graph.nodeById('b')!;

      final path = graph.route(fromLat: a.lat, fromLng: a.lng, toLat: b.lat, toLng: b.lng);

      // There is no a→b edge; the walk must go the long way round.
      expect(path?.map((n) => n.id).toList(), ['a', 'c', 'd', 'e', 'b']);
    });

    test('prefers a direct edge once one exists', () {
      final graph = CampusGraph(
        nodes: _grid().nodes,
        edges: [..._grid().edges, (a: 'a', b: 'b')],
      );
      final a = graph.nodeById('a')!;
      final b = graph.nodeById('b')!;

      final path = graph.route(fromLat: a.lat, fromLng: a.lng, toLat: b.lat, toLng: b.lng);
      expect(path?.map((n) => n.id).toList(), ['a', 'b']);
    });

    test('returns a single node when start and destination snap together', () {
      final graph = _grid();
      final a = graph.nodeById('a')!;
      final path = graph.route(
        fromLat: a.lat,
        fromLng: a.lng,
        toLat: a.lat + 0.00001,
        toLng: a.lng,
      );
      expect(path?.length, 1);
    });

    test('returns null across disconnected components', () {
      // 'z' sits near the others but is joined to nothing.
      final graph = CampusGraph(
        nodes: [..._grid().nodes, _n('z', -2, 2)],
        edges: _grid().edges,
      );
      final a = graph.nodeById('a')!;
      final z = graph.nodeById('z')!;

      expect(
        graph.route(fromLat: a.lat, fromLng: a.lng, toLat: z.lat, toLng: z.lng),
        isNull,
        reason: 'callers must fall back to a direct line rather than invent a path',
      );
    });

    test('returns null when the graph has no edges at all', () {
      final graph = CampusGraph(nodes: _grid().nodes, edges: const []);
      final a = graph.nodeById('a')!;
      final b = graph.nodeById('b')!;
      expect(graph.route(fromLat: a.lat, fromLng: a.lng, toLat: b.lat, toLng: b.lng), isNull);
    });

    test('ignores edges pointing at deleted nodes', () {
      // A survey can delete a node and leave a dangling edge behind.
      final graph = CampusGraph(
        nodes: [_n('a', 0, 0), _n('c', -1, 0)],
        edges: const [(a: 'a', b: 'c'), (a: 'c', b: 'ghost')],
      );
      final a = graph.nodeById('a')!;
      final c = graph.nodeById('c')!;

      expect(
        graph.route(fromLat: a.lat, fromLng: a.lng, toLat: c.lat, toLng: c.lng)?.length,
        2,
      );
    });
  });

  group('routeLength and walkingTime', () {
    test('sums the legs of a route', () {
      final graph = _grid();
      final a = graph.nodeById('a')!;
      final b = graph.nodeById('b')!;
      final path = graph.route(fromLat: a.lat, fromLng: a.lng, toLat: b.lat, toLng: b.lng)!;

      // 1 down + 4 across + 1 up ≈ 6 grid steps of ~100 m.
      expect(CampusGraph.routeLength(path), closeTo(600, 60));
    });

    test('a single-node route has no length', () {
      final graph = _grid();
      expect(CampusGraph.routeLength([graph.nodeById('a')!]), 0);
    });

    test('estimates walking time at a campus pace', () {
      expect(walkingTime(135).inSeconds, 100); // 1.35 m/s
      expect(walkingTime(0).inSeconds, 0);
    });
  });

  group('serialisation', () {
    test('survives a round trip', () {
      final original = _grid();
      final restored = CampusGraph.fromMap(original.toMap());

      expect(restored.nodes.length, original.nodes.length);
      expect(restored.edges.length, original.edges.length);

      final a = restored.nodeById('a')!;
      final b = restored.nodeById('b')!;
      expect(
        restored.route(fromLat: a.lat, fromLng: a.lng, toLat: b.lat, toLng: b.lng)?.length,
        5,
      );
    });

    test('a missing document yields an empty graph rather than throwing', () {
      final graph = CampusGraph.fromMap(null);
      expect(graph.isEmpty, isTrue);
      expect(graph.nodes, isEmpty);
    });

    test('malformed entries are skipped, not fatal', () {
      final graph = CampusGraph.fromMap({
        'nodes': [
          {'id': 'a', 'lat': 11.0766, 'lng': 77.1421},
          {'lat': 11.0, 'lng': 77.0}, // no id
          'rubbish',
        ],
        'edges': [
          {'a': 'a', 'b': ''}, // incomplete
          42,
        ],
      });
      expect(graph.nodes.length, 1);
      expect(graph.edges, isEmpty);
    });
  });

  group('editing', () {
    test('withNode adds an unconnected point when nothing is given to join to', () {
      final graph = _grid().withNode(_n('f', -2, 2));

      expect(graph.nodes.length, 6);
      expect(graph.edges.length, 4);
      expect(graph.neighboursOf('f'), isEmpty);
    });

    test('withNode joins to the point it was dropped from', () {
      final graph = _grid().withNode(_n('f', -2, 2), connectTo: 'd');

      expect(graph.neighboursOf('f'), {'d'});
      expect(graph.neighboursOf('d'), containsAll(<String>{'c', 'e', 'f'}));
    });

    test('withoutNode takes its connections with it', () {
      final graph = _grid().withoutNode('d');

      expect(graph.nodeById('d'), isNull);
      // c-d and d-e both go: a dangling edge left behind would be tolerated
      // when routing but is rubbish in the saved document.
      expect(graph.edges.length, 2);
      expect(graph.neighboursOf('c'), {'a'});
      expect(graph.neighboursOf('e'), {'b'});
    });

    test('deleting a mid-path point severs the route through it', () {
      final graph = _grid().withoutNode('d');
      final route = graph.route(
        fromLat: _n('a', 0, 0).lat,
        fromLng: _n('a', 0, 0).lng,
        toLat: _n('b', 0, 4).lat,
        toLng: _n('b', 0, 4).lng,
      );

      expect(route, isNull, reason: 'the two halves are now disconnected');
    });

    test('withEdge joins two existing points', () {
      final graph = _grid().withEdge('a', 'b');

      expect(graph.hasEdge('a', 'b'), isTrue);
      expect(graph.hasEdge('b', 'a'), isTrue, reason: 'edges are undirected');
      expect(graph.edges.length, 5);
    });

    test('withEdge refuses the pairs a fat-fingered tap produces', () {
      final grid = _grid();

      expect(grid.withEdge('a', 'a').edges.length, 4, reason: 'self-edge');
      expect(grid.withEdge('a', 'nope').edges.length, 4, reason: 'unknown node');
      expect(grid.withEdge('c', 'd').edges.length, 4, reason: 'already connected');
      expect(grid.withEdge('d', 'c').edges.length, 4, reason: 'already connected, reversed');
    });

    test('withoutEdge breaks the link but keeps both points', () {
      final graph = _grid().withoutEdge('d', 'c'); // reversed from how it was stored

      expect(graph.hasEdge('c', 'd'), isFalse);
      expect(graph.nodes.length, 5);
      expect(graph.nodeById('d'), isNotNull);
    });

    test('edits leave the original graph untouched', () {
      final original = _grid();
      original.withoutNode('d');
      original.withEdge('a', 'b');

      expect(original.nodes.length, 5);
      expect(original.edges.length, 4);
      expect(original.hasEdge('c', 'd'), isTrue);
    });

    test('an edited graph survives a save-and-reload round trip', () {
      final edited = _grid().withoutNode('d').withEdge('a', 'b');
      final reloaded = CampusGraph.fromMap(edited.toMap());

      expect(reloaded.nodes.length, 4);
      expect(reloaded.hasEdge('a', 'b'), isTrue);
      expect(reloaded.nodeById('d'), isNull);
    });
  });
}
