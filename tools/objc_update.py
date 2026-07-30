#!/usr/bin/env python3
"""Regenerate OBJC_METHODS.md: every Objective-C method in the binary, with its status.

The counterpart to :mod:`cxx_update` for the Objective-C side. Where that checklist is driven by
Ghidra's function list, this one is driven by the shipped binary's own runtime metadata, which names
every class, category, method and property the application defines. Nothing Apple ships appears
there: a framework's classes live in the framework, so the only Apple-derived entries are the
categories this application adds to Apple classes, which are the application's own code.

Two statuses are tracked per method and they mean different things.

``Reconstructed``
    The method has a reconstruction in the source tree, either an explicit definition inside the
    class's ``@implementation`` or a ``@property`` that synthesises it.

``Verified``
    The reconstruction has been read against the disassembly, per the five-step process in
    ``.claude/rules/reconstruction.md``. A method can be reconstructed and unverified; that is the
    normal state, and the point of the checklist is to make the gap visible.

Usage: ``tools/objc_update.py <binary>``, where the binary is the one **inside the .ipa** — the
unpacked copy under ``rb458orig`` is a different build and matches nothing.
"""
import argparse
import glob
import re
import struct
import sys
from pathlib import Path
from typing import NamedTuple

PATH = 'OBJC_METHODS.md'
IMAGE_BASE = 0x100000000
DONE = '✅'
NOT = '❌'
_LC_SEGMENT_64 = 0x19
_ZERO_FILL = ('__bss', '__common')
# Methods the compiler emits for a class with ARC-managed or C++-typed ivars. They have no
# reconstruction and never will, so they are counted and excluded rather than listed.
_COMPILER_GENERATED = ('.cxx_construct', '.cxx_destruct')

