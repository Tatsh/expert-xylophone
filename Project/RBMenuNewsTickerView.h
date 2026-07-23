/** @file
 * The scrolling news-ticker banner shown on the music-menu footer. It is a @c UIView subclass that
 * marquees a line of news text and, when the text is a link, taps through to the store, a web page,
 * or a campaign. It is also the base class of @c RBMenuButton.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMenuNewsTickerView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base. This is a speculative
 * header declaring only the members its subclasses and callers currently need; the full class is
 * reconstructed elsewhere.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Base view for the scrolling news-ticker banner on the music-menu footer.
 */
@interface RBMenuNewsTickerView : UIView

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
