/**
 * @file
 * The Hinabita campaign portrait layer's anchor and animation-curve tables for
 * @c rb::TitleColetteScene.
 */

#pragma once

/**
 * @brief The five sub-character base X positions the phone layout interpolates from.
 *
 * Each is eased toward the screen centre by the fit scale.
 * @ghidraAddress 0x2fccd8
 */
constexpr float g_aCampaignPortraitPhoneBaseX[] = {190.0f, 280.0f, 384.0f, 488.0f, 581.0f};

/**
 * @brief The six character anchor positions the iPad layout uses directly.
 * @ghidraAddress 0x2fccd0
 */
constexpr float g_aCampaignPortraitPadAnchor[][2] = {
    {389.0f, 1020.0f},
    {190.0f, 1020.0f},
    {280.0f, 1020.0f},
    {384.0f, 1020.0f},
    {488.0f, 1020.0f},
    {581.0f, 1020.0f},
};

/**
 * @brief The entrance alpha (fade-in) curves, one per character.
 *
 * Ordered as the main portrait then five sub-characters; four knots each.
 * @ghidraAddress 0x2fcd00
 */
constexpr float g_aCampaignPortraitEntranceAlpha[][8] = {
    {0.0f, 0.0f, 4150.0f, 0.0f, 4166.66650390625f, 1.0f, 4183.33349609375f, 1.0f},
    {1666.6666259765625f, 0.0f, 2000.0f, 1.0f, 4150.0f, 1.0f, 4166.66650390625f, 0.0f},
    {2333.333251953125f, 0.0f, 2666.666748046875f, 1.0f, 4150.0f, 1.0f, 4166.66650390625f, 0.0f},
    {3000.0f, 0.0f, 3333.333251953125f, 1.0f, 4150.0f, 1.0f, 4166.66650390625f, 0.0f},
    {2666.666748046875f, 0.0f, 3000.0f, 1.0f, 4150.0f, 1.0f, 4166.66650390625f, 0.0f},
    {2000.0f, 0.0f, 2333.333251953125f, 1.0f, 4150.0f, 1.0f, 4166.66650390625f, 0.0f},
};
/**
 * @brief The matching entrance scale curves: a pop that overshoots to 1.2 then settles.
 *
 * Six knots each.
 * @ghidraAddress 0x2fcdc0
 */
constexpr float g_aCampaignPortraitEntranceScale[][12] = {
    {0.0f,
     0.0f,
     4166.66650390625f,
     0.0f,
     4333.33349609375f,
     1.2000000476837158f,
     4416.66650390625f,
     0.8999999761581421f,
     4500.0f,
     1.0f,
     4516.66650390625f,
     1.0f},
    {1666.6666259765625f,
     0.0f,
     1833.3333740234375f,
     1.2000000476837158f,
     1916.6666259765625f,
     0.8999999761581421f,
     2000.0f,
     1.0f,
     3983.333251953125f,
     1.0f,
     4150.0f,
     0.0f},
    {2333.333251953125f,
     0.0f,
     2500.0f,
     1.2000000476837158f,
     2583.333251953125f,
     0.8999999761581421f,
     2666.666748046875f,
     1.0f,
     3983.333251953125f,
     1.0f,
     4150.0f,
     0.0f},
    {3000.0f,
     0.0f,
     3166.666748046875f,
     1.2000000476837158f,
     3250.0f,
     0.8999999761581421f,
     3333.333251953125f,
     1.0f,
     3983.333251953125f,
     1.0f,
     4150.0f,
     0.0f},
    {2666.666748046875f,
     0.0f,
     2833.333251953125f,
     1.2000000476837158f,
     2916.666748046875f,
     0.8999999761581421f,
     3000.0f,
     1.0f,
     3983.333251953125f,
     1.0f,
     4150.0f,
     0.0f},
    {2000.0f,
     0.0f,
     2166.666748046875f,
     1.2000000476837158f,
     2250.0f,
     0.8999999761581421f,
     2333.333251953125f,
     1.0f,
     3983.333251953125f,
     1.0f,
     4150.0f,
     0.0f},
};

/**
 * @brief The SE-reaction scale curve (six knots).
 *
 * Its last knot's time is when the reaction ends.
 * @ghidraAddress 0x2fcee0
 */
constexpr float g_aCampaignPortraitReaction[] = {0.0f,
                                                 1.0f,
                                                 16.66666603088379f,
                                                 1.0f,
                                                 83.33333587646484f,
                                                 1.2000000476837158f,
                                                 133.3333282470703f,
                                                 0.8999999761581421f,
                                                 166.6666717529297f,
                                                 1.0f,
                                                 183.3333282470703f,
                                                 1.0f};
/**
 * @brief The time at which the SE-reaction scale curve ends, matching that curve's last knot time.
 */
constexpr float kCampaignPortraitReactionEnd = 183.3333282470703f;
