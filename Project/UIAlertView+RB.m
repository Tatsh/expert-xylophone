//
//  UIAlertView+RB.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (category UIAlertView(RB)). Verified
//  against the arm64 disassembly: -initWithTitle:message:delegate:cancelButtonTitle:
//  otherButtonTitles: is variadic, so the decompiler drops or reorders its trailing button and
//  format arguments; the register and stack setup were read directly to recover each call's exact
//  title, message, delegate, cancel button, other buttons, and -setTag: value.
//
//  The fixed English button and sentence strings are localized at runtime through the main bundle,
//  exactly as the binary's shared string cache does when it fills its global pointers; this
//  category resolves them on demand with the same NSBundle lookup. The hard-coded Japanese titles
//  and messages are baked into the binary as literal strings and are reproduced verbatim, including
//  the binary's "BAET" typo in the spending-limit message.
//

#import "UIAlertView+RB.h"

#import "StoreCampaignItemInfo.h"

// The empty value passed as the @c value: argument of every localized-string lookup, matching the
// binary's shared string cache.
static NSString *const kEmptyLocalizedValue = @"";

// Localized button labels resolved from the main bundle (the shared string cache uses the same
// keys).
static NSString *const kLocalizedKeyOK = @"OK";
static NSString *const kLocalizedKeyNo = @"NO";
static NSString *const kLocalizedKeyYes = @"YES";
static NSString *const kLocalizedKeyCancel = @"Cancel";
static NSString *const kLocalizedKeyClose = @"Close";
static NSString *const kLocalizedKeyRetry = @"Retry";
static NSString *const kLocalizedKeyAppStore = @"AppStore";

// Fixed English titles and sentences resolved from the main bundle.
static NSString *const kLocalizedKeyCaution = @"Caution";
static NSString *const kLocalizedKeyError = @"Error";
static NSString *const kLocalizedKeyInfomation = @"Infomation";
static NSString *const kLocalizedKeyDeleteSong = @"DELETE SONG";
static NSString *const kLocalizedKeyDownload = @"Download";
static NSString *const kLocalizedKeyUnlockRequirement = @"Unlock Requirement";
static NSString *const kLocalizedKeyAppInstalledReward = @"AppInstalledReward";
static NSString *const kLocalizedKeyFreeSpaceLow =
    @"Free space of the storage area is low. May not work correctly when you play the game as it "
    @"is.";
static NSString *const kLocalizedKeyGameCenterFailed = @"Failed to connect Game Center.";
static NSString *const kLocalizedKeyDownloadFailed =
    @"Falied to download. Please check your network connection.";
static NSString *const kLocalizedKeyServerConnectFailed =
    @"Can't connect to the server. Please check your network connection.";
static NSString *const kLocalizedKeyOpenInMap = @"Do you want to open in the \"map\" this place?";
static NSString *const kLocalizedKeyEnableLocationService =
    @"To display the current position. From the \"Settings\" app. Please set to \"On\" position "
    @"information service.";
static NSString *const kLocalizedKeyTookOverData = @"Took over the data";
static NSString *const kLocalizedKeyReflectedOnLimePoint = @"reflected on the lime point score.";
static NSString *const kLocalizedKeyInstallRestoredPacks =
    @"To install restored PACKs, select \"OK\".";
static NSString *const kLocalizedKeyRestorePacks = @"To restore purchased PACKs, select \"OK\".";
static NSString *const kLocalizedKeyInstallPacks = @"Install PACKs";
static NSString *const kLocalizedKeyNewVersionAvailable =
    @"A new version is available. Do you want to move App Store?";
static NSString *const kLocalizedKeyUpdateDataFound =
    @"Update data found. Do you want to download?";
static NSString *const kLocalizedKeyLatestGameDataRequired =
    @"The latest game data is required. Download will commence.";
static NSString *const kLocalizedKeyInsufficientPoints = @"Insufficient Points!";
static NSString *const kLocalizedKeyUpdateToUnlockSong =
    @"This application must be updated to unlock this song.";
static NSString *const kLocalizedKeyPurchaseAdditionalSequences =
    @"Purchase Additional Sequences?";
static NSString *const kLocalizedKeyHasBeenAddedFormat = @"%@ has been added.";
static NSString *const kLocalizedKeyLimePointAddedFormat = @"%d LimePoint has been Added.";
static NSString *const kLocalizedKeySequenceRequirementFormat =
    @"%1$@ is required to purchase this Sequence. Purchase (%2$@)?";

