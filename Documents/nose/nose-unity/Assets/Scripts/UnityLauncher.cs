using UnityEngine;
using System.Runtime.InteropServices;

/// <summary>
/// UnityLauncher handles communication between Unity and iOS
/// This script enables two-way communication for the UnityBridge
/// </summary>
public class UnityLauncher : MonoBehaviour
{
    public static UnityLauncher Instance { get; private set; }

#if UNITY_IOS && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void Nose_OnUnityResponse(string json);
#endif

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

    /// <summary>
    /// Send data back to iOS
    /// </summary>
    /// <param name="method">The method name to call on iOS</param>
    /// <param name="message">The data to send</param>
    public void SendToIOS(string method, string message)
    {
#if UNITY_IOS && !UNITY_EDITOR
        // If we're sending a UnityResponse, pass through the payload directly
        // The message is already a JSON string with { callbackId, data }
        if (method == "UnityResponse")
        {
            Nose_OnUnityResponse(message);
            return;
        }
#endif
        // Wrap into a single JSON for the iOS bridge (used for editor/testing)
        var response = new UnityBridgeResponse { callbackId = method, data = message };
        string json = JsonUtility.ToJson(response);

#if UNITY_IOS && !UNITY_EDITOR
        Nose_OnUnityResponse(json);
#else
        Debug.Log($"[UnityLauncher] iOS bridge disabled or in Editor. Payload: {json}");
#endif
    }

    [System.Serializable]
    private class UnityBridgeResponse
    {
        public string callbackId;
        public string data;
    }
}
