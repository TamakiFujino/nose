using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

public class UnityBridge : MonoBehaviour
{
    public static UnityBridge Instance { get; private set; }

    // Events for iOS to Unity communication
    public static event System.Action<string> OnChangeAsset;
    public static event System.Action<string> OnChangeColor;

    private AssetManager assetManager;
    
    // Callback system for iOS responses
    private Dictionary<string, System.Action<string>> pendingCallbacks = new Dictionary<string, System.Action<string>>();
    private int callbackIdCounter = 0;

    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }
        else
        {
            Destroy(gameObject);
        }
    }

    private void Start()
    {
        // Ensure UnityLauncher exists so we can send responses back to iOS
        if (UnityLauncher.Instance == null)
        {
            var go = new GameObject("UnityLauncher");
            go.AddComponent<UnityLauncher>();
        }
        assetManager = FindObjectOfType<AssetManager>();
        if (assetManager == null)
        {
            Debug.LogError("UnityBridge: AssetManager not found!");
        }
    }

    // iOS calls this method to change an asset
    public void ChangeAsset(string assetJson)
    {
        Debug.Log($"UnityBridge: Received asset change request: {assetJson}");
        OnChangeAsset?.Invoke(assetJson);
    }

    // iOS calls this method to change a color
    public void ChangeColor(string colorJson)
    {
        Debug.Log($"UnityBridge: Received color change request: {colorJson}");
        OnChangeColor?.Invoke(colorJson);
    }

    // iOS calls this method to remove an asset for a category/subcategory
    public void RemoveAsset(string message)
    {
        Debug.Log($"UnityBridge: Received remove asset request: {message}");
        try
        {
            var data = JsonUtility.FromJson<CategoryRequest>(message);
            if (assetManager != null && data != null)
            {
                assetManager.RemoveAssetForSlot(data.category, data.subcategory);
            }
        }
        catch (System.Exception e)
        {
            Debug.LogError($"RemoveAsset parse error: {e.Message}");
        }
    }

    // iOS calls this method to reset body pose to default (A-pose)
    public void ResetBodyPose()
    {
        Debug.Log("UnityBridge: ResetBodyPose request");
        if (assetManager != null)
        {
            assetManager.ResetBodyPose();
        }
    }

    // iOS calls this method to get all available categories with callback
    public void GetAvailableCategories(string callbackId)
    {
        if (assetManager == null) 
        {
            SendResponseToiOS(callbackId, "[]");
            return;
        }
        
        var categories = assetManager.GetAvailableCategories();
        var categoryList = new List<object>();
        
        foreach (var category in categories)
        {
            var subcategories = assetManager.GetSubcategoriesForCategory(category);
            categoryList.Add(new { category = category, subcategories = subcategories });
        }
        
        var response = new { categories = categoryList };
        string jsonResponse = JsonUtility.ToJson(response);
        SendResponseToiOS(callbackId, jsonResponse);
    }

    // iOS calls this method to get all assets for a specific category/subcategory with callback
    public void GetAssetsForCategory(string message)
    {
        if (assetManager == null) 
        {
            SendResponseToiOS("", "[]");
            return;
        }
        
        try
        {
            var data = JsonUtility.FromJson<CategoryRequest>(message);
            var assets = assetManager.GetAvailableAssets(data.category, data.subcategory);
            var response = new { assets = assets.ToArray() };
            string jsonResponse = JsonUtility.ToJson(response);
            SendResponseToiOS(data.callbackId, jsonResponse);
        }
        catch (System.Exception e)
        {
            Debug.LogError($"Error parsing category request: {e.Message}");
            SendResponseToiOS("", "[]");
        }
    }

    // iOS calls this method to get all available assets (for debugging) with callback
    public void GetAllAvailableAssets(string callbackId)
    {
        if (assetManager == null) 
        {
            SendResponseToiOS(callbackId, "[]");
            return;
        }
        
        var allAssets = new List<AssetItem>();
        var categories = assetManager.GetAvailableCategories();
        
        foreach (var category in categories)
        {
            var subcategories = assetManager.GetSubcategoriesForCategory(category);
            foreach (var subcategory in subcategories)
            {
                var assets = assetManager.GetAvailableAssets(category, subcategory);
                allAssets.AddRange(assets);
            }
        }
        
        var response = new { assets = allAssets.ToArray() };
        string jsonResponse = JsonUtility.ToJson(response);
        SendResponseToiOS(callbackId, jsonResponse);
    }

    // iOS calls this to get available body poses (from AssetManager.poses)
    public void GetBodyPoses(string callbackId)
    {
        if (assetManager == null)
        {
            SendResponseToiOS(callbackId, "{\"poses\":[]}");
            return;
        }

        var poseNames = assetManager.poses
            .Where(p => p != null && !string.IsNullOrEmpty(p.name))
            .Select(p => p.name)
            .ToArray();
        var response = new PoseListResponse { poses = poseNames };
        string jsonResponse = JsonUtility.ToJson(response);
        SendResponseToiOS(callbackId, jsonResponse);
    }

    // iOS calls this method to check if the asset catalog is loaded with callback
    public void IsAssetCatalogLoaded(string callbackId)
    {
        if (assetManager == null) 
        {
            SendResponseToiOS(callbackId, "false");
            return;
        }
        
        var categories = assetManager.GetAvailableCategories();
        bool isLoaded = categories.Count > 0;
        SendResponseToiOS(callbackId, isLoaded.ToString());
    }

    // iOS calls this method to get the current avatar state with callback
    public void GetCurrentAvatarState(string callbackId)
    {
        if (assetManager == null) 
        {
            SendResponseToiOS(callbackId, "{}");
            return;
        }
        
        var state = new Dictionary<string, string>();
        foreach (var kvp in assetManager.loadedAssets)
        {
            var asset = assetManager.GetAssetById(kvp.Key);
            if (asset != null)
            {
                state[$"{asset.category}_{asset.subcategory}"] = asset.id;
            }
        }
        
        var response = new { state = state };
        string jsonResponse = JsonUtility.ToJson(response);
        SendResponseToiOS(callbackId, jsonResponse);
    }

    // iOS calls this to capture a thumbnail of the avatar camera and receive base64 PNG via callbackId
    public void CaptureAvatarThumbnail(string callbackId)
    {
        StartCoroutine(CaptureThumbnailCoroutine(callbackId));
    }

    private IEnumerator CaptureThumbnailCoroutine(string callbackId)
    {
        // Pick a camera: prefer a camera named "AvatarCamera", else Camera.main, else any enabled camera
        Camera cam = null;
        var avatarCamGO = GameObject.Find("AvatarCamera");
        if (avatarCamGO != null) cam = avatarCamGO.GetComponent<Camera>();
        if (cam == null) cam = Camera.main;
        if (cam == null)
        {
            var all = GameObject.FindObjectsOfType<Camera>();
            foreach (var c in all) { if (c != null && c.enabled) { cam = c; break; } }
        }
        if (cam == null)
        {
            SendResponseToiOS(callbackId, "{\"error\":\"No camera found\"}");
            yield break;
        }

        // Wait for end of frame to ensure latest pose is rendered
        yield return new WaitForEndOfFrame();

        int width = Mathf.Clamp(Screen.width, 128, 4096);
        int height = Mathf.Clamp(Screen.height, 128, 4096);

        var prevRT = RenderTexture.active;
        var prevCamRT = cam.targetTexture;
        RenderTexture rt = RenderTexture.GetTemporary(width, height, 24, RenderTextureFormat.ARGB32);
        try
        {
            cam.targetTexture = rt;
            cam.Render();

            RenderTexture.active = rt;
            Texture2D tex = new Texture2D(width, height, TextureFormat.RGBA32, false);
            tex.ReadPixels(new Rect(0, 0, width, height), 0, 0, false);
            tex.Apply(false, false);

            byte[] png = ImageConversion.EncodeToPNG(tex);
            Object.Destroy(tex);

            string b64 = System.Convert.ToBase64String(png);
            var payload = new ThumbnailPayload { imageBase64 = b64, width = width, height = height };
            string json = JsonUtility.ToJson(payload);
            SendResponseToiOS(callbackId, json);
        }
        finally
        {
            cam.targetTexture = prevCamRT;
            RenderTexture.active = prevRT;
            RenderTexture.ReleaseTemporary(rt);
        }
    }

    // iOS calls this to capture and save a thumbnail to a file under Application.temporaryCachePath
    // message should be a relative path like "avatar_captures/users/<uid>/collections/<id>/avatar.png"
    public void CaptureAvatarThumbnailToFile(string relativePath)
    {
        StartCoroutine(CaptureThumbnailToFileCoroutine(relativePath));
    }

    private IEnumerator CaptureThumbnailToFileCoroutine(string relativePath)
    {
        // Pick a camera similar to CaptureThumbnailCoroutine
        Camera cam = null;
        var avatarCamGO = GameObject.Find("AvatarCamera");
        if (avatarCamGO != null) cam = avatarCamGO.GetComponent<Camera>();
        if (cam == null) cam = Camera.main;
        if (cam == null)
        {
            var all = GameObject.FindObjectsOfType<Camera>();
            foreach (var c in all) { if (c != null && c.enabled) { cam = c; break; } }
        }
        if (cam == null)
        {
            Debug.LogError("CaptureAvatarThumbnailToFile: No camera found");
            yield break;
        }

        yield return new WaitForEndOfFrame();

        int width = Mathf.Clamp(Screen.width, 128, 4096);
        int height = Mathf.Clamp(Screen.height, 128, 4096);

        var prevRT = RenderTexture.active;
        var prevCamRT = cam.targetTexture;
        RenderTexture rt = RenderTexture.GetTemporary(width, height, 24, RenderTextureFormat.ARGB32);
        try
        {
            cam.targetTexture = rt;
            cam.Render();
            RenderTexture.active = rt;
            Texture2D tex = new Texture2D(width, height, TextureFormat.RGBA32, false);
            tex.ReadPixels(new Rect(0, 0, width, height), 0, 0, false);
            tex.Apply(false, false);
            byte[] png = ImageConversion.EncodeToPNG(tex);
            Object.Destroy(tex);

            string dir = System.IO.Path.Combine(Application.temporaryCachePath, System.IO.Path.GetDirectoryName(relativePath) ?? string.Empty);
            if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
            string full = System.IO.Path.Combine(Application.temporaryCachePath, relativePath);
            System.IO.File.WriteAllBytes(full, png);
            Debug.Log($"CaptureAvatarThumbnailToFile: wrote {full}");
        }
        finally
        {
            cam.targetTexture = prevCamRT;
            RenderTexture.active = prevRT;
            RenderTexture.ReleaseTemporary(rt);
        }
    }
    // Send response back to iOS
    private void SendResponseToiOS(string callbackId, string response)
    {
        if (string.IsNullOrEmpty(callbackId))
        {
            Debug.LogWarning("No callback ID provided, cannot send response to iOS");
            return;
        }
        
        // Send response to iOS via UnityLauncher
        if (UnityLauncher.Instance != null)
        {
            var responseData = new ResponseData { callbackId = callbackId, data = response };
            string jsonResponse = JsonUtility.ToJson(responseData);
            // Send through UnityResponse so iOS always receives it
            UnityLauncher.Instance.SendToIOS("UnityResponse", jsonResponse);
            Debug.Log($"Sent response to iOS: {callbackId} -> {response}");
        }
        else
        {
            Debug.LogError("UnityLauncher.Instance not found, cannot send response to iOS");
        }
    }

    // Send log message back to iOS
    public void SendLogToiOS(string message)
    {
        Debug.Log($"Unity -> iOS: {message}");
        // You can implement additional logging here if needed
    }
}

// Helper classes for JSON serialization
[System.Serializable]
public class CategoryRequest
{
    public string category;
    public string subcategory;
    public string callbackId;
}

[System.Serializable]
public class ResponseData
{
    public string callbackId;
    public string data;
}

[System.Serializable]
public class PoseListResponse
{
    public string[] poses;
}

[System.Serializable]
public class ThumbnailPayload
{
    public string imageBase64;
    public int width;
    public int height;
}
