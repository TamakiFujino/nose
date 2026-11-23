import bpy
import bmesh
import math
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

SAVE = '--save' in sys.argv

scalp = bpy.data.objects['scalp.001']
bm = bmesh.new()
bm.from_mesh(scalp.data)
bvh = BVHTree.FromBMesh(bm)

boundary_v = set()
for e in bm.edges:
    if len(e.link_faces) == 1:
        boundary_v.update(v for v in e.verts)

# ---------------- side columns (guide_R), seam extended further back ----------------
N_COLS = 12
N_HUG = 10
N_FALL = 6
THETA_END = math.radians(112)
SEAM_Z_MIN = -0.080
HEM_Y = -0.098
TUCK = 0.12
OFF_ROOT = 0.006
OFF_EAR = 0.020
PIVOT_DROP = 0.050

part = sorted({v.co.to_tuple() for v in boundary_v if abs(v.co.x) < 0.002},
              key=lambda c: -c[2])
part = [Vector(c) for c in part if c[2] >= SEAM_Z_MIN]
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

side_cols = []
for root in roots:
    pivot = Vector((0.0, root.y - PIVOT_DROP, root.z))
    pts = [root.copy()]
    last_r = (root - pivot).length
    for i in range(1, N_HUG + 1):
        th = THETA_END * i / N_HUG
        d = Vector((math.sin(th), math.cos(th), 0.0))
        hit = bvh.ray_cast(pivot + d * 0.5, -d, 1.0)
        if hit[0] is not None and (hit[0] - pivot).dot(d) > 0.01:
            last_r = (hit[0] - pivot).length
        off = OFF_ROOT + (OFF_EAR - OFF_ROOT) * (i / N_HUG) ** 1.2
        pts.append(pivot + d * (last_r + off))
    ear = pts[-1]
    for i in range(1, N_FALL + 1):
        s = i / N_FALL
        y = ear.y + (HEM_Y - ear.y) * s
        tuck = TUCK * max(0.0, (s - 0.6) / 0.4) ** 2
        pts.append(Vector((ear.x * (1 - tuck), y, ear.z)))
    for _ in range(2):
        for j in range(1, len(pts) - 1):
            pts[j] = pts[j] * 0.5 + (pts[j - 1] + pts[j + 1]) * 0.25
    side_cols.append(pts)

# ---------------- back fan (guide_B), roots lower + hugging ----------------
N_AZ = 14
AZ_START = math.radians(16)
AZ_END = math.radians(164)
B_HUG = 9
TH_START = math.radians(24)   # below the crown silhouette (was 7deg -> visible ring)
TH_END = math.radians(102)
B_FALL = 6
B_OFF_ROOT = 0.003            # hug the scalp at the root ring
PIVOT = Vector((0.0, 0.060, -0.040))

back_cols = []
for ci in range(N_AZ):
    phi = AZ_START + (AZ_END - AZ_START) * ci / (N_AZ - 1)
    cph, sph = math.cos(phi), math.sin(phi)
    pts = []
    last_r = 0.09
    for i in range(B_HUG):
        th = TH_START + (TH_END - TH_START) * i / (B_HUG - 1)
        d = Vector((math.sin(th) * cph, math.cos(th), -math.sin(th) * sph))
        hit = bvh.ray_cast(PIVOT + d * 0.5, -d, 1.0)
        if hit[0] is not None and (hit[0] - PIVOT).dot(d) > 0.01:
            last_r = (hit[0] - PIVOT).length
        off = B_OFF_ROOT + (OFF_EAR - B_OFF_ROOT) * (i / (B_HUG - 1)) ** 1.2
        pts.append(PIVOT + d * (last_r + off))
    ear = pts[-1]
    axis = Vector((0.0, 0.0, -0.045))
    for i in range(1, B_FALL + 1):
        s = i / B_FALL
        y = ear.y + (HEM_Y - ear.y) * s
        tuck = TUCK * max(0.0, (s - 0.6) / 0.4) ** 2
        pts.append(Vector((ear.x + (axis.x - ear.x) * tuck, y, ear.z + (axis.z - ear.z) * tuck)))
    for _ in range(2):
        for j in range(1, len(pts) - 1):
            pts[j] = pts[j] * 0.5 + (pts[j - 1] + pts[j + 1]) * 0.25
    back_cols.append(pts)
bm.free()


def replace_grid(obj_name, cols, mirror_x=False):
    obj = bpy.data.objects[obj_name]
    m = obj.data
    rows = len(cols[0])
    verts = []
    for col in cols:
        for p in col:
            verts.append((-p.x, p.y, p.z) if mirror_x else (p.x, p.y, p.z))
    faces = []
    for c in range(len(cols) - 1):
        for r in range(rows - 1):
            a = c * rows + r
            b = (c + 1) * rows + r
            q = (a, a + 1, b + 1, b)
            faces.append(tuple(reversed(q)) if mirror_x else q)
    m.clear_geometry()
    m.from_pydata(verts, [], faces)
    m.validate()
    root_ids = {c * rows for c in range(len(cols))}
    for e in m.edges:
        if e.vertices[0] in root_ids and e.vertices[1] in root_ids:
            e.use_edge_sharp = True
    for p in m.polygons:
        p.use_smooth = True
    m.update()
    obj.update_tag()
    print(f'{obj_name}: rebuilt {len(m.vertices)} verts, sharp={sum(1 for e in m.edges if e.use_edge_sharp)}')


replace_grid('guide_R', side_cols)
replace_grid('guide_L', side_cols, mirror_x=True)
replace_grid('guide_B', back_cols)

# ---------------- coverage check: union of 3 shells vs scalp ----------------
bmu = bmesh.new()
for name in ['guide_R', 'guide_L', 'guide_B']:
    bmu.from_mesh(bpy.data.objects[name].data)
union = BVHTree.FromBMesh(bmu)
bm2 = bmesh.new()
bm2.from_mesh(scalp.data)
sc = BVHTree.FromBMesh(bm2)
miss = sub = tot = 0
C = Vector((0.0, 0.055, -0.03))
for ti in range(14):
    th = math.radians(6 + ti * 7)
    for pi in range(36):
        phi = math.radians(2.5 + pi * 10)  # all around, avoid exact seam plane
        d = Vector((math.sin(th) * math.cos(phi), math.cos(th), -math.sin(th) * math.sin(phi)))
        hs = union.ray_cast(C + d * 0.5, -d, 0.6)
        hc = sc.ray_cast(C + d * 0.5, -d, 0.6)
        if hc[0]:
            tot += 1
            if not hs[0]:
                miss += 1
            elif (hs[0] - C).length < (hc[0] - C).length:
                sub += 1
print(f'coverage: scalp dirs={tot} shell_missing={miss} submerged={sub}')

if SAVE:
    bpy.ops.wm.save_mainfile()
    print('SAVED MAINFILE')
