/** @file
 * The scrolling news-ticker banner shown on the music-menu footer. It is a @c UIView subclass that
 * marquees a line of news text and, when that text carries an @c rbplus:// link, taps through to
 * the store, a campaign, a sequence, or an in-app web page. It is also the base class of
 * @c RBMenuButton.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMenuNewsTickerView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Base view for the scrolling news-ticker banner on the music-menu footer.
 */
@interface RBMenuNewsTickerView : UIView

/**
 * @brief Initialise the ticker with the given frame and build its subviews.
 *
 * Chains to @c super, resets @c baseDuration to zero, and calls @c SetUpView to create the clipping
 * base view, the news label, and the anchor-point animation.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x9e670
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the ticker's subviews: the background image frame, the clipping text base view, the
 * scrolling news label, and the repeating anchor-point animation.
 *
 * The label colours and background are chosen by the active theme, and the fonts are sized by the
 * iPad idiom.
 * @ghidraAddress 0x9e6f0
 */
- (void)SetUpView;

/**
 * @brief Set the news text and start (or restart) the marquee scroll, then parse the accompanying
 * link into the store, pack, campaign, sequence, or web identifiers.
 * @param text The news line to display.
 * @param LINK The @c rbplus:// link to route through, or @c nil for plain text with no link.
 * @return The scroll animation's duration in seconds, or zero when the text fits without scrolling.
 * @ghidraAddress 0x9f190
 */
- (float)setText:(nullable NSString *)text LINK:(nullable NSURL *)LINK;

/**
 * @brief The scroll animation's base duration in seconds, added to the length-dependent scroll time.
 * @param duration The base duration in seconds.
 * @ghidraAddress 0x9f150
 */
- (void)setDuration:(float)duration;

/**
 * @brief The parsed pack identifier from the current link, or @c nil.
 * @return The pack identifier.
 * @ghidraAddress 0x9f160
 */
- (nullable NSString *)getPackID;

/**
 * @brief The parsed campaign identifier from the current link, or @c nil.
 * @return The campaign identifier.
 * @ghidraAddress 0x9f16c
 */
- (nullable NSString *)getCampaignID;

/**
 * @brief The parsed sequence identifier from the current link, or @c nil.
 * @return The sequence identifier.
 * @ghidraAddress 0x9f178
 */
- (nullable NSString *)getSequenceID;

/**
 * @brief The parsed web-page identifier from the current link, or @c nil.
 * @return The web-page identifier.
 * @ghidraAddress 0x9f184
 */
- (nullable NSString *)getWebID;

/**
 * @brief Restart the marquee scroll when a scroll animation finishes, keeping the text looping.
 * @param animation The animation that stopped.
 * @param finished Whether the animation reached its end rather than being removed.
 * @ghidraAddress 0xa0730
 */
- (void)animationDidStop:(nullable CAAnimation *)animation finished:(BOOL)finished;

/**
 * @brief Stop the marquee scroll by removing all animations from the text layer.
 * @ghidraAddress 0xa0a3c
 */
- (void)stopNews;

/**
 * @brief Whether the current link routes to the in-app store rather than an external URL.
 * @return @c YES when the link is an @c rbplus:// store, pack, campaign, sequence, or web link.
 * @ghidraAddress 0xa0b7c
 */
- (BOOL)isLinkToStore;

/**
 * @brief Open the current external link URL in the system browser, if it can be opened.
 * @ghidraAddress 0xa0b8c
 */
- (void)toLink;

/**
 * @brief Parse a query string as an @c rbplus:// URL and return its path components.
 * @param query The query string to parse, or @c nil.
 * @return The path components, or @c nil.
 * @ghidraAddress 0xa0cf4
 */
- (nullable NSArray<NSString *> *)parseQuery:(nullable NSString *)query;

/**
 * @brief The clipping container that masks the scrolling text to the ticker bounds.
 */
@property(strong, nonatomic, nullable) UIView *textBaseView;

/**
 * @brief The label that renders and scrolls the news text.
 */
@property(strong, nonatomic, nullable) UILabel *textView;

/**
 * @brief The font used for the news text, sized by the active iPad idiom.
 */
@property(strong, nonatomic, nullable) UIFont *font;

/**
 * @brief The external link URL to open when the ticker is tapped, or @c nil for an in-app link.
 */
@property(strong, nonatomic, nullable) NSURL *linkURL;

/**
 * @brief The pack identifier parsed from an in-app @c rbplus://store/pack link.
 */
@property(strong, nonatomic, nullable) NSString *packID;

/**
 * @brief The campaign identifier parsed from an in-app @c rbplus://store/campaign link.
 */
@property(strong, nonatomic, nullable) NSString *campaignID;

/**
 * @brief The sequence identifier parsed from an in-app @c rbplus://store/seq link.
 */
@property(strong, nonatomic, nullable) NSString *sequenceID;

/**
 * @brief The web-page identifier parsed from an in-app @c rbplus://info/web link.
 */
@property(strong, nonatomic, nullable) NSString *webID;

/**
 * @brief The target object notified when the ticker's link is followed.
 */
@property(strong, nonatomic, nullable) id target;

/**
 * @brief The scroll animation's base duration in seconds.
 */
@property(assign, nonatomic) float baseDuration;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
