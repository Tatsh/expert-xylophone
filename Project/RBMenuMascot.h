/** @file
 * The animated mascot character that wanders across the music-menu screen. It is a @c UIView
 * subclass that plays a sprite-frame animation on an inner @c UIImageView (a random normal or, on
 * the Hinabita 2017-03 campaign, a rare frame set), drifts left and right under a simple gravity
 * model, bounces off the screen edges, and hops when tapped. During the campaign it instead shows a
 * scrolling speech-bubble ticker of campaign messages and, when a message carries a link, taps
 * through to the store, a web page, or a campaign via @c RBUrlSchemeManager.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMenuMascot, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@protocol RBMenuMascotDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The animated, tappable mascot shown wandering across the music-menu screen.
 */
@interface RBMenuMascot : UIView

/**
 * @brief The frame sets for the normal mascot animation.
 *
 * Each element is a @c NSMutableArray of @c UIImage frames for one animation clip.
 */
@property(nonatomic, strong) NSMutableArray *normalImageArray;
/** @brief The per-clip frame counts for @c normalImageArray. */
@property(nonatomic, strong) NSMutableArray *normalFrameCountArray;
/** @brief The frame sets for the rare (campaign) mascot animation. */
@property(nonatomic, strong) NSMutableArray *rareImageArray;
/** @brief The per-clip frame counts for @c rareImageArray. */
@property(nonatomic, strong) NSMutableArray *rareFrameCountArray;

/** @brief The inner image view that runs the mascot sprite animation. */
@property(nonatomic, strong, nullable) UIImageView *mascotView;
/** @brief The container view holding the campaign message bubble. */
@property(nonatomic, strong, nullable) UIView *messageView;
/** @brief The resizable speech-bubble background behind the campaign message. */
@property(nonatomic, strong, nullable) UIImageView *messageBgView;
/** @brief The label that renders the current campaign message text. */
@property(nonatomic, strong, nullable) UILabel *messageLabel;
/** @brief The campaign message list, taken from @c RBCampaignData. */
@property(nonatomic, strong, nullable) NSArray *messageList;

/** @brief The mascot type identifier passed to @c setup:. */
@property(nonatomic, assign) int type;
/** @brief The index of the campaign message currently shown. */
@property(nonatomic, assign) int currentMessageIndex;
/** @brief The index of the campaign message to show next. */
@property(nonatomic, assign) int nextMessageIndex;

/** @brief Whether the mascot is running in campaign (message-ticker) mode. */
@property(nonatomic, assign) BOOL isCampaignMode;
/** @brief Whether the wander animation is currently running. */
@property(nonatomic, assign) BOOL isAnimation;
/** @brief Whether a message-ticker fade or slide animation is in flight. */
@property(nonatomic, assign) BOOL messageViewAnimating;

/** @brief The horizontal drift speed, in points per frame. */
@property(nonatomic, assign) float speedX;
/** @brief The vertical speed, in points per frame. */
@property(nonatomic, assign) float speedY;
/** @brief The vertical acceleration (gravity) applied per frame. */
@property(nonatomic, assign) float accellY;
/** @brief The mascot render scale. */
@property(nonatomic, assign) float scale;
/** @brief The resting vertical position the mascot settles to. */
@property(nonatomic, assign) float baseY;
/** @brief The right-edge bounce limit, in points. */
@property(atomic, assign) float limitX;
/** @brief The bottom-edge bounce limit, in points. */
@property(atomic, assign) float limitY;

/** @brief The delegate notified when a linked campaign message is tapped. */
@property(nonatomic, weak, nullable) id<RBMenuMascotDelegate> delegate;

/**
 * @brief Builds the mascot: loads the sprite frames, the inner image view, the tap recogniser, and
 * the campaign message bubble, then seeds the campaign message list.
 * @param type The mascot type identifier.
 * @ghidraAddress 0x2b774
 */
- (void)setup:(int)type;

/**
 * @brief Starts the wander animation: picks a random clip, positions the mascot at a random resting
 * height, applies the scale transform, and begins ticking.
 * @param sender The animation trigger (unused).
 * @ghidraAddress 0x2c850
 */
- (void)startAnimation:(nullable id)sender;

/**
 * @brief Stops the wander animation and clears the sprite frames.
 * @ghidraAddress 0x2d478
 */
- (void)stopAnimation;

/**
 * @brief Advances the campaign message ticker: fades the current bubble out and slides the next
 * message in.
 * @ghidraAddress 0x2d54c
 */
- (void)updateMessage;

/**
 * @brief Runs one wander step: integrates the vertical gravity, bounces off the screen edges,
 * flipping the mascot, and returns the mascot's new frame origin.
 * @return The mascot's new frame origin, in points.
 * @ghidraAddress 0x2ebe4
 */
- (CGPoint)getMovePoint;

/**
 * @brief Measures a campaign message string constrained to the message-bubble width for the current
 * font variant.
 * @param text The message text to measure.
 * @return The size the text occupies.
 * @ghidraAddress 0x2e5d4
 */
- (CGSize)generateCGSize:(NSString *)text;

/**
 * @brief Drives the per-frame move animation on the Colette theme (repositions the mascot and, when
 * finished, advances the ticker).
 * @ghidraAddress 0x2e6c4
 */
- (void)update;

/**
 * @brief Handles a tap: hops the mascot upward off-campaign, or advances or follows the campaign
 * message ticker on-campaign.
 * @param sender The tap gesture recogniser.
 * @ghidraAddress 0x2e8c8
 */
- (void)onTapped:(UITapGestureRecognizer *)sender;

@end

/**
 * @brief The delegate protocol the mascot uses to surface a tapped campaign-message link.
 */
@protocol RBMenuMascotDelegate <NSObject>
@optional
/** @brief Requests that the host present the campaign notification page. */
- (void)showNotificationPageView;
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
