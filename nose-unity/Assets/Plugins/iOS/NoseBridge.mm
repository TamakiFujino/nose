#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Unity P/Invoke target. Lives inside UnityFramework so the symbol is always present.
// At runtime (UaaL), if the host app exposes UnityResponseHandler, we forward to it.
// Otherwise (standalone), we just log and no-op.
void Nose_OnUnityResponse(const char* json) {
    @autoreleasepool {
        if (json == NULL) {
            NSLog(@"[NoseBridge] Nose_OnUnityResponse called with null json");
            return;
        }
        NSString *jsonStr = [NSString stringWithUTF8String:json];

        Class handlerClass = NSClassFromString(@"UnityResponseHandler");
        if (handlerClass && [handlerClass respondsToSelector:@selector(handleUnityResponseStatic:)]) {
            // Forward to host app's Swift bridge if available
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [handlerClass performSelector:@selector(handleUnityResponseStatic:) withObject:jsonStr];
            #pragma clang diagnostic pop
        } else {
            NSLog(@"[NoseBridge] Host UnityResponseHandler not available; dropping response: %@", jsonStr);
        }
    }
}

#ifdef __cplusplus
}
#endif


