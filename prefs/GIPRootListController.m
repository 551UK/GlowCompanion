#import "Preferences.h"
#import "../PositionPreferences.h"

@interface GIPSettingsTableController : UITableViewController
@property(nonatomic, strong) UISlider *positionSlider;
@property(nonatomic, strong) UILabel *offsetLabel;
- (void)refreshPosition;
- (void)moveUp;
- (void)moveDown;
- (void)resetPosition;
@end

@implementation GIPSettingsTableController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.accessibilityIdentifier = @"GIPSettingsTable";
    self.tableView.rowHeight = 50;
    self.positionSlider = [[UISlider alloc] init];
    self.positionSlider.minimumValue = -75;
    self.positionSlider.maximumValue = 700;
    self.positionSlider.accessibilityLabel = @"Vertical icon offset";
    self.positionSlider.accessibilityIdentifier = @"GIPPositionSlider";
    [self.positionSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    self.offsetLabel = [[UILabel alloc] init];
    self.offsetLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.offsetLabel.textAlignment = NSTextAlignmentCenter;
    self.offsetLabel.accessibilityIdentifier = @"GIPCurrentOffset";
    [self refreshPosition];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshPosition];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; return section == 0 ? 5 : 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return section == 0 ? @"Icon position" : @"About";
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 1) return @"Moves all Glow notification icons together. Date, time and battery stay in place. Requires Glow. Made by 551.";
    return @"0 keeps the original working position. Negative values move up; positive values move down. Changes apply when Glow next appears, without another respring. The row stays within the screen edges.";
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView; return indexPath.section == 0 && indexPath.row == 1 ? 64 : 50;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (indexPath.section == 0 && indexPath.row < 2) {
        UIView *content = indexPath.row == 0 ? self.offsetLabel : self.positionSlider;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        content.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:content];
        [NSLayoutConstraint activateConstraints:@[
            [content.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [content.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [content.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor]
        ]];
    } else {
        cell.textLabel.textColor = self.view.tintColor;
        cell.accessibilityTraits |= UIAccessibilityTraitButton;
        if (indexPath.section == 1) {
            cell.textLabel.text = @"GitHub repository";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @[@"Move up 10 pt", @"Move down 10 pt", @"Reset to default position"][indexPath.row - 2];
        }
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/551UK/GlowCompanion"] options:@{} completionHandler:nil];
    } else if (indexPath.row == 2) { [self moveUp]; }
    else if (indexPath.row == 3) { [self moveDown]; }
    else if (indexPath.row == 4) { [self resetPosition]; }
}
- (void)refreshPosition {
    double value = GIPReadOffset();
    self.positionSlider.value = (float)value;
    self.offsetLabel.text = value == 0 ? @"Default position (0 pt)" : [NSString stringWithFormat:@"%.0f pt %@", fabs(value), value < 0 ? @"up" : @"down"];
}
- (void)sliderChanged:(UISlider *)slider { GIPWriteOffset(slider.value); [self refreshPosition]; }
- (void)moveUp { GIPWriteOffset(GIPReadOffset() - 10); [self refreshPosition]; }
- (void)moveDown { GIPWriteOffset(GIPReadOffset() + 10); [self refreshPosition]; }
- (void)resetPosition { GIPWriteOffset(0); [self refreshPosition]; }
@end

@interface GIPRootListController : PSViewController
@property(nonatomic, strong) GIPSettingsTableController *settingsController;
@end

@implementation GIPRootListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"GlowIconPosition";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.settingsController = [[GIPSettingsTableController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self addChildViewController:self.settingsController];
    UIView *tableView = self.settingsController.view;
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tableView];
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    [self.settingsController didMoveToParentViewController:self];
}
@end
