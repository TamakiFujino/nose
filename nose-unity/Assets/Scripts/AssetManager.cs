using System.Collections.Generic;
using UnityEngine;
using System;
using System.Collections;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using UnityEngine.ResourceManagement.ResourceLocations;
using System.Linq;
using UnityEngine.Playables;
using UnityEngine.Animations;

[System.Serializable]
public class AssetItem
{
    public string id;
    public string name;
    public string modelPath;
    public string thumbnailPath;
    public string category;
    public string subcategory;
    public bool isActive;
    public Dictionary<string, string> metadata;
}

public class AssetManager : MonoBehaviour
{
    [Header("Asset Management")]
    public Transform avatarRoot; // Parent transform for all avatar parts
    [Tooltip("Optional: Body SkinnedMeshRenderer to derive skeleton root/bones from")] public SkinnedMeshRenderer bodySkinnedMesh;
    [Tooltip("Optional: Override skeleton root transform (defaults to bodySkinnedMesh.rootBone or avatarRoot)")] public Transform skeletonRootOverride;
    public Dictionary<string, GameObject> loadedAssets = new Dictionary<string, GameObject>();

    // Tracks which assetId is currently active per category/subcategory slot
    private readonly Dictionary<string, string> slotKeyToActiveAssetId = new Dictionary<string, string>();

    // Track Addressables handles per slot for proper release
    private readonly Dictionary<string, AsyncOperationHandle<GameObject>> slotKeyToHandle = new Dictionary<string, AsyncOperationHandle<GameObject>>();

    // Store all available assets discovered from Addressables
    private readonly Dictionary<string, List<AssetItem>> availableAssets = new Dictionary<string, List<AssetItem>>();
    // Fast lookup from address -> AssetItem we created
    private readonly Dictionary<string, AssetItem> addressToAssetItem = new Dictionary<string, AssetItem>(StringComparer.Ordinal);
    // Track per-asset region masks derived from labels/config so we can recompute mask on remove
    private readonly Dictionary<string, int> assetIdToRegionMask = new Dictionary<string, int>();

    // Pending colors to apply once a slot's asset is loaded
    private readonly Dictionary<string, string> slotKeyToPendingColor = new Dictionary<string, string>();

    private bool addressablesInitialized = false;

    [Header("Remote Catalog (Firebase Hosting)")]
    [Tooltip("Base URL where addressables are hosted (without trailing slash)")]
    public string remoteCatalogBaseUrl = "https://nose-a2309.web.app/addressables";

    [Tooltip("If set, use this full catalog URL directly instead of composing from base + platform + version")]
    public string remoteCatalogOverrideUrl = "";

    [Tooltip("Platform folder name under the hosting path (usually iOS or Android)")]
    public string platformFolderOverride = ""; // leave empty to auto-detect

    [Header("Current Selection")]
    public string currentCategory = "Base";
    public string currentSubcategory = "Eye";
    public string currentAssetId = "";

    // Events
    public static event Action<AssetItem> OnAssetChanged;
    public static event Action<string, string> OnCategoryChanged;
    public static event Action OnAssetsCatalogLoaded; // New event for when catalog is loaded

    [Header("Body Poses")]
    [Tooltip("List of available body poses (name must match the 'name' sent from iOS for Base/Body)")]
    public List<PoseDefinition> poses = new List<PoseDefinition>();

    private PlayableGraph poseGraph;
    private AnimationPlayableOutput poseOutput;
    private AnimationClipPlayable posePlayable;

    // Original body pose snapshot (local transforms) and animator state for A-pose resets
    private struct TRS { public Vector3 p; public Quaternion r; public Vector3 s; }
    private readonly Dictionary<Transform, TRS> originalBodyPose = new Dictionary<Transform, TRS>();
    private bool originalBodyPoseCaptured = false;
    private bool bodyAnimatorDisabledForAPose = false;
    private string currentPoseName = null;

    [Header("Debug")]
    public bool verboseLogs = false;
    public bool verboseDiscoveryLogs = false;

    // Hidden item unload management
    private const float hiddenUnloadDelaySeconds = 15f;
    private readonly Dictionary<string, Coroutine> pendingUnloadBySlot = new Dictionary<string, Coroutine>();

    [Header("Region Mask Labels")] 
    [Tooltip("Prefix for Addressables labels that hide body regions, like 'hide:chest', 'hide:shoulder'.")]
    public string hideLabelPrefix = "hide:";

    [System.Serializable]
    public class RegionDef { public string name; public int id; }

    [Tooltip("Map region names to integer IDs used by the body region shader. Configure to match your Blender paint.")]
    public List<RegionDef> regionDefs = new List<RegionDef>
    {
        new RegionDef{ name = "chest", id = 1},
        new RegionDef{ name = "shoulder", id = 2},
        new RegionDef{ name = "stomach", id = 3},
        new RegionDef{ name = "upperarm_l", id = 4},
        new RegionDef{ name = "upperarm_r", id = 5},
        new RegionDef{ name = "forearm_l", id = 6},
        new RegionDef{ name = "forearm_r", id = 7},
        new RegionDef{ name = "hand_l", id = 8},
        new RegionDef{ name = "hand_r", id = 9},
        new RegionDef{ name = "torso", id = 10},
        new RegionDef{ name = "hip", id = 11},
        new RegionDef{ name = "thigh_l", id = 12},
        new RegionDef{ name = "thigh_r", id = 13},
        new RegionDef{ name = "calf_l", id = 14},
        // add or adjust as needed
    };

