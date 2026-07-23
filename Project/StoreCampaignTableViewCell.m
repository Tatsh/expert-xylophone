#import "StoreCampaignTableViewCell.h"

#import "RBMusicManager.h"
#import "StoreCampaignItemInfo.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The pad cell is 180 points tall; the phone cell reuses the shared 100-point layout metric.
static const CGFloat kCellHeightPad = 180.0;

// The artwork inset from the cell edge: 12 points horizontally on pad and 10 on phone, with a
// constant 10-point vertical inset.
static const CGFloat kArtworkMarginWidthPad = 12.0;
static const CGFloat kArtworkMarginWidthPhone = 10.0;
static const CGFloat kArtworkMarginHeight = 10.0;

// The banner artwork frame size: 640x160 on pad and 320x80 on phone.
static const CGFloat kItemWidthPad = 640.0;
static const CGFloat kItemWidthPhone = 320.0;
static const CGFloat kItemHeightPad = 160.0;
static const CGFloat kItemHeightPhone = 80.0;

// The rounded jacket placeholder is a square (110 points on pad, 64 on phone) that is inset from the
// artwork origin, nudged up 2 points on phone to line up with the shadow.
static const CGFloat kJacketSizePad = 110.0;
static const CGFloat kJacketSizePhone = 64.0;
static const int kJacketPhoneVerticalNudge = 2;
static const CGFloat kJacketCornerRadius = 5.0;
static const CGFloat kJacketCapInset = 4.0;
static const CGFloat kJacketShadowOffset = 1.0;
static const CGFloat kJacketShadowOpacity = 0.6;
static const CGFloat kJacketShadowRadius = 1.0;

// The centre of the frame divides the surplus size in half.
static const CGFloat kHalf = 0.5;

// The artwork fades in over two tenths of a second once its banner arrives.
static const NSTimeInterval kArtworkFadeDuration = 0.2;
static const CGFloat kOpaqueAlpha = 1.0;
static const CGFloat kTransparentAlpha = 0.0;

// A campaign item is a tune when its type is zero; only a tune is checked against the local library.
static const int kCampaignItemTypeTune = 0;

// The two alternating pack-background images (selected by row parity) and the jacket placeholder.
static NSString *const kPackBackgroundImageNameEven = @"09_store/store_pack_bg_0";
static NSString *const kPackBackgroundImageNameOdd = @"09_store/store_pack_bg_1";
static NSString *const kJacketPlaceholderImageName = @"09_store/store_jacket_110";

// The purchased action-button state that a downloaded item forces.
static const int kButtonTypePurchased = 1;

@implementation StoreCampaignTableViewCell {
    // Plain ivars without properties, written straight from the bound item.
    BOOL downloadFlag;
    int buttonType;
    BOOL bUnlock;
    int hideType;
}

+ (CGFloat)cellHeight:(BOOL)isPad {
    return isPad ? kCellHeightPad : g_dCustomizeLayoutMetric100;
}

- (instancetype)initWithDeviceType:(BOOL)isPad
                   reuseIdentifier:(NSString *)reuseIdentifier
                               tag:(int)tag {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        self.tag = tag;
        self.backgroundColor = [UIColor clearColor];

        CGSize itemSize = [self getItemSize:isPad];
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat cellHeight = [StoreCampaignTableViewCell cellHeight:isPad];

        UIImage *packBackground = [UIImage
            imageWithName:(tag & 1) ? kPackBackgroundImageNameOdd : kPackBackgroundImageNameEven];
        UIImageView *packBackgroundView = [[UIImageView alloc]
            initWithFrame:CGRectMake((int)((screenWidth - itemSize.width) * kHalf),
                                     (int)((cellHeight - itemSize.height) * kHalf),
                                     itemSize.width,
                                     itemSize.height)];
        [packBackgroundView
            setImage:[packBackground
                         resizableImageWithCapInsets:UIEdgeInsetsMake(kJacketCapInset,
                                                                      kJacketCapInset,
                                                                      kJacketCapInset,
                                                                      kJacketCapInset)]];
        // Both device branches configure the same rounded, clipped corners in the binary.
        packBackgroundView.layer.cornerRadius = kJacketCornerRadius;
        packBackgroundView.clipsToBounds = YES;
        [self addSubview:packBackgroundView];
        self.backgroundView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        CGSize margin = [self getArtworkMargin:isPad];
        CGFloat jacketSize = isPad ? kJacketSizePad : kJacketSizePhone;
        UIImageView *artwork = [[UIImageView alloc]
            initWithFrame:CGRectMake((int)margin.width,
                                     (int)margin.height - (isPad ? 0 : kJacketPhoneVerticalNudge),
                                     jacketSize,
                                     jacketSize)];
        self.artworkView = artwork;
        [self.artworkView setImage:nil];
        self.artworkView.layer.shadowOffset = CGSizeMake(kJacketShadowOffset, kJacketShadowOffset);
        self.artworkView.layer.shadowColor = [UIColor blackColor].CGColor;
        self.artworkView.layer.shadowOpacity = kJacketShadowOpacity;
        self.artworkView.layer.shadowRadius = kJacketShadowRadius;
        self.artworkView.layer.shouldRasterize = YES;
        self.artworkView.alpha = kTransparentAlpha;
        [packBackgroundView addSubview:self.artworkView];
        if (!isPad) {
            packBackgroundView.autoresizingMask =
                UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        }

        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.exclusiveTouch = YES;
        self.contentView.exclusiveTouch = YES;
    }
    return self;
}

- (void)setInfo:(StoreCampaignItemInfo *)info tag:(int)tag {
    self.tag = tag;
    if (info == nil) {
        [self.artworkView setImage:[UIImage imageWithName:kJacketPlaceholderImageName]];
    } else {
        bUnlock = info.bUnlock;
        hideType = info.hideType;
        _campaignID = info.campaignID;
        buttonType = info.buttonType;
        downloadFlag = [self hasItem:info.itemType itemID:info.itemID];
        [self setDownloadFlag:downloadFlag];
        (void)info.itemType; // Yes, the binary reads and discards itemType here.
        [self.artworkView setImage:nil];
    }
}

- (void)setDownloadFlag:(BOOL)flag {
    downloadFlag = flag;
    if (flag) {
        buttonType = kButtonTypePurchased;
    }
}

- (BOOL)hasItem:(int)itemType itemID:(int)itemID {
    if (itemType == kCampaignItemTypeTune) {
        if ([[RBMusicManager getInstance] getMusicData:itemID] != nil) {
            NSString *path = [RBMusicManager getPathFromPurchesed:itemID];
            return [[NSFileManager defaultManager] fileExistsAtPath:path];
        }
    }
    return NO;
}

- (CGSize)getArtworkMargin:(BOOL)isPad {
    return CGSizeMake(isPad ? kArtworkMarginWidthPad : kArtworkMarginWidthPhone,
                      kArtworkMarginHeight);
}

- (CGSize)getItemSize:(BOOL)isPad {
    return CGSizeMake(isPad ? kItemWidthPad : kItemWidthPhone,
                      isPad ? kItemHeightPad : kItemHeightPhone);
}

- (void)setArtwork:(UIImage *)artwork {
    if (artwork != nil) {
        // The binary passes the region font-variant flag where an isPad flag is expected.
        CGSize size = [self getItemSize:GetFontVariantFlag()];
        self.artworkView.frame = CGRectMake(0, 0, size.width, size.height);
        [self.artworkView setImage:artwork];
        [UIView animateWithDuration:kArtworkFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x57194 */
                           self.artworkView.alpha = kOpaqueAlpha;
                         }];
    }
}

@end
