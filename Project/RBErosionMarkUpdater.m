#import "RBErosionMarkUpdater.h"

#import "AppDelegate.h"
#import "RBCoreDataManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "ScoreData.h"

// Shared engine helpers and globals defined elsewhere in the binary.
extern double g_dTranslucentAlpha;
extern double g_dCustomizeLayoutMetric100;
extern NSString *const g_pLocalizedOK;
extern NSString *const g_pLocalizedCancel;
extern NSString *const g_pLocalizedRetry;
BOOL IsPad(void);

// Local declarations for the two sibling classes reconstructed separately. These members belong in
// the siblings' own headers (RBErosionMarkUpdaterAlertController and RBErosionMarkUpdaterScoreView).
@interface RBErosionMarkUpdaterAlertController : UIAlertController
@end

@interface RBErosionMarkUpdaterScoreView : UIView
@property(strong, nonatomic, nullable) UIView *dialogView;
@property(strong, nonatomic, nullable) UILabel *titleLabel;
@property(strong, nonatomic, nullable) UILabel *messageLabel;
- (nullable instancetype)initWithFrame:(CGRect)frame delegate:(nullable id)delegate;
- (void)showAnimation:(nullable void (^)(void))completion;
- (void)hideAnimation:(nullable void (^)(void))completion;
- (void)remove;
@end

/// The tune identifier of the erosion-mark record whose scores this dialog corrects.
static const unsigned int kErosionMarkTuneID = 99999344; // 0x5f5e470

/// Difficulty indices used for the score fields, pickers, and text-field tags.
enum {
    kDifficultyBasic = 0,
    kDifficultyMedium = 1,
    kDifficultyHard = 2,
};

/// The number of picker components (digits) per difficulty.
enum {
    kBasicDigitCount = 3,
    kMediumHardDigitCount = 4,
};

/// The number of rows in a digit picker component (0 through 9).
static const NSInteger kPickerDigitRowCount = 10;

/// Sentinel for @c activeFieldIndex meaning no field is being edited.
static const NSInteger kNoActiveField = -1;

/// The shared updater instance, allocated lazily by @c +updateCheckStart:.
/// @ghidraAddress 0x3de498
static RBErosionMarkUpdater *g_sharedUpdater = nil;

/// The lower score bounds per difficulty, seeded by the game before the dialog opens.
/// @ghidraAddress 0x3de4a0
static NSArray<NSNumber *> *g_lowerScoreBounds = nil;

/// The upper score bounds per difficulty, seeded by the game before the dialog opens.
/// @ghidraAddress 0x3de4a8
static NSArray<NSNumber *> *g_upperScoreBounds = nil;

@implementation RBErosionMarkUpdater

#pragma mark Entry point

+ (void)updateCheckStart:(RBViewController *)viewController {
    if (g_sharedUpdater == nil) {
        g_sharedUpdater = [[RBErosionMarkUpdater alloc] init];
    }
    if ([g_sharedUpdater needUpdateScore]) {
        g_sharedUpdater.viewController = viewController;
        g_sharedUpdater.displayRate = IsPad() ? 1.0 : g_dTranslucentAlpha;
        ScoreData *score = [g_sharedUpdater getScore];
        [g_sharedUpdater updateStartBasic:score.scoBas.integerValue
                                   Medium:score.scoMed.integerValue
                                     Hard:score.scoHar.integerValue];
    }
}

#pragma mark Setup

- (void)updateStartBasic:(NSInteger)basic Medium:(NSInteger)medium Hard:(NSInteger)hard {
    self.baseBasicScore = basic;
    self.editBasicScore = basic;
    self.baseMediumScore = medium;
    self.editMediumScore = medium;
    self.baseHardScore = hard;
    self.editHardScore = hard;
    [self setupView];
    [self showAlertSetScore];
}