    [Header("Region Mask Group Config")]
    public RegionMaskConfig regionMaskConfig;

    private void Start()
    {
        EnsureAvatarRoot();
        SetupUnityBridge();
        StartCoroutine(InitializeAddressables());
        if (verboseLogs) Debug.Log("AssetManager: Ready to receive asset data from iOS");
    }

    private void EnsureAvatarRoot()
    {
        // If avatarRoot is not set, try to find a sensible root so items follow scene-level rotation
        if (avatarRoot == null)
        {
            // Prefer a GameObject named "Avatar"
            var avatarGO = GameObject.Find("Avatar");
            if (avatarGO != null)
            {
                avatarRoot = avatarGO.transform;
                return;
            }

            // Fall back to body skinned mesh/animator and climb to the scene root
            var bodySmr = GetBodySkinnedMesh();
            Transform candidate = bodySmr != null ? bodySmr.transform : null;
            if (candidate == null)
            {
                var animator = GetBodyAnimator();
                if (animator != null) candidate = animator.transform;
            }
            if (candidate != null)
            {
                Transform root = candidate;
                while (root.parent != null) root = root.parent;
                avatarRoot = root;
            }
        }
    }

    private Animator GetBodyAnimator()
    {
        if (avatarRoot == null) return null;
        var animator = avatarRoot.GetComponent<Animator>();
        if (animator == null) animator = avatarRoot.GetComponentInChildren<Animator>(true);
        if (animator == null) animator = avatarRoot.GetComponentInParent<Animator>();
        return animator;
    }

    private SkinnedMeshRenderer GetBodySkinnedMesh()
    {
        if (bodySkinnedMesh != null) return bodySkinnedMesh;
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
        bodySkinnedMesh = best;
        return bodySkinnedMesh;
    }

