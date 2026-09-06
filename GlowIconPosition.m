#import <UIKit/UIKit.h>
#import <SpriteKit/SpriteKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <math.h>
#import "PositionPreferences.h"

static double verticalOffset;
static BOOL tweakEnabled = YES;
static __weak SKScene *lastScene;

// Glow 0.6-12 keeps all notification icons in this single SKNode ivar.
static Ivar iconsIvar;
static BOOL installed;
static void (*originalRepopulate)(id, SEL);
static void (*originalDidFinishUpdate)(id, SEL);
typedef void (*HookMessage)(Class, SEL, IMP, IMP *);

static void moveIcons(SKScene *scene);

static void preferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL wasEnabled = tweakEnabled;
        verticalOffset = GIPReadOffset();
        tweakEnabled = GIPReadEnabled();

        SKScene *scene = lastScene;
        if (!scene || !installed) return;

        if (tweakEnabled) {
            moveIcons(scene);
        } else if (wasEnabled && originalRepopulate) {
            // Rebuild Glow's icon row through the original implementation so
            // disabling the tweak immediately restores Glow's own placement.
            originalRepopulate(scene, sel_registerName("repopulateAppIcons"));
        }
    });
}

static void moveIcons(SKScene *scene) {
    if (!tweakEnabled) return;

    SKNode *icons = object_getIvar(scene, iconsIvar);
    SKView *view = scene.view;
    if (!icons || !view || !icons.parent || icons.children.count == 0) return;

    CGRect bounds = view.bounds;
    if (CGRectIsEmpty(bounds)) return;
    // Glow's overlay window may report a zero safe area. Keep a conservative
    // notch clearance in that case, including on the target iPhone 12 Pro Max.
    CGFloat safeTop = MAX(view.safeAreaInsets.top, view.window.safeAreaInsets.top);
    safeTop = MAX(safeTop, 59.0);
    // Convert the row's current accumulated frame to view coordinates so
    // badges and icon scaling are included in the clearance calculation.
    CGRect row = [icons calculateAccumulatedFrame]; // parent coordinates
    CGPoint upper = [scene convertPoint:CGPointMake(CGRectGetMidX(row), CGRectGetMaxY(row))
                              fromNode:icons.parent];
    CGPoint lower = [scene convertPoint:CGPointMake(CGRectGetMidX(row), CGRectGetMinY(row))
                              fromNode:icons.parent];
    CGFloat height = fabs([scene convertPointToView:upper].y -
                          [scene convertPointToView:lower].y);
    if (!isfinite(height) || height > bounds.size.height) return;
    CGFloat centerY = CGRectGetMinY(bounds) + safeTop + 16.0 + height / 2.0 + verticalOffset;
    // Clamp the entire row inside the visible screen while allowing movement
    // above the default notch clearance when explicitly requested.
    CGFloat minY = CGRectGetMinY(bounds) + 2.0 + height / 2.0;
    CGFloat maxY = CGRectGetMaxY(bounds) - MAX(view.safeAreaInsets.bottom, 8.0) - height / 2.0;
    if (maxY < minY) return;
    centerY = MIN(MAX(centerY, minY), maxY);
    if (centerY + height / 2.0 > CGRectGetMaxY(bounds)) return;
    CGPoint desired = [scene convertPointFromView:CGPointMake(CGRectGetMidX(bounds), centerY)];
    desired = [icons.parent convertPoint:desired fromNode:scene];
    // Position the visual row's center, accounting for asymmetric badges.
    CGPoint current = icons.position;
    desired.x -= CGRectGetMidX(row) - current.x;
    desired.y -= CGRectGetMidY(row) - current.y;
    if (!isfinite(desired.x) || !isfinite(desired.y)) return;
    if (fabs(current.x - desired.x) > 0.1 || fabs(current.y - desired.y) > 0.1)
        icons.position = desired;
}

static void repopulate(id self, SEL cmd) {
    lastScene = (SKScene *)self;
    originalRepopulate(self, cmd);
    moveIcons(self);
}

static void didFinishUpdate(id self, SEL cmd) {
    lastScene = (SKScene *)self;
    if (originalDidFinishUpdate) originalDidFinishUpdate(self, cmd);
    // SpriteKit invokes this after actions/constraints, so Glow's animations
    // cannot pull the icon row back to the center before rendering.
    moveIcons(self);
}

static void installHooks(void) {
    if (installed) return;
    Class cls = objc_getClass("GlowScene");
    if (!cls || ![cls isSubclassOfClass:[SKScene class]]) return;
    iconsIvar = class_getInstanceVariable(cls, "_appIconsNode");
    if (!iconsIvar || !class_getInstanceMethod(cls, sel_registerName("repopulateAppIcons")) ||
        !class_getInstanceMethod(cls, @selector(didFinishUpdate))) return;
    HookMessage hook = (HookMessage)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    if (!hook) {
        void *handle = dlopen("/var/jb/usr/lib/libsubstrate.dylib", RTLD_NOW);
        if (handle) hook = (HookMessage)dlsym(handle, "MSHookMessageEx");
    }
    if (!hook) { NSLog(@"[GlowIconPosition] Hook library unavailable"); return; }
    installed = YES;
    hook(cls, sel_registerName("repopulateAppIcons"), (IMP)repopulate, (IMP *)&originalRepopulate);
    hook(cls, @selector(didFinishUpdate), (IMP)didFinishUpdate, (IMP *)&originalDidFinishUpdate);
    NSLog(@"[GlowIconPosition] Notification icon positioning hooks installed");
}

static void imageAdded(const struct mach_header *header, intptr_t slide) {
    (void)slide;
    Dl_info info;
    if (!dladdr(header, &info) || !info.dli_fname) return;
    const char *name = strrchr(info.dli_fname, '/');
    name = name ? name + 1 : info.dli_fname;
    if (strcasecmp(name, "glow.dylib") == 0)
        dispatch_async(dispatch_get_main_queue(), ^{
            verticalOffset = GIPReadOffset();
            tweakEnabled = GIPReadEnabled();
            installHooks();
        });
}

__attribute__((constructor)) static void initialize(void) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, preferencesChanged, GIP_CHANGED, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    // Defer Objective-C lookups until runtime image registration completes.
    // The image callback also covers Glow loading after this companion.
    _dyld_register_func_for_add_image(imageAdded);
    dispatch_async(dispatch_get_main_queue(), ^{
        verticalOffset = GIPReadOffset();
        tweakEnabled = GIPReadEnabled();
        installHooks();
    });
}
