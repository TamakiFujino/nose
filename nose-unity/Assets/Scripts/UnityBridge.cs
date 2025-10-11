using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine.Rendering;

public class UnityBridge : MonoBehaviour
{
    public static UnityBridge Instance { get; private set; }

    // Events for iOS to Unity communication
    public static event System.Action<string> OnChangeAsset;
    public static event System.Action<string> OnChangeColor;

    private AssetManager assetManager;
    private HorizontalRotateOnDrag rotator;
    private CommandBuffer stencilClearCmd;
    
    // Helper to snapshot and restore material state when forcing opaque capture
    private struct MaterialState
    {
        public Material material;
		public Shader shader;
        public bool alphaTestOn;
        public bool alphaBlendOn;
        public bool alphaPremulOn;
        public bool hadMode;
        public float? mode;
        public bool hadSurface;
        public float? surface;
        public bool hadColor;
        public Color? color;
		public bool hadRegionMask;
		public float? regionMask;
        public int renderQueue;

        public MaterialState(Material m)
        {
			material = m;
			shader = m != null ? m.shader : null;
            alphaTestOn = m != null && m.IsKeywordEnabled("_ALPHATEST_ON");
            alphaBlendOn = m != null && m.IsKeywordEnabled("_ALPHABLEND_ON");
            alphaPremulOn = m != null && m.IsKeywordEnabled("_ALPHAPREMULTIPLY_ON");
            hadMode = m != null && m.HasProperty("_Mode");
            mode = hadMode ? (float?)m.GetFloat("_Mode") : null;
            hadSurface = m != null && m.HasProperty("_Surface");
            surface = hadSurface ? (float?)m.GetFloat("_Surface") : null;
            hadColor = m != null && m.HasProperty("_Color");
            color = hadColor ? (Color?)m.GetColor("_Color") : null;
			hadRegionMask = m != null && m.HasProperty("_RegionHideMask");
			regionMask = hadRegionMask ? (float?)m.GetFloat("_RegionHideMask") : null;
            renderQueue = m != null ? m.renderQueue : -1;
        }
    }
    
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

        rotator = FindObjectOfType<HorizontalRotateOnDrag>();

        // Ensure ThumbnailCamera never renders to the screen by default
        var thumbCamGO = GameObject.Find("ThumbnailCamera");
        if (thumbCamGO != null)
        {
            var cam = thumbCamGO.GetComponent<Camera>();
            if (cam != null) cam.enabled = false;
        }

