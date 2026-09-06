#import "Preferences.h"
#import "../PositionPreferences.h"

@interface GIPRootListController : PSListController
@property(nonatomic, strong) NSArray *gipSpecifiers;
@end

@implementation GIPRootListController
- (NSArray *)specifiers {
    if (!self.gipSpecifiers)
        self.gipSpecifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return self.gipSpecifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    (void)specifier;
    return @(GIPReadOffset());
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    (void)specifier;
    if ([value respondsToSelector:@selector(doubleValue)]) GIPWriteOffset([value doubleValue]);
    [self reloadSpecifierID:@"CURRENT_POSITION" animated:NO];
}
- (id)currentPosition:(PSSpecifier *)specifier {
    (void)specifier;
    double offset = GIPReadOffset();
    if (offset == 0) return @"Default (0 pt)";
    return [NSString stringWithFormat:@"%.0f pt %@", fabs(offset), offset < 0 ? @"up" : @"down"];
}
- (void)moveUp { GIPWriteOffset(GIPReadOffset() - 10); self.gipSpecifiers = nil; [self reloadSpecifiers]; }
- (void)moveDown { GIPWriteOffset(GIPReadOffset() + 10); self.gipSpecifiers = nil; [self reloadSpecifiers]; }
- (void)resetPosition { GIPWriteOffset(0); self.gipSpecifiers = nil; [self reloadSpecifiers]; }
- (void)openGitHub {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/551UK/GlowCompanion"]
                                      options:@{} completionHandler:nil];
}
@end
