#import "RBStoreTabController.h"

#import "AppDelegate.h"
#import "RBBGMManager.h"
#import "RBCampaignViewController.h"
#import "RBMenuView.h"
#import "RBNavigationController.h"
#import "RBStoreExtendPageViewController.h"
#import "RBStoreManageViewController.h"
#import "RBStorePageViewController.h"
#import "StoreDialogView.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "soundeffectmanager.h"

// Store tab indices, matching the order the four navigation controllers are installed.
enum {
    kStoreTabPack = 0,       // The song-pack store tab.
    kStoreTabExtendNote = 1, // The extend-note store tab.
    kStoreTabManage = 2,     // The purchase-management tab.
    kStoreTabCampaign = 3,   // The campaign store tab.
    kStoreTabCount = 4,      // The number of store tabs.
};

// Themed sound-effect identifiers.
enum { kSoundEffectCancel = 4 };

// The message font shown in the modal download dialog: 16 points on the phone, 18 on the pad.
static const CGFloat kDialogMessageFontSizePhone = 16.0;
static const CGFloat kDialogMessageFontSizePad = 18.0;

// The modal download dialog frame: origin at the top-left with a fixed size, wider on the pad. The
// phone width and pad height both come from g_dMascotMessageMaxWidthPad (@0x2ee930); the phone
// height from @0x3107d0 and the pad width from @0x3107d8.
static const CGFloat kDialogWidthPhone = 300.0;
static const CGFloat kDialogHeightPhone = 270.0;
static const CGFloat kDialogWidthPad = 400.0;
static const CGFloat kDialogHeightPad = 300.0;

// The show and hide animations for the modal dialog fade over three tenths of a second.
static const NSTimeInterval kDialogShowDuration = 0.3; // @ghidraAddress 0x3010a0
static const CGFloat kCoverAlphaHidden = 0.0;
static const CGFloat kCoverAlphaVisible = 1.0;

// The cover view is the first entry of the global UIColor palette built by
// InitializeUIColorPalette (@0x5517c): 50%-translucent black (red, green, and blue components 0
// with alpha 0.5). It is a cross-file palette global; it is rebuilt here rather than re-declared
// as a shared extern until the palette globals are recovered.
static const CGFloat kCoverAlpha = 0.5;

// The dimming cover flexes in every direction so it tracks its host's bounds.
// @ghidraAddress 0x310450 (g_dwAutoresizingMaskFlexibleAll)
static const UIViewAutoresizing kAutoresizingMaskFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The half-scale factor used to place the dialog at the centre of the view's bounds.
static const CGFloat kCenterScale = 0.5;

// The store's back-button title.
static NSString *const kBackButtonTitle = @"Back";

@interface RBStoreTabController () {
    // Set while a modal-dialog fade animation (begun with the UIView animation API) is in flight.
    BOOL m_IsUIViewAnimation;
    // Set while a tab-switch animation is in flight; suppresses tab changes and the back button.
    BOOL m_Animation;
}
@end

@implementation RBStoreTabController

#pragma mark - Lifecycle

