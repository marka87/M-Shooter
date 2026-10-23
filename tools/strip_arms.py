"""AK-Arme aus fps_ak_animated.glb (DJMaesen, CC BY 4.0) herausloesen: nur Arm-Mesh, Skelett, Animation.
AK-Knoten bleiben leer (Bezug fuer die Waffenlage), AK-Meshes/Material/Texturen fliegen raus,
Arm-Texturen werden auf 1024 px verkleinert, die Grundfarbe grau. Aufruf: python strip_arms.py <quelle.glb> <ziel.glb>"""
import io
import json
import struct
import sys

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
data = open(src, 'rb').read()
jlen = struct.unpack('<I', data[12:16])[0]
j = json.loads(data[20:20 + jlen])
bin_start = 20 + jlen + 8
blob = data[bin_start:bin_start + struct.unpack('<I', data[20 + jlen:24 + jlen])[0]]

# AK-Meshes von den Knoten loesen, nur Mesh 0 (Arme) und Material 0 (arms) behalten
for node in j['nodes']:
    if node.get('mesh', 0) != 0:
        del node['mesh']
j['meshes'] = j['meshes'][:1]
for prim in j['meshes'][0]['primitives']:
    assert prim.get('material', 0) == 0
j['materials'] = j['materials'][:1]
j['textures'] = j['textures'][:3]
j['images'] = j['images'][:3]

# Benutzte Accessoren sammeln (Arm-Mesh, Skin, Animation)
used_acc = set()
for prim in j['meshes'][0]['primitives']:
    used_acc.update(prim['attributes'].values())
    if 'indices' in prim:
        used_acc.add(prim['indices'])
    for target in prim.get('targets', []):
        used_acc.update(target.values())
for skin in j['skins']:
    if 'inverseBindMatrices' in skin:
        used_acc.add(skin['inverseBindMatrices'])
for anim in j['animations']:
    for s in anim['samplers']:
        used_acc.update((s['input'], s['output']))

# Neuer Binaerpuffer: benutzte Views der Accessoren plus verkleinerte Bilder
out = bytearray()
views = []
view_map = {}


def add_view(raw, target=None):
    while len(out) % 4:
        out.append(0)
    v = {'buffer': 0, 'byteOffset': len(out), 'byteLength': len(raw)}
    if target is not None:
        v['target'] = target
    out.extend(raw)
    views.append(v)
    return len(views) - 1


acc_map = {}
accessors = []
for i, acc in enumerate(j['accessors']):
    if i not in used_acc:
        continue
    bv = acc['bufferView']
    if bv not in view_map:
        old = j['bufferViews'][bv]
        off = old.get('byteOffset', 0)
        nv = add_view(blob[off:off + old['byteLength']], old.get('target'))
        if 'byteStride' in old:
            views[nv]['byteStride'] = old['byteStride']
        view_map[bv] = nv
    acc = dict(acc, bufferView=view_map[bv])
    acc_map[i] = len(accessors)
    accessors.append(acc)

base_color = j['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']
for i, im in enumerate(j['images']):
    old = j['bufferViews'][im['bufferView']]
    off = old.get('byteOffset', 0)
    img = Image.open(io.BytesIO(blob[off:off + old['byteLength']]))
    img = img.resize((1024, 1024), Image.LANCZOS)
    if i == j['textures'][base_color]['source']:
        # Grundfarbe grau und auf volle Helligkeit gestreckt: die Armfarbe kommt im Spiel aus dem Material
        gray = img.convert('L')
        hist = gray.histogram()
        top = next(v for v in range(256) if sum(hist[:v + 1]) >= 0.99 * sum(hist))
        img = gray.point(lambda v: min(255, v * 230 // max(top, 1))).convert('RGB')
    buf = io.BytesIO()
    img.save(buf, 'PNG', optimize=True)
    im['bufferView'] = add_view(buf.getvalue())

for prim in j['meshes'][0]['primitives']:
    prim['attributes'] = {k: acc_map[v] for k, v in prim['attributes'].items()}
    if 'indices' in prim:
        prim['indices'] = acc_map[prim['indices']]
    if 'targets' in prim:
        prim['targets'] = [{k: acc_map[v] for k, v in t.items()} for t in prim['targets']]
for skin in j['skins']:
    if 'inverseBindMatrices' in skin:
        skin['inverseBindMatrices'] = acc_map[skin['inverseBindMatrices']]
for anim in j['animations']:
    for s in anim['samplers']:
        s['input'], s['output'] = acc_map[s['input']], acc_map[s['output']]

j['accessors'] = accessors
j['bufferViews'] = views
j['buffers'] = [{'byteLength': len(out)}]
while len(out) % 4:
    out.append(0)
js = json.dumps(j, separators=(',', ':')).encode()
js += b' ' * (-len(js) % 4)
total = 12 + 8 + len(js) + 8 + len(out)
glb = struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(out), 0x004E4942) + out
open(dst, 'wb').write(glb)
tmax = max(acc['max'][0] for i, acc in enumerate(accessors) if 'max' in acc and acc['type'] == 'SCALAR' and acc['count'] > 1 and any(acc_map.get(s['input']) == i for a in j['animations'] for s in a['samplers']))
print(f'{dst}: {len(glb) / 1e6:.1f} MB, Animation bis {tmax:.2f} s ({tmax * 30:.0f} Frames)')
