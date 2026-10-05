#!/usr/bin/env node
/**
 * Builds `campusPaths/graph` — the campus walking network — from a GeoJSON
 * file of footpaths traced in geojson.io, Google My Maps or JOSM.
 *
 *   node tool/seedPaths.js tool/data/campus_paths.geojson
 *   node tool/seedPaths.js paths.geojson --dry-run     # print, write nothing
 *   node tool/seedPaths.js paths.geojson --merge       # keep existing nodes
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS to point at the admin key, e.g.
 *   GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/campus360-admin.json node tool/seedPaths.js paths.geojson
 *
 * Input: any GeoJSON (FeatureCollection, Feature, or bare geometry). LineString
 * and MultiLineString become walkable runs — consecutive vertices are joined
 * into edges. Point features become named nodes (their `name` property is kept)
 * and are welded into whatever line passes through them, which is how you label
 * a junction or a building entrance. Polygons are ignored.
 *
 * Vertices closer than JOIN_METRES are collapsed into one node, so two paths
 * that were traced to the same junction actually connect there — without that
 * A* treats them as separate networks and refuses to route between them.
 *
 * Safe to re-run: the whole graph lives in one document and is replaced
 * wholesale, so re-seeding a corrected file corrects the map.
 */

const fs = require('fs');
const path = require('path');

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const PROJECT_ID = 'campus360-app';
const DATABASE_ID = 'default'; // named database — see SETUP.md

// Two vertices within this distance are the same place. Loose enough to absorb
// hand-tracing slop, tight enough not to weld opposite sides of a walkway.
const JOIN_METRES = 4;

// A campusLocation further than this from every node cannot be routed to:
// CampusGraph.nearestNode gives up at 250 m, but anything beyond ~40 m means
// the path stops well short of the door.
const REACH_METRES = 40;

// Same maths as lib/models/campus_path.dart — the graph this writes is routed
// over on-device, so the two must agree about what "4 metres apart" means.
function haversineMetres(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ---------------------------------------------------------------------------
// GeoJSON -> runs of [lng, lat] coordinates, plus standalone labelled points
// ---------------------------------------------------------------------------

function collectGeometries(geojson) {
  const runs = []; // arrays of [lng, lat]
  const points = []; // { lng, lat, name }

  const visitGeometry = (geometry, props) => {
    if (!geometry) return;
    const name = (props && (props.name || props.title)) || '';

    switch (geometry.type) {
      case 'LineString':
        runs.push(geometry.coordinates);
        break;
      case 'MultiLineString':
        runs.push(...geometry.coordinates);
        break;
      case 'Point': {
        const [lng, lat] = geometry.coordinates;
        points.push({ lng, lat, name });
        break;
      }
      case 'MultiPoint':
        for (const [lng, lat] of geometry.coordinates) points.push({ lng, lat, name });
        break;
      case 'GeometryCollection':
        for (const g of geometry.geometries) visitGeometry(g, props);
        break;
      default:
        // Polygons and anything exotic: a building outline is not a walkway.
        break;
    }
  };

  const visit = (node) => {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'FeatureCollection') node.features.forEach(visit);
    else if (node.type === 'Feature') visitGeometry(node.geometry, node.properties);
    else visitGeometry(node, null);
  };

  visit(geojson);
  return { runs, points };
}

// ---------------------------------------------------------------------------
// Vertex welding
// ---------------------------------------------------------------------------

/**
 * Interns coordinates into node ids, collapsing anything within JOIN_METRES.
 *
 * Candidates come from a coarse lat/lng grid so this stays linear-ish instead
 * of comparing every vertex to every other one; the cell is sized above the
 * join radius, and neighbouring cells are checked, so nothing near a cell
 * boundary is missed.
 */
class NodeSet {
  constructor() {
    this.nodes = [];
    this.cells = new Map();
    // ~1e-4 degrees is ~11 m of latitude: comfortably larger than JOIN_METRES.
    this.cellSize = 0.0001;
  }

  _cellKey(lat, lng) {
    return `${Math.floor(lat / this.cellSize)}:${Math.floor(lng / this.cellSize)}`;
  }

