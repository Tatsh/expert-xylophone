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
    # UIImage(RB)'s themed lookup. The fallback-language arm looked like a reconstruction bug and
    # is not: 0x1a1898 re-reads the count after the insert and 0x1a189c subtracts one, so the
    # binary itself replaces the file name rather than the language component, and that last
    # lookup can never resolve. The count < 2 guard is the b.cc at 0x1a187c.
    0x1A1644: 'UIImage(RB) +imageWithName:imageDirectory:themaDirectory:retina: '
              'faithful, including the fallback arm that replaces the wrong component',
    # The retina arm is entered only when the flag is set (cbz w0 at 0x1a1a5c skips it) and falls
    # through to the non-retina call when it returns nil (cbnz x24 at 0x1a1a88 returns early).
    0x1A1A0C: 'UIImage(RB) +imageWithName:imageDirectory:themaDirectory: two-arm retina fallback, '
              'w5 carries the retina flag as 1 then 0',
    # Reads g_pThemedImageCache straight from 0x3df3d8 and tail-calls removeAllObjects at 0x1a1640.
    # There is no bl to the lazy accessor, so this arm does not create the cache to empty it.
    0x1A1630: 'UIImage(RB) +clearImageCache: bare global load, no lazy init',
    # w3 = 1 at 0x1a2840 is useCache:YES, then a tail call.
    0x1A2830: 'UIImage(RB) +imageWithName: forwards with useCache:YES',
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
    # RBStoreExtendNoteDetailViewController, read against the disassembly one routine at a time.
    0x1a76bc: 'RBStoreExtendNoteDetailViewController -initWithExtendNoteInfo:: the title is set '
              'twice when the note has a name',
    0x1a78c0: 'RBStoreExtendNoteDetailViewController -loadView: bare super call',
    0x1a78f4: 'RBStoreExtendNoteDetailViewController -setExtendNoteInfo:: the nil arm blanks the '
              'three labels and drops the placeholder jacket in',
    0x1a7db4: 'RBStoreExtendNoteDetailViewController -setPurchaseState:: the argument is unused; '
              'the colour and title come from the info',
    0x1a7f2c: 'RBStoreExtendNoteDetailViewController -hasItem:itemID:: a non-zero hasItem short-'
              'circuits to NO at 0x1a7f40',
    0x1a8040: 'RBStoreExtendNoteDetailViewController -showItemInfo: the artwork download only '
              'starts when nothing is loaded',
    0x1a8224: 'RBStoreExtendNoteDetailViewController -loadInfo: nil-guarded tail call',
    0x1a8278: 'RBStoreExtendNoteDetailViewController -sampleStart: PlayMusic takes the float 0.5 '
              'at 0x1a834c',
    0x1a83d4: 'RBStoreExtendNoteDetailViewController -sampleStop: g_flFlashMinOpacity from '
              '0x2ec6b4, index reset through the setter',
    0x1a8508: 'RBStoreExtendNoteDetailViewController -selectButton: the played index is read '
              'through its accessor, then selectButton: is performed on the delegate',
    0x1a8628: 'RBStoreExtendNoteDetailViewController -sampleViewStop: alpha 0, status 0',
    0x1a8700: 'RBStoreExtendNoteDetailViewController -sampleViewDownloading: alpha 1, status 1',
    0x1a87e4: 'RBStoreExtendNoteDetailViewController -sampleViewPlaying: alpha 1, status 2',
    0x1a88c0: 'RBStoreExtendNoteDetailViewController -handleTapArtworkView: the playing and '
              'downloading arms really are identical (0x1a8a48 joins them)',
    0x1a8b38: 'RBStoreExtendNoteDetailViewController -finishBgm:: tail call to sampleStop',
    0x1a8b54: 'RBStoreExtendNoteDetailViewController -downloaderFinished:: identity check on the '
              'downloader, PlayMusic 0.0, index 1',
    0x1a8d08: 'RBStoreExtendNoteDetailViewController -downloaderError:: stop, drop, network alert',
    0x1a8dcc: 'RBStoreExtendNoteDetailViewController -alertView:didDismissWithButtonIndex:: acts '
              'only while the closing flag is clear (cbnz at 0x1a8df0)',
    0x1a8ec0: 'RBStoreExtendNoteDetailViewController -alertViewCancel:: the mirrored polarity, '
              'acting only while the flag is set',
    0x1a8fb8: 'RBStoreExtendNoteDetailViewController -didPresentAlertView:: the presented root view',
    0x1a90f8: 'RBStoreExtendNoteDetailViewController -stopDownloadArtworks: cancel then detach, '
              'in that order',
    0x1a9310: 'RBStoreExtendNoteDetailViewController -didReceiveMemoryWarning: bare super call',
    0x1a9344: 'RBStoreExtendNoteDetailViewController -viewDidUnload: super, then the artwork '
              'downloads stop',
    0x1a9394: 'RBStoreExtendNoteDetailViewController -dealloc: sample cancelled, artworks stopped',
    # Eleven defects fixed. The item view and detail card flex in width only (masks 0x2 at
    # 0x1a9834 and 0x1aad74) and the button in its left margin (0x1aa4d4); the music label is 50
    # tall (0x2ec6e0) and the artist and level rows 20, at y = 50 and y = 70 with the level inset
    # -230 (0x2ec6e8); the button sits at width - 112 by 100 (0x2ec6f8); the card is the view
    # height less 140 (0x2ec728); the description starts at x = 10 under the banner; the divider
    # and its label are 30 tall and take UIView(RB) -width; the sample overlay is at the origin
    # and its spinner is a half-sized WhiteLarge indicator; the terms text is a Japanese literal.
    0x1a9458: 'RBStoreExtendNoteDetailViewController -viewWillAppear:: the whole hierarchy, every '
              'constant decoded from the pool',
    0x1ab7fc: 'RBStoreExtendNoteDetailViewController -viewDidAppear:: nil-guarded loadInfo',
    0x1ab870: 'RBStoreExtendNoteDetailViewController -viewWillDisappear:: the alert is dismissed '
              'before super, and the delegate read at 0x1ab9d4 is discarded',
    # Six defects fixed: the constraint height is MAXFLOAT (0x2ec748) and the fit cap 50, the
    # description top is the banner's maxY, the terms strip has two arms around the card height,
    # and the content size is itemView.height + detailView.height.
    0x1aba24: 'RBStoreExtendNoteDetailViewController -updateLayout: the nine-attempt font shrink '
              'and both card-height arms (fcmp at 0x1abed4)',
    0x1ac3ec: 'RBStoreExtendNoteDetailViewController -viewDidDisappear:: bare super call',
    0x1ac420: 'RBStoreExtendNoteDetailViewController -willAnimateRotationToInterfaceOrientation:'
              'duration:: super, then updateLayout',
    0x1ac470: 'RBStoreExtendNoteDetailViewController -setButtonTextBuy: g_pLocalizedBuyFormat over '
              'the boxed price, enabled',
    0x1ac5fc: 'RBStoreExtendNoteDetailViewController -setButtonTextInstall: normal state, enabled',
    0x1ac6ac: 'RBStoreExtendNoteDetailViewController -setButtonTextInstalling: disabled state '
              '(w3 = 2), disabled',
    0x1ac75c: 'RBStoreExtendNoteDetailViewController -setButtonTextInstalled: the same shape with '
              'the installed global',
    0x1ac80c: 'RBStoreExtendNoteDetailViewController -selfCheckButtonText: the unsigned compare at '
              '0x1ac99c disables the error state too',
    0x1aca50: 'RBStoreExtendNoteDetailViewController -showTerm: store term controller, pushed '
              'animated',
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
    0x1d7964: 'RBStoreDetailViewController -init: the navigation title is "info", not the '
              'empty-copyright constant that had been reused for it; that constant keeps its '
              'name and its own correct use on the copyright cell',
    # RBStoreDetailViewController. The inverse sweep has its first confirmed catch here and
    # it was a wrong value, not merely a wrong name.
    0x1d8aa0: 'RBStoreDetailViewController -stopSample:: the fade is '
              'g_flFlashMinOpacity at four bytes, not a local constant of zero; the '
              'local had the wrong value, an instant stop against a 0.2 second fade',
    0x1d8c18: 'RBStoreDetailViewController -finishBgm:: a 64-bit pair, tbnz on bit 63 '
              'then an unsigned compare, which is exactly what the source cast makes '
              'correct',
    0x1d8d84: 'RBStoreDetailViewController -doPurchase:: the sample stop runs only on '
              'the not-purchased arm',
    0x1d9028: 'RBStoreDetailViewController -setPurchaseState:: guarded on the header '
              'view, and the argument is inverted before setEnabled:',
    0x1d9408: 'RBStoreDetailViewController -setButtonTextBuy: one argument slot for one specifier',
    0x1d95d8: 'RBStoreDetailViewController -setButtonTextInstall: normal state and '
              'enabled, unlike the installing and installed pair which use the disabled '
              'state',
    0x1d9f58: 'RBStoreDetailViewController -tableView:numberOfRowsInSection:: count plus two',
    0x1dc3fc: 'RBStoreDetailViewController -didReceiveMemoryWarning: the super call only',
    0x1dc430: 'RBStoreDetailViewController -viewDidUnload: super first, then the artwork stop',
    # RBStorePageViewController closes out. Every method is now ticked or accounted for:
    # -viewDidLoad and -scrollViewDidScroll: are recommended for rewrite rather than
    # patching, packListDownloadSuccess: is unread, and five invented selectors are left
    # in place deliberately so the rewrite diff stays readable.
    0x1eee74: 'RBStorePageViewController -openItunesWithURL:: both arms; the affiliate '
              'call takes the NSURL object itself, with no absoluteString send '
              'anywhere, which the committed header disagrees with',
    0x1ef574: 'RBStorePageViewController -storeExtendNoteInfoDownloaderFinished:: '
              'guarded clear, then the next restore',
    0x1ef694: 'RBStorePageViewController -storeExtendNoteInfoDownloaderError:: hides '
              'the dialog, where the pack equivalent deliberately does not, the two '
              'being otherwise identical',
    0x1ef7c0: 'RBStorePageViewController -updateExtendNoteInfo:Save:: the save flag '
              'gates the persist',
    0x1ef8a0: 'RBStorePageViewController -showTerms: mask 0x3f, five sends in order',
    # RewardCore, first batch. Two of its three defects are exact repeats of RecommendCore's
    # singleton pair, and a tree-wide sweep for that shape now returns nothing, so the two
    # were the only instances and the pattern is closed.
    0x2076e4: 'RewardCore -init: the whole body was dropped; the binary wraps the super '
              'call in a dispatch_sync on the shared queue through a byref',
    0x2078b8: 'RewardCore +allocWithZone:: creates the queue in its once body and '
              'guards on the shared slot',
    0x2079d0: 'RewardCore +sharedInstance: the instance slot is the file-scope one '
              '+allocWithZone: writes, not a method-local static',
    0x207a80: 'RewardCore -initializeFlg: tracking disabled returns zero before the ivar is read',
    0x207acc: 'RewardCore -clearInitialize: clears the flag, removes the campaign key, '
              'synchronises',
    0x207b6c: 'RewardCore -campaignFlg: every failing arm falls to the same -2',
    0x208624: 'RewardCore -startWithBlock:: the block tag named the method; the invoke '
              'is at 0x2086bc',
    0x208738: 'RewardCore -createUdidWithBlock:: an eor before the ccmp means the block '
              'fires when the result is false or the error is set',
    0x2088e0: 'RewardCore -createCFUdidWithError:: the pasteboard import runs only when '
              'one udid is present and the other is not',
    0x1ec5f0: 'RBStorePageViewController -scrollViewDidScroll:: rewritten from the disassembly; '
              'the arm test is the table content height against its bounds height, the frame is '
              'captured three-quarters with origin.y replaced, and the second banner halves its '
              'own height where the first uses the whole',
    0x54210: 'AppDelegate -application:didReceiveLocalNotification:: the outer dictionary really '
             'is a literal, three pairs read from the stack, but the inner lookup sends '
             'objectForKey:',
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
    # neTextureForiOS's NSData decoder, the sibling of C_TEXTURE::LoadFromUIImage. The two loops at
    # 0x323b8 and 0x323cc round the CGImage's width and height up to a power of two; the flip
    # translates by the image height (scvtf d9,w23), not the allocated height. The alpha test at
    # 0x100032494 is (alphaInfo - 1) unsigned-less-than 4, so formats 1 through 4 stay RGBA and 0,
    # 5, and 6 take the tight-RGB repack at 0x3244b4. The scale is a float, not a double: the type
    # encoding ends f24 and SetDataAndUpload stores the register it is forwarded in with str s0 at
    # 0x31f84, with no fcvt anywhere on the path.
    0x32320: 'neTextureForiOS +LoadTexture:Scale:: power-of-two RGBA decode, tight-RGB when opaque',
    # NetworkUtil's endpoint builders. Every format string and endpoint path was decoded from its
    # __cfstring entry rather than read off a label, and every stringWithFormat: argument list was
    # taken from the stp/str writes to [sp, #..] ahead of the bl.
    # The length is 64-bit throughout (cbz x20 at 0x32634, cmp x24,x20 with b.cc at 0x326bc), which
    # matches the Q16 in the method's type encoding. The alphabet at 0x32f666 is 62 characters and
    # the modulus is the divide-by-62 magic at 0x32670-0x3269c.
    0x32610: 'NetworkUtil +createNonce: 62-character alphabet, NSUInteger length',
    0x32740: 'NetworkUtil +deviceName: getInstance then getHardwareName',
    # The cache is the global at 0x3dc278, guarded by a bare cbnz at 0x327c8 with no dispatch_once.
    # The suffix is the __cfstring at 0x363ce0, whose five bytes at 0x32f6a8 spell STORE.
    0x327b0: 'NetworkUtil +identifierParams: cached MD5 of the UUID key plus the STORE suffix',
    # Format 0x363d00. The five slots at 0x32910-0x32918 are identifierParams, 0x1a160c, deviceName,
    # 0x1a1600, 0x1a1618, in that order.
    0x3287c: 'NetworkUtil +userInfo: five-slot uuid/version/device/os/locale query',
    # x2 is the scheme and x3 the host at 0x32a28-0x32a2c, so 0x363d20 and 0x363900 are not swapped.
    0x329d0: 'NetworkUtil +createSecureURL: https://akx.s.konaminet.jp with the given path',
    # The cbz x20 at 0x32ab4 picks the arm; both arms lead the argument list with the CGI base path
    # at 0x363920, so the api and param slots follow it rather than precede it.
    0x32a6c: 'NetworkUtil +createSecureAPI:withParam: two arms, base path first in both',
    0x32ba0: 'NetworkUtil +startupURL: startup/ with target=%@',
    0x32c70: 'NetworkUtil +resourceURL: v3/ssl_resource/, nil param',
    0x32c90: 'NetworkUtil +tokenSetURL: push/token/, nil param',
    0x32cb0: 'NetworkUtil +lineMessageURL: new2/ with target=%@&%@',
    0x32dac: 'NetworkUtil +playedV2URL: log/play/, nil param',
    0x32dcc: 'NetworkUtil +tutorialStatusURL: tutorial/, nil param',
    0x32dec: 'NetworkUtil +searchMasterURL: search_master/ with target=%@&%@',
    0x32ee8: 'NetworkUtil +searchURL: gamecenter/, nil param',
    # The theme reaches the format as an NSNumber, boxed by the numberWithInt: at 0x32f78.
    0x32f08: 'NetworkUtil +unlockListURL: unlock/ with target=%@&thema=%@',
    # Four slots, not three: 0x330b8 and 0x330bc write region, music, key, and userInfo, and the
    # format at 0x363de0 ends in &%@.
    0x33058: 'NetworkUtil +unlockMusicURL:randKey:: unlockmusic/, four-slot query with userInfo',
    0x33168: 'NetworkUtil +unlockedURL: unlocked/, nil param',
    0x33188: 'NetworkUtil +packListURL:limit:genre:: five-slot query, userInfo last',
    # cbz w3 at 0x332cc; the closed arm at 0x33358 writes only region and pack.
    0x332a8: 'NetworkUtil +packInfoURL:UserOpen:: both arms, userInfo only when open',
    0x33408: 'NetworkUtil +musicInfoURL:: v3/musicinfo/ with target=%@&music=%d&%@',
    0x33514: 'NetworkUtil +receiptV3URL: v3/verify_receipt/, nil param',
    0x33534: 'NetworkUtil +campaignListURL: campaign/list/, nil param',
    # The verify and fetch paths sit adjacent in the pool and are not transposed: 0x3356c loads
    # 0x363b60 (campaign/verify/) and 0x3358c loads 0x363b40 (campaign/fetch/).
    0x33554: 'NetworkUtil +campaignSerialCheckURL: campaign/verify/, nil param',
    0x33574: 'NetworkUtil +campaignItemInfoURL: campaign/fetch/, nil param',
    0x33594: 'NetworkUtil +manageSortListURL: manage_sort/ with target=%@',
    0x3365c: 'NetworkUtil +extendNoteListURL:limit:: four-slot query, userInfo last',
    # cbz w3 at 0x33790, mirroring packInfoURL:UserOpen:.
    0x3376c: 'NetworkUtil +extendNoteInfoURL:UserOpen:: both arms, userInfo only when open',
    0x338cc: 'NetworkUtil +termList: v3/terms/list/, nil param',
    0x338ec: 'NetworkUtil +termFetch: v3/terms/fetch/, nil param',
    0x3390c: 'NetworkUtil +termAgree: v3/terms/log/, nil param',
    0x3392c: 'NetworkUtil +userAgeURL: v3/age/, nil param',
    # AudioManager's sound-effect, background-music and interruption routines. The ivar list settles
    # the offset variables these bodies index: 0x3c8430 sePlayer, 0x3c8434 seAVPlayer, 0x3c843c
    # seList (stride 0xc), 0x3c8438 _isStart, 0x3c8440 isInterruption, 0x3c8444 isPlaying, 0x3c8448
    # isSuspend, 0x3c844c isOnPauseVoice, 0x3c8450 isOnPause, 0x3c8454 seVolume, 0x3c8458 seManageId
    # (stride 0x30 per group), 0x3c845c unitVolume.
    0x3DAC4: 'AudioManager -getGroupID:resourceId:: cbz on the call name picks the key',
    # Four arms off the cbz x19 at 0x3dc8c and the cbz w23 at 0x3dc90. The tag is applied by the orr
    # at 0x3df10 (0x60000000, bus) and 0x3e024 (0x10000000, voice), each on the pre-boxed index.
    0x3DC48: 'AudioManager -loadSe:isLoop:callName:group:: four arms, both index tags',
    0x3E1A4: 'AudioManager -releaseSe:resourceId:: four arms, count re-read every iteration',
    # The rid loop calls intValue twice, once for the group and again for the mask (0x3e754,
    # 0x3e7ac).
    0x3E580: 'AudioManager -releaseSeAll: name loop then rid loop, seType cleared last',
    # The dispatch block is emitted twice, before and after stopOldInstance; both copies agree.
    0x3E8E4: 'AudioManager -prepare:resourceId:volume:: retry once after dropping the oldest',
    0x3EAB0: 'AudioManager -prepareSetGroup:resourceId:groupId:: bus from slot, volume from group',
    0x3EC00: 'AudioManager -playSe:resourceId:: volume from seVolume[group]',
    0x3ECE8: 'AudioManager -playSe:resourceId:Volume:: same with an explicit volume',
    # Sweep then compact, both over seList; the trailing re-read at 0x3f388 returns early.
    0x3F260: 'AudioManager -orderInstanceList: sweep finished slots then compact',
    # The same shape over seManageId, but it swaps the bus ids rather than the groups (0x3f4c4 to
    # 0x3f4d0) and then scans for the first free slot.
    0x3F3C0: 'AudioManager -orderInstanceList:: per-group sweep, compact, then first free slot',
    # fmov d0 of 1.0 at 0x3f738 and -1.0 at 0x3f878, divided by the time and scaled by the pool
    # double at 0x2eef30, which is 0x3fa99999a0000000, a float 0.05f widened.
    0x3F714: 'AudioManager -createBgmFadeInTimer:: unitVolume = 0.05f / time',
    0x3F854: 'AudioManager -createBgmFadeOutTimer:: the same with a negated numerator',
    # fcmp against the same 0x2eef30 double at 0x3fa20, b.le taking the immediate arm.
    0x3F994: 'AudioManager -playBgm:: interruption guard, then faded or immediate start',
    0x3FC1C: 'AudioManager -stopBgm:: deleteFadeTimer before the fade test',
    0x3FD48: 'AudioManager -onPauseBgm:: isOnPause set before deleteFadeTimer',
    0x3FE30: 'AudioManager -bgmCurrentTime: zero when there is no player',
    0x3FED0: 'AudioManager -bgmDeviceCurrentTime: same shape',
    0x3FF70: 'AudioManager -setBgmCurrentTime:: no-op when there is no player',
    0x40018: 'AudioManager -isPlayingBgm: forwards to the player',
    # The clamp at 0x40190 is overwritten by the unconditional setVolume: at 0x40200.
    0x400C4: 'AudioManager -onFadeInTimer:: identity check, then a clamp the tail undoes',
    # b.pl at 0x40308 keeps fading; the silent arm reads isOnPause at 0x40384 to pick stop or pause.
    0x40268: 'AudioManager -onFadeOutTimer:: stop or pause chosen by isOnPause',
    0x4048C: 'AudioManager -pushBgm: pause, drop the old stack entry, then move the player across',
    0x405A4: 'AudioManager -popBgm: release, restore, re-delegate, clear the stack',
    0x40660: 'AudioManager -seekBgmToTop: setCurrentTime: zero, no nil check',
    0x406B8: 'AudioManager -playVoice: resumes from voicePlayTime only when paused',
    0x407BC: 'AudioManager -stopVoice: clears isPlaying[1]',
    0x40860: 'AudioManager -onPauseVoice: saves the position, then stops rather than pauses',
    0x40948: 'AudioManager -isPlayingVoice: forwards to the player',
    # Two independent compares, so one player can match each.
    0x409F4: 'AudioManager -audioPlayerDidFinishPlaying:successfully:: clears whichever matched',
    # cinc at 0x40af8 turns the compare straight into the array index.
    0x40AA8: 'AudioManager -audioPlayerBeginInterruption:: index is the bgm compare',
    0x40B2C: 'AudioManager -audioPlayerEndInterruption:: cset feeds resumePlayer:',
    0x40BAC: 'AudioManager -audioPlayerEndInterruption:withOptions:: same, options ignored',
    # b.hi at 0x40c3c, so the bound is unsigned and a negative index is rejected too.
    0x40C2C: 'AudioManager -suspendPlayer:: unsigned bound, flag set before the switch',
    # Guarded on isInterruption, then isPlaying, then the per-player pause flag; the bgm arm loads
    # the 0x2ec718 double, 0x3fd3333340000000, a float 0.3f widened.
    0x40CE4: 'AudioManager -resumePlayer:: three guards, bgm resumes with a 0.3f fade',
    0x40D6C: 'AudioManager -systemSuspend: guarded on _isStart and not isSuspend',
    0x40E00: 'AudioManager -systemResume: the mirror of it',
    # 0x40f04 onwards nils seNameList, seRidList, bgmPlayer, voicePlayer, fadeTimer, stackBgm and
    # seType by hand before the superclass call.
    0x40E90: 'AudioManager -dealloc: engine teardown then seven explicit property clears',
    # RBViewController. Its ivar list confirms the layout the header documents (m_LoopTime +0x08
    # through m_PreviewPlayerColorCache +0x28), and every float below was decoded either from the
    # pool address the adrp/ldr names or from the fmov's own imm8 field, because Ghidra's rendering
    # of an fmov immediate is a bit pattern rather than a value.
    0x89050: 'RBViewController -loadView: mask 0x12, scale guarded by respondsToSelector:',
    # Popover size from 0x2ee918 and 0x2fedd0; the neighbours are 90.0 and 312.0, both plausible.
    0x8945c: 'RBViewController -showPresentViewController:: two arms, popover 320x480 on the pad',
    0x89798: 'RBViewController -playListAddMusicSet:: type 1, anchored on the add button',
    0x8997c: 'RBViewController -playListButtonPush:: guarded on selectedView, themed effect 1',
    # Three defects fixed. The cover mask at 0x310450 is 0x3f and 0x12 is its pool neighbour at
    # 0x310458; the indicator style is 1 (White); the spinner bounds are a 20-point square from the
    # fmov at 0x89fb4, not the cover's bounds.
    0x89c90: 'RBViewController -createView: menu view then tweet cover, both built once',
    # One defect fixed: w3 is 2 at 0x8a24c, which is Slide.
    0x8a134: 'RBViewController -viewWillAppear:: status bar hidden with the slide animation',
    0x8a294: 'RBViewController -didSelectPlaylistViewController:: popover on the pad, modal off it',
    # d2 and d3 of the frame are taken, so it really is the size and not the origin.
    0x8a444: 'RBViewController -navigationController:willShowViewController:animated:: size only',
    0x8a5d8: 'RBViewController -viewWillTransitionToSize:withTransitionCoordinator:: willRotate '
             'in the animation block (0x8a704), didRotate in the completion (0x8a774)',
    0x8b288: 'RBViewController -SetLoopTimeMilliSec:: str s0 then CreateTimer',
    0x8b2a0: 'RBViewController -CreateTimer: both flags, then Start on each C_TIME',
    0x8b314: 'RBViewController -RemoveTimer: invalidate then nil',
    0x8b3bc: 'RBViewController -showMusicListView: takeover point read before the flag is set',
    # Four defects fixed. 0x8bbcc is PlayGameStateSoundEffect (0x1ccb08); 0x8bc08 is
    # LoadAndSetThemedVoice (0x1ccc18), not the themed effect player; 0x8bc4c starts the loop a
    # second time; and the hide-animation block at 0x8bd9c sets up the camera, calls
    # UpdateProjection and enters normal scene mode rather than only starting the loop.
    0x8b5b8: 'RBViewController -playGameWithMusicData:RandSeed:: difficulty switch 1/2/default',
    # Three defects fixed. PauseMusic takes the 0.2f at 0x2ec6b4, whose neighbour 0x2ec6b0 is the
    # 100.0f tilt near plane; the dispatch delay is 0x05f5e101 from the movz/movk at 0x8c3f0, a
    # tenth of a second and not a whole one; and its block at 0x8c884 enters alternate scene mode
    # rather than calling -showPreview.
    0x8be40: 'RBViewController -startPreview: pad speed-type clamp, then the shared settings tail',
    0x8c8cc: 'RBViewController -showPreview: hides the menu and the cover',
    # The retry loop runs 101 times; PlayMusic takes the 1.5f from the fmov at 0x8cae4.
    0x8c970: 'RBViewController -hidePreview: three store-id checks short-circuit onto one call',
    0x8ce28: 'RBViewController -openItunesWithURL:: falls back to openURL: when there are no '
             'affiliate parameters',
    0x8d204: 'RBViewController -closeItunesWithURL: forwards to the finish handler',
    0x8d264: 'RBViewController -getTopViewController:: navigation controllers take lastObject',
    0x8d40c: 'RBViewController -productViewControllerDidFinish:: guarded on itunesViewCtrl',
    0x8d540: 'RBViewController +hasTwitterAPI: NSClassFromString compared against nil',
    0x8d564: 'RBViewController +canTweet: short-circuits on hasTwitterAPI',
    0x8d5b4: 'RBViewController -PostTwitter:Images:URLs:: fast enumeration over both arrays',
    0x8d9c0: 'RBViewController -PostTweet: arrayWithObject: then both fields cleared',
    0x8dacc: 'RBViewController -PostImageCreater: creates the image, then hops to the main thread',
    # One defect fixed: w3 is 4 at 0x8dd4c, ReloadIgnoringLocalAndRemoteCacheData.
    0x8dbbc: 'RBViewController -PostTwitter:Text:: four-way guard, 15 second probe timeout',
    0x8de58: 'RBViewController -cancelTwitterConnection: clears the flag and hides the cover',
    0x8df10: 'RBViewController -connection:didReceiveResponse:: cmp against 0x194, which is 404',
    0x8dfc8: 'RBViewController -connection:didFailWithError:: forwards to the cancel path',
    0x8dfe4: 'RBViewController -connectionDidFinishLoading:: lazily creates the queue',
    0x8e118: 'RBViewController -showTermsWithDelegate:: term type 1 at 0x8e1b0',
    0x8e2d8: 'RBViewController -updateErosionMarkScore: tail call to the updater',
    # One defect fixed: the width comes from the UIView(RB) -width category, whose selector is at
    # 0x3bf998, and the two margins are fmov immediates of -10.0 and 10.0 at 0x8e420 and 0x8e430.
    0x8e2f4: 'RBViewController -setupCorporateButton: top-right inset by 10, mask 0x21',
    # Two defects fixed: the duration at 0x2ec718 is a float 0.3f widened, and the options word is
    # 3 at 0x8e634, LayoutSubviews with AllowUserInteraction rather than an ease curve.
    0x8e550: 'RBViewController -fadeCorporateButton:: weak self, 0.5 second delay',
    0x8e898: 'RBViewController -tapCorporateButton:: Safari when available, openURL otherwise',
    # RBErosionMarkUpdater, partial: the picker, text-field and alert delegates plus the two update
    # outcomes. The ivar list types every score as q, so the NSInteger properties are right, and the
    # shared updater really is the global at 0x3de498. The rest of the class is not read yet.
    # The fcsel at 0x142bf0 picks 1.0 on the pad and the 0x2ec6a0 double otherwise, which is
    # g_dTranslucentAlpha, a float 0.8f widened; its neighbour at 0x2ec698 is 168.0. The 1.0 is an
    # fmov immediate whose imm8 at 0x142bec is 0x70.
    0x142B4C: 'RBErosionMarkUpdater +updateCheckStart:: lazy singleton, then the pad display rate',
    0x142D4C: 'RBErosionMarkUpdater -updateStartBasic:Medium:Hard:: base and edit set pairwise',
    # cmp 2 then cmp 1 then cbnz, and the three arms pass 0, 1 and 2 to setPickerViewScore:score:
    # at 0x143e7c, 0x143f4c and 0x144014.
    0x143D8C: 'RBErosionMarkUpdater -reset: three arms plus a default that does nothing',
    0x14451C: 'RBErosionMarkUpdater -needUpdateScore: three lower-bound compares, short-circuited',
    0x144820: 'RBErosionMarkUpdater -getScore: tune id 0x5f5e470 out of the shared context',
    # Three defects fixed. The types string is B16@0:8 and the binary returns w21, 0 at 0x144be8 and
    # 1 at 0x144c50, so it is not void. There is no NSLog anywhere in the routine: every bl is
    # msgSend or an ARC helper, and the only selector sent to the error is userInfo (0x3bfb10). The
    # save-failure path instead reads __got[8], which the indirect symbol table binds to
    # _NSDetailedErrorsKey, tests the result for nil at 0x144b20 and for count at 0x144b34, and
    # enumerates it with an empty body. The single return test at 0x144be4 is on the error, not on
    # the result of -save:.
    0x1448D8: 'RBErosionMarkUpdater -updateScore: BOOL return, empty detailed-error walk',
    # Multipliers read off the arms: 0x64 then 0xa for the three-digit basic picker, 0x3e8 then
    # 0x64 then 0xa for the four-digit medium and hard ones.
    0x1433EC: 'RBErosionMarkUpdater -getPickerViewScore:: 3 digits basic, 4 medium and hard',
    0x14370C: 'RBErosionMarkUpdater -setPickerViewScore:score:: the mirror, animated always NO',
    # Two defects fixed, both invented text. The __cfstring at 0x36d060 is 13 characters with no
    # trailing full stop, and 0x36d080 is a different sentence from the one we had.
    0x144080: 'RBErosionMarkUpdater -scoreValidate: unchanged test, then three bounded ranges',
    # One defect fixed: the routine sends exactly two set...Controller: messages, so the confirm
    # controller is never cleared. Both bounds globals are cleared at 0x144f78 and 0x144f88.
    0x144D38: 'RBErosionMarkUpdater -remove: two arms off NSClassFromString(UIAlertController)',
    # Three defects fixed. Only d2 of the frame at 0x142e9c survives into the toolbar: the origin is
    # zeroed by the two movi at 0x142ee0 and the height is the 44.0 at 0x2eec40, whose neighbours
    # are 284.0 and 79.0. Both bar-button titles were a single space where the binary carries
    # UTF-16 string constants at 0x36d000 and 0x36d020.
    0x142E08: 'RBErosionMarkUpdater -setupView: toolbar, three tagged pickers, three alert builders',
    0x143B8C: 'RBErosionMarkUpdater -pickerOpen: first non-nil field becomes first responder',
    0x143CC8: 'RBErosionMarkUpdater -pickerClose: resigns all three unconditionally',
    0x144418: 'RBErosionMarkUpdater -updatePerform: update, remove, then clear the global',
    0x14445C: 'RBErosionMarkUpdater -updateCancel: remove, mark updated, save, clear the global',
    # Both zero-index arms reach the same reshowAlertSetScore:nil at 0x148160 and 0x148178.
    0x1480AC: 'RBErosionMarkUpdater -alertView:clickedButtonAtIndex:: cancel and confirm views',
    0x1481A4: 'RBErosionMarkUpdater -textFieldDidBeginEditing:: stores the tag',
    0x148204: 'RBErosionMarkUpdater -textFieldDidEndEditing:: stores -1 then resigns',
    # sub/cmp/cinc at 0x148288 gives four components for tag 1 or 2 and three otherwise.
    0x148270: 'RBErosionMarkUpdater -numberOfComponentsInPickerView:: 4 for medium and hard',
    0x1482A8: 'RBErosionMarkUpdater -pickerView:titleForRow:forComponent:: bare %zd of the row',
    0x1482E4: 'RBErosionMarkUpdater -pickerView:didSelectRow:inComponent:: %04zd into the field',
    # RBStoreExtendPageViewController, read against the disassembly one routine at a time.
    0x15a0b8: 'RBStoreExtendPageViewController -initWithParent:: IsPad() at 0x15a2e4 stores the '
              'idiom byte, moveToPackID starts at -1 (0x15a300)',
    0x15a3a4: 'RBStoreExtendPageViewController -loadView: the background is 226/227/228 from the '
              'pool at 0x30be90..0x30bea0, mask 0x12',
    # Six defects fixed. The pad table reserves the show-more BUTTON's height (v11 at 0x15ac84),
    # the spinner centre is (buttonW*0.5 + spinnerW, buttonH*0.5) at 0x15abb8, its style is Gray
    # (w2=2 at 0x15ab34), the button inset is the fmov #-15.0 at 0x15aa64, the campaign image name
    # puts campaignName first (stp x24,x8 at 0x15ba08), and the loading spinner's centre y is a
    # literal zero (movi v1 at 0x15bf18).
    0x15a534: 'RBStoreExtendPageViewController -viewDidLoad: both idiom arms, every pool constant '
              'decoded',
    0x15c660: 'RBStoreExtendPageViewController -showError:: hides 0x2710 and 0x2711, then sets '
              'and reveals 0x2712',
    0x15c810: 'RBStoreExtendPageViewController -pushBarBtnRestore:: tag 0x1f at 0x15c84c',
    0x15c880: 'RBStoreExtendPageViewController -showTerms: mask 0x3f from 0x310450, then '
              '-showAnimation',
    # The four dictionary keys were read out of the CFString structs the stack slots point at,
    # and the block invokes are 0x15ce0c (bare ret), 0x15ce10 and 0x15d0e0.
    0x15c9a4: 'RBStoreExtendPageViewController -sendUserAge: target/app_ver/user_id/type, count 4 '
              'at 0x15cae4, alert tag 0x22 in both failure blocks',
    # Two defects fixed: the right-hand banner and the 0x186a0 label both take the width from
    # UIView(RB) -width (frame width, sel at 0x3bf998), not from bounds.
    0x15d260: 'RBStoreExtendPageViewController -extendNoteListDownloadSuccess:: gap 300/100 at '
              '0x15d5b0, margin +-50.0 from 0x2ec6e0/0x2ec738, label drop 25.0 at 0x15d958',
    0x15db50: 'RBStoreExtendPageViewController -forceOpenExtendNoteDetailView: three arms, the '
              'idiom byte at 0x15dc5c picks the pad overlay teardown',
    0x15deec: 'RBStoreExtendPageViewController -extendNoteListDownloadError:errorMessage:: the '
              'cbz at 0x15df80 puts the inline alert on the visible-table arm',
    0x15e208: 'RBStoreExtendPageViewController -extendNoteListDownloadNothing:: same polarity, '
              'then the pending PID is cleared unconditionally',
    0x15e340: 'RBStoreExtendPageViewController -cellViewSelected:: guarded by allowsSelection, '
              'the cell view supplies its own index',
    # The jump table at 0x15e6e4 maps 0..3 to the pack alert, purchase, and the two download arms
    # in that order, and 4 or above falls through to the default.
    0x15e4e0: 'RBStoreExtendPageViewController -selectButton:: four button states, alert tag 0x21',
    # Both blocks retain self at 0x15e850 and 0x15e878 rather than taking a weak reference, so
    # the weak capture was wrong; the open duration is the double 0.3 from 0x3010a0.
    0x15e6f4: 'RBStoreExtendPageViewController -openExtendNoteDetailViewWithPID:: strong self '
              'capture, options 0x30000',
    0x15eb74: 'RBStoreExtendPageViewController -pushSampleButton:: both arms of the refusal flag',
    # The close duration at 0x2ec718 is (double)0.3f, the same slot the label shadow alpha reads,
    # not the double 0.3 the open animation uses.
    0x15ed78: 'RBStoreExtendPageViewController -handleTapCoverView:: strong self capture, the '
              'completion re-enables the restore button only when it exists',
    0x15f160: 'RBStoreExtendPageViewController -startDownloadExtendNote:: the URL is read and '
              'nil-tested twice (0x15f1b8 and 0x15f1d8), then both idiom arms of each state',
    # The threshold table at 0x30bef0 is {5000, 5000, 20000}, not the round figures it looks like.
    0x15f9a0: 'RBStoreExtendPageViewController -checkAttainLimitPurchase:: type 0 raises the '
              'selection alert (tag 0x20), any other type the over-limit message',
    0x15fbec: 'RBStoreExtendPageViewController -startPurchase:: both bail-outs share the error '
              'alert at 0x15fdf8, layout 1 for the progress dialog',
    0x15fec0: 'RBStoreExtendPageViewController -detailViewClose: pad taps the cover view, phone '
              'pops animated',
    0x15ff4c: 'RBStoreExtendPageViewController -storeDialogCancel:: both idiom arms, then both '
              'managers save',
    0x1601d8: 'RBStoreExtendPageViewController -updateExtendNoteInfo:Save:: the save arm re-reads '
              'the singleton',
    0x1602b8: 'RBStoreExtendPageViewController -updatePurchasedTableCell:: the pad halves the '
              'index with the signed fix-up at 0x160408, the phone walks section 1, both reload '
              'with animation 5 (None)',
    0x160838: 'RBStoreExtendPageViewController -reDownloadPackMusics:: update with Save:YES, then '
              'the download',
    0x1608a4: 'RBStoreExtendPageViewController -purchaseSucceeded:: the PID guard at 0x160928, '
              'JPY-only accumulation, save runs on both arms',
    # The format is the localised global at 0x3cfd08, seeded from the purchase-cancelled key at
    # 0x110bc, not the bare "%@" the reconstruction had.
    0x160d44: 'RBStoreExtendPageViewController -purchaseFailed:error:: localised cancellation '
              'format over error.localizedDescription',
    0x160ed8: 'RBStoreExtendPageViewController -addRestoreExtendNoteInfo:: appends, then drops the '
              'resolved product ID when the pending set holds it',
    0x161040: 'RBStoreExtendPageViewController -nextRestoreExtendNoteInfo: the copy is empty-'
              'tested at 0x1610b4, each ID resolved then added',
    0x161314: 'RBStoreExtendPageViewController -askDownloadAllNotes: the missing count is the '
              'branchless eor/add at 0x16166c, prompt tag 0x1e',
    0x161804: 'RBStoreExtendPageViewController -restoreDownloadAllNotes: the nil-array arm at '
              '0x161ae8 is unreachable and kept',
    # The jump table at 0x1621dc covers tags 0x1e through 0x22 in order.
    0x161d34: 'RBStoreExtendPageViewController -alertView:clickedButtonAtIndex:: five tags, the '
              'limit alert splits at button index 3 (0x161edc)',
    0x1621f0: 'RBStoreExtendPageViewController -alertViewCancel:: only the pack tag 0x21 clears '
              'moveToPackID',
    0x162258: 'RBStoreExtendPageViewController -didPresentAlertView:: the presented root view',
    0x162398: 'RBStoreExtendPageViewController -restoreSucceeded: both working sets rebuilt, then '
              'the download prompt on a NO return',
    0x162604: 'RBStoreExtendPageViewController -restoreFailed:: the same 0x3cfd08 format as the '
              'purchase failure',
    0x16273c: 'RBStoreExtendPageViewController -restoreNothing: tail-call to hideModalDialog',
    0x162790: 'RBStoreExtendPageViewController -storeExtendNoteInfoDownloaderFinished:: the '
              'polarity really is inverted against -restoreSucceeded (cbz at 0x162860)',
    0x1628b0: 'RBStoreExtendPageViewController -storeExtendNoteInfoDownloaderError:: detach, drop, '
              'hide',
    0x162988: 'RBStoreExtendPageViewController -downloadManagerStartTask:: g_pDownloadingMessage'
              'Format at 0x3cfbd8 over the current task name',
    0x162b7c: 'RBStoreExtendPageViewController -downloadManagerCompleted:: both idiom arms, then '
              'both managers save and the dialog hides',
    0x162dbc: 'RBStoreExtendPageViewController -downloadManagerFailed:: alert first, then both '
              'idiom arms, then the saves',
    0x16304c: 'RBStoreExtendPageViewController -downloadManagerProceed:: the ivar supplies the '
              'progress, the argument is ignored',
    0x16315c: 'RBStoreExtendPageViewController -numPackRows: the pad rounds up with an unsigned '
              'shift at 0x1631c0',
    # Defects fixed: the footer spinner is a 24x24 White indicator (0x163848, w2=1 at 0x16386c),
    # not a zero-framed Gray one.
    0x163240: 'RBStoreExtendPageViewController -tableView:cellForRowAtIndexPath:: both idiom arms, '
              'the pad right tile index is the bfi at 0x16452c, footer font 18/15 by fcsel',
    0x164f54: 'RBStoreExtendPageViewController -tableView:numberOfRowsInSection:: the two idiom '
              'arms really are identical',
    # Defect fixed: the height tables at 0x30bed0 (pad) and 0x30bee0 (phone) had been read the
    # wrong way round, so the pack row was 80 on the pad and 140 on the phone.
    0x16504c: 'RBStoreExtendPageViewController -tableView:heightForRowAtIndexPath:: two two-entry '
              'tables indexed by the pack-row cset at 0x1650a8',
    # Defect fixed: the phone row tints are 0.8 (0x2eea40) and 193/255 (0x30bec0).
    0x16511c: 'RBStoreExtendPageViewController -tableView:willDisplayCell:forRowAtIndexPath:: both '
              'idiom arms, footer rows take g_dRBWebViewGrayViewWhite',
    0x165428: 'RBStoreExtendPageViewController -tableView:willSelectRowAtIndexPath:: returns the '
              'argument',
    0x165440: 'RBStoreExtendPageViewController -tableView:didSelectRowAtIndexPath:: the footer row '
              'and every pad row are inert',
    0x165598: 'RBStoreExtendPageViewController -showDetailViewForPhone:: delegate, info, pending '
              'PID cleared, pushed animated',
    0x165708: 'RBStoreExtendPageViewController -selectShowMore: the in-flight flag guards it, the '
              'button recentres around its own sizeToFit',
    0x165938: 'RBStoreExtendPageViewController -imageDownloader:didLoad:: the pad maps the product '
              'row back with the signed halving at 0x1659f8 and picks the tile by parity',
    # Defect fixed: the snapped Y is (contentOffset.y + bounds.height) - anchoredHeight, per the
    # fadd/fsub pair at 0x165ec4, not baseY + contentOffset.y.
    0x165c40: 'RBStoreExtendPageViewController -scrollViewDidScroll:: auto-load guard, then both '
              'banners with margins 300/100 and the campaign half-height anchor at 0x16601c',
    0x166184: 'RBStoreExtendPageViewController -stopDownloadArtworks: empty-guarded, detach then '
              'cancel each, then clear',
    0x1663a4: 'RBStoreExtendPageViewController -viewWillAppear:: the phone deselect arm, the error '
              'label resize, and both IsPad() calls at 0x166568 and 0x1665d8',
    # Defect fixed: the first-fetch arm hides the pack table (w2 = 1 at 0x1669fc); the
    # reconstruction revealed it.
    0x166858: 'RBStoreExtendPageViewController -viewDidAppear:: empty list and no fetch in flight '
              'is the only arm that starts a fetch',
    0x166ad0: 'RBStoreExtendPageViewController -viewWillDisappear:: pad teardown, in-flight reset, '
              'downloader drop, then cancelFetching',
    0x166d48: 'RBStoreExtendPageViewController -willAnimateRotationToInterfaceOrientation:duration:'
              ': bare super call',
    0x166d80: 'RBStoreExtendPageViewController -didReceiveMemoryWarning: clears the cache before '
              'super',
    0x166e04: 'RBStoreExtendPageViewController -dealloc: detach and cancel the info downloader',
    0x166f14: 'RBStoreExtendPageViewController -showLoadingView: the scrolled rect takes width and '
              'height from two separate frame reads (0x167008, 0x167018)',
    0x16726c: 'RBStoreExtendPageViewController -popoverControllerDidDismissPopover:: back button '
              'then restore button re-enabled',
    0x167340: 'RBStoreExtendPageViewController -storeDetailViewOpenItunesWithURL:: nil-guarded '
              'forward to the root view controller',
    # Defect fixed: the fallback arm at 0x1675c8 passes the argument straight to openURL:, so the
    # parameter is an NSURL and not a string, matching RBStorePageViewController's twin.
    0x167404: 'RBStoreExtendPageViewController -openItunesWithURL:: affiliate parameters decide '
              'between the in-app product page and Safari',
    0x16777c: 'RBStoreExtendPageViewController -closeItunesWithURL: forwards the retained '
              'controller',
    0x1677dc: 'RBStoreExtendPageViewController -productViewControllerDidFinish:: the completion at '
              '0x167890 clears the property, self captured strongly',
    # MusicData. The yomi tables are static arrays of ten CFString constants at 0x3ceb18 (rows) and
    # 0x3ceb68 (labels), with the no-row initial @"#" in the slot at 0x3cebb8; the reconstruction
    # had built them as NSArrays in an invented +initialize and used @"" for that initial.
    0x5ea48: 'MusicData +GetYomiIndex: the loop bound is the literal 10 at 0x5eaf0 and the '
             'no-row answer the literal 9 at 0x5eaf8; nil or empty returns -1',
    0x5eb44: 'MusicData +GetYomiString: the range check at 0x5eb50 is unsigned (b.cc), so the -1 '
             'GetYomiIndex: can return selects @"#" rather than reading off the table',
    # The key buffer is allocated by the array form of operator new at 0x5ebc4 and released by the
    # array form of operator delete at 0x5ec08, so the shipped translation unit was Objective-C++;
    # the reconstruction still spells them malloc and free, which is the only difference.
    0x5eb78: 'MusicData +decodeBF:Key:KeyLength: derived[i] = i + key[i], MD5 at 0x5ec00, then '
             'cipherInit: with the 16-byte digest and decipher: in place',
    0x5ecd4: 'MusicData +getZipData:Path:DecodeType: the guard at 0x5ed0c is unsigned (b.ls), so '
             'a negative type is rejected too; the key table stride is 16 at 0x5ed88',
    # The archive is closed on the found and the missing path but not when openFile: fails
    # (0x5edd4 skips it). Level range is value-1 in 0..14, from the subs/b.lt and cmp #0xe pairs
    # at 0x5f0dc, 0x5f0fc and 0x5f120.
    0x5ee64: 'MusicData +dataWithPath:ID: decode types 0 and 1 are tried in turn, the sort-name '
             'caches are re-read rather than reused, and the isEqualToString: at 0x5f7f8 is '
             'discarded',
    0x600cc: 'MusicData -getZipData: forwards self.filePath and self.decodeType',
    0x60190: 'MusicData -getOptionalZipData: tail-calls with withDefaultName:nil (x3 = 0)',
    0x601b8: 'MusicData -getOptionalZipData:withDefaultName: the optionalDataDict hit is only a '
             'gate; a nil member still falls through to the default name',
    0x602ec: 'MusicData -musicBasic getOptionalZipData:@"bgm_b" withDefaultName:@"bgm"',
    0x60308: 'MusicData -musicMedium getOptionalZipData:@"bgm_m" withDefaultName:@"bgm"',
    0x60324: 'MusicData -musicHard getOptionalZipData:@"bgm_h" withDefaultName:@"bgm"',
    0x60368: 'MusicData -sheetBasicLight @"note_bas2" defaulting to @"note_bas"',
    0x60398: 'MusicData -sheetMediumLight @"note_med2" defaulting to @"note_med"',
    0x603c8: 'MusicData -sheetHardLight @"note_har2" defaulting to @"note_har"',
    0x603e4: 'MusicData -sheetSpecial nil spData short-circuits at 0x60418',
    0x60484: 'MusicData -sheetSpecialLight nil spData short-circuits at 0x604b8',
    # The two unsuffixed brown accessors read the archive directly and have no cbz on the member;
    # the six suffixed ones reject a nil member before decoding (0x6009b8 and its siblings).
    0x60844: 'MusicData -musicNameImageBrown2xData reads @"title_w2x" and tints unguarded',
    0x60988: 'MusicData -musicNameImageBrown2xDataBasic guarded, cbz at 0x6009b8',
    0x60ad8: 'MusicData -musicNameImageBrown2xDataMedium guarded, cbz at 0x60b08',
    0x60c28: 'MusicData -musicNameImageBrown2xDataHard guarded, cbz at 0x60c58',
    0x60d78: 'MusicData -artistNameImageBrown2xData reads @"artist_w2x" and tints unguarded',
    0x60ebc: 'MusicData -artistNameImageBrown2xDataBasic guarded, cbz at 0x60eec',
    0x6100c: 'MusicData -artistNameImageBrown2xDataMedium guarded, cbz at 0x6103c',
    0x6115c: 'MusicData -artistNameImageBrown2xDataHard guarded, cbz at 0x6118c',
    # IsPad() is the bl to 0x1a1200; the cbz on its result takes the phone arm, and the pad arm
    # prefers the 2x asset only when mainScreen.scale > 1.0 (fcmp against the fmov #1.0).
    0x612ac: 'MusicData -artwork both idiom arms, returns nil when no image decodes',
    0x61498: 'MusicData -artworkBasic both idiom arms, returns nil when no image decodes',
    0x61684: 'MusicData -artworkMedium falls back to -artwork at 0x61814 instead of nil',
    0x6188c: 'MusicData -artworkHard falls back to -artwork at 0x61a1c instead of nil',
    # The 2x variant is fetched only inside the scale > 1.0 arm (b.le at 0x61ae8 skips it) and the
    # single-resolution member only when that returns nil, so neither send is unconditional.
    0x61a94: 'MusicData -musicNameImageWhite lazy 2x preference',
    0x61ba4: 'MusicData -musicNameImageWhiteBasic lazy 2x preference, b.le at 0x61bf8',
    0x61cb4: 'MusicData -musicNameImageWhiteMedium lazy 2x preference, b.le at 0x61d08',
    0x61dc4: 'MusicData -musicNameImageWhiteHard lazy 2x preference, b.le at 0x61e18',
    0x61ed4: 'MusicData -artistNameImageWhite lazy 2x preference, b.le at 0x61f28',
    0x61fe4: 'MusicData -artistNameImageWhiteBasic lazy 2x preference, b.le at 0x62038',
    0x620f4: 'MusicData -artistNameImageWhiteMedium lazy 2x preference, b.le at 0x62148',
    0x62204: 'MusicData -artistNameImageWhiteHard lazy 2x preference, b.le at 0x62258',
    # The black tint is colorWithRed:0 green:0 blue:0 alpha:1 (movi v0-v2, fmov d3 #1.0), which is
    # exactly +blackColor. Each accessor inlines the matching white getter rather than sending it.
    0x62314: 'MusicData -musicNameImageBlack tints the white strip black',
    0x624a0: 'MusicData -musicNameImageBlackBasic tints the basic white strip',
    0x62638: 'MusicData -musicNameImageBlackMedium tints the medium white strip',
    0x627d0: 'MusicData -musicNameImageBlackHard tints the hard white strip',
    0x62968: 'MusicData -artistNameImageBlack tints the artist white strip',
    0x62af4: 'MusicData -artistNameImageBlackBasic tints the basic artist white strip',
    # Both of these send the unsuffixed artistNameImageWhite2x/artistNameImageWhiteData, a shipped
    # copy-paste that the reconstruction had silently corrected to the suffixed variants.
    0x62c8c: 'MusicData -artistNameImageBlackMedium tints the unsuffixed strip, 0x62cf0/0x62d14',
    0x62e24: 'MusicData -artistNameImageBlackHard tints the unsuffixed strip, 0x62e88/0x62eac',
    # The brown family, unlike the black one, does use its own suffix throughout. Its components
    # come from the pool at 0x2fcf38/0x2fcf40/0x2fcf48 and are float quotients widened to double.
    0x62fbc: 'MusicData -musicNameImageBrown tints the white strip brown',
    0x63154: 'MusicData -musicNameImageBrownBasic sends musicNameImageWhite2xBasic at 0x631b8',
    0x632f8: 'MusicData -musicNameImageBrownMedium sends musicNameImageWhite2xMedium at 0x6335c',
    0x6349c: 'MusicData -musicNameImageBrownHard sends musicNameImageWhite2xHard at 0x63500',
    0x63640: 'MusicData -artistNameImageBrown tints the artist white strip brown',
    0x637d8: 'MusicData -artistNameImageBrownBasic sends artistNameImageWhite2xBasic at 0x6383c',
    0x6397c: 'MusicData -artistNameImageBrownMedium sends artistNameImageWhite2xMedium at 0x639e0',
    0x63b20: 'MusicData -artistNameImageBrownHard sends artistNameImageWhite2xHard at 0x63b84',
    # Every 2x accessor has the same body: nil member and nil image both return nil, then
    # imageWithCGImage:scale:orientation: with the fmov #2.0 in d0 and UIImageOrientationUp in x3.
    0x63cc4: 'MusicData -artwork2x rewraps artwork2xData at scale 2',
    0x63dbc: 'MusicData -artwork2xBasic rewraps artwork2xDataBasic at scale 2',
    0x63eb4: 'MusicData -artwork2xMedium rewraps artwork2xDataMedium at scale 2',
    0x63fac: 'MusicData -artwork2xHard rewraps artwork2xDataHard at scale 2',
    0x640a4: 'MusicData -musicNameImageWhite2x rewraps musicNameImageWhite2xData at scale 2',
    0x6419c: 'MusicData -musicNameImageWhite2xBasic rewraps the basic member at scale 2',
    0x64294: 'MusicData -musicNameImageWhite2xMedium rewraps the medium member at scale 2',
    0x6438c: 'MusicData -musicNameImageWhite2xHard rewraps the hard member at scale 2',
    0x64484: 'MusicData -artistNameImageWhite2x rewraps artistNameImageWhite2xData at scale 2',
    0x6457c: 'MusicData -artistNameImageWhite2xBasic rewraps the basic member at scale 2',
    0x64674: 'MusicData -artistNameImageWhite2xMedium rewraps the medium member at scale 2',
    0x6476c: 'MusicData -artistNameImageWhite2xHard rewraps the hard member at scale 2',
    0x64864: 'MusicData -musicNameImageBlack2x rewraps musicNameImageBlack2xData at scale 2',
    0x6495c: 'MusicData -musicNameImageBlack2xBasic rewraps the basic member at scale 2',
    0x64a54: 'MusicData -musicNameImageBlack2xMedium rewraps the medium member at scale 2',
    0x64b4c: 'MusicData -musicNameImageBlack2xHard rewraps the hard member at scale 2',
    0x64c44: 'MusicData -artistNameImageBlack2x rewraps artistNameImageBlack2xData at scale 2',
    0x64d3c: 'MusicData -artistNameImageBlack2xBasic rewraps the basic member at scale 2',
    0x64e34: 'MusicData -artistNameImageBlack2xMedium rewraps the medium member at scale 2',
    0x64f2c: 'MusicData -artistNameImageBlack2xHard rewraps the hard member at scale 2',
    0x65024: 'MusicData -musicNameImageBrown2x rewraps musicNameImageBrown2xData at scale 2',
    0x6511c: 'MusicData -musicNameImageBrown2xBasic rewraps the basic member at scale 2',
    0x65214: 'MusicData -musicNameImageBrown2xMedium rewraps the medium member at scale 2',
    0x6530c: 'MusicData -musicNameImageBrown2xHard rewraps the hard member at scale 2',
    0x65404: 'MusicData -artistNameImageBrown2x rewraps artistNameImageBrown2xData at scale 2',
    0x654fc: 'MusicData -artistNameImageBrown2xBasic rewraps the basic member at scale 2',
    0x655f4: 'MusicData -artistNameImageBrown2xMedium rewraps the medium member at scale 2',
    0x656ec: 'MusicData -artistNameImageBrown2xHard rewraps the hard member at scale 2',
    # size is sent twice, at 0x6582c for the width and 0x65840 for the height, and the blend mode
    # is the literal 0x14 at 0x658d4, which is kCGBlendModeSourceAtop rather than SourceIn.
    0x657e4: 'MusicData -setColor:withColor: draws into an options context at image.scale, then '
             'fills the same rect source-atop',
    0x65964: 'MusicData -createCache the same two idiom arms as -artwork, storing instead of '
             'returning and with no -artwork fallback',
    # Every comparator settles a tie the same way: cset w8,hi and csel with -1 under cc, an
    # unsigned length ordering that ranks the longer string later.
    0x65b4c: 'MusicData -compare: musicNameHira with plain compare:, then length',
    0x65ce0: 'MusicData -compareMusicNameCustom: musicSortName with options 2 (NSLiteralSearch), '
             'then length',
    0x65df4: 'MusicData -compareArtistNameCustom: artistSortName, ties fall to '
             '-compareMusicNameCustom: at 0x65e74',
    0x65eec: 'MusicData -compareMusicNameHira: musicNameHira with options 2, then length',
    0x66000: 'MusicData -compareArtistNameHira: artistNameHira, ties fall to '
             '-compareMusicNameHira: at 0x66080',
    # UIAlertView(RB). Every string operand is an ldr from the shared string cache in
    # __DATA,__common at 0x1003cfb60, which reads as zero in the file, so each key was recovered
    # from the initialiser that fills the cache (one block every 0x4c bytes from 0x100010100,
    # loading the key literal into x2 before -localizedStringForKey:value:table:). Sixteen keys
    # were wrong, mostly a newline smoothed into ". " and " quoting where the binary uses '.
    0xdc98: 'UIAlertView(RB) +deleteAlertViewWithDelegate:: DELETE SONG, nil message, NO/YES, '
            'no -show',
    0xdd38: 'UIAlertView(RB) +strageAlertView: Caution, nil delegate, Close, no -show',
    0xdd94: 'UIAlertView(RB) +showRestoreDownloadWithDelegate:: Install PACKs at 0x1003cfd38, '
            'Cancel/OK',
    0xde64: 'UIAlertView(RB) +showRestoreMessageWithDelegate:: title is Restore purchases at '
            '0x1003cfd30 (0xdea0), not Install PACKs',
    0xdf34: 'UIAlertView(RB) +showGameCenterError: Error/Failed to connect Game Center., nil '
            'delegate, OK',
    0xdfc0: 'UIAlertView(RB) +showNetworkErrorWithDelegate:: setTag 0 at 0xe03c before -show',
    0xe090: 'UIAlertView(RB) +showDownloadErrorWithDelegate:: cancelButtonTitle really is nil '
            '(x5=0), Close is the other button',
    0xe158: 'UIAlertView(RB) +showTakeoverMessage: Took over the data, nil delegate, Close',
    0xe1e4: 'UIAlertView(RB) +showInfomation: the location-service key has two newlines and '
            "single quotes",
    0xe270: 'UIAlertView(RB) +showMapWithTitle:delegate:: title is the parameter, Cancel/OK',
    0xe358: 'UIAlertView(RB) +showWithErrorMessage:delegate:: message is the parameter, OK only',
    0xe42c: 'UIAlertView(RB) +showConnectRetryWithErrorMessage:delegate:: OK cancel, Retry other',
    0xe514: 'UIAlertView(RB) +showConnectRetryOrCancel:: Close cancel, Retry other',
    0xe5e4: 'UIAlertView(RB) +showUnlockedMusicInfoWithDelegate:musicName:: format is '
            '"%@" has been added! at 0x1003cfde8, empty title literal',
    0xe6e8: 'UIAlertView(RB) +showSelectPurchaseLimitTypeWithDelegate:: three "%@ (%@)" buttons '
            'terminated by stp x26,xzr at 0xe83c; the third limit is 無制限',
    0xe93c: 'UIAlertView(RB) +showPurchaseOverMessageWithDelegate:: both Japanese literals, nil '
            'delegate, inline OK lookup',
    0xea50: 'UIAlertView(RB) +showUnlockTermsDescription2:: title from 0x1003cfdf0 at 0xeaec, '
            'message from -campaignTermsDescription',
    0xebc0: 'UIAlertView(RB) +showAlertUpdateForUnlock:: the AppStore button is the bare literal '
            'at 0x100361b20 (0xec68), not a bundle lookup',
    0xed10: 'UIAlertView(RB) +showAlertShortageOfPoint: Insufficient Points. with a full stop',
    0xee34: 'UIAlertView(RB) +showAlertLatestApplication:: -show then setTag 3 at 0xeed0',
    0xef18: 'UIAlertView(RB) +showDownloadWithDelegate:: -show then setTag 1 at 0xefb4',
    0xeffc: 'UIAlertView(RB) +showAlertNeedResourceUpdate:: -show then setTag 2 at 0xf0e8',
    0xf2e0: 'UIAlertView(RB) +showAlertNeedDownloadMusicNameList:: the Japanese literal is passed '
            'as the format itself, NO/YES',
    0xf3e4: 'UIAlertView(RB) +showColetteThemaUnlockMessage: localised string used as the format, '
            'no -show',
    0xf588: 'UIAlertView(RB) +showSerialcodeDialog:: nil title, inline Cancel and OK lookups, '
            'no -show',
    0xf764: 'UIAlertView(RB) +setExclusiveTouchForView:: fast enumeration, sets the flag then '
            'recurses at 0xf840',
    0xf8cc: 'UIAlertView(RB) +showPurchasePack:delegate:: stp x19,x19 at 0xf930 passes the '
            'requirement twice for %1$@ and %2$@',
    0xf9e0: 'UIAlertView(RB) +showMovePackDetailToExtendDetail:: empty title, NO/YES, no -show',
    0xfa84: 'UIAlertView(RB) +showAlertNotFoundMusics:: appends "\\n" then the name each pass '
            '(0xfb7c, 0xfb8c), cancel button is YES',
    0xfcb0: 'UIAlertView(RB) +showAlertUpdateErosionMark:: NSMutableString from the Japanese '
            'literal, NO/YES',
    # RBStoreManageViewController. Every non-ASCII literal in this file had been recovered wrongly
    # and two colour constants were the wrong component; see the fixes in the same change.
    0x1cddc0: 'RBStoreManageViewController -initWithParent: the sort button exists only when the '
              'version string contains "ja_" (rangeOfString: at 0x1ce010 against NSNotFound), and '
              'the right bar items branch three ways on which of the two buttons exist',
    0x1ce97c: 'RBStoreManageViewController -loadView autoresizing mask 0x12 from 0x310458, row '
              'height from the {50,60} table at 0x3107b0 indexed by the isPad ivar, popover only '
              'on the pad, then every navigation-bar subview made exclusive-touch',
    0x1cf0ec: 'RBStoreManageViewController -presentSortSelect:: phone pushes, pad toggles the '
              'popover and disables the left bar item, arrow direction 1 (up)',
    0x1cf2cc: 'RBStoreManageViewController -hideSortSelect:: both idiom arms, then re-enables',
    0x1cf3f4: 'RBStoreManageViewController -switchToSort:title:: a nil sortDict defers the switch '
              'behind the download prompt, otherwise the whole list is re-sorted and the '
              'not-found names are alerted then cleared',
    0x1cf77c: 'RBStoreManageViewController -SelectSort toggles between the two sort titles at '
              '0x36ec40 and 0x36ec60, reloading on either match',
    0x1cf9ec: 'RBStoreManageViewController -getSortedDictionary:row:: the collated orders unwrap '
              'an RBManageSortData, the download orders return the entry itself (b.hi at 0x1cfa44)',
    # Both collation arms test a_yomi for the misc re-bucket, even the title arm which collates on
    # m_yomi: 0x1d0484 selects m_yomi, 0x1d0494 still queries a_yomi.
    0x1cfb48: 'RBStoreManageViewController -sortList: four arms, 26 leading collation sections '
              'dropped at 0x1d0a30, section 0x24 shifted one earlier when a_yomi is non-empty',
    0x1d1080: 'RBStoreManageViewController -goToTop:: scrollRectToVisible: with the unit square, '
              'animated, and only when the table exists',
    0x1d1130: 'RBStoreManageViewController -toggleOpen:: eor #1 at 0x1d1198, row animation 0x64',
    0x1d1280: 'RBStoreManageViewController -tableView:heightForHeaderInSection:: 30 on the pad, 25 '
              'on the phone, and 0 for an empty or uncollated section',
    0x1d1364: 'RBStoreManageViewController -tableView:viewForHeaderInSection:: the expanded glyph '
              'is the plain triangle at 0x36eba0, the collapsed one the U+FE0E form at 0x36ed20',
    0x1d15b4: 'RBStoreManageViewController -tableView:titleForHeaderInSection:: nil unless '
              'collated and the section is non-empty',
    0x1d16dc: 'RBStoreManageViewController -sectionIndexTitlesForTableView:: nil below sort 2',
    0x1d172c: 'RBStoreManageViewController -tableView:sectionForSectionIndexTitle:atIndex:: csel '
              'at 0x1d174c returns 0 below sort 2, else the index unchanged',
    # The action button is right-aligned: x is cellWidth - buttonWidth - inset and y centres it,
    # from the fsub/fmul at 0x1d1f94 and 0x1d1f9c. The inset is the fmov -10.0 at 0x1d1f30 in
    # download order, else the index-bar width (40 on the pad from 0x2ee950, 25 on the phone).
    0x1d175c: 'RBStoreManageViewController -tableView:cellForRowAtIndexPath:: button frame, fonts '
              'by idiom, and the title label white 50/255 from 0x2eeef8',
    0x1d2220: 'RBStoreManageViewController -tableView:numberOfRowsInSection:: 0 when collapsed',
    0x1d22e8: 'RBStoreManageViewController -tableView:willDisplayCell:forRowAtIndexPath:: tbnz on '
              'bit 0 of the row, even rows 193/255 from 0x310790, odd the 0.8 at 0x2ec6a0',
    0x1d2434: 'RBStoreManageViewController -numberOfSectionsInTableView:: 1 below sort 2',
    # The tag packs section and row: the smulh/asr pair at 0x1d252c is the division by the
    # 1000000 built by the mov/movk at 0x1d2514, and 0x1d2554 is the matching remainder.
    0x1d24bc: 'RBStoreManageViewController -pushCellButton:: the same purchased path is tested '
              'twice at 0x1d2600 and 0x1d2640, and the modal dialog is laid out before its '
              'message is set, with layout:NO rather than layoutIfNeeded',
    0x1d2ab8: 'RBStoreManageViewController -startDownloadMusic queues the tune task then one per '
              'purchased extend note, then starts the manager',
    0x1d2fc4: 'RBStoreManageViewController -popoverControllerDidDismissPopover: re-enables the '
              'left bar item',
    0x1d3058: 'RBStoreManageViewController -downloaderFinished:: the info arm registers the tune '
              'and its notes, the sort arm normalises both readings to yomigana and re-enters '
              '-switchToSort:title: with the deferred index',
    0x1d39e0: 'RBStoreManageViewController -downloaderError:: the info arm still starts the '
              'download, the sort arm alerts instead',
    0x1d3b10: 'RBStoreManageViewController -storeDialogCancel:: the info downloader is cleared '
              'after cancelling, the download manager is not',
    0x1d3c5c: 'RBStoreManageViewController -alertView:clickedButtonAtIndex:: the delete arm needs '
              'only button 1, the download arm needs button 1 and the matching alert',
    0x1d414c: 'RBStoreManageViewController -alertView:didDismissWithButtonIndex: clears both '
              'working indices to -1',
    0x1d416c: 'RBStoreManageViewController -alertView:willDismissWithButtonIndex: the same',
    0x1d418c: 'RBStoreManageViewController -alertViewCancel: the same',
    0x1d41ac: 'RBStoreManageViewController -didPresentAlertView: walks keyWindow to the presented '
              "controller's view and makes it exclusive-touch",
    0x1d42ec: 'RBStoreManageViewController -downloadManagerCompleted: rebuilds the tune array and '
              'marks it dirty before clearing the working indices',
    0x1d4494: 'RBStoreManageViewController -downloadManagerFailed: alerts with a nil delegate',
    0x1d454c: 'RBStoreManageViewController -downloadManagerProceed: forwards overallProgress',
    0x1d4664: 'RBStoreManageViewController -viewWillAppear: re-sorts only when the purchased count '
              'differs from latestArrayCount',
    0x1d47f8: 'RBStoreManageViewController -viewDidAppear: reloads then flashes the indicators',
    0x1d48c0: 'RBStoreManageViewController -dealloc clears the alert and table delegates, cancels '
              'both downloaders, and removes the view',
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
