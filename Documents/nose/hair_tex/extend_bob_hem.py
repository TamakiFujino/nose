"""現行ボブの実ガイド（guide_L.001 / guide_B.001）の裾を非破壊で下へ伸ばす。

build_bob_guides.py の再実行は不可（実ガイドは .001 系へ再構成済みで、再生成すると
別物の guide_L/B を作ってしまう）。そこで生きているグリッドメッシュの「落下部分
（末尾 N_FALL 行）」だけを列ごとに縦方向へ比例伸長する。X/Z は不変（巻き・タック・
分け目は維持）。後れ毛(make_surface_wisps.py)はグリッドを再サンプルするので、
このスクリプトの後に再実行すれば自動追従する。

実行: Blender -b faceapp.blend --python extend_bob_hem.py -- --save [--extend 0.035]
（負値で短縮。現在の裾からの相対量）
"""
import bpy
import sys

SAVE = '--save' in sys.argv
EXTEND = 0.035          # 裾を下げる量[m]（アプリ座標: +y=上）。負値=短くする
if '--extend' in sys.argv:
    EXTEND = float(sys.argv[sys.argv.index('--extend') + 1])
# (メッシュ名, 行数, 落下部分の行数) — build_bob_guides.py の構成と一致
GRIDS = [('guide_L.001', 17, 6), ('guide_B.001', 15, 6)]

for name, rows, n_fall in GRIDS:
    me = bpy.data.objects[name].data
    n_cols = len(me.vertices) // rows
    assert n_cols * rows == len(me.vertices), f'{name}: grid mismatch'
    ys_before = [v.co.y for v in me.vertices]
    for c in range(n_cols):
        col = [me.vertices[c * rows + r] for r in range(rows)]
        ear = col[rows - n_fall - 1].co.y          # 落下開始行（この上は不変）
        hem = col[rows - 1].co.y
        if hem >= ear - 1e-5:
            continue                               # 落下していない列は触らない
        k = (hem - EXTEND - ear) / (hem - ear)     # 伸長率（列ごと）
        for r in range(rows - n_fall, rows):
            v = col[r]
            v.co.y = ear + (v.co.y - ear) * k
    me.update()
    bpy.data.objects[name].update_tag()
    ys_after = [v.co.y for v in me.vertices]
    print(f'{name}: cols={n_cols} min_y {min(ys_before):.4f} -> {min(ys_after):.4f}')

if SAVE:
    bpy.ops.wm.save_mainfile()
    print('SAVED MAINFILE')
