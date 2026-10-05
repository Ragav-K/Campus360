#!/usr/bin/env node
/**
 * Tests the graph builder behind `tool/seedPaths.js`.
 *
 *   node tool/testSeedPaths.js
 *
 * No credentials, no network, no dependencies — it only exercises the pure
 * functions. The A* that routes over this graph is covered by
 * `test/campus_graph_test.dart`; what is untested without this is the step in
 * between, where traced lines become nodes and edges. That step is where a
 * campus map goes wrong quietly: a junction that fails to weld leaves two
 * networks that each look fine on screen and cannot be routed between.
 */

const {
  haversineMetres,
  collectGeometries,
  buildGraph,
  mergeGraphs,
  connectedComponents,
  JOIN_METRES,
} = require('./seedPaths.js');

let pass = 0;
let fail = 0;

function check(label, ok, detail = '') {
  if (ok) {
    pass++;
    console.log(`  PASS  ${label}`);
  } else {
    fail++;
    console.log(`  FAIL  ${label} ${detail}`);
  }
}

// Campus centre, matching the Dart tests. ~111 m per 0.001° of latitude.
const LAT = 11.0766;
const LNG = 77.1421;

/** A point [lng, lat] offset from the centre by metres, GeoJSON order. */
const at = (eastMetres, northMetres) => [
  LNG + eastMetres / (111320 * Math.cos((LAT * Math.PI) / 180)),
  LAT + northMetres / 110540,
];

const line = (...points) => ({
  type: 'Feature',
  properties: {},
  geometry: { type: 'LineString', coordinates: points },
});

const point = (coord, name) => ({
  type: 'Feature',
  properties: { name },
  geometry: { type: 'Point', coordinates: coord },
});

const collection = (...features) => ({ type: 'FeatureCollection', features });

const build = (geojson) => buildGraph(collectGeometries(geojson));

const neighbours = (graph, id) =>
  new Set(
    graph.edges
      .filter((e) => e.a === id || e.b === id)
      .map((e) => (e.a === id ? e.b : e.a)),
  );

// ---------------------------------------------------------------------------

console.log('\nGeometry collection');
{
  const { runs, points } = collectGeometries(
    collection(
      line(at(0, 0), at(50, 0)),
      point(at(0, 0), 'Gate'),
      {
        type: 'Feature',
        properties: {},
        geometry: {
          type: 'MultiLineString',
          coordinates: [[at(0, 50), at(50, 50)], [at(0, 90), at(50, 90)]],
        },
      },
      {
        type: 'Feature',
        properties: {},
        // A building outline is not a walkway.
        geometry: { type: 'Polygon', coordinates: [[at(0, 0), at(9, 0), at(9, 9), at(0, 0)]] },
      },
    ),
  );

  check('LineString and MultiLineString both become runs', runs.length === 3, `(got ${runs.length})`);
  check('Point features are collected with their name', points.length === 1 && points[0].name === 'Gate');
  check('Polygons are ignored', runs.every((r) => r.length === 2));
}

console.log('\nBuilding a graph from one line');
{
  const graph = build(collection(line(at(0, 0), at(20, 0), at(40, 0))));

  check('every vertex becomes a node', graph.nodes.length === 3, `(got ${graph.nodes.length})`);
  check('consecutive vertices are joined', graph.edges.length === 2, `(got ${graph.edges.length})`);
  check('node ids are stable and sequential', graph.nodes.map((n) => n.id).join() === 'n1,n2,n3');
  check(
    'the middle vertex connects both ends',
    neighbours(graph, 'n2').size === 2,
    `(got ${neighbours(graph, 'n2').size})`,
  );
}

console.log('\nWelding — the whole reason this script exists');
{
  // Two lines traced to the same junction, 1 m apart from hand-tracing slop.
  const graph = build(
    collection(
      line(at(0, 0), at(30, 0), at(60, 0)),
      line(at(30, 1), at(30, 30)),
    ),
  );

  check('near-identical vertices collapse into one node', graph.nodes.length === 4, `(got ${graph.nodes.length})`);
  check(
    'the branch actually joins the junction',
    neighbours(graph, 'n2').size === 3,
    `(got ${neighbours(graph, 'n2').size} neighbours)`,
  );
  check('the welded network is a single component', connectedComponents(graph).length === 1);
}