- (void)setupView {
    CGRect frame = [AppDelegate appDelegate].viewController.view.frame;
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:frame];
    toolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *resetItem = [[UIBarButtonItem alloc] initWithTitle:@" "
                                                                  style:UIBarButtonItemStyleDone
                                                                 target:self
                                                                 action:@selector(reset)];
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:@" "
                                                                  style:UIBarButtonItemStyleDone
                                                                 target:self
                                                                 action:@selector(pickerClose)];
    toolbar.items = @[ resetItem, closeItem ];
    self.toolbar = toolbar;

    self.basicPickerView = [[UIPickerView alloc] init];
    self.basicPickerView.delegate = self;
    self.basicPickerView.tag = kDifficultyBasic;
    self.basicPickerView.showsSelectionIndicator = YES;
    [self setPickerViewScore:kDifficultyBasic score:self.baseBasicScore];

    self.mediumPickerView = [[UIPickerView alloc] init];
    self.mediumPickerView.delegate = self;
    self.mediumPickerView.tag = kDifficultyMedium;
    self.mediumPickerView.showsSelectionIndicator = YES;
    [self setPickerViewScore:kDifficultyMedium score:self.baseMediumScore];

    self.hardPickerView = [[UIPickerView alloc] init];
    self.hardPickerView.delegate = self;
    self.hardPickerView.tag = kDifficultyHard;
    self.hardPickerView.showsSelectionIndicator = YES;
    [self setPickerViewScore:kDifficultyHard score:self.baseHardScore];

    [self createAlertSetScore];
    [self createAlertCancel];
    [self createAlertConfirm];
}

#pragma mark Dialog

- (void)createAlertSetScore {
    NSString *title = [NSString stringWithFormat:@"スコアの確認"];
    if (NSClassFromString(@"UIAlertController") == nil) {
        self.alertSetScoreView =
            [[RBErosionMarkUpdaterScoreView alloc] initWithFrame:self.viewController.view.bounds
                                                        delegate:self];
        self.alertSetScoreView.titleLabel.text = title;

        UIView *container = [[UIView alloc]
            initWithFrame:CGRectMake(5.0, self.displayRate * 100.0, IsPad() ? 300.0 : 280.0, 0.0)];
        NSInteger bases[] = {self.baseBasicScore, self.baseMediumScore, self.baseHardScore};
        UIPickerView *pickers[] = {
            self.basicPickerView, self.mediumPickerView, self.hardPickerView};
        for (int difficulty = kDifficultyBasic; difficulty <= kDifficultyHard; ++difficulty) {
            if (bases[difficulty] != g_lowerScoreBounds[difficulty].integerValue) {
                continue;
            }
            UITextField *field =
                [[UITextField alloc] initWithFrame:CGRectMake(self.displayRate * 15.0,
                                                              container.frame.size.height + 5.0,
                                                              self.displayRate * 250.0,
                                                              self.displayRate * 30.0)];
            field.borderStyle = UITextBorderStyleLine;
            field.layer.borderColor =
                [UIColor colorWithWhite:g_dTranslucentAlpha alpha:1.0].CGColor;
            UILabel *label = [[UILabel alloc]
                initWithFrame:CGRectMake(10.0, 0.0, g_dCustomizeLayoutMetric100, 20.0)];
            label.font = [UIFont systemFontOfSize:14.0];
            label.text = @"";
            field.leftView = label;
            field.leftViewMode = UITextFieldViewModeAlways;
            field.text = [NSString stringWithFormat:@"%04zd", bases[difficulty]];
            field.inputAccessoryView = self.toolbar;
            field.inputView = pickers[difficulty];
            field.delegate = self;
            field.tag = difficulty;
            if (difficulty == kDifficultyBasic) {
                self.basicField = field;
            } else if (difficulty == kDifficultyMedium) {
                self.mediumField = field;
            } else {
                self.hardField = field;
            }
            container.frame = CGRectMake(container.frame.origin.x,
                                         container.frame.origin.y,
                                         self.displayRate * 260.0,
                                         container.frame.size.height + self.displayRate * 30.0);
            [container addSubview:field];
        }
        if (container.frame.size.height > 0.0) {
            [self.alertSetScoreView.dialogView addSubview:container];
        }
        return;
    }

    __weak RBErosionMarkUpdater *weakSelf = self;
    self.alertSetScoreController = [RBErosionMarkUpdaterAlertController
        alertControllerWithTitle:title
                         message:@"確認したいスコアを入力してください"
                  preferredStyle:UIAlertControllerStyleAlert];
    if (self.baseBasicScore == g_lowerScoreBounds[kDifficultyBasic].integerValue) {
        [self.alertSetScoreController
            addTextFieldWithConfigurationHandler:^(UITextField *textField) {
              /** @ghidraAddress 0x1463f8 */
              UILabel *label = [[UILabel alloc]
                  initWithFrame:CGRectMake(0.0, 0.0, g_dCustomizeLayoutMetric100, 20.0)];
              label.font = [UIFont systemFontOfSize:14.0];
              label.text = @"BASIC";
              textField.leftView = label;
              textField.leftViewMode = UITextFieldViewModeAlways;
              textField.text = [NSString stringWithFormat:@"%04zd", weakSelf.baseBasicScore];
              textField.inputAccessoryView = weakSelf.toolbar;
              textField.inputView = weakSelf.basicPickerView;
              textField.delegate = weakSelf;
              textField.tag = kDifficultyBasic;
              weakSelf.basicField = textField;
            }];
    }
    if (self.baseMediumScore == g_lowerScoreBounds[kDifficultyMedium].integerValue) {
        [self.alertSetScoreController
            addTextFieldWithConfigurationHandler:^(UITextField *textField) {
              /** @ghidraAddress 0x146524 */
              UILabel *label = [[UILabel alloc]
                  initWithFrame:CGRectMake(0.0, 0.0, g_dCustomizeLayoutMetric100, 20.0)];
              label.font = [UIFont systemFontOfSize:14.0];
              label.text = @"MEDIUM";
              textField.leftView = label;
              textField.leftViewMode = UITextFieldViewModeAlways;
              textField.text = [NSString stringWithFormat:@"%04zd", weakSelf.baseMediumScore];
              textField.inputAccessoryView = weakSelf.toolbar;
              textField.inputView = weakSelf.mediumPickerView;
              textField.delegate = weakSelf;
              textField.tag = kDifficultyMedium;
              weakSelf.mediumField = textField;
            }];
    }
    if (self.baseHardScore == g_lowerScoreBounds[kDifficultyHard].integerValue) {
        [self.alertSetScoreController
            addTextFieldWithConfigurationHandler:^(UITextField *textField) {
              /** @ghidraAddress 0x146658 */
              UILabel *label = [[UILabel alloc]
                  initWithFrame:CGRectMake(0.0, 0.0, g_dCustomizeLayoutMetric100, 20.0)];
              label.font = [UIFont systemFontOfSize:14.0];
              label.text = @"HARD";
              textField.leftView = label;
              textField.leftViewMode = UITextFieldViewModeAlways;
              textField.text = [NSString stringWithFormat:@"%04zd", weakSelf.baseHardScore];
              textField.inputAccessoryView = weakSelf.toolbar;
              textField.inputView = weakSelf.hardPickerView;
              textField.delegate = weakSelf;
              textField.tag = kDifficultyHard;
              weakSelf.hardField = textField;
            }];
    }
    [self.alertSetScoreController
        addAction:[UIAlertAction actionWithTitle:g_pLocalizedCancel
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction *action) {
                                           /** @ghidraAddress 0x146cbc */
                                           [self performSelector:@selector(showAlertCancel)
                                                      withObject:nil
                                                      afterDelay:0];
                                         }]];
    [self.alertSetScoreController
        addAction:[UIAlertAction actionWithTitle:g_pLocalizedOK
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                           /** @ghidraAddress 0x146cfc */
                                           [self performSelector:@selector(showAlertConfirm)
                                                      withObject:nil
                                                      afterDelay:0];
                                         }]];
}

