//
//  RBHowToView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBHowToView). Verified against the
//  arm64 disassembly: -setupView's theme/idiom/Retina-dependent frame maths and the
//  page-layout of -createViewSame: were recovered from the soft-float register moves that the
//  decompiler folds into pseudo-variables.
//

#import "RBHowToView.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"

// The default (non-typed) variant of the music-menu popup passed to -setMusicMenuPopupViewType:.
static const NSInteger kMusicMenuPopupViewTypeDefault = 0;

// The number of how-to-play instruction pages, one image per page.
static const int kHowToPlayPageCount = 6;

// The how-to-play page artwork, laid out one image per page. Page @c i uses element @c i.
static NSString *const kHowToPlayPageImageNames[] = {
    @"03_howtoplay/how_1",
    @"03_howtoplay/how_2",
    @"03_howtoplay/how_3",
    @"03_howtoplay/how_4",
    @"03_howtoplay/how_5",
    @"03_howtoplay/how_6",
};

// The page control's fixed height, in points, common to every layout branch.
static const CGFloat kPageControlHeight = 24.0;

// The scroll view's fixed left inset, in points, common to every layout branch.
static const CGFloat kScrollViewOriginX = 4.0;

// The transform scale applied to the page control so its dots render smaller than the system size.
static const CGFloat kPageControlScale = 0.8;

// Page-indicator tint whites (a grey value from black to white) for the Classic theme, where the
// current page is fully white and the other pages are mid-grey.
static const CGFloat kClassicPageIndicatorWhite = 0.5;
static const CGFloat kClassicCurrentPageIndicatorWhite = 1.0;

// Page-indicator tint whites for every non-Classic theme, where the other pages are a light grey
// and the current page is mid-grey.
static const CGFloat kThemedPageIndicatorWhite = 0.6669999957084656;
static const CGFloat kThemedCurrentPageIndicatorWhite = 0.5;

// Scroll view and page control geometry for the Classic theme with the iPad (wide) layout.
static const CGRect kClassicWideScrollFrame = {{kScrollViewOriginX, 4.0}, {536.0, 600.0}};
static const CGRect kClassicWidePageControlFrame = {{2.0, 615.0}, {540.0, kPageControlHeight}};

// Scroll view and page control geometry for the Classic theme with the narrow iPad idiom.
static const CGRect kClassicNarrowScrollFrame = {{kScrollViewOriginX, 0.0}, {312.0, 300.0}};
static const CGRect kClassicNarrowPageControlFrame = {{60.0, 285.0}, {200.0, kPageControlHeight}};

// Scroll view and page control geometry for a non-Classic theme with the iPad (wide) layout.
static const CGRect kThemedWideScrollFrame = {{kScrollViewOriginX, 30.0}, {536.0, 600.0}};
static const CGRect kThemedWidePageControlFrame = {{2.0, 640.0}, {540.0, kPageControlHeight}};

// Scroll view geometry for a non-Classic theme with the narrow iPad idiom. The scroll view's top
// inset and height differ between Retina and non-Retina; the page control is shared.
static const CGRect kThemedNarrowRetinaScrollFrame = {{kScrollViewOriginX, 0.0}, {312.0, 300.0}};
static const CGRect kThemedNarrowNonRetinaScrollFrame = {{kScrollViewOriginX, 10.0},
                                                         {312.0, 280.0}};
static const CGRect kThemedNarrowPageControlFrame = {{60.0, 295.0}, {200.0, kPageControlHeight}};

@implementation RBHowToView {
    BOOL m_Animating;
    int m_PageNum;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:kMusicMenuPopupViewTypeDefault];
        [self setupView];
    }
    return self;
}

- (void)dealloc {
    for (UIView *page in self.scrollView.subviews) {
        if (page) {
            [(UIImageView *)page setImage:nil];
            page.layer.sublayers = nil;
            [page removeFromSuperview];
        }
    }
    self.scrollView.delegate = nil;
    [self.scrollView removeFromSuperview];
    self.scrollView = nil;
}

