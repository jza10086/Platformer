#!/usr/bin/env python3
"""Extract one mushroom and the red flag cloth from Kenney Platformer Kit 4.1.

Only standard-library data processing: no external archive code is executed.
Original GLBs remain unchanged beside the derived files. Run from the repo root.
"""
from pathlib import Path
import collections
import json
import struct

ROOT = Path(__file__).resolve().parents[1] / 'assets/kenney/platformer-kit/Models'

def extract(source, target, select_components):
    blob = (ROOT / source).read_bytes()
    json_len = struct.unpack_from('<I', blob, 12)[0]
    document = json.loads(blob[20:20 + json_len])
    binary = blob[28 + json_len:]
    primitive = document['meshes'][0]['primitives'][0]
    def read(index):
        a = document['accessors'][index]
        v = document['bufferViews'][a['bufferView']]
        count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        fmt = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]
        size = struct.calcsize(fmt) * count
        start = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        return [struct.unpack_from('<' + fmt * count, binary, start + i * size) for i in range(a['count'])]
    positions = read(primitive['attributes']['POSITION'])
    indices = [v[0] for v in read(primitive['indices'])]
    parents = list(range(len(positions)))
    def find(i):
        while parents[i] != i:
            i = parents[i]
        return i
    def union(a, b):
        parents[find(a)] = find(b)
    seen = {}
    for i, p in enumerate(positions):
        key = tuple(round(v, 5) for v in p)
        if key in seen:
            union(i, seen[key])
        seen[key] = i
    for i in range(0, len(indices), 3):
        union(indices[i], indices[i + 1])
        union(indices[i + 1], indices[i + 2])
    groups = collections.defaultdict(list)
    for i in range(len(positions)):
        groups[find(i)].append(i)
    chosen = set()
    for group in groups.values():
        points = [positions[i] for i in group]
        low = [min(p[k] for p in points) for k in range(3)]
        high = [max(p[k] for p in points) for k in range(3)]
        if select_components(low, high):
            chosen.update(group)
    selected_triangles = [indices[i:i + 3] for i in range(0, len(indices), 3) if all(n in chosen for n in indices[i:i + 3])]
    vertices = sorted(set(n for face in selected_triangles for n in face))
    remap = {old: new for new, old in enumerate(vertices)}
    assert vertices and selected_triangles
    out = bytearray()
    views, accessors = [], []
    def write(values, kind, component=5126):
        while len(out) % 4:
            out.append(0)
        start = len(out)
        fmt = 'f' if component == 5126 else 'I'
        for value in values:
            out.extend(struct.pack('<' + fmt * len(value), *value))
        views.append({'buffer': 0, 'byteOffset': start, 'byteLength': len(out) - start})
        accessors.append({'bufferView': len(views) - 1, 'componentType': component, 'count': len(values), 'type': kind})
        return len(accessors) - 1
    attributes = {}
    for name, index in primitive['attributes'].items():
        values = read(index)
        attributes[name] = write([values[i] for i in vertices], document['accessors'][index]['type'])
    pos_accessor = accessors[attributes['POSITION']]
    pos_accessor['min'] = [min(positions[i][k] for i in vertices) for k in range(3)]
    pos_accessor['max'] = [max(positions[i][k] for i in vertices) for k in range(3)]
    new_indices = write([(remap[i],) for face in selected_triangles for i in face], 'SCALAR', 5125)
    while len(out) % 4:
        out.append(0)
    generated = {
        'asset': {'version': '2.0', 'generator': 'Cloudstep deterministic subset extraction; source Kenney CC0'},
        'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': Path(target).stem}],
        'meshes': [{'primitives': [{'attributes': attributes, 'indices': new_indices, 'material': 0}]}],
        'materials': document['materials'], 'textures': document['textures'], 'images': document['images'],
        'samplers': document.get('samplers', []), 'buffers': [{'byteLength': len(out)}],
        'bufferViews': views, 'accessors': accessors,
    }
    if 'extensionsUsed' in document:
        generated['extensionsUsed'] = document['extensionsUsed']
    encoded = json.dumps(generated, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    result = struct.pack('<III', 0x46546C67, 2, 28 + len(encoded) + len(out))
    result += struct.pack('<II', len(encoded), 0x4E4F534A) + encoded
    result += struct.pack('<II', len(out), 0x004E4942) + out
    (ROOT / target).write_bytes(result)
    print(target, len(vertices), 'vertices;', len(selected_triangles), 'triangles')

# The tall mushroom's cap and stalk are two disconnected components at +X.
extract('mushrooms.glb', 'mushroom-single.glb', lambda low, high: (low[0] + high[0]) / 2 > 0.1)
# The fabric is the component entirely to the right of the pole.
extract('flag.glb', 'flag-cloth.glb', lambda low, high: low[0] > 0.04)