- (void)createAlertCancel {
    NSString *title = [NSString stringWithFormat:@"確認の中止"];
    NSString *message = [NSString stringWithFormat:@"確認を中止してもよろしいですか？"];
    if (NSClassFromString(@"UIAlertController") == nil) {
        self.alertCancelView = [[UIAlertView alloc] initWithTitle:title
                                                          message:message
                                                         delegate:self
                                                cancelButtonTitle:g_pLocalizedRetry
                                                otherButtonTitles:g_pLocalizedOK, nil];
        return;
    }
    self.alertCancelController =
        [RBErosionMarkUpdaterAlertController alertControllerWithTitle:title
                                                              message:message
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [self.alertCancelController
        addAction:[UIAlertAction actionWithTitle:g_pLocalizedRetry
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                           /** @ghidraAddress 0x1470b4 */
                                           [self performSelector:@selector(showAlertSetScore)
                                                      withObject:nil
                                                      afterDelay:0];
                                         }]];
    [self.alertCancelController
        addAction:[UIAlertAction actionWithTitle:g_pLocalizedOK
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction *action) {
                                           /** @ghidraAddress 0x1470f4 */
                                           [self performSelector:@selector(updateCancel)
                                                      withObject:nil
                                                      afterDelay:0];
                                         }]];
}