  _nearby(lat, lng) {
    const out = [];
    const ci = Math.floor(lat / this.cellSize);
    const cj = Math.floor(lng / this.cellSize);
    for (let di = -1; di <= 1; di++) {
      for (let dj = -1; dj <= 1; dj++) {
        const bucket = this.cells.get(`${ci + di}:${cj + dj}`);
        if (bucket) out.push(...bucket);
      }
    }
    return out;
  }

  /** Returns the id of an existing node at this spot, or creates one. */
  intern(lat, lng, name = '') {
    let best = null;
    let bestDistance = Infinity;

    for (const node of this._nearby(lat, lng)) {
      const d = haversineMetres(lat, lng, node.lat, node.lng);
      if (d < bestDistance) {
        bestDistance = d;
        best = node;
      }
    }

    if (best && bestDistance <= JOIN_METRES) {
      // A named point wins over an unnamed vertex it merged with — the label
      // is the reason it was placed by hand.
      if (name && !best.name) best.name = name;
      return best.id;
    }

    const node = { id: `n${this.nodes.length + 1}`, lat, lng, name };
    this.nodes.push(node);
    const key = this._cellKey(lat, lng);
    if (!this.cells.has(key)) this.cells.set(key, []);
    this.cells.get(key).push(node);
    return node.id;
  }
}

function buildGraph({ runs, points }) {
  const set = new NodeSet();

  // Labelled points first, so a junction keeps its name rather than inheriting
  // an anonymous line vertex that happened to be interned earlier.
  for (const p of points) set.intern(p.lat, p.lng, p.name);

  const edgeKeys = new Set();
  const edges = [];

  const addEdge = (a, b) => {
    if (a === b) return; // a zero-length segment: two vertices that welded
    const key = a < b ? `${a}|${b}` : `${b}|${a}`; // undirected
    if (edgeKeys.has(key)) return;
    edgeKeys.add(key);
    edges.push({ a, b });
  };

  for (const run of runs) {
    let previousId = null;
    for (const [lng, lat] of run) {
      const id = set.intern(lat, lng);
      if (previousId) addEdge(previousId, id);
      previousId = id;
    }
  }

  const nodes = set.nodes.map((n) => (n.name ? n : { id: n.id, lat: n.lat, lng: n.lng }));
  return { nodes, edges };
}

/** Merges a previously stored graph in, re-welding its nodes against the new ones. */
function mergeGraphs(existing, incoming) {
  const set = new NodeSet();
  const idMap = new Map();

  for (const source of [incoming, existing]) {
    for (const n of source.nodes) {
      idMap.set(`${source === incoming ? 'new' : 'old'}:${n.id}`, set.intern(n.lat, n.lng, n.name || ''));
    }
  }

  const edgeKeys = new Set();
  const edges = [];
  for (const source of [incoming, existing]) {
    const prefix = source === incoming ? 'new' : 'old';
    for (const e of source.edges) {
      const a = idMap.get(`${prefix}:${e.a}`);
      const b = idMap.get(`${prefix}:${e.b}`);
      if (!a || !b || a === b) continue; // dangling edge — drop it, as the app does
      const key = a < b ? `${a}|${b}` : `${b}|${a}`;
      if (edgeKeys.has(key)) continue;
      edgeKeys.add(key);
      edges.push({ a, b });
    }
  }

  const nodes = set.nodes.map((n) => (n.name ? n : { id: n.id, lat: n.lat, lng: n.lng }));
  return { nodes, edges };
}

// ---------------------------------------------------------------------------
// Checks — a graph that writes cleanly can still be unroutable
// ---------------------------------------------------------------------------

function connectedComponents({ nodes, edges }) {
  const adjacency = new Map(nodes.map((n) => [n.id, []]));
  for (const e of edges) {
    if (!adjacency.has(e.a) || !adjacency.has(e.b)) continue;
    adjacency.get(e.a).push(e.b);
    adjacency.get(e.b).push(e.a);
  }

  const seen = new Set();
  const components = [];

  for (const node of nodes) {
    if (seen.has(node.id)) continue;
    const stack = [node.id];
    const component = [];
    seen.add(node.id);
    while (stack.length) {
      const id = stack.pop();
      component.push(id);
      for (const next of adjacency.get(id)) {
        if (seen.has(next)) continue;
        seen.add(next);
        stack.push(next);
      }
    }
    components.push(component);
  }

  return components.sort((a, b) => b.length - a.length);
}