# Methods read against the disassembly, keyed by their address in the image-base-stripped form.
# A routine belongs here only once its body has actually been compared, not merely because it was
# read or because a constant in it was checked.
VERIFIED = {
    # ApplilinkCore's flag block at 0x3df630, each accessor distinguished only by its
    # displacement; every byte's readers and writers were checked by cross-reference.
    0x214c00: 'ApplilinkCore +setNavigationBarCommonAppearance:: stores the argument verbatim',
    0x214c10: 'ApplilinkCore +isNavigationBarCommonAppearance: byte load, no cset',
    0x214c20: 'ApplilinkCore +setPriorityDeviceLanguages:: stores the argument verbatim',
    0x214c30: 'ApplilinkCore +isPriorityDeviceLanguages: byte load at +0x4',
    0x214c40: 'ApplilinkCore +setIndicatorColor:: objc_storeStrong inlined',
    0x214c6c: 'ApplilinkCore +getIndicatorColor: the nil arm substitutes whiteColor, so it never '
              'returns nil, which is why the declaration is no longer nullable',
    0x214cb4: 'ApplilinkCore +unusedInStore: stores 1, despite the name',
    0x214cc8: 'ApplilinkCore +isUsedInStore: byte load at +0x5, no inversion',
    0x214cd8: 'ApplilinkCore +buildUnderXcode6: stores 1 at +0x6',
    0x214cec: 'ApplilinkCore +isBuildXcode6: mvn then and #1, the inverse of the stored byte',
    0x214fb4: 'ApplilinkCore +isInitializingFlg: the byte at +0, written by the initialize family',
    0x214fc4: 'ApplilinkCore +isInitializeStatusFlg: the byte at +0x1',
    0x214fd4: 'ApplilinkCore +appliId: objectForKey: with the ApplilinkNetwork.appliId key',
    0x215040: 'ApplilinkCore +currentUdid: cbz at 0x215084 sends the false case away, so the '
              'advertising UDID is the arm taken when tracking is available, not unavailable',
    # RBPopoverBackgroundView. The four extents predicates were cross-checked against each other,
    # and the field order comes from the ivar type encoding rather than from the offsets alone.
    0xd7c14: 'RBPopoverBackgroundView +contentViewInsets: 8.0 copied to all four registers',
    0xd7c28: 'RBPopoverBackgroundView +arrowHeight: 19.0 as an fmov immediate',
    0xd7c30: 'RBPopoverBackgroundView +arrowBase: 37.0, a pool load from 0x3014d8',
    0xd7c3c: 'RBPopoverBackgroundView -halfArrowBase: arrowBase times 0.5',
    0xd7c68: 'RBPopoverBackgroundView -initWithFrame:: only d0 and d1 come from the zero '
             'constant; d2 and d3 carry the incoming size, saved before super clobbers them',
    0xd8720: 'RBPopoverBackgroundView -arrowCenter: mid-X on the up or down arm, mid-Y otherwise',
    0xd878c: 'RBPopoverBackgroundView -wantsUpOrDownArrow: short-circuits on wantsUpArrow',
    0xd87d8: 'RBPopoverBackgroundView -wantsUpArrow: tests 1 where its sibling tests 2',
    0xd87fc: 'RBPopoverBackgroundView -isArrowBetweenLeftAndRightEdgesOfPopover: right first',
    0xd8844: 'RBPopoverBackgroundView -isArrowAtLeftEdgeOfPopover: fsub against left at +0',
    0xd8878: 'RBPopoverBackgroundView -isArrowAtRightEdgeOfPopover: fadd against right at +0x8',
    0xd88b0: 'RBPopoverBackgroundView -isArrowBetweenTopAndBottomEdgesOfPopover: top first',
    0xd88f8: 'RBPopoverBackgroundView -isArrowAtTopEdgeOfPopover: fsub against top at +0x10',
    0xd8930: 'RBPopoverBackgroundView -isArrowAtBottomEdgeOfPopover: fadd against bottom at +0x18',
    # MusicData. Each comparator's selector reference was resolved on its own rather than
    # extrapolated from the first, and all five are distinct.
    0x60044: 'MusicData -dealloc: clears artworkCache, then the ARC-emitted super call',
    0x65c5c: 'MusicData -compareMusicID:: MusicID, signed cset gt with a csel on lt',
    0x660f8: 'MusicData -compareDifficultyBasic:: difficultyBasic',
    0x6617c: 'MusicData -compareDifficultyMedium:: difficultyMedium',
    0x66200: 'MusicData -compareDifficultyHard:: difficultyHard',
    0x66284: 'MusicData -compareDifficultySpecial:: difficultySpecial',
    0x66308: 'MusicData -isArtworkCache: one send, then cset ne',
    0x667b4: 'MusicData -setArtworkCache:: objc_setProperty_atomic on _artworkCache',
    0x667c0: 'MusicData -artworkCacheBasic: objc_getProperty with atomic set',
    0x667d0: 'MusicData -setArtworkCacheBasic:: _artworkCacheBasic at 152',
    0x667dc: 'MusicData -artworkCacheMedium: objc_getProperty with atomic set',
    0x667ec: 'MusicData -setArtworkCacheMedium:: _artworkCacheMedium at 160',
    0x667f8: 'MusicData -artworkCacheHard: objc_getProperty with atomic set',
    0x66808: 'MusicData -setArtworkCacheHard:: _artworkCacheHard at 168, distinct from Medium',
    # AudioManager's sound-effect family. The three singular methods return the engine call's
    # result and the three -All methods discard it, which is a real asymmetry in the binary.
    0x3e868: 'AudioManager -releaseBgm: stop, then a tail call clearing the player',
    0x3edd0: 'AudioManager -playSeSetGroup:resourceId:groupId:: -1 only when both tests fail',
    0x3ee78: 'AudioManager -stopSe:: both arms fall into and w0,w0,w8 with no mov w0,#1, so the '
             'engine result is returned rather than YES',
    0x3eefc: 'AudioManager -onPauseSe:: the same shape',
    0x3ef80: 'AudioManager -offPauseSe:: the same shape',
    0x3f004: 'AudioManager -isPlayingSe:: the playing constant is 2, from an immediate',
    0x3f090: 'AudioManager -onPauseSeAll: four slots, no free-slot test, returns 1 unconditionally',
    0x3f110: 'AudioManager -offPauseSeAll: the same shape',
    0x3f190: 'AudioManager -stopSeAll: the same shape',
    0x3f210: 'AudioManager -stopAll: three sends, all results discarded',
    0x3f544: 'AudioManager -stopOldInstance: the shift copies handle and group but not busId',
    0x3f5e4: 'AudioManager -addInstance:group:: stores at most once, at the first free slot',
    0x3f624: 'AudioManager -setSeVolume:groupId:: b.hi at 0x3f640 is unsigned, so a negative '
             'volume is rejected too',
    0x3f6a8: 'AudioManager -deleteFadeTimer: invalidate, then a tail call clearing the timer',
    0xa1e08: 'RBMenuView -setCurrentPageIndex:: the guard sends currentPageIndex rather than '
             'reading the ivar, and the label pair at 0xa1eac is (index + 1, maxPage)',
    0xa1f24: 'RBMenuView -setMaxPage:: the csel takes 1 when the argument is zero',
    0xb8b14: 'RBMenuView -setCurrentMenuMode:: b.cs at 0xb8b2c is unsigned, so a negative mode '
             'takes the second arm',
    0x1e9628: 'RBStorePageViewController -numPackRows: lsr, so the halving is unsigned',
    0x1eb708: 'RBStorePageViewController -numberOfSectionsInTableView:: 3 on the phone, 1 on the '
              'pad, from a csel on the m_IsPad ivar',
    0x1eb728: 'RBStorePageViewController -tableView:numberOfRowsInSection:: b.cc at 0x1eb7a8 is '
              'unsigned, and the continued flag is added zero-extended',
    0x1eb838: 'RBStorePageViewController -tableView:heightForRowAtIndexPath:: the pad pair at '
              '0x30bed0 is 60/140 and the phone pair at 0x30bee0 is 60/80, which is the swap this '
              'fixes; the row test is a signed cset lt',
    0x200778: 'RBNumberLabel -initWithFrame:: the clear background and a zero number from movi',
    0xf2468: 'StoreDownloadManager -initWithTasks:delegate:: nil tasks return nil before super',
    0xf3678: 'StoreDownloadManager -dealloc: cancels an in-flight downloader and clears it',
    0xf25c4: 'StoreDownloadManager -currentProgress: forwards to the file downloader',
    0xf262c: 'StoreDownloadManager -overallProgress: both ucvtf are unsigned, matching the '
             'unsigned index and count, and the operand order is (index + progress) / tasks',
    0xf268c: 'StoreDownloadManager -numTasks: the task count, returned 64-bit',
    0xf26ec: 'StoreDownloadManager -start: the flag and the index are ivar accesses, not sends',
    0xf299c: 'StoreDownloadManager -cancel: the whole body sits inside the downloader guard',
    0xf2a88: 'StoreDownloadManager -restart: tail-calls -start when not started, clears the '
             'downloader before the bound test, and b.cs at 0xf2b14 is unsigned',
    0xf2e40: 'StoreDownloadManager -downloaderFinished:: writeToFile: takes the address of a '
             'zeroed NSError local, not nil, and b.cs at 0xf3020 is unsigned',
    0xf3434: 'StoreDownloadManager -downloaderProceed:: the respondsToSelector guard and nothing '
             'else',
    0xf3514: 'StoreDownloadManager -downloaderError:: the idle timer is cleared first and the '
             'delegate is notified whether or not a downloader was present',
    # RBExperienceData's unlock family: fast enumeration over one collection each, comparing
    # intValue against the argument. Each was read separately, since the bodies are identical
    # apart from the collection they enumerate.
    0x1ba21c: 'RBExperienceData -unlockWithExprosionType:: explosionItems',
    0x1ba370: 'RBExperienceData -unlockWithFrameType:: frameItems',
    0x1ba4c4: 'RBExperienceData -unlockWithBackgroundType:: backgroundItems',
    0x1ba618: 'RBExperienceData -unlockWithMusicID:: musicItems',
    0x1ba76c: 'RBExperienceData -unlockWithThemaID:: themaItems',
    0x1ba8c0: 'RBExperienceData -unlockWithType:ID:: the jump table at 0x1ba954 gives 0-4, 7 and '
              '10, with 5, 6, 8 and 9 falling to the b.hi #0xa default that returns NO',
    # RBUserSettingData, all twenty-three read. Twelve defects, of which ten were one invented
    # selector shared across the reset family.
    0x1f4214: 'RBUserSettingData -init: super, then setDefault under a nil guard',
    0x1f4288: 'RBUserSettingData -setDefault: the three customise dictionaries in key order, and '
              'the 0.9 effect size at 0x2ef17c rather than its 96.0 neighbour',
    0x1f5038: 'RBUserSettingData -initWithCoder:: the version re-read decides the default arm, and '
              'totalPurchase precedes purchaseLimitType, the reverse of encode',
    0x1f6214: 'RBUserSettingData -encodeWithCoder:: all fifty-three encodes, including the two '
              'orderings inverted relative to the decoder',
    0x1f6ba0: 'RBUserSettingData -resetBgmType: writes its key directly',
    0x1f6cac: 'RBUserSettingData -resetShotType: writes its key directly',
    0x1f6db8: 'RBUserSettingData -resetExplosionType: writes its key directly',
    0x1f6ec4: 'RBUserSettingData -resetFrameType: writes its key directly',
    0x1f6fd0: 'RBUserSettingData -resetBackgroundType: writes its key directly',
    0x1f70dc: 'RBUserSettingData -resetNoteType: writes its key directly',
    0x1f71e8: 'RBUserSettingData -resetGaugeStyle: writes its key directly',
    0x1f736c: 'RBUserSettingData -resetShotVolume: writes its key directly',
    0x1f7480: 'RBUserSettingData -resetBackgroundBrightness: writes its key directly',
    0x1f72f4: 'RBUserSettingData -resetGhostStyle:: the guard compares a ghost-style value, not a '
              'theme; right number, wrong domain before',
    0x1f7cb4: 'RBUserSettingData +sharedInstance: a plain nil test, re-checked after the unarchive',
    0x1f7ee8: 'RBUserSettingData -save: the defaults are fetched twice, as the source has it',
    0x1f800c: 'RBUserSettingData -themaName: tail-calls +themaNameWithID: with the current theme',
    0x1f8048: 'RBUserSettingData -themaPath: pathForResource:ofType: with the bundle type',
    0x1f80fc: 'RBUserSettingData +themaNameWithID:: four arms, each string read from its literal',
    0x1f8160: 'RBUserSettingData -needUpdateTerms:: NSNumericSearch, and cset eq on cmn is exactly '
              'the ascending test',
    0x1f8234: 'RBUserSettingData -updateTutorialStatus:value:: the binary boxes both halves with '
              'numberWithInt:, so an unsigned boxing would not match on the read side',
    0x1f83a4: 'RBUserSettingData -getTutorialStatus:: numberWithInt: on the lookup key, agreeing '
              'with the write side',
    0x1f8494: 'RBUserSettingData -getTutorialStatusList: fast enumeration, b.cc is unsigned',
    0x1f7594: 'RBUserSettingData -setThema:: b.ls is unsigned, all six fallback defaults, the '
              'nine coder keys in order, and the trailing switch that leaves an unknown theme '
              "alone; the binary re-sends customizeItems per key where the source caches it, "
              'and sends objectAtIndex:/objectForKey: where the style rules require subscripting',
    0x20084c: 'RBNumberLabel -setNumber:: compares, stores, then redraws',
    0x200874: 'RBNumberLabel -setImageType:: the same shape on a 64-bit ivar',
    # RecommendCore, forty-two methods read against the disassembly; twelve defects fixed,
    # including two more invented selectors that were really block bodies.
    0x236978: 'RecommendCore: read against the disassembly',
    0x236b4c: 'RecommendCore: read against the disassembly',
    0x236c64: 'RecommendCore: the shared instance is the same global +allocWithZone: '
              'uses, not a method-local static',
    0x236d24: 'RecommendCore: read against the disassembly',
    0x236d3c: 'RecommendCore: read against the disassembly',
    0x236d4c: 'RecommendCore: read against the disassembly',
    0x236e4c: 'RecommendCore: the appliId exit calls the block unguarded, unlike the '
              'createUdid exit',
    0x237778: 'RecommendCore: none of the six callback invocations is nil-guarded',
    0x237bb0: 'RecommendCore: the tag belonged to the block body at 0x237c48, and that '
              'call is unguarded',
    0x237cd0: 'RecommendCore: read against the disassembly',
    0x237d6c: 'RecommendCore: read against the disassembly',
    0x237fe4: 'RecommendCore: read against the disassembly',
    0x238260: 'RecommendCore: read against the disassembly',
    0x2385d8: 'RecommendCore: read against the disassembly',
    0x2387d0: 'RecommendCore: read against the disassembly',
    0x238848: 'RecommendCore: b.cc at 0x238ce8 is unsigned, the rect is {0, 0, w, h} from '
              'two frame sends, and the delegate passed on is the captured self',
    0x23a40c: 'RecommendCore: read against the disassembly',
    0x23a5ac: 'RecommendCore: read against the disassembly',
    0x23a644: 'RecommendCore: read against the disassembly',
    0x23a660: 'RecommendCore: read against the disassembly',
    0x23b420: 'RecommendCore: the model key boxes with numberWithUnsignedInt:, which must '
              'match the read side',
    0x23b758: 'RecommendCore: read against the disassembly',
    0x23b82c: 'RecommendCore: read against the disassembly',
    0x23b8c0: 'RecommendCore: read against the disassembly',
    0x23d5c0: 'RecommendCore: read against the disassembly',
    0x23d744: 'RecommendCore: read against the disassembly',
    0x23d7f8: 'RecommendCore: read against the disassembly',
    0x23d84c: 'RecommendCore: read against the disassembly',
    0x23d8cc: 'RecommendCore: read against the disassembly',
    0x23d9d4: 'RecommendCore: read against the disassembly',
    0x23daf4: 'RecommendCore: read against the disassembly',
    0x23dc50: 'RecommendCore: read against the disassembly',
    0x23ddf8: 'RecommendCore: read against the disassembly',
    0x23dfa0: 'RecommendCore: read against the disassembly',
    0x23e148: 'RecommendCore: read against the disassembly',
    0x23e1b0: 'RecommendCore: read against the disassembly',
    0x23e250: 'RecommendCore: read against the disassembly',
    0x23e300: 'RecommendCore: read against the disassembly',
    0x23e3d0: 'RecommendCore: read against the disassembly',
    0x23e454: 'RecommendCore: read against the disassembly',
    0x23e4e0: 'RecommendCore: read against the disassembly',
    0x23e5ac: 'RecommendCore: the controller arm sends FailLink, not FailOpen; only the '
              'nil arm sends FailOpen',
    # ApplilinkUdid, thirty-six methods read; the seventeen string literals and every kSec
    # constant were decoded from the binary rather than taken from a label.
    0x22b5f0: 'ApplilinkUdid: -init takes the shared queue, it does not mint one',
    0x22b7c4: 'ApplilinkUdid: +allocWithZone: creates the queue in its once block',
    0x22b8c4: 'ApplilinkUdid: +sharedInstance shares its slot with +allocWithZone:',
    0x22b9ac: 'ApplilinkUdid: read against the disassembly',
    0x22bb94: 'ApplilinkUdid: read against the disassembly',
    0x22bcc0: 'ApplilinkUdid: read against the disassembly',
    0x22bee8: 'ApplilinkUdid: read against the disassembly',
    0x22c00c: 'ApplilinkUdid: read against the disassembly',
    0x22c0d8: 'ApplilinkUdid: read against the disassembly',
    0x22c1a4: 'ApplilinkUdid: read against the disassembly',
    0x22c2f4: 'ApplilinkUdid: read against the disassembly',
    0x22c508: 'ApplilinkUdid: read against the disassembly',
    0x22c63c: 'ApplilinkUdid: read against the disassembly',
    0x22c8b8: 'ApplilinkUdid: the index bound at 0x22c8d4 is unsigned',
    0x22c9f0: 'ApplilinkUdid: read against the disassembly',
    0x22ca54: 'ApplilinkUdid: read against the disassembly',
    0x22cb28: 'ApplilinkUdid: read against the disassembly',
    0x22cba4: 'ApplilinkUdid: read against the disassembly',
    0x22cc98: 'ApplilinkUdid: read against the disassembly',
    0x22ce18: 'ApplilinkUdid: the use count boxes with numberWithInteger:',
    0x22d3ec: 'ApplilinkUdid: the kSecMatchLimit pair is transposed in the shipped binary',
    0x22d52c: 'ApplilinkUdid: read against the disassembly',
    0x22d69c: 'ApplilinkUdid: read against the disassembly',
    0x22d980: 'ApplilinkUdid: the same transposed pair, instruction for instruction',
    0x22db4c: 'ApplilinkUdid: read against the disassembly',
    0x22dcac: 'ApplilinkUdid: read against the disassembly',
    0x22dcf8: 'ApplilinkUdid: read against the disassembly',
    0x22ddac: 'ApplilinkUdid: ASIdentifierManager is messaged directly; AdSupport really is linked',
    0x22de2c: 'ApplilinkUdid: read against the disassembly',
    0x22e42c: 'ApplilinkUdid: read against the disassembly',
    0x22e52c: 'ApplilinkUdid: read against the disassembly',
    0x22e5d4: 'ApplilinkUdid: read against the disassembly',
    0x22e6bc: 'ApplilinkUdid: read against the disassembly',
    0x22e9c4: 'ApplilinkUdid: read against the disassembly',
    0x22ea4c: 'ApplilinkUdid: -UUIDString is a direct send, not performSelector:',
    0x22ec0c: 'ApplilinkUdid: read against the disassembly',
    # RecommendCore, the nine it had not reached, plus the block bodies behind them. The
    # tenth, -linkActionWithDefaultScheme: at 0x23d0dc, is read and NOT ticked: it passes
    # objects where the callee formats them with %d, and correcting that crosses a file
    # this pass did not own, so the mismatch stands recorded rather than half-fixed.
    0x239480: 'RecommendCore -openAdAreaWithParentView:rect:...: b.cc at 0x239548 is '
              'unsigned, and the variadic pushes two arguments into a %d_%@.html '
              'format, not one',
    0x239ed8: 'RecommendCore -openFullViewControllerWithAdModel:...: the no-banner arm '
              'already passed its adModel',
    0x23a674: 'RecommendCore -redirectWithRequest:appParam:: the nil-url and '
              'canOpenURL-false arms both fall through and run the rest, and the not- '
              'close case returns 1',
    0x23c11c: 'RecommendCore -showOwnAdWithAdLocation:toAppliId:creativeId:: the guards '
              'and the session capture set',
    0x23bb5c: 'RecommendCore '
              '-postAnalysisListRegistWithAdType:AdModel:adLocation:impressionId:: five '
              'arrays built, four posted; the ad_id array is filled and never passed',
    0x23c5fc: 'RecommendCore -touchOwnAdWithAdLocation:...: three guards and the shared '
              'failure tail',
    0x23d330: 'RecommendCore -setUniqueAdWithAdLocation:impressionId:: remove on a nil '
              'impression, else set',
    0x23d4cc: 'RecommendCore -getUniqueAdWithAdLocation:: nil-guarded unarchive then objectForKey:',
    # ApplilinkUdid, the last six; the class is now complete at 42 of 42.
    0x22d040: 'ApplilinkUdid: the date and the length are both used, not discarded; the '
              'return is the account string, not the attribute dictionary',
    0x22dec0: 'ApplilinkUdid: sixteen appendFormat: iterations over a stack digest',
    0x22dfd8: 'ApplilinkUdid: four arms on the tracking path, and the two NO returns '
              'differ by one instruction',
    0x22e2cc: 'ApplilinkUdid: the same all-nil guard, but this one does not clear the '
              'initialise flag',
    0x22e7a4: 'ApplilinkUdid: a nil record, not merely a nil index, falls through to '
              'the old-service branch',
    0x22edb4: 'ApplilinkUdid: reads the singleton slot directly, so it is a no-op when '
              'nothing created it',
    # AppDelegate, eighteen more; four defects, of which the startupRequest pair was the
    # largest: the weak receiver and an invented handler that is really a block invoke.
    0x4ecfc: 'AppDelegate -getTermURLWithID:: three format slots for three specifiers',
    0x4ee50: 'AppDelegate -needUpdateTerms: NSNumericSearch, ascending tested across '
              'the full register',
    0x4f07c: 'AppDelegate -getExtendNotePIDForOpenStore: four instructions, the ivar direct',
    0x4f08c: 'AppDelegate +getPushNotificationData: exactly one fetch',
    0x4f0fc: 'AppDelegate +popPushNotificationData: four independent re-fetches, and '
              'objectAtIndex: not the subscript form',
    0x4f314: 'AppDelegate +addPushNotificationData:: one fetch, then addObject:',
    0x4f3d4: 'AppDelegate +getOuterURL: fetch and tail autorelease',
    0x4f444: 'AppDelegate +setOuterURL:: fetch then the setter',
    0x4f4d0: 'AppDelegate -isEnableEarlyBonus: three separate list sends, MusicID is '
              'int against one %d',
    0x4f658: 'AppDelegate -isEnableHotBonus: the same shape on the hot list',
    0x4faf4: 'AppDelegate -showTerms: the view controller with a nil delegate',
    0x4fb4c: 'AppDelegate -startupRequest: the weak reference is to +appDelegate, not '
              'self, and the web-info handler is a block invoke rather than a method',
    0x50af0: 'AppDelegate +appDelegate: the application delegate, tail autoreleased',
    0x50c8c: 'AppDelegate +totalScoreLeaderboardCategory: the pad takes '
              'the plain category, not transposed',
    0x517fc: 'AppDelegate +saveDataKey: the passphrase literal',
    0x5307c: 'AppDelegate -applicationWillEnterForeground:: the reload is skipped '
              'while the map is showing',
    0x53350: 'AppDelegate -applicationDidReceiveMemoryWarning:: the binary keeps its '
              'own misspelling',
    0x53628: 'AppDelegate -application:didRegisterUserNotificationSettings:: the '
              'receiver is the application',
    # RBCampaignViewController, first eight. -downloaderFinished: at 0x1fc988 is NOT
    # ticked: its strings and its de-inlining were corrected, its body was not read.
    # RBCampaignViewController, eight more. Three constants had been attributed to engine
    # globals that do not exist: the binary loads them as PC-relative literals out of
    # __text, which is what a source literal compiles to, not an adrp against __const.
    0x1fa700: 'RBCampaignViewController -downloadCampaignList: offset 0, limit 20, '
              'UTF-8, the JSON content type',
    0x1faf90: 'RBCampaignViewController -tableView:willDisplayCell:forRowAtIndexPath:: '
              'the odd-row white is a literal, not a global; both mechanisms appear in '
              'this one function',
    0x1fb118: 'RBCampaignViewController -tableView:didSelectRowAtIndexPath:: both idiom arms',
    0x1fb228: 'RBCampaignViewController -sampleStart: loop true, fade 0.5f, and a '
              'discarded cell fetch',
    0x1fb410: 'RBCampaignViewController -sampleStop: the -1 early return, and the index '
              'reset sits inside the cell branch',
    0x1fb5c0: 'RBCampaignViewController -pushExternalLink:: tbnz #0x1f is a 32-bit sign '
              'test, so the row is an int',
    0x1fb72c: 'RBCampaignViewController -pushCellButton:: the jump table read, not '
              'inferred; b.hi is unsigned and case 1 is the default block',
    0x1fbdac: 'RBCampaignViewController -handleTapCoverView:: the method only; its two '
              'block bodies are not read',
    # RBStorePageViewController. -viewDidLoad at 0x1dd5b0 is NOT ticked: eleven defects were
    # proved and fixed in it, but several blocks are unread and it is recommended for a
    # rewrite from the disassembly rather than further patching.
    0x1dcf88: 'RBStorePageViewController -initWithParent:: the title comes from a '
              'runtime-initialised global, not an empty string; its sole writer '
              'localises "Music Packs"',
    0x1dd25c: 'RBStorePageViewController -loadView: three arms, and the fallback colour '
              'components read exactly',
    0x1e0a90: 'RBStorePageViewController -showError:: two hides and the tagged message label',
    0x1e14fc: 'RBStorePageViewController -pushBarBtnRestore:: the restore alert, tagged 31',
    0x1e2f24: 'RBStorePageViewController -packListDownloadNothing:: the error arm loads '
              'the server-error string, not the push-up-to-show-more one',
    0x1e3018: 'RBStorePageViewController -packViewSelected:: guarded on '
              'allowsSelection, then the pack id',
    0x1e55cc: 'RBStorePageViewController -detailViewClose: pad taps the cover, phone pops',
    0x1e8748: 'RBStorePageViewController -restoreSucceeded: three guarded clears and '
              'the unlock refresh',
    0x1e8c00: 'RBStorePageViewController -restoreNothing: hide the dialog, restart the promotion',
    0x1eec14: 'RBStorePageViewController -stopPromotion: nil-guarded cancel',
    0x1ecb34: 'RBStorePageViewController -stopDownloadArtworks: clear each delegate, '
              'cancel, then remove all',
    # RBCampaignViewController, thirteen more, no defects. The super-call position is not
    # uniform across the four lifecycle methods and each was checked rather than inferred.
    0x1fc758: 'RBCampaignViewController -didPresentAlertView:: the five-send chain to '
              'the presented view',
    0x1fc898: 'RBCampaignViewController -alertViewClose: the index reset sits inside the nil guard',
    0x1fdcb4: 'RBCampaignViewController -showError:: three hides and a text, in order',
    0x1fddf4: 'RBCampaignViewController -storeDialogCancel:: two independent guards, '
              'and the reset is unconditional here',
    0x1fe2bc: 'RBCampaignViewController -downloadManagerFailed:: clear, alert, hide, reset',
    0x1fe368: 'RBCampaignViewController -downloadManagerProceed:: the dialog is fetched '
              'before the type test',
    0x1ff470: 'RBCampaignViewController -refreshUnlockBadge: unsigned loop, nil entries '
              'skipped, counts accumulated',
    0x1ff728: 'RBCampaignViewController -viewWillAppear:: super last',
    0x1ff7bc: 'RBCampaignViewController -viewDidAppear:: super first, then the two-part guard',
    0x1ff91c: 'RBCampaignViewController -viewWillDisappear:: super last, sample stopped on the pad',
    0x1ff9d4: 'RBCampaignViewController -viewDidDisappear:: super last, guarded on the '
              'played index',
    0x1ffc38: 'RBCampaignViewController '
              '-willAnimateRotationToInterfaceOrientation:duration:: super only',
    0x1ffc6c: 'RBCampaignViewController -imageDownloader:didLoad:: a fresh index path, '
              'not the argument reused',
    # RBStorePageViewController, nine more. A class-wide sweep also converted ten IsPad()
    # calls to the ivar the binary reads; five of those methods stay unticked, since an
    # idiom fix proved from the call sites is not a verification of the body.
    0x1e0c40: 'RBStorePageViewController -sendUserAge: four keys, and both blocks read in full',
    0x1e26d0: 'RBStorePageViewController -forceOpenPackDetailView: the idiom is the '
              'ivar, and the pack id comes from the getter, not the same-named property',
    0x1e2a6c: 'RBStorePageViewController -packListDownloadError:errorMessage:: the nil '
              'message substitutes the connect-failed global; centre, size, centre in '
              'that order',
    0x1e3848: 'RBStorePageViewController -openDetailAnimStop:finished:context:: the '
              'context is the fourth argument',
    0x1e3f3c: 'RBStorePageViewController -pushSampleButton:: the two arms were swapped, '
              'so the icon and the action were both the wrong way round',
    0x1e41a8: 'RBStorePageViewController '
              '-openDetailAnimStopFromPromotion:finished:context:: the pack id from the '
              'promotion',
    0x1e5658: 'RBStorePageViewController -storeDialogCancel:: the idiom is the ivar; '
              'both arms verified',
    0x1e66f8: 'RBStorePageViewController -addRestorePackInfo:: add, map to a product '
              'id, then remove if present',
    0x1ef40c: 'RBStorePageViewController -addRestoreExtendNoteInfo:: the same shape on the note id',
    # RBCampaignViewController, five more, no defects. -downloaderError: carries two
    # faithful-but-surprising behaviours that are documented so nobody "fixes" them.
    0x1fda70: 'RBCampaignViewController -downloaderError:: five identity arms; the '
              'music-info arm clears the info downloader, and only three of the five '
              'reach the shared index reset',
    0x1fdfb8: 'RBCampaignViewController -downloadManagerCompleted:: b.lt is signed, '
              'matching the NSInteger count',
    0x1fec34: 'RBCampaignViewController -refreshMusicList: outer bound b.cs unsigned, '
              'inner fast enumeration b.cc, and the break really does leave the inner '
              'loop',
    0x1ffa44: 'RBCampaignViewController -showDetailViewForPhone:: the identifier is '
              'cleared before the search, not after',
    0x1ffe00: 'RBCampaignViewController -itemInfoDownload: UTF-8 body and the JSON content type',
    # RBStorePageViewController, nine more. The IsPad sweep now closes: eight call sites in
    # the binary against eight in the source, one to one, every other idiom test the ivar.
    # -packListDownloadSuccess: had its idiom source corrected but is NOT ticked, its body
    # being unfinished.
    0x1ede24: 'RBStorePageViewController -switchToGenre:: a missing arm — the title '
              'takes an idiom-chosen prefix through a two-argument format — and the '
              'scroll rect keeps the height left in d3',
    0x1ecd54: 'RBStorePageViewController -viewWillAppear:: the row animation is None, '
              'not Middle; all five idiom sites placed',
    0x1e31ac: 'RBStorePageViewController -openPackDetailViewWithPackId:: the curve is '
              'Linear, not EaseInOut',
    0x1e432c: 'RBStorePageViewController -handleTapCoverView:: its duration is a '
              'different pool slot, float-rounded',
    0x1e50ac: 'RBStorePageViewController -checkAttainLimitPurchase:: b.cs is unsigned, '
              'so a negative type cannot index the table; the price is read with '
              'integerValue',
    0x1e5890: 'RBStorePageViewController -updateMusicInfo:Save:: three guards, then the '
              'save flag gates the persist',
    0x1e6058: 'RBStorePageViewController -reDownloadPackMusics:: update then start, nothing else',
    0x1e60c4: 'RBStorePageViewController -purchaseSucceeded:: the identifier mismatch '
              'early-returns; this one really does use intValue, unlike its sibling',
    # RBCampaignViewController, three more.
    0x1ff038: 'RBCampaignViewController -refreshUnlockTable: the badge adds the raw '
              'unlock count, not a normalised BOOL; its sibling -refreshUnlockBadge '
              'already added it raw',
    0x1fb934: 'RBCampaignViewController -showDetailView:: the item is fetched before '
              'the idiom test and discarded on the phone path; the method only, not its '
              'two blocks',
    0x1fc3fc: 'RBCampaignViewController -alertView:clickedButtonAtIndex:: three-way at '
              'both levels, and the index reset is skipped only when the serial code '
              'has length',
    # RBStorePageViewController, eleven more.
    0x1e3a48: 'RBStorePageViewController -storePromotionViewTaped:PackID:: the curve is '
              'Linear through the older API',
    0x1e52f8: 'RBStorePageViewController -detailViewStartPurchase:: both guards fall to '
              'one error arm',
    0x1e5ad8: 'RBStorePageViewController -updatePurchasedTableCell:: pad halves the row '
              'with the signed divide idiom and passes section 0; phone passes the row '
              'and section 2',
    0x1e6564: 'RBStorePageViewController -purchaseFailed:error:: the product identifier '
              'argument is never read',
    0x1e6860: 'RBStorePageViewController -nextRestorePackInfo: a snapshot, then the -1 '
              'route to the extend-note path',
    0x1e8a80: 'RBStorePageViewController -restoreFailed:: the dialog, the message, then '
              'the promotion restarts',
    0x1e8c9c: 'RBStorePageViewController -storePackInfoDownloaderFinished:: guarded '
              'clear, then the next restore',
    0x1e8dbc: 'RBStorePageViewController -storePackInfoDownloaderError:: the guarded '
              'clear is the whole body',
    0x1e925c: 'RBStorePageViewController -downloadManagerFailed:: the retry alert, tagged 33',
    0x1e931c: 'RBStorePageViewController -downloadManagerProceed:: one assignment; the '
              'manager argument is unread',
    0x1e942c: 'RBStorePageViewController -restoreDownloadCancel: both idiom arms',
    # AppDelegate, eight more. Five methods in this class re-send a getter per use where
    # the source cached it; where the source already repeated the read, it matched.
    0x50398: 'AppDelegate -showDownload: the controller is stored before both property writes',
    0x50698: 'AppDelegate +ApplilinkInitialize: the server data is re-sent, not cached',
    0x50920: 'AppDelegate +setRecommendUnreadCount: the same re-fetch',
    0x50b60: 'AppDelegate +setNoBackupAttribute:: NSNumericSearch against 5.0.1, and '
              'the attribute value is one byte',
    0x51828: 'AppDelegate -resetGame: the block loads the weak reference five times, '
              'once per use, so there is no strong local; the loop time is an fmov '
              'immediate, not a pool load',
    0x52f8c: 'AppDelegate -applicationWillResignActive:: the controller is read twice, '
              'as the source has it',
    0x530b4: 'AppDelegate -applicationDidEnterBackground:: the texture release is '
              'skipped while the map shows',
    0x531a4: 'AppDelegate -applicationWillTerminate:: two reads of the download '
              'controller, then the save',
    0x1fe4fc: 'RBCampaignViewController -forceOpenCampaignDetailView: three loops over the same '
              'list with two shapes — the search runs to completion accumulating a flag, the two '
              'idiom loops break on a match — and the idiom test here calls IsPad() directly '
              'where its neighbours read the cached ivar',
    # RBStorePageViewController, nine more from batch five.
    0x1e4858: 'RBStorePageViewController -startDownloadPackMusics:: three-way early '
              'return, and the manager is stored before the dialog work',
    0x1e8110: 'RBStorePageViewController -alertView:clickedButtonAtIndex:: a jump table '
              'over tags 30 to 34; tag 32 compares signed, so index four and above '
              'opens the external page',
    0x1e8608: 'RBStorePageViewController -didPresentAlertView:: one chain to the presented view',
    0x1e9058: 'RBStorePageViewController -downloadManagerCompleted:: both idiom arms, '
              'then hide and restart',
    0x1eb954: 'RBStorePageViewController -tableView:willDisplayCell:forRowAtIndexPath:: '
              'the grey white is the float-rounded value, not a tidy 0.6; the two row '
              'tints were already exact',
    0x1ebc90: 'RBStorePageViewController -tableView:willSelectRowAtIndexPath:: nil only '
              'for the sample-label section',
    0x1ebcfc: 'RBStorePageViewController -tableView:didSelectRowAtIndexPath:: the row '
              'guard is an equality, not a bound',
    0x1ebe6c: 'RBStorePageViewController -showDetailViewForPhone:: the open-store '
              'identifier is cleared before the push',
    0x1ec078: 'RBStorePageViewController -selectShowMore: the loading flag latches, '
              'then centre, size, centre',
    # RBCampaignViewController.
    0x1fa878: 'RBCampaignViewController -tableView:cellForRowAtIndexPath:: the block '
              'tag named the method, not the block; the call takes a completion, and '
              'that completion is empty',
    # AppDelegate. The keychain trio had ten defects between them; every argument list
    # was read from the stack writes rather than counted.
    0x511cc: 'AppDelegate +getServerData: five pairs read from the stack; the '
              'dictionary is the variadic, and the inserts are setObject:forKey:, not '
              'subscripts',
    0x514c8: 'AppDelegate +setServerData:andB:: the version gate is 4.0, not 5.0.1, '
              'and the format embeds the separator so it takes two arguments, not three',
    0x50cb8: 'AppDelegate +musicListKey: both dictionaries variadic, the same 4.0 '
              'gate, and the bundle identifier is fetched twice',
    0x51bc8: 'AppDelegate -application:openURL:sourceApplication:annotation:: the host '
              'is used only for the nil test; the last two arguments are untouched',
    0x54550: 'AppDelegate -audioSessionInterrupted:: the key is a literal, not the '
              'framework symbol, and the value is unboxed once per comparison',
    0x533c8: 'AppDelegate -startRegisterForRemoteNotification: the nil test returns '
              'before count is sent, and the application is fetched inside each arm',
    # RBStorePageViewController, ten more, all clean.
    0x1e6f30: 'RBStorePageViewController -askDownloadAllMusics: five enumerations in '
              'order; b.lt is signed',
    0x1e7788: 'RBStorePageViewController -restoreDownloadAllMusics: tasks built only '
              'for absent files',
    0x1ec2e8: 'RBStorePageViewController -imageDownloader:didLoad:: the pad halves the '
              'row and picks a side by its low bit',
    0x1ed380: 'RBStorePageViewController -viewDidAppear:: super first, then the empty- '
              'and-idle split',
    0x1ed6e4: 'RBStorePageViewController -viewWillDisappear:: super first, then four '
              'guarded blocks',
    0x1ed9f8: 'RBStorePageViewController '
              '-willAnimateRotationToInterfaceOrientation:duration:: the width feeds '
              'the rotate',
    0x1edae8: 'RBStorePageViewController -didReceiveMemoryWarning: the downloaders are '
              'cleared before super',
    0x1edb6c: 'RBStorePageViewController -dealloc: two guarded blocks; the super call '
              'is correctly absent under ARC',
    0x1ee3ac: 'RBStorePageViewController -presentGenreSelect:: a real IsPad() call, '
              'then the popover visibility test',
    0x1ee610: 'RBStorePageViewController -hideGenreSelect:: the three re-enables run '
              'unconditionally',
    # RBStorePageViewController, eight more. -tableView:cellForRowAtIndexPath: at 0x1e96b4
    # had its unsigned bound corrected but is NOT ticked: 1735 instructions, partially read.
    0x1ee7a4: 'RBStorePageViewController -showLoadingView: the scroll rect keeps the '
              'height left in d3 by a second frame send, the third tag lookup is on the '
              'table view, not self',
    0x1eeb58: 'RBStorePageViewController -setPlaySampleName:: nil gives the empty '
              'string; the branch sense is inverted from the source but identical',
    0x1eeca8: 'RBStorePageViewController -popoverControllerDidDismissPopover:: three '
              're-enables and nothing else',
    0x1eedb0: 'RBStorePageViewController -storeDetailViewOpenItunesWithURL:: forwards '
              'to the application view controller',
    0x1ef1ec: 'RBStorePageViewController -closeItunesWithURL: one send to its own finish handler',
    0x1ef24c: 'RBStorePageViewController -productViewControllerDidFinish:: guarded '
              'dismiss, the block clears the ivar',
    0x1ef324: 'RBStorePageViewController -goToTop:: scroll position 1 is Top',
    0x1ef76c: 'RBStorePageViewController -switchToSpecialStore: one send to the parent',
    # AppDelegate, two more. -launchAppStore is declared as an instance method in the
    # source and the metadata has it as a class method at 0x53268; reported, not fixed,
    # since correcting it also touches a caller outside this class.
    0x4d77c: 'AppDelegate -startApplication: the two version strings are not transposed, the '
             'three tier values are immediates matching the enumeration, the delay constant is '
             'read at four bytes with 0.9f as its neighbour, and scvtf is signed; the two '
             'identical alert arms are separate in the binary as in the source',
    0x52cbc: 'AppDelegate -applicationDidBecomeActive:: the scene register survives the storage '
             'block, so the deep-link guard really is on the scene, and the alert takes self '
             'rather than a weak reference, none being created here',
    0x504dc: 'AppDelegate -alertView:clickedButtonAtIndex:: the tag is read three '
              'times, and 10 is the network-error tag against 3 for the new version, '
              'not transposed',
    0x4f7e0: 'AppDelegate -showTitle: the explosion size is a pool load of 0.9f taken '
              'at single width, its neighbour being 96.0f; the other two effect sizes '
              'are fmov immediates',
    # RBStoreDetailViewController opens with two clean screens: the class has no class
    # methods at all, so no kind disagreement, and all 43 selectors it defines are in the
    # metadata, so no invented ones. Both recorded as negatives before any body was read.
    0x1e96b4: 'RBStorePageViewController -tableView:cellForRowAtIndexPath:: fully read '
              'across two passes, nine defects; the sample-label width comes from the '
              'category getter, not from frame.size.width',
    0x1d9028: 'RBStoreDetailViewController -setPurchaseState:: guarded on the header '
              'view, and the argument is inverted before setEnabled:',
    0x1d9408: 'RBStoreDetailViewController -setButtonTextBuy: one argument slot for one specifier',
    0x1d95d8: 'RBStoreDetailViewController -setButtonTextInstall: normal state and '
              'enabled, unlike the installing and installed pair which use the disabled '
              'state',
    0x1d9f58: 'RBStoreDetailViewController -tableView:numberOfRowsInSection:: count plus two',
    0x1dc3fc: 'RBStoreDetailViewController -didReceiveMemoryWarning: the super call only',
    0x1dc430: 'RBStoreDetailViewController -viewDidUnload: super first, then the artwork stop',
    0x1f9220: 'RBCampaignViewController -loadView: three of seven autoresizing masks, every '
              'centre truncating through the signed fcvtzs pair, a transposed -44.0 that belongs '
              'to the pad detail view, and a fixed 40 by 40 indicator host',
    0x1f8e2c: 'RBCampaignViewController -initWithParent:: the three asset names are '
              'paths with slashes',
    0x1fc128: 'RBCampaignViewController -updateExperienceData: the unlock keys are Type '
              'and ID, capitalised',
    0x1faf5c: 'RBCampaignViewController -tableView:numberOfRowsInSection:: the list '
              'ivar read directly',
    0x1fb0e4: 'RBCampaignViewController -tableView:heightForRowAtIndexPath:: the idiom '
              'flag passed straight through',
    0x1fec00: 'RBCampaignViewController -reloadUnlockList: refresh then a tail call',
    0x1ff5cc: 'RBCampaignViewController -setBadgeCnt:: b.lt is signed, one slot for one specifier',
    0x1ff6a0: 'RBCampaignViewController -didReceiveMemoryWarning: nothing but the super call',
    0x1ff6d4: 'RBCampaignViewController -viewDidUnload: super, then the table view cleared',
    0x2202ec: 'ApplilinkStore -init: the queue is the private serial one from +allocWithZone:',
    0x2204c0: 'ApplilinkStore +allocWithZone:: creates the queue, then re-tests the singleton',
    0xa9108: 'RBMenuView -createMusicList: the csel at 0xa939c picks the artist comparator on 1',
    0x1a1b08: 'UIImage +imageNamedWithoutCache:: the two passes use mirrored iPad tags',
    0x1a2fa4: 'UIImage -clipImageWithRect:: all twelve items, including the d0-d3 mapping',
    0x1ea20: 'RBResourceDownloadViewController -updateLayout: three arms, aligned not centred',
    0x16d5c0: 'RBMusicGridLayout -init: both idiom arms, every constant decoded from the pool',
    0x16d7d8: 'RBMusicGridLayout -prepareLayout: ceiling division, slack, item frames',
    0x16de78: 'RBMusicGridLayout -collectionViewContentSize: tail-call to the ivar',
    0x16de84: 'RBMusicGridLayout per-item attributes: frameless, index passed through',
    0x16deb0: 'RBMusicGridLayout supplementary attributes: the same frameless shape',
    0x16df1c: 'RBMusicGridLayout -layoutAttributesForElementsInRect:: intersection order',
    0x16e0a0: 'RBMusicGridLayout -shouldInvalidateLayoutForBoundsChange:: returns 1',
    # RBMenuTutorialView, all fourteen read against the disassembly. Thirteen defects were fixed
    # in the process; the touch path was found clean, which is what ruled the tutorial out as the
    # cause of the stuck overlay on the device.
    0x137b0c: 'RBMenuTutorialView -initWithFrame:: ldr s0, so the content dimensions are single '
              'precision; cbz at 0x137b6c sends the phone to 300x100',
    0x137bfc: 'RBMenuTutorialView -setupView: the -0.85 window offset at 0x308cb8, the pastel drop '
              'scales 1.5 and 0.8, and the message size taken from clip table entries 9 and 10',
    0x139af8: 'RBMenuTutorialView -showAnimationWithTutorialType:withRootView:: the animating '
              'early-out and both weak-captured blocks',
    0x139e04: 'RBMenuTutorialView -hideAnimation: the same shape, 0.25 duration',
    0x13aac4: 'RBMenuTutorialView -tap:: b.cc at 0x13ab14 is unsigned lower',
    0x13ab34: 'RBMenuTutorialView -startTutorialWithType:withAnimation:: every arm of the '
              'thirty-five entry jump table at 0x13b870 walked, and the 1000.0 reward at 0x2f8540',
    0x13b8fc: 'RBMenuTutorialView -startTutorialWithType:withRootView:: sets the root then '
              'forwards with animation true',
    0x13b974: 'RBMenuTutorialView -setClipRect: receivers traced by register, so the rect really '
              "is the target's frame converted from its superview to self",
    0x13ba8c: 'RBMenuTutorialView -layoutBackground:withAnimation:: the animation flag is never '
              "read, and the grey control's width comes from its own frame",
    0x13c8a0: 'RBMenuTutorialView -hitTest:withEvent:: nil only when the touch target is set and '
              'all four containment guards fall through; read independently and agreed',
    0x13cb4c: 'RBMenuTutorialView -willRotate: the sublayer opacity sweep and both stops',
    0x13cdd4: 'RBMenuTutorialView -didRotate: the content alpha is zero, not the dim value',
    0x13cfe8: 'RBMenuTutorialView -contentViewSettingWithTouchAnim:cursorAnim:stay:useAnimation:: '
              'the default rect is the zero constant, and the side test is against self.height',
    0x13d510: 'RBMenuTutorialView -startCursorAnimation:: the frame terms and the 0.5 bob; the '
              'repeat count at 0x13d740 is NOT proven, the caller setting no argument register',
    # RBMenuNewsTickerView, all nine read. Eleven defects fixed, and between them they account for
    # the blank ticker on the device: the layer anchor, the parked y keyframes, the label frame,
    # and an empty format string that dropped the NEWS prefix.
    0x9e670: 'RBMenuNewsTickerView -initWithFrame:: the rect is forwarded to super untouched',
    0x9e6f0: 'RBMenuNewsTickerView -SetUpView: both fcsel pairs take the pad value first, the '
             'anchor is parked at the origin, and the format string carries NEWS',
    0x9f150: 'RBMenuNewsTickerView -setDuration:: a direct ivar store, no accessor send',
    0xa0730: 'RBMenuNewsTickerView -animationDidStop:finished:: the point is captured before the '
             'replacement animation is built',
    0xa0a3c: 'RBMenuNewsTickerView -stopNews: guarded on animationKeys and its count',
    0xa0b7c: 'RBMenuNewsTickerView -isLinkToStore: three instructions, a byte load',
    0xa0b8c: 'RBMenuNewsTickerView -toLink: nil test, canOpenURL: guard, then openURL:',
    0xa0cf4: 'RBMenuNewsTickerView -parseQuery:: the binary tests host, not scheme, and discards '
             'the pathComponents result',
    # RBExperienceData, five read and all already correct.
    0x1b8910: 'RBExperienceData -init: seven sets in the source order, dictionary capacity 20',
    0x1b9cfc: 'RBExperienceData +sharedInstance: a plain nil test, not @synchronized or once',
    0x1b9e50: 'RBExperienceData -save: archived under NSStringFromClass, then synchronize',
    0x1b9f74: 'RBExperienceData -unlockWithBGMtype:: bgmItems, the standard enumeration',
    0x1ba0c8: 'RBExperienceData -unlockWithShotType:: shotItems, byte-identical shape',
    0x9f190: 'RBMenuNewsTickerView -setText:LINK:: the label frame is (0, 0, measured text '
             'width, base view height); sizeWithFont: supplies d2 and the textBaseView frame send '
             'leaves the height in d3, which is why copying the base frame wholesale left the '
             'marquee nothing to scroll',
    0x9dab4: 'RBMenuButton -setupView:: the bounds fcsel and both cap-inset calls',
    0x9d9fc: 'RBMenuButton -initWithType:: super init then setupView:',
    0x5df3c: 'ScoreData -getFrameBonusType: the three-way csel and the 2-collapses-to-1 return',
    0x5d3bc: 'ScoreData +hashScore:: send order, the 1000.0 scale at 0x2f8540, the 16-byte digest',
    # The seven -shouldAutorotateToInterfaceOrientation: bodies that are one unsigned range test,
    # `sub x8,x2,#1; cmp x8,#2; cset w0,cc`, accepting only the two portrait orientations.
    0x7df4: 'RBCampaignDetailViewController -shouldAutorotateToInterfaceOrientation:',
    0x19e00: 'RBResourceDownloadViewController -shouldAutorotateToInterfaceOrientation:',
    0x114854: 'RBTermView -shouldAutorotateToInterfaceOrientation:',
    0x194138: 'RBNotificationPageView -shouldAutorotateToInterfaceOrientation:',
    0x1a9300: 'RBStoreExtendNoteDetailViewController -shouldAutorotateToInterfaceOrientation:',
    0x1c9478: 'RBTermAgreeView -shouldAutorotateToInterfaceOrientation:',
    0x1dc3ec: 'RBStoreDetailViewController -shouldAutorotateToInterfaceOrientation:',
    # MusicDataFromDoc's eight sheet accessors are each `adrp/ldr loadSheet; b _objc_msgSend`,
    # forwarding to the same selector with no argument, which is what this file does.
    0x676a4: 'MusicDataFromDoc -sheetBasic: tail-calls loadSheet',
    0x676b0: 'MusicDataFromDoc -sheetBasicLight: tail-calls loadSheet',
    0x676bc: 'MusicDataFromDoc -sheetMedium: tail-calls loadSheet',
    0x676c8: 'MusicDataFromDoc -sheetMediumLight: tail-calls loadSheet',
    0x676d4: 'MusicDataFromDoc -sheetHard: tail-calls loadSheet',
    0x676e0: 'MusicDataFromDoc -sheetHardLight: tail-calls loadSheet',
    0x676ec: 'MusicDataFromDoc -sheetSpecial: tail-calls loadSheet',
    0x676f8: 'MusicDataFromDoc -sheetSpecialLight: tail-calls loadSheet',
    # The artwork pair passes its scale and luminance as fmov immediates, 2.0/1.0 and 1.0/1.0.
    0x67704: 'MusicDataFromDoc -artwork2xData: artworkDataWithScale:2.0 Luminance:1.0',
    0x67718: 'MusicDataFromDoc -artworkData: artworkDataWithScale:1.0 Luminance:1.0',
    # AudioManager, read end to end against the disassembly. +sharedManager guards with
    # @synchronized on the class, not dispatch_once, and -init's field writes were checked against
    # the ivar list, which is what exposed the layout defect fixed alongside this.
    0x3d0c4: 'AudioManager +sharedManager', 0x3d154: 'AudioManager -init',
    0x3d3ec: 'AudioManager -systemStart', 0x3d4b4: 'AudioManager -systemStartBlock',
    0x3d4c4: 'AudioManager -systemTerminate', 0x3d50c: 'AudioManager -onStartPlayer:',
    0x3d560: 'AudioManager -initBgm:', 0x3d638: 'AudioManager -loadBgmData:isLoop:',
    0x3d764: 'AudioManager -loadBgmDataWithBytes:length:isLoop:',
    0x3d7ec: 'AudioManager -loadBgmDataWithBytesNoCopy:length:isLoop:',
    0x3d874: 'AudioManager -loadBgmDataWithBytesNoCopy:length:freeWhenDone:isLoop:',
    0x3d8fc: 'AudioManager -loadVoiceData:isLoop:',
    # RBMusicView's selection handlers. Every selector was resolved from the name bytes and every
    # implementation confirmed to exist, so none of these registers a dead action.
    0xd2ddc: 'RBMusicView -SetRankView:', 0xd37a8: 'RBMusicView -SetSettingButtonSelected:',
    0xd397c: 'RBMusicView -SetGhostView:', 0xd3b50: 'RBMusicView -updateDecideButton',
    0xd3fac: 'RBMusicView -SelectDoublePlayButton', 0xd4028: 'RBMusicView -SelectDecideButton',
    0xd44d0: 'RBMusicView -SelectHistory', 0xd4620: 'RBMusicView -SelectWhitePastelButton',
    0xd4694: 'RBMusicView -SelectBlackPastelButton', 0xd4f54: 'RBMusicView -SelectItunes',
    # RBViewController's run loop, lifecycle and projection, verified independently by two agents.
    0x8af3c: 'RBViewController -Task', 0x8af88: 'RBViewController -Draw',
    0x8b074: 'RBViewController -mainLoop', 0x8b0a8: 'RBViewController -StartLoop',
    0x8b0c4: 'RBViewController -StopLoop', 0x8b0dc: 'RBViewController -ResumeLoop',
    0x8b0f8: 'RBViewController -RestartLoop',
    0x8b110: 'RBViewController -CreateDisplayLinkTimer',
    0x8a800: 'RBViewController -UpdateProjection', 0x8a7e4: 'RBViewController -LayoutedGLView:',
    0x8af30: 'RBViewController -openGLView', 0x88fc0: 'RBViewController -init',
    0x893c4: 'RBViewController -showPresentViewController',
    0x89c24: 'RBViewController -removeView',
    0x8a3e8: 'RBViewController -didSelectMenuSortViewController:',
    0x8a530: 'RBViewController -willRotateToInterfaceOrientation:duration:',
    0x8a584: 'RBViewController -didRotateFromInterfaceOrientation:',
    # AppDelegate's URL accessors. The four-instruction getters have no msgSend at all, which is
    # what proved they read the ivar rather than the copy property.
    0x4eb78: 'AppDelegate -getBaseWebInfoURL', 0x4eb88: 'AppDelegate -setWebInfoURL:',
    0x4ec18: 'AppDelegate -getWebInfoURL', 0x4ec28: 'AppDelegate -setPreWebInfoURL:',
    0x4eca4: 'AppDelegate -getPreWebInfoURL', 0x4ecb4: 'AppDelegate -setBaseTermURL:',
    0x4ecec: 'AppDelegate -getBaseTermURL',
    0x4ee40: 'AppDelegate -getTermLastUpdateTimeString',
    0x4ef50: 'AppDelegate -setLatestTermsVersion:',
    0x4efa4: 'AppDelegate -getInfoLastUpdateTimeString',
    0x4efec: 'AppDelegate -getPackIDForOpenStore',
    0x4f034: 'AppDelegate -getCampaignIDForOpenStore',
    # RBMenuView's collection and scroll-view delegates, on the song-selection screen.
    0xb35fc: 'RBMenuView -collectionView:numberOfItemsInSection:: musicList then count',
    0xb42e8: 'RBMenuView -scrollViewWillBeginDragging:: sends setSearchBarNonActive',
    0xb4304: 'RBMenuView -scrollViewDidEndDecelerating:: forwards to scrollViewDidEndScroll:',
    0xb4384: 'RBMenuView -scrollViewDidEndScrollingAnimation:: forwards the same way',
}