// Hard-coded Japanese titles and messages baked into the binary as literal strings.
static NSString *const kAgeConfirmationTitle = @"年齢確認";
static NSString *const kAgeConfirmationMessage =
    @"有料サービスのご利用にあたり、年齢の確認をお願いしております。\n\nご入力頂いた情報は、課金上限設定にのみ使用いたします。";
static NSString *const kSpendingLimitExceededTitle = @"制限超過";
static NSString *const kSpendingLimitExceededMessage =
    @"1ヶ月の課金上限額を超過したため購入できません。月が変わってから再度REFLEC BAET Storeにお越しくだ"
    @"さい。";
static NSString *const kColetteWelcomeTitle = @"WELCOME TO colette!!";
static NSString *const kColetteWelcomeMessageKey = @"設定->テーマで colette が選べるようになりました!!";
static NSString *const kSerialCodePromptFormat = @"シリアルコードを入力してください";
static NSString *const kReorderNeedsDownloadFormat =
    @"並べ替えに必要なデータをダウンロードします";
static NSString *const kMusicsNotFoundHeader =
    @"並べ替えに必要な情報が見つからなかったため、「＃」に分類しました。\n";
static NSString *const kErosionMarkHistoryMessage =
    @"Ver.4.4.0 でErosion Markをプレイした履歴が見つかりました。\nスコアを修正しますか？";

// The three button labels of the age/spending-limit selection alert, each formatted "%@ (%@)".
static NSString *const kAgeBracketUnder16 = @"16歳未満";
static NSString *const kAgeBracketUnder20 = @"20歳未満";
static NSString *const kAgeBracket20OrOver = @"20歳以上";
static NSString *const kSpendingLimit5000 = @"¥5000/月";
static NSString *const kSpendingLimit20000 = @"¥20000/月";
static NSString *const kSpendingLimitNone = @"無";

// The "%@ (%@)" template used to build the age/spending-limit buttons.
static NSString *const kLabelWithAmountFormat = @"%@ (%@)";

// The newline separator prepended to each string appended by @c showAlertNotFoundMusics:.
static NSString *const kMusicsNotFoundSeparator = @"\n";

// The tag identifying an "update data found" alert to the shared delegate.
static const NSInteger kAlertTagUpdateDataFound = 1;
// The tag identifying a "latest game data required" alert to the shared delegate.
static const NSInteger kAlertTagResourceUpdate = 2;
// The tag identifying a "new version available" alert to the shared delegate.
static const NSInteger kAlertTagNewVersion = 3;
// The tag identifying a network-error alert to the shared delegate.
static const NSInteger kAlertTagNetworkError = 0;

// Resolves a fixed UI string from the main bundle the way the shared string cache does.
static NSString *RBLocalizedUIString(NSString *key) {
    return [[NSBundle mainBundle] localizedStringForKey:key
                                                  value:kEmptyLocalizedValue
                                                  table:nil];
}

@implementation UIAlertView (RB)

#pragma mark - Delete and storage

+ (UIAlertView *)deleteAlertViewWithDelegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xdc98 */
    return [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyDeleteSong)
                                      message:nil
                                     delegate:delegate
                            cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyNo)
                            otherButtonTitles:RBLocalizedUIString(kLocalizedKeyYes), nil];
}

+ (UIAlertView *)strageAlertView {
    /** @ghidraAddress 0xdd38 */
    return [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyCaution)
                                      message:RBLocalizedUIString(kLocalizedKeyFreeSpaceLow)
                                     delegate:nil
                            cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyClose)
                            otherButtonTitles:nil];
}

#pragma mark - Restore

+ (UIAlertView *)showRestoreDownloadWithDelegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xdd94 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyInstallPacks)
                                   message:RBLocalizedUIString(kLocalizedKeyInstallRestoredPacks)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyCancel)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyOK), nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showRestoreMessageWithDelegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xde64 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyInstallPacks)
                                   message:RBLocalizedUIString(kLocalizedKeyRestorePacks)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyCancel)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyOK), nil];
    [alert show];
    return alert;
}

#pragma mark - Errors and notices

