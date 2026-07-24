#import "RBMusicHistoryView.h"

#import "GraphView.h"
#import "History.h"
#import "HistoryData.h"
#import "RBCoreDataManager.h"
#import "UIImage+RB.h"

// The graph view's frame within the panel, decoded from the .const pools referenced by CreateView
// (@0x4980..: x 16.0, y 20.0, and the two doubles DAT_1002ec690 and DAT_1002ec698).
static const CGFloat kGraphViewX = 16.0;
static const CGFloat kGraphViewY = 20.0;
static const CGFloat kGraphViewWidth = 389.0;
static const CGFloat kGraphViewHeight = 168.0;

// The achievement rate is stored as a unit fraction and plotted as a percentage, and the graph's
// maximum plotted value is the full 100%.
static const float kAchievementRatePercentScale = 100.0f;
static const CGFloat kGraphMaxValue = 100.0;

// The panel's fully-opaque and fully-transparent alpha endpoints.
static const CGFloat kPanelAlphaOpaque = 1.0;
static const CGFloat kPanelAlphaTransparent = 0.0;

// The show animation's fade duration and delay, in seconds, and its animation options (the binary
// passes the literal option value 1, UIViewAnimationOptionLayoutSubviews).
static const NSTimeInterval kShowAnimationDuration = 0.5;
static const NSTimeInterval kShowAnimationDelay = 0.0;

// The shared translucent-panel background alpha (g_dTranslucentAlpha @0x1002ec6a0, 0.8) and the
// shared mascot-move animation duration (g_dMascotMoveAnimDuration @0x1002ec6a8, 0.1, reused as
// the hide-fade duration). Both are cross-file palette and timing globals; they are cached here
// rather than re-declared as shared external constants until those globals are recovered.
static const CGFloat kTranslucentAlpha = 0.8;
static const NSTimeInterval kMascotMoveAnimDuration = 0.1;

@implementation RBMusicHistoryView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.dataArray = [[NSMutableArray alloc] init];
        self.pointViewArray = [[NSMutableArray alloc] init];
        [self CreateView];
    }
    return self;
}

#pragma mark View construction

- (void)CreateView {
    UIImage *sheetImage = [UIImage imageWithName:@"02_music_detail/diary_graph"];
    self.graphSheetView = [[UIImageView alloc] initWithImage:sheetImage];
    [self addSubview:self.graphSheetView];

    self.graphView = [[GraphView alloc]
        initWithFrame:CGRectMake(kGraphViewX, kGraphViewY, kGraphViewWidth, kGraphViewHeight)];
    [self addSubview:self.graphView];

    self.hidden = YES;
    self.alpha = kPanelAlphaTransparent;
    self.backgroundColor = [UIColor colorWithWhite:kTranslucentAlpha alpha:kTranslucentAlpha];
}

#pragma mark Drawing

- (void)drawRect:(CGRect)rect {
    // The binary implements an empty drawRect: override. @ghidraAddress 0x4e3c
}

#pragma mark Graph data

- (void)createGraphData {
    // Worked from the raw arm64 (@0x4b98..): the decompiler crashes on this method with the known
    // RBCoreDataManager broken-struct error.
    NSManagedObjectContext *context = [RBCoreDataManager sharedInstance].historyContext;
    NSArray *records = [History getScoreData:self.musicID
                                  Difficulty:self.difficulty
                      inManagedObjectContext:context];
    if (records == nil || [records count] == 0) {
        return;
    }

    NSMutableArray *values = [[NSMutableArray alloc] init];
    // The records come back most recent first; they are plotted oldest to newest.
    for (long i = (long)[records count] - 1; i >= 0; --i) {
        HistoryData *record = [records objectAtIndex:i];
        float percent = [History getAR:record] * kAchievementRatePercentScale;
        [values addObject:@(percent)];
    }
    [self.graphView setData:values maxValue:kGraphMaxValue];
}

#pragma mark Show and hide animations

- (void)showAnimation:(int)musicID difficulty:(int)difficulty {
    if (self.m_IsAnimation) {
        return;
    }
    self.musicID = musicID;
    self.difficulty = difficulty;
    self.m_IsAnimation = YES;
    self.hidden = NO;
    [UIView animateWithDuration:kShowAnimationDuration
        delay:kShowAnimationDelay
        options:UIViewAnimationOptionLayoutSubviews
        animations:^{
          /** @ghidraAddress 0x4f8c */
          self.alpha = kPanelAlphaOpaque;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x4fb0 */
          self.alpha = kPanelAlphaOpaque;
          self.m_IsAnimation = NO;
          [self createGraphData];
        }];
}

- (void)hideAnimation {
    if (self.m_IsAnimation) {
        return;
    }
    self.m_IsAnimation = YES;
    [UIView animateWithDuration:kMascotMoveAnimDuration
        animations:^{
          /** @ghidraAddress 0x5114 */
          self.alpha = kPanelAlphaTransparent;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x5138 */
          self.hidden = YES;
          self.alpha = kPanelAlphaTransparent;
          self.m_IsAnimation = NO;
          [self.dataArray removeAllObjects];
          for (UIView *pointView in self.pointViewArray) {
              [pointView removeFromSuperview];
          }
          [self.pointViewArray removeAllObjects];
          [self.graphView reset];
        }];
}

@end