class Section(NamedTuple):
    """One Mach-O section."""

    name: str
    address: int
    size: int
    offset: int


class Method(NamedTuple):
    """One Objective-C method from the runtime metadata."""

    class_name: str
    kind: str
    selector: str
    address: int
    accessor: bool


class Metadata:
    """The shipped Mach-O's Objective-C metadata."""

    def __init__(self, path: Path) -> None:
        self._data = path.read_bytes()
        self._sections = list(self._read_sections())

    def _read_sections(self):
        n_commands, = struct.unpack_from('<I', self._data, 16)
        offset = 32
        for _ in range(n_commands):
            command, size = struct.unpack_from('<II', self._data, offset)
            if command == _LC_SEGMENT_64:
                n_sections, = struct.unpack_from('<I', self._data, offset + 64)
                cursor = offset + 72
                for _ in range(n_sections):
                    name = self._data[cursor:cursor + 16].rstrip(b'\0').decode()
                    address, section_size = struct.unpack_from('<QQ', self._data, cursor + 32)
                    file_offset, = struct.unpack_from('<I', self._data, cursor + 48)
                    yield Section(name, address, section_size, file_offset)
                    cursor += 80
            offset += size

    def offset_of(self, address: int) -> int | None:
        """Map a virtual address to a file offset, or ``None`` when unmapped."""
        for section in self._sections:
            if section.address <= address < section.address + section.size:
                if section.name in _ZERO_FILL:
                    return None
                return section.offset + (address - section.address)
        return None

    def section(self, name: str) -> Section | None:
        """Find a section by name."""
        return next((s for s in self._sections if s.name == name), None)

    def string_at(self, address: int) -> str:
        """Read a NUL-terminated string, or ``'?'`` when unreadable."""
        offset = self.offset_of(address)
        if offset is None:
            return '?'
        return self._data[offset:self._data.index(b'\0', offset)].decode('utf-8', 'replace')

    def _word(self, address: int) -> int:
        offset = self.offset_of(address)
        return 0 if offset is None else struct.unpack_from('<Q', self._data, offset)[0]

    def _accessors(self, properties: int) -> set[str]:
        """Derive the selectors a class's property list synthesises."""
        offset = self.offset_of(properties) if properties else None
        if offset is None:
            return set()
        entry_size, count = struct.unpack_from('<II', self._data, offset)
        out: set[str] = set()
        for index in range(count):
            entry = offset + 8 + index * entry_size
            name = self.string_at(struct.unpack_from('<Q', self._data, entry)[0])
            attributes = self.string_at(struct.unpack_from('<Q', self._data, entry + 8)[0])
            getter = re.search(r'(?:^|,)G([^,]+)', attributes)
            setter = re.search(r'(?:^|,)S([^,]+)', attributes)
            out.add(getter.group(1) if getter else name)
            if 'R' not in attributes.split(','):
                out.add(setter.group(1) if setter else f'set{name[:1].upper()}{name[1:]}:')
        return out

    def _method_list(self, method_list: int) -> list[tuple[str, int]]:
        """Walk a method list, returning each selector and implementation address."""
        offset = self.offset_of(method_list) if method_list else None
        if offset is None:
            return []
        entry_size, count = struct.unpack_from('<II', self._data, offset)
        out: list[tuple[str, int]] = []
        for index in range(count):
            entry = offset + 8 + index * entry_size
            # A 12-byte entry is a relative method list: each field is a signed offset from itself.
            if entry_size == 12:
                name_offset, _, imp_offset = struct.unpack_from('<iii', self._data, entry)
                entry_address = method_list + 8 + index * entry_size
                out.append((self.string_at(self._word(entry_address + name_offset)),
                            entry_address + 8 + imp_offset))
            else:
                name, _, implementation = struct.unpack_from('<QQQ', self._data, entry)
                out.append((self.string_at(name), implementation))
        return out

    def methods(self) -> list[Method]:
        """Enumerate every method the binary defines, from the class list and the category list."""
        out: list[Method] = []
        classlist = self.section('__objc_classlist')
        if classlist is not None:
            for index in range(classlist.size // 8):
                address, = struct.unpack_from('<Q', self._data, classlist.offset + index * 8)
                out.extend(self._class_methods(address))
        catlist = self.section('__objc_catlist')
        if catlist is not None:
            for index in range(catlist.size // 8):
                address, = struct.unpack_from('<Q', self._data, catlist.offset + index * 8)
                out.extend(self._category_methods(address))
        return out

    def _class_methods(self, class_address: int) -> list[Method]:
        offset = self.offset_of(class_address)
        if offset is None:
            return []
        isa, _, _, _, data = struct.unpack_from('<QQQQQ', self._data, offset)
        out: list[Method] = []
        for ro, kind in ((data, '-'), (self._metaclass_ro(isa), '+')):
            ro_offset = self.offset_of(ro) if ro else None
            if ro_offset is None:
                continue
            name = self.string_at(struct.unpack_from('<Q', self._data, ro_offset + 24)[0])
            method_list, = struct.unpack_from('<Q', self._data, ro_offset + 32)
            properties, = struct.unpack_from('<Q', self._data, ro_offset + 64)
            accessors = self._accessors(properties)
            for selector, implementation in self._method_list(method_list):
                out.append(Method(name, kind, selector, implementation, selector in accessors))
        return out

    def _metaclass_ro(self, isa: int) -> int:
        offset = self.offset_of(isa)
        if offset is None:
            return 0
        *_, data = struct.unpack_from('<QQQQQ', self._data, offset)
        return data

    def _category_methods(self, category_address: int) -> list[Method]:
        offset = self.offset_of(category_address)
        if offset is None:
            return []
        name, _, instance_methods, class_methods = struct.unpack_from('<QQQQ', self._data, offset)
        # The class a category extends is reached through a reference the linker binds at load time,
        # so it cannot be named from the file. The category's own name is recorded instead.
        label = f'({self.string_at(name)})'
        out: list[Method] = []
        for method_list, kind in ((instance_methods, '-'), (class_methods, '+')):
            for selector, implementation in self._method_list(method_list):
                out.append(Method(label, kind, selector, implementation, False))
        return out


def reconstructed(root: Path) -> tuple[set[tuple[str, str, str]], set[tuple[str, str]]]:
    """
    Collect what the source tree reconstructs.

    Returns
    -------
    tuple[set, set]
        Keyed definitions of ``(class, kind, selector)``, and ``(kind, selector)`` pairs for
        anything defined in a category, whose class cannot be matched by name.
    """
    keyed: set[tuple[str, str, str]] = set()
    loose: set[tuple[str, str]] = set()
    implementation = re.compile(r'^@implementation\s+(\w+)(?:\s*\(\s*(\w+)\s*\))?')
    interface = re.compile(r'^@interface\s+(\w+)(?:\s*\(\s*\w*\s*\))?')
    end = re.compile(r'^@end')
    method = re.compile(r'^\s*([-+])\s*\([^)]*\)\s*(.+)$')
    prop = re.compile(r'^\s*@property\s*(?:\(([^)]*)\))?\s*.*?([A-Za-z_]\w*)\s*;')
    files = []
    for pattern in ('Project/**/*.m', 'Project/**/*.mm', 'Project/**/*.h'):
        files += glob.glob(pattern, recursive=True)
    for name in sorted(set(files)):
        lines = Path(name).read_text(errors='replace').splitlines()
        current: str | None = None
        is_category = False
        for index, line in enumerate(lines):
            opened = implementation.match(line) or interface.match(line)
            if opened:
                current = opened.group(1)
                is_category = '(' in line.split(current, 1)[1][:3]
                continue
            if end.match(line):
                current = None
                continue
            if current is None:
                continue
            found = method.match(line)
            if found:
                chunk = found.group(2)
                cursor = index
                while '{' not in chunk and ';' not in chunk and cursor - index < 8:
                    cursor += 1
                    if cursor >= len(lines):
                        break
                    chunk += ' ' + lines[cursor]
                selector = _selector_of(chunk)
                if selector:
                    keyed.add((current, found.group(1), selector))
                    if is_category:
                        loose.add((found.group(1), selector))
                continue
            declared = prop.match(line)
            if declared:
                attributes = declared.group(1) or ''
                name_ = declared.group(2)
                getter = re.search(r'getter\s*=\s*(\w+)', attributes)
                keyed.add((current, '-', getter.group(1) if getter else name_))
                if 'readonly' not in attributes:
                    setter = re.search(r'setter\s*=\s*(\w+:?)', attributes)
                    if setter:
                        selector = setter.group(1)
                        keyed.add((current, '-', selector if selector.endswith(':') else
                                   f'{selector}:'))
                    else:
                        keyed.add((current, '-', f'set{name_[:1].upper()}{name_[1:]}:'))
    return keyed, loose


def _selector_of(signature: str) -> str:
    """Build a selector from a method signature's text after the return type."""
    text = signature.split('{')[0].split(';')[0].strip()
    if ':' not in text:
        return re.split(r'[\s(]', text)[0]
    return ''.join(f'{part}:' for part in re.findall(r'(\w+)\s*:', text))


def mechanically_verified() -> dict[int, str]:
    """
    Read the addresses the mechanical passes proved against the instructions.

    Returns
    -------
    dict[int, str]
        Each verified address and what it was shown to do.
    """
    out: dict[int, str] = {}
    for name in ('tools/objc_verified.txt', 'tools/objc_verified_trivial.txt',
                 'tools/objc_verified_float_constants.txt'):
        path = Path(name)
        if not path.is_file():
            continue
        for line in path.read_text().splitlines():
            if line.startswith('#') or not line.strip():
                continue
            address, _, why = line.partition(' ')
            out[int(address, 16)] = why
    return out


def render(methods: list[Method], keyed, loose) -> str:
    """Build the checklist document."""
    listed = [m for m in methods if m.selector not in _COMPILER_GENERATED]
    skipped = len(methods) - len(listed)
    mechanical = mechanically_verified()
    rows = []
    done = verified = 0
    for m in sorted(listed, key=lambda m: m.address):
        is_reconstructed = ((m.class_name, m.kind, m.selector) in keyed
                    or (m.kind, m.selector) in loose)
        relative = m.address - IMAGE_BASE
        is_verified = relative in VERIFIED or relative in mechanical
        done += is_reconstructed
        verified += is_verified
        rows.append(f'| `{m.class_name}` | `{m.kind}` | `{m.selector}` | '
                    f'{"prop" if m.accessor else ""} | {DONE if is_reconstructed else NOT} | '
                    f'{DONE if is_verified else NOT} | `{m.address - IMAGE_BASE:#x}` |')
    accessors = sum(1 for m in listed if m.accessor)
    mechanical_count = sum(1 for m in listed
                           if m.accessor and (m.address - IMAGE_BASE) in mechanical)
    header = f'''# Objective-C methods to verify

Every Objective-C method the binary defines, from its own runtime metadata. Nothing Apple ships
appears here: a framework's classes live in the framework, so the only Apple-derived rows are the
categories this application adds to Apple classes, which are its own code. The
{skipped} `.cxx_construct`/`.cxx_destruct` methods the compiler emits for ARC-managed and C++-typed
ivars are counted and excluded, since they have no reconstruction and never will.

`Reconstructed` is whether a reconstruction exists in the source tree, either an explicit
definition in the class's `@implementation` or a `@property` that synthesises it. `Verified` is
whether that reconstruction has been read against the disassembly, per the five-step process in
[.claude/rules/reconstruction.md](.claude/rules/reconstruction.md). **The two are independent, and
the gap between them is the point of this file.** `prop` marks a method a property list synthesises.

A category cannot be attributed to the class it extends: that class is reached through a reference
the linker binds at load time, so the file never names it, and a category's own name is the
category's. Those rows carry the category name in parentheses and are matched on the selector alone.

Total: {len(listed)} — {done} reconstructed, {verified} verified
({100.0 * verified / len(listed):.1f}%).
{accessors} are property accessors. Two mechanical passes account for most of the verified
count and record their evidence per address: `tools/objc_verify_accessors.py` shows an accessor
moves exactly the ivar its property declares, and `tools/objc_verify_trivial.py` shows an empty or
constant-returning body agrees with its reconstruction. Everything else was read by hand.

Regenerate with `tools/objc_update.py <binary>`, where the binary is the one **inside the .ipa**;
the unpacked copy under `rb458orig` is a different build and matches nothing.

| Class | Kind | Selector | Prop | Reconstructed | Verified | Address |
| ----- | :--: | -------- | :--: | :-----------: | :------: | ------- |
'''
    return header + '\n'.join(rows) + '\n'


def main(argv=None) -> int:
    """Regenerate the checklist."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the shipped Mach-O from inside the .ipa')
    parser.add_argument('root', type=Path, nargs='?', default=Path('Project'),
                        help='the reconstructed source root (default: Project)')
    args = parser.parse_args(argv)
    if not args.binary.is_file():
        print(f'error: no such binary: {args.binary}', file=sys.stderr)
        return 1
    metadata = Metadata(args.binary)
    methods = metadata.methods()
    if not methods:
        print('error: no Objective-C metadata found; is this the right binary?', file=sys.stderr)
        return 1
    keyed, loose = reconstructed(args.root)
    Path(PATH).write_text(render(methods, keyed, loose))
    print(f'wrote {PATH}: {len(methods)} method(s) from the metadata')
    # A VERIFIED entry naming an address the metadata does not define is a claim about a routine
    # that does not exist, which is worse than no claim, so say so rather than silently dropping it.
    defined = {m.address - IMAGE_BASE for m in methods}
    stale = sorted(set(VERIFIED) - defined)
    for address in stale:
        print(f'error: VERIFIED names {address:#x}, which the metadata does not define: '
              f'{VERIFIED[address]}', file=sys.stderr)
    return 1 if stale else 0


if __name__ == '__main__':
    raise SystemExit(main())