+ (UIAlertView *)showGameCenterError {
    /** @ghidraAddress 0xdf34 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyError)
                                   message:RBLocalizedUIString(kLocalizedKeyGameCenterFailed)
                                  delegate:nil
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showNetworkErrorWithDelegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xdfc0 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyError)
                                   message:RBLocalizedUIString(kLocalizedKeyServerConnectFailed)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:nil];
    [alert setTag:kAlertTagNetworkError];
    [alert show];
    return alert;
}

+ (UIAlertView *)showDownloadErrorWithDelegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xe090 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyError)
                                   message:RBLocalizedUIString(kLocalizedKeyDownloadFailed)
                                  delegate:delegate
                         cancelButtonTitle:nil
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyClose), nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showTakeoverMessage {
    /** @ghidraAddress 0xe158 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyTookOverData)
                                   message:RBLocalizedUIString(kLocalizedKeyReflectedOnLimePoint)
                                  delegate:nil
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyClose)
                         otherButtonTitles:nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showInfomation {
    /** @ghidraAddress 0xe1e4 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyInfomation)
                                   message:RBLocalizedUIString(kLocalizedKeyEnableLocationService)
                                  delegate:nil
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showMapWithTitle:(NSString *)title
                         delegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xe270 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:title
                                   message:RBLocalizedUIString(kLocalizedKeyOpenInMap)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyCancel)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyOK), nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showWithErrorMessage:(NSString *)message
                             delegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xe358 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyError)
                                   message:message
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showConnectRetryWithErrorMessage:(NSString *)message
                                         delegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xe42c */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyError)
                                   message:message
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyRetry), nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showConnectRetryOrCancel:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xe514 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyError)
                                   message:RBLocalizedUIString(kLocalizedKeyDownloadFailed)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyClose)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyRetry), nil];
    [alert show];
    return alert;
}

#pragma mark - Points and purchases

+ (UIAlertView *)showUnlockedMusicInfoWithDelegate:(id<UIAlertViewDelegate>)delegate
                                         musicName:(NSString *)musicName {
    /** @ghidraAddress 0xe5e4 */
    NSString *message =
        [NSString stringWithFormat:RBLocalizedUIString(kLocalizedKeyHasBeenAddedFormat), musicName];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:kEmptyLocalizedValue
                                                    message:message
                                                   delegate:delegate
                                          cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                                          otherButtonTitles:nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showSelectPurchaseLimitTypeWithDelegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xe6e8 */
    NSString *cancel = RBLocalizedUIString(kLocalizedKeyCancel);
    NSString *under16 = [NSString stringWithFormat:kLabelWithAmountFormat,
                                                   kAgeBracketUnder16, kSpendingLimit5000];
    NSString *under20 = [NSString stringWithFormat:kLabelWithAmountFormat,
                                                   kAgeBracketUnder20, kSpendingLimit20000];
    NSString *over20 = [NSString stringWithFormat:kLabelWithAmountFormat,
                                                  kAgeBracket20OrOver, kSpendingLimitNone];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:kAgeConfirmationTitle
                                                    message:kAgeConfirmationMessage
                                                   delegate:delegate
                                          cancelButtonTitle:cancel
                                          otherButtonTitles:under16, under20, over20, nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showPurchaseOverMessageWithDelegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xe93c */
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:kSpendingLimitExceededTitle
                                                    message:kSpendingLimitExceededMessage
                                                   delegate:nil
                                          cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                                          otherButtonTitles:nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showAlertShortageOfPoint {
    /** @ghidraAddress 0xed10 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyError)
                                   message:RBLocalizedUIString(kLocalizedKeyInsufficientPoints)
                                  delegate:nil
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showAddLimepointByApplilink:(NSString *)rewardName
                                            :(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xf150 */
    NSString *message = [NSString
        stringWithFormat:RBLocalizedUIString(kLocalizedKeyHasBeenAddedFormat), rewardName];
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyAppInstalledReward)
                                   message:message
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:nil];
    [alert show];
    return alert;
}

#pragma mark - Updates and downloads

+ (UIAlertView *)showAlertUpdateForUnlock:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xebc0 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:kEmptyLocalizedValue
                                   message:RBLocalizedUIString(kLocalizedKeyUpdateToUnlockSong)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyCancel)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyAppStore), nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showAlertLatestApplication:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xee34 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyInfomation)
                                   message:RBLocalizedUIString(kLocalizedKeyNewVersionAvailable)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyNo)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyYes), nil];
    [alert show];
    [alert setTag:kAlertTagNewVersion];
    return alert;
}

+ (UIAlertView *)showDownloadWithDelegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xef18 */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyDownload)
                                   message:RBLocalizedUIString(kLocalizedKeyUpdateDataFound)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyNo)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyYes), nil];
    [alert show];
    [alert setTag:kAlertTagUpdateDataFound];
    return alert;
}

