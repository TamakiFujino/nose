# hair_tex — ヘアカード用アトラスとガイド生成スクリプト

face-app のカード髪（Hair Tool 4.x、`faceapp.blend`）のオフライン資産一式。
エクスポート側の手順は face-app の `.claude/skills/hair-cards-export` を参照。

## 座標系の規約

- アプリ座標 = `scalp.001` のローカル座標（= arkit_head ローカル。回転X+90°・
  スケール100・移動0）。**+y=上、+z=前、x=0=分け目シーム**、単位はほぼ実寸メートル。
- ランドマーク実測: 目中心 y=0.022 / まつ毛上 0.043 / 眉 ≈0.055 / 顎 -0.089 /
  おでこ前面 z≈0.054 / 鼻先 z=0.078 / 頭頂 y=0.130。
- ガイドはルート境界エッジを **Sharp マーク**（Hair Tool の Strands from Grid
  surface がルートとして要求）。全クアッド必須。

## アトラス

- `bake_hair_atlas.py` — 2048²・8列（base_wide/main_wide/main_med/med_wavy/
  narrow/thin_few/wisp/ahoge）を6マップ（alpha/roottip/id/normal/ao/albedo）に
  ベイク。`--test` で512px高速確認。列仕様は冒頭 `COLS`。
  - 法線はOpenGL +Y・カメラ軸=ワールド軸なのでワールド法線を直書き。
  - 列内に収める soft-clamp は「横振れ全体の縮小」方式（壁クランプは縁に毛が溜まる）。
- `write_uvboxes.py` — アルファ実範囲から Hair Tool 用 UVボックス8個を
  `UV_Data` メッシュ（UV_Matrix 等のPOINT属性）に書き込み。

## ガイド生成（いずれも `Blender -b faceapp.blend --python <script> -- --save`）

| スクリプト | 生成物 | 備考 |
|---|---|---|
| `build_bob_guides.py` | guide_R/L/B（ボブ、顎下丈） | サイド=分け目ルート横巻き、バック=方位角扇 |
| `build_length_variants.py` | guide_{R,L,B}_{med,long} | 肩つき/胸上。顎-6cmから首へ収束 |
| `build_bangs_guides.py` | guide_F_{short,mid,long}_{R,L} | カーテンバング（分け目ルート）。裾=眉上/眉下/目の下、xh0/xh1でスイープ調整 |
| `make_surface_wisps.py` | surface_wisps（実カーブ32本） | 後れ毛。本数/浮き/うねり/シードはスクリプト冒頭。実カーブなのでSculpt可 |

## 検証の鉄則

このファイルのヘッドレスプレビューレンダーは**信頼しない**（旧noseヘア資産の
写り込み・偽オクルージョンあり）。ガイドの妥当性は BVH レイキャスト／頂点比較の
数値検証で行い、見た目はユーザーのGUIビューポートで確認してもらう。

## バックアップ

`backup_pre_rebake_20261122/` は旧4列アトラス（2026-08版）。git管理外。
