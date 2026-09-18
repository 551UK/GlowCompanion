#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>

static BOOL PatchScaleSpecifier(id object, BOOL *changed) {
    BOOL found = NO;

    if ([object isKindOfClass:[NSMutableDictionary class]]) {
        NSMutableDictionary *dictionary = (NSMutableDictionary *)object;
        NSString *identifier = dictionary[@"id"];
        NSString *key = dictionary[@"key"];

        if ([identifier isEqualToString:@"ICONS_SCALE"] || [key isEqualToString:@"iconsScale"]) {
            found = YES;

            NSNumber *currentMax = dictionary[@"max"];
            if (![currentMax isKindOfClass:[NSNumber class]] || fabs(currentMax.doubleValue - 3.0) > 0.0001) {
                dictionary[@"max"] = @3.0;
                *changed = YES;
            }

            NSNumber *currentDefault = dictionary[@"default"];
            if (![currentDefault isKindOfClass:[NSNumber class]] || fabs(currentDefault.doubleValue - 2.20) > 0.0001) {
                dictionary[@"default"] = @2.20;
                *changed = YES;
            }
        }

        for (id value in dictionary.allValues) {
            if (PatchScaleSpecifier(value, changed)) {
                found = YES;
            }
        }
    } else if ([object isKindOfClass:[NSMutableArray class]]) {
        for (id value in (NSMutableArray *)object) {
            if (PatchScaleSpecifier(value, changed)) {
                found = YES;
            }
        }
    }

    return found;
}

static BOOL PatchGlowSpecifierFile(NSString *path) {
    NSData *input = [NSData dataWithContentsOfFile:path];
    if (!input) return NO;

    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:input
                                                        options:NSPropertyListMutableContainersAndLeaves
                                                         format:&format
                                                          error:&error];
    if (!plist || error) return NO;

    BOOL changed = NO;
    if (!PatchScaleSpecifier(plist, &changed)) return NO;
    if (!changed) return YES;

    NSData *output = [NSPropertyListSerialization dataWithPropertyList:plist
                                                                format:format
                                                               options:0
                                                                 error:&error];
    if (!output || error) return NO;

    return [output writeToFile:path options:NSDataWritingAtomic error:&error] && !error;
}

static BOOL ReadDouble(CFTypeRef value, double *result) {
    if (!value || CFGetTypeID(value) != CFNumberGetTypeID()) return NO;
    return CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, result);
}

static void SetGlowSavedScale(void) {
    CFStringRef appID = CFSTR("net.limneos.glow");
    CFStringRef key = CFSTR("iconsScale");
    CFStringRef mobileUser = CFSTR("mobile");

    CFPropertyListRef existing = CFPreferencesCopyValue(key,
                                                       appID,
                                                       mobileUser,
                                                       kCFPreferencesAnyHost);

    BOOL shouldSet = existing == NULL;
    double current = 0.0;
    if (ReadDouble(existing, &current)) {
        // Replace Glow's untouched/default value but preserve a user's custom scale.
        shouldSet = fabs(current - 1.30) < 0.0001;
    }

    if (shouldSet) {
        double target = 2.20;
        CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &target);
        if (value) {
            CFPreferencesSetValue(key,
                                  value,
                                  appID,
                                  mobileUser,
                                  kCFPreferencesAnyHost);
            CFPreferencesSynchronize(appID,
                                     mobileUser,
                                     kCFPreferencesAnyHost);
            CFRelease(value);

            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                 CFSTR("net.limneos.glow.settingsChanged"),
                                                 NULL,
                                                 NULL,
                                                 true);
        }
    }

    if (existing) CFRelease(existing);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 64;

        NSString *path = [NSString stringWithUTF8String:argv[1]];
        if (!PatchGlowSpecifierFile(path)) return 65;

        SetGlowSavedScale();
        return 0;
    }
}