+ (UIAlertView *)showAlertNeedResourceUpdate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xeffc */
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:kEmptyLocalizedValue
                                   message:RBLocalizedUIString(kLocalizedKeyLatestGameDataRequired)
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:nil];
    [alert show];
    [alert setTag:kAlertTagResourceUpdate];
    return alert;
}

+ (UIAlertView *)showAlertNeedDownloadMusicNameList:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xf2e0 */
    NSString *message = [NSString stringWithFormat:kReorderNeedsDownloadFormat];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:kEmptyLocalizedValue
                                                    message:message
                                                   delegate:delegate
                                          cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyNo)
                                          otherButtonTitles:RBLocalizedUIString(kLocalizedKeyYes),
                                                            nil];
    [alert show];
    return alert;
}

#pragma mark - Themes, serial codes, and sequences

+ (UIAlertView *)showColetteThemaUnlockMessage {
    /** @ghidraAddress 0xf3e4 */
    NSString *message = [NSString stringWithFormat:RBLocalizedUIString(kColetteWelcomeMessageKey)];
    return [[UIAlertView alloc] initWithTitle:kColetteWelcomeTitle
                                      message:message
                                     delegate:nil
                            cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                            otherButtonTitles:nil];
}

+ (UIAlertView *)showSerialcodeDialog:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xf588 */
    NSString *message = [NSString stringWithFormat:kSerialCodePromptFormat];
    return [[UIAlertView alloc] initWithTitle:nil
                                      message:message
                                     delegate:delegate
                            cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyCancel)
                            otherButtonTitles:RBLocalizedUIString(kLocalizedKeyOK), nil];
}

+ (UIAlertView *)showPurchasePack:(NSString *)requirement
                         delegate:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xf8cc */
    NSString *message =
        [NSString stringWithFormat:RBLocalizedUIString(kLocalizedKeySequenceRequirementFormat),
                                   requirement];
    return [[UIAlertView alloc] initWithTitle:kEmptyLocalizedValue
                                      message:message
                                     delegate:delegate
                            cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyNo)
                            otherButtonTitles:RBLocalizedUIString(kLocalizedKeyYes), nil];
}

+ (UIAlertView *)showMovePackDetailToExtendDetail:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xf9e0 */
    return [[UIAlertView alloc]
             initWithTitle:kEmptyLocalizedValue
                   message:RBLocalizedUIString(kLocalizedKeyPurchaseAdditionalSequences)
                  delegate:delegate
         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyNo)
         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyYes), nil];
}

#pragma mark - Campaign terms

+ (UIAlertView *)showUnlockTermsDescription2:(id)campaign {
    /** @ghidraAddress 0xea50 */
    NSString *message = [(StoreCampaignItemInfo *)campaign campaignTermsDescription];
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:RBLocalizedUIString(kLocalizedKeyUnlockRequirement)
                                   message:message
                                  delegate:nil
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyOK)
                         otherButtonTitles:nil];
    [alert show];
    return alert;
}

#pragma mark - Lists and history

+ (UIAlertView *)showAlertNotFoundMusics:(id<NSFastEnumeration>)musics {
    /** @ghidraAddress 0xfa84 */
    NSMutableString *message = [[NSMutableString alloc] initWithString:kMusicsNotFoundHeader];
    for (NSString *music in musics) {
        [message appendString:kMusicsNotFoundSeparator];
        [message appendString:music];
    }
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:kEmptyLocalizedValue
                                   message:message
                                  delegate:nil
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyYes)
                         otherButtonTitles:nil];
    [alert show];
    return alert;
}

+ (UIAlertView *)showAlertUpdateErosionMark:(id<UIAlertViewDelegate>)delegate {
    /** @ghidraAddress 0xfcb0 */
    NSMutableString *message =
        [[NSMutableString alloc] initWithString:kErosionMarkHistoryMessage];
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:kEmptyLocalizedValue
                                   message:message
                                  delegate:delegate
                         cancelButtonTitle:RBLocalizedUIString(kLocalizedKeyNo)
                         otherButtonTitles:RBLocalizedUIString(kLocalizedKeyYes), nil];
    [alert show];
    return alert;
}

#pragma mark - Touch handling

+ (void)setExclusiveTouchForView:(UIView *)view {
    /** @ghidraAddress 0xf764 */
    for (UIView *subview in view.subviews) {
        subview.exclusiveTouch = YES;
        [UIAlertView setExclusiveTouchForView:subview];
    }
}

@end
