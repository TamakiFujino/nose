import bpy
import bmesh
import math
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

SAVE = '--save' in sys.argv

CHIN_Y = -0.089
VARIANTS = {
    'med':  dict(hem=-0.185, n_fall=9,  drift=0.30),   # shoulder-touching
    'long': dict(hem=-0.285, n_fall=13, drift=0.35),   # chest-length
}
DRIFT_SPAN = 0.060   # full convergence this far below the chin, then hold

scalp = bpy.data.objects['scalp.001']
bm = bmesh.new()
bm.from_mesh(scalp.data)
bvh = BVHTree.FromBMesh(bm)

boundary_v = set()
for e in bm.edges:
    if len(e.link_faces) == 1:
        boundary_v.update(v for v in e.verts)

N_COLS = 12
N_HUG = 10
THETA_END = math.radians(112)
SEAM_Z_MIN = -0.080
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


def smooth(pts, n=2):
    for _ in range(n):
        for j in range(1, len(pts) - 1):
            pts[j] = pts[j] * 0.5 + (pts[j - 1] + pts[j + 1]) * 0.25
    return pts


def fall_point(ear, axis_xz, s, hem, drift):
    """Drop from ear-level; converge toward the neck axis below the chin."""
    y = ear.y + (hem - ear.y) * s
    if y < CHIN_Y:
        f = min((CHIN_Y - y) / DRIFT_SPAN, 1.0)
        k = drift * (3 * f * f - 2 * f * f * f)          # smoothstep drift
    else:
        k = 0.0
    if s > 0.85:                                          # small tip tuck
        k += 0.06 * ((s - 0.85) / 0.15) ** 2
    x = ear.x + (axis_xz.x - ear.x) * k
    z = ear.z + (axis_xz.y - ear.z) * k
    return Vector((x, y, z))


def side_columns(hem, n_fall, drift):
    cols = []
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
        axis = Vector((ear.x * 0.35, ear.z))   # converge toward the neck, keep z
        for i in range(1, n_fall + 1):
            pts.append(fall_point(ear, axis, i / n_fall, hem, drift))
        cols.append(smooth(pts))
    return cols


N_AZ = 14
AZ_START = math.radians(16)
AZ_END = math.radians(164)
B_HUG = 9
TH_START = math.radians(24)
TH_END = math.radians(102)
B_OFF_ROOT = 0.003
PIVOT = Vector((0.0, 0.060, -0.040))


def back_columns(hem, n_fall, drift):
    cols = []
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
        axis = Vector((ear.x * 0.35, -0.055))  # neck center-ish behind
        for i in range(1, n_fall + 1):
            pts.append(fall_point(ear, axis, i / n_fall, hem, drift))
        cols.append(smooth(pts))
    return cols


bm.free()

coll = bpy.data.collections.get('guides_length_variants')
if not coll:
    coll = bpy.data.collections.new('guides_length_variants')
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
    print(f'{name}: verts={len(m.vertices)} quads={len(m.polygons)} sharp={sum(1 for e in m.edges if e.use_edge_sharp)}')
    return o


made = []
for suffix, v in VARIANTS.items():
    sc = side_columns(v['hem'], v['n_fall'], v['drift'])
    bc = back_columns(v['hem'], v['n_fall'], v['drift'])
    made.append(make_grid_obj(f'guide_R_{suffix}', sc))
    made.append(make_grid_obj(f'guide_L_{suffix}', sc, mirror_x=True))
    made.append(make_grid_obj(f'guide_B_{suffix}', bc))

if SAVE:
    # keep the variants out of the way until used
    lc = bpy.context.view_layer.layer_collection.children.get('guides_length_variants')
    if lc:
        lc.hide_viewport = True
    bpy.ops.wm.save_mainfile()
    print('SAVED MAINFILE')
    sys.exit(0)

# previews
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'OBJECT'
scalp.color = (0.3, 0.45, 0.85, 1.0)
for o in made:
    if o.name.endswith('_med'):
        o.color = (0.9, 0.55, 0.15, 1.0)
    else:
        o.color = (0.8, 0.2, 0.3, 1.0)
scene.render.resolution_x = 600
scene.render.resolution_y = 1000
scene.render.image_settings.file_format = 'PNG'
cam_data = bpy.data.cameras.new('_pv')
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 55
cam = bpy.data.objects.new('_pv_cam', cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
for variant in ['med', 'long']:
    show = {f'guide_R_{variant}', f'guide_L_{variant}', f'guide_B_{variant}',
            'scalp.001', 'head', 'face', 'ears'}
    for o in bpy.data.objects:
        o.hide_render = o.name not in show
    for name, loc, rot in [('front', (0, -60, -8), (math.pi / 2, 0, 0)),
                           ('side', (60, 4, -8), (math.pi / 2, 0, math.pi / 2))]:
        cam.location = loc
        cam.rotation_euler = rot
        scene.render.filepath = f'/tmp/glen_{variant}_{name}.png'
        bpy.ops.render.render(write_still=True)
print('VARIANTS DONE')
