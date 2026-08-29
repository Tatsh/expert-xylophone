/**
 * @file
 * A small @c NSCoding-conforming singleton holding the per-event bonus multipliers awarded
 * during play.
 *
 * The multipliers are the clear, full-combo, and per-miss bonuses, the per-rank bonuses, and the
 * first-play,
 * pastel, early-play, and hot-music campaign bonuses. The instance persists itself to and from the
 * user defaults, keyed by its own class name, and seeds sensible defaults on a fresh install.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBBonusData, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An archivable singleton of the bonus multipliers awarded during play.
 */
@interface RBBonusData : NSObject <NSCoding>

/**
 * The multiplier awarded for clearing a chart.
 * @ghidraAddress 0x1f4054 (getter)
 * @ghidraAddress 0x1f4064 (setter)
 */
@property(nonatomic, assign) float clearBonus;
/**
 * The multiplier awarded for a full combo.
 * @ghidraAddress 0x1f4074 (getter)
 * @ghidraAddress 0x1f4084 (setter)
 */
@property(nonatomic, assign) float fullComboBonus;
/**
 * The multiplier awarded for a single-miss clear.
 * @ghidraAddress 0x1f4094 (getter)
 * @ghidraAddress 0x1f40a4 (setter)
 */
@property(nonatomic, assign) float miss1Bonus;
/**
 * The multiplier awarded for a two-miss clear.
 * @ghidraAddress 0x1f40b4 (getter)
 * @ghidraAddress 0x1f40c4 (setter)
 */
@property(nonatomic, assign) float miss2Bonus;
/**
 * The multiplier awarded for an AAA+ rank.
 * @ghidraAddress 0x1f40d4 (getter)
 * @ghidraAddress 0x1f40e4 (setter)
 */
@property(nonatomic, assign) float rankAAAPBonus;
/**
 * The multiplier awarded for an AAA rank.
 * @ghidraAddress 0x1f40f4 (getter)
 * @ghidraAddress 0x1f4104 (setter)
 */
@property(nonatomic, assign) float rankAAABonus;
/**
 * The multiplier awarded for an AA rank.
 * @ghidraAddress 0x1f4114 (getter)
 * @ghidraAddress 0x1f4124 (setter)
 */
@property(nonatomic, assign) float rankAABonus;
/**
 * The multiplier awarded for an A rank.
 * @ghidraAddress 0x1f4134 (getter)
 * @ghidraAddress 0x1f4144 (setter)
 */
@property(nonatomic, assign) float rankABonus;
/**
 * The multiplier awarded for a B rank.
 * @ghidraAddress 0x1f4154 (getter)
 * @ghidraAddress 0x1f4164 (setter)
 */
@property(nonatomic, assign) float rankBBonus;
/**
 * The multiplier awarded for a tune's first play.
 * @ghidraAddress 0x1f4174 (getter)
 * @ghidraAddress 0x1f4184 (setter)
 */
@property(nonatomic, assign) float firstPlayBonus;
/**
 * The multiplier awarded for a black-pastel campaign tune.
 * @ghidraAddress 0x1f4194 (getter)
 * @ghidraAddress 0x1f41a4 (setter)
 */
@property(nonatomic, assign) float blackPastelBonus;
/**
 * The multiplier awarded for a pastel campaign tune.
 * @ghidraAddress 0x1f41b4 (getter)
 * @ghidraAddress 0x1f41c4 (setter)
 */
@property(nonatomic, assign) float pastelBonus;
/**
 * The multiplier awarded for an early-play campaign tune.
 * @ghidraAddress 0x1f41d4 (getter)
 * @ghidraAddress 0x1f41e4 (setter)
 */
@property(nonatomic, assign) float earlyPlayBonus;
/**
 * The multiplier awarded for a hot-music campaign tune.
 * @ghidraAddress 0x1f41f4 (getter)
 * @ghidraAddress 0x1f4204 (setter)
 */
@property(nonatomic, assign) float hotMusicBonus;

/**
 * Returns the shared bonus-data singleton, unarchiving it from the user defaults or
 * seeding a fresh default-valued instance on first use.
 * @return The shared @c RBBonusData instance.
 * @ghidraAddress 0x1f3df8
 */
+ (instancetype)sharedInstance;

/**
 * Archives the receiver and writes it to the user defaults, keyed by the class name.
 * @ghidraAddress 0x1f3f30
 */
- (void)save;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
