# Addressables Pipeline (Blender → Unity → Firebase Hosting)

## 1) Export each asset from Blender
- Units: Metric, Unit Scale 1.0. Apply transforms (Ctrl+A → Rotation & Scale; location to origin if needed).
- Orientation: Forward = -Z, Up = +Y in FBX export. Keep scale at 1.0.
- Armature: one root armature, clean bone names (no `.001`), T-pose/bind pose on frame 0, no stray animation on export frame.
- Mesh cleanup: remove unused vertex colors unless needed; ensure correct UVs and normals (Auto Smooth as required).
- Materials/textures: keep material slot names stable; pack or reference texture files you plan to import.
- Export: FBX, Apply Transform ON, “Only Selected Objects”, include Armature + Mesh, Bake Animation OFF for static meshes unless you need clips.

## 2) Import each asset into Unity
- Put FBX and related textures into `nose-unity/Assets/Models/` (or the same folder path they originated from) so existing `.meta` files and GUID references stay valid.
- In Inspector (Model tab):
  - Scale Factor 1.0, Preserve Hierarchy ON.
  - Rig: Animation Type = Humanoid for character bodies; Avatar Definition = Create From This Model.
  - Materials: keep naming consistent; if you replaced files, reassign any missing materials.
- Do not delete the source FBX after import—Unity needs the file to keep references valid.

## 3) Create prefabs and add to Addressables
- Instantiate the imported model in a scene, set materials, colliders, LODs as needed, then drag it into a Prefabs folder to create a prefab.
- Select the prefab, check “Addressable”, and give it a stable address (e.g., `catalog/body/base_female`).
- Assign the prefab to the remote Addressables group used for delivery (default remote group under Addressables Groups).

## 4) Build Addressables and deploy to Firebase Hosting
- Build Addressables: `Window → Asset Management → Addressables → Groups → Build → New Build → Default Build Script`. Output goes to `nose-unity/ServerData/iOS/`.
- Deploy: from repo root run `./scripts/deploy_addressables.sh` and choose dev/staging/both. The script:
  - Copies `nose-unity/ServerData/iOS/` to `hosting/<env>/addressables/iOS/`.
  - Optionally runs `firebase deploy --only hosting:<env>` using FirebaseConfig settings (targets dev→`nose-a2309`, staging→`nose-staging`).
- Runtime load path: defaults to `https://nose-a2309.web.app/addressables/[BuildTarget]` (see Addressables profile). Catalog URL can also be overridden via `Config.plist` `AddressablesCatalogURL`.

## 5) Common pitfalls
- If you delete/move the source FBX after import, Unity loses the asset (broken GUID). Keep the FBX in place or restore from git/backup in the same path.
- Changing bone names or hierarchy can break animations/clothing bindings—keep rig structure stable unless you update all dependent assets.
- After replacing assets, rebuild Addressables and redeploy to ensure Hosting serves the new bundles/catalog.




