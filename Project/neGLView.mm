#import "neGLView.h"

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES1/gl.h>
#import <QuartzCore/QuartzCore.h>

#import "neEngineBridge.h"

// The most recently created GL view. The binary keeps a single file-scope pointer that
// -initWithFrame: writes last and -dealloc clears; +GetInstance returns it. Only one instance is
// ever live.
static neGLView *g_pGLView = nil;

@interface neGLView ()

// The backing EAGL context that owns the drawable and its GL objects.
@property(nonatomic, strong, nullable) EAGLContext *glContext;

@end

@implementation neGLView {
    // The engine GL ES backend that owns the framebuffer helpers. It is the shared render-state
    // singleton, not a per-view object.
    neGLESRenderer *m_GLInterface;
    // The GL framebuffer object bound while drawing.
    GLuint m_DefaultFramebuffer;
    // The GL colour renderbuffer whose storage tracks the layer's drawable.
    GLuint m_ColorRenderbuffer;
    // The GL_RENDERBUFFER_OES bind target constant used when presenting and resizing.
    GLuint m_RenderBufferID;
    // The current front-buffer size, queried from the renderbuffer after each layout.
    GLint m_FrontBufferWidth;
    GLint m_FrontBufferHeight;
}

+ (Class)layerClass {
    /** @ghidraAddress 0x39e1c */
    return [CAEAGLLayer class];
}

+ (nullable instancetype)GetInstance {
    /** @ghidraAddress 0x39e10 */
    return g_pGLView;
}

- (nullable instancetype)initWithFrame:(CGRect)frame {
    /** @ghidraAddress 0x39e30 */
    self = [super initWithFrame:frame];
    if (!self) {
        g_pGLView = nil;
        return nil;
    }

    CAEAGLLayer *eaglLayer = static_cast<CAEAGLLayer *>(self.layer);
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking : @NO,
        kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGB565
    };

    self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    if (!self.glContext || ![EAGLContext setCurrentContext:self.glContext]) {
        g_pGLView = nil;
        return nil;
    }

    EnsureGLRenderStateSingleton();
    m_GLInterface = GetGlRenderer();
    m_RenderBufferID = GetGLRenderbufferTarget();

    self.opaque = YES;
    self.backgroundColor = UIColor.blackColor;
    self.multipleTouchEnabled = YES;

    m_GLInterface->GenFramebuffer(&m_DefaultFramebuffer);
    m_GLInterface->GenRenderbuffer(&m_ColorRenderbuffer);
    m_GLInterface->BindFramebuffer(m_DefaultFramebuffer);
    m_GLInterface->BindRenderbuffer(m_ColorRenderbuffer);
    m_GLInterface->AttachRenderbufferToFramebuffer(RENDER_KIND_COLOR, m_ColorRenderbuffer);

    g_pGLView = self;
    return self;
}

- (void)dealloc {
    /** @ghidraAddress 0x3a188 */
    if (m_DefaultFramebuffer != 0) {
        m_GLInterface->DeleteFramebuffer(m_DefaultFramebuffer);
        m_DefaultFramebuffer = 0;
    }
    if (m_ColorRenderbuffer != 0) {
        m_GLInterface->DeleteRenderbuffer(m_ColorRenderbuffer);
        m_ColorRenderbuffer = 0;
    }
    if ([EAGLContext currentContext] == self.glContext) {
        [EAGLContext setCurrentContext:nil];
    }
    self.glContext = nil;
    g_pGLView = nil;
}

- (void)layoutSubviews {
    /** @ghidraAddress 0x3a2e4 */
    [self.glContext renderbufferStorage:m_RenderBufferID
                           fromDrawable:static_cast<CAEAGLLayer *>(self.layer)];
    m_GLInterface->GetRenderbufferWidth(&m_FrontBufferWidth);
    m_GLInterface->GetRenderbufferHeight(&m_FrontBufferHeight);
    CheckFramebufferComplete(); // The completeness check is issued for its GL side effect only.

    if ([self.delegate respondsToSelector:@selector(LayoutedGLView:)]) {
        [self.delegate LayoutedGLView:self];
    }
}

- (int)GetFrontBufferWidth {
    /** @ghidraAddress 0x3a448 */
    return m_FrontBufferWidth;
}

- (int)GetFrontBufferHeight {
    /** @ghidraAddress 0x3a458 */
    return m_FrontBufferHeight;
}

- (BOOL)BeginRender {
    /** @ghidraAddress 0x3a468 */
    return [EAGLContext setCurrentContext:self.glContext];
}

- (void)SetDefaultFrameBuffer {
    /** @ghidraAddress 0x3a4d8 */
    // The binary body is empty: this build binds the framebuffer once at initialisation and leaves
    // the hook as a no-op.
}

- (void)SetDefaultColorBuffer {
    /** @ghidraAddress 0x3a4dc */
    // The binary body is empty: this build binds the colour renderbuffer once at initialisation and
    // leaves the hook as a no-op.
}

- (BOOL)Present {
    /** @ghidraAddress 0x3a4e0 */
    return [self.glContext presentRenderbuffer:m_RenderBufferID];
}

#pragma mark - Touch input

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /** @ghidraAddress 0x3a550 */
    // The owning-view key pair is this view's frame size, correlating each touch to the GL surface.
    CGRect frame = self.frame;
    int key1 = static_cast<int>(CGRectGetWidth(frame));
    int key2 = static_cast<int>(CGRectGetHeight(frame));
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self];
        TouchManager::FetchSharedSingleton()->AddTouchPoint(
            static_cast<int>(location.x), static_cast<int>(location.y), key1, key2);
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    /** @ghidraAddress 0x3a704 */
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self];
        CGPoint previous = [touch previousLocationInView:self];
        // The previous position locates the tracked slot; the current position replaces it.
        TouchManager::FetchSharedSingleton()->UpdateTouchPoint(static_cast<int>(location.x),
                                                               static_cast<int>(location.y),
                                                               static_cast<int>(previous.x),
                                                               static_cast<int>(previous.y));
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    /** @ghidraAddress 0x3a8b0 */
    if (touches.count == [event touchesForView:self].count) {
        // Every touch on this view ended at once: mark them all ended in a single pass.
        TouchManager::FetchSharedSingleton()->MarkAllTouchesEnded();
        return;
    }
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self];
        CGPoint previous = [touch previousLocationInView:self];
        TouchManager::FetchSharedSingleton()->HandleTouchMoved(static_cast<int>(location.x),
                                                               static_cast<int>(location.y),
                                                               static_cast<int>(previous.x),
                                                               static_cast<int>(previous.y));
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    /** @ghidraAddress 0x3ab14 */
    [self touchesEnded:touches withEvent:event];
}

@end
