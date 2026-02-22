using UnityEngine;

public class HorizontalRotateOnDrag : MonoBehaviour
{
    [Header("Target to rotate; defaults to this transform")]
    public Transform target;

    [Range(0.01f, 1f)]
    public float degreesPerPixel = 0.2f;

    public bool invert = false;
    public bool debugLog = false;

    private float lastMouseX;
    private bool mouseDragging;

    private void Awake()
    {
        if (target == null) target = transform;
        Input.simulateMouseWithTouches = true;
    }

    private void Update()
    {
        HandleMouseDrag();
        HandleTouchDrag();
    }

    private void HandleMouseDrag()
    {
        if (Input.GetMouseButtonDown(0))
        {
            mouseDragging = true;
            lastMouseX = Input.mousePosition.x;
            if (debugLog) Debug.Log("Mouse drag begin");
        }
        else if (Input.GetMouseButtonUp(0))
        {
            mouseDragging = false;
            if (debugLog) Debug.Log("Mouse drag end");
        }

        if (mouseDragging)
        {
            float x = Input.mousePosition.x;
            float deltaX = x - lastMouseX;
            lastMouseX = x;
            if (debugLog) Debug.Log($"Mouse deltaX: {deltaX}");
            RotateY(deltaX);
        }
    }

    private void HandleTouchDrag()
    {
        if (Input.touchCount == 0) return;
        Touch t = Input.GetTouch(0);
        if (debugLog && t.phase == TouchPhase.Began)
        {
            Debug.Log($"Touch begin: {t.position}");
        }
        if (t.phase == TouchPhase.Moved)
        {
            if (debugLog) Debug.Log($"Touch deltaX: {t.deltaPosition.x}");
            RotateY(t.deltaPosition.x);
        }
    }

    private void RotateY(float deltaPixelsX)
    {
        if (target == null) return;
        float sign = invert ? -1f : 1f;
        float angle = sign * deltaPixelsX * degreesPerPixel;
        target.Rotate(0f, angle, 0f, Space.World);
    }

    // Allows native layer to forward horizontal drag deltas to Unity directly
    public void ExternalDrag(float deltaPixelsX)
    {
        if (debugLog) Debug.Log($"External drag deltaX: {deltaPixelsX}");
        RotateY(deltaPixelsX);
    }
}


