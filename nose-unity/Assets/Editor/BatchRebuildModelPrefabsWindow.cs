using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public class BatchRebuildModelPrefabsWindow : EditorWindow
{
    private DefaultAsset targetFolder;
    private bool overwriteExisting = true;
    private bool preserveAssetLabels = true;
    private bool selectionOnly = false;

    [MenuItem("Tools/Nose/Batch Rebuild Model Prefabs")]
    private static void Open()
    {
        GetWindow<BatchRebuildModelPrefabsWindow>("Rebuild Model Prefabs");
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Rebuild Prefabs From FBX", EditorStyles.boldLabel);
        EditorGUILayout.HelpBox(
            "Creates or overwrites .prefab wrappers for FBX assets. Use this after re-exporting item FBXs from Blender with the new body skeleton.",
            MessageType.Info);

        targetFolder = (DefaultAsset)EditorGUILayout.ObjectField(
            new GUIContent("Target Folder", "Folder containing FBX assets to rebuild."),
            targetFolder,
            typeof(DefaultAsset),
            false);

        selectionOnly = EditorGUILayout.ToggleLeft("Use current Project selection only", selectionOnly);
        overwriteExisting = EditorGUILayout.ToggleLeft("Overwrite existing prefabs", overwriteExisting);
        preserveAssetLabels = EditorGUILayout.ToggleLeft("Preserve Unity asset labels", preserveAssetLabels);

        using (new EditorGUI.DisabledScope(!selectionOnly && targetFolder == null))
        {
            if (GUILayout.Button("Rebuild Prefabs"))
            {
                RebuildPrefabs();
            }
        }
    }

    private void RebuildPrefabs()
    {
        var fbxPaths = selectionOnly ? CollectSelectedFbxPaths() : CollectFbxPathsFromFolder();
        if (fbxPaths.Count == 0)
        {
            EditorUtility.DisplayDialog("Rebuild Model Prefabs", "No FBX assets found.", "OK");
            return;
        }

        int created = 0;
        int overwritten = 0;
        int skipped = 0;

        try
        {
            AssetDatabase.StartAssetEditing();

            for (int i = 0; i < fbxPaths.Count; i++)
            {
                string fbxPath = fbxPaths[i];
                EditorUtility.DisplayProgressBar("Rebuild Model Prefabs", fbxPath, (float)i / fbxPaths.Count);

                string prefabPath = Path.ChangeExtension(fbxPath, ".prefab");
                bool prefabExists = File.Exists(prefabPath);
                if (prefabExists && !overwriteExisting)
                {
                    skipped++;
                    continue;
                }

                string[] labels = prefabExists && preserveAssetLabels
                    ? AssetDatabase.GetLabels(AssetDatabase.LoadMainAssetAtPath(prefabPath))
                    : null;

                var source = AssetDatabase.LoadAssetAtPath<GameObject>(fbxPath);
                if (source == null)
                {
                    Debug.LogWarning($"[BatchRebuildModelPrefabs] Could not load FBX: {fbxPath}");
                    skipped++;
                    continue;
                }

                var instance = (GameObject)PrefabUtility.InstantiatePrefab(source);
                if (instance == null)
                {
                    Debug.LogWarning($"[BatchRebuildModelPrefabs] Could not instantiate FBX: {fbxPath}");
                    skipped++;
                    continue;
                }

                instance.name = Path.GetFileNameWithoutExtension(fbxPath);
                instance.transform.position = Vector3.zero;
                instance.transform.rotation = Quaternion.identity;
                instance.transform.localScale = Vector3.one;

                var saved = PrefabUtility.SaveAsPrefabAsset(instance, prefabPath);
                Object.DestroyImmediate(instance);

                if (saved == null)
                {
                    Debug.LogWarning($"[BatchRebuildModelPrefabs] Could not save prefab: {prefabPath}");
                    skipped++;
                    continue;
                }

                if (labels != null) AssetDatabase.SetLabels(saved, labels);

                if (prefabExists) overwritten++;
                else created++;
            }
        }
        finally
        {
            AssetDatabase.StopAssetEditing();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorUtility.ClearProgressBar();
        }

        Debug.Log($"[BatchRebuildModelPrefabs] Created: {created}, Overwritten: {overwritten}, Skipped: {skipped}");
        EditorUtility.DisplayDialog(
            "Rebuild Model Prefabs",
            $"Created: {created}\nOverwritten: {overwritten}\nSkipped: {skipped}",
            "OK");
    }

    private List<string> CollectFbxPathsFromFolder()
    {
        var results = new List<string>();
        if (targetFolder == null) return results;

        string folderPath = AssetDatabase.GetAssetPath(targetFolder);
        if (string.IsNullOrEmpty(folderPath) || !AssetDatabase.IsValidFolder(folderPath)) return results;

        foreach (string guid in AssetDatabase.FindAssets("t:Model", new[] { folderPath }))
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (path.EndsWith(".fbx", System.StringComparison.OrdinalIgnoreCase))
            {
                results.Add(path);
            }
        }

        results.Sort();
        return results;
    }

    private List<string> CollectSelectedFbxPaths()
    {
        var results = new HashSet<string>();

        foreach (var obj in Selection.objects)
        {
            string path = AssetDatabase.GetAssetPath(obj);
            if (string.IsNullOrEmpty(path)) continue;

            if (AssetDatabase.IsValidFolder(path))
            {
                foreach (string guid in AssetDatabase.FindAssets("t:Model", new[] { path }))
                {
                    string modelPath = AssetDatabase.GUIDToAssetPath(guid);
                    if (modelPath.EndsWith(".fbx", System.StringComparison.OrdinalIgnoreCase))
                    {
                        results.Add(modelPath);
                    }
                }
            }
            else if (path.EndsWith(".fbx", System.StringComparison.OrdinalIgnoreCase))
            {
                results.Add(path);
            }
        }

        var list = new List<string>(results);
        list.Sort();
        return list;
    }
}
