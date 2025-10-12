using UnityEngine;

public class StencilApplier : MonoBehaviour
{
    [Header("Shaders")]
    public Shader jacketStencilWriterShader;   // Writes stencil (outer garment)
    public Shader innerClothingMaskShader;     // Tests stencil to hide under jacket
    public Shader bodyMaskShader;

    [Header("Targets")]
    public SkinnedMeshRenderer bodySkinnedMesh;
    [Tooltip("If enabled, replaces the body's materials with Body Mask shader.")]
    public bool applyBodyMaskToBody = false;

    [Header("Body Material Filters (skip masking for these)")]
    public string[] excludeMaterialNameContains = new string[] { "Hand", "Head", "Face", "Eye", "Foot" };

    private void Awake()
    {
        if (jacketStencilWriterShader == null) jacketStencilWriterShader = Shader.Find("Nose/Standard Stencil (Clothing)");
        if (innerClothingMaskShader == null) innerClothingMaskShader = Shader.Find("Nose/Standard Stencil (Top Mask)");
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
        var mgr = FindObjectOfType<AssetManager>();
        if (mgr != null && mgr.loadedAssets.TryGetValue(asset.id, out GameObject go) && go != null)
        {
            // Apply body mask only if explicitly enabled via inspector (applyBodyMaskToBody)
            // For clothing, choose correct shader based on subcategory
            if (asset.category.Equals("Clothes", System.StringComparison.OrdinalIgnoreCase))
            {
                if (asset.subcategory.Equals("Jacket", System.StringComparison.OrdinalIgnoreCase))
                {
                    ApplyShaderRecursive(go, jacketStencilWriterShader);
                }
                else
                {
                    ApplyShaderRecursive(go, innerClothingMaskShader);
                }
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

    private void ApplyShaderRecursive(GameObject root, Shader shader)
    {
        if (root == null || shader == null) return;
        foreach (var r in root.GetComponentsInChildren<Renderer>(true))
        {
            var mats = r.materials;
            for (int i = 0; i < mats.Length; i++)
            {
                if (mats[i] == null) continue;
                mats[i].shader = shader;
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


