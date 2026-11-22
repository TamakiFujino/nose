# Hair card atlas baker — procedural strand clumps rendered top-down with Cycles.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
#       --python bake_hair_atlas.py -- [--test] [--out DIR]
#
# Outputs (RES x RES):
#   hair_alpha.png    coverage (raw / Non-Color)
#   hair_roottip.png  0=root .. 1=tip gradient per strand (raw)
#   hair_id.png       per-strand random value (raw)
#   hair_normal.png   tangent-space normal, OpenGL +Y (raw)
#   hair_ao.png       ambient occlusion, white=open (raw)
#   hair_albedo.png   brown albedo composed from root+id (sRGB)
#   _preview_coverage.png
#   hair_atlas_bake.blend  the generated bake scene, for manual tweaks

import bpy
import math
import random
import sys
import os
import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
TEST = '--test' in argv
OUT = argv[argv.index('--out') + 1] if '--out' in argv else os.path.dirname(os.path.abspath(__file__))
RES = 512 if TEST else 2048
TMP = '/tmp/hairtex_passes'
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

random.seed(42)

# ---------------------------------------------------------------- strand gen
# Atlas space: x,y in [-0.5, 0.5], roots at top (y+), tips hang down.

def gen_clump(cx, width, n, length, r0, wander=0.3, freq=(1.5, 3.0),
              subclumps=0, cross=0.25, tip_drift=0.25, short_frac=0.15,
              arc=0.0, npts=28):
    """Returns list of (points, radii) for one column."""
    strands = []
    if subclumps > 0:
        subs = [(cx + (random.random() - 0.5) * width * 0.7,
                 random.uniform(0, 2 * math.pi)) for _ in range(subclumps)]
    for _ in range(n):
        if subclumps > 0:
            scx, scphase = random.choice(subs)
            x0 = scx + random.gauss(0, width * 0.07)
            phase = scphase + random.gauss(0, 0.8)
        else:
            x0 = cx + (random.random() - 0.5) * width * 0.92
            phase = random.uniform(0, 2 * math.pi)
        xm = cx + (random.random() - 0.5) * width * (1.0 + cross) + arc * width * 1.5
        xt = xm + random.gauss(0, width * tip_drift)
        y0 = 0.47 - abs(random.gauss(0, 0.018))
        # long-biased spread so tip density fades gradually instead of chopping off
        L = length * (0.60 + 0.40 * random.random() ** 0.6)
        if random.random() < short_frac:
            L *= random.uniform(0.45, 0.8)
        L = min(L, y0 + 0.49)
        amp = wander * width * random.uniform(0.5, 1.5)
        fq = random.uniform(*freq)
        rr = r0 * random.uniform(0.75, 1.3)
        z0 = random.uniform(0.0, 0.03)
        z1 = z0 + random.uniform(-0.012, 0.012)
        hw = width * 0.5 * 0.97
        dxs, ys, zs = [], [], []
        for j in range(npts):
            t = j / (npts - 1)
            x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * xm + t ** 2 * xt
            x += amp * t * t * math.sin(phase + fq * math.pi * t)
            dxs.append(x - cx)
            ys.append(y0 - L * t)
            zs.append(z0 + (z1 - z0) * t)
        # keep the strip UV-separable: shrink the whole lateral motion of
        # outliers instead of clamping (clamping piles strands on the edge)
        m = max(abs(d) for d in dxs)
        if m > hw:
            s = hw / m * random.uniform(0.88, 1.0)
            dxs = [d * s for d in dxs]
        pts, radii = [], []
        for j in range(npts):
            t = j / (npts - 1)
            pts.append((cx + dxs[j], ys[j], zs[j]))
            radii.append(max(rr * (1 - t) ** 0.6, 0.00012))
        strands.append((pts, radii))
    return strands


