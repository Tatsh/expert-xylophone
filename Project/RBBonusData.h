/** @file
 * A small @c NSCoding-conforming singleton holding the per-event bonus multipliers awarded during
 * play: the clear, full-combo, and per-miss bonuses, the per-rank bonuses, and the first-play,
 * pastel, early-play, and hot-music campaign bonuses. The instance persists itself to and from the
 * user defaults, keyed by its own class name, and seeds sensible defaults on a fresh install.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBBonusData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief An archivable singleton of the bonus multipliers awarded during play.
 */
@interface RBBonusData : NSObject <NSCoding>

/**
 * @brief The multiplier awarded for clearing a chart.
 * @ghidraAddress 0x1f4054 (getter)
 * @ghidraAddress 0x1f4064 (setter)
 */
@property(nonatomic, assign) float clearBonus;
/**
 * @brief The multiplier awarded for a full combo.
 * @ghidraAddress 0x1f4074 (getter)
 * @ghidraAddress 0x1f4084 (setter)
 */
@property(nonatomic, assign) float fullComboBonus;
/**
 * @brief The multiplier awarded for a single-miss clear.
 * @ghidraAddress 0x1f4094 (getter)
 * @ghidraAddress 0x1f40a4 (setter)
 */
@property(nonatomic, assign) float miss1Bonus;
/**
 * @brief The multiplier awarded for a two-miss clear.
 * @ghidraAddress 0x1f40b4 (getter)
 * @ghidraAddress 0x1f40c4 (setter)
 */
@property(nonatomic, assign) float miss2Bonus;
/**
 * @brief The multiplier awarded for an AAA+ rank.
 * @ghidraAddress 0x1f40d4 (getter)
 * @ghidraAddress 0x1f40e4 (setter)
 */
@property(nonatomic, assign) float rankAAAPBonus;
/**
 * @brief The multiplier awarded for an AAA rank.
 * @ghidraAddress 0x1f40f4 (getter)
 * @ghidraAddress 0x1f4104 (setter)
 */
@property(nonatomic, assign) float rankAAABonus;
/**
 * @brief The multiplier awarded for an AA rank.
 * @ghidraAddress 0x1f4114 (getter)
 * @ghidraAddress 0x1f4124 (setter)
 */
@property(nonatomic, assign) float rankAABonus;
/**
 * @brief The multiplier awarded for an A rank.
 * @ghidraAddress 0x1f4134 (getter)
 * @ghidraAddress 0x1f4144 (setter)
 */
@property(nonatomic, assign) float rankABonus;
/**
 * @brief The multiplier awarded for a B rank.
 * @ghidraAddress 0x1f4154 (getter)
 * @ghidraAddress 0x1f4164 (setter)
 */
@property(nonatomic, assign) float rankBBonus;
/**
 * @brief The multiplier awarded for a tune's first play.
 * @ghidraAddress 0x1f4174 (getter)
 * @ghidraAddress 0x1f4184 (setter)
 */
@property(nonatomic, assign) float firstPlayBonus;
/**
 * @brief The multiplier awarded for a black-pastel campaign tune.
 * @ghidraAddress 0x1f4194 (getter)
 * @ghidraAddress 0x1f41a4 (setter)
 */
@property(nonatomic, assign) float blackPastelBonus;
/**
 * @brief The multiplier awarded for a pastel campaign tune.
 * @ghidraAddress 0x1f41b4 (getter)
 * @ghidraAddress 0x1f41c4 (setter)
 */
@property(nonatomic, assign) float pastelBonus;
/**
 * @brief The multiplier awarded for an early-play campaign tune.
 * @ghidraAddress 0x1f41d4 (getter)
 * @ghidraAddress 0x1f41e4 (setter)
 */
@property(nonatomic, assign) float earlyPlayBonus;
/**
 * @brief The multiplier awarded for a hot-music campaign tune.
 * @ghidraAddress 0x1f41f4 (getter)
 * @ghidraAddress 0x1f4204 (setter)
 */
@property(nonatomic, assign) float hotMusicBonus;

/**
 * @brief Returns the shared bonus-data singleton, unarchiving it from the user defaults or
 * seeding a fresh default-valued instance on first use.
 * @return The shared @c RBBonusData instance.
 * @ghidraAddress 0x1f3df8
 */
+ (instancetype)sharedInstance;

/**
 * @brief Archives the receiver and writes it to the user defaults, keyed by the class name.
 * @ghidraAddress 0x1f3f30
 */
- (void)save;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
