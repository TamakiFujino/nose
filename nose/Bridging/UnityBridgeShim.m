#import <Foundation/Foundation.h>
#if __has_include("nose-Swift.h")
#import "nose-Swift.h"
#endif

// This function is called by Unity to send responses back to iOS
void Nose_OnUnityResponse(const char* json) {
    @autoreleasepool {
        NSString *jsonStr = [NSString stringWithUTF8String:json];
#if __has_include("nose-Swift.h")
        // Forward to Swift via UnityResponseHandler when available in app target
        [UnityResponseHandler handleUnityResponseStatic:jsonStr];
#else
        // Fallback: post notification that the app observes and forwards to Swift
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NoseUnityResponseNotification"
                                                            object:nil
                                                          userInfo:@{ @"json": jsonStr ?: @"" }];
#endif
    }
}
