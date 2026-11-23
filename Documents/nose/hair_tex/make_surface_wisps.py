import bpy
import bmesh
import math
import random
import sys
from mathutils import Vector

SAVE = '--save' in sys.argv
random.seed(11)

N_PTS = 16
TARGET_WIDTH = 0.009      # ~9mm card width for wisps (local = app meters)
HEAD_C = Vector((0.0, 0.03, -0.02))


def grid_cols(obj_name, rows):
    me = bpy.data.objects[obj_name].data
    cols = []
    n = len(me.vertices) // rows
    for c in range(n):
        cols.append([me.vertices[c * rows + r].co.copy() for r in range(rows)])
    return cols


def sample(cols, fc, fr):
    c0 = min(int(fc), len(cols) - 2)
    r0 = min(int(fr), len(cols[0]) - 2)
    cu, ru = fc - c0, fr - r0
    a = cols[c0][r0].lerp(cols[c0][r0 + 1], ru)
    b = cols[c0 + 1][r0].lerp(cols[c0 + 1][r0 + 1], ru)
    return a.lerp(b, cu)


def make_wisps(cols, count, mirror=False):
    rows = len(cols[0])
    strands = []
    for _ in range(count):
        fc = random.uniform(0.3, len(cols) - 1.3)
        # 60% root at the part line (crown wisps), 40% start mid-height (side/hem wisps)
        if random.random() < 0.6:
            r_start = random.uniform(0.0, 2.0)
        else:
            r_start = random.uniform(3.0, rows * 0.5)
        # 終端は裾近くまで必ず届かせる（下限55%だと中腹で切れる短い毛が混ざり、
        # メインの髪より明らかに短い浮き毛として悪目立ちする）
        r_end = random.uniform(rows * 0.82, rows - 1.05)
        floaty = 0.003 if random.random() < 0.22 else 0.0
        amp = random.uniform(0.003, 0.009)
        phase = random.uniform(0, 2 * math.pi)
        freq = random.uniform(1.0, 2.2)
        drift = random.uniform(-1.2, 1.2)   # crosses columns
        pts = []
        for j in range(N_PTS):
            t = j / (N_PTS - 1)
            fr = r_start + (r_end - r_start) * t
            fcc = min(max(fc + drift * t, 0.0), len(cols) - 1.001)
            p = sample(cols, fcc, fr)
            # local frame
            eps = 0.35
            tr = (sample(cols, fcc, min(fr + eps, rows - 1.001)) - p)
            tc = (sample(cols, min(fcc + eps, len(cols) - 1.001), fr) - p)
            nrm = tr.cross(tc)
            if nrm.length > 1e-9:
                nrm.normalize()
                if (p - HEAD_C).dot(nrm) < 0:
                    nrm = -nrm
            # monotonic: hug the hair until mid-length, then lift so TIPS stand clear
            off = 0.0010 + (0.0055 + floaty) * (t ** 1.4)
            lat = amp * t * math.sin(phase + freq * math.pi * t)
            tcn = tc.normalized() if tc.length > 1e-9 else Vector((1, 0, 0))
            q = p + nrm * off + tcn * lat
            pts.append(q)
        strands.append(pts)
        if mirror:
            strands.append([Vector((-q.x, q.y, q.z)) for q in pts])
    return strands


side = grid_cols('guide_L.001', 17)
back = grid_cols('guide_B.001', 15)
strands = make_wisps(side, 12, mirror=True) + make_wisps(back, 8, mirror=False)
print('wisp strands:', len(strands))

# profile clamps radius at 1.0 -> width tops out ~4.7mm (= nice wisp width,
# ~60% of the base cards). radius here is just the taper profile.
hc = bpy.data.hair_curves.new('surface_wisps')
hc.add_curves([N_PTS] * len(strands))
i = 0
for pts in strands:
    for j, p in enumerate(pts):
        t = j / (N_PTS - 1)
        pt = hc.points[i]
        pt.position = p
        pt.radius = max(0.55 * (1 - t) ** 0.5, 0.05)
        i += 1

# curve-domain attrs: UV box (thin_few=5 / wisp=6) + flags the profile may read
ba = hc.attributes.new('UV_Box_ID', 'INT', 'CURVE')
ba.data.foreach_set('value', [random.choice([5, 5, 6]) for _ in range(len(strands))])
fa = hc.attributes.new('Flip_x', 'BOOLEAN', 'CURVE')
fa.data.foreach_set('value', [False] * len(strands))
for aname, default in [('tilt', 0.0), ('roundness', 0.0), ('Factor', 1.0)]:
    a = hc.attributes.get(aname) or hc.attributes.new(aname, 'FLOAT', 'POINT')
    a.data.foreach_set('value', [default] * len(hc.points))

src = bpy.data.objects['guide_L.001_curve']
old = bpy.data.objects.get('surface_wisps')
if old:
    bpy.data.objects.remove(old, do_unlink=True)
wisp = src.copy()
wisp.data = hc
wisp.name = 'surface_wisps'
for m in list(wisp.modifiers):
    if 'Profile' not in m.name:
        wisp.modifiers.remove(m)
prof = wisp.modifiers[0]
prof.properties.inputs['Input_15']['value'] = bpy.data.objects['UV_Data']  # all 8 boxes
coll = bpy.data.collections['hair_guide_bob._centerpart']
coll.objects.link(wisp)
print('object ready:', wisp.name, '| mods:', [m.name for m in wisp.modifiers],
      '| uv:', prof.properties.inputs['Input_15']['value'].name)

# ---- width calibration: measure ribbon cross-edge, rescale radius ----
def measure_width():
    dg = bpy.context.evaluated_depsgraph_get()
    for inst in dg.object_instances:
        if inst.is_instance and inst.parent and inst.parent.original.name == 'surface_wisps' \
                and inst.object.type == 'MESH':
            me = inst.object.to_mesh()
            if not len(me.polygons):
                inst.object.to_mesh_clear()
                continue
            widths = []
            for p in list(me.polygons)[:400]:
                els = []
                vs = p.vertices
                for k in range(len(vs)):
                    a = me.vertices[vs[k]].co
                    b = me.vertices[vs[(k + 1) % len(vs)]].co
                    els.append((a - b).length)
                widths.append(min(els))
            n = (len(me.vertices), len(me.polygons))
            inst.object.to_mesh_clear()
            widths.sort()
            return widths[len(widths) // 2], n
    return None, None

w, geo = measure_width()
print(f'final width={w} geo={geo}')

if SAVE:
    bpy.ops.wm.save_mainfile()
    print('SAVED MAINFILE')
