import bpy
import bmesh
import math
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

SAVE = '--save' in sys.argv

# hem heights + how far out the hem arc reaches (center -> temple)
VARIANTS = {
    'short': dict(hem=0.058, xh0=0.012, xh1=0.052),
    'mid':   dict(hem=0.045, xh0=0.014, xh1=0.056),
    'long':  dict(hem=0.002, xh0=0.022, xh1=0.065),   # swings wider, clears the nose
}
N_COLS = 7
N_ROWS = 9
SEAM_Z_MIN = -0.005    # roots: seam front end (z~0.045) back to just past crown front
CLEAR_ROOT = 0.002
CLEAR_TIP = 0.009

scalp = bpy.data.objects['scalp.001']
inv = scalp.matrix_world.inverted()

bm = bmesh.new()
for name in ['face', 'scalp.001', 'head']:
    o = bpy.data.objects.get(name)
    if not o:
        continue
    tmp = o.data.copy()
    tmp.transform(inv @ o.matrix_world)
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
bvh = BVHTree.FromBMesh(bm)
bm.free()


def surf_z(x, y, fallback):
    hit = bvh.ray_cast(Vector((x, y, 0.5)), Vector((0, 0, -1)), 1.0)
    return hit[0].z if hit[0] is not None else fallback


# seam roots: center-part line, front segment (same extraction as the side guides)
sbm = bmesh.new()
sbm.from_mesh(scalp.data)
boundary_v = set()
for e in sbm.edges:
    if len(e.link_faces) == 1:
        boundary_v.update(v for v in e.verts)
part = sorted({v.co.to_tuple() for v in boundary_v if abs(v.co.x) < 0.002},
              key=lambda c: -c[2])
part = [Vector(c) for c in part if c[2] >= SEAM_Z_MIN]
sbm.free()
lens = [0.0]
for a, b in zip(part, part[1:]):
    lens.append(lens[-1] + (b - a).length)
roots = []
for i in range(N_COLS):
    d = lens[-1] * i / (N_COLS - 1)
    for j in range(len(lens) - 1):
        if lens[j] <= d <= lens[j + 1]:
            f = (d - lens[j]) / max(lens[j + 1] - lens[j], 1e-9)
            roots.append(part[j].lerp(part[j + 1], f))
            break
    else:
        roots.append(part[-1].copy())
print('bangs seam roots z:', [round(r.z, 3) for r in roots])


def bang_columns(hem, xh0, xh1):
    cols = []
    for i, root in enumerate(roots):
        s = i / (N_COLS - 1)              # 0 = seam front (hairline), 1 = toward crown
        xh = xh0 + (xh1 - xh0) * s        # hem sweeps center -> temple
        pts = []
        for j in range(N_ROWS):
            t = j / (N_ROWS - 1)
            x = root.x + (xh - root.x) * (t ** 1.1)
            y = root.y + (hem - root.y) * (t ** 1.15)
            clear = CLEAR_ROOT + (CLEAR_TIP - CLEAR_ROOT) * t
            z = surf_z(x, y, (pts[-1].z - clear) if pts else 0.045) + clear
            if pts and z < pts[-1].z - 0.012:
                z = pts[-1].z - 0.012
            pts.append(Vector((x, y, z)))
        for _ in range(2):
            for j in range(1, len(pts) - 1):
                pts[j] = pts[j] * 0.5 + (pts[j - 1] + pts[j + 1]) * 0.25
        cols.append(pts)
    return cols


coll = bpy.data.collections.get('hair_guide_bangs')
if not coll:
    coll = bpy.data.collections.new('hair_guide_bangs')
    bpy.context.scene.collection.children.link(coll)


def make_grid_obj(name, cols, mirror_x=False):
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    rows = len(cols[0])
    m = bpy.data.meshes.new(name)
    verts = []
    for col in cols:
        for p in col:
            verts.append((-p.x, p.y, p.z) if mirror_x else p.to_tuple())
    faces = []
    for c in range(len(cols) - 1):
        for r in range(rows - 1):
            a = c * rows + r
            b = (c + 1) * rows + r
            q = (a, a + 1, b + 1, b)
            faces.append(tuple(reversed(q)) if mirror_x else q)
    m.from_pydata(verts, [], faces)
    m.validate()
    root_ids = {c * rows for c in range(len(cols))}
    for e in m.edges:
        if e.vertices[0] in root_ids and e.vertices[1] in root_ids:
            e.use_edge_sharp = True
    o = bpy.data.objects.new(name, m)
    coll.objects.link(o)
    o.matrix_world = scalp.matrix_world.copy()
    mat = bpy.data.materials.get('hair_card_mat')
    if mat:
        m.materials.append(mat)
    for p in m.polygons:
        p.use_smooth = True
    print(f'{name}: {len(m.vertices)} verts sharp={sum(1 for e in m.edges if e.use_edge_sharp)}')
    return o


for suffix, v in VARIANTS.items():
    cols = bang_columns(v['hem'], v['xh0'], v['xh1'])
    make_grid_obj(f'guide_F_{suffix}_R', cols)
    make_grid_obj(f'guide_F_{suffix}_L', cols, mirror_x=True)

# numeric sanity: all verts proud of the surface
bad = 0
total = 0
for suffix in VARIANTS:
    o = bpy.data.objects[f'guide_F_{suffix}_R']
    for vtx in o.data.vertices:
        s = surf_z(vtx.co.x, vtx.co.y, None)
        if s is not None:
            total += 1
            if vtx.co.z < s:
                bad += 1
print(f'proud check: {total - bad}/{total} verts in front of surface (bad={bad})')

if SAVE:
    bpy.ops.wm.save_mainfile()
    print('SAVED MAINFILE')
