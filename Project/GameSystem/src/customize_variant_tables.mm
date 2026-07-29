//
//  customize_variant_tables.mm
//  REFLEC BEAT plus
//
//  The customize-asset variant-name tables declared in customize_variant_tables.h, transcribed
//  verbatim from the binary's read-only data. BuildCustomizeAssetPathString (0x54ee0) indexes the
//  table matching the asset category to pick the variant token for the asset's path.
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#import "customize_variant_tables.h"

// The BGM (category 0) variant-name table: 36 asset tokens followed by their 36 uppercase
// display keys.
// @ghidraAddress 0x359c50
NSString *const g_aCustomizeBgmVariants[] = {
    @"classic",
    @"limelight",
    @"tag",
    @"qrispy",
    @"yukky",
    @"led",
    @"96",
    @"djtaka",
    @"nekomata",
    @"tomosuke",
    @"djyoshitaka",
    @"qrispy2",
    @"qrispy3",
    @"sota",
    @"scu",
    @"colette",
    @"winter",
    @"spring",
    @"summer",
    @"autumn",
    @"qrispy4",
    @"tag2",
    @"led2",
    @"nekomata2",
    @"scu2",
    @"pon",
    @"2bwaves",
    @"prim",
    @"djsilverberg",
    @"seiya",
    @"totto",
    @"akhuta",
    @"venus",
    @"venus2",
    @"maxmaximizer",
    @"maxmaximizer2",
    @"CUSTOM_CLASSIC",
    @"CUSTOM_LIMELIGHT",
    @"CUSTOM_TAG",
    @"CUSTOM_QRISPY",
    @"CUSTOM_YUKKY",
    @"CUSTOM_LED",
    @"CUSTOM_96",
    @"CUSTOM_DJTAKA",
    @"CUSTOM_NEKOMATA",
    @"CUSTOM_TOMOSUKE",
    @"CUSTOM_DJYOSHITAKA",
    @"CUSTOM_QRISPY2",
    @"CUSTOM_QRISPY3",
    @"CUSTOM_SOTA",
    @"CUSTOM_SCU",
    @"CUSTOM_COLETTE",
    @"CUSTOM_WINTER",
    @"CUSTOM_SPRING",
    @"CUSTOM_SUMMER",
    @"CUSTOM_AUTUMN",
    @"CUSTOM_QRISPY4",
    @"CUSTOM_TAG2",
    @"CUSTOM_LED2",
    @"CUSTOM_NEKOMATA2",
    @"CUSTOM_SCU2",
    @"CUSTOM_PON",
    @"CUSTOM_2BWAVES",
    @"CUSTOM_PRIM",
    @"CUSTOM_DJSILVERBERG",
    @"CUSTOM_SEIYA",
    @"CUSTOM_TOTTO",
    @"CUSTOM_AKHUTA",
    @"CUSTOM_VENUS",
    @"CUSTOM_VENUS2",
    @"CUSTOM_MAXMAXIMIZER",
    @"CUSTOM_MAXMAXIMIZER2",
};

// The shot-sound (category 1) variant-name table: 33 asset tokens, the four judge-sound
// names, then the 33 uppercase display keys.
// @ghidraAddress 0x359e90
NSString *const g_aCustomizeShotVariants[] = {
    @"default1",    @"default2",    @"default3",    @"hockey",     @"volleyball", @"tennis",
    @"baseball",    @"tabletennis", @"electro1",    @"electro2",   @"electro3",   @"electro4",
    @"electro5",    @"electro6",    @"clap",        @"tambourine", @"japan",      @"percussion",
    @"latin",       @"hit",         @"sword",       @"bomb",       @"fight",      @"steel",
    @"light",       @"fireworks",   @"qrispy",      @"sota",       @"96",         @"percussion2",
    @"japan2",      @"pawapuro",    @"jinglebell",  @"JUST",       @"GREAT",      @"GOOD",
    @"RIVAL",       @"DEFAULT1",    @"DEFAULT2",    @"DEFAULT3",   @"HOCKEY",     @"VOLLEYBALL",
    @"TENNIS",      @"BASEBALL",    @"TABLETENNIS", @"ELECTRO1",   @"ELECTRO2",   @"ELECTRO3",
    @"ELECTRO4",    @"ELECTRO5",    @"ELECTRO6",    @"CLAP",       @"TAMBOURINE", @"JAPAN",
    @"PERCUSSION",  @"LATIN",       @"HIT",         @"SWORD",      @"BOMB",       @"FIGHT",
    @"STEEL",       @"LIGHT",       @"FIREWORKS",   @"QRISPY",     @"SOTA",       @"96",
    @"PERCUSSION2", @"JAPAN2",      @"PAWAPURO",    @"JINGLEBELL",
};

// The explosion (category 2) variant-name table.
// @ghidraAddress 0x35a0c0
NSString *const g_aCustomizeExplosionVariants[] = {
    @"classic", @"limelight", @"flame", @"ice",  @"plasma",  @"tornado", @"fireworks",
    @"star",    @"quavre",    @"heart", @"rose", @"copious", @"colette", @"snow",
    @"tentei",  @"flower",    @"maple", @"iidx", @"popn",
};

// The frame (category 3) variant-name table.
// @ghidraAddress 0x35a158
NSString *const g_aCustomizeFrameVariants[] = {
    @"classic_default",  @"classic_bronze",    @"classic_silver",     @"classic_gold",
    @"classic_platinum", @"classic_black",     @"classic_crimson",    @"limelight_default",
    @"limelight_yellow", @"limelight_blue",    @"limelight_red",      @"limelight_black",
    @"limelight_purple", @"limelight_copious", @"colette_allseasons", @"colette_winter",
    @"colette_spring",   @"colette_summer",    @"colette_autumn",     @"colette_green",
    @"colette_yellow",   @"colette_blue",      @"colette_red",        @"colette_tentei",
    @"colette_iidx",     @"colette_popn",      @"colette_spade",      @"colette_heart",
    @"colette_club",     @"colette_dia",       @"colette_joker",
};

// The background (category 4) variant-name table.
// @ghidraAddress 0x35a250
NSString *const g_aCustomizeBackgroundVariants[] = {
    @"classic_default",   @"classic_bronze",     @"classic_silver",    @"classic_gold",
    @"classic_platinum",  @"classic_black",      @"limelight_default", @"limelight_yellow",
    @"limelight_blue",    @"limelight_red",      @"limelight_black",   @"limelight_purple",
    @"limelight_copious", @"colette_allseasons", @"colette_winter",    @"colette_spring",
    @"colette_summer",    @"colette_autumn",     @"colette_green",     @"colette_yellow",
    @"colette_blue",      @"colette_red",        @"colette_tentei",    @"colette_spade",
    @"colette_heart",     @"colette_club",       @"colette_dia",       @"colette_joker",
};

// The object (category 5) size variant-name table.
// @ghidraAddress 0x35a330
NSString *const g_aCustomizeObjectVariants[] = {
    @"big",
    @"medium",
    @"small",
};

// The theme (category 10) variant-name table, indexed by RBUserSettingDataTheme.
// @ghidraAddress 0x35a348
NSString *const g_aCustomizeThemaVariants[] = {
    @"classic",
    @"limelight",
    @"colette",
};
