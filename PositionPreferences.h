#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

#define GIP_DOMAIN CFSTR("com.551.glowiconposition")
#define GIP_CHANGED CFSTR("com.551.glowiconposition/settingsChanged")
#define GIP_OFFSET_KEY CFSTR("verticalOffset")
#define GIP_ENABLED_KEY CFSTR("enabled")

static inline double GIPClampOffset(double value) {
    return isfinite(value) ? fmax(-75.0, fmin(700.0, round(value))) : 0.0;
}

static inline BOOL GIPReadEnabled(void) {
    CFPreferencesAppSynchronize(GIP_DOMAIN);
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(GIP_ENABLED_KEY, GIP_DOMAIN));
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : YES;
}

static inline void GIPWriteEnabled(BOOL enabled) {
    CFPreferencesSetAppValue(GIP_ENABLED_KEY, (__bridge CFBooleanRef)(enabled ? kCFBooleanTrue : kCFBooleanFalse), GIP_DOMAIN);
    CFPreferencesAppSynchronize(GIP_DOMAIN);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), GIP_CHANGED, NULL, NULL, true);
}

static inline double GIPReadOffset(void) {
    CFPreferencesAppSynchronize(GIP_DOMAIN);
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(GIP_OFFSET_KEY, GIP_DOMAIN));
    return [value isKindOfClass:[NSNumber class]] ? GIPClampOffset([value doubleValue]) : 0.0;
}

static inline void GIPWriteOffset(double value) {
    CFPreferencesSetAppValue(GIP_OFFSET_KEY, (__bridge CFNumberRef)@(GIPClampOffset(value)), GIP_DOMAIN);
    CFPreferencesAppSynchronize(GIP_DOMAIN);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), GIP_CHANGED, NULL, NULL, true);
}
