/**
 * @file
 * The full-screen resource-download flow.
 *
 * It is the view controller the app delegate presents to
 * refresh the downloadable game-asset bundle: it asks the server for the current resource version
 * and item URL, compares that against the installed version, downloads the asset archive to the
 * Caches directory, unzips it into the image-asset directory, and verifies the extracted file list
 * before dismissing itself back to the title screen. While it runs it shows a help carousel, an
 * animated progress bar, and a background effect.
 *
 * The binary models this class as a @c UIViewController subclass named
 * @c RBResourceDownloadViewController (its instances are the app delegate's
 * @c resourceDownloadViewController); its selectors, ivars, and the preserved "Resoure" misspelling
 * in its background-effect view type are reproduced verbatim.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBResourceDownloadViewController,
 * image base 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"
#import "SSZipArchive.h"

@class Downloader, RBResoureDownloadBGEffectView;

NS_ASSUME_NONNULL_BEGIN

/**
 * Presents and drives the downloadable game-asset refresh flow.
 *
 * It is both the @c NSURLSession download delegate for the asset archive and the @c SSZipArchive
 * delegate for its extraction, and it doubles as the @c UIScrollView delegate and the
 * @c UIAlertView delegate for its help carousel and error prompts.
 */
@interface RBResourceDownloadViewController :
    RBBaseViewController <NSURLSessionDownloadDelegate,
                          SSZipArchiveDelegate,
                          UIScrollViewDelegate,
                          UIAlertViewDelegate>

/**
 * The item URL to download the asset archive from, taken from the server response.
 * @ghidraAddress 0x20380 (getter)
 * @ghidraAddress 0x20390 (setter)
 */
@property(copy, nonatomic, nullable) NSString *downloadPath;
/**
 * The resource version reported by the server, persisted once the download succeeds.
 * @ghidraAddress 0x2039c (getter)
 * @ghidraAddress 0x203ac (setter)
 */
@property(copy, nonatomic, nullable) NSString *version;
/**
 * Whether to force a re-check even when the installed version already matches.
 * @ghidraAddress 0x203b8 (getter)
 * @ghidraAddress 0x203c8 (setter)
 */
@property(nonatomic, assign) BOOL forceCheck;
/**
 * The in-flight version-query data task, cancelled when the view disappears.
 * @ghidraAddress 0x203d8 (getter)
 * @ghidraAddress 0x203e8 (setter)
 */
@property(nonatomic, strong, nullable) NSURLSessionDataTask *dataTask;
/**
 * The connection that fetches the resource-version information from the server.
 * @ghidraAddress 0x20420 (getter)
 * @ghidraAddress 0x20430 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *downloader;
/**
 * The in-flight asset-archive download task, cancelled when the view disappears.
 * @ghidraAddress 0x20468 (getter)
 * @ghidraAddress 0x20478 (setter)
 */
@property(nonatomic, strong, nullable) NSURLSessionDownloadTask *downloadTask;
/**
 * The container view that holds the help carousel and the progress artwork.
 * @ghidraAddress 0x204b0 (getter)
 * @ghidraAddress 0x204c0 (setter)
 */
@property(nonatomic, strong, nullable) UIView *helpView;
/**
 * The resizable background image behind the help carousel.
 * @ghidraAddress 0x204f8 (getter)
 * @ghidraAddress 0x20508 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *scrollBGView;
/**
 * The paged scroll view that presents the help pages.
 * @ghidraAddress 0x20540 (getter)
 * @ghidraAddress 0x20550 (setter)
 */
@property(nonatomic, strong, nullable) UIScrollView *scrollView;
/**
 * The page control mirroring the help carousel's current page.
 * @ghidraAddress 0x20588 (getter)
 * @ghidraAddress 0x20598 (setter)
 */
@property(nonatomic, strong, nullable) UIPageControl *pageControl;
/**
 * The gradient overlay drawn above the progress artwork.
 * @ghidraAddress 0x205d0 (getter)
 * @ghidraAddress 0x205e0 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *gradView;
/**
 * The container view holding the pastel progress artwork.
 * @ghidraAddress 0x20618 (getter)
 * @ghidraAddress 0x20628 (setter)
 */
