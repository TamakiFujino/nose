using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public class BatchThumbnailGeneratorWindow : EditorWindow
{
    private int thumbnailSize = 512;
    private float paddingFactor = 1.3f;
    private bool overwriteExisting = true;
    private string outputFolder = "Assets/Thumbnails";

    [MenuItem("Tools/Nose/Batch Generate Thumbnails (Appearance)")]
    private static void Open()
    {
        GetWindow<BatchThumbnailGeneratorWindow>("Generate Thumbnails");
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Batch Appearance Thumbnail Generator", EditorStyles.boldLabel);
        EditorGUILayout.HelpBox(
            "Generates PNG thumbnails for appearance prefabs (clothes, hair, accessories, eyes, eyebrows).\n" +
            "Open SampleScene first. Requires a ThumbnailCamera in the scene.\n" +
            "For pose thumbnails use Tools > Nose > Batch Generate Pose Thumbnails.",
            MessageType.Info);

        thumbnailSize = EditorGUILayout.IntField("Thumbnail Size (px)", thumbnailSize);
        thumbnailSize = Mathf.Clamp(thumbnailSize, 64, 2048);

        paddingFactor = EditorGUILayout.Slider("Padding Factor", paddingFactor, 1.0f, 2.0f);
        overwriteExisting = EditorGUILayout.ToggleLeft("Overwrite existing thumbnails", overwriteExisting);
        outputFolder = EditorGUILayout.TextField("Output Folder", outputFolder);

        EditorGUILayout.Space();
        if (GUILayout.Button("Generate Thumbnails"))
        {
            GenerateAll();
        }
    }

    private void GenerateAll()
    {
        // Discover scene references
        var assetManager = Object.FindObjectOfType<AssetManager>();
        if (assetManager == null || assetManager.avatarRoot == null)
        {
            EditorUtility.DisplayDialog("Thumbnail Generator", "AssetManager or avatarRoot not found. Open SampleScene first.", "OK");
            return;
        }

        var thumbCamGO = GameObject.Find("ThumbnailCamera");
        if (thumbCamGO == null)
        {
            EditorUtility.DisplayDialog("Thumbnail Generator", "ThumbnailCamera not found in scene.", "OK");
            return;
        }
        var cam = thumbCamGO.GetComponent<Camera>();
        if (cam == null)
        {
            EditorUtility.DisplayDialog("Thumbnail Generator", "ThumbnailCamera has no Camera component.", "OK");
            return;
        }

        var avatarRoot = assetManager.avatarRoot;
        var bodySmr = assetManager.bodySkinnedMesh;
        if (bodySmr == null)
            bodySmr = GetBodySkinnedMesh(avatarRoot);

        // Collect appearance prefabs (everything except Base/Body poses)
        var guids = AssetDatabase.FindAssets("t:Prefab", new[] { "Assets/Models" });
        var appearancePrefabs = new List<string>();

        foreach (var guid in guids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (!path.StartsWith("Assets/Models/Base/Body/"))
                appearancePrefabs.Add(path);
        }
        appearancePrefabs.Sort();

        int total = appearancePrefabs.Count;

        if (total == 0)
        {
            EditorUtility.DisplayDialog("Thumbnail Generator", "No prefabs found to process.", "OK");
            return;
        }

        int generated = 0;
        int skipped = 0;
        int errors = 0;
        int index = 0;

        try
        {
            // Build bone map once for rebinding
            var skeletonRoot = GetSkeletonRoot(avatarRoot, bodySmr);
            var boneMap = BuildBoneMap(skeletonRoot);
            var bodyRootBone = skeletonRoot;

            // Process appearance prefabs (two-pass: measure bounds, then render)
            {
                // Group prefabs by subcategory (e.g. "Clothes/Tops", "Hair/Front")
                var subcategoryGroups = new Dictionary<string, List<string>>();
                foreach (var prefabPath in appearancePrefabs)
                {
                    string subKey = GetSubcategoryKey(prefabPath);
                    if (!subcategoryGroups.ContainsKey(subKey))
                        subcategoryGroups[subKey] = new List<string>();
                    subcategoryGroups[subKey].Add(prefabPath);
                }

                // Pass 1: compute union bounds per subcategory
                var subcategoryBounds = new Dictionary<string, Bounds>();
                foreach (var kvp in subcategoryGroups)
                {
                    string subKey = kvp.Key;
                    EditorUtility.DisplayProgressBar("Measuring Bounds", subKey, (float)index / total);

                    foreach (var prefabPath in kvp.Value)
                    {
                        Bounds? itemBounds = MeasureItemBounds(prefabPath, avatarRoot, boneMap, bodyRootBone);
                        if (!itemBounds.HasValue) continue;

                        if (subcategoryBounds.ContainsKey(subKey))
                        {
                            var existing = subcategoryBounds[subKey];
                            existing.Encapsulate(itemBounds.Value);
                            subcategoryBounds[subKey] = existing;
                        }
                        else
                        {
                            subcategoryBounds[subKey] = itemBounds.Value;
                        }
                    }
                }

                // Pass 2: render each item using the shared subcategory bounds
                foreach (var kvp in subcategoryGroups)
                {
                    string subKey = kvp.Key;
                    Bounds framingBounds;
                    if (!subcategoryBounds.TryGetValue(subKey, out framingBounds))
                        continue;

                    foreach (var prefabPath in kvp.Value)
                    {
                        float progress = (float)index / total;
                        if (EditorUtility.DisplayCancelableProgressBar("Generating Thumbnails", prefabPath, progress))
                            goto done;
                        index++;

                        string pngPath = PrefabPathToOutputPath(prefabPath);
                        if (!overwriteExisting && File.Exists(pngPath))
                        {
                            skipped++;
                            continue;
                        }

                        if (GenerateAppearanceThumbnail(prefabPath, cam, avatarRoot, boneMap, bodyRootBone, framingBounds, pngPath))
                            generated++;
                        else
                            errors++;
                    }
                }
            }
            done:;
        }
        finally
        {
            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
        }

        Debug.Log($"[ThumbnailGenerator] Generated: {generated}, Skipped: {skipped}, Errors: {errors}");
        EditorUtility.DisplayDialog("Thumbnail Generator",
            $"Generated: {generated}\nSkipped: {skipped}\nErrors: {errors}", "OK");
    }

    // ── Appearance Thumbnails ────────────────────────────────────────

    /// <summary>
    /// Pass 1 helper: instantiate item, compute its bounds, destroy it.
    /// </summary>
    private Bounds? MeasureItemBounds(string prefabPath, Transform avatarRoot,
        Dictionary<string, Transform> boneMap, Transform bodyRootBone)
    {
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
        if (prefab == null) return null;

        var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
        if (instance == null) return null;

        try
        {
            instance.transform.SetParent(avatarRoot, false);
            instance.transform.localPosition = Vector3.zero;
            instance.transform.localRotation = Quaternion.identity;
            instance.transform.localScale = Vector3.one;
            RebindSkinnedMeshesToBody(instance, boneMap, bodyRootBone);

            var renderers = instance.GetComponentsInChildren<Renderer>(true);
            if (renderers == null || renderers.Length == 0) return null;
            return ComputeBounds(renderers);
        }
        finally
        {
            Object.DestroyImmediate(instance);
        }
    }

    /// <summary>
    /// Pass 2: render a single item using shared subcategory bounds for framing.
    /// </summary>
    private bool GenerateAppearanceThumbnail(string prefabPath, Camera cam, Transform avatarRoot,
        Dictionary<string, Transform> boneMap, Transform bodyRootBone,
        Bounds framingBounds, string pngPath)
    {
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
        if (prefab == null)
        {
            Debug.LogWarning($"[ThumbnailGenerator] Could not load prefab: {prefabPath}");
            return false;
        }

        var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
        if (instance == null)
        {
            Debug.LogWarning($"[ThumbnailGenerator] Could not instantiate: {prefabPath}");
            return false;
        }

        try
        {
            instance.transform.SetParent(avatarRoot, false);
            instance.transform.localPosition = Vector3.zero;
            instance.transform.localRotation = Quaternion.identity;
            instance.transform.localScale = Vector3.one;

            SetLayerRecursively(instance, avatarRoot.gameObject.layer);
            RebindSkinnedMeshesToBody(instance, boneMap, bodyRootBone);

            // Collect the item's own renderers before hiding everything else
            var itemRendererSet = new HashSet<Renderer>(instance.GetComponentsInChildren<Renderer>(true));
            if (itemRendererSet.Count == 0) return false;

            // Hide ALL scene renderers except the item's
            var hiddenRenderers = new List<Renderer>();
            foreach (var r in Object.FindObjectsOfType<Renderer>(true))
            {
                if (r == null || !r.enabled) continue;
                if (itemRendererSet.Contains(r)) continue;
                r.enabled = false;
                hiddenRenderers.Add(r);
            }

            try
            {
                // Frame using the shared subcategory bounds (consistent across all items)
                FrameCamera(cam, framingBounds);
                return RenderToPNG(cam, pngPath);
            }
            finally
            {
                foreach (var r in hiddenRenderers)
                {
                    if (r != null) r.enabled = true;
                }
            }
        }
        finally
        {
            Object.DestroyImmediate(instance);
        }
    }

    // ── Bone Rebinding (ported from AssetManager.cs:264-316) ────────

    private void RebindSkinnedMeshesToBody(GameObject instance,
        Dictionary<string, Transform> bodyBoneMap, Transform bodyRootBone)
    {
        if (instance == null) return;

        // Disable any animators on the item prefab
        foreach (var anim in instance.GetComponentsInChildren<Animator>(true))
            anim.enabled = false;

        foreach (var smr in instance.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (smr == null) continue;

            // Root bone
            Transform mappedRoot = null;
            if (smr.rootBone != null)
                bodyBoneMap.TryGetValue(smr.rootBone.name, out mappedRoot);
            smr.rootBone = mappedRoot != null ? mappedRoot : bodyRootBone;

            // Bones array
            var bones = smr.bones;
            if (bones != null && bones.Length > 0)
            {
                var newBones = new Transform[bones.Length];
                for (int i = 0; i < bones.Length; i++)
                {
                    var source = bones[i];
                    Transform replacement;
                    if (source != null && bodyBoneMap.TryGetValue(source.name, out replacement))
                        newBones[i] = replacement;
                    else
                        newBones[i] = bodyRootBone;
                }
                smr.bones = newBones;
            }

            smr.updateWhenOffscreen = true;
        }
    }

    // ── Camera Framing (ported from UnityBridge.cs:976-1010) ────────

    private void FrameCamera(Camera cam, Bounds bounds)
    {
        // Save/restore handled by caller via RenderToPNG
        Vector3 center = bounds.center;
        float height = Mathf.Max(0.01f, bounds.size.y) * paddingFactor;
        float width = Mathf.Max(0.01f, bounds.size.x) * paddingFactor;
        float depth = Mathf.Max(0.01f, bounds.size.z) * paddingFactor;

        // Force square aspect for thumbnails
        cam.aspect = 1f;

        if (cam.orthographic)
        {
            float orthoForHeight = height * 0.5f;
            float orthoForWidth = width * 0.5f; // aspect is 1:1
            cam.orthographicSize = Mathf.Max(orthoForHeight, orthoForWidth);
        }

        // Position camera in front of the bounds
        float safeDistance = Mathf.Max(height, width, depth) * 2f;
        Vector3 forward = cam.transform.forward.sqrMagnitude > 0.0001f ? cam.transform.forward : Vector3.forward;
        cam.transform.position = center - forward.normalized * safeDistance;
        cam.transform.LookAt(center);
        cam.nearClipPlane = Mathf.Min(cam.nearClipPlane, 0.01f);
    }

    // ── Render-to-PNG (ported from UnityBridge.cs:747-891) ──────────

    private bool RenderToPNG(Camera cam, string pngPath)
    {
        // Save camera state
        var prevRT = RenderTexture.active;
        var prevCamRT = cam.targetTexture;
        var prevCamRect = cam.rect;
        bool prevEnabled = cam.enabled;
        var prevClear = cam.clearFlags;
        var prevBG = cam.backgroundColor;
        float prevOrthoSize = cam.orthographic ? cam.orthographicSize : 0f;
        float prevAspect = cam.aspect;
        int prevCullingMask = cam.cullingMask;
        Vector3 prevPos = cam.transform.position;
        Quaternion prevRot = cam.transform.rotation;
        float prevNearClip = cam.nearClipPlane;

        int size = thumbnailSize;
        RenderTexture rt = RenderTexture.GetTemporary(size, size, 24, RenderTextureFormat.ARGB32);

        try
        {
            cam.enabled = false; // don't render to screen
            cam.cullingMask = -1; // all layers
            cam.rect = new Rect(0f, 0f, 1f, 1f);

            // Transparent background
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0f, 0f, 0f, 0f);

            cam.targetTexture = rt;
            cam.Render();

            RenderTexture.active = rt;
            Texture2D tex = new Texture2D(size, size, TextureFormat.RGBA32, false);
            tex.ReadPixels(new Rect(0, 0, size, size), 0, 0, false);
            tex.Apply(false, false);

            // Fix alpha for URP opaque shaders that don't write alpha
            var pixels = tex.GetPixels32();
            for (int i = 0; i < pixels.Length; i++)
            {
                if (pixels[i].r > 0 || pixels[i].g > 0 || pixels[i].b > 0)
                    pixels[i].a = 255;
            }
            tex.SetPixels32(pixels);
            tex.Apply(false, false);

            byte[] png = ImageConversion.EncodeToPNG(tex);
            Object.DestroyImmediate(tex);

            // Ensure output directory exists
            string dir = Path.GetDirectoryName(pngPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            File.WriteAllBytes(pngPath, png);
            Debug.Log($"[ThumbnailGenerator] Saved: {pngPath}");
            return true;
        }
        catch (System.Exception e)
        {
            Debug.LogError($"[ThumbnailGenerator] Failed to render {pngPath}: {e.Message}");
            return false;
        }
        finally
        {
            // Restore camera state
            cam.targetTexture = prevCamRT;
            cam.rect = prevCamRect;
            cam.clearFlags = prevClear;
            cam.backgroundColor = prevBG;
            cam.cullingMask = prevCullingMask;
            if (cam.orthographic) cam.orthographicSize = prevOrthoSize;
            cam.aspect = prevAspect;
            cam.nearClipPlane = prevNearClip;
            cam.transform.SetPositionAndRotation(prevPos, prevRot);
            cam.enabled = prevEnabled;
            RenderTexture.active = prevRT;
            RenderTexture.ReleaseTemporary(rt);
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────

    /// <summary>
    /// Extracts subcategory key from prefab path.
    /// e.g. "Assets/Models/Clothes/Tops/foo.prefab" → "Clothes/Tops"
    /// </summary>
    private string GetSubcategoryKey(string prefabPath)
    {
        // Strip "Assets/Models/" prefix
        string rel = prefabPath;
        if (rel.StartsWith("Assets/Models/"))
            rel = rel.Substring("Assets/Models/".Length);
        // Take first two path segments: Category/Subcategory
        var parts = rel.Split('/');
        if (parts.Length >= 2)
            return parts[0] + "/" + parts[1];
        return parts[0];
    }

    private string PrefabPathToOutputPath(string prefabPath)
    {
        // Assets/Models/Clothes/Tops/foo.prefab → Assets/Thumbnails/Clothes/Tops/foo.png
        string relative = prefabPath;
        if (relative.StartsWith("Assets/Models/"))
            relative = relative.Substring("Assets/Models/".Length);
        relative = Path.ChangeExtension(relative, ".png");
        return Path.Combine(outputFolder, relative);
    }

    private Bounds ComputeBounds(Renderer[] renderers)
    {
        Bounds b = renderers[0].bounds;
        for (int i = 1; i < renderers.Length; i++)
        {
            if (renderers[i] != null)
                b.Encapsulate(renderers[i].bounds);
        }
        return b;
    }

    private void SetLayerRecursively(GameObject obj, int layer)
    {
        if (obj == null) return;
        obj.layer = layer;
        foreach (Transform t in obj.GetComponentsInChildren<Transform>(true))
        {
            if (t == null || t.gameObject == obj) continue;
            t.gameObject.layer = layer;
        }
    }

    private SkinnedMeshRenderer GetBodySkinnedMesh(Transform avatarRoot)
    {
        if (avatarRoot == null) return null;
        SkinnedMeshRenderer best = null;
        int maxBones = -1;
        foreach (var smr in avatarRoot.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (smr == null) continue;
            int count = smr.bones != null ? smr.bones.Length : 0;
            if (count > maxBones)
            {
                maxBones = count;
                best = smr;
            }
        }
        return best;
    }

    private Transform GetSkeletonRoot(Transform avatarRoot, SkinnedMeshRenderer bodySmr)
    {
        if (bodySmr != null && bodySmr.rootBone != null)
        {
            Transform t = bodySmr.rootBone;
            Transform last = t;
            while (t != null && IsUnder(t, avatarRoot))
            {
                last = t;
                t = t.parent;
            }
            return last != null ? last : bodySmr.rootBone;
        }
        var animator = avatarRoot.GetComponent<Animator>();
        if (animator == null) animator = avatarRoot.GetComponentInChildren<Animator>(true);
        if (animator != null)
        {
            var hips = animator.GetBoneTransform(HumanBodyBones.Hips);
            if (hips != null) return hips;
        }
        return avatarRoot;
    }

    private Dictionary<string, Transform> BuildBoneMap(Transform root)
    {
        var map = new Dictionary<string, Transform>();
        if (root == null) return map;
        foreach (var t in root.GetComponentsInChildren<Transform>(true))
        {
            if (!map.ContainsKey(t.name)) map[t.name] = t;
        }
        return map;
    }

    private static bool IsUnder(Transform child, Transform root)
    {
        if (child == null || root == null) return false;
        var current = child;
        while (current != null)
        {
            if (current == root) return true;
            current = current.parent;
        }
        return false;
    }
}