- (void)createAlertConfirm {
    NSString *title = [NSString stringWithFormat:@"スコアの反映"];
    if (NSClassFromString(@"UIAlertController") == nil) {
        self.alertConfirmView = [[UIAlertView alloc] initWithTitle:title
                                                           message:@""
                                                          delegate:self
                                                 cancelButtonTitle:g_pLocalizedCancel
                                                 otherButtonTitles:g_pLocalizedOK, nil];
        return;
    }
    self.alertConfirmController =
        [RBErosionMarkUpdaterAlertController alertControllerWithTitle:title
                                                              message:@""
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [self.alertConfirmController
        addAction:[UIAlertAction actionWithTitle:g_pLocalizedCancel
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction *action) {
                                           /** @ghidraAddress 0x146cfc */
                                           [self performSelector:@selector(showAlertSetScore)
                                                      withObject:nil
                                                      afterDelay:0];
                                         }]];
    [self.alertConfirmController
        addAction:[UIAlertAction actionWithTitle:g_pLocalizedOK
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                           /** @ghidraAddress 0x1474a4 */
                                           [self performSelector:@selector(updatePerform)
                                                      withObject:nil
                                                      afterDelay:0];
                                         }]];
}

- (void)showAlertSetScore {
    if (NSClassFromString(@"UIAlertController") != nil) {
        [self.alertSetScoreController setMessage:@""];
        [[AppDelegate appDelegate].viewController presentViewController:self.alertSetScoreController
                                                               animated:YES
                                                             completion:nil];
        return;
    }
    __weak RBErosionMarkUpdater *weakSelf = self;
    self.alertSetScoreView.messageLabel.text = @"";
    [self.viewController.view addSubview:self.alertSetScoreView];
    [self.alertSetScoreView showAnimation:^{
      /** @ghidraAddress 0x14780c */
      [weakSelf pickerOpen];
    }];
}

- (void)reshowAlertSetScore:(NSString *)message {
    if (NSClassFromString(@"UIAlertController") == nil) {
        self.alertSetScoreView.messageLabel.text = message;
        [self.viewController.view addSubview:self.alertSetScoreView];
        [self.alertSetScoreView showAnimation:nil];
        return;
    }
    [self.alertSetScoreController setMessage:message];
    [[AppDelegate appDelegate].viewController presentViewController:self.alertSetScoreController
                                                           animated:YES
                                                         completion:nil];
}

- (void)showAlertCancel {
    if (NSClassFromString(@"UIAlertController") == nil) {
        [self pickerClose];
        [self.alertSetScoreView hideAnimation:nil];
        [self.alertCancelView show];
        return;
    }
    [[AppDelegate appDelegate].viewController presentViewController:self.alertCancelController
                                                           animated:YES
                                                         completion:nil];
}

- (void)showAlertConfirm {
    NSString *message = [self scoreValidate];
    if (message != nil) {
        [self reshowAlertSetScore:message];
        return;
    }
    NSMutableString *summary = [[NSMutableString alloc] init];
    if (self.baseBasicScore == g_lowerScoreBounds[kDifficultyBasic].integerValue) {
        [summary appendFormat:@"BASIC: %04zd → %04zd\n", self.baseBasicScore, self.editBasicScore];
    }
    if (self.baseMediumScore == g_lowerScoreBounds[kDifficultyMedium].integerValue) {
        [summary
            appendFormat:@"MEDIUM: %04zd → %04zd\n", self.baseMediumScore, self.editMediumScore];
    }
    if (self.baseHardScore == g_lowerScoreBounds[kDifficultyHard].integerValue) {
        [summary appendFormat:@"HARD: %04zd → %04zd\n", self.baseHardScore, self.editHardScore];
    }
    if (NSClassFromString(@"UIAlertController") == nil) {
        [self pickerClose];
        [self.alertSetScoreView hideAnimation:nil];
        [self.alertConfirmView setMessage:summary];
        [self.alertConfirmView show];
        return;
    }
    [self.alertConfirmController setMessage:summary];
    [[AppDelegate appDelegate].viewController presentViewController:self.alertConfirmController
                                                           animated:YES
                                                         completion:nil];
}

#pragma mark Editing

- (void)reset {
    switch (self.activeFieldIndex) {
    case kDifficultyHard:
        self.editHardScore = self.baseHardScore;
        self.hardField.text = [NSString stringWithFormat:@"%04zd", self.editHardScore];
        [self setPickerViewScore:kDifficultyHard score:self.baseHardScore];
        break;
    case kDifficultyMedium:
        self.editMediumScore = self.baseMediumScore;
        self.mediumField.text = [NSString stringWithFormat:@"%04zd", self.editMediumScore];
        [self setPickerViewScore:kDifficultyMedium score:self.baseMediumScore];
        break;
    case kDifficultyBasic:
        self.editBasicScore = self.baseBasicScore;
        self.basicField.text = [NSString stringWithFormat:@"%04zd", self.editBasicScore];
        [self setPickerViewScore:kDifficultyBasic score:self.baseBasicScore];
        break;
    default:
        break;
    }
}

