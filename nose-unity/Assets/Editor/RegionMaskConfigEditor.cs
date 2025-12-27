using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(RegionMaskConfig))]
public class RegionMaskConfigEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        var cfg = (RegionMaskConfig)target;

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Preview in Scene", EditorStyles.boldLabel);

        AssetManager am = FindObjectOfType<AssetManager>();
        if (am == null)
        {
            EditorGUILayout.HelpBox("No AssetManager found in the open scene. Preview requires an AssetManager to apply the mask.", MessageType.Warning);
            return;
        }

        if (cfg.groups == null || cfg.groups.Count == 0)
        {
            EditorGUILayout.HelpBox("No groups defined.", MessageType.Info);
            return;
        }

        // Resolver from name -> id using the scene AssetManager mapping
        System.Func<string, int?> resolver = (name) =>
        {
            if (string.IsNullOrEmpty(name) || am.regionDefs == null) return null;
            var def = am.regionDefs.Find(r => string.Equals(r.name, name, System.StringComparison.OrdinalIgnoreCase));
            return def != null ? (int?)def.id : null;
        };

        for (int i = 0; i < cfg.groups.Count; i++)
        {
            var g = cfg.groups[i];
            if (g == null) continue;
            EditorGUILayout.BeginVertical("box");
            EditorGUILayout.LabelField(string.IsNullOrEmpty(g.label) ? $"Group {i}" : g.label, EditorStyles.boldLabel);

            EditorGUI.BeginDisabledGroup(true);
            EditorGUILayout.LabelField("Regions (names)", string.Join(", ", g.regionNames));
            EditorGUILayout.LabelField("Regions (ids)", string.Join(", ", g.regionIds));
            EditorGUI.EndDisabledGroup();

            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("Preview"))
            {
                int mask = cfg.BuildMaskForLabel(g.label, resolver);
                am.SetBodyRegionMask(mask);
                Debug.Log($"[RegionMaskConfig] Preview '{g.label}' → mask 0x{mask:X}");
            }
            if (GUILayout.Button("Clear"))
            {
                am.SetBodyRegionMask(0);
                Debug.Log("[RegionMaskConfig] Cleared region mask");
            }
            EditorGUILayout.EndHorizontal();
            EditorGUILayout.EndVertical();
        }

        EditorGUILayout.Space();
        if (GUILayout.Button("Clear All (Mask=0)"))
        {
            am.SetBodyRegionMask(0);
            Debug.Log("[RegionMaskConfig] Cleared all region masks (0)");
        }
    }
}