{
  // Opposite sides of a walkway must NOT weld, or the network gains shortcuts
  // through places nobody can walk.
  const apart = JOIN_METRES * 3;
  const graph = build(collection(line(at(0, 0), at(50, 0)), line(at(0, apart), at(50, apart))));

  check('vertices further apart than the join radius stay separate', graph.nodes.length === 4);
  check('and stay in separate components', connectedComponents(graph).length === 2);
}

console.log('\nLabelled points');
{
  const graph = build(
    collection(line(at(0, 0), at(30, 0), at(60, 0)), point(at(30, 0.5), 'Library entrance')),
  );

  const named = graph.nodes.filter((n) => n.name);
  check('a point on the line labels that node rather than adding one', graph.nodes.length === 3);
  check('the label survives the weld', named.length === 1 && named[0].name === 'Library entrance');
  check(
    'the labelled node keeps the line’s connections',
    neighbours(graph, named[0].id).size === 2,
    `(got ${neighbours(graph, named[0].id).size})`,
  );
}

console.log('\nDuplicate and degenerate input');
{
  // The same walkway traced twice — easy to do when tracing over a satellite
  // image in two sittings.
  const graph = build(collection(line(at(0, 0), at(40, 0)), line(at(0, 0), at(40, 0))));

  check('a re-traced line adds no duplicate nodes', graph.nodes.length === 2, `(got ${graph.nodes.length})`);
  check('and no duplicate edges', graph.edges.length === 1, `(got ${graph.edges.length})`);
}

{
  // Two vertices that weld together would otherwise produce a self-edge.
  const graph = build(collection(line(at(0, 0), at(0, 0.5), at(40, 0))));

  check('welded consecutive vertices produce no self-edge', graph.edges.every((e) => e.a !== e.b));
  check('and the run still connects end to end', connectedComponents(graph).length === 1);
}

console.log('\nMerging with a stored graph');
{
  const stored = {
    nodes: [
      { id: 'old1', lat: LAT, lng: LNG, name: 'Surveyed gate' },
      { id: 'old2', lat: at(0, 40)[1], lng: at(0, 40)[0] },
    ],
    edges: [{ a: 'old1', b: 'old2' }],
  };

  // A newly traced line starting at the stored gate.
  const incoming = build(collection(line(at(0, 0.5), at(50, 0))));
  const merged = mergeGraphs(stored, incoming);

  check('stored and traced points both survive', merged.nodes.length === 3, `(got ${merged.nodes.length})`);
  check('the traced line welds onto the surveyed point', merged.edges.length === 2, `(got ${merged.edges.length})`);
  check('the merge is one connected network', connectedComponents(merged).length === 1);
  check(
    'a surveyed name is not lost in the merge',
    merged.nodes.some((n) => n.name === 'Surveyed gate'),
  );
  check('merged ids are renumbered consistently', merged.edges.every((e) => e.a !== e.b));
}

{
  // saveGraph tolerates a dangling edge on read; the merge must not carry one
  // forward into the document it writes.
  const stored = {
    nodes: [{ id: 'old1', lat: LAT, lng: LNG }],
    edges: [{ a: 'old1', b: 'deleted' }],
  };
  const merged = mergeGraphs(stored, build(collection(line(at(80, 0), at(120, 0)))));

  check('dangling stored edges are dropped', merged.edges.length === 1, `(got ${merged.edges.length})`);
}

console.log('\nConnectivity reporting');
{
  const graph = build(
    collection(line(at(0, 0), at(40, 0)), line(at(300, 300), at(340, 300)), line(at(600, 0), at(640, 0))),
  );
  const components = connectedComponents(graph);

  check('every disconnected piece is reported', components.length === 3, `(got ${components.length})`);
  check('components are ordered largest first', components[0].length >= components[2].length);
}

console.log('\nDistance');
{
  check('haversine is zero for a point against itself', haversineMetres(LAT, LNG, LAT, LNG) < 0.001);
  check(
    'and matches the Dart implementation for 0.001°',
    Math.abs(haversineMetres(LAT, LNG, LAT + 0.001, LNG) - 111.19) < 0.5,
  );
}

console.log(`\n${pass} passed, ${fail} failed.`);
process.exit(fail === 0 ? 0 : 1);
