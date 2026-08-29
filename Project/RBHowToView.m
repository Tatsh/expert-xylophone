#import "RBHowToView.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"

static const int kHowToPlayPageCount = 6;

static NSString *const kHowToPlayPageImageNames[] = {
    @"03_howtoplay/how_1",
    @"03_howtoplay/how_2",
    @"03_howtoplay/how_3",
    @"03_howtoplay/how_4",
    @"03_howtoplay/how_5",
    @"03_howtoplay/how_6",
};

static const CGFloat kPageControlHeight = 24.0;

static const CGFloat kScrollViewOriginX = 4.0;

static const CGFloat kPageControlScale = 0.8;

static const CGFloat kClassicPageIndicatorWhite = 0.5;
static const CGFloat kClassicCurrentPageIndicatorWhite = 1.0;

static const CGFloat kThemedPageIndicatorWhite = 0.667f;
static const CGFloat kThemedCurrentPageIndicatorWhite = 0.5;

static const CGRect kClassicWideScrollFrame = {{kScrollViewOriginX, 4.0}, {536.0, 600.0}};
static const CGRect kClassicWidePageControlFrame = {{2.0, 615.0}, {540.0, kPageControlHeight}};

static const CGRect kClassicNarrowScrollFrame = {{kScrollViewOriginX, 0.0}, {312.0, 300.0}};
static const CGRect kClassicNarrowPageControlFrame = {{60.0, 285.0}, {200.0, kPageControlHeight}};

static const CGRect kThemedWideScrollFrame = {{kScrollViewOriginX, 30.0}, {536.0, 600.0}};
static const CGRect kThemedWidePageControlFrame = {{2.0, 640.0}, {540.0, kPageControlHeight}};

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
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeHowTo];
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