@property(nonatomic, strong, nullable) UIView *pastelView;
/**
 * The "pop" artwork that animates in when the download finishes.
 * @ghidraAddress 0x20660 (getter)
 * @ghidraAddress 0x20670 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *popImageView;
/**
 * The static pastel background of the progress meter.
 * @ghidraAddress 0x206a8 (getter)
 * @ghidraAddress 0x206b8 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *pastelImageView;
/**
 * The full-length progress track artwork.
 * @ghidraAddress 0x206f0 (getter)
 * @ghidraAddress 0x20700 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *trackImageView;
/**
 * The clipped progress-fill artwork whose width tracks the download or unzip progress.
 * @ghidraAddress 0x20738 (getter)
 * @ghidraAddress 0x20748 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *progressImageView;
/**
 * The black fade overlay used to transition into and out of the flow.
 * @ghidraAddress 0x20780 (getter)
 * @ghidraAddress 0x20790 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *fadeImageView;
/**
 * The animated particle background shown for the iPad (wide) layout.
 * @ghidraAddress 0x207c8 (getter)
 * @ghidraAddress 0x207d8 (setter)
 */
@property(nonatomic, strong, nullable) RBResoureDownloadBGEffectView *bgEffectView;
/**
 * Which phase drives the progress fill: download, unzip, or verification.
 * @ghidraAddress 0x20810 (getter)
 * @ghidraAddress 0x20820 (setter)
 */
@property(nonatomic, assign) int progressMode;
/**
 * The total number of files reported by the archive during extraction.
 * @ghidraAddress 0x20830 (getter)
 * @ghidraAddress 0x20840 (setter)
 */
@property(assign) int allFileCount;
/**
 * The number of files extracted so far.
 * @ghidraAddress 0x20850 (getter)
 * @ghidraAddress 0x20860 (setter)
 */
@property(assign) int currentFileCount;
/**
 * Whether the "pop" completion animation should run on the next appearance.
 * @ghidraAddress 0x20870 (getter)
 * @ghidraAddress 0x20884 (setter)
 */
@property(assign) BOOL nextAnimation;
/**
 * The download job descriptor (download path, file name, document path, target path, and
 * archive password) built for the current archive.
 * @ghidraAddress 0x20894 (getter)
 * @ghidraAddress 0x208a4 (setter)
 */
@property(strong, nullable) NSDictionary *fileInfoDic;

/**
 * Verify the extracted asset list: unzip the manifest, then confirm every listed file exists
 * in the image-asset directory.
 * @return @c YES when the manifest and every file it lists are present; otherwise @c NO.
 * @ghidraAddress 0x1c2bc
 */
+ (BOOL)checkFile;

/**
 * Start the resource-version request or, when an item URL is already known, the download.
 * @ghidraAddress 0x19f74
 */
- (void)download;
/**
 * Resume the paused asset download and clear the persisted pause flag.
 * @ghidraAddress 0x1a01c
 */
- (void)resume;
/**
 * Suspend the asset download and persist the pause flag.
 * @ghidraAddress 0x1a0e8
 */
- (void)pause;
/**
 * Query the server for the current resource version and item URL.
 * @ghidraAddress 0x1aad8
 */
- (void)request;
/**
 * Play the "pop" completion animation, then schedule the next retry pass.
 * @ghidraAddress 0x1a5bc
 */
- (void)animation;
/**
 * Download the asset archive at @p urlString to the Caches directory as a background task.
 * @param urlString The absolute URL of the asset archive.
 * @ghidraAddress 0x1b994
 */
- (void)downloadWithURLString:(NSString *)urlString;
/**
 * Extract the downloaded archive described by @p info into the image-asset directory.
 * @param info The @c fileInfoDic download descriptor.
 * @ghidraAddress 0x1bdfc
 */
- (void)unzip:(NSDictionary *)info;
/**
 * Persist the new resource version, then verify the extracted files and dismiss on success.
 * @ghidraAddress 0x1c0d8
 */
- (void)success;
/**
 * Update the progress-fill width from a fractional progress value (main thread).
 * @param progress A boxed @c float in the range 0..1.
 * @ghidraAddress 0x1c72c
 */
- (void)updateProgress:(NSNumber *)progress;
/**
 * Build the help-carousel and progress views and lay them out.
 * @ghidraAddress 0x1caf8
 */
- (void)setupView;
/**
 * Add one help-page image at the given page index to the scroll view.
 * @param index The zero-based help-page index (0..5).
 * @ghidraAddress 0x1e84c
 */
- (void)createViewSame:(int)index;
/**
 * Re-lay out the help and pastel views for the current bounds and orientation.
 * @ghidraAddress 0x1ea20
 */
- (void)updateLayout;
/**
 * Recompute the scroll view's content size from the page count.
 * @ghidraAddress 0x1f600
 */
- (void)layoutScrollView;
/**
 * Scroll the help carousel to the page the page control was changed to.
 * @param sender The page control that fired the value-changed event.
 * @ghidraAddress 0x1f6c4
 */
- (void)pageDidChangeValue:(UIPageControl *)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
