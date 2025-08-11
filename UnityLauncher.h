//
//  UnityLauncher.h
//  UaaLHostFinal
//
//  Created by Momin Aman on 8/9/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UnityLauncher : NSObject
+ (instancetype)shared;
- (void)launchUnityIfNeeded;
- (void)showUnity;
- (UIViewController *)unityRootViewController;
- (void)sendMessageToUnity:(NSString *)gameObject method:(NSString *)method message:(NSString *)message;
@end

NS_ASSUME_NONNULL_END
