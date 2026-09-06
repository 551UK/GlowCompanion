#import <UIKit/UIKit.h>
// Only the private Preferences declarations used by this bundle.
@interface PSSpecifier : NSObject
- (id)propertyForKey:(NSString *)key;
@end
@interface PSListController : UIViewController
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (void)reloadSpecifiers;
- (void)reloadSpecifierID:(NSString *)identifier animated:(BOOL)animated;
@end