# column spec: (name, width, n, length, r0, extra kwargs)
COLS = [
    ('base_wide', 0.160, 520, 0.92, 0.0010, dict(wander=0.07, subclumps=0, cross=0.10, tip_drift=0.10)),
    ('main_wide', 0.150, 400, 0.90, 0.0010, dict(wander=0.14, subclumps=5, cross=0.15, tip_drift=0.14)),
    ('main_med',  0.120, 280, 0.88, 0.0009, dict(wander=0.18, subclumps=4, cross=0.15, tip_drift=0.15)),
    ('med_wavy',  0.110, 230, 0.85, 0.0009, dict(wander=0.85, freq=(1.3, 1.5), subclumps=3, cross=0.12, tip_drift=0.12)),
    ('narrow',    0.080, 150, 0.80, 0.0009, dict(wander=0.20, subclumps=2, cross=0.15, tip_drift=0.15)),
    ('thin_few',  0.055, 34,  0.75, 0.0008, dict(wander=0.40, subclumps=2, cross=0.3, short_frac=0.3)),
    ('wisp',      0.050, 11,  0.65, 0.0007, dict(wander=0.90, freq=(1.0, 1.8), cross=1.2, tip_drift=0.5, short_frac=0.4)),
    ('ahoge',     0.040, 3,   0.38, 0.0013, dict(wander=0.80, freq=(0.8, 1.2), arc=1.0, short_frac=0.0)),
]

GAP = (0.96 - sum(c[1] for c in COLS)) / (len(COLS) - 1)
strands = []
x = -0.48
for name, width, n, length, r0, kw in COLS:
    strands += gen_clump(x + width / 2, width, n, length, r0, **kw)
    x += width + GAP
print(f'strands total: {len(strands)}')

# ---------------------------------------------------------------- scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.render.resolution_x = RES
scene.render.resolution_y = RES
scene.render.film_transparent = True
scene.view_settings.view_transform = 'Standard'
scene.cycles.use_denoising = False
scene.cycles_curves.shape = 'THICK'   # 3D cylinder cross-section → real normals
scene.cycles_curves.subdivisions = 3
scene.render.image_settings.file_format = 'OPEN_EXR'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '16'

try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'METAL'
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    scene.cycles.device = 'GPU'
    print('cycles device: METAL GPU')
except Exception as e:
    print('GPU unavailable, CPU fallback:', e)

cam_data = bpy.data.cameras.new('bake_cam')
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 1.0
cam = bpy.data.objects.new('hair_bake_cam', cam_data)
cam.location = (0, 0, 1)
scene.collection.objects.link(cam)
scene.camera = cam

hc = bpy.data.hair_curves.new('bake_strands')
hc.add_curves([len(p) for p, _ in strands])
i = 0
for pts, radii in strands:
    for p, r in zip(pts, radii):
        pt = hc.points[i]
        pt.position = p
        pt.radius = r
        i += 1
obj = bpy.data.objects.new('bake_strands', hc)
scene.collection.objects.link(obj)

# ---------------------------------------------------------------- materials

def emission_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    return m, nt, em

mats = {}

m, nt, em = emission_mat('pass_white')
em.inputs['Color'].default_value = (1, 1, 1, 1)
mats['alpha'] = m

m, nt, em = emission_mat('pass_root')
hi = nt.nodes.new('ShaderNodeHairInfo')
nt.links.new(hi.outputs['Intercept'], em.inputs['Color'])
mats['root'] = m

m, nt, em = emission_mat('pass_id')
hi = nt.nodes.new('ShaderNodeHairInfo')
nt.links.new(hi.outputs['Random'], em.inputs['Color'])
mats['id'] = m

# camera is axis-aligned at +Z, so world normal == tangent-space (OpenGL +Y)
m, nt, em = emission_mat('pass_normal')
geo = nt.nodes.new('ShaderNodeNewGeometry')
vm = nt.nodes.new('ShaderNodeVectorMath')
vm.operation = 'MULTIPLY_ADD'
vm.inputs[1].default_value = (0.5, 0.5, 0.5)
vm.inputs[2].default_value = (0.5, 0.5, 0.5)
nt.links.new(geo.outputs['Normal'], vm.inputs[0])
nt.links.new(vm.outputs['Vector'], em.inputs['Color'])
mats['normal'] = m

m, nt, em = emission_mat('pass_ao')
ao = nt.nodes.new('ShaderNodeAmbientOcclusion')
ao.inputs['Distance'].default_value = 0.04
ao.samples = 16
nt.links.new(ao.outputs['Color'], em.inputs['Color'])
mats['ao'] = m

