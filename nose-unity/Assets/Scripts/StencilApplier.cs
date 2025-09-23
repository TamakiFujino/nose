using UnityEngine;

public class StencilApplier : MonoBehaviour
{
    [Header("Shaders")]
    public Shader clothingShader;
    public Shader bodyMaskShader;

    [Header("Targets")]
    public SkinnedMeshRenderer bodySkinnedMesh;
    [Tooltip("If enabled, replaces the body's materials with Body Mask shader.")]
    public bool applyBodyMaskToBody = false;

    [Header("Body Material Filters (skip masking for these)")]
    public string[] excludeMaterialNameContains = new string[] { "Hand", "Head", "Face", "Eye", "Foot" };

    private void Awake()
    {
        if (clothingShader == null) clothingShader = Shader.Find("Nose/Standard Stencil (Clothing)");
        if (bodyMaskShader == null) bodyMaskShader = Shader.Find("Nose/Standard Stencil (Body Mask)");
        if (bodySkinnedMesh == null)
        {
            var mgr = FindObjectOfType<AssetManager>();
            if (mgr != null)
            {
                var smr = mgr.GetType().GetMethod("GetBodySkinnedMesh", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)?.Invoke(mgr, null) as SkinnedMeshRenderer;
                bodySkinnedMesh = smr != null ? smr : mgr.GetComponentInChildren<SkinnedMeshRenderer>(true);
            }
        }
        if (applyBodyMaskToBody)
        {
            ApplyBodyMask();
        }
        AssetManager.OnAssetChanged += OnAssetChanged;
    }

    private void OnDestroy()
    {
        AssetManager.OnAssetChanged -= OnAssetChanged;
    }

    private void OnAssetChanged(AssetItem asset)
    {
        if (asset == null) return;
        // Apply clothing shader to newly loaded items (non-base/body)
        if (!(asset.category.Equals("Base", System.StringComparison.OrdinalIgnoreCase) && asset.subcategory.Equals("Body", System.StringComparison.OrdinalIgnoreCase)))
        {
            var mgr = FindObjectOfType<AssetManager>();
            if (mgr != null && mgr.loadedAssets.TryGetValue(asset.id, out GameObject go) && go != null)
            {
                ApplyClothing(go);
            }
        }
    }

    private void ApplyBodyMask()
    {
        if (bodySkinnedMesh == null || bodyMaskShader == null) return;
        var mats = bodySkinnedMesh.materials;
        for (int i = 0; i < mats.Length; i++)
        {
            if (mats[i] == null) continue;
            if (!ShouldExcludeMaterial(mats[i]))
            {
                mats[i].shader = bodyMaskShader;
            }
        }
        bodySkinnedMesh.materials = mats;
    }

    private void ApplyClothing(GameObject root)
    {
        if (root == null || clothingShader == null) return;
        foreach (var r in root.GetComponentsInChildren<Renderer>(true))
        {
            var mats = r.materials;
            for (int i = 0; i < mats.Length; i++)
            {
                if (mats[i] == null) continue;
                mats[i].shader = clothingShader;
            }
            r.materials = mats;
        }
    }

    private bool ShouldExcludeMaterial(Material mat)
    {
        if (mat == null || excludeMaterialNameContains == null) return false;
        string name = mat.name;
        for (int i = 0; i < excludeMaterialNameContains.Length; i++)
        {
            var token = excludeMaterialNameContains[i];
            if (!string.IsNullOrEmpty(token) && name.IndexOf(token, System.StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return true;
            }
        }
        return false;
    }
}