- (void)pickerOpen {
    if (self.basicField != nil) {
        [self.basicField becomeFirstResponder];
    } else if (self.mediumField != nil) {
        [self.mediumField becomeFirstResponder];
    } else if (self.hardField != nil) {
        [self.hardField becomeFirstResponder];
    }
}

- (void)pickerClose {
    [self.basicField resignFirstResponder];
    [self.mediumField resignFirstResponder];
    [self.hardField resignFirstResponder];
}

- (NSInteger)getPickerViewScore:(int)difficulty {
    switch (difficulty) {
    case kDifficultyHard: {
        NSInteger thousands = [self.hardPickerView selectedRowInComponent:0];
        NSInteger hundreds = [self.hardPickerView selectedRowInComponent:1];
        NSInteger tens = [self.hardPickerView selectedRowInComponent:2];
        NSInteger ones = [self.hardPickerView selectedRowInComponent:3];
        return thousands * 1000 + hundreds * 100 + tens * 10 + ones;
    }
    case kDifficultyMedium: {
        NSInteger thousands = [self.mediumPickerView selectedRowInComponent:0];
        NSInteger hundreds = [self.mediumPickerView selectedRowInComponent:1];
        NSInteger tens = [self.mediumPickerView selectedRowInComponent:2];
        NSInteger ones = [self.mediumPickerView selectedRowInComponent:3];
        return thousands * 1000 + hundreds * 100 + tens * 10 + ones;
    }
    case kDifficultyBasic: {
        NSInteger hundreds = [self.basicPickerView selectedRowInComponent:0];
        NSInteger tens = [self.basicPickerView selectedRowInComponent:1];
        NSInteger ones = [self.basicPickerView selectedRowInComponent:2];
        return hundreds * 100 + tens * 10 + ones;
    }
    default:
        return 0;
    }
}

- (void)setPickerViewScore:(int)difficulty score:(NSInteger)score {
    switch (difficulty) {
    case kDifficultyHard:
        [self.hardPickerView selectRow:(score / 1000) % 10 inComponent:0 animated:NO];
        [self.hardPickerView selectRow:(score / 100) % 10 inComponent:1 animated:NO];
        [self.hardPickerView selectRow:(score / 10) % 10 inComponent:2 animated:NO];
        [self.hardPickerView selectRow:score % 10 inComponent:3 animated:NO];
        break;
    case kDifficultyMedium:
        [self.mediumPickerView selectRow:(score / 1000) % 10 inComponent:0 animated:NO];
        [self.mediumPickerView selectRow:(score / 100) % 10 inComponent:1 animated:NO];
        [self.mediumPickerView selectRow:(score / 10) % 10 inComponent:2 animated:NO];
        [self.mediumPickerView selectRow:score % 10 inComponent:3 animated:NO];
        break;
    case kDifficultyBasic:
        [self.basicPickerView selectRow:(score / 100) % 10 inComponent:0 animated:NO];
        [self.basicPickerView selectRow:(score / 10) % 10 inComponent:1 animated:NO];
        [self.basicPickerView selectRow:score % 10 inComponent:2 animated:NO];
        break;
    default:
        break;
    }
}

#pragma mark Persistence

- (BOOL)needUpdateScore {
    if ([RBUserSettingData sharedInstance].updatedErosionMark) {
        return NO;
    }
    NSManagedObjectContext *context = [RBCoreDataManager sharedInstance].managedObjectContext;
    ScoreData *score = [ScoreData getScoreData:kErosionMarkTuneID inManagedObjectContext:context];
    if (score.scoBas.integerValue == g_lowerScoreBounds[kDifficultyBasic].integerValue) {
        return YES;
    }
    if (score.scoMed.integerValue == g_lowerScoreBounds[kDifficultyMedium].integerValue) {
        return YES;
    }
    return score.scoHar.integerValue == g_lowerScoreBounds[kDifficultyHard].integerValue;
}

- (ScoreData *)getScore {
    NSManagedObjectContext *context = [RBCoreDataManager sharedInstance].managedObjectContext;
    return [ScoreData getScoreData:kErosionMarkTuneID inManagedObjectContext:context];
}