/** @ghidraAddress 0x1d537c */
- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    // Pack tab: the song-pack store page, fronted by a "Back" bar button, wrapped in a nav
    // controller. Every navigation-bar subview is made exclusive-touch so a tap cannot leak
    // through to another control.
    RBStorePageViewController *packPage = [[RBStorePageViewController alloc] initWithParent:self];
    UIBarButtonItem *packBack = [[UIBarButtonItem alloc] initWithTitle:kBackButtonTitle
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(pushBarBtnBack:)];
    packPage.navigationItem.leftBarButtonItem = packBack;
    for (UIView *subview in packPage.navigationController.navigationBar.subviews) {
        subview.exclusiveTouch = YES;
    }
    self.mainNavCtrl = [[RBNavigationController alloc] initWithRootViewController:packPage];

    // Extend-note tab.
    self.extendNotePageViewCtrl = [[RBStoreExtendPageViewController alloc] initWithParent:self];
    UIBarButtonItem *extendBack =
        [[UIBarButtonItem alloc] initWithTitle:kBackButtonTitle
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pushBarBtnBack:)];
    self.extendNotePageViewCtrl.navigationItem.leftBarButtonItem = extendBack;
    for (UIView *subview in self.extendNotePageViewCtrl.navigationController.navigationBar
             .subviews) {
        subview.exclusiveTouch = YES;
    }
    self.extendNoteNavCtrl =
        [[RBNavigationController alloc] initWithRootViewController:self.extendNotePageViewCtrl];

    // Manage tab.
    RBStoreManageViewController *managePage =
        [[RBStoreManageViewController alloc] initWithParent:self];
    UIBarButtonItem *manageBack =
        [[UIBarButtonItem alloc] initWithTitle:kBackButtonTitle
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pushBarBtnBack:)];
    managePage.navigationItem.leftBarButtonItem = manageBack;
    for (UIView *subview in managePage.navigationController.navigationBar.subviews) {
        subview.exclusiveTouch = YES;
    }
    self.manageNavCtrl = [[RBNavigationController alloc] initWithRootViewController:managePage];

    // Campaign tab. The binary reads the not-yet-assigned campaignNavCtrl ivar here (rather than
    // the campaign page's own navigationController, as the other three tabs do), so this
    // exclusive-touch loop iterates an empty collection; reproduced faithfully.
    self.campaignViewCtrl = [[RBCampaignViewController alloc] initWithParent:self];
    UIBarButtonItem *campaignBack =
        [[UIBarButtonItem alloc] initWithTitle:kBackButtonTitle
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pushBarBtnBack:)];
    self.campaignViewCtrl.navigationItem.leftBarButtonItem = campaignBack;
    for (UIView *subview in self.campaignNavCtrl.navigationBar.subviews) {
        subview.exclusiveTouch = YES;
    }
    self.campaignNavCtrl =
        [[RBNavigationController alloc] initWithRootViewController:self.campaignViewCtrl];

    self.viewControllers =
        @[ self.mainNavCtrl, self.extendNoteNavCtrl, self.manageNavCtrl, self.campaignNavCtrl ];

    // Jump straight to the tab a pending open request names, if any.
    AppDelegate *appDelegate = [AppDelegate appDelegate];
    if ([appDelegate getPackIDForOpenStore] != nil) {
        [self selectTab:kStoreTabPack];
    } else if ([[AppDelegate appDelegate] getCampaignIDForOpenStore] != nil) {
        [self selectTab:kStoreTabCampaign];
    } else if ([[AppDelegate appDelegate] getExtendNotePIDForOpenStore] != nil) {
        [self selectTab:kStoreTabExtendNote];
    }

    // Make the tab-bar buttons exclusive-touch as well.
    for (UIView *subview in self.tabBar.subviews) {
        subview.exclusiveTouch = YES;
    }

    return self;
}

/** @ghidraAddress 0x1d6018 */
- (void)loadView {
    [super loadView];

    // Match the view's content-scale factor to the main screen where the runtime supports it.
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        if ([self.view respondsToSelector:@selector(contentScaleFactor)]) {
            self.view.contentScaleFactor = [UIScreen mainScreen].scale;
        }
    }

    // The dimming cover starts hidden and covers the whole view.
    UIView *cover = [[UIView alloc] initWithFrame:self.view.bounds];
    cover.opaque = NO;
    cover.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:kCoverAlpha];
    cover.autoresizingMask = kAutoresizingMaskFlexibleAll;
    cover.hidden = YES;
    [self.view addSubview:cover];
    self.coverView = cover;

    // The modal download dialog is sized (and its message font sized) for the phone or pad layout.
    if (!IsPad()) {
        CGRect frame = CGRectMake(0, 0, kDialogWidthPhone, kDialogHeightPhone);
        self.modalDialog = [[StoreDialogView alloc] initWithFrame:frame];
        self.modalDialog.labelMessage.font = [UIFont systemFontOfSize:kDialogMessageFontSizePhone];
    } else {
        CGRect frame = CGRectMake(0, 0, kDialogWidthPad, kDialogHeightPad);
        self.modalDialog = [[StoreDialogView alloc] initWithFrame:frame];
        self.modalDialog.labelMessage.font = [UIFont systemFontOfSize:kDialogMessageFontSizePad];
    }
    self.modalDialog.center = CGPointMake(self.view.bounds.size.width * kCenterScale,
                                          self.view.bounds.size.height * kCenterScale);
    [cover addSubview:self.modalDialog];
}

#pragma mark - Modal download dialog

/** @ghidraAddress 0x1d655c */
- (BOOL)showModalDialog:(id)delegate {
    if (m_IsUIViewAnimation) {
        return NO;
    }
    m_IsUIViewAnimation = YES;

    self.coverView.alpha = kCoverAlphaHidden;
    self.coverView.hidden = NO;
    [self.modalDialog.indicatorView startAnimating];
    self.modalDialog.buttonAbort.enabled = NO;
    self.modalDialog.delegate = delegate;

    [UIView beginAnimations:nil context:nullptr];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    [UIView setAnimationDuration:kDialogShowDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(openDialogAnimStop:finished:context:)];
    self.coverView.alpha = kCoverAlphaVisible;
    [UIView commitAnimations];
    return YES;
}

/** @ghidraAddress 0x1d6824 */
- (void)openDialogAnimStop:(NSString *)animationID
                  finished:(NSNumber *)finished
                   context:(void *)context {
    m_IsUIViewAnimation = NO;
    self.modalDialog.buttonAbort.enabled = YES;
}

