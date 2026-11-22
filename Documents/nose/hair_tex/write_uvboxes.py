import bpy
import numpy as np
from mathutils import Matrix, Vector

RES = 2048
PAD = 3  # px padding around each column's content

# same layout as bake_hair_atlas.py COLS
widths = [0.160, 0.150, 0.120, 0.110, 0.080, 0.055, 0.050, 0.040]
names = ['base_wide', 'main_wide', 'main_med', 'med_wavy', 'narrow', 'thin_few', 'wisp', 'ahoge']
colors = [
    (0.20, 0.35, 0.90, 1.0), (0.15, 0.60, 0.95, 1.0), (0.10, 0.80, 0.70, 1.0),
    (0.20, 0.85, 0.20, 1.0), (0.95, 0.85, 0.10, 1.0), (0.95, 0.55, 0.10, 1.0),
    (0.95, 0.20, 0.20, 1.0), (0.90, 0.10, 0.90, 1.0),
]
gap = (0.96 - sum(widths)) / (len(widths) - 1)

# load alpha
img = bpy.data.images.get('hair_alpha.png') or bpy.data.images.load(
    '/Users/tamakifujino/Documents/nose/hair_tex/hair_alpha.png')
img.colorspace_settings.name = 'Non-Color'
buf = np.empty(img.size[0] * img.size[1] * 4, np.float32)
img.pixels.foreach_get(buf)
alpha = buf.reshape(RES, RES, 4)[..., 0]  # row 0 = bottom (V=0)

boxes = []
u = 0.02
for w, name in zip(widths, names):
    px0, px1 = int(u * RES), int((u + w) * RES)
    win = alpha[:, px0:px1] > 0.1
    rows = np.where(win.any(axis=1))[0]
    cols = np.where(win.any(axis=0))[0]
    v_min = max(rows.min() - PAD, 0) / RES
    v_max = min(rows.max() + PAD, RES - 1) / RES
    u_min = max(px0 + cols.min() - PAD, 0) / RES
    u_max = min(px0 + cols.max() + PAD, RES - 1) / RES
    boxes.append((name, [u_min, v_max], [u_max, v_min]))  # start=left-top(root), end=right-bottom(tip)
    print(f'{name}: U[{u_min:.3f},{u_max:.3f}] V[{v_min:.3f},{v_max:.3f}]')
    u += w + gap


def calc_uv_matrix(uv_start, uv_end):
    st = Vector((uv_start[0], uv_end[1]))
    en = Vector((uv_end[0], uv_start[1]))
    sx, sy = en.x - st.x, en.y - st.y
    return Matrix(((sx, 0, 0, st.x), (0, sy, 0, st.y), (0, 0, 1, 0), (0, 0, 0, 1)))


uv_owner = bpy.data.objects['UV_Data']
mesh = uv_owner.data
print('old box count:', len(mesh.vertices))
mesh.clear_geometry()
n = len(boxes)
mesh.vertices.add(n)
mesh.vertices.foreach_set('co', [0.0] * (3 * n))

mat_attr = mesh.attributes.new('UV_Matrix', 'FLOAT4X4', 'POINT')
for i, (_, st, en) in enumerate(boxes):
    mat_attr.data[i].value = calc_uv_matrix(st, en)

for aname, atype, values, key in [
    ('Offset_Root', 'FLOAT', [0.0] * n, 'value'),
    ('Offset_Tip', 'FLOAT', [0.0] * n, 'value'),
    ('Flip_y', 'BOOLEAN', [False] * n, 'value'),
]:
    attr = mesh.attributes.get(aname) or mesh.attributes.new(aname, atype, 'POINT')
    attr.data.foreach_set(key, values)

col_attr = mesh.attributes.get('Color') or mesh.attributes.new('Color', 'BYTE_COLOR', 'POINT')
col_attr.data.foreach_set('color', np.array(colors, np.float32).ravel())
mesh.update()

# verify the profile modifier still points at UV_Data
hair = bpy.data.objects['guide_R_hair']
prof = next(m for m in hair.modifiers if m.type == 'NODES' and 'Profile' in m.name)
try:
    print('profile uv owner:', prof['Input_15'].name)
except Exception as e:
    print('profile uv owner check skipped:', e)
print('new box count:', len(mesh.vertices))

bpy.ops.wm.save_mainfile()
print('UVBOXES SAVED')