- (void)updateScore {
    NSManagedObjectContext *context = [RBCoreDataManager sharedInstance].managedObjectContext;
    ScoreData *score = [ScoreData getScoreData:kErosionMarkTuneID inManagedObjectContext:context];
    score.scoBas = @(self.editBasicScore);
    score.scoMed = @(self.editMediumScore);
    score.scoHar = @(self.editHardScore);
    score.chksco = [ScoreData hashScore:score];
    NSError *error = nil;
    if (![context save:&error]) {
        NSLog(@"%@", error.localizedDescription);
        return;
    }
    [RBUserSettingData sharedInstance].updatedErosionMark = YES;
    [[RBUserSettingData sharedInstance] save];
}

- (NSString *)scoreValidate {
    if (self.editBasicScore == self.baseBasicScore &&
        self.editMediumScore == self.baseMediumScore && self.editHardScore == self.baseHardScore) {
        return @"スコアが変更されていません。";
    }
    if (self.editBasicScore != self.baseBasicScore) {
        if (self.editBasicScore < g_lowerScoreBounds[kDifficultyBasic].integerValue ||
            g_upperScoreBounds[kDifficultyBasic].integerValue < self.editBasicScore) {
            return @"入力されたスコアが範囲外です。";
        }
    }
    if (self.editMediumScore != self.baseMediumScore) {
        if (self.editMediumScore < g_lowerScoreBounds[kDifficultyMedium].integerValue ||
            g_upperScoreBounds[kDifficultyMedium].integerValue < self.editMediumScore) {
            return @"入力されたスコアが範囲外です。";
        }
    }
    if (self.editHardScore != self.baseHardScore) {
        if (self.editHardScore < g_lowerScoreBounds[kDifficultyHard].integerValue ||
            g_upperScoreBounds[kDifficultyHard].integerValue < self.editHardScore) {
            return @"入力されたスコアが範囲外です。";
        }
    }
    return nil;
}

- (void)updatePerform {
    [self updateScore];
    [self remove];
    g_sharedUpdater = nil;
}

- (void)updateCancel {
    [self remove];
    [RBUserSettingData sharedInstance].updatedErosionMark = YES;
    [[RBUserSettingData sharedInstance] save];
    g_sharedUpdater = nil;
}

- (void)remove {
    self.basicPickerView.delegate = nil;
    self.basicPickerView = nil;
    self.mediumPickerView.delegate = nil;
    self.mediumPickerView = nil;
    self.hardPickerView.delegate = nil;
    self.hardPickerView = nil;
    self.toolbar.delegate = nil;
    self.toolbar = nil;
    if (NSClassFromString(@"UIAlertController") == nil) {
        [self.alertSetScoreView remove];
        self.alertSetScoreView = nil;
        self.alertCancelView.delegate = nil;
        self.alertCancelView = nil;
        self.alertConfirmView.delegate = nil;
        self.alertConfirmView = nil;
    } else {
        self.alertSetScoreController = nil;
        self.alertCancelController = nil;
        self.alertConfirmController = nil;
    }
    g_lowerScoreBounds = nil;
    g_upperScoreBounds = nil;
}

#pragma mark UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.activeFieldIndex = textField.tag;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.activeFieldIndex = kNoActiveField;
    [textField resignFirstResponder];
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    return NO;
}

#pragma mark UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    NSInteger tag = pickerView.tag;
    return (tag == kDifficultyMedium || tag == kDifficultyHard) ? kMediumHardDigitCount :
                                                                  kBasicDigitCount;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return kPickerDigitRowCount;
}

#pragma mark UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component {
    return [NSString stringWithFormat:@"%zd", row];
}

- (void)pickerView:(UIPickerView *)pickerView
      didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component {
    NSInteger score = [self getPickerViewScore:(int)pickerView.tag];
    if (pickerView.tag == kDifficultyMedium) {
        self.mediumField.text = [NSString stringWithFormat:@"%04zd", score];
        self.editMediumScore = score;
    } else if (pickerView.tag == kDifficultyHard) {
        self.hardField.text = [NSString stringWithFormat:@"%04zd", score];
        self.editHardScore = score;
    } else {
        self.basicField.text = [NSString stringWithFormat:@"%04zd", score];
        self.editBasicScore = score;
    }
}

#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.alertCancelView == alertView) {
        if (buttonIndex == 0) {
            [self reshowAlertSetScore:nil];
        } else {
            [self updateCancel];
        }
    } else if (self.alertConfirmView == alertView) {
        if (buttonIndex == 0) {
            [self reshowAlertSetScore:nil];
        } else {
            [self updatePerform];
        }
    }
}

@end