    private Transform GetSkeletonRoot()
    {
        if (skeletonRootOverride != null) return skeletonRootOverride;
        var bodySmr = GetBodySkinnedMesh();
        if (bodySmr != null && bodySmr.rootBone != null)
        {
            // Find top-most ancestor under avatarRoot
            Transform t = bodySmr.rootBone;
            Transform last = t;
            while (t != null && IsUnder(t, avatarRoot))
            {
                last = t;
                t = t.parent;
            }
            return last != null ? last : bodySmr.rootBone;
        }
        var animator = GetBodyAnimator();
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

    private void RebindSkinnedMeshesToBody(GameObject instance)
    {
        if (instance == null || avatarRoot == null) return;

        var animator = GetBodyAnimator();
        var skeletonRoot = GetSkeletonRoot();
        var bodyRootBone = skeletonRoot != null ? skeletonRoot : (animator != null ? (animator.GetBoneTransform(HumanBodyBones.Hips) ?? avatarRoot) : avatarRoot);
        var bodyBoneMap = BuildBoneMap(skeletonRoot);

        // Disable any animators on the clothing prefab to avoid double-driving
        foreach (var anim in instance.GetComponentsInChildren<Animator>(true))
        {
            anim.enabled = false;
        }

        foreach (var smr in instance.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (smr == null) continue;

            // Root bone
            Transform mappedRoot = null;
            if (smr.rootBone != null)
            {
                // Try to map root bone by name
                bodyBoneMap.TryGetValue(smr.rootBone.name, out mappedRoot);
            }
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
                    {
                        newBones[i] = replacement;
                    }
                    else
                    {
                        newBones[i] = bodyRootBone;
                    }
                }
                smr.bones = newBones;
            }

            smr.updateWhenOffscreen = true;
            smr.skinnedMotionVectors = true;
        }
    }

    private string GetPlatformFolder()
    {
        if (!string.IsNullOrEmpty(platformFolderOverride)) return platformFolderOverride;
#if UNITY_IOS
        return "iOS";
#elif UNITY_ANDROID
        return "Android";
#else
        return "iOS"; // default for editor testing against iOS bundles
#endif
    }

    private IEnumerator InitializeAddressables()
    {
        var init = Addressables.InitializeAsync();
        yield return init;

        // If there is a local catalog, this will update it to remote
        var check = Addressables.CheckForCatalogUpdates(false);
        yield return check;
        var catalogs = check.Result;
        if (catalogs != null && catalogs.Count > 0)
        {
            var update = Addressables.UpdateCatalogs(catalogs);
            yield return update;
            if (verboseLogs) Debug.Log("Addressables: Updated existing catalogs");
        }
        else
        {
            if (verboseLogs) Debug.Log("Addressables: No existing catalogs to update");
        }

        // Explicitly load remote catalog from Firebase Hosting (in case no local bootstrap exists)
        yield return TryLoadRemoteCatalog();

        // Attempt to load RegionMaskConfig from Addressables if not assigned in the Inspector
        yield return LoadRegionMaskConfigIfNeeded();

        addressablesInitialized = true;
        if (verboseLogs) Debug.Log("AssetManager: Addressables initialized");

        // Discover available assets from Addressables
        yield return DiscoverAvailableAssets();
    }

    private IEnumerator LoadRegionMaskConfigIfNeeded()
    {
        if (regionMaskConfig != null)
        {
            yield break;
        }
        // Addressables entry added at: Assets/RegionMaskConfig.asset
        var handle = Addressables.LoadAssetAsync<RegionMaskConfig>("Assets/RegionMaskConfig.asset");
        yield return handle;
        if (handle.Status == AsyncOperationStatus.Succeeded && handle.Result != null)
        {
            regionMaskConfig = handle.Result;
            Debug.Log("RegionMaskConfig loaded from Addressables.");
        }
        else
        {
            Debug.LogWarning("RegionMaskConfig not assigned and couldn't be loaded from Addressables. Region masking will be skipped.");
        }
        if (handle.IsValid()) Addressables.Release(handle);
    }

    private IEnumerator TryLoadRemoteCatalog()
    {
        string platform = GetPlatformFolder();
        string version = Application.version; // matches PlayerSettings.bundleVersion (e.g., 0.1)
        string catalogUrl = !string.IsNullOrEmpty(remoteCatalogOverrideUrl)
            ? remoteCatalogOverrideUrl
            : $"{remoteCatalogBaseUrl}/{platform}/catalog_{version}.json";

        Debug.Log($"Addressables: Attempting to load remote catalog at {catalogUrl}");
        var loadCatalogHandle = Addressables.LoadContentCatalogAsync(catalogUrl, true);
        yield return loadCatalogHandle;

        if (loadCatalogHandle.IsValid())
        {
            if (loadCatalogHandle.Status == AsyncOperationStatus.Succeeded)
            {
                Debug.Log("Addressables: Remote catalog loaded successfully");
            }
            else
            {
                Debug.LogWarning("Addressables: Failed to load remote catalog (will proceed with whatever is available)");
            }
            Addressables.Release(loadCatalogHandle);
        }
        else
        {
            Debug.LogWarning("Addressables: LoadContentCatalogAsync returned an invalid handle; skipping");
        }
    }

    private IEnumerator DiscoverAvailableAssets()
    {
        if (verboseDiscoveryLogs) Debug.Log("🔍 Discovering Addressables by catalog keys (no labels)...");

        int discovered = 0;
        var seenKeys = new HashSet<string>();

        // Enumerate all resource locators and scan their keys
        foreach (var locator in Addressables.ResourceLocators)
        {
            foreach (var keyObj in locator.Keys)
            {
                if (keyObj is string key && key.StartsWith("Models/", StringComparison.Ordinal))
                {
                    if (!seenKeys.Add(key)) continue;

                    var keyHandle = Addressables.LoadResourceLocationsAsync(key, typeof(GameObject));
                    yield return keyHandle;

                    if (keyHandle.Status == AsyncOperationStatus.Succeeded)
                    {
                        foreach (var loc in keyHandle.Result)
                        {
                            ProcessAssetLocation(loc);
                            discovered++;
                        }
                    }
                    else
                    {
                        Debug.LogWarning($"⚠️ No locations for catalog key: {key}");
                    }

                    if (keyHandle.IsValid()) Addressables.Release(keyHandle);
                }
            }
        }

        if (verboseDiscoveryLogs) Debug.Log($"🔍 Catalog key scan discovered {discovered} assets under 'Models/'");

        if (verboseDiscoveryLogs)
        {
            Debug.Log($"✅ Asset discovery complete. Total categories: {availableAssets.Count}");
            foreach (var kvp in availableAssets)
            {
                Debug.Log($"  📁 {kvp.Key}: {kvp.Value.Count} assets");
            }
        }

        OnAssetsCatalogLoaded?.Invoke();
    }

    private void ProcessAssetLocation(IResourceLocation location)
    {
        // Skip legacy Resources entries to avoid pulling everything under Resources/
        var providerId = location.ProviderId;
        if (!string.IsNullOrEmpty(providerId) && providerId.Contains("LegacyResourcesProvider"))
        {
            // Only include assets that are actually in Addressables bundles
            return;
        }

        // Use address as authoritative key (don't rely on physical folder move)
        string address = location.PrimaryKey;
        if (string.IsNullOrEmpty(address)) return;

        // Expect addresses like: Models/Clothes/Tops/02_tops_tight_half
        var parts = address.Split('/');
        if (parts.Length < 4 || parts[0] != "Models")
        {
            // Not following our convention; skip silently
            return;
        }

        string category = parts[1];
        string subcategory = parts[2];
        string assetName = parts[parts.Length - 1];

        // Derive a thumbnail address by convention (optional Addressable)
        // e.g., Thumbs/Clothes/Tops/02_tops_tight_half
        string thumbnailAddress = $"Thumbs/{category}/{subcategory}/{assetName}";

        // Prefer internal id for loading to avoid InvalidKeyException on primary address
        string internalIdForLoad = $"Assets/Models/{category}/{subcategory}/{assetName}.prefab";
        var assetItem = new AssetItem
        {
            id = $"{category}_{subcategory}_{assetName}",
            name = assetName,
            modelPath = internalIdForLoad,
            thumbnailPath = thumbnailAddress,
            category = category,
            subcategory = subcategory,
            isActive = true,
            metadata = new Dictionary<string, string>()
        };

        string key = $"{category}_{subcategory}";
        if (!availableAssets.ContainsKey(key)) availableAssets[key] = new List<AssetItem>();
        availableAssets[key].Add(assetItem);

        addressToAssetItem[address] = assetItem;
        Debug.Log($"  ✅ Added: {address} → {key} (thumb: {thumbnailAddress})");
    }

    private void SetupUnityBridge()
    {
        UnityBridge.OnChangeAsset += HandleAssetChange;
        UnityBridge.OnChangeColor += HandleColorChange;
    }

    private void OnDestroy()
    {
        UnityBridge.OnChangeAsset -= HandleAssetChange;
        UnityBridge.OnChangeColor -= HandleColorChange;

        // Release any outstanding Addressables handles
        foreach (var kv in slotKeyToHandle)
        {
            if (kv.Value.IsValid()) Addressables.Release(kv.Value);
        }
        slotKeyToHandle.Clear();
    }

    private void HandleAssetChange(string assetJson)
    {
        try
        {
            AssetItem asset = JsonUtility.FromJson<AssetItem>(assetJson);
            ChangeAsset(asset);
        }
        catch (Exception e)
        {
            Debug.LogError($"Error parsing asset JSON: {e.Message}");
        }
    }

    public void ChangeAsset(AssetItem asset)
    {
        Debug.Log($"Changing asset to: {asset.name} (ID: {asset.id})");

        // Update current selection
        currentCategory = asset.category;
        currentSubcategory = asset.subcategory;
        currentAssetId = asset.id;

        // Early-out if same asset already active for this slot to avoid redundant loads
        string slotKey = $"{asset.category}:{asset.subcategory}";
        if (slotKeyToActiveAssetId.TryGetValue(slotKey, out string activeId) &&
            !string.IsNullOrEmpty(activeId) && string.Equals(activeId, asset.id, StringComparison.Ordinal))
        {
            // Ensure any pending color is applied even if we skip reload
            if (slotKeyToPendingColor.TryGetValue(slotKey, out string pendingHex) &&
                loadedAssets.TryGetValue(activeId, out GameObject existingGo) && existingGo != null)
            {
                if (TryParseHexColor(pendingHex, out Color pendingColor))
                {
                    ApplyColorToObject(existingGo, pendingColor, true);
                    slotKeyToPendingColor.Remove(slotKey);
                }
            }
            OnAssetChanged?.Invoke(asset);
            OnCategoryChanged?.Invoke(asset.category, asset.subcategory);
            return;
        }

        // For Base/Body, apply pose instead of loading an addressable prefab
        if (string.Equals(asset.category, "Base", StringComparison.OrdinalIgnoreCase) &&
            string.Equals(asset.subcategory, "Body", StringComparison.OrdinalIgnoreCase))
        {
            ApplyBodyPose(asset.name);
            OnAssetChanged?.Invoke(asset);
            OnCategoryChanged?.Invoke(asset.category, asset.subcategory);
            return;
        }

        // Load and instantiate the asset via Addressables
        StartCoroutine(LoadAddressableCoroutine(asset));

        // Trigger event
        OnAssetChanged?.Invoke(asset);
        OnCategoryChanged?.Invoke(asset.category, asset.subcategory);
    }

    private IEnumerator LoadAddressableCoroutine(AssetItem asset)
    {
        // Wait until Addressables is initialized
        while (!addressablesInitialized)
        {
            yield return null;
        }

        string slotKey = $"{asset.category}:{asset.subcategory}";

        // Destroy previous instance in this slot only if choosing a different asset to reduce flicker
        if (slotKeyToActiveAssetId.TryGetValue(slotKey, out string activeAssetId))
        {
            if (!string.IsNullOrEmpty(activeAssetId) && activeAssetId != asset.id && loadedAssets.TryGetValue(activeAssetId, out GameObject existing))
            {
                if (existing != null) Destroy(existing);
                loadedAssets.Remove(activeAssetId);
            }
        }

        // Release previous handle for this slot
        if (slotKeyToHandle.TryGetValue(slotKey, out var oldHandle))
        {
            if (oldHandle.IsValid()) Addressables.Release(oldHandle);
            slotKeyToHandle.Remove(slotKey);
        }

        string address = asset.modelPath;
        if (string.IsNullOrEmpty(address))
        {
            Debug.LogError($"Asset {asset.name} has no modelPath");
            yield break;
        }

        // Try the provided address first (can be internal id or address)
        var handle = Addressables.LoadAssetAsync<GameObject>(address);
        yield return handle;

        if (!(handle.Status == AsyncOperationStatus.Succeeded && handle.Result != null))
        {
            // Fallback to internal id path used in catalog m_InternalIds: Assets/Models/.../{name}.prefab
            if (handle.IsValid()) Addressables.Release(handle);
            string internalId = $"Assets/Models/{asset.category}/{asset.subcategory}/{asset.name}.prefab";
            var fallback = Addressables.LoadAssetAsync<GameObject>(internalId);
            yield return fallback;

            if (fallback.Status == AsyncOperationStatus.Succeeded && fallback.Result != null)
            {
                handle = fallback; // treat fallback as the active handle
                address = internalId;
            }
            else
            {
                Debug.LogError($"Addressables: failed to load '{asset.name}'");
                if (fallback.IsValid()) Addressables.Release(fallback);
                yield break;
            }
        }

        // Success path
        GameObject prefab = handle.Result;
        // If the same asset is already active for this slot, skip re-instantiation to avoid flicker
        if (slotKeyToActiveAssetId.TryGetValue(slotKey, out string currentId) && currentId == asset.id && loadedAssets.ContainsKey(asset.id))
        {
            Debug.Log($"Asset already active for {slotKey}: {asset.name}, skipping reload");
            // Ensure any pending color is still applied
            if (slotKeyToPendingColor.TryGetValue(slotKey, out string storedHex) && loadedAssets.TryGetValue(asset.id, out GameObject existingGo))
            {
                if (TryParseHexColor(storedHex, out Color pendingColor))
                {
                    ApplyColorToObject(existingGo, pendingColor, true);
                    slotKeyToPendingColor.Remove(slotKey);
                }
            }
            yield break;
        }
        GameObject assetInstance = Instantiate(prefab, avatarRoot);
        assetInstance.name = asset.name;

        // Ensure it inherits avatarRoot transform cleanly
        assetInstance.transform.localPosition = Vector3.zero;
        assetInstance.transform.localRotation = Quaternion.identity;
        assetInstance.transform.localScale = Vector3.one;

        // Ensure the instantiated item's layer matches the avatarRoot layer so
        // cameras (e.g., ThumbnailCamera) with culling masks include it
        SetLayerRecursively(assetInstance, avatarRoot.gameObject.layer);

        // Rebind skinned meshes to the body skeleton so pose/rotation matches
        RebindSkinnedMeshesToBody(assetInstance);

		// Enforce a stable render order to reduce z-fighting at garment overlaps
		ApplyStableRenderOrder(asset.category, asset.subcategory, assetInstance);

        // Track new instance and handle
        loadedAssets[asset.id] = assetInstance;
        slotKeyToActiveAssetId[slotKey] = asset.id;
        slotKeyToHandle[slotKey] = handle;

        Debug.Log($"Asset loaded via Addressables: {asset.name} (address/internalId: {address})");

        // Apply region hide mask based on Addressables labels (via RegionMaskConfig); store per-asset and apply union
        TryApplyRegionMaskFromLabels(address, asset.id);

        // Apply pending color for this slot if any
        if (slotKeyToPendingColor.TryGetValue(slotKey, out string pendingHex))
        {
            if (TryParseHexColor(pendingHex, out Color pendingColor))
            {
                ApplyColorToObject(assetInstance, pendingColor, true);
                slotKeyToPendingColor.Remove(slotKey);
                Debug.Log($"Applied pending color to {slotKey}: {pendingHex}");
            }
        }
    }

    private void TryApplyRegionMaskFromLabels(string address, string assetId)
    {
        try
        {
            if (string.IsNullOrEmpty(address)) return;
            if (string.IsNullOrEmpty(assetId)) return;
            // Build a set of possible keys that could identify this asset in the catalog
            var possibleKeys = new System.Collections.Generic.HashSet<string>(System.StringComparer.Ordinal);
            possibleKeys.Add(address);
            // If address is Assets/Models/.../Name.prefab add Models/.../Name
            const string assetsModels = "Assets/Models/";
            const string models = "Models/";
            if (address.StartsWith(assetsModels, System.StringComparison.Ordinal))
            {
                string noExt = address.EndsWith(".prefab", System.StringComparison.OrdinalIgnoreCase)
                    ? address.Substring(0, address.Length - ".prefab".Length)
                    : address;
                string asAddress = noExt.Substring("Assets/".Length); // Models/.../Name
                possibleKeys.Add(asAddress);
            }
            else if (address.StartsWith(models, System.StringComparison.Ordinal))
            {
                // If address is Models/.../Name add Assets/Models/.../Name.prefab
                possibleKeys.Add("Assets/" + address + ".prefab");
            }

            // Discover labels by scanning resource locators' keys and checking which labels contain this address
            var labels = new System.Collections.Generic.HashSet<string>(System.StringComparer.OrdinalIgnoreCase);
            foreach (var locator in Addressables.ResourceLocators)
            {
                foreach (var keyObj in locator.Keys)
                {
                    if (!(keyObj is string lbl)) continue;
                    // Only consider potential hide/group labels to keep it fast
                    bool consider = false;
                    if (!string.IsNullOrEmpty(hideLabelPrefix) && lbl.StartsWith(hideLabelPrefix, System.StringComparison.OrdinalIgnoreCase)) consider = true;
                    if (!consider && regionMaskConfig != null)
                    {
                        // Quick membership check against configured group labels
                        if (regionMaskConfig.groups.Exists(g => string.Equals(g.label, lbl, System.StringComparison.OrdinalIgnoreCase))) consider = true;
                    }
                    if (!consider) continue;

                    if (locator.Locate(lbl, typeof(GameObject), out var labelLocs))
                    {
                        foreach (var l in labelLocs)
                        {
                            if (l != null && possibleKeys.Contains(l.PrimaryKey))
                            {
                                labels.Add(lbl);
                                break;
                            }
                        }
                    }
                }
            }

            int mask = 0;
            foreach (var label in labels)
            {
                // Only use RegionMaskConfig groups (hide:* legacy removed)
            }

            // Also support predefined group labels via RegionMaskConfig (e.g., 'top-short')
            if (regionMaskConfig != null)
            {
                foreach (var label in labels)
                {
                    int groupMask = regionMaskConfig.BuildMaskForLabel(label, (regionName) =>
                    {
                        var def = regionDefs.Find(r => string.Equals(r.name, regionName, System.StringComparison.OrdinalIgnoreCase));
                        return def != null ? (int?)def.id : null;
                    });
                    if (groupMask != 0) mask |= groupMask;
                }
            }
            if (mask != 0)
            {
                // Do not apply yet; we'll store per-asset and then apply the UNION across all active items
            }

            // Store mask per active asset to support recomputation on removal
            assetIdToRegionMask[assetId] = mask;

            // Recompute union mask across all currently active items and apply
            int unionMask = 0;
            foreach (var kv in slotKeyToActiveAssetId)
            {
                if (!string.IsNullOrEmpty(kv.Value) && assetIdToRegionMask.TryGetValue(kv.Value, out int m))
                {
                    unionMask |= m;
                }
            }
            SetBodyRegionMask(unionMask);
            Debug.Log($"Applied region mask union from labels ({string.Join(",", labels)}): 0x{unionMask:X}");
        }
        catch (System.Exception e)
        {
            Debug.LogWarning($"TryApplyRegionMaskFromLabels error: {e.Message}");
        }
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

    private void SetAssetActive(string assetId, bool active)
    {
        if (loadedAssets.ContainsKey(assetId))
        {
            loadedAssets[assetId].SetActive(active);
        }
    }

	// Ensure deterministic rendering order among categories/subcategories to minimize edge artifacts
	private void ApplyStableRenderOrder(string category, string subcategory, GameObject root)
	{
		if (root == null) return;
		// Base queues: Opaque ~2000; keep within opaque/cutout range
		int baseQueue = 2000;
		int offset = 0;
		// Body draws first
		if (string.Equals(category, "Base", StringComparison.OrdinalIgnoreCase))
		{
			offset = 0; // Body
		}
		else if (string.Equals(category, "Clothes", StringComparison.OrdinalIgnoreCase))
		{
			// For stencil masking: jacket (stencil writer) must render BEFORE inner clothing (mask testers)
			// Order (low to high): Jacket < Bottoms < Tops; socks lowest among clothes if needed
			if (string.Equals(subcategory, "Socks", StringComparison.OrdinalIgnoreCase)) offset = 2;     // earliest within clothes
			else if (string.Equals(subcategory, "Jacket", StringComparison.OrdinalIgnoreCase)) offset = 8; // render before other clothes
			else if (string.Equals(subcategory, "Bottoms", StringComparison.OrdinalIgnoreCase)) offset = 12;
			else if (string.Equals(subcategory, "Tops", StringComparison.OrdinalIgnoreCase)) offset = 20;  // render after jacket so stencil is set
			else offset = 25;
		}
		else if (string.Equals(category, "Hair", StringComparison.OrdinalIgnoreCase))
		{
			offset = 40;
		}
		else
		{
			offset = 50; // accessories and others
		}

		int desiredQueue = baseQueue + offset;
		foreach (var r in root.GetComponentsInChildren<Renderer>(true))
		{
			if (r == null) continue;
			var mats = r.materials;
			if (mats == null) continue;
			for (int i = 0; i < mats.Length; i++)
			{
				var m = mats[i];
				if (m == null) continue;
				// Only adjust if currently in opaque/cutout range to avoid breaking transparents
				if (m.renderQueue <= 2450)
				{
					m.renderQueue = desiredQueue;
				}
			}
		}
	}

    public void RemoveAssetForSlot(string category, string subcategory)
    {
        string slotKey = $"{category}:{subcategory}";
        // Recompute mask from remaining items (excluding this slot)
        int recomputedMask = 0;
        foreach (var kv in slotKeyToActiveAssetId)
        {
            if (kv.Key == slotKey) continue;
            if (!string.IsNullOrEmpty(kv.Value) && assetIdToRegionMask.TryGetValue(kv.Value, out int m))
            {
                recomputedMask |= m;
            }
        }
        if (slotKeyToActiveAssetId.TryGetValue(slotKey, out string activeAssetId))
        {
            if (!string.IsNullOrEmpty(activeAssetId) && loadedAssets.TryGetValue(activeAssetId, out GameObject existing))
            {
                if (existing != null) Destroy(existing);
                loadedAssets.Remove(activeAssetId);
                assetIdToRegionMask.Remove(activeAssetId);
            }
            slotKeyToActiveAssetId.Remove(slotKey);
        }

        // Release handle for this slot
        if (slotKeyToHandle.TryGetValue(slotKey, out var handle))
        {
            if (handle.IsValid()) Addressables.Release(handle);
            slotKeyToHandle.Remove(slotKey);
        }

        // Apply new union mask
        SetBodyRegionMask(recomputedMask);
        Debug.Log($"Removed asset for slot {slotKey}. Recomputed mask=0x{recomputedMask:X}");
    }

    // Toggle visibility for a category/subcategory without changing mask bookkeeping or unloading
    public void SetVisibilityForSlot(string category, string subcategory, bool visible)
    {
        string slotKey = $"{category}:{subcategory}";
        if (slotKeyToActiveAssetId.TryGetValue(slotKey, out string activeAssetId))
        {
            if (!string.IsNullOrEmpty(activeAssetId))
            {
                SetAssetActive(activeAssetId, visible);
                if (verboseLogs) Debug.Log($"Set visibility for slot {slotKey} → {visible}");

                // Schedule unload when hidden, cancel if shown again
                if (!visible)
                {
                    if (pendingUnloadBySlot.TryGetValue(slotKey, out var co) && co != null)
                    {
                        StopCoroutine(co);
                        pendingUnloadBySlot.Remove(slotKey);
                    }
                    var routine = StartCoroutine(UnloadHiddenAfterDelay(slotKey, activeAssetId));
                    pendingUnloadBySlot[slotKey] = routine;
                }
                else
                {
                    if (pendingUnloadBySlot.TryGetValue(slotKey, out var co) && co != null)
                    {
                        StopCoroutine(co);
                        pendingUnloadBySlot.Remove(slotKey);
                    }
                }
            }
        }
    }

    private IEnumerator UnloadHiddenAfterDelay(string slotKey, string assetId)
    {
        yield return new WaitForSeconds(hiddenUnloadDelaySeconds);
        // If still hidden, unload to free memory
        if (!slotKeyToActiveAssetId.TryGetValue(slotKey, out string currentId) || currentId != assetId)
        {
            yield break; // slot changed; ignore
        }
        if (!loadedAssets.TryGetValue(assetId, out GameObject go) || go == null)
        {
            yield break; // already gone
        }
        if (go.activeSelf)
        {
            yield break; // became visible; don't unload
        }
        // Destroy instance and release handle, keep mask bookkeeping so union remains correct
        if (verboseLogs) Debug.Log($"Unloading hidden asset for slot {slotKey} after delay");
        Destroy(go);
        loadedAssets.Remove(assetId);
        if (slotKeyToHandle.TryGetValue(slotKey, out var handle))
        {
            if (handle.IsValid()) Addressables.Release(handle);
            slotKeyToHandle.Remove(slotKey);
        }
        pendingUnloadBySlot.Remove(slotKey);
    }

    [Serializable]
    public class PoseDefinition
    {
        public string name;
        public AnimationClip clip;
    }

    private void ApplyBodyPose(string poseName)
    {
        // Ensure original pose is captured once, and animator enabled if we previously disabled it
        CaptureOriginalBodyPoseIfNeeded();
        var animator = GetBodyAnimator();
        if (animator == null)
        {
            Debug.LogWarning("ApplyBodyPose: No Animator found on avatarRoot");
            return;
        }
        if (string.IsNullOrEmpty(poseName)) return;
        // Skip if same pose already active
        if (!string.IsNullOrEmpty(currentPoseName) && string.Equals(currentPoseName, poseName, StringComparison.OrdinalIgnoreCase))
        {
            Debug.Log($"ApplyBodyPose: Pose '{poseName}' already active, skipping");
            return;
        }

        var def = poses.FirstOrDefault(p => string.Equals(p.name, poseName, StringComparison.OrdinalIgnoreCase));
        if (def == null || def.clip == null)
        {
            Debug.LogWarning($"ApplyBodyPose: Pose not found or clip missing for '{poseName}'");
            return;
        }

        // Tear down previous graph
        if (poseGraph.IsValid())
        {
            poseGraph.Destroy();
        }

        poseGraph = PlayableGraph.Create("BodyPoseGraph");
        poseGraph.SetTimeUpdateMode(DirectorUpdateMode.GameTime);

        posePlayable = AnimationClipPlayable.Create(poseGraph, def.clip);
        posePlayable.SetApplyFootIK(true);
        posePlayable.SetTime(0.0);
        posePlayable.SetSpeed(0.0); // hold pose at first frame; adjust if you want a specific time

        poseOutput = AnimationPlayableOutput.Create(poseGraph, "BodyPoseOutput", animator);
        poseOutput.SetSourcePlayable(posePlayable);
        // Enable animator only after graph is fully prepared to avoid a blank frame
        if (bodyAnimatorDisabledForAPose)
        {
            animator.enabled = true;
            bodyAnimatorDisabledForAPose = false;
        }
        poseGraph.Play();
        animator.Update(0f);
        currentPoseName = poseName;

        Debug.Log($"ApplyBodyPose: Applied pose '{poseName}'");
    }

    public void ResetBodyPose()
    {
        // Stop any pose playable graph
        if (poseGraph.IsValid())
        {
            poseGraph.Destroy();
        }

        // Disable animator so it doesn't drive bones, then restore original bind pose
        var animator = GetBodyAnimator();
        if (animator != null)
        {
            animator.enabled = false;
            bodyAnimatorDisabledForAPose = true;
        }
        RestoreOriginalBodyPose();
        currentPoseName = null;
        Debug.Log("ResetBodyPose: Restored to original armature pose (A-pose)");
    }

    private void CaptureOriginalBodyPoseIfNeeded()
    {
        if (originalBodyPoseCaptured) return;
        var root = GetSkeletonRoot();
        if (root == null) return;
        originalBodyPose.Clear();
        foreach (var t in root.GetComponentsInChildren<Transform>(true))
        {
            TRS trs;
            trs.p = t.localPosition;
            trs.r = t.localRotation;
            trs.s = t.localScale;
            originalBodyPose[t] = trs;
        }
        originalBodyPoseCaptured = true;
        Debug.Log("CaptureOriginalBodyPose: Captured body bind pose");
    }

    private void RestoreOriginalBodyPose()
    {
        if (!originalBodyPoseCaptured) { CaptureOriginalBodyPoseIfNeeded(); }
        var root = GetSkeletonRoot();
        if (root == null) return;
        foreach (var t in root.GetComponentsInChildren<Transform>(true))
        {
            if (originalBodyPose.TryGetValue(t, out var trs))
            {
                t.localPosition = trs.p;
                t.localRotation = trs.r;
                t.localScale = trs.s;
            }
        }
    }

    public AssetItem GetAssetById(string assetId)
    {
        // Search through all available assets
        foreach (var categoryAssets in availableAssets.Values)
        {
            var found = categoryAssets.FirstOrDefault(a => a.id == assetId);
            if (found != null) return found;
        }
        return null;
    }

    public List<AssetItem> GetAvailableAssets(string category, string subcategory)
    {
        string key = $"{category}_{subcategory}";
        if (availableAssets.TryGetValue(key, out var assets))
        {
            return assets.Where(a => a.isActive).ToList();
        }
        return new List<AssetItem>();
    }

    public List<string> GetAvailableCategories()
    {
        return availableAssets.Keys.Select(k => k.Split('_')[0]).Distinct().ToList();
    }

    public List<string> GetSubcategoriesForCategory(string category)
    {
        return availableAssets.Keys
            .Where(k => k.StartsWith(category + "_"))
            .Select(k => k.Split('_')[1])
            .ToList();
    }

    // Backward-compatible API expected by existing callers
    public List<AssetItem> GetAssetsForCategory(string category, string subcategory)
    {
        return GetAvailableAssets(category, subcategory);
    }

    [Serializable]
    private class ColorPayload { public string category; public string subcategory; public string colorHex; }

    private void HandleColorChange(string colorJson)
    {
        try
        {
            var payload = JsonUtility.FromJson<ColorPayload>(colorJson);
            if (payload == null) { Debug.LogWarning("Color payload null"); return; }
            string slotKey = $"{payload.category}:{payload.subcategory}";

            // Special case: Base/Body → color the body mesh instead of items
            if (string.Equals(payload.category, "Base", System.StringComparison.OrdinalIgnoreCase) &&
                string.Equals(payload.subcategory, "Body", System.StringComparison.OrdinalIgnoreCase))
            {
                if (TryParseHexColor(payload.colorHex, out Color bodyColor))
                {
                    var bodySmr = GetBodySkinnedMesh();
                    if (bodySmr != null)
                    {
                        ApplyColorToObject(bodySmr.gameObject, bodyColor, false);
                        return;
                    }
                    // Fallback to avatarRoot if body SMR not assigned/found
                    if (avatarRoot != null) {
                        ApplyColorToObject(avatarRoot.gameObject, bodyColor, false);
                        return;
                    }
                }
                else
                {
                    Debug.LogWarning($"Failed to parse body color {payload.colorHex}");
                }
                // Continue to default flow if body path failed
            }

            if (slotKeyToActiveAssetId.TryGetValue(slotKey, out string activeAssetId))
            {
                if (loadedAssets.TryGetValue(activeAssetId, out GameObject go) && go != null)
                {
                    if (TryParseHexColor(payload.colorHex, out Color c))
                    {
                        ApplyColorToObject(go, c, true);
                    }
                    else
                    {
                        Debug.LogWarning($"Failed to parse color {payload.colorHex}");
                    }
                }
                else
                {
                    // Asset for this slot not yet instantiated; remember color and apply after load
                    slotKeyToPendingColor[slotKey] = payload.colorHex;
                }
            }
            else
            {
                // No active asset tracked for this slot yet; remember color
                slotKeyToPendingColor[slotKey] = payload.colorHex;
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"Error handling color change: {e.Message}");
        }
    }

    private static bool TryParseHexColor(string hex, out Color color)
    {
        color = Color.white;
        if (string.IsNullOrEmpty(hex)) return false;
        string h = hex.Trim();
        if (h.StartsWith("#")) h = h.Substring(1);
        if (h.Length == 6)
        {
            if (ColorUtility.TryParseHtmlString("#" + h, out color)) return true;
        }
        if (h.Length == 8)
        {
            if (ColorUtility.TryParseHtmlString("#" + h, out color)) return true;
        }
        return false;
    }

    private void ApplyColorToObject(GameObject root, Color color, bool onlyFirstMaterial)
    {
        if (!onlyFirstMaterial)
        {
            // Apply to all materials of all renderers (used for Base/Body)
            var allRenderers = root.GetComponentsInChildren<Renderer>(true);
            foreach (var r in allRenderers)
            {
                var mats = r.materials;
                for (int i = 0; i < mats.Length; i++)
                {
                    var m = mats[i];
                    if (m == null) continue;
                    if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", color);
                    else if (m.HasProperty("_Color")) m.SetColor("_Color", color);
                }
            }
            return;
        }

        // Apply only to the first material of a single, primary renderer under this prefab
        // Prefer SkinnedMeshRenderer if available; otherwise first Renderer found
        Renderer targetRenderer = null;
        var candidateSmr = root.GetComponentInChildren<SkinnedMeshRenderer>(true);
        if (candidateSmr != null && candidateSmr.materials != null && candidateSmr.materials.Length > 0)
        {
            targetRenderer = candidateSmr;
        }
        else
        {
            targetRenderer = root.GetComponentInChildren<Renderer>(true);
        }

        if (targetRenderer == null) return;
        var targetMats = targetRenderer.materials;
        if (targetMats == null || targetMats.Length == 0) return;
        var mat0 = targetMats[0];
        if (mat0 == null) return;
        if (mat0.HasProperty("_BaseColor")) mat0.SetColor("_BaseColor", color);
        else if (mat0.HasProperty("_Color")) mat0.SetColor("_Color", color);
    }

    // Helper: allow external systems (e.g., native bridge) to set body region mask by integer bitmask
    public void SetBodyRegionMask(int mask)
    {
        var smr = GetBodySkinnedMesh();
        if (smr != null)
        {
            int id = Shader.PropertyToID("_RegionHideMask");
            foreach (var m in smr.materials)
            {
                if (m != null && m.HasProperty(id)) m.SetInt(id, mask);
            }
        }
    }
}
