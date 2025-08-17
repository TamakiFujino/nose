#import <Foundation/Foundation.h>
#import "nose-Swift.h"

// This function is called by Unity to send responses back to iOS
void Nose_OnUnityResponse(const char* json) {
    @autoreleasepool {
        NSString *jsonStr = [NSString stringWithUTF8String:json];
        
        // Forward to Swift via UnityResponseHandler
        [UnityResponseHandler handleUnityResponseStatic:jsonStr];
    }
}
