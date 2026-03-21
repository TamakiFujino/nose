using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class BatchCopyRigSourceWindow : EditorWindow
{
    private GameObject sourceModel;
    private DefaultAsset targetFolder;
    private bool selectionOnly = false;
    private bool forceHumanoid = true;

    [MenuItem("Tools/Nose/Batch Copy Body Rig Source")]
    private static void Open()
    {
        GetWindow<BatchCopyRigSourceWindow>("Copy Body Rig Source");
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Copy Body Rig Source", EditorStyles.boldLabel);
        EditorGUILayout.HelpBox(
            "Copies the selected source model's Avatar/Rig source to multiple FBX model importers. Use this when clothing/items should reference the same Body Avatar.",
            MessageType.Info);

        sourceModel = (GameObject)EditorGUILayout.ObjectField(
            new GUIContent("Source Body FBX", "Pick the body FBX asset that has the correct Avatar setup."),
            sourceModel,
            typeof(GameObject),
            false);

        targetFolder = (DefaultAsset)EditorGUILayout.ObjectField(
            new GUIContent("Target Folder", "Folder containing FBX assets to update."),
            targetFolder,
            typeof(DefaultAsset),
            false);

        selectionOnly = EditorGUILayout.ToggleLeft("Use current Project selection only", selectionOnly);
        forceHumanoid = EditorGUILayout.ToggleLeft("Force Humanoid + Copy From Other Avatar", forceHumanoid);

        using (new EditorGUI.DisabledScope(sourceModel == null || (!selectionOnly && targetFolder == null)))
        {
            if (GUILayout.Button("Copy Rig Source"))
            {
                CopyRigSource();
            }
        }
    }

    private void CopyRigSource()
    {
        string sourcePath = AssetDatabase.GetAssetPath(sourceModel);
        if (string.IsNullOrEmpty(sourcePath))
        {
            EditorUtility.DisplayDialog("Copy Body Rig Source", "Source Body FBX is not a valid asset.", "OK");
            return;
        }

        var sourceImporter = AssetImporter.GetAtPath(sourcePath) as ModelImporter;
        if (sourceImporter == null)
        {
            EditorUtility.DisplayDialog("Copy Body Rig Source", "Source asset is not a model importer.", "OK");
            return;
        }

        Avatar sourceAvatar = FindAvatarAtPath(sourcePath);
        if (sourceAvatar == null)
        {
            EditorUtility.DisplayDialog("Copy Body Rig Source", "Could not find an Avatar sub-asset on the source Body FBX.", "OK");
            return;
        }

        var targetPaths = selectionOnly ? CollectSelectedFbxPaths() : CollectFbxPathsFromFolder();
        if (targetPaths.Count == 0)
        {
            EditorUtility.DisplayDialog("Copy Body Rig Source", "No target FBX assets found.", "OK");
            return;
        }

        int updated = 0;
        int skipped = 0;

        try
        {
            AssetDatabase.StartAssetEditing();

            for (int i = 0; i < targetPaths.Count; i++)
            {
                string targetPath = targetPaths[i];
                EditorUtility.DisplayProgressBar("Copy Body Rig Source", targetPath, (float)i / targetPaths.Count);

                if (targetPath == sourcePath)
                {
                    skipped++;
                    continue;
                }

                var importer = AssetImporter.GetAtPath(targetPath) as ModelImporter;
                if (importer == null)
                {
                    skipped++;
                    continue;
                }

                if (forceHumanoid)
                {
                    importer.animationType = ModelImporterAnimationType.Human;
                    importer.avatarSetup = ModelImporterAvatarSetup.CopyFromOther;
                }

                importer.sourceAvatar = sourceAvatar;
                importer.SaveAndReimport();
                updated++;
            }
        }
        finally
        {
            AssetDatabase.StopAssetEditing();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorUtility.ClearProgressBar();
        }

        Debug.Log($"[BatchCopyRigSource] Updated: {updated}, Skipped: {skipped}, Source: {sourcePath}");
        EditorUtility.DisplayDialog(
            "Copy Body Rig Source",
            $"Updated: {updated}\nSkipped: {skipped}\nSource: {sourcePath}",
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

    private static Avatar FindAvatarAtPath(string assetPath)
    {
        foreach (var asset in AssetDatabase.LoadAllAssetsAtPath(assetPath))
        {
            if (asset is Avatar avatar) return avatar;
        }
        return null;
    }
}
