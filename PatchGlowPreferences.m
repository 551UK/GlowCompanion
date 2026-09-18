#import <Foundation/Foundation.h>
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
            if (![currentMax isKindOfClass:[NSNumber class]] || currentMax.doubleValue < 3.0) {
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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            return 64;
        }

        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSData *input = [NSData dataWithContentsOfFile:path];
        if (!input) {
            return 66;
        }

        NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
        NSError *error = nil;
        id plist = [NSPropertyListSerialization propertyListWithData:input
                                                            options:NSPropertyListMutableContainersAndLeaves
                                                             format:&format
                                                              error:&error];
        if (!plist || error) {
            return 65;
        }

        BOOL changed = NO;
        if (!PatchScaleSpecifier(plist, &changed)) {
            return 67;
        }

        if (!changed) {
            return 0;
        }

        NSData *output = [NSPropertyListSerialization dataWithPropertyList:plist
                                                                    format:format
                                                                   options:0
                                                                     error:&error];
        if (!output || error) {
            return 65;
        }

        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!handle) {
            return 73;
        }

        @try {
            [handle truncateFileAtOffset:0];
            [handle writeData:output];
            [handle synchronizeFile];
            [handle closeFile];
        } @catch (__unused NSException *exception) {
            return 74;
        }

        return 0;
    }
}
