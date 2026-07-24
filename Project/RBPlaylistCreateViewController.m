#import "RBPlaylistCreateViewController.h"

#import "RBPlaylistManager.h"
#import "RBUserSettingData.h"
#import "neEngineBridge.h"

// The autoresizing mask applied to the root view: flexible width and flexible height.
static const UIViewAutoresizing kRootViewAutoresizing =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

// The title label point size.
static const CGFloat kTitleFontSize = 18.0;

// On the pad, when the view is taller than this the frame is clamped back to it in
// -viewWillAppear:.
static const CGFloat kPadFullHeightThreshold = 528.0; // @ghidraAddress 0x2fee00

// The text-field layout: it is inset ten points from the view's left and top, spans the view width
// less twice that inset, and is g_dLayoutMetricThirtyTwo points tall.
static const CGFloat kTextFieldInset = 10.0;

// The longest playlist name accepted by the text field.
static const NSUInteger kMaxPlaylistNameLength = 128;

// The system version at which the navigation bar switched from tintColor to barTintColor.
static const CGFloat kBarTintColorMinSystemVersion = 7.0;

// The newline the on-screen keyboard's return key inserts; a replacement equal to it is the commit
// gesture and is always allowed through.
static NSString *const kNewlineString = @"\n";

@implementation RBPlaylistCreateViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0x8f250 */
- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.opaque = YES;
    self.view.backgroundColor = UIColor.whiteColor;
    self.view.autoresizingMask = kRootViewAutoresizing;

    RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    if (theme == RBUserSettingDataThemeClassic) {
        self.titleColor = g_pPaletteWhiteColor;
        self.buttonColor = g_pPaletteOpaqueBlackColor;
        self.selectedRowColor = g_pPalettePurpleColor;
        if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
            self.navigationController.navigationBar.tintColor = UIColor.blackColor;
            self.navigationController.toolbar.tintColor = UIColor.blackColor;
        }
    } else if (theme == RBUserSettingDataThemeLimelight) {
        self.titleColor = g_pPaletteDarkGreenColor;
        self.buttonColor = g_pPaletteLeafGreenColor;
        self.selectedRowColor = g_pPaletteLeafGreenColor2;
        if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
            self.navigationController.navigationBar.tintColor = UIColor.whiteColor;
            self.navigationController.toolbar.tintColor = UIColor.whiteColor;
        }
    } else if (theme == RBUserSettingDataThemeColette) {
        self.titleColor = g_pPaletteSteelBlueColor;
        self.buttonColor = g_pPaletteLeafGreenColor3;
        self.selectedRowColor = g_pPaletteSteelBlueColor3;
        if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
            self.navigationController.navigationBar.tintColor = UIColor.whiteColor;
            self.navigationController.toolbar.tintColor = UIColor.whiteColor;
        }
    }

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor = self.titleColor;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:kTitleFontSize];
    self.titleLabel.backgroundColor = UIColor.clearColor;
    self.navigationItem.titleView = self.titleLabel;
    [self setTitle:g_pLocalizedCreatePlaylist];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(doneButtonPush:)];
    if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
        self.navigationItem.rightBarButtonItem.tintColor = self.buttonColor;
    }

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:g_pLocalizedReturn
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(backButtonPush:)];
    if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
        self.navigationItem.leftBarButtonItem.tintColor = self.buttonColor;
    }

    self.textField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.textField.borderStyle = UITextBorderStyleRoundedRect;
    self.textField.keyboardType = UIKeyboardTypeDefault;
    self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textField.placeholder = g_pLocalizedPlaylistName;
    self.textField.returnKeyType = UIReturnKeyDone;
    [self.textField addTarget:self
                       action:@selector(fieldChanged:)
             forControlEvents:UIControlEventEditingChanged];
    self.textField.delegate = self;
    [self.view addSubview:self.textField];
}

/** @ghidraAddress 0x90164 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];
    [self.navigationController setToolbarHidden:NO];

    if (IsPad() && self.view.bounds.size.height > kPadFullHeightThreshold) {
        self.view.frame = CGRectMake(self.view.frame.origin.x,
                                     self.view.frame.origin.y,
                                     self.view.frame.size.width,
                                     kPadFullHeightThreshold);
    }

    self.textField.frame = CGRectMake(kTextFieldInset,
                                      kTextFieldInset,
                                      self.view.frame.size.width - 2 * kTextFieldInset,
                                      g_dLayoutMetricThirtyTwo);
}

/** @ghidraAddress 0x90428 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.textField becomeFirstResponder];
}

/** @ghidraAddress 0x904ac */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.textField resignFirstResponder];
}

#pragma mark - Title

/** @ghidraAddress 0x8f158 */
- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    self.titleLabel.text = title;
    [self.titleLabel sizeToFit];
}

#pragma mark - Navigation-bar buttons

/** @ghidraAddress 0x90530 */
- (void)doneButtonPush:(id)sender {
    [self.textField resignFirstResponder];
    NSString *name = self.textField.text;
    NSString *trimmed =
        [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length != 0) {
        RBPlaylistManager *manager = [RBPlaylistManager sharedInstance];
        if ([manager addPlaylistWithName:name]) {
            [manager synchronize];
        }
    }
    [self.navigationController popViewControllerAnimated:YES];
}

/** @ghidraAddress 0x9070c */
- (void)backButtonPush:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Text field

/** @ghidraAddress 0x90778 */
- (void)fieldChanged:(id)sender {
    self.navigationItem.rightBarButtonItem.enabled = self.textField.text.length != 0;
}

/** @ghidraAddress 0x90890 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (self.textField.text.length != 0) {
        [self doneButtonPush:nil];
    }
    return YES;
}

/** @ghidraAddress 0x9094c */
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    if (self.textField != textField) {
        return NO;
    }
    if ([string compare:kNewlineString] == NSOrderedSame) {
        return YES;
    }
    NSUInteger newLength = (textField.text.length - range.length) + string.length;
    return newLength < kMaxPlaylistNameLength;
}

@end
