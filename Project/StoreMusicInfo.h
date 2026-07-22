/** @file
 * A store music metadata model describing a single purchasable tune: its identifier, display name,
 * artist, the item, artwork, sample, and iTunes URLs, the three per-difficulty levels, and the list
 * of associated extend-note identifiers. Instances are built from a store catalogue entry
 * dictionary and are handed to @c RBMusicManager to record a purchase.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class StoreMusicInfo, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief A store metadata model for a single purchasable tune.
 */
@interface StoreMusicInfo : NSObject

/**
 * @brief The tune identifier.
 * @ghidraAddress 0x68508 (getter)
 * @ghidraAddress 0x68518 (setter)
 */
@property(nonatomic, assign) int musicID;
/**
 * @brief The tune display name.
 * @ghidraAddress 0x68528 (getter)
 * @ghidraAddress 0x68538 (setter)
 */
@property(nonatomic, strong) NSString *name;
/**
 * @brief The tune artist.
 * @ghidraAddress 0x68570 (getter)
 * @ghidraAddress 0x68580 (setter)
 */
@property(nonatomic, strong) NSString *artist;
/**
 * @brief The store item URL for the tune's archive.
 * @ghidraAddress 0x685b8 (getter)
 * @ghidraAddress 0x685c8 (setter)
 */
@property(nonatomic, strong) NSString *itemURL;
/**
 * @brief The tune artwork URL.
 * @ghidraAddress 0x68600 (getter)
 * @ghidraAddress 0x68610 (setter)
 */
@property(nonatomic, strong) NSString *artworkURL;
/**
 * @brief The tune audio sample URL.
 * @ghidraAddress 0x68648 (getter)
 * @ghidraAddress 0x68658 (setter)
 */
@property(nonatomic, strong) NSString *sampleURL;
/**
 * @brief The iTunes store URL, only stored when it passes @c StoreUtil validation.
 * @ghidraAddress 0x68690 (getter)
 * @ghidraAddress 0x686a0 (setter)
 */
@property(nonatomic, strong) NSString *itunesURL;
/**
 * @brief The basic-difficulty level, clamped to the range one to fifteen inclusive.
 * @ghidraAddress 0x686d8 (getter)
 * @ghidraAddress 0x686e8 (setter)
 */
@property(nonatomic, assign) int lvBasic;
/**
 * @brief The medium-difficulty level, clamped to the range one to fifteen inclusive.
 * @ghidraAddress 0x686f8 (getter)
 * @ghidraAddress 0x68708 (setter)
 */
@property(nonatomic, assign) int lvMedium;
/**
 * @brief The hard-difficulty level, clamped to the range one to fifteen inclusive.
 * @ghidraAddress 0x68718 (getter)
 * @ghidraAddress 0x68728 (setter)
 */
@property(nonatomic, assign) int lvHard;
/**
 * @brief The identifiers of the extend-note charts associated with the tune, if any.
 * @ghidraAddress 0x68738 (getter)
 * @ghidraAddress 0x68748 (setter)
 */
@property(nonatomic, strong) NSArray *extIDList;

/**
 * @brief Build a store music info from a catalogue entry dictionary.
 *
 * The dictionary provides the @c ID, @c Name, @c Artist, @c ItemURL, @c SampleURL, @c ArtworkURL,
 * @c iTunesURL, @c Level, and @c PID entries. A non-positive identifier yields @c nil. The
 * @c iTunesURL is only stored when @c StoreUtil accepts it, the three @c Level entries are clamped
 * to one to fifteen inclusive, and the @c PID list is copied only when it is non-empty.
 * @param dictionary The catalogue entry dictionary to read.
 * @return The initialised instance, or @c nil when the identifier is not positive.
 * @ghidraAddress 0x67e84
 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

/**
 * @brief Whether the tune's archive is already present on disk.
 *
 * Checks the current purchased-music directory first and then the legacy caches directory.
 * @return @c YES when the archive exists in either location.
 * @ghidraAddress 0x683f0
 */
- (BOOL)fileExist;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