        // Attach stencil clear before opaques on avatar cameras to avoid stale stencil between category switches
        TryAttachStencilClearToAvatarCameras();
    }

    // iOS calls this to override the remote catalog URL explicitly
    public void SetRemoteCatalogURL(string url)
    {
        try
        {
            var mgr = assetManager != null ? assetManager : FindObjectOfType<AssetManager>();
            if (mgr != null)
            {
                mgr.remoteCatalogOverrideUrl = url;
                Debug.Log($"UnityBridge: remote catalog override set to {url}");
            }
        }
        catch (System.Exception e)
        {
            Debug.LogWarning($"SetRemoteCatalogURL error: {e.Message}");
        }
    }

    private void TryAttachStencilClearToAvatarCameras()
    {
        if (stencilClearCmd != null) return;
        Shader clearShader = Shader.Find("Nose/Stencil Clear");
        if (clearShader == null) return;

        Material clearMat = new Material(clearShader);
        stencilClearCmd = new CommandBuffer { name = "Clear Stencil" };
        // Draw a full-screen procedural triangle to clear stencil
        stencilClearCmd.DrawProcedural(Matrix4x4.identity, clearMat, 0, MeshTopology.Triangles, 3);

        // Apply to likely cameras
        var avatarCam = GameObject.Find("AvatarCamera")?.GetComponent<Camera>();
        var thumbCam = GameObject.Find("ThumbnailCamera")?.GetComponent<Camera>();
        if (avatarCam != null)
        {
            avatarCam.RemoveCommandBuffer(CameraEvent.BeforeForwardOpaque, stencilClearCmd);
            avatarCam.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, stencilClearCmd);
        }
        if (thumbCam != null)
        {
            thumbCam.RemoveCommandBuffer(CameraEvent.BeforeForwardOpaque, stencilClearCmd);
            thumbCam.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, stencilClearCmd);
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

    // iOS calls this to rotate the avatar by sending horizontal delta in pixels (string parseable as float)
    public void RotateAvatar(string message)
    {
        if (string.IsNullOrEmpty(message)) return;
        if (rotator == null) rotator = FindObjectOfType<HorizontalRotateOnDrag>();
        if (rotator == null)
        {
            Debug.LogWarning("RotateAvatar: HorizontalRotateOnDrag not found in scene");
            return;
        }
        if (float.TryParse(message, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float dx))
        {
            rotator.ExternalDrag(dx);
        }
        else
        {
            Debug.LogWarning($"RotateAvatar: could not parse delta '{message}'");
        }
    }

    private IEnumerator CaptureThumbnailCoroutine(string callbackId)
    {
        // Pick a camera: prefer a camera named "ThumbnailCamera", then "AvatarCamera", else Camera.main, else any enabled camera
        Camera cam = null;
        var thumbCamGO = GameObject.Find("ThumbnailCamera");
        if (thumbCamGO != null) cam = thumbCamGO.GetComponent<Camera>();
        var avatarCamGO = GameObject.Find("AvatarCamera");
        if (cam == null && avatarCamGO != null) cam = avatarCamGO.GetComponent<Camera>();
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
        var prevCamRect = cam.rect;
        bool isThumbnailCamera = cam.gameObject != null && cam.gameObject.name == "ThumbnailCamera";
        bool prevEnabled = cam.enabled;
        RenderTexture rt = RenderTexture.GetTemporary(width, height, 24, RenderTextureFormat.ARGB32);
        try
        {
            // Ensure the thumbnail camera does not render to screen while capturing
            if (isThumbnailCamera) cam.enabled = false;
            // Render into full texture area regardless of scene viewport settings
            cam.rect = new Rect(0f, 0f, 1f, 1f);
            cam.targetTexture = rt;
            cam.Render();

            RenderTexture.active = rt;

            // Compute avatar viewport rect and crop to it if available
            Rect pixelRect = new Rect(0, 0, width, height);
            if (assetManager != null && assetManager.gameObject != null)
            {
                if (TryComputeAvatarViewportRect(cam, out Rect viewportRect))
                {
                    // Expand slightly for padding
                    viewportRect = ExpandViewportRect(viewportRect, 0.05f);
                    pixelRect = ViewportToPixelRect(viewportRect, width, height);
                }
            }

            int cropW = Mathf.Clamp(Mathf.RoundToInt(pixelRect.width), 8, width);
            int cropH = Mathf.Clamp(Mathf.RoundToInt(pixelRect.height), 8, height);
            Texture2D tex = new Texture2D(cropW, cropH, TextureFormat.RGBA32, false);
            tex.ReadPixels(pixelRect, 0, 0, false);
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
            cam.rect = prevCamRect;
            if (isThumbnailCamera) cam.enabled = prevEnabled;
            RenderTexture.active = prevRT;
            RenderTexture.ReleaseTemporary(rt);
        }
    }

    // iOS calls this to capture and save a thumbnail to a file under Application.temporaryCachePath
    // message format: "relative|width|height|transparentFlag" (transparentFlag: 1=true, 0/absent=false)
    // Backwards compatible with message = relative only
    public void CaptureAvatarThumbnailToFile(string message)
    {
        StartCoroutine(CaptureThumbnailToFileCoroutine(message));
    }

    private IEnumerator CaptureThumbnailToFileCoroutine(string message)
    {
        // Parse message parts
        string relativePath = message;
        int reqW = -1, reqH = -1; bool transparent = false;
        var parts = message.Split('|');
        if (parts.Length >= 1) relativePath = parts[0];
        if (parts.Length >= 3)
        {
            int.TryParse(parts[1], out reqW);
            int.TryParse(parts[2], out reqH);
        }
        if (parts.Length >= 4) transparent = parts[3] == "1";
        // Pick a camera similar to CaptureThumbnailCoroutine, preferring "ThumbnailCamera"
        Camera cam = null;
        var thumbCamGO = GameObject.Find("ThumbnailCamera");
        if (thumbCamGO != null) cam = thumbCamGO.GetComponent<Camera>();
        var avatarCamGO = GameObject.Find("AvatarCamera");
        if (cam == null && avatarCamGO != null) cam = avatarCamGO.GetComponent<Camera>();
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

        int width = reqW > 0 ? Mathf.Clamp(reqW, 64, 4096) : Mathf.Clamp(Screen.width, 128, 4096);
        int height = reqH > 0 ? Mathf.Clamp(reqH, 64, 4096) : Mathf.Clamp(Screen.height, 128, 4096);

		var prevRT = RenderTexture.active;
        var prevCamRT = cam.targetTexture;
        var prevCamRect = cam.rect;
        bool isThumbnailCamera = cam.gameObject != null && cam.gameObject.name == "ThumbnailCamera";
        bool prevEnabled = cam.enabled;
        var prevClear = cam.clearFlags;
        var prevBG = cam.backgroundColor;
        float prevOrthoSize = cam.orthographic ? cam.orthographicSize : 0f;
        float prevAspect = cam.aspect;
        Vector3 prevPos = cam.transform.position; Quaternion prevRot = cam.transform.rotation;
        List<Renderer> disabledNonAvatarRenderers = null;
        RenderTexture rt = RenderTexture.GetTemporary(width, height, 24, RenderTextureFormat.ARGB32);
        try
        {
            // Ensure the thumbnail camera does not render to screen while capturing
            if (isThumbnailCamera) cam.enabled = false;
            // Render into full texture area regardless of scene viewport settings
            cam.rect = new Rect(0f, 0f, 1f, 1f);
            if (transparent)
            {
                cam.clearFlags = CameraClearFlags.SolidColor;
                cam.backgroundColor = new Color(0f, 0f, 0f, 0f);
            }

            // Hide all non-avatar renderers during capture to ensure transparency
            var mgr = assetManager != null ? assetManager : GameObject.FindObjectOfType<AssetManager>();
            if (mgr != null && mgr.avatarRoot != null)
            {
                disabledNonAvatarRenderers = new List<Renderer>();
                var allRenderers = GameObject.FindObjectsOfType<Renderer>(true);
                foreach (var r in allRenderers)
                {
                    if (r == null || !r.enabled) continue;
                    var t = r.transform;
                    bool underAvatar = t == mgr.avatarRoot || t.IsChildOf(mgr.avatarRoot);
                    if (!underAvatar)
                    {
                        r.enabled = false;
                        disabledNonAvatarRenderers.Add(r);
                    }
                }
            }

            // Frame avatar to fit requested aspect without cropping
            cam.aspect = (float)width / Mathf.Max(1, height);
            // Add more headroom to avoid top clipping at high FOV
            FrameAvatarForFullFigure(cam, 1.20f, 0.0f);
            // Ensure near clip doesn't cut off toes
            cam.nearClipPlane = Mathf.Min(cam.nearClipPlane, 0.01f);
            cam.targetTexture = rt;
            cam.Render();
            RenderTexture.active = rt;
            // No cropping – capture full RT to preserve full figure
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
            // Restore any renderers we hid and camera state
            if (disabledNonAvatarRenderers != null)
            {
                foreach (var r in disabledNonAvatarRenderers)
                {
                    if (r != null) r.enabled = true;
                }
            }
            cam.targetTexture = prevCamRT;
            cam.rect = prevCamRect;
            cam.clearFlags = prevClear;
            cam.backgroundColor = prevBG;
            if (cam.orthographic) cam.orthographicSize = prevOrthoSize;
            cam.aspect = prevAspect;
            cam.transform.SetPositionAndRotation(prevPos, prevRot);
            if (isThumbnailCamera) cam.enabled = prevEnabled;
            RenderTexture.active = prevRT;
            RenderTexture.ReleaseTemporary(rt);
        }
    }

    private bool TryComputeAvatarViewportRect(Camera cam, out Rect viewportRect)
    {
        viewportRect = new Rect(0, 0, 1, 1);
        if (cam == null) return false;
        var assetMgr = assetManager != null ? assetManager : GameObject.FindObjectOfType<AssetManager>();
        if (assetMgr == null || assetMgr.avatarRoot == null) return false;

        var renderers = assetMgr.avatarRoot.GetComponentsInChildren<Renderer>(true);
        if (renderers == null || renderers.Length == 0) return false;

        bool anyPoint = false;
        float minX = 1f, minY = 1f, maxX = 0f, maxY = 0f;

        foreach (var r in renderers)
        {
            if (r == null) continue;
            Bounds b = r.bounds;
            Vector3 c = b.center;
            Vector3 e = b.extents;
            // 8 corners of the bounds box
            Vector3[] corners = new Vector3[]
            {
                c + new Vector3( e.x,  e.y,  e.z),
                c + new Vector3( e.x,  e.y, -e.z),
                c + new Vector3( e.x, -e.y,  e.z),
                c + new Vector3( e.x, -e.y, -e.z),
                c + new Vector3(-e.x,  e.y,  e.z),
                c + new Vector3(-e.x,  e.y, -e.z),
                c + new Vector3(-e.x, -e.y,  e.z),
                c + new Vector3(-e.x, -e.y, -e.z)
            };
            foreach (var world in corners)
            {
                Vector3 vp = cam.WorldToViewportPoint(world);
                // consider only points in front of camera
                if (vp.z <= 0f) continue;
                anyPoint = true;
                minX = Mathf.Min(minX, vp.x);
                minY = Mathf.Min(minY, vp.y);
                maxX = Mathf.Max(maxX, vp.x);
                maxY = Mathf.Max(maxY, vp.y);
            }
        }

        if (!anyPoint) return false;
        // Clamp to [0,1]
        minX = Mathf.Clamp01(minX);
        minY = Mathf.Clamp01(minY);
        maxX = Mathf.Clamp01(maxX);
        maxY = Mathf.Clamp01(maxY);
        float w = Mathf.Max(0.01f, maxX - minX);
        float h = Mathf.Max(0.01f, maxY - minY);
        viewportRect = new Rect(minX, minY, w, h);
        return true;
    }

    private Rect ExpandViewportRect(Rect rect, float paddingFraction)
    {
        float cx = rect.x + rect.width * 0.5f;
        float cy = rect.y + rect.height * 0.5f;
        float w = rect.width * (1f + paddingFraction * 2f);
        float h = rect.height * (1f + paddingFraction * 2f);
        float x = cx - w * 0.5f;
        float y = cy - h * 0.5f;
        // Clamp to [0,1]
        float x0 = Mathf.Clamp01(x);
        float y0 = Mathf.Clamp01(y);
        float x1 = Mathf.Clamp01(x + w);
        float y1 = Mathf.Clamp01(y + h);
        return new Rect(x0, y0, Mathf.Max(0.01f, x1 - x0), Mathf.Max(0.01f, y1 - y0));
    }

    private Rect ViewportToPixelRect(Rect vp, int texWidth, int texHeight)
    {
        float px = vp.x * texWidth;
        // Flip Y because ReadPixels uses bottom-left origin and viewport.y is from bottom,
        // but we want the rect's bottom edge at (1 - (y + h)) in pixel space
        float py = (1f - (vp.y + vp.height)) * texHeight;
        float pw = vp.width * texWidth;
        float ph = vp.height * texHeight;
        return new Rect(Mathf.Round(px), Mathf.Round(py), Mathf.Round(pw), Mathf.Round(ph));
    }

    private void FrameAvatarForFullFigure(Camera cam, float padding, float verticalBias)
    {
        var mgr = assetManager != null ? assetManager : GameObject.FindObjectOfType<AssetManager>();
        if (mgr == null || mgr.avatarRoot == null || cam == null) return;

        var renderers = mgr.avatarRoot.GetComponentsInChildren<Renderer>(true);
        if (renderers == null || renderers.Length == 0) return;
        Bounds b = renderers[0].bounds;
        for (int i = 1; i < renderers.Length; i++) { if (renderers[i] != null) b.Encapsulate(renderers[i].bounds); }

        Vector3 center = b.center;
        // Apply a small vertical bias so composition feels centered by eye
        center.y += verticalBias * b.size.y;
        float height = Mathf.Max(0.01f, b.size.y) * padding;
        float width = Mathf.Max(0.01f, b.size.x) * padding;

        if (cam.orthographic)
        {
            float orthoForHeight = height * 0.5f;
            float orthoForWidth = (width * 0.5f) / Mathf.Max(0.01f, cam.aspect);
            cam.orthographicSize = Mathf.Max(orthoForHeight, orthoForWidth);
            cam.transform.LookAt(center);
        }
        else
        {
            float vFov = Mathf.Deg2Rad * Mathf.Max(1f, cam.fieldOfView);
            float distByHeight = (height * 0.5f) / Mathf.Tan(vFov * 0.5f);
            float hFov = 2f * Mathf.Atan(Mathf.Tan(vFov * 0.5f) * cam.aspect);
            float distByWidth = (width * 0.5f) / Mathf.Tan(hFov * 0.5f);
            float dist = Mathf.Max(distByHeight, distByWidth);
            Vector3 forward = cam.transform.forward.sqrMagnitude > 0.0001f ? cam.transform.forward : Vector3.forward;
            cam.transform.position = center - forward.normalized * dist;
            cam.transform.LookAt(center);
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
