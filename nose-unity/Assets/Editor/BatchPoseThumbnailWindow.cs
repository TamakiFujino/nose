using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Animations;
using UnityEngine.Playables;

/// <summary>
/// Generates pose thumbnails in Play Mode by applying each pose via PlayableGraph
/// (the same way the app does at runtime) and capturing a screenshot.
/// Accessible via Tools > Nose > Batch Generate Pose Thumbnails.
/// </summary>
public class BatchPoseThumbnailWindow : EditorWindow
{
    private int thumbnailSize = 512;
    private float paddingFactor = 1.3f;
    private bool overwriteExisting = true;
    private string outputFolder = "Assets/Thumbnails";

    [MenuItem("Tools/Nose/Batch Generate Pose Thumbnails")]
    private static void Open()
    {
        GetWindow<BatchPoseThumbnailWindow>("Pose Thumbnails");
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Batch Pose Thumbnail Generator", EditorStyles.boldLabel);
        EditorGUILayout.HelpBox(
            "Generates PNG thumbnails for each pose in AssetManager.poses.\n" +
            "Must be in PLAY MODE. Open SampleScene, enter Play Mode, then click Generate.",
            MessageType.Info);

        thumbnailSize = EditorGUILayout.IntField("Thumbnail Size (px)", thumbnailSize);
        thumbnailSize = Mathf.Clamp(thumbnailSize, 64, 2048);

        paddingFactor = EditorGUILayout.Slider("Padding Factor", paddingFactor, 1.0f, 2.0f);
        overwriteExisting = EditorGUILayout.ToggleLeft("Overwrite existing thumbnails", overwriteExisting);
        outputFolder = EditorGUILayout.TextField("Output Folder", outputFolder);

        EditorGUILayout.Space();

        if (!EditorApplication.isPlaying)
        {
            EditorGUILayout.HelpBox("Enter Play Mode first, then click Generate.", MessageType.Warning);
            GUI.enabled = false;
        }

        if (GUILayout.Button("Generate Pose Thumbnails"))
        {
            StartGeneration();
        }

        GUI.enabled = true;
    }

    private void StartGeneration()
    {
        if (!EditorApplication.isPlaying)
        {
            EditorUtility.DisplayDialog("Pose Thumbnails", "Enter Play Mode first.", "OK");
            return;
        }

        var runner = new GameObject("_PoseThumbnailRunner").AddComponent<PoseThumbnailRunner>();
        runner.thumbnailSize = thumbnailSize;
        runner.paddingFactor = paddingFactor;
        runner.overwriteExisting = overwriteExisting;
        runner.outputFolder = outputFolder;
        runner.StartCoroutine(runner.GenerateAll());
    }
}

/// <summary>
/// Temporary MonoBehaviour that runs in Play Mode to generate pose thumbnails.
/// Applies each pose via PlayableGraph (same as ApplyBodyPose), waits a frame, captures.
/// Destroys itself when done.
/// </summary>
public class PoseThumbnailRunner : MonoBehaviour
{
    public int thumbnailSize = 512;
    public float paddingFactor = 1.3f;
    public bool overwriteExisting = true;
    public string outputFolder = "Assets/Thumbnails";

    public IEnumerator GenerateAll()
    {
        // Wait a frame for play mode to fully initialize
        yield return null;

        var assetManager = FindObjectOfType<AssetManager>();
        if (assetManager == null)
        {
            Debug.LogError("[PoseThumbnails] AssetManager not found.");
            DestroyImmediate(gameObject);
            yield break;
        }

        var poses = assetManager.poses;
        if (poses == null || poses.Count == 0)
        {
            Debug.LogError("[PoseThumbnails] AssetManager.poses is empty.");
            DestroyImmediate(gameObject);
            yield break;
        }

        var thumbCamGO = GameObject.Find("ThumbnailCamera");
        if (thumbCamGO == null)
        {
            Debug.LogError("[PoseThumbnails] ThumbnailCamera not found in scene.");
            DestroyImmediate(gameObject);
            yield break;
        }
        var cam = thumbCamGO.GetComponent<Camera>();

        Animator animator = FindHumanoidAnimator(assetManager);
        if (animator == null)
        {
            Debug.LogError("[PoseThumbnails] No humanoid Animator found.");
            DestroyImmediate(gameObject);
            yield break;
        }

        Debug.Log($"[PoseThumbnails] Using Animator on '{animator.gameObject.name}' " +
            $"(isHuman={animator.isHuman}, avatar={animator.avatar?.name ?? "null"})");
        Debug.Log($"[PoseThumbnails] Processing {poses.Count} poses...");

        Transform renderRoot = animator.transform;
        var avatarRoot = assetManager.avatarRoot;
        int generated = 0, skipped = 0, errors = 0;

        PlayableGraph poseGraph = default;

        for (int i = 0; i < poses.Count; i++)
        {
            var def = poses[i];
            if (def == null || def.clip == null || string.IsNullOrEmpty(def.name))
            {
                errors++;
                continue;
            }

            string pngPath = Path.Combine(outputFolder, "Base", "Body", def.name + ".png");
            if (!overwriteExisting && File.Exists(pngPath))
            {
                skipped++;
                continue;
            }

            // Tear down previous graph
            if (poseGraph.IsValid())
                poseGraph.Destroy();

            // Apply pose via PlayableGraph — same as AssetManager.ApplyBodyPose
            poseGraph = PlayableGraph.Create("PoseThumbnail");
            poseGraph.SetTimeUpdateMode(DirectorUpdateMode.GameTime);

            var clipPlayable = AnimationClipPlayable.Create(poseGraph, def.clip);
            clipPlayable.SetApplyFootIK(true);
            clipPlayable.SetTime(0.0);
            clipPlayable.SetSpeed(0.0); // hold at first frame

            var output = AnimationPlayableOutput.Create(poseGraph, "PoseOutput", animator);
            output.SetSourcePlayable(clipPlayable);

            animator.enabled = true;
            poseGraph.Play();
            animator.Update(0f);

            // Wait a frame so Unity processes the pose and updates renderers
            yield return null;

            // Find renderers for bounds
            Renderer[] renderers = renderRoot.GetComponentsInChildren<Renderer>(true);
            if ((renderers == null || renderers.Length == 0) && avatarRoot != null)
                renderers = avatarRoot.GetComponentsInChildren<Renderer>(true);
            if (renderers == null || renderers.Length == 0)
            {
                Debug.LogWarning($"[PoseThumbnails] No renderers for pose '{def.name}'");
                errors++;
                continue;
            }

            Bounds bounds = ComputeBounds(renderers);
            FrameCamera(cam, bounds);

            // Hide all scene renderers except the body so background is transparent
            var bodyRendererSet = new HashSet<Renderer>(renderers);
            var allRenderers = FindObjectsOfType<Renderer>(true);
            var hiddenRenderers = new List<Renderer>();
            foreach (var r in allRenderers)
            {
                if (!bodyRendererSet.Contains(r) && r.enabled)
                {
                    r.enabled = false;
                    hiddenRenderers.Add(r);
                }
            }

            // Wait another frame so camera position is applied before render
            yield return null;

            if (RenderToPNG(cam, pngPath))
                generated++;
            else
                errors++;

            // Restore hidden renderers
            foreach (var r in hiddenRenderers)
            {
                if (r != null) r.enabled = true;
            }
        }

        // Cleanup
        if (poseGraph.IsValid())
            poseGraph.Destroy();

        Debug.Log($"[PoseThumbnails] Done! Generated: {generated}, Skipped: {skipped}, Errors: {errors}");
        EditorUtility.DisplayDialog("Pose Thumbnails",
            $"Generated: {generated}\nSkipped: {skipped}\nErrors: {errors}", "OK");

        DestroyImmediate(gameObject);
    }

