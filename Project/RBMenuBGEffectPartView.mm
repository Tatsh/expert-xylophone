//
//  RBMenuBGEffectPartView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMenuBGEffectPartView). This is an
//  Objective-C++ file because -startAnimation reaches the C++ GameSystem engine singleton and the
//  S_VECTOR2 engine vector type. Verified against the arm64 disassembly: the spawn maths (integer
//  modulo of the viewport extent, the alpha and size table lookups, and the random cycle delay) use
//  soft-float register moves that the decompiler folds into pseudo-variables, so they were recovered
//  from the disassembly at 0x10000d2a8.
//

#import "RBMenuBGEffectPartView.h"

#import "UIImage+RB.h"
#import "gamesystem.h"
#import "s_vector2.h"

// The default sprite artwork paths seeded by -init. Concrete subclasses override these.
static NSString *const kDefaultImage1Path = @"01_music_select/bg_tex_05";
static NSString *const kDefaultImage2Path = @"01_music_select/bg_tex_03";
static NSString *const kDefaultImage3Path = @"01_music_select/bg_tex_01";

// The three sprite frames the effect view cycles through, keyed by a random selector.
enum {
    kSpriteImage1 = 0, /*!< The frame loaded from image1Path. */
    kSpriteImage2 = 1, /*!< The frame loaded from image2Path. */
    kSpriteImage3 = 2, /*!< The frame loaded from image3Path. */
    kSpriteImageCount = 3,
};

// The per-cycle random parameter is quantised into this many buckets to index the size and alpha
// tables.
constexpr int kSpawnTableCount = 5;

// The particle side length, in points, selected by (random % kSpawnTableCount). Larger particles
// are rarer because the low bucket indices are hit less often by the raw random value.
constexpr float kSpawnSizeTable[] = {90.0f, 60.0f, 45.0f, 30.0f, 15.0f};

// The particle starting opacity, selected by (random % kSpawnTableCount), fading in step with the
// size table.
constexpr float kSpawnAlphaTable[] = {1.0f, 0.9f, 0.8f, 0.7f, 0.6f};

// The random cycle-start delay is (random % kSpawnDelayModulus) / kSpawnDelayDivisor seconds.
constexpr unsigned int kSpawnDelayModulus = 100;
// @ghidraAddress 0x2ec6b0 (shared read-only float, value 100.0).
constexpr float kSpawnDelayDivisor = 100.0f;

// One fade-out cycle lasts this long, in seconds.
constexpr NSTimeInterval kFadeCycleDuration = 2.0;

@interface RBMenuBGEffectPartView ()

// The GL viewport extent used to place the particle, cached at the start of each cycle. This is a
// C++ engine type, so it stays out of the public header. (Binary ivar +0x48.)
@property(assign, nonatomic) S_VECTOR2 m_screenSize;

@end

@implementation RBMenuBGEffectPartView

- (instancetype)init {
    /** @ghidraAddress 0xcce0 */
    self = [super init];
    if (self) {
        self.image1Path = kDefaultImage1Path;
        self.image2Path = kDefaultImage2Path;
        self.image3Path = kDefaultImage3Path;
    }
    return self;
}

- (void)setupView {
    /** @ghidraAddress 0xcd98 */
    self.image1 = [UIImage imageWithName:self.image1Path];
    self.image1 = [self.image1 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.image2 = [UIImage imageWithName:self.image2Path];
    // The binary re-templates image1 here, not the freshly loaded image2, so image2 and image3 end
    // up holding image1's frame. Faithful to the binary.
    self.image2 = [self.image1 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.image3 = [UIImage imageWithName:self.image3Path];
    self.image3 = [self.image1 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    // The binary builds this array and never stores it, so it is kept only for its retain side
    // effects on the three frames.
    NSMutableArray *frames = [[NSMutableArray alloc] init];
    [frames addObject:self.image1];
    [frames addObject:self.image2];
    [frames addObject:self.image3];

    self.effect = [[UIImageView alloc]
        initWithFrame:CGRectMake(0, 0, self.image1.size.width, self.image1.size.height)];
    [self addSubview:self.effect];
    self.isAnimationEnableLoop = YES;
}

- (void)startAnimation {
    /** @ghidraAddress 0xd2a8 */
    if (self.isAnimation) {
        return;
    }
    self.isAnimation = YES;
    self.isAnimationEnableLoop = YES;

    GameSystem *gameSystem = GameSystem::GetGameSystem();
    self.m_screenSize = S_VECTOR2(gameSystem->GetViewportWidth(), gameSystem->GetViewportHeight());

    unsigned int randX = arc4random();
    unsigned int randY = arc4random();
    float screenWidth = self.m_screenSize.x;
    float screenHeight = self.m_screenSize.y;

    switch (randX % kSpriteImageCount) {
    case kSpriteImage3:
        self.effect.image = self.image3;
        break;
    case kSpriteImage2:
        self.effect.image = self.image2;
        break;
    case kSpriteImage1:
        self.effect.image = self.image1;
        break;
    default:
        break;
    }

    self.alpha = kSpawnAlphaTable[randX % kSpawnTableCount];
    self.tintColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];

    unsigned int width = static_cast<unsigned int>(screenWidth);
    unsigned int spawnX = (width != 0) ? (randX % width) : randX;
    unsigned int height = static_cast<unsigned int>(screenHeight);
    unsigned int spawnY = (height != 0) ? (randY % height) : randY;
    float spawnSize = kSpawnSizeTable[randX % kSpawnTableCount];
    float delay = static_cast<float>(randX % kSpawnDelayModulus) / kSpawnDelayDivisor;

    self.frame = CGRectMake(spawnX, spawnY, spawnSize, spawnSize);

    __weak RBMenuBGEffectPartView *weakSelf = self;
    [UIView animateWithDuration:kFadeCycleDuration
        delay:delay
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          /** @ghidraAddress 0xd6e4 */
          weakSelf.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xd744 */
          if (finished) {
              [weakSelf stopAnimation];
              if (weakSelf.isAnimationEnableLoop) {
                  [weakSelf startAnimation];
              }
          }
        }];
}

- (void)stopAnimation {
    /** @ghidraAddress 0xd81c */
    self.isAnimation = NO;
    [self.effect.layer removeAllAnimations];
    [self.effect stopAnimating];
    self.effect.image = nil;
}

- (void)setAnimationLoopFlag:(BOOL)animationLoopFlag {
    /** @ghidraAddress 0xd810 */
    self.isAnimationEnableLoop = animationLoopFlag;
}

- (void)removeFromSuperview {
    /** @ghidraAddress 0xd934 */
    [super removeFromSuperview];
}

@end