# ---------------------------------------------------------------- render passes
PASS_SAMPLES = {'alpha': 24, 'root': 24, 'id': 24, 'normal': 32, 'ao': 96}
if TEST:
    PASS_SAMPLES = {k: max(8, v // 3) for k, v in PASS_SAMPLES.items()}

exr = {}
for key in ['alpha', 'root', 'id', 'normal', 'ao']:
    obj.data.materials.clear()
    obj.data.materials.append(mats[key])
    scene.cycles.samples = PASS_SAMPLES[key]
    path = os.path.join(TMP, f'{key}.exr')
    scene.render.filepath = path
    print(f'render pass: {key} ({PASS_SAMPLES[key]} spp)')
    bpy.ops.render.render(write_still=True)
    exr[key] = path

# keep the editable scene (white material looks sane in viewport)
obj.data.materials.clear()
obj.data.materials.append(mats['alpha'])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'hair_atlas_bake.blend'))

# ---------------------------------------------------------------- numpy post

def load_exr(path):
    img = bpy.data.images.load(path)
    buf = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return buf.reshape(RES, RES, 4)


def unpremul(rgba):
    a = rgba[..., 3:4]
    rgb = rgba[..., :3] / np.maximum(a, 1e-6)
    return np.clip(rgb, 0, 1), np.clip(a[..., 0], 0, 1)


def dilate(data, mask, iters=16):
    """Push valid pixels outward into empty space (mip-bleed padding)."""
    out = data.copy()
    filled = mask.copy()
    for _ in range(iters):
        if filled.all():
            break
        new_out, new_filled = out.copy(), filled.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            s = np.roll(out, (dy, dx), (0, 1))
            sm = np.roll(filled, (dy, dx), (0, 1))
            take = (~new_filled) & sm
            new_out[take] = s[take]
            new_filled[take] = True
        out, filled = new_out, new_filled
    return out, filled


def save_png(name, rgb, alpha=None, srgb=False):
    """rgb: HxWx3 float. Raw values unless srgb=True (then linear→sRGB on save)."""
    img = bpy.data.images.new(name, RES, RES, alpha=True, float_buffer=True)
    img.colorspace_settings.name = 'sRGB' if srgb else 'Non-Color'
    a = alpha if alpha is not None else np.ones((RES, RES), np.float32)
    rgba = np.concatenate([rgb, a[..., None]], axis=-1).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(OUT, name)
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)
    print('wrote', os.path.join(OUT, name))


cov = np.clip(load_exr(exr['alpha'])[..., 3], 0, 1)
mask = cov > 0.02

root_rgb, _ = unpremul(load_exr(exr['root']))
id_rgb, _ = unpremul(load_exr(exr['id']))
nrm_rgb, _ = unpremul(load_exr(exr['normal']))
ao_rgb, _ = unpremul(load_exr(exr['ao']))

# renormalize AA-blended normals
n = nrm_rgb * 2 - 1
n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
nrm_rgb = n * 0.5 + 0.5

root_rgb, _ = dilate(root_rgb, mask)
id_rgb, _ = dilate(id_rgb, mask)
nrm_rgb, filled = dilate(nrm_rgb, mask)
ao_rgb, _ = dilate(ao_rgb, mask)

root_rgb[~filled] = 0.0
id_rgb[~filled] = 0.5
nrm_rgb[~filled] = (0.5, 0.5, 1.0)
ao_rgb[~filled] = 1.0

save_png('hair_alpha.png', np.repeat(cov[..., None], 3, -1), alpha=cov)
save_png('hair_roottip.png', root_rgb, alpha=cov)
save_png('hair_id.png', id_rgb, alpha=cov)
save_png('hair_normal.png', nrm_rgb, alpha=cov)
save_png('hair_ao.png', ao_rgb, alpha=cov)
save_png('_preview_coverage.png', np.repeat(cov[..., None], 3, -1))

# albedo (linear brown from root+id, saved as sRGB for the current app pipeline)
t = root_rgb[..., :1] ** 1.2
root_c = np.array([0.030, 0.016, 0.009], np.float32)
tip_c = np.array([0.140, 0.075, 0.042], np.float32)
alb = (root_c * (1 - t) + tip_c * t) * (0.80 + 0.45 * id_rgb[..., :1])
save_png('hair_albedo.png', alb.astype(np.float32), alpha=cov, srgb=True)

print('DONE')
