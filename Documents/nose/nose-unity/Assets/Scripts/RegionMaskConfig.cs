using System;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(menuName = "Nose/Region Mask Config", fileName = "RegionMaskConfig")]
public class RegionMaskConfig : ScriptableObject
{
    [Serializable]
    public class Group
    {
        [Tooltip("Addressables label to match, e.g., 'top-short'")]
        public string label;

        [Tooltip("Region names to hide when this label is present (matched against AssetManager.regionDefs names)")]
        public List<string> regionNames = new List<string>();

        [Tooltip("Optional: region IDs (if you prefer direct IDs instead of names)")]
        public List<int> regionIds = new List<int>();
    }

    public List<Group> groups = new List<Group>();

    // Build a mask for a label using name->id mapping provided by AssetManager
    public int BuildMaskForLabel(string label, Func<string, int?> tryResolveRegionNameToId)
    {
        if (string.IsNullOrEmpty(label)) return 0;
        Group g = groups.Find(x => string.Equals(x.label, label, StringComparison.OrdinalIgnoreCase));
        if (g == null) return 0;
        int mask = 0;
        foreach (var n in g.regionNames)
        {
            if (string.IsNullOrWhiteSpace(n)) continue;
            var id = tryResolveRegionNameToId?.Invoke(n.Trim());
            if (id.HasValue && id.Value >= 0 && id.Value <= 30)
            {
                mask |= (1 << id.Value);
            }
        }
        foreach (var id in g.regionIds)
        {
            if (id >= 0 && id <= 30) mask |= (1 << id);
        }
        return mask;
    }
}



