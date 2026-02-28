//
//  UnityLauncher.m
//  UaaLHost
//
//  Bootstraps UnityFramework inside the host app and exposes a simple
//  Objective-C API that we can call from Swift/SwiftUI.
//

#if defined(EXCLUDE_UNITY)
// ── Stub implementation (no UnityFramework dependency) ──────────────
#import "UnityLauncher.h"

@implementation UnityLauncher

+ (instancetype)shared {
    static UnityLauncher *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [UnityLauncher new];
    });
    return instance;
}

- (void)launchUnityIfNeeded {
    NSLog(@"[UaaL-stub] launchUnityIfNeeded called – Unity excluded from this build");
}

- (void)showUnity {
    NSLog(@"[UaaL-stub] showUnity called – Unity excluded from this build");
}

- (void)hideUnity {
    NSLog(@"[UaaL-stub] hideUnity called – Unity excluded from this build");
}

- (UIViewController *)unityRootViewController {
    NSLog(@"[UaaL-stub] unityRootViewController called – returning nil");
    return nil;
}

- (void)sendMessageToUnity:(NSString *)gameObject method:(NSString *)method message:(NSString *)message {
    NSLog(@"[UaaL-stub] sendMessageToUnity called – Unity excluded from this build");
}

@end

#else
// ── Real implementation (links UnityFramework.framework) ────────────
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h> // << fix: use _NSGetMachExecuteHeader()
#import <dlfcn.h> // For dlsym and RTLD_DEFAULT

// Minimal forward declarations so we don't need UnityFramework headers at compile time
@protocol UnityFrameworkListener @end

@interface UnityFramework : NSObject
+ (UnityFramework *)getInstance;
- (id)appController;
- (void)runEmbeddedWithArgc:(int)argc argv:(char * _Nullable * _Nullable)argv appLaunchOpts:(NSDictionary *)launchOpts;
- (void)showUnityWindow;
- (void)setDataBundleId:(const char *)bundleId;
- (void)setExecuteHeader:(void *)header;
- (void)registerFrameworkListener:(id<UnityFrameworkListener>)listener;
@end

// Forward declaration of Unity's app controller type to access rootViewController
@interface UnityAppController : UIResponder
@property (nonatomic, readonly) UIViewController *rootViewController;
@end

@interface UnityLauncher : NSObject <UnityFrameworkListener>
+ (instancetype)shared;
- (void)launchUnityIfNeeded;
- (void)showUnity;
- (UIViewController *)unityRootViewController;
@end

static UnityFramework *_ufw = nil;

@implementation UnityLauncher

+ (instancetype)shared {
    static UnityLauncher *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [UnityLauncher new];
    });
    return instance;
}

- (UnityFramework *)loadUnityFramework {
    if (_ufw) return _ufw;

    // Load UnityFramework bundle from main app Frameworks/
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *ufwPath = [bundlePath stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework"];
    NSBundle *ufwBundle = [NSBundle bundleWithPath:ufwPath];
    if (![ufwBundle isLoaded]) {
        [ufwBundle load];
    }

    Class ufwClass = [ufwBundle principalClass];
    if (!ufwClass) {
        NSLog(@"[UaaL] Failed to get UnityFramework principal class");
        return nil;
    }

    UnityFramework *ufw = [ufwClass performSelector:@selector(getInstance)];
    if ([ufw appController] && _ufw) {
        return _ufw;
    }

    // Use dyld API to fetch the main image header (index 0)
    const struct mach_header *execHdr = _dyld_get_image_header(0);
    [ufw setExecuteHeader:(void *)execHdr];

    const char *mainBundleId = [[[NSBundle mainBundle] bundleIdentifier] UTF8String];
    [ufw setDataBundleId:mainBundleId];
    [ufw registerFrameworkListener:self];

    _ufw = ufw;
    return ufw;
}

- (void)launchUnityIfNeeded {
    UnityFramework *ufw = [self loadUnityFramework];
    if (!ufw) return;

    if (![ufw appController]) {
        // Build argc/argv from current process arguments so Unity gets valid pointers
        NSArray<NSString *> *arguments = [NSProcessInfo processInfo].arguments;
        int argc = (int)arguments.count;
        char **argv = (char **)calloc((size_t)argc, sizeof(char *));
        for (int i = 0; i < argc; ++i) {
            const char *utf8 = [arguments[i] UTF8String];
            argv[i] = strdup(utf8 ? utf8 : "");
        }

        NSDictionary *launchOpts = @{};

        [ufw runEmbeddedWithArgc:argc argv:argv appLaunchOpts:launchOpts];

        // Clean up our temporary argv copy
        for (int i = 0; i < argc; ++i) {
            free(argv[i]);
        }
        free(argv);
    }

    [ufw showUnityWindow];
}

- (void)showUnity {
    if (_ufw) {
        [_ufw showUnityWindow];
    } else {
        [self launchUnityIfNeeded];
    }
}

- (void)hideUnity {
    // Hide Unity by presenting an empty view controller over it or resigning key window if needed.
    // Since Unity is embedded, we'll just bring host UI forward; the floating window removal already reveals Unity.
    // No-op placeholder to keep API symmetry; actual hiding is managed by our UI layering.
}

- (UIViewController *)unityRootViewController {
    UnityAppController *controller = (UnityAppController *)[_ufw appController];
    return controller.rootViewController;
}

- (void)sendMessageToUnity:(NSString *)gameObject method:(NSString *)method message:(NSString *)message {
    if (_ufw && gameObject && method && message) {
        // Dynamically call UnitySendMessage at runtime
        void (*unitySendMessage)(const char*, const char*, const char*) = (void (*)(const char*, const char*, const char*))dlsym(RTLD_DEFAULT, "UnitySendMessage");
        if (unitySendMessage) {
            unitySendMessage([gameObject UTF8String], [method UTF8String], [message UTF8String]);
            NSLog(@"[UaaL] Sent message to Unity: GameObject=%@, Method=%@, Message=%@", gameObject, method, message);
        } else {
            NSLog(@"[UaaL] UnitySendMessage function not found");
        }
    } else {
        NSLog(@"[UaaL] Failed to send message to Unity - Unity not ready or invalid parameters");
    }
}

#pragma mark - UnityFrameworkListener

- (void)unityDidUnload:(NSNotification *)notification {
    // Unity was unloaded; clear handle
    _ufw = nil;
}

@end

#endif /* EXCLUDE_UNITY */
