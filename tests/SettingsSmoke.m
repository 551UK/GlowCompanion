#import <UIKit/UIKit.h>
#import "../prefs/Preferences.h"
// The simulator harness supplies only the PreferenceLoader base class. It runs
// the exact production UIKit screen without requiring a jailbroken simulator.
@implementation PSViewController
@end
#import "../prefs/GIPRootListController.m"

@interface SmokeDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation SmokeDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)application; (void)options;
    GIPWriteEnabled(YES);
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    GIPRootListController *root = [GIPRootListController new];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:root];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        GIPSettingsTableController *screen = root.settingsController;
        BOOL passed = screen != nil && screen.tableView.numberOfSections == 3 &&
            [screen.tableView numberOfRowsInSection:0] == 1 &&
            [screen.tableView numberOfRowsInSection:1] == 5 &&
            [screen.tableView numberOfRowsInSection:2] == 1;
        passed &= screen.enabledSwitch.isOn && GIPReadEnabled();
        screen.enabledSwitch.on = NO;
        [screen.enabledSwitch sendActionsForControlEvents:UIControlEventValueChanged];
        passed &= !GIPReadEnabled();
        screen.enabledSwitch.on = YES;
        [screen.enabledSwitch sendActionsForControlEvents:UIControlEventValueChanged];
        passed &= GIPReadEnabled();
        [screen resetPosition];
        passed &= screen.positionSlider.value == 0 && [screen.offsetLabel.text isEqualToString:@"Default position (0 pt)"];
        [screen moveUp]; passed &= GIPReadOffset() == -10;
        [screen moveDown]; passed &= GIPReadOffset() == 0;
        screen.positionSlider.value = 175;
        [screen.positionSlider sendActionsForControlEvents:UIControlEventValueChanged];
        passed &= GIPReadOffset() == 175 && [screen.offsetLabel.text isEqualToString:@"175 pt down"];
        [screen resetPosition];
        [screen.tableView layoutIfNeeded];
        passed &= screen.enabledSwitch.window != nil && screen.positionSlider.window != nil && screen.positionSlider.bounds.size.width > 100;
        NSIndexPath *githubPath = [NSIndexPath indexPathForRow:0 inSection:2];
        UITableViewCell *github = [screen tableView:screen.tableView cellForRowAtIndexPath:githubPath];
        passed &= [github.textLabel.text isEqualToString:@"GitHub repository"];
        NSString *report = passed ? @"PASS: enable switch, visible settings table, slider, up/down, reset, persistence and GitHub row" : @"FAIL";
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/settings-smoke.txt"];
        [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    });
    return YES;
}
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(SmokeDelegate.class)); }
}
