using UnityEngine;
using UnityEditor;
using System.IO;

/// <summary>
/// Helper script to set up Addressables for asset catalogs.
/// This script provides guidance on how to move JSON files to Addressables.
/// </summary>
public class AddressablesSetupHelper : MonoBehaviour
{
    [Header("Setup Instructions")]
    [TextArea(10, 20)]
    public string setupInstructions = @"
SETUP INSTRUCTIONS:

1. MOVE JSON FILES TO UNITY:
   - Copy these JSON files from nose/Assets/ to nose-unity/Assets/Resources/:
     * assets_base.json
     * assets_hair.json  
     * assets_clothes_tops.json
     * assets_clothes_socks.json
     * assets_accessories.json

2. MARK JSON FILES AS ADDRESSABLES:
   - In Unity, select each JSON file
   - In Inspector, check 'Addressable'
   - Set Address to:
     * assets_base.json → 'catalog/base'
     * assets_hair.json → 'catalog/hair'
     * assets_clothes_tops.json → 'catalog/clothes_tops'
     * assets_clothes_socks.json → 'catalog/clothes_socks'
     * assets_accessories.json → 'catalog/accessories'

3. BUILD ADDRESSABLES:
   - Window → Asset Management → Addressables → Groups
   - Click 'Build → New Build → Default Build Script'
   - This creates ServerData/iOS/ folder

4. UPLOAD TO FIREBASE HOSTING:
   - Upload ServerData/iOS/ contents to:
     https://nose-a2309.web.app/addressables/iOS/

5. REMOVE JSON FILES FROM XCODE:
   - Delete JSON files from nose/Assets/ folder
   - Clean and rebuild Xcode project

RESULT: Assets can now be updated without app updates!
";

    [Header("Current Status")]
    public bool jsonFilesInUnity = false;
    public bool jsonFilesMarkedAsAddressables = false;
    public bool addressablesBuilt = false;
    public bool uploadedToFirebase = false;

    private void Start()
    {
        CheckSetupStatus();
    }

    private void CheckSetupStatus()
    {
        // Check if JSON files exist in Unity
        jsonFilesInUnity = File.Exists(Path.Combine(Application.dataPath, "Resources", "assets_base.json"));
        
        // Note: The other checks would require Addressables API access at runtime
        // These are manual checks for now
    }

    [ContextMenu("Check Setup Status")]
    public void CheckSetupStatusManual()
    {
        CheckSetupStatus();
        Debug.Log($"Setup Status: JSON in Unity: {jsonFilesInUnity}");
    }

    [ContextMenu("Show Setup Instructions")]
    public void ShowSetupInstructions()
    {
        Debug.Log(setupInstructions);
    }
}

#if UNITY_EDITOR
[CustomEditor(typeof(AddressablesSetupHelper))]
public class AddressablesSetupHelperEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        
        AddressablesSetupHelper helper = (AddressablesSetupHelper)target;
        
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Quick Actions", EditorStyles.boldLabel);
        
        if (GUILayout.Button("Check Setup Status"))
        {
            helper.CheckSetupStatusManual();
        }
        
        if (GUILayout.Button("Show Instructions in Console"))
        {
            helper.ShowSetupInstructions();
        }
        
        EditorGUILayout.Space();
        EditorGUILayout.HelpBox(
            "After completing the setup, you can delete this helper script. " +
            "It's only needed during the migration process.", 
            MessageType.Info
        );
    }
}
#endif
