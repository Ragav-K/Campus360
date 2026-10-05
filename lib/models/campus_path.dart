import 'dart:collection';
import 'dart:math' as math;

/// Great-circle distance in metres between two lat/lng points.
///
/// Haversine rather than a flat-earth approximation: the maths is trivial and
/// it removes any doubt about correctness, even though over 600 m of campus the
/// difference is centimetres.
double haversineMetres(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180.0;

  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);

  return 2 * earthRadius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// A point on the campus walking network — a junction, a doorway, a corner.
class PathNode {
  const PathNode({required this.id, required this.lat, required this.lng, this.name = ''});

  final String id;
  final double lat;
  final double lng;

  /// Optional human label, e.g. "Library entrance". Useful when surveying.
  final String name;

  double distanceTo(PathNode other) => haversineMetres(lat, lng, other.lat, other.lng);

  factory PathNode.fromMap(Map<String, dynamic> m) => PathNode(
        id: m['id'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        name: m['name'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        if (name.isNotEmpty) 'name': name,
      };
}

/// The campus walking network, and the routing over it.
///
/// Pure Dart — no Firebase, no Flutter — so the routing can be unit-tested
/// directly and runs entirely on the device with no network. That is the whole
/// point: online routing APIs (Google/Mapbox Directions) cannot work here.
class CampusGraph {
  CampusGraph({required this.nodes, required List<({String a, String b})> edges})
      : _adjacency = _buildAdjacency(nodes, edges),
        _edges = edges;

  final List<PathNode> nodes;
  final List<({String a, String b})> _edges;
  final Map<String, Set<String>> _adjacency;

  List<({String a, String b})> get edges => List.unmodifiable(_edges);

  bool get isEmpty => nodes.isEmpty || _edges.isEmpty;

  static Map<String, Set<String>> _buildAdjacency(
    List<PathNode> nodes,
    List<({String a, String b})> edges,
  ) {
    final ids = {for (final n in nodes) n.id};
    final map = {for (final n in nodes) n.id: <String>{}};

    for (final edge in edges) {
      // Edges are undirected. Ignore any referring to a node that no longer
      // exists — a survey can delete a node and leave a dangling edge.
      if (!ids.contains(edge.a) || !ids.contains(edge.b) || edge.a == edge.b) continue;
      map[edge.a]!.add(edge.b);
      map[edge.b]!.add(edge.a);
    }
    return map;
  }

  PathNode? nodeById(String id) => nodes.where((n) => n.id == id).firstOrNull;

  /// Nearest node to a coordinate, or null when the graph is empty.
  ///
  /// [maxMetres] guards against snapping someone standing far off campus onto
  /// a node that is nowhere near them.
  PathNode? nearestNode(double lat, double lng, {double maxMetres = 250}) {
    PathNode? best;
    var bestDistance = double.infinity;

    for (final node in nodes) {
      final d = haversineMetres(lat, lng, node.lat, node.lng);
      if (d < bestDistance) {
        bestDistance = d;
        best = node;
      }
    }
    return bestDistance <= maxMetres ? best : null;
  }

  /// Shortest walking route between two coordinates, as an ordered list of
  /// nodes. Returns null when either end can't be snapped to the network, or
  /// when the two ends are in disconnected parts of it.
  ///
  /// Callers must handle null by drawing a direct line marked as such, rather
  /// than implying a path exists.
  List<PathNode>? route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    final start = nearestNode(fromLat, fromLng);
    final goal = nearestNode(toLat, toLng);
    if (start == null || goal == null) return null;
    if (start.id == goal.id) return [start];

    return _aStar(start, goal);
  }

  /// A* with a straight-line-distance heuristic.
  ///
  /// The heuristic never overestimates (a straight line is the shortest
  /// possible distance between two points), so the result is guaranteed
  /// optimal, not merely plausible.
  List<PathNode>? _aStar(PathNode start, PathNode goal) {
    final byId = {for (final n in nodes) n.id: n};

    final cameFrom = <String, String>{};
    final gScore = <String, double>{start.id: 0};
    final fScore = <String, double>{start.id: start.distanceTo(goal)};

    // A sorted set keyed on fScore acts as the priority queue. Node counts here
    // are in the hundreds, so this is far simpler than a real heap and just as
    // fast in practice.
    final open = SplayTreeSet<String>((a, b) {
      final byScore = (fScore[a] ?? double.infinity).compareTo(fScore[b] ?? double.infinity);
      return byScore != 0 ? byScore : a.compareTo(b); // tie-break keeps it a set
    })
      ..add(start.id);

    final visited = <String>{};

    while (open.isNotEmpty) {
      final currentId = open.first;
      if (currentId == goal.id) return _reconstruct(cameFrom, byId, goal.id);

      open.remove(currentId);
      visited.add(currentId);

      final current = byId[currentId]!;
      for (final neighbourId in _adjacency[currentId] ?? const <String>{}) {
        if (visited.contains(neighbourId)) continue;
        final neighbour = byId[neighbourId]!;

        final tentative = gScore[currentId]! + current.distanceTo(neighbour);
        if (tentative >= (gScore[neighbourId] ?? double.infinity)) continue;

        // Remove before mutating fScore — the set's ordering depends on it, and
        // changing the key of a member in place corrupts the tree.
        open.remove(neighbourId);
        cameFrom[neighbourId] = currentId;
        gScore[neighbourId] = tentative;
        fScore[neighbourId] = tentative + neighbour.distanceTo(goal);
        open.add(neighbourId);
      }
    }

    return null; // disconnected
  }

  List<PathNode> _reconstruct(
    Map<String, String> cameFrom,
    Map<String, PathNode> byId,
    String goalId,
  ) {
    final path = <PathNode>[byId[goalId]!];
    var current = goalId;
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.insert(0, byId[current]!);
    }
    return path;
  }