/** @ghidraAddress 0x1d68c4 */
- (BOOL)hideModalDialog {
    m_IsUIViewAnimation = YES;
    self.modalDialog.buttonAbort.enabled = NO;
    self.modalDialog.delegate = nil;

    // Both blocks capture self strongly, matching the binary's retained object capture.
    [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
        animations:^{
          /** @ghidraAddress 0x1d6a60 */
          self.coverView.alpha = kCoverAlphaHidden;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1d6acc */
          self->m_IsUIViewAnimation = NO;
          [self.modalDialog.indicatorView stopAnimating];
          self.modalDialog.progressView.progress = 0;
          self.coverView.hidden = YES;
        }];
    return YES;
}

#pragma mark - Tab selection

/** @ghidraAddress 0x1d754c */
- (void)selectTab:(int)index {
    if (m_Animation) {
        return;
    }
    self.selectedIndex = static_cast<NSUInteger>(index);
}

/** @ghidraAddress 0x1d6f6c */
- (void)forceOpen {
    if (self.viewControllers == nil || self.viewControllers.count == 0) {
        return;
    }
    RBNavigationController *firstNav =
        static_cast<RBNavigationController *>(self.viewControllers[kStoreTabPack]);
    if (firstNav.viewControllers.count == 0) {
        return;
    }
    if (!self.coverView.isHidden) {
        return;
    }

    AppDelegate *appDelegate = [AppDelegate appDelegate];
    if ([appDelegate getPackIDForOpenStore] != nil) {
        // Pop the pack tab to its root and force its detail view open.
        UINavigationController *packNav =
            static_cast<UINavigationController *>(self.viewControllers[kStoreTabPack]);
        UIViewController *packPage = packNav.viewControllers[kStoreTabPack];
        if (self.selectedIndex - 1 < kStoreTabCampaign) {
            [self selectTab:kStoreTabPack];
        }
        if (![packPage respondsToSelector:@selector(forceOpenPackDetailView)]) {
            return;
        }
        [packPage performSelector:@selector(forceOpenPackDetailView)];
        return;
    }
    if ([[AppDelegate appDelegate] getCampaignIDForOpenStore] != nil) {
        UINavigationController *campaignNav =
            static_cast<UINavigationController *>(self.viewControllers[kStoreTabCampaign]);
        UIViewController *campaignPage = campaignNav.viewControllers[kStoreTabPack];
        if (self.selectedIndex < kStoreTabCampaign) {
            [self selectTab:kStoreTabCampaign];
        }
        if (![campaignPage respondsToSelector:@selector(forceOpenCampaignDetailView)]) {
            return;
        }
        [campaignPage performSelector:@selector(forceOpenCampaignDetailView)];
        return;
    }
    if ([[AppDelegate appDelegate] getExtendNotePIDForOpenStore] == nil) {
        return;
    }
    UINavigationController *extendNav =
        static_cast<UINavigationController *>(self.viewControllers[kStoreTabExtendNote]);
    UIViewController *extendPage = extendNav.viewControllers[kStoreTabPack];
    if (self.selectedIndex < kStoreTabCount && self.selectedIndex != kStoreTabExtendNote) {
        [self selectTab:kStoreTabExtendNote];
    }
    if (![extendPage respondsToSelector:@selector(forceOpenExtendNoteDetailView)]) {
        return;
    }
    [extendPage performSelector:@selector(forceOpenExtendNoteDetailView)];
}

#pragma mark - Navigation

/** @ghidraAddress 0x1d6c20 */
- (void)pushBarBtnBack:(id)sender {
    if (m_Animation) {
        return;
    }

    // Stop the pack tab's promotion presentation.
    UINavigationController *packNav =
        static_cast<UINavigationController *>(self.viewControllers[kStoreTabPack]);
    RBStorePageViewController *packPage =
        static_cast<RBStorePageViewController *>(packNav.viewControllers[kStoreTabPack]);
    if (packPage != nil) {
        [packPage stopPromotion];
    }

    // Restore the menu BGM that the store paused: stop the pushed track, pop it, and resume.
    // The binary reuses the flash-min-opacity constant (0.2) as the BGM fade duration here.
    if ([[RBBGMManager getInstance] isPushMusic]) {
        [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
        (void)[[RBBGMManager getInstance] popMusic]; // The binary discards this result.
        [[RBBGMManager getInstance] PlayMusic:g_flFlashMinOpacity];
    }

    [self.musicMenuView reloadMusicData];
    [[[AppDelegate appDelegate] navigationController] popToRootViewControllerAnimated:YES];
    if (self.musicMenuView != nil) {
        [self.musicMenuView RemoveStoreViewController];
    }
    PlayThemedSoundEffect(SoundEffectManager::GetInstance(), kSoundEffectCancel);
}

@end
