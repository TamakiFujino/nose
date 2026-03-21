# Blender scripts for Nose Unity pipeline

## Vertex Groups → Packed Region Mask Textures

**Script:** `vertex_groups_to_region_mask_textures.py`

Generates four packed RGBA PNG textures from the active mesh UVs:

- `RegionMaskPack0.png` = regions `1-4` in `RGBA`
- `RegionMaskPack1.png` = regions `5-8` in `RGBA`
- `RegionMaskPack2.png` = regions `9-12` in `RGBA`
- `RegionMaskPack3.png` = regions `13-16` in `RGBA` (`13-14` currently used)

This is the recommended path for clean mask boundaries in Unity because each region gets its own texture channel instead of being encoded as a single interpolated numeric vertex ID.

### Requirements

- Save the `.blend` file first. The script exports PNGs next to the blend file.
- The mesh must have an active UV map.
- Vertex group names must match `Assets/Scripts/AssetManager.cs` region names exactly.

### How to run

1. Select the body mesh object.
2. Open the **Scripting** workspace.
3. Open `vertex_groups_to_region_mask_textures.py`.
4. Click **Run Script**.

After the first run, you can also press **F3** and run **`Vertex Groups to Region Mask Textures`** again.

### Unity setup

1. Import the generated `RegionMaskPack0.png` to `RegionMaskPack3.png`.
2. Set each texture to **Non-Color** in Unity import settings.
3. On the body material using **`Nose/Body Region Mask`**:
   - Enable **`Use Region Mask Textures`**
   - Assign the four pack textures
4. Or assign the same four textures on **`AssetManager`** using:
   - `Body Region Mask Pack 0`
   - `Body Region Mask Pack 1`
   - `Body Region Mask Pack 2`
   - `Body Region Mask Pack 3`
   - `Use Region Mask Textures`

`RegionMaskConfig` and `_RegionHideMask` still work as before; only the region source changes from vertex color to packed textures.

## Vertex Groups → Region Mask

**Script:** `vertex_groups_to_region_mask.py`

Converts Blender **vertex groups** into the **Region Mask** Color Attribute used by the Unity shader `Nose/Body Region Mask`. Vertex group names are matched to region IDs defined in `Assets/Scripts/AssetManager.cs` (`regionDefs`).

### Requirements

- Name vertex groups exactly like the Unity region names (e.g. `chest`, `shoulder`, `upperarm_l`). Matching is case-insensitive.
- Vertices can be in multiple groups; the group with the **highest weight** for that vertex wins. Vertices in no matching group get region ID `0` (never hidden).

### How to run

**Option A: Run once (Scripting workspace)**

1. Select the body mesh object.
2. Open the **Scripting** workspace.
3. Open `vertex_groups_to_region_mask.py` in the Text Editor (or paste its contents).
4. Click **Run Script**.

**Option B:** After running the script once, the operator is registered for the session. Press **F3** (or Space) and search for **"Vertex Groups to Region Mask"** to run it again without re-opening the script.

### Customizing region names/IDs

Edit the `REGION_NAME_TO_ID` dictionary at the top of the script so it matches your `AssetManager.regionDefs` in Unity. If you add or rename regions in Unity, update this dict and re-run the script.

### Result

- Creates or updates a vertex Color Attribute named **`RegionMask`** (configurable via the operator’s property).
- Red channel = `region_id / 255`; G, B = 0. Export the mesh with **Vertex Colors** enabled so Unity receives it; the body material must use the **Nose/Body Region Mask** shader.
- This path is kept mainly for debugging / fallback. Prefer the packed texture workflow above for cleaner boundaries.
