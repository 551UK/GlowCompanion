#import <UIKit/UIKit.h>
#import <SpriteKit/SpriteKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <math.h>

// Glow 0.6-12 keeps all notification icons in this single SKNode ivar.
static Ivar iconsIvar;
static BOOL installed;
static void (*originalRepopulate)(id, SEL);
static void (*originalDidFinishUpdate)(id, SEL);
typedef void (*HookMessage)(Class, SEL, IMP, IMP *);

static void moveIcons(SKScene *scene) {
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
    CGFloat centerY = CGRectGetMinY(bounds) + safeTop + 16.0 + height / 2.0;
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
    originalRepopulate(self, cmd);
    moveIcons(self);
}

static void didFinishUpdate(id self, SEL cmd) {
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
    NSLog(@"[GlowIconPosition] Notification icon positioning enabled");
}

static void imageAdded(const struct mach_header *header, intptr_t slide) {
    (void)slide;
    Dl_info info;
    if (!dladdr(header, &info) || !info.dli_fname) return;
    const char *name = strrchr(info.dli_fname, '/');
    name = name ? name + 1 : info.dli_fname;
    if (strcasecmp(name, "glow.dylib") == 0)
        dispatch_async(dispatch_get_main_queue(), ^{ installHooks(); });
}

__attribute__((constructor)) static void initialize(void) {
    // Defer Objective-C lookups until runtime image registration completes.
    // The image callback also covers Glow loading after this companion.
    _dyld_register_func_for_add_image(imageAdded);
    dispatch_async(dispatch_get_main_queue(), ^{ installHooks(); });
}