async function reportUnreachableLocations(db, nodes) {
  let snap;
  try {
    snap = await db.collection('campusLocations').get();
  } catch (e) {
    // A dry run is useful with no credentials at all — the welding and
    // connectivity checks are pure. Only this cross-check needs Firestore, so
    // it degrades to a note rather than taking the whole run down.
    console.warn(`\n⚠ Could not check places against the network: ${e.message.split('\n')[0]}`);
    return;
  }

  const stranded = [];

  for (const doc of snap.docs) {
    const geo = doc.get('geo');
    if (!geo || typeof geo.lat !== 'number' || typeof geo.lng !== 'number') continue;
    let nearest = Infinity;
    for (const n of nodes) {
      nearest = Math.min(nearest, haversineMetres(geo.lat, geo.lng, n.lat, n.lng));
    }
    if (nearest > REACH_METRES) {
      stranded.push({ name: doc.get('name') || doc.id, metres: Math.round(nearest) });
    }
  }

  if (stranded.length === 0) return;
  console.warn(`\n⚠ ${stranded.length} place(s) with no path point nearby:`);
  for (const s of stranded) console.warn(`    ${s.name} — nearest point ${s.metres} m away`);
  console.warn('  Trace a spur to each entrance, or routing will stop short of the door.');
}

// ---------------------------------------------------------------------------

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const merge = args.includes('--merge');
  const file = args.find((a) => !a.startsWith('--')) || 'tool/data/campus_paths.geojson';

  const absolute = path.resolve(file);
  if (!fs.existsSync(absolute)) {
    console.error(`No such file: ${absolute}`);
    console.error('Usage: node tool/seedPaths.js <paths.geojson> [--merge] [--dry-run]');
    process.exit(1);
  }

  const geojson = JSON.parse(fs.readFileSync(absolute, 'utf8'));
  const collected = collectGeometries(geojson);
  if (collected.runs.length === 0 && collected.points.length === 0) {
    console.error('No LineString or Point geometries found — nothing to seed.');
    process.exit(1);
  }

  // Constructing these does no I/O and needs no credentials; the first actual
  // read or write is where a missing key surfaces.
  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db = getFirestore(DATABASE_ID);
  const doc = db.collection('campusPaths').doc('graph');

  let graph = buildGraph(collected);

  if (merge) {
    const snap = await doc.get();
    const existing = snap.data();
    if (existing && Array.isArray(existing.nodes)) {
      const before = graph.nodes.length;
      graph = mergeGraphs(
        { nodes: existing.nodes, edges: existing.edges || [] },
        graph,
      );
      console.log(`Merged with stored graph: ${before} -> ${graph.nodes.length} points.`);
    }
  }

  const components = connectedComponents(graph);
  console.log(
    `${path.basename(file)}: ${collected.runs.length} line(s), ` +
      `${collected.points.length} labelled point(s)`,
  );
  console.log(`Graph: ${graph.nodes.length} points, ${graph.edges.length} connections.`);

  if (components.length > 1) {
    console.warn(`\n⚠ The network is in ${components.length} disconnected pieces:`);
    for (const c of components.slice(0, 5)) {
      const sample = graph.nodes.find((n) => n.id === c[0]);
      console.warn(
        `    ${c.length} point(s) near ${sample.lat.toFixed(5)}, ${sample.lng.toFixed(5)}`,
      );
    }
    console.warn('  Routing between pieces returns no route. Join them at a junction.');
  }

  if (dryRun) {
    // No Firestore at all on a dry run, so the welding and connectivity checks
    // are usable with no credentials — which is exactly when you want them,
    // while still deciding whether the trace is any good. Skipping the
    // cross-check is not optional politeness: google-gax reports a missing key
    // as an uncaught async error that a try/catch around the read never sees.
    console.log('\n--dry-run: nothing written, and places were not cross-checked.');
    return;
  }

  await reportUnreachableLocations(db, graph.nodes);

  await doc.set({
    nodes: graph.nodes,
    edges: graph.edges,
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log('\nWrote campusPaths/graph.');
}

// Only seed when run directly, so tool/testSeedPaths.js can require the pure
// builders without needing credentials or touching Firestore.
if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

module.exports = {
  haversineMetres,
  collectGeometries,
  buildGraph,
  mergeGraphs,
  connectedComponents,
  JOIN_METRES,
};
