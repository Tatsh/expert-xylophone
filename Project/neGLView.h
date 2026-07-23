/** @file
 * The OpenGL ES drawing surface. It is a @c UIView subclass backed by an @c EAGLContext and the
 * engine's GL ES interface: it owns the framebuffer and renderbuffer, reports the front-buffer
 * size, and drives the begin-render / present cycle for each frame. On layout it resizes the
 * renderbuffer from its layer and notifies its delegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class neGLView, image base 0x100000000).
 * @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class neGLView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Receives layout notifications from a @c neGLView. The view checks each callback with
 * @c -respondsToSelector: before invoking it, so conformance is informal.
 */
@protocol neGLViewDelegate <NSObject>

@optional

/**
 * @brief Notifies the delegate that the GL view laid out and resized its renderbuffer.
 * @param glView The view that was laid out.
 * @ghidraAddress 0x8a7e4
 */
- (void)LayoutedGLView:(neGLView *)glView;

@end

/**
 * @brief The OpenGL ES drawing surface that hosts the game renderer.
 */
@interface neGLView : UIView

/** @brief The delegate notified of layout changes. */
@property(nonatomic, weak, nullable) id<neGLViewDelegate> delegate;

/**
 * @brief Returns the current front-buffer width, in pixels.
 * @ghidraAddress 0x3a448
 */
- (int)GetFrontBufferWidth;

/**
 * @brief Returns the current front-buffer height, in pixels.
 * @ghidraAddress 0x3a458
 */
- (int)GetFrontBufferHeight;

/**
 * @brief Makes this view's @c EAGLContext current so rendering can begin.
 * @return @c YES when the context was made current.
 * @ghidraAddress 0x3a468
 */
- (BOOL)BeginRender;

/**
 * @brief Binds the default framebuffer for rendering.
 * @ghidraAddress 0x3a4d8
 */
- (void)SetDefaultFrameBuffer;

/**
 * @brief Binds the default colour renderbuffer for rendering.
 * @ghidraAddress 0x3a4dc
 */
- (void)SetDefaultColorBuffer;

/**
 * @brief Presents the colour renderbuffer to the screen.
 * @return @c YES when the renderbuffer was presented.
 * @ghidraAddress 0x3a4e0
 */
- (BOOL)Present;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