    private Animator FindHumanoidAnimator(AssetManager assetManager)
    {
        var candidates = new List<Animator>();
        var avatarRoot = assetManager.avatarRoot;

        if (avatarRoot != null)
        {
            var a = avatarRoot.GetComponent<Animator>();
            if (a != null) candidates.Add(a);
            foreach (var c in avatarRoot.GetComponentsInChildren<Animator>(true))
                if (!candidates.Contains(c)) candidates.Add(c);
            var p = avatarRoot.GetComponentInParent<Animator>();
            if (p != null && !candidates.Contains(p)) candidates.Add(p);
        }
        foreach (var a in FindObjectsOfType<Animator>(true))
            if (!candidates.Contains(a)) candidates.Add(a);

        foreach (var a in candidates)
            if (a.avatar != null && a.isHuman) return a;
        foreach (var a in candidates)
            if (a.avatar != null) return a;
        return candidates.Count > 0 ? candidates[0] : null;
    }

    private void FrameCamera(Camera cam, Bounds bounds)
    {
        Vector3 center = bounds.center;
        float height = Mathf.Max(0.01f, bounds.size.y) * paddingFactor;
        float width = Mathf.Max(0.01f, bounds.size.x) * paddingFactor;
        float depth = Mathf.Max(0.01f, bounds.size.z) * paddingFactor;

        cam.aspect = 1f;

        if (cam.orthographic)
        {
            cam.orthographicSize = Mathf.Max(height, width) * 0.5f;
        }

        float safeDistance = Mathf.Max(height, width, depth) * 2f;
        Vector3 forward = cam.transform.forward.sqrMagnitude > 0.0001f ? cam.transform.forward : Vector3.forward;
        cam.transform.position = center - forward.normalized * safeDistance;
        cam.transform.LookAt(center);
        cam.nearClipPlane = Mathf.Min(cam.nearClipPlane, 0.01f);
    }

    private bool RenderToPNG(Camera cam, string pngPath)
    {
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
            cam.enabled = false;
            cam.cullingMask = -1;
            cam.rect = new Rect(0f, 0f, 1f, 1f);
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0f, 0f, 0f, 0f);

            cam.targetTexture = rt;
            cam.Render();

            RenderTexture.active = rt;
            Texture2D tex = new Texture2D(size, size, TextureFormat.RGBA32, false);
            tex.ReadPixels(new Rect(0, 0, size, size), 0, 0, false);
            tex.Apply(false, false);

            var pixels = tex.GetPixels32();
            for (int i = 0; i < pixels.Length; i++)
            {
                if (pixels[i].r > 0 || pixels[i].g > 0 || pixels[i].b > 0)
                    pixels[i].a = 255;
            }
            tex.SetPixels32(pixels);
            tex.Apply(false, false);

            byte[] png = ImageConversion.EncodeToPNG(tex);
            DestroyImmediate(tex);

            string dir = Path.GetDirectoryName(pngPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            File.WriteAllBytes(pngPath, png);
            Debug.Log($"[PoseThumbnails] Saved: {pngPath}");
            return true;
        }
        catch (System.Exception e)
        {
            Debug.LogError($"[PoseThumbnails] Failed to render {pngPath}: {e.Message}");
            return false;
        }
        finally
        {
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
}