  /// Total walking distance of a route in metres.
  static double routeLength(List<PathNode> route) {
    var total = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      total += route[i].distanceTo(route[i + 1]);
    }
    return total;
  }

  /// Nodes directly joined to [id]. The survey map draws these so an admin can
  /// see what a point is connected to before deleting it.
  Set<String> neighboursOf(String id) => Set.unmodifiable(_adjacency[id] ?? const <String>{});

  bool hasEdge(String a, String b) => (_adjacency[a] ?? const <String>{}).contains(b);

  // ---------------------------------------------------------------------------
  // Editing. Every operation returns a new graph rather than mutating this one:
  // the survey screen saves the result wholesale, and an in-place edit that
  // failed to save would leave the UI showing a state Firestore never accepted.
  // ---------------------------------------------------------------------------

  /// Adds a node, optionally joined to an existing one.
  CampusGraph withNode(PathNode node, {String? connectTo}) => CampusGraph(
        nodes: [...nodes, node],
        edges: [
          ..._edges,
          if (connectTo != null && connectTo != node.id) (a: connectTo, b: node.id),
        ],
      );

  /// Removes a node and every edge touching it.
  ///
  /// Dropping the edges matters: [CampusGraph] tolerates dangling edges when
  /// reading, but leaving them in the saved document accumulates rubbish that
  /// makes a later survey harder to reason about.
  CampusGraph withoutNode(String id) => CampusGraph(
        nodes: nodes.where((n) => n.id != id).toList(),
        edges: _edges.where((e) => e.a != id && e.b != id).toList(),
      );

  /// Joins two nodes. A no-op for a self-edge, an unknown node, or a pair that
  /// is already connected — all three are things a fat-fingered tap can ask for.
  CampusGraph withEdge(String a, String b) {
    final ids = {for (final n in nodes) n.id};
    if (a == b || !ids.contains(a) || !ids.contains(b) || hasEdge(a, b)) return this;
    return CampusGraph(nodes: nodes, edges: [..._edges, (a: a, b: b)]);
  }

  /// Breaks the connection between two nodes, leaving both in place.
  CampusGraph withoutEdge(String a, String b) => CampusGraph(
        nodes: nodes,
        edges: _edges
            .where((e) => !((e.a == a && e.b == b) || (e.a == b && e.b == a)))
            .toList(),
      );

  factory CampusGraph.fromMap(Map<String, dynamic>? d) {
    if (d == null) return CampusGraph(nodes: const [], edges: const []);

    final nodes = (d['nodes'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(PathNode.fromMap)
            .where((n) => n.id.isNotEmpty)
            .toList() ??
        <PathNode>[];

    final edges = (d['edges'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => (a: e['a'] as String? ?? '', b: e['b'] as String? ?? ''))
            .where((e) => e.a.isNotEmpty && e.b.isNotEmpty)
            .toList() ??
        <({String a, String b})>[];

    return CampusGraph(nodes: nodes, edges: edges);
  }

  Map<String, dynamic> toMap() => {
        'nodes': nodes.map((n) => n.toMap()).toList(),
        'edges': _edges.map((e) => {'a': e.a, 'b': e.b}).toList(),
      };
}

/// Estimated walking time at a normal campus pace.
Duration walkingTime(double metres) =>
    Duration(seconds: (metres / 1.35).round()); // 1.35 m/s ≈ 4.9 km/h