- (void)setupView {
    [super setupView];

    CGRect scrollFrame;
    CGRect pageControlFrame;
    CGFloat pageIndicatorWhite;
    CGFloat currentPageIndicatorWhite;

    if ([RBUserSettingData sharedInstance].thema != RBUserSettingDataThemeClassic) {
        pageIndicatorWhite = kThemedPageIndicatorWhite;
        currentPageIndicatorWhite = kThemedCurrentPageIndicatorWhite;
        if (IsPad()) {
            scrollFrame = kThemedWideScrollFrame;
            pageControlFrame = kThemedWidePageControlFrame;
        } else {
            scrollFrame = GetIsRetinaFlag() ? kThemedNarrowRetinaScrollFrame :
                                              kThemedNarrowNonRetinaScrollFrame;
            pageControlFrame = kThemedNarrowPageControlFrame;
        }
    } else {
        pageIndicatorWhite = kClassicPageIndicatorWhite;
        currentPageIndicatorWhite = kClassicCurrentPageIndicatorWhite;
        if (IsPad()) {
            scrollFrame = kClassicWideScrollFrame;
            pageControlFrame = kClassicWidePageControlFrame;
        } else {
            scrollFrame = kClassicNarrowScrollFrame;
            pageControlFrame = kClassicNarrowPageControlFrame;
        }
    }

    m_PageNum = kHowToPlayPageCount;

    self.scrollView = [[UIScrollView alloc] initWithFrame:scrollFrame];
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width * m_PageNum,
                                             self.scrollView.bounds.size.height);
    self.scrollView.delegate = self;
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.contentView addSubview:self.scrollView];

    self.pageControl = [[UIPageControl alloc] initWithFrame:pageControlFrame];
    self.pageControl.numberOfPages = m_PageNum;
    self.pageControl.currentPage = 0;
    self.pageControl.transform = CGAffineTransformMakeScale(kPageControlScale, kPageControlScale);
    [self.pageControl addTarget:self
                         action:@selector(pageDidChangeValue:)
               forControlEvents:UIControlEventValueChanged];
    self.pageControl.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    self.pageControl.pageIndicatorTintColor = [UIColor colorWithWhite:pageIndicatorWhite alpha:1.0];
    self.pageControl.currentPageIndicatorTintColor =
        [UIColor colorWithWhite:currentPageIndicatorWhite alpha:1.0];
    [self.contentView addSubview:self.pageControl];

    for (int page = 0; page < m_PageNum; ++page) {
        [self createViewSame:page];
    }

    [self layoutScrollView];
}

- (void)createViewSame:(int)index {
    if (index > kHowToPlayPageCount - 1) {
        return;
    }

    UIImage *image = [UIImage imageWithName:kHowToPlayPageImageNames[index] useCache:NO];
    UIImageView *pageView = [[UIImageView alloc] initWithImage:image];
    CGFloat pageWidth = self.scrollView.frame.size.width;
    pageView.frame = CGRectMake(index * pageWidth, 0.0, image.size.width, image.size.height);
    pageView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.scrollView addSubview:pageView];
}

- (void)layoutScrollView {
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width * m_PageNum,
                                             self.scrollView.bounds.size.height);
}

- (void)pageDidChangeValue:(id)sender {
    NSInteger page = self.pageControl.currentPage;
    CGFloat pageWidth = self.scrollView.frame.size.width;
    if (self.scrollView && !self.scrollView.isTracking && !self.scrollView.isDragging &&
        !self.scrollView.isDecelerating) {
        [self.scrollView scrollRectToVisible:CGRectMake(page * pageWidth,
                                                        0.0,
                                                        pageWidth,
                                                        self.scrollView.frame.size.height)
                                    animated:YES];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat page = scrollView.contentOffset.x / scrollView.bounds.size.width;
    NSInteger targetPage = (NSInteger)page;
    if (page - (float)targetPage > 0.5) {
        ++targetPage;
    }
    if ((float)self.pageControl.currentPage != (float)targetPage) {
        self.pageControl.currentPage = targetPage;
    }
}

@end
