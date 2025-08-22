using UnityEngine;
using System.Collections.Generic;

public class AvatarController : MonoBehaviour
{
    [Header("Avatar References")]
    public Transform avatarRoot;
    public SkinnedMeshRenderer avatarMeshRenderer;
    
    [Header("Asset Slots")]
    public Transform baseSlot;      // For base body parts
    public Transform hairSlot;      // For hair
    public Transform clothesSlot;   // For clothing
    public Transform accessoriesSlot; // For accessories
    
    [Header("Current Assets")]
    public Dictionary<string, GameObject> currentAssets = new Dictionary<string, GameObject>();
    
    private AssetManager assetManager;
    
    private void Start()
    {
        // Find the asset manager
        assetManager = FindObjectOfType<AssetManager>();
        if (assetManager == null)
        {
            Debug.LogError("AvatarController: AssetManager not found!");
            return;
        }
        
        // Subscribe to asset change events
        AssetManager.OnAssetChanged += HandleAssetChanged;
        AssetManager.OnCategoryChanged += HandleCategoryChanged;
        
        // Set up avatar root if not assigned
        if (avatarRoot == null)
        {
            avatarRoot = transform;
        }
        
        // Set up default slots if not assigned
        SetupDefaultSlots();
    }
    
    private void SetupDefaultSlots()
    {
        if (baseSlot == null)
        {
            GameObject baseSlotObj = new GameObject("BaseSlot");
            baseSlotObj.transform.SetParent(avatarRoot);
            baseSlotObj.transform.localPosition = Vector3.zero;
            baseSlotObj.transform.localRotation = Quaternion.identity;
            baseSlot = baseSlotObj.transform;
        }
        
        if (hairSlot == null)
        {
            GameObject hairSlotObj = new GameObject("HairSlot");
            hairSlotObj.transform.SetParent(avatarRoot);
            hairSlotObj.transform.localPosition = Vector3.zero;
            hairSlotObj.transform.localRotation = Quaternion.identity;
            hairSlot = hairSlotObj.transform;
        }
        
        if (clothesSlot == null)
        {
            GameObject clothesSlotObj = new GameObject("ClothesSlot");
            clothesSlotObj.transform.SetParent(avatarRoot);
            clothesSlotObj.transform.localPosition = Vector3.zero;
            clothesSlotObj.transform.localRotation = Quaternion.identity;
            clothesSlot = clothesSlotObj.transform;
        }
        
        if (accessoriesSlot == null)
        {
            GameObject accessoriesSlotObj = new GameObject("AccessoriesSlot");
            accessoriesSlotObj.transform.SetParent(avatarRoot);
            accessoriesSlotObj.transform.localPosition = Vector3.zero;
            accessoriesSlotObj.transform.localRotation = Quaternion.identity;
            accessoriesSlot = accessoriesSlotObj.transform;
        }
    }
    
    private void HandleAssetChanged(AssetItem asset)
    {
        Debug.Log($"AvatarController: Asset changed to {asset.name}");
        
        // Update the avatar based on the new asset
        ApplyAssetToAvatar(asset);
    }
    
    private void HandleCategoryChanged(string category, string subcategory)
    {
        Debug.Log($"AvatarController: Category changed to {category} - {subcategory}");
        
        // You can add category-specific logic here
        // For example, changing avatar poses or camera angles
    }
    
    private void ApplyAssetToAvatar(AssetItem asset)
    {
        // Get the appropriate slot for this asset
        Transform targetSlot = GetSlotForCategory(asset.category);
        
        if (targetSlot == null)
        {
            Debug.LogError($"AvatarController: No slot found for category {asset.category}");
            return;
        }
        
        // Remove existing assets of the same category/subcategory
        RemoveAssetsOfCategory(asset.category, asset.subcategory);
        
        // Add the new asset
        if (assetManager.loadedAssets.ContainsKey(asset.id))
        {
            GameObject assetInstance = assetManager.loadedAssets[asset.id];
            assetInstance.transform.SetParent(targetSlot);
            assetInstance.transform.localPosition = Vector3.zero;
            assetInstance.transform.localRotation = Quaternion.identity;
            assetInstance.transform.localScale = Vector3.one;
            
            // Store reference
            currentAssets[asset.id] = assetInstance;
            
            Debug.Log($"AvatarController: Applied asset {asset.name} to slot {targetSlot.name}");
        }
    }
    
    private Transform GetSlotForCategory(string category)
    {
        switch (category.ToLower())
        {
            case "base":
                return baseSlot;
            case "hair":
                return hairSlot;
            case "clothes":
                return clothesSlot;
            case "accessories":
                return accessoriesSlot;
            default:
                Debug.LogWarning($"AvatarController: Unknown category {category}");
                return avatarRoot;
        }
    }
    
    private void RemoveAssetsOfCategory(string category, string subcategory)
    {
        List<string> assetsToRemove = new List<string>();
        
        foreach (var kvp in currentAssets)
        {
            AssetItem asset = GetAssetById(kvp.Key);
            if (asset != null && asset.category == category && asset.subcategory == subcategory)
            {
                assetsToRemove.Add(kvp.Key);
            }
        }
        
        foreach (string assetId in assetsToRemove)
        {
            if (currentAssets.ContainsKey(assetId))
            {
                Destroy(currentAssets[assetId]);
                currentAssets.Remove(assetId);
            }
        }
    }
    
    private AssetItem GetAssetById(string assetId)
    {
        if (assetManager != null)
        {
            return assetManager.GetAssetsForCategory("", "").Find(a => a.id == assetId);
        }
        return null;
    }
    
    // Method to get current avatar state (useful for Firestore)
    public Dictionary<string, string> GetCurrentAvatarState()
    {
        Dictionary<string, string> state = new Dictionary<string, string>();
        
        foreach (var kvp in currentAssets)
        {
            AssetItem asset = GetAssetById(kvp.Key);
            if (asset != null)
            {
                state[$"{asset.category}_{asset.subcategory}"] = asset.id;
            }
        }
        
        return state;
    }
    
    private void OnDestroy()
    {
        AssetManager.OnAssetChanged -= HandleAssetChanged;
        AssetManager.OnCategoryChanged -= HandleCategoryChanged;
    }
}
