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
    # Read in full against the disassembly, including the parts most likely to go wrong: the
    # negative fmov at 0x3245c (word 0x1e7e1001, imm8 0xf0, so -1.0 and not the -4.0 the printed
    # form suggests), the unsigned range trick at 0x32494 that selects RGBA for alphaInfo 1..4,
    # and the zero-initialised RGBA allocation against the uninitialised RGB one. The types string
    # ends f24, so the scale really is float rather than the double the header first declared.
    # 0x32320 was keyed twice. The other entry, further down, carries the full decode evidence
    # including the f24 scale, so this shorter duplicate is removed rather than merged.
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
    # A batch of short bodies read end to end, every instruction accounted for. The ivar each one
    # reaches was resolved through its _OBJC_IVAR_$_ offset variable into the class's ivar list, so
    # the name and width are the binary's own, not inferred from the reconstruction.
    0xc2d8: 'StoreButtonView -cornerRadius: one ldr d0 of _cornerRadius, whose ivar type is d',
    0xc2e8: 'StoreButtonView -setCornerRadius:: str d0 into _cornerRadius, then a tail call to '
            'setNeedsDisplay',
    0x17a54: 'SePlayer -sePlay: loads the soundSource ivar (type I) and tail-calls alSourcePlay',
    0x20afc: 'RBPastelManager -allReset: str wzr is a 32-bit store covering the whole four-byte '
             'currentShowList, so every stage is cleared, not just the leading one',
    0x2653c: 'StoreExtendNoteDetailViewPad -getArtworkMargin:: the fmov immediates 0x4028.. and '
             '0x4024.. are 12.0 and 10.0, and the BOOL argument is never read',
    0x26548: 'StoreExtendNoteDetailViewPad -getItemSize:: the pool loads at 0x2eec30 and 0x2eec38 '
             'are 650.0 and 284.0, and the BOOL argument is never read',
    0x34b30: 'SoundData -format: add, not ldr, so it returns the address of m_Format',
    0x354fc: 'SoundPlayer -getSoundData: loads m_SoundData and tail-calls the autorelease helper',
    0x3557c: 'SoundPlayer -currentFrame: loads m_CurrentFrame, whose ivar type q is the long long '
             'the declaration uses',
    # SoundPlayer's transport flags are three separate B ivars, m_IsPlaying (+0x364), m_IsLoop
    # (+0x370) and m_IsStop (+0x374); each method below moves exactly the ones named.
    0x3558c: 'SoundPlayer -setLoop:: the cbnz on m_IsPlaying returns without storing, so the loop '
             'flag is ignored while playing',
    0x355ac: 'SoundPlayer -isLoop: one ldrb of m_IsLoop',
    0x355bc: 'SoundPlayer -play: sets m_IsPlaying to 1 and clears m_IsStop, both in this order',
    0x355dc: 'SoundPlayer -isPlaying: one ldrb of m_IsPlaying',
    0x355ec: 'SoundPlayer -endPlay: clears m_IsPlaying only, leaving m_IsStop alone',
    0x355fc: 'SoundPlayer -stop: sets m_IsStop only, leaving m_IsPlaying alone',
    0x35610: 'SoundPlayer -isStop: one ldrb of m_IsStop',
    0x39e10: 'neGLView +GetInstance: a bare load of the g_pGLView global at 0x3dc290, with no lazy '
             'construction',
    0x39e1c: 'neGLView +layerClass: returns the CAEAGLLayer class object',
    0x3a448: 'neGLView -GetFrontBufferWidth: loads m_FrontBufferWidth, ivar type i',
    0x3a458: 'neGLView -GetFrontBufferHeight: loads m_FrontBufferHeight, ivar type i',
    0x41d04: 'AVBus -status: loads mStatus, ivar type i',
    0x41d14: 'AVBus -audioPlayerDidFinishPlaying:successfully:: stores the literal 4 into mStatus, '
             'which is AVBusStatusStopped, and reads neither argument',
    0x41f38: 'AVBus -currentID: ldrh, matching the S (unsigned short) ivar mCurrentID',
    0x41f20: 'AVBus -isSameSource:: cmp of the mSource pointer against the argument and a cset eq, '
             'so the comparison is by identity',
    0x6a980: 'RBBGMManager -isPushMusic: one ldrb of m_IsPushMusic, whose name the ivar list gives '
             'as m_IsPushMusic (the reconstruction had spelled it fIsPushMusic, as it had '
             'm_IsMusic)',
    # MusicDataFromDoc's eight image-data getters each forward with a fixed scale and luminance
    # pair; the fmov immediates 0x40000000 and 0x3f800000 are 2.0 and 1.0, and the 1x forms copy
    # v0 into v1 rather than materialising 1.0 twice.
    0x67944: 'MusicDataFromDoc -musicNameImageWhite2xData: forwards with scale 2.0, luminance 1.0',
    0x67958: 'MusicDataFromDoc -musicNameImageWhiteData: forwards with scale 1.0, luminance 1.0',
    0x67c0c: 'MusicDataFromDoc -artistNameImageWhite2xData: the artist counterpart, scale 2.0',
    0x87930: 'TwitterImageCreater -setScore:Side:: b.ls on the side takes the store only for 0 and '
             '1, matching the two-element m_Score ivar, and the score stays in x2 for the '
             'setScore: tail call',
    0x87958: 'TwitterImageCreater -setAR:Side:: the same guard, one register earlier because the '
             'rate travels in s0, tail-calling setAr:',
    # The remaining six figure setters share -setScore:Side:'s shape exactly; only the forwarded
    # selector differs, and each was resolved from its own adrp page (0x3c1000) rather than assumed.
    0x87980: 'TwitterImageCreater -setJustNum:Side:: forwards setJustNum: (0x3c15f0)',
    0x879a8: 'TwitterImageCreater -setGreatNum:Side:: forwards setGreatNum: (0x3c15f8)',
    0x879d0: 'TwitterImageCreater -setGoodNum:Side:: forwards setGoodNum: (0x3c1600)',
    0x879f8: 'TwitterImageCreater -setMissNum:Side:: forwards setMissNum: (0x3c1608)',
    0x87a20: 'TwitterImageCreater -setJustReflecNum:Side:: forwards setJustReflecNum: (0x3c1610)',
    0x87a48: 'TwitterImageCreater -setMaxComboNum:Side:: forwards setMaxComboNum: (0x3c1618)',
    0x6796c: 'MusicDataFromDoc -musicNameImageBlack2xData: forwards with scale 2.0, luminance 0.0',
    0x67980: 'MusicDataFromDoc -musicNameImageBlackData: forwards with scale 1.0, luminance 0.0',
    0x67c20: 'MusicDataFromDoc -artistNameImageWhiteData: scale 1.0, luminance 1.0, the 1.0 copied '
             'from v0 into v1 rather than materialised twice',
    0x67c34: 'MusicDataFromDoc -artistNameImageBlack2xData: scale 2.0, luminance 0.0',
    0x67c48: 'MusicDataFromDoc -artistNameImageBlackData: scale 1.0, luminance 0.0',
    # Verified here after two subagent rewrites of it were reverted for inventing a weak-reference
    # pattern: the method calls no weak-reference helper and no assert function at all.
    0x1a6d00: 'RBMusicOtherView -updateSwitchWithType:: the jump table at 0x1a7330 maps the four '
              'switch types onto vsPastel, ghostStyle, fullJustReflec and userFullCombo in that '
              'order; the ghost arm branches on ghostStyle == 1 directly rather than materialising '
              'a boolean (cmp at 0x1a6f4c); the shared tail at 0x1a7150 picks the on or off knob '
              'animation, both at the 0.2 of g_dMascotMessageAnimDuration',
    0xd934: 'RBMenuBGEffectPartView -removeFromSuperview: chains to super and does nothing else',
    0xe8894: 'RBMenuBGEffectView -removeFromSuperview: the same lone super chain',
    0x3d080: 'neWindow -initWithFrame:: chains to super and returns it, adding nothing',
    0xd8f98: 'RBPopoverBackgroundView -horizontalInsetsForStretchedImage:insets:: returns {top, '
             'width - 0.4375, bottom, 9.0}; the shrink is the fmov immediate whose bit pattern is '
             '0xbfdc000000000000, not a whole point',
    0xd8fdc: 'RBPopoverBackgroundView -verticalInsetsForStretchedImage:insets:: the transpose of '
             'it, {height - 0.4375, left, 9.0, right}',
    0x14d40: 'UnZipArchive -init: chains to super and clears m_ZipFile only when that returned '
             'non-nil',
    # The three getInstance accessors share one shape: a load of the slot, a cbnz that returns it,
    # and otherwise alloc/init, store, release the previous value. No dispatch_once, no
    # @synchronized, so the reconstruction's plain nil check is the faithful spelling.
    0x6a990: 'RBMusicManager +getInstance: the fifth accessor sharing the plain nil-check shape',
    0x67238: 'MusicDataFromDoc -init: chains to the MusicData initialiser and adds nothing',
    0x73728: 'Downloader -hashChecked: forwards to the conn RBHttpUtil, not to an ivar of its own',
    0x9e4e8: 'RBMenuButton -setEnabled:: forwards the flag to the wrapped button, tail-call release',
    0x9c404: 'RBCampaignData +sharedInstance: the plain nil check again, no once token or lock',
    0x68924: 'StorePackInfo -initWithPackID:: super init, nil check, then the packID setter',
    0xcbd84: 'RBMusicView -dealloc: settingScroll.layer removeAllAnimations and nothing else',
    0x1ad424: 'RBTutorialPastel -getClipList:: indexes the 0x3df3e0 table at a 32-byte CGRect '
              'stride, ldp giving x and y then width and height, scales each by the 0.5 fmov, and '
              'four fcsel on IsPad take the raw row on the pad and the halved one otherwise. '
              'Field order is preserved with no transposition',
    0x1b356c: 'RBTutorialPastelLayer -getClipList:: instruction-identical to the RBTutorialPastel '
              'one and reading the same table, checked separately',
    0x1c0750: 'RBMenuPageSliderView -reset:currentPage:: forwards both arguments to the slider',
    0x1c09b0: 'RBMenuPageSliderView -hideAnimation: detaches the slider\'s delegate before '
              'chaining to super, so a hide in flight cannot call back',
    0x1bd624: 'RBApplilinkView -initWithFrame:: the mov w2 of 8 is the Applilink popup type, then '
              'setupView, then hideAnimating cleared',
    0x1bff4c: 'RBMenuPageSlider -continueTrackingWithTouch:withEvent:: takes the point in the '
              'touch\'s own view and calls sliderChangeWithTouchPoint:isEnd: with the mov w2 of 0. '
              'This class uses the two-argument selector where the other three sliders use the '
              'one-argument form, so its trio is not the same family',
    0x1bac10: 'RBExperienceData -addBackgroundType:: appends to backgroundItems',
    0x1bacb4: 'RBExperienceData -addMusicID:: appends to musicItems',
    0x1bad58: 'RBExperienceData -addThemaID:: appends to themaItems; the seven add methods all '
              'share a body and differ only in the collection, so each was matched to its own '
              'ivar selector rather than the family taken from one',
    0x1c0578: 'RBMenuPageSliderView -willRotate: hides the slider with a movi of zero and then '
              'sets animating, so the flag is raised after the alpha rather than before',
    0x1baac8: 'RBExperienceData -addExprosionType:: appends to explosionItems; the selector keeps '
              'the binary\'s misspelling while the ivar it targets is spelled correctly, and both '
              'come from the metadata',
    0x1bab6c: 'RBExperienceData -addFrameType:: the same over frameItems',
    0x194284: 'RBUnlockView -initWithFrame:: super, nil check, setupView, and no popup type set',
    0x19ebfc: 'RBMusicMenuPopupView -initWithFrame:: the base class sets type 0, HowTo, and '
              'exclusiveTouch YES, but calls no setupView; each subclass supplies its own',
    0x1ba980: 'RBExperienceData -addBGMType:: boxes the int and appends it to bgmItems',
    0x1baa24: 'RBExperienceData -addShotType:: the same over shotItems',
    0x19e5b0: 'RBCharacterBase -init: super init, nil check, then setDefault',
    0x1973c0: 'RBUnlockView -pushRewardButton:: forwards the sender to parentCustomView '
              'toRewardList:, so the reward list is opened by the parent rather than by itself',
    0x1932b8: 'RBNotificationPageView -initWithFrame:: the Information type and setupView sit '
              'inside the nil check, but setIsFirstRequest: with a mov w2 of 1 is sent after the '
              'branch rejoins, so it runs even on a nil self as a no-op send. The reconstruction '
              'places it outside the if and says why',
    0x19ab70: 'RBUnlockData +sharedInstance: the plain nil check again, no once token or lock',
    0x1988c4: 'RBUnlockView -noButtonTap:: themed effect 4, kSoundEffectPopupCancel, then hides '
              'the popup view rather than itself',
    0x19991c: 'RBUnlockView -downloadManagerProceed:: pipes the manager\'s overallProgress into '
              'progressOverlayView',
    0x1940dc: 'RBNotificationPageView -alertView:clickedButtonAtIndex:: clears animating and '
              'hides, but unlike the term views does not nil the alert view\'s delegate',
    0x1903b0: 'RBUnlockCollectionCell -setEnabled:: stores the flag, then an fcsel picks 0.0 when '
              'enabled and the 0.6 pool load otherwise for the disable overlay, and mirrors the '
              'flag onto userInteractionEnabled',
    0x1837f8: 'RBExtendNoteManager -getExtendNoteDataArray: rebuilds on nil or the dirty flag, the '
              'extend-note twin of the music manager accessor',
    0x193a68: 'RBNotificationPageView -hideAnimation: chains to super only while NOT animating, '
              'which is the inverse of the usual guard and is what the binary tests',
    0x193120: 'RBNotificationPagePhoneViewController -webViewDidStartLoad:: empties the shared '
              'URL cache',
    0x193184: 'RBNotificationPagePhoneViewController -webViewDidFinishLoad:: clears isFirstRequest '
              'then injects the script at 0x36c920, which decodes to the webkitTouchCallout none '
              'assignment and matches the declared constant',
    0x194000: 'RBNotificationPageView -webViewDidStartLoad:: the same cache purge, read separately',
    0x194064: 'RBNotificationPageView -webViewDidFinishLoad:: the same clear and the same injected '
              'script, from the same CFString the phone controller uses',
    0x17f6dc: 'RBTimingSlider -endTrackingWithTouch:withEvent:: completes the third slider trio, '
              'void where the other two return YES',
    0x18ddc4: 'RBUnlockCollectionView -collectionView:didHighlightItemAtIndexPath:: looks the cell '
              'up on the passed collection view and sets highlighted',
    0x18de50: 'RBUnlockCollectionView -collectionView:didUnhighlightItemAtIndexPath:: the mirror, '
              'with a mov w2 of 0',
    0x18f6b4: 'RBPushNotificationView -stopTimer: guards only the invalidate; the clear runs '
              'unconditionally, which the reconstruction has and a single if would not',
    0x178ff0: 'StoreExtendNoteInfo -extFileExist: asks NSFileManager about the purchased path for '
              'its own pid, so it reports the extend-note file rather than the pack file',
    0x17dc08: 'RBServerAPIManager -downloaderFinished:: identical to its downloaderError:, '
              'cancelling the passed downloader and dropping it from httpArray',
    0x17f594: 'RBTimingSlider -beginTrackingWithTouch:withEvent:: the third slider class with the '
              'same tracking shape, taking the point in the touch\'s own view',
    0x17f638: 'RBTimingSlider -continueTrackingWithTouch:withEvent:: likewise, returning YES',
    0x1786d8: 'StoreExtendNoteInfo -initWithExtendNoteID:: super init, nil check, then the pid '
              'setter, whose name differs from the parameter\'s',
    0x179bc0: 'StoreExtendNoteInfoDownloader -initWithStoreExtendNoteInfo:: super init, nil check, '
              'then extendNoteInfo',
    0x179e44: 'StoreExtendNoteInfoDownloader -cancel: cancels the downloader and clears it, both '
              'guarded on one being held',
    0x17dca4: 'RBServerAPIManager -downloaderError:: cancels the passed downloader and drops it '
              'from httpArray, so the receiver of cancel is the argument rather than self',
    0x171d30: 'RBTermPhoneViewController -alertView:clickedButtonAtIndex:: on isFirstRequest it '
              'nils the alert view\'s own delegate, not its own, then forceClose',
    0x172ffc: 'RBWebView -uiWebView:resource:willSendRequest:redirectResponse:fromDataSource:: '
              'stamps the device description onto the request under the CFString at 0x363fc0, '
              'which decodes to "User-Agent", and returns the request',
    0x34310: 'SoundData -initWithContentsFileName:Stream:: super init, nil check, then '
             'prepare:Stream: with both arguments forwarded',
    0x16f154: 'RBVolumeSlider -continueTrackingWithTouch:withEvent:: same as its begin form, '
              'returning YES',
    0x16f1f8: 'RBVolumeSlider -endTrackingWithTouch:withEvent:: the same point handling but void, '
              'so the trio matches RBEffectSizeSlider\'s exactly',
    0x174754: 'RBMusicSearchExpander -init: super init, nil check, then loadDictionary',
    0x1747c8: 'RBMusicSearchExpander -getDictionary: hands back a copy through '
              'dictionaryWithDictionary: rather than the expandDict ivar itself',
    0x177ac0: 'StoreTableCellViewBase -setBgImage:: drives backGroundImageView.image',
    0x1687dc: 'RBCustomSelectView -initWithFrame:: super, nil check, setupView, no type set',
    0x169828: 'RBCustomSelectView -prevButtonTap:: startPreview on the app delegate\'s view '
              'controller, then themed effect 1, in that order',
    0x16f0b0: 'RBVolumeSlider -beginTrackingWithTouch:withEvent:: the same shape as '
              'RBEffectSizeSlider\'s, taking the point in the touch\'s own view and returning YES',
    0x142a00: 'RBErosionMarkUpdaterAlertController -init: an IsPad branch on the orientation mask. '
              'The pad takes the orr w2 of 6, Portrait with PortraitUpsideDown, and every other '
              'idiom takes 0x1e, which is MaskAll',
    0x1591b4: 'RBCustomSelectCollectionView -collectionView:didUnhighlightItemAtIndexPath:: the '
              'mirror of the highlight form with a mov w2 of 0',
    0x16e77c: 'RBCustomSelectCollectionCell -setHighlighted:: chains to super then mirrors the '
              'flag onto itemButton',
    0x16ea10: 'RBCustomSelectCollectionCell -prepareForReuse: super, clears the button image for '
              'the normal state, then clears the selected flag',
    0x159128: 'RBCustomSelectCollectionView -collectionView:didHighlightItemAtIndexPath:: looks '
              'the cell up on the passed collection view and sets highlighted with the mov w2 of 1',
    0x1555d8: 'RBCustomSelectCollectionView -initWithFrame:customizeType:: super with the rect, '
              'nil check, the type, then setupView, so the type is in place before the layout runs',
    0x142a98: 'RBErosionMarkUpdaterAlertController -initWithOrientationMask:: super init, nil '
              'check, then the mask; the plain -init beside it takes the same shape',
    0x154cb4: 'DAProgressOverlayView -displayOperationDidFinishAnimation: setState: with the mov '
              'w2 of 2, which is OperationFinished, zeroes the progress, and schedules the update '
              'timer with the mov w5 of 1 for repeats YES',
    0x154d48: 'DAProgressOverlayView -displayOperationWillTriggerAnimation: the same shape with a '
              'mov w2 of 0, Waiting, so the two differ only in the state they enter',
    0x155130: 'DAProgressOverlayView -setProgress:: acts only on a change, clamps into [0, 1], '
              'takes state 1 while strictly between the bounds, and at exactly 1 fires the finish '
              'animation only when triggersDownloadDidFinishAnimationAutomatically is set',
    0x107104: 'RBThemaView -initWithFrame:: the mov w2 of 2 is RBMusicMenuPopupViewTypeTheme, then '
              'setupView, then exclusiveTouch YES, which the sibling popups do not set',
    0x10cfa4: 'RBRewardListView -initWithFrame:: super, nil check, setupView, and no type set',
    0x101898: 'StorePromotionView -imageDownloaderDidFail:didLoad:: sends removeObject: to its '
              'imageDownloader, so that property is a collection here where the same name is a '
              'single downloader in the sibling store views',
    0x13d878: 'RBMenuTutorialView -stopCursorAnimation:: hides the passed view\'s cursorView, but '
              'only when one is held',
    0x13dbc4: 'RBMenuTutorialView -stopTouchAnimation:: hides its own touchView and stops it '
              'animating, with no nil guard, unlike the cursor form beside it. Both asymmetries '
              'are real and each was read rather than assumed from its sibling',
    0x1147bc: 'RBTermView -alertView:clickedButtonAtIndex:: on isFirstRequest it clears animating, '
              'nils the alert view\'s own delegate rather than its own, then hides',
    0x109b10: 'StoreCampaignItemInfo +getButtonName:: a six-arm jump table at 0x109ba0 with a nil '
              'default above 5. Every arm was decoded and its CFString read as UTF-16 with the '
              'record length in characters: download, downloaded, unlock-condition, update, '
              'serial-input, and point-unlocked, in that order, matching the declared constants '
              'case for case. Arm order is what a jump table transposes, so it was not sampled',
    0x103048: 'StorePromotionView -stopAnimation: invalidates and clears the timer when one is set',
    0x105290: 'ReplayData -init: super init, nil check, then reset',
    0x1071a8: 'RBThemaView -layoutSubviews: super, then feeds its own scrollView back through '
              'scrollViewDidScroll: to re-run the paging maths after a bounds change',
    0xeb0e4: 'RBSettingView -OpenView: a genuine three-arm theme branch. Themes 2 and 1 share the '
             'orr w1 of 0xc, theme 0 takes the orr of 3, and any other theme plays nothing at all '
             'because the cbnz skips the call entirely; showAnimation then runs unconditionally. '
             'The reconstruction\'s else-if captures that silent third case',
    0xef940: 'StoreDetailMusicCell -sampleStop: stops the indicator and hides sampleView with the '
             'mov w2 of 1',
    0xefbc4: 'StoreDetailMusicCell -tapSp:: builds the move-to-extend-detail alert with self as '
             'delegate and shows it, the same shape as StorePackMusicView -tapSp',
    0xf3e90: 'StoreImageView -loadedImage: whether imageView.image is non-nil',
    0xf5898: 'StorePackCell -setBgImage:: drives bgView.image',
    0xfe9e0: 'StorePackView -setBgImage:: same selector as StorePackCell\'s but a different ivar, '
             'backGroundImageView, which is why the two were read separately',
    0xfea6c: 'StorePackView -setArtwork:: drives artworkImageView.image',
    0xd9120: 'RBPopoverBackgroundView -imageFromImageContextWithSourceImage:size:: begins a context '
             'with the mov w0 of 0 for opaque NO, draws into a rect at the origin, then gets the '
             'image and ends the context, in that order',
    0xe9dac: 'RBSettingView -initWithFrame:ButtonFrame:: super with the first rect, nil check, '
             'then setupView: with the second',
    0xebf94: 'RBSettingView -SelectTermButton: themed effect 1, parentView showTermView, then its '
             'own hideAnimation, the same three-step shape as its SelectInfoButton sibling',
    0xec0e0: 'RBSettingView -selectMap:: the same shape again over showSearchView, ignoring sender',
    0xef784: 'StoreDetailMusicCell -setBgImage:: drives bgView.image and keeps no ivar of its own',
    0xe8fa8: 'RBSettingMenuButton -initWithFilename:: super init, nil check, then setupView: with '
             'the argument passed straight through',
    0xc62c8: 'RBMusicColorView -SelectButton:: acts only when the tag differs from the current '
             'colour, then ShowSelect and themed effect 1, matching kSoundEffectSelect',
    0xd8e38: 'RBPopoverBackgroundView -contextSizeForFirstHalfImage:: a CGSize through the '
             'soft-float shuffle, so the pairing was checked rather than assumed. v9 takes v0 as '
             'the width and v10 takes v1 as the height, and the two fcsel give {stretch, height} '
             'when an up or down arrow is wanted and {width, stretch} otherwise. No transposition',
    0xd5ca4: 'RBMusicView -ReplayMusic: the same retry shape as the RBMenuView method of that name '
             'but a different delay. Its pool slot 0x2eedc0 holds 0.20000000298023224, which is '
             '0.2f widened, so this one uses g_dMascotMessageAnimDuration where the other uses '
             'g_dMascotMoveAnimDuration; the reconstruction picks the right global for each',
    0xd65dc: 'RBMusicView -setScrollable:: enables the scroll view and hides the page control on '
             'the inverted flag',
    0xb5d54: 'RBMenuView -closeTutorial: removes and clears tutorialView when one is held',
    0xe6300: 'RBSearchMapViewController -pushCurrent:: looks the map up by the mov w2 tag of '
             '0x23d and toggles tracking only when it is found',
    0xaaa20: 'RBMenuView -ReplayMusic: retries on the next turn when PlayMusic: with the 1.5f '
             'fmov returns false. The delay pool slot at 0x2ec6a8 holds 0.10000000149011612, which '
             'is 0.1f widened rather than the true double 0.1, so the f suffix on '
             'g_dMascotMoveAnimDuration is load-bearing and must not be tidied away',
    0xb21e4: 'RBMenuView -handleLongPressGesture:: requires neither tutorial to be running and the '
             'cmp x0 of 1, UIGestureRecognizerStateBegan, before starting playlist editing',
    0x83d30: 'ImageDownloader -initWithGetURL:unUseRetina:: super init, nil check, then the retina '
             'flag before the URL, in that order',
    0xb5c0c: 'RBMenuView -setPastelForTutorialStart: two movi of zero, so both the mascot and the '
             'search mascot are hidden',
    0xb5cb0: 'RBMenuView -setPastelForTutorialEnd: a movi of zero then an fmov of 1.0, so the '
             'mascot stays hidden while the search mascot is shown; the asymmetry is real and the '
             'reconstruction already flags it',
    0xab7ac: 'RBMenuView -releaseSelectMusic: removes and clears selectedView when one is held, '
             'then showInfomation unconditionally, keeping the binary\'s misspelling',
    0xaf2a8: 'RBMenuView -startNewsFromTimer: invalidates and clears newsBannerTimer when set, '
             'then startNews unconditionally',
    0x3bf70: 'RBEffectSizeSlider -continueTrackingWithTouch:withEvent:: the third of the tracking '
             'trio, identical to the begin form and likewise returning YES',
    0x6a70c: 'RBBGMManager -LoadMusic:Loop:: sets m_IsMusic with a mov w9 of 1 before handing the '
             'data to AudioManager loadBgmData:isLoop:',
    0x35620: 'SoundPlayer -loadData:Frames:: guarded on m_SoundData, reads the frame cursor and '
             'm_IsLoop into the getData: call with an out-parameter, stops when it reports '
             'exhaustion, and stores the returned cursor back. The mov w3,w3 zero-extends the '
             'frame count, matching its unsigned int spelling',
    0x41964: 'AVBus -stop: NO when no player is bound, else stops it, writes the mov w9 of 4 into '
             'mStatus, which is AVBusStatusStopped, and returns YES',
    0x41bc0: 'AVBus -setVolume:: NO when no player is bound, else forwards and returns YES',
    0x72fa8: 'Downloader -cancel: nils its own delegate first, then cancels conn if one is held',
    0x3becc: 'RBEffectSizeSlider -beginTrackingWithTouch:withEvent:: same shape as its end form, '
             'taking the point in the touch\'s own view, and returns YES to keep tracking',
    0x71654: 'RBPlaylistManager -synchronize: writeToFile:atomically: with the mov w3 of 1, so '
             'the playlist array is written atomically',
    0x6a7b4: 'RBBGMManager -LoadMusicWithPush:Loop:: pops only when m_IsPushMusic is already set, '
             'then pushes, loads, and returns the flag as it stands afterwards',
    0x6cc80: 'RBMusicManager -releaseClientMusic: sixteen bytes, a mov w2 of 0 and a tail branch '
             'to setClientMusicPageNum:, so it is exactly that send and nothing else',
    0x6cc90: 'RBMusicManager -setClientMusicPageNum:: sends releaseClientMusic then its own '
             'selector to self, so the pair recurse until the stack is exhausted. The '
             'reconstruction now stores directly AND drops the release send; the earlier fix '
             'removed only the self-send and left the mutual cycle intact. Twenty entries per page',
    0x1840c0: 'RBExtendNoteManager -releaseClientMusic: the same sixteen-byte '
              '[self setClientMusicPageNum:0] as its music-manager twin',
    0x1840d0: 'RBExtendNoteManager -setClientMusicPageNum:: the same mutual recursion, but its '
              'third send stores through setClientExtendNotePageNum:, a differently-named '
              'property, which is what makes the music-manager version look like a copy-paste '
              'slip. The reconstruction had reproduced the cycle faithfully and now carries the '
              'same fix',
    0x6a854: 'RBBGMManager -pushMusic: returns the entry value of m_IsMusic and, when set, pushes '
             'the BGM then flips m_IsPushMusic on and m_IsMusic off',
    0x6c6b8: 'RBMusicManager -getMusicDataArray: rebuilds when the array is nil or the dirty flag '
             'is set, then returns it',
    0x7193c: 'RBPlaylistManager -indexOfPlaylist:: indexOfObjectIdenticalTo: on arrayPlaylist, so '
             'it matches by pointer identity rather than by isEqual:',
    0xfd100: 'StorePackMusicView -setBG:: clamps the index to [0, 1] with signed tests, indexes '
             'the name table at 0x35b388, stretches with caps of 4 on both axes, and assigns to '
             'bg.image. The signed clamp is why the parameter is an int rather than a BOOL',
    0xfce3c: 'StorePackMusicView -sampleStop: stops indicatorSample, then sets the idle artwork on '
             'buttonSample for state 0, UIControlStateNormal',
    0x2ab60: 'StringConvert +stringTransform:withTransform:reverse:: copies into an NSMutableString '
             'and calls CFStringTransform over the whole string, the x1 range being NULL. Its '
             'reverse flag encodes C, CoreFoundation\'s Boolean, not the signed-char BOOL',
    0x2a88c: 'StringConvert +convertKorsk:: returns the input unchanged when nil or empty, else '
             'one stringByReplacingOccurrencesOfString:withString: over the pair at 0x362d40',
    0x36e0c: 'RBHttpUtil -initWithPostURL:post:contentType:: forwards with a single-precision '
             'fmov of 15.0; the four-argument form encodes its timeout f, not d, so the default '
             'constant is retyped from NSTimeInterval to float',
    0x41c64: 'AVBus -volume: returns the fmov immediate 1.0 when no player is bound, decoded from '
             'the instruction word and matching kUnboundVoiceVolume, else the player\'s volume',
    0x36308: 'RBTutorialManager +getUnlockedItemInfo: getInstance, then a copy of unlockItemInfo',
    0x39d1c: 'RBNotificationData -encodeWithCoder:: archives notificationDict under the CFString '
             'at 0x3640c0, which decodes to "notificationList" and matches the declared key',
    0x3c014: 'RBEffectSizeSlider -endTrackingWithTouch:withEvent:: takes the touch point in the '
             'touch\'s own view, not the slider, and feeds it to sliderChangeWithTouchPoint:',
    0xdda2c: 'RBRankingView -initWithFrame:: the mov w2 of 5 is RBMusicMenuPopupViewTypeRanking',
    0xe650c: 'RBSearchView -initWithFrame:: the mov w2 of 4 is RBMusicMenuPopupViewTypeSearch; it '
             'reaches the setter through dot syntax where its sibling uses the message form, '
             'which compiles to the same send',
    0xb0e18: 'RBMenuView -setSearchBarNonActive: resigns the search bar only when one is held',
    0xc0768: 'RBStoreExtendNoteList -downloaderError:: reports through the delegate with the '
             'server-connect-failed string, then clears extendNotelistDownloader',
    0xdcf90: 'RBRankingTableView -tableView:willDisplayCell:forRowAtIndexPath:: the receiver of '
             'setBackgroundColor: is x3, the cell, not the table view; the colour is clearColor',
    0xe6598: 'RBSearchView -showAnimation: chains to super, then sends initialView to the map',
    0x6a8f0: 'RBBGMManager -popMusic: returns the entry value of m_IsPushMusic, and when it was '
             'set clears it with strb wzr, sets m_IsMusic with a mov w9 of 1, and pops the BGM',
    0xab9e0: 'RBMenuView -hideSettingView: sends hideAnimation only when settingView is held',
    0x87d40: 'TwitterImageCreater -drawImageFileName:X:Y:: passes the two ints straight through '
             'with m_Scale, the f-encoded ivar, unlike the Position: form which truncates first',
    0x69880: 'StorePackInfoDownloader -cancel: cancels the downloader and clears it, both guarded '
             'on one being held',
    0x69fac: 'RBBGMManager -PlayMusic:: NO when m_IsMusic is clear, else AudioManager playBgm:',
    0x6a324: 'RBBGMManager -LoadMusicSelect: RelaseMusic, keeping the binary\'s own misspelling, '
             'then LoadMusicType: with RBUserSettingData bgmType and a mov w3 of 1 for Loop:YES',
    0x87dd4: 'TwitterImageCreater -drawImageFileName:Position:: truncates the CGPoint to two ints '
             'and passes m_Scale, the f-encoded ivar, through to drawImage:X:Y:Scale:',
    0x153c0: 'BFCodec -cipherInit:: nil-guards the NSData, then forwards its bytes and length to '
             'the two-argument form',
    0x363a8: 'RBTutorialManager +resetUnlockedItemInfo: getInstance, then unlockItemInfo '
             'removeAllObjects',
    0x20b0c: 'RBPastelManager +tryShow:: for a non-zero stage it scans every earlier slot and bails '
             'on the first one already shown, then marks its own and clears the rest. The tail '
             'clear runs from stage+1 to 4, the cmp #3 with b.gt being the >= 4 early out, and 4 '
             'matches both kPastelShowStageCount and the ivar\'s own [4B] encoding',
    0x3578c: 'RBTutorialManager +needStartTutorialMusicselect: NO once totalRecordCount reaches 1, '
             'else the persisted flag 0x17 compared against 1; 0x17 is RBTutorialStatusMusicSelectSeen',
    0x358ec: 'RBTutorialManager +needStartTutorialPlay: the same record gate, then currentStatus '
             'compared against the cmp #9, which is RBTutorialStatusPlayStart',
    0x35c50: 'RBTutorialManager +needStartTutorialStore: the same gate, then the persisted flag '
             '0x25, which is 37, matching RBTutorialStatusStoreSeen',
    0x987b0: 'RBCustomView -showAnimation: chains to the superclass showAnimation through '
             'objc_msgSendSuper2, then saves RBUserSettingData; it launches no tutorial step',
    0x1534c: 'BFCodec -cipherInit:keyLength:: clears the context, copies the eight-byte IV from '
             '0x2ec7e0, then tail-calls the key schedule. The IV reads e3 66 31 da 2c 85 a0 64 '
             'from the binary, matching kBlowfishInitialIV byte for byte',
    0x96664: 'RBCustomView -initWithFrame:: the mov w2 of 1 matches '
             'RBMusicMenuPopupViewTypeCustomize, then setupView',
    0x99eb0: 'RBHowToView -initWithFrame:: the mov x2 of 0 is RBMusicMenuPopupViewTypeHowTo, the '
             'enum\'s own name for the default variant',
    0x904ac: 'RBPlaylistCreateViewController -viewWillDisappear:: super, then textField '
             'resignFirstResponder, the mirror of its viewDidAppear:',
    0xbf488: 'RBStoreExtendNoteList -isFetching: short-circuits, returning YES on a live '
             'extendNotelistDownloader without ever reading productsRequest',
    0x96328: 'RBCreditsView -initWithFrame:: super, nil check, then setMusicMenuPopupViewType: '
             'with the orr w2 of 3 matching kMusicMenuPopupViewTypeCredits, then setupView',
    0x4cadc: 'StoreExtendNoteView -setArtwork:: drives artworkImageView.image, no ivar of its own',
    0x90428: 'RBPlaylistCreateViewController -viewDidAppear:: super, then textField '
             'becomeFirstResponder so the keyboard is up on entry',
    0xc348: 'StoreButtonView -setHighlighted:: reads the old value through super, calls super\'s '
            'setter, and redisplays only on a change. The binary spells the test as eor then '
            'cmp #1 where the reconstruction uses !=, which agree for canonical BOOLs',
    0xc3d4: 'StoreButtonView -setSelected:: the same change-detecting shape over isSelected',
    0x6a03c: 'RBBGMManager -PauseMusic:: guarded on m_IsMusic, then AudioManager onPauseBgm:',
    0x6a0c8: 'RBBGMManager -StopMusic:: the same guard, then stopBgm:',
    0xbe3d4: 'RBNewsHUDView -initWithFrame:: super, nil check, then the lowercase setupView',
    0xc9370: 'RBMusicFirstInfoView -initWithFrame:: the same shape but the capitalised SetupView; '
             'the two selectors differ only in case and both reconstructions match their own',
    0xb4320: 'RBMenuView -scrollViewDidEndDragging:willDecelerate:: the tbnz on bit 0 of x3 means '
             'the forward to scrollViewDidEndScroll: happens only when decelerate is NO',
    0xd6b8c: 'RBMusicView -getDifficultyButton:: forwards the index to difficultyView',
    0xdc514: 'RBRankingTableView -pushLoadNext:: disables buttonLoadNext, then load: with the mov '
             'w2 of 0x14, matching kLoadNextIncrement of 20',
    0xebf1c: 'RBSettingView -SelectInfoButton: themed effect 1, parentView '
             'showNotificationPageView, then its own hideAnimation',
    0x4169c: 'AVBus -setSource:: stores the record, then dispatches on its first field, URL when '
             'set and data otherwise, passing the +0x10 BOOL as isLoop, and returns mCurrentID '
             'through ldrh. Its method_t types read S24@0:8^{AVSource=@@B}16, so the return is '
             'retyped from unsigned int to unsigned short; -currentID at 0x41f38 encodes S16@0:8 '
             'and is retyped with it',
    0xb8aa4: 'RBMenuView -SelectPlaylistFinButton: RBPlaylistManager synchronize, then the tail '
             'call to playlistEditFinish',
    0x4171c: 'AVBus -removeSource: nils mSource, bumps the S-encoded mCurrentID with ldrh/strh, '
             'and returns whether a player was attached, nilling it when so',
    0x41d28: 'AVBus -audioPlayerBeginInterruption:: from status 2 only, the csel keeps 2 while the '
             'player is still playing and drops to 4 otherwise',
    0xc911c: 'RBMusicDifficultyView -getDifficultyButton:: difficultyButtons objectAtIndex:',
    0x87a70: 'TwitterImageCreater -setName:Side:: FIXED with the other eight Side: setters. The '
             'guard is cmp #1 with b.ls or b.hi, an unsigned compare, where the reconstruction '
             'tested a signed int and so admitted a negative index',
    0x69688: 'StorePackInfoDownloader -initWithStorePackInfo:: super init, nil check, packInfo',
    0x6ae38: 'RBMusicManager -init: super init, nil check, then createPreInMusics',
    0x4a2c8: 'RBTermDetailPhoneViewController -alertView:clickedButtonAtIndex:: on isFirstRequest '
             'it nils the alert view\'s own delegate, not its own, then forceClose',
    0x34cf8: 'SoundManager -setupAudioSession: the category argument resolves through the import '
             'to _AVAudioSessionCategoryAmbient, and setActive: takes w2 of 1 with a nil error',
    0x41da8: 'AVBus -audioPlayerEndInterruption:: replays only from status 2 and drops to 4 when '
             'play fails; the cmp #2 and mov w8,#4 match AVBusStatusPlaying and AVBusStatusStopped',
    0x41e20: 'AVBus -audioPlayerEndInterruption:withOptions:: instruction-identical to the '
             'one-argument form, options never read, and read separately rather than assumed',
    0x6a154: 'RBBGMManager -SeekToTop: guarded on m_IsMusic, then AudioManager seekBgmToTop',
    0xab350: 'RBMenuView -getRandamInt:max:: seeds srand(time(NULL)) once behind a file-scope '
             'flag, then maps rand() over ((max-min)+1) with the pool double at 0x301070, which '
             'reads bit-for-bit as 1/2**31 and matches the declared 1.0/2147483648.0',
    0x3a468: 'neGLView -BeginRender: returns EAGLContext setCurrentContext: over its own '
             'glContext, with the class object in x0 and the context in x2',
    0x3a4e0: 'neGLView -Present: sends presentRenderbuffer: to glContext with m_RenderBufferID, '
             'the I-encoded ivar loaded into w2, and returns the result',
    0x20a88: 'RBPastelManager -init: super init, nil check, then allReset',
    0x36b5c: 'RBHttpUtil -init: the same shape with reset in place of allReset',
    0xc194: 'StoreButtonView -setButtonColor:: stores the retained colour into _buttonColor and '
            'then sends setNeedsDisplay, so it is a custom setter rather than a synthesised one',
    0xc264: 'StoreButtonView -setDisabledColor:: the same shape over _disabledColor',
    0x3550c: 'SoundPlayer -setCurrentFrame:: clamps to [0, m_SoundData.totalFrames], calling '
             'totalFrames twice on the over-range path. The ivar encodes q, so the property and '
             'the parameter are retyped from long long to NSInteger',
    0x35cfc: 'RBTutorialManager +getStatus:: forwards to RBUserSettingData getTutorialStatus:',
    0x69700: 'StorePackInfoDownloader -dealloc: delegate, packInfo, downloader, all through '
             'their setters and in that order',
    0x179c64: 'StoreExtendNoteInfoDownloader -dealloc: the sibling shape, with setExtendNoteInfo: '
              'in the middle slot',
    0xa220c: 'RBMenuView -dealloc: reads newsDownloader twice, once to nil-test and once to send '
             'cancel, exactly as reconstructed',
    0x218f0c: 'RecommendAdWebView -dealloc: nils _applilinkDelegate directly, then the delegate '
              'through its setter',
    0x2413e0: 'RecommendAdAreaView -dealloc: six ivars in the binary order, _applilinkDelegate, '
              '_sdkDelegate, the delegate via its setter, then _adLocation, _impressionId, '
              '_requestCode',
    0x248164: 'RecommendFullScreenController -dealloc: stops and removes _indicator, then nils it '
              'with _baseView, _shadeView, and the two applilink delegates',
    0xf4220: 'StoreImageView -dealloc: cancelDownload on the downloader when one is held',
    0x41e98: 'AVBus -dealloc: nils player, then the ARC-emitted super chain',
    0x878ac: 'TwitterImageCreater -dealloc: sends its own reset and nothing else',
    0xfe958: 'StorePackView -dealloc: detaches the delegate only',
    0x177a38: 'StoreTableCellViewBase -dealloc: the same delegate detach',
    0x14d84: 'UnZipArchive -dealloc: closeFile before the chain',
    0x3970c: 'RBHttpUtil -dealloc: cancel before the chain',
    0x4ca54: 'StoreExtendNoteView -dealloc: delegate detach',
    0xcc08: 'StoreButtonView -dealloc: nils buttonColor then disabledColor, in that order',
    0x21f1f8: 'RewardWebViewController -dealloc: clearDelegate and then a direct strb wzr clearing '
              '_viewCloseFlg at 0x21f224, which a msgSend-only scan does not see',
    0x154b38: 'DAProgressOverlayView -initWithFrame:: super, nil check, setUp',
    0x18e3cc: 'RBPushNotificationView -initWithFrame:: a bare super chain with no nil check and '
              'no setup call, exactly as reconstructed',
    0x18f74c: 'RBPushNotificationView -dealloc: setDelegate:nil then stopTimer before the super '
              'chain. Finding this is what disproved the audit note claiming only one dealloc in '
              'the binary does more than chain; the real count is 39 of 88',
    0x16ff9c: 'RBTermPhoneViewController -viewDidAppear:: super, then loadList',
    0x159240: 'RBCustomSelectCollectionView -collectionView:numberOfItemsInSection:: items.count, '
              'with the section argument never read',
    0x18dc24: 'RBUnlockCollectionView -collectionView:numberOfItemsInSection:: the same shape, '
              'read on its own rather than inferred from the sibling',
    0x168174: 'RBUrlSchemeManager +sharedManager: a plain nil check on the 0x3de800 slot, no once '
              'token and no lock',
    0x181aac: 'RBExtendNoteManager +getInstance: the same plain nil check, and it sends '
              'loadPurchasedNotes inside the nil branch before returning',
    0x9070c: 'RBPlaylistCreateViewController -backButtonPush:: pops the navigation controller '
             'animated, the mov w2 of 1',
    0x93a7c: 'RBPlaylistViewController -returnButtonPush:: the same pop, read on its own',
    0xb217c: 'RBMenuView -searchBar:textDidChange:: passes x3, the search text, to '
             'searchStringChanged: rather than x2, the bar, and only then runs exeSearchPickUp',
    0x356b8: 'RBTutorialManager +getInstance: a plain nil check with no once token, and it seeds '
             'currentStatus with the mov w2 of 0xffffffff, which is RBTutorialStatusNone',
    0x35724: 'RBTutorialManager +isTutorial: getInstance then the instance isTutorial',
    0x35d6c: 'RBTutorialManager +getCurrentStatus: getInstance then the currentStatus getter',
    0x734b8: 'Downloader -currentProgress: forwards to conn; the float comes back in v0 and is '
             'parked in v8 across the release, so the float return type is right',
    0x73520: 'Downloader -getData: forwards to conn, same selector',
    0x73588: 'Downloader -getDataInJSON: forwards to conn, selector slot 0x478 read individually',
    0x735f0: 'Downloader -getHeader: forwards to conn, selector slot 0x2f0',
    0x73658: 'Downloader -systemErrorMessage: forwards to conn, selector slot 0x3d0',
    0x736c0: 'Downloader -showErrorMessage: forwards to conn, selector slot 0x3d8. Each of the six '
             'had its own selector reference resolved rather than the family assumed from one',
    0x87848: 'TwitterImageCreater -reset: three guarded release-and-nil blocks in order, m_Data '
             'through operator delete[], m_Context through CGContextRelease, m_ColorSpace through '
             'CGColorSpaceRelease, each nil-checked before the call and cleared after',
    0x154ae0: 'DAProgressOverlayView -initWithCoder:: super initWithCoder:, nil check, then setUp',
    0x140544: 'RBMenuTutorialView -getClipRect:: indexes the runtime-seeded 0x3de058 table at a '
              '32-byte CGRect stride into d8-d11, then four fcsel on IsPad choose between the raw '
              'row and the same row times the 0.5 fmov immediate. The four fields stay in x, y, '
              'width, height order with no transposition; the misleading comment is corrected',
    0xf0d5c: 'RBCorporateViewController -webView:shouldStartLoadWithRequest:navigationType:: '
             'starts the indicator and always returns YES',
    0xf0ecc: 'RBCorporateViewController -webViewDidStartLoad:: ignores the web view and empties '
             'the shared URL cache',
    0xfd208: 'StorePackMusicView -tapSp: builds the move-to-extend-detail alert with self as the '
             'delegate and shows it',
    0x35498: 'SoundPlayer -setSoundData:: a guarded setter, it only stores while m_IsPlaying is '
             'clear, so a write during playback is silently dropped',
    0x3ab14: 'neGLView -touchesCancelled:withEvent:: forwards both arguments to '
             'touchesEnded:withEvent:',
    0x68e30: 'StorePackInfo -priceString: sends priceString: to the classref at 0x3c7290, which '
             'resolves through its class_ro_t to StoreUtil rather than being assumed',
    0xd6b28: 'RBMusicView -getDoubleButton: reads doubleButton twice, once to nil-test and once '
             'to return, exactly as reconstructed',
    0x109850: 'StoreCampaignItemInfo -checkNewUnlock: NO unless bUnlock, then the inverse of '
              'alreadyDownload',
    0x1d754c: 'RBStoreTabController -selectTab:: returns while m_Animation is set, else writes '
              'selectedIndex',
    0xe6454: 'RBSearchMapViewController -didChangeUserTracking:: drives currentLocation.selected',
    0xe6f94: 'RBSearchView -didChangeUserTracking:: the same, over currentPositionButton',
    0xe6e74: 'RBSearchView -selectCurrentPosition:: ignores the sender, sends map toggleTrackingMode',
    0xe47f0: 'RBSearchMapView -imageDownloaderDidFail:didLoad:: nils the downloader, shows the '
             'server-connect-failed string, then subIndicator, which is the void spinner-refcount '
             'action paired with addIndicator rather than a getter whose result is dropped',
    0xf5528: 'StorePackCell -isPurchased: an eor with 1 over labelPurchased.isHidden',
    0xf5588: 'StorePackCell -setIsPurchased:: hides labelPurchased on the inverted argument; '
             'unlike StoreExtendNoteView it really does read the argument',
    0xfebd8: 'StorePackView -isPurchased: the same inversion over purchasedButton.isHidden',
    0xfec38: 'StorePackView -setIsPurchased:: the matching setter, argument read',
    0xe9c28: 'RBSettingMenuButton -setEnabled:: passes a hardcoded w2 of 0, so it ignores its '
             'argument and always disables the inner button; the quirk is already flagged in place',
    0x101924: 'StorePromotionView -getImageCount: promotionDataArray.count, nothing else',
    0xd6684: 'RBMusicView -setEnableButton:: forwards the flag to difficultyView',
    0xeb144: 'RBSettingView -CloseView: returns early while m_Animating, else plays themed effect '
             '4 (kSoundEffectCancel, the mov w1) and tail-calls hideAnimation',
    0x168850: 'RBCustomSelectView -getCollectionViewStartY:: the cset inverts the sense, so theme '
              '0 takes index 1 of the 0x30bf00 pair (70, 40) and gets 40 on the pad; narrow is an '
              'fcsel between the 21 fmov immediate and the 34 at pool 0x2fd00c. All four decoded '
              'from the binary and all four match',
    0x202748: 'RBBaseViewController -shouldAutorotate: YES off the pad; on the pad it is the '
              'negation of GetGameSystem()->GetBgmPlaying(), the byte at +0xac',
    0x2027dc: 'RBBaseViewController -shouldAutorotateToInterfaceOrientation:: the sub #1 / cmp #1 '
              '/ b.hi is exactly the Portrait and PortraitUpsideDown pair; any other orientation '
              'is NO before the bgm flag is even read',
    0x202900: 'RBBaseTableViewController -shouldAutorotate: read separately, instruction-identical '
              'to the RBBaseViewController one',
    0x202994: 'RBBaseTableViewController -shouldAutorotateToInterfaceOrientation:: likewise, read '
              'separately rather than inferred from its sibling',
    0x202b00: 'RBBaseTabBarController -shouldAutorotate: the third of the identical trio, also '
              'read on its own',
    0x1942f8: 'RBUnlockView -setParentView:: forwards to the differently-named setParentCustomView:',
    0x1998e0: 'RBUnlockView -downloadManagerFailed:: ignores the manager, nils dlMusicName, then '
              'reloadData',
    0x18efa0: 'RBPushNotificationView -hideAnimationStart: stopTimer, then hideAnimation bounced '
              'through performSelectorOnMainThread: with waitUntilDone YES',
    0x1dc8e0: 'RBStoreDetailViewController -viewDidDisappear:: a pure super chain',
    0x201628: 'RBAnimationFactory +createPositionXAnim...: tail-calls the key-path builder with '
              'the "position.x" CFString at 0x36cfc0',
    0x201644: 'RBAnimationFactory +createPositionYAnim...: loads the SAME 0x36cfc0 "position.x" '
              'string, not the "position.y" at 0x36cfe0 that exists two slots along. A bug in the '
              'shipped binary; the reconstruction reproduces it and the file header says so',
    0x1cb2e8: 'RBCoreDataManager +scoreDataFileName: a csel on IsPad, ScoreData.sqlite on the pad '
              'and ScoreDataPhone.sqlite otherwise',
    0x1f05fc: 'RBStorePackList +storeCountry: nil-checks the cached country global before copying '
              'it with stringWithString:, and returns nil when unset',
    0x1ad484: 'RBTutorialPastel -getPosition:: calls IsPad and discards the result, then indexes '
              'the 0x3df460 table at a 16-byte stride for the CGPoint pair in d0/d1',
    0x1b35cc: 'RBTutorialPastelLayer -getPosition:: instruction-identical to the RBTutorialPastel '
              'one, reading the same 0x3df460 table; its discarded IsPad is now flagged too',
    0x19bc00: 'RBPopupView -tap:: ignores the sender and sends hideAnimation',
    0x19e1dc: 'RBCustomInfoPopupView -tap:: the same shape, read separately rather than assumed',
    0x1a027c: 'RBMusicMenuPopupView -tap:: likewise, the third of the identical popup dismissals',
    0x1999bc: 'RBUnlockView -alertView:clickedButtonAtIndex:: reads neither parameter, sends request',
    0x19e9e8: 'RBCharacterBase -checkLimitType:: and/cmp/cset, so it tests that every bit of the '
              'argument is set in useLimit rather than any of them',
    0x1bb3a8: 'RBExperienceData -resetPoint:: only theme 2 does anything, zeroing pointB; every '
              'other theme returns immediately',
    0xe7288: 'RBMenuBGEffectView -setupView: sends its own setupRainbow then tail-calls '
             'setupParticle, and never chains to the superclass setupView',
    0x100464: 'StorePromotionView -layoutSubviews: a pure super chain, nothing else',
    0x18eac4: 'RBPushNotificationView -showNotification: setNextNotification, then tail-call '
              'showAnimation',
    0x16889c: 'RBCustomSelectView -getCollectionViewMargin: an fcsel on IsPad, 20 wide and 12 '
              'narrow, both decoded from the instruction words rather than the printed immediates',
    0x186004: 'GraphView -setData:maxValue:: forwards to the three-argument form with w3 zero, so '
              'isMovableMinLine is NO',
    0x181b14: 'RBExtendNoteManager +getExtendNoteDataFilename:: formats "%09d.rb" over the one id, '
              'one specifier and one stack-pushed argument',
    0x16ffec: 'RBTermPhoneViewController -viewDidDisappear:: a pure super chain, nothing else',
    0x181f64: 'RBExtendNoteManager -init: a pure super chain, no ivar seeding',
    0x1931fc: 'RBNotificationPagePhoneViewController -alertView:clickedButtonAtIndex:: reads '
              'neither parameter; on isFirstRequest it sends pushBarBtnBack: nil',
    0x86b9c: 'StoreUtil +affiliateParametersFromURL:: FIXED, the parameter is an NSURL sent -host '
             'and -query directly (no URLWithString: anywhere in the routine), and a host that is '
             'not itunes.apple.com returns nil rather than falling through to the query parse',
    0x859f8: 'StoreUtil +productIDForPackID:: FIXED, the format is "%@%05d" over the rbplus.pack '
             'prefix and the id; the reconstruction had dropped the stack-passed prefix argument',
    0x874a0: 'StoreUtil +pidToProductID:: FIXED the same way, over the rbplus.note prefix; despite '
             'the generic name this one vends extend-note product ids, not pack ones',
    0x716f4: 'RBPlaylistManager -numberOfPlaylists: the count of arrayPlaylist',
    0x73458: 'Downloader -currentSize: forwards to the connection\'s own currentSize',
    0x69e50: 'RBBGMManager +getInstance: the same plain nil check as its three siblings',
    0x19c40: 'RBResoureDownloadBGEffectView -setupView: the super send is setupRainbow, not the '
             'superclass setupView, and it precedes the local setupParticle',
    0x41308: 'AVBus -init: seeds mStatus with -1, which is AVBusStatusNone, and zeroes the '
             'S-typed mCurrentID with a strh',
    0x35380: 'SoundManager -startSystem: starts the graph only when it is initialised and not '
             'already playing, and marks it playing after the start rather than before',
    0x4cb68: 'StoreExtendNoteView -isPurchased: the eor #1 at 0x4cb98 inverts the label\'s hidden '
             'flag, so purchased means the caption is showing',
    0x4cbc8: 'StoreExtendNoteView -setIsPurchased:: sets the standing caption and never reads its '
             'argument, so the flag it appears to take has no effect',
    0x4d004: 'StoreExtendNoteView -reset: clears the artwork, then chains to the empty base reset',
    0xc138: 'StoreButtonView -buttonColor: lazily installs blueColor into the _buttonColor ivar on '
            'first read, releasing whatever was there, and returns the ivar rather than the call',
    0xc208: 'StoreButtonView -disabledColor: the same shape with grayColor',
    0xc300: 'StoreButtonView -highlightColor:factor:: fsub gives 1 - factor once, and each of the '
            'four lanes is that times the component plus the factor, so all four including alpha '
            'are blended the same way',
    0x3403c: 'StorePackListGenre -packCount: the count of arrayPackInfo, nothing else',
    0x3930c: 'RBHttpUtil -currentSize: the length of downloadedData',
    0x35198: 'SoundManager -stop:: stops the indexed player only when it reports playing, and '
             'returns 1 either way, from the mov w0 after both arms rejoin',
    0x18b14: 'SystemHardware +getInstance: plain nil check, no once-token or lock',
    0x20a30: 'RBPastelManager +getInstance: the same shape',
    0x34bb0: 'SoundManager +getInstance: the same shape',
    0x18a98: 'SystemHardware -init: seeds m_HardwareType with the 15 sentinel, and only when super '
             'returned non-nil',
    0x93d00: 'RBPlaylistViewController -numberOfSectionsInTableView:: 2 whenever the type is not '
             'the menu, and for the menu the cinc eq at 0x93d40 gives 2 at the root node and 1 '
             'below it, which is the three-armed form the reconstruction spells out',
    0x18cf4: 'SystemHardware -getHardwareName: the same resolve-once guard as getHardwareType, '
             'then a tail call to the hardwareName property rather than a stored copy',
    0x49264: 'RBTermDetailPhoneViewController -viewDidAppear:: chains to super with the flag, then '
             'loads the detail',
    0x69ea8: 'RBBGMManager -init: clears m_IsMusic and m_IsPushMusic, in that order, and only when '
             'super returned non-nil',
    0x18cb0: 'SystemHardware -getHardwareType: 15 is the unresolved sentinel; the cmp at 0x18ccc '
             'resolves once and re-reads the ivar rather than using the call result',
    0x881fc: 'TwitterImageCreater -getDigitNum:: the loop test is (previous + 9) against 18 with '
             'b.hi, an unsigned compare, so it stops on a single digit of either sign; the tail '
             'csel returns 1 for a zero argument',
    0x9d37c: 'RBCampaignData -presetHinabitaMode: names the campaign 201703hnbt and then clears '
             'the matching flag rather than setting it',
    0xf0ff0: 'RBCorporateViewController -alertView:clickedButtonAtIndex:: the cbz on isFirstRequest '
             'skips the pop entirely, and the button index is never read',
    0x1428b4: 'RBErosionMarkUpdaterScoreView -remove: clears the delegate before removing itself, '
              'in that order',
    0x142b1c: 'RBErosionMarkUpdaterAlertController -supportedInterfaceOrientations: returns the '
              'Q-typed _orientationMask ivar unmodified',
    0x3532c: 'SoundManager -unsetCallBack:: zeroes a sixteen-byte struct on the stack and hands it '
             'to AudioUnitSetProperty as property 0x17, scope 1 and size 16, which are the render '
             'callback, the input scope, and the struct size',
    0xbf024: 'RBStoreExtendNoteList +storeCountry: the cbz returns nil when the global is unset, '
             'otherwise a copy through stringWithString:',
    0xd8030: 'RBPopoverBackgroundView -setArrowDirection:: stores into the Q-typed _arrowDirection, '
             'then adds the drop shadow and asks for layout, in that order',
    0x1405a8: 'RBMenuTutorialView -animationDidStop:finished:: clears animating and reads neither '
              'argument',
    0x9da80: 'RBMenuButton -layoutSubviews: a lone super chain',
    0x69114: 'StorePackInfo -downloadDetailInfo: cset eq on the musicInfos pointer, so it reports '
             'whether the tune list is still absent rather than present',
    0x35038: 'SoundManager -releaseData:: clears the slot and returns 1 only when it held '
             'something, 0 otherwise; the ivar type [10@"SoundData"] gives the ten-slot bound',
    0xdedf4: 'RBRankingView -SelectFriendButton: plays themed slot 1 (mov w1 at 0xdee08) then '
             'showFriend:YES',
    0xdee2c: 'RBRankingView -SelectAllButton: the same, with showFriend:NO from the mov w2 at '
             '0xdee48',
    0x492b4: 'RBTermDetailPhoneViewController -viewDidDisappear:: likewise, forwarding the flag',
    0x14ec8: 'UnZipArchive -closeFile: the cbz makes closing a no-op when no archive is open, and '
             'm_ZipFile is cleared after the close, not before',
    0x1503c: 'UnZipArchive -setFirst: returns whether the seek returned 0, and NO without seeking '
             'when m_ZipFile is null',
    0x15070: 'UnZipArchive -setNext: the same shape against the next-entry seek',
    0x6a9e8: 'RBMusicManager +getMusicDataFilename:: formats the id with %09d.rb',
    0xab9d4: 'RBMenuView -SelectSettingButton: the binary is a lone tail call to toggleSettingView; '
             'our copy carries temporary RBPDBG logging around that same call',
    0xbeff8: 'RBNewsHUDView -imageDownloaderDidFail:didLoad:: sets m_CanHide, then hides; neither '
             'argument is read',
    0xf4200: 'StoreImageView -imageDownloaderDidFail:didLoad:: clears the downloader and nothing '
             'else, neither argument read',
    0x103a50: 'StorePromotionView -scrollViewWillBeginDragging:: a lone tail call to stopAnimation',
    0x103c50: 'StorePromotionView -scrollViewDidEndDecelerating:: the counterpart, startAnimation',
    0x56fd4: 'StoreCampaignTableViewCell -getItemSize:: two fcsel pairs, 320/640 wide and 80/160 '
             'tall, the pad arm taking the larger of each',
    0x729e0: 'Downloader +dictionaryToQueryData:: forwards to RBHttpUtil unchanged',
    0x72a0c: 'Downloader +dictionaryToJsonData:: likewise',
    0x85b4c: 'StoreUtil +priceString:: forwards with useCatalogPrice: 0, from the mov w3 before '
             'the tail call',
    0xc9bf4: 'RBMusicFirstInfoView -tap:: a lone tail call to hideAnimation, the recogniser unread',
    0xd61b0: 'RBMusicView -firstInfoScrollEnd: the cbz on m_FirstInfo returns without scheduling; '
             'otherwise it defers setFirstScrollAnimation by the 0.5 in the fmov, with a nil object',
    0xedde8: 'StoreDetailMusicCell +cellHeight: one pool load of 80.0',
    0x1099ac: 'StoreCampaignItemInfo -registSuccess: writes the same 1 into both _bServerUnlock and '
              'its neighbour, so the two flags are set together',
    0x10d018: 'RBRewardListView -setParentView:: forwards to setParentCustomView:, which is why the '
              'two names differ',
    0x194ba0: 'RBUnlockView -reloadData: s10 is the row height and s11 the row gap (the fcsel pair '
              'at 0x194c10 and 0x194c1c); d9, the height each row is built with, is taken from s10 '
              'at 0x195008 before the fadd at 0x19502c folds the gap in, and the loop advances by '
              'that summed value at 0x1950e0, so rows draw at the height but step by height plus '
              'gap. The banner height is imageHeight / (imageWidth / width) from the fdiv pair at '
              '0x1954d8, v9 being the height lane of the size call at 0x1954a8',
    0x56e6c: 'StoreCampaignTableViewCell -setDownloadFlag:: stores the flag, then sets buttonType '
             'to 1 only when it is set, leaving it alone otherwise',
    0x94c3c: 'RBPlaylistViewController -tableView:canEditRowAtIndexPath:: cset eq against section '
             '1, the playlists section',
    0x94d70: 'RBPlaylistViewController -tableView:canMoveRowAtIndexPath:: the same test, '
             'instruction for instruction',
    0xc2974: 'RBMusicColorBar -alphaValue: sends sliderValue and narrows the double with fcvt, '
             'which is the float the declaration returns',
    0xd9110: 'RBPopoverBackgroundView -mirroredInsets:: swaps v1 and v3 only, so left and right '
             'exchange while top and bottom stay',
    0xdc598: 'RBRankingTableView -tableView:numberOfRowsInSection:: tail-calls numEntries, '
             'ignoring the section',
    0xec0c0: 'RBSettingView -SelectExitButton: the cbz on m_Animating returns while a transition '
             'runs, otherwise tail-calls hideAnimation',
    # Read by a subagent and then re-checked here against the bytes, point by point, because a
    # sibling batch from the same run had invented a weak-reference pattern the binary does not use.
    0x1c813c: 'RBTermAgreeView -sendAgree: the boxing is numberWithInteger:, not the numberWithInt: '
              'a boxed int literal emits, and the proceed argument is the global block at 0x35f500 '
              'whose invoke is 0x1c853c, not nil',
    0xe661c: 'RBSearchView -setupView: the current-position button takes 606.0 (0x301630) and, on '
             'the default theme, 193.0 (0x301638); its highlight image binds to state 4, selected, '
             'from the mov w3 at 0xe6790, and its mask is 0x21, left plus bottom margin, from the '
             'mov w2 at 0xe67c8',
    0x19335c: 'RBNotificationPageView -setupView: reaches the delegate through the hand-written '
              '-getWebInfoURL and -getInfoLastUpdateTimeString accessors, clears through '
              '-setWebInfoURL:, and re-sends +appDelegate at every use rather than holding it',
    0x191ebc: 'RBNotificationPagePhoneViewController -viewDidLoad: the same accessor and re-fetch '
              'shape as 0x19335c',
    0x888b0: 'TwitterImageCreater -createImage: the badge names are indexed static tables, the four '
             'difficulty names at 0x35b4e0 and the level names at 0x35b500 in rows of fifteen, so '
             'index 15 is the second grade\'s first level, not names formatted at the point of use',
    0x14efc: 'UnZipArchive -getEntryNum: the cbz on m_ZipFile returns 0 when no archive is open, '
             'otherwise the first field of m_ZipFileGlobalInfo, which is number_entry',
    0x1605c: 'GraphCircleView -setData:maxValue:: forwards to the three-argument form with '
             'isMovableMinLine set to 0',
    0x259c4: 'StoreExtendNoteDetailViewPad -finishBgm:: a lone tail call to stopSample, the '
             'notification argument unread',
    0x45d08: 'StoreCampaignDetailViewPad -finishBgm:: the same shape, tail-calling sampleStop',
    0x3536c: 'SoundManager -getSoundPlayer:: indexes the m_SoundPlayer array ivar, whose type '
             '[8@"SoundPlayer"] gives the eight-element bound, then autoreleases',
    0x471e8: 'StoreCampaignDetailViewPad -getArtworkMargin:: fmov immediates 12.0 and 10.0, the '
             'BOOL unread',
    0x471f4: 'StoreCampaignDetailViewPad -getItemSize:: pool loads 0x2eec30 and 0x2eec38, 650.0 '
             'and 284.0, the BOOL unread',
    0x5606c: 'RBStoreManageSortViewController -tableView:numberOfRowsInSection:: tail-calls the '
             'sortRuleCount getter, ignoring the section',
    0x56fa4: 'StoreCampaignTableViewCell +cellHeight:: fcsel ne takes 180.0 (0x2ee970) on the pad '
             'and 100.0 (0x2ec6f8) otherwise',
    0x56fc0: 'StoreCampaignTableViewCell -getArtworkMargin:: fcsel ne picks 12.0 over 10.0 for the '
             'width only, so the height stays the 10.0 left in d1 on both arms',
    0xa1e08: 'RBMenuView -setCurrentPageIndex:: the guard sends currentPageIndex rather than '
             'reading the ivar, and the label pair at 0xa1eac is (index + 1, maxPage)',
    0xa1f24: 'RBMenuView -setMaxPage:: the csel takes 1 when the argument is zero',
    0xb8b14: 'RBMenuView -setCurrentMenuMode:: b.cs at 0xb8b2c is unsigned, so a negative mode '
             'takes the second arm',
    # The call-set difference the mechanical pass reports is false on both sides: the selectors it
    # sees only in the binary are our dot access and @() boxing, and the ones it sees only in the
    # source are inside the three blocks, which the binary compiles as separate functions
    # (0xb28d0, 0xb2a04, 0xb2e00) and so does not send from this body.
    0xb2280: 'RBMenuView -configureCell:: cbz at 0xb22cc takes mode 0 to the addButton arm and the '
             'cmp #1 at 0xb22d0 takes mode 1 to removeButton (selectors 0x3c26c8 and 0x3c26d0); '
             'the eor #1 at 0xb237c/0xb243c is the ! on containsObject:; the tbnz at 0xb24ac '
             'returns while decelerating; the cbz at 0xb2674 picks updateScoreData:spData: over '
             'updateScoreData: (0x3c26d8 against 0x3c26e0)',
    # Same false call-set difference as 0xb2280: dot access and @() on one side, the two dispatch
    # blocks (0x1596dc, 0x1597d8) on the other.
    0x1592a8: 'RBCustomSelectCollectionView -collectionView:cellForItemAtIndexPath:: the jump '
              'table at 0x1596c4 maps customizeType 0..5 onto the bgm, shot, explosion, frame, '
              'background and note settings in that order, b.hi at 0x1593fc sends anything above '
              'to the w24 = 0 default at 0x15964c, and the cset eq at 0x159568 is the '
              'selectedType == itemID that drives setIsSelected:',
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
    # RBResourceDownloadViewController, read one routine at a time against the disassembly. The
    # csel at 0x19df4 is the only idiom branch in this group and it runs the wrong way round from
    # the usual: the pad gets the RESTRICTIVE mask 6, the phone gets 0x1e. Both LoadMusicType: 0xf
    # and the PlayMusic: volume held, the latter a 4-byte ldr s0 at 0x19f34 off 0x2ee910, so 0.3f
    # is correctly spelled float32 rather than a double.
    0x19ddc: 'RBResourceDownloadViewController -supportedInterfaceOrientations: pad 6, phone 0x1e',
    0x19e1c: 'RBResourceDownloadViewController -willAnimateRotation...: super only, args untouched',
    0x19e50: 'RBResourceDownloadViewController -viewDidLoad: mask 0x3f, setupView, then the BGM',
    0x19f74: 'RBResourceDownloadViewController -download: downloadPath or fall back to -request',
    0x1a01c: 'RBResourceDownloadViewController -resume: task resume, pause flag NO, then save',
    0x1a0e8: 'RBResourceDownloadViewController -pause: task suspend, pause flag YES, then save',
    0x1a1b4: 'RBResourceDownloadViewController -alertView:clickedButtonAtIndex:: tag 3, then the '
             'cancel-index compare at 0x1a208; every other tag just downloads',
    0x1a2ac: 'RBResourceDownloadViewController -viewDidAppear:: 1.0 fade to alpha 0, then the '
             'completion runs -animation and -download in that order',
    0x1a56c: 'RBResourceDownloadViewController -viewWillLayoutSubviews: super then -updateLayout',
    # The progress fill's height is the subtle one and our source already had it right, with a
    # comment saying so. Each of the three arms zeroes only d0 and d1 and computes d2; d3 is never
    # written, so the height survives from the second -[trackImageView frame] send, which exists
    # solely to reload it. Widths per mode: 0 is trackWidth * (p * 0.5) at 0x1c8cc, 1 is
    # (trackWidth * (p + 1.0f)) * 0.5 at 0x1c818, 2 is trackWidth * p at 0x1c98c. Mode 0 groups the
    # multiply differently from our source, which is arithmetically the same and not worth churn.
    # The + 1.0f really is a float32 add at 0x1c808 before the widening, as we spell it.
    0x1c72c: 'RBResourceDownloadViewController -updateProgress:: three modes, height from d3',
    # DELIBERATE DEVIATION, not a defect and NOT gated: the binary tail-calls -success straight
    # from this callback at 0x1ca54, on SSZipArchive's detached thread. Our source wraps it in a
    # dispatch_async to the main queue with a comment explaining that current iOS traps the direct
    # call. That deviation is neither behind ENABLE_PATCHES nor recorded in PATCHES.md, which is
    # the project's convention for one. Ticked because the routine has been read, not because the
    # body matches. Flagged for a decision.
    0x1ca44: 'RBResourceDownloadViewController -zipArchiveDidUnzipArchiveAtPath:...: -success, '
             'but ours marshals it to the main queue and the binary does not',
    0x1ca60: 'RBResourceDownloadViewController -zipArchiveWillUnzipFileAtIndex:...: float32 '
             'fileIndex/totalFiles from x2 and x3, then updateProgress: on the main thread',
    0x1f600: 'RBResourceDownloadViewController -layoutScrollView: width * m_PageNum, height kept',
    0x1f6c4: 'RBResourceDownloadViewController -pageDidChangeValue:: four guards, non-nil then '
             'not tracking, dragging or decelerating, then scrollRectToVisible animated YES',
    0x1fef0: 'RBResourceDownloadViewController -URLSession:...didResumeAtOffset:...: progress 0',
    # b.pl at 0x1ffa4 skips the update, so it runs only when the ratio is below 1.0f; a NaN takes
    # the skip too. The ratio is totalBytesWritten (x5) over totalBytesExpectedToWrite (x6), not
    # the per-call bytesWritten in x4.
    0x1ff7c: 'RBResourceDownloadViewController -URLSession:...didWriteData:...: ratio under 1.0f',
    # -success carries a neDebugLog and -URLSession:...didFinishDownloadingToURL: an NE_DBG_FIRST
    # block, and NEITHER is invented content. neDebugLog is the project's own instrumentation from
    # GameSystem/src/neDebugLog.h, compiled in only under RBPDBG and collapsing to an empty inline
    # otherwise, and NE_DBG_FIRST(n) collapses to if (0). Every bl in -success goes to objc_msgSend,
    # objc_retainAutoreleasedReturnValue or objc_release, so the binary really does contain no C
    # call, which is the expected result rather than a discrepancy. Recorded because this looks
    # exactly like the invented-NSLog defect until the header is checked. The one wrinkle: an empty
    # inline still evaluates its arguments, and -success passes GetImageAssetDirectoryPath(), which
    # is a pure read of a global, so nothing is executed that the binary would not do.
    0x1c0d8: 'RBResourceDownloadViewController -success: version, flag, save, then checkFile picks '
             'dismiss at 0x1c1c4 or the error alert at 0x1c204',
    0x2002c: 'RBResourceDownloadViewController -URLSession:...didFinishDownloadingToURL:: move, '
             'then cbz on the error picks unzip on a new thread or the error path',
    0x20298: 'RBResourceDownloadViewController -URLSession:task:didCompleteWithError:: the cbz at '
             '0x2022a8 is on x4, the error, and the body runs only when it is non-nil',
    # The page is rounded in float32: the double quotient is narrowed once by the fcvt at 0x1f97c
    # and that float32 feeds both the truncation and the fractional subtraction. Ours narrows from
    # the double twice, which agrees for every reachable value. Threshold is a strict > 0.5f.
    0x1f934: 'RBResourceDownloadViewController -scrollViewDidScroll:: round-half-up in float32',
    0x1fa5c: 'RBResourceDownloadViewController -viewDidDisappear:: both tasks cancelled and '
             'cleared, the subview sweep, then seven image views nilled and showTitle',
    # One defect fixed: the page view takes ALL SIX autoresizing flags, not the width-and-height
    # pair. 0x1e984 loads the same 0x310450 slot that -viewDidLoad loads, and the bytes there are
    # 3f 00 00 00 00 00 00 00. The guard is a signed cmp against 5 with b.le at 0x1e874, matching
    # kHelpPageCount - 1, and the six names in the table at 0x35a388 decode to how_1..how_6, which
    # is what we had. The frame is (index * scrollWidth, 0, image width, image height) and the two
    # separate -size sends at 0x1e92c and 0x1e93c supply d0 and d1 respectively.
    0x1e84c: 'RBResourceDownloadViewController -createViewSame:: one page per index, mask 0x3f',
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
    # RBPurchaseManager's lifecycle, persistence, and purchase entry points. The saved list is
    # salted: four bytes of arc4random are prepended at 0x6d788 and skipped on load by the
    # subdataWithRange: at 0x6dab0, whose location is 4 and whose length is the sub at 0x6da94.
    # Both halves reach the file through the accessor at 0x1a1624, which Ghidra labels
    # GetApplicationSupportPath; that label is wrong. The global it reads is filled at 0x1a08a8
    # from NSSearchPathForDirectoriesInDomains with directory 9, NSDocumentDirectory, so our
    # GetDocumentsDirectoryPath is the correct name for it.
    0x6d2b8: 'RBPurchaseManager -init: four lists at capacity 0, productIds plain init, both '
             'flags cleared before restoredTransactions',
    0x6d4e4: 'RBPurchaseManager -dealloc: delegate nil, then cancel on the downloader',
    0x6d674: 'RBPurchaseManager -saveProductList: salt, property list, Blowfish, write',
    0x6d8e8: 'RBPurchaseManager -loadProductList: decipher, skip the salt, capacity 32 fallback',
    0x6dcc8: 'RBPurchaseManager -beginPurchase:: four-way guard, quantity 1',
    0x6de88: 'RBPurchaseManager -beginRestore: both flags set, three lists emptied',
    0x6e110: 'RBPurchaseManager -addProductID:Save:: contains test first, save is conditional',
    0x6e21c: 'RBPurchaseManager -addProductFromPurchaseCheckedProducts: adds with Save NO, then '
             'one save at the end',
    0x6e370: 'RBPurchaseManager -addPurchaseCheckTransaction:: nil and isPurchased guards',
    0x6e468: 'RBPurchaseManager -checkNextReceipt: empty-queue and in-flight-downloader guards, '
             'nonce 32 and post body encoding 4, downloader set before addData',
    0x70490: 'RBPurchaseManager -downloaderError:: the branch guard is _isRestored, the ivar '
             'offset global at 0x3c872c holding 9; the restore arm builds its error after the '
             'respondsToSelector: check and the purchase arm before it, which the source keeps; '
             'transactioing is cleared before isRestored at 0x707f4 and 0x707f8',
    # RBPurchaseManager's three Base64 routines, worked instruction by instruction. The alphabet is
    # the 64 bytes at 0x337e6e, and the decoder's linear search bounds itself at 0x41, one past the
    # alphabet, so it can also match the NUL terminator at 0x337eae; the source's
    # sizeof(kBase64Alphabet) is 65 and reproduces that exactly. The V1 encoder loads its bytes with
    # ldrsb and then shifts at register width (lsr at 0x6f484 and 0x6f498), so the sign extension
    # reaches the masked field for any byte above 0x7f; narrowing to unsigned char first would zero
    # those bits. Its combines are add, at 0x6f488 and 0x6f49c, not or. The V2 encoder loads with
    # ldrb throughout and needs no such care.
    0x6f3b8: 'RBPurchaseManager +encodedStringWithBase64:: NUL-sentinel partial group, register '
             'width shifts, pad count from the b2/b3 zero tests',
    0x6f544: 'RBPurchaseManager +encodedStringWithBase64V2:: unsigned loads, bfi combines, the '
             'two-byte and one-byte tails at 0x6f660 and 0x6f6c8',
    0x6f784: 'RBPurchaseManager +decodedStringWithBase64:: 65-entry search, bfxil combines, the '
             'written advance keyed on which of v2/v3 came back 0xff',
    # RBPurchaseManager's StoreKit observer. The transaction-state dispatch at 0x6ea0c is a compare
    # chain, not a jump table: 1 Purchased goes to 0x6ec34, 2 Failed to 0x6eb70, 3 Restored falls
    # through at 0x6ea24, and every other state - 0 Purchasing and 4 Deferred - lands on 0x6ed64,
    # which is the loop continuation, so they are deliberate no-ops rather than a missing arm. The
    # two byte guards on the Restored arm are the ivar-offset globals at 0x3c8728 and 0x3c872c,
    # which hold 8 and 9, so they are _transactioing and _isRestored in that order.
    0x6d260: 'RBPurchaseManager +sharedManager: bare nil check, no dispatch_once',
    0x6d4d0: 'RBPurchaseManager +isPurchasable: tail call to SKPaymentQueue canMakePayments',
    0x6d5ac: 'RBPurchaseManager -start: addTransactionObserver: self',
    0x6d610: 'RBPurchaseManager -end: removeTransactionObserver: self',
    0x6dc30: 'RBPurchaseManager -isPurchased:: containsObject: on purchasedProducts',
    0x6e030: 'RBPurchaseManager -removePurchaseCheckedProduct:: removeObject:',
    0x6e0bc: 'RBPurchaseManager -clearPurchaseCheckedProducts: removeAllObjects',
    0x6e834: 'RBPurchaseManager -requestDidFinish:: cbz on the request, then checkNextReceipt',
    0x6e858: 'RBPurchaseManager -paymentQueue:updatedTransactions:: three real arms and a no-op '
             'default; only Purchased and Failed clear _transactioing, Restored does not',
    0x6ee94: 'RBPurchaseManager -paymentQueue:removedTransactions:: enumerates and does nothing',
    0x6efb4: 'RBPurchaseManager -paymentQueueRestoreCompletedTransactionsFinished:: the tbz at '
             '0x6f158 loops back to 0x6f0b0 while addPurchaseCheckTransaction: is false',
    0x6f288: 'RBPurchaseManager -paymentQueue:restoreCompletedTransactionsFailedWithError:: '
             'isRestored cleared before transactioing, matching the two strb at 0x6f358/0x6f364',
    # RecommendAdData's archived-payload readers. Every __cfstring the class references was decoded
    # from its struct (flags/ptr/length) rather than from a decompiler label, which is what exposed
    # the four sub-key literals: the archive keys its entries by the fully qualified name, so the
    # inner objectForKey: takes 'ApplilinkRecommend.allAdData.list' and friends at 0x3722e0,
    # 0x372300, 0x372320, and 0x372340, not the bare sub-key we had. The daily-count reader's
    # formatter is 'yyyy/MM/dd' at 0x3724e0, with slashes, distinct from the 'yyyy-MM-dd HH:mm:ss'
    # at 0x372440 used by the term readers.
    0x226e90: 'RecommendAdData +getBannerDisplayStatusList: debug arm, then the qualified sub-key',
    0x226fbc: 'RecommendAdData +getAdModelSettingList: same shape, key at 0x372320',
    0x2270e8: 'RecommendAdData +getAdList: no debug arm, key at 0x3722e0',
    0x2271c4: 'RecommendAdData +getInterstitialSpecList: no debug arm, key at 0x372340',
    0x2272a0: 'RecommendAdData +getAdStatusByAdModel:: the fast-enumeration protocol has no back '
              'edge at 0x22742c, so it reads only the first record, as list[0] does',
    0x227460: 'RecommendAdData +getAdDataByAdId:: narrowed on ad_id, first record or nil',
    0x2277dc: 'RecommendAdData +getAdListByAdType:: narrowed on ad_type, returned unfiltered',
    0x2283c8: 'RecommendAdData +getLotteryBannerData: ad type 2, two count guards, arc4random at '
              '0x228448 modulo the count',
    0x228a18: 'RecommendAdData +getInterstitialSpecPriorityList: priority.intValue, ascending NO',
    0x229ce4: 'RecommendAdData +getAdDisplayCountDailyDictionary: yyyy/MM/dd day comparison',
    0x229ee0: 'RecommendAdData +getAdDisplayCountTotalDictionary: bare top-level defaults key',
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
    # Two defects fixed, both invented text: the title and message are the UTF-16 constants at
    # 0x36d1c0 and 0x36d1e0. Everything else held. The button titles are the globals at 0x3cfd50
    # and 0x3cfce0, which are g_pLocalizedRetry and g_pLocalizedOK at their declared addresses, and
    # the legacy arm's variadic really does carry one other title plus the nil that 0x146fb0 writes
    # to the stack.
    0x146D3C: 'RBErosionMarkUpdater -createAlertCancel: two arms, Default then Cancel actions',
    # Two defects fixed. The title is the UTF-16 constant at 0x36d200, not what we had. And the two
    # arms disagree about which string they use: 0x1471a0 reloads the literal for the controller
    # while 0x14738c passes the stringWithFormat: result, so that result reaches only the legacy
    # arm. The button titles are the globals at 0x3cfb80 and 0x3cfce0, g_pLocalizedCancel and
    # g_pLocalizedOK at their declared addresses, and the styles are Cancel then Default.
    0x147134: 'RBErosionMarkUpdater -createAlertConfirm: empty message, literal title on one arm',
    # Twelve defects fixed. The cbz at 0x145064 puts the UIAlertController arm on the fall-through
    # and the legacy arm at 0x1454ac, the opposite of how we had read it. Title and message were
    # both invented: they are the UTF-16 constants at 0x36d0c0 and 0x36d0e0. The medium and hard
    # configuration blocks are at 0x1466e4 and 0x1469d0; the addresses we carried, 0x146524 and
    # 0x146658, fall inside the basic block, which runs 0x1463f8..0x146658. The legacy container is
    # (5.0, rate * 85.0, pad ? 150.0 : 120.0, 0.0) from the fmov at 0x145608 and the pool at
    # 0x301820, 0x301028 and 0x2ef168, and it grows to rate * 290.0 (0x301808) by rate * 38.0
    # (0x2eeec0) per field, each field being rate * 260.0 wide (0x308cd8). Every field label
    # carries an ideographic space and its own name, 0x36d160, 0x36d180 and 0x36d1a0, where we had
    # an empty string. The origin and height are read back through the UIView(RB) x, y and height
    # accessors, not through -frame. The b.le at 0x14610c is the height > 0.0 guard, not a fourth
    # arm. The three modern blocks and both actions held, as did g_dCustomizeLayoutMetric100: the
    # label frames really do load 0x2ec6f8, which is 100.0.
    0x144FFC: 'RBErosionMarkUpdater -createAlertSetScore: two arms, three unrolled fields each',
    # The class-name argument every arm switches on is the ASCII constant at 0x36d0a0, and the cbz
    # that follows means the fall-through is the UIAlertController arm and the branch target is the
    # legacy one. The block at 0x14780c loads the weak self and sends pickerOpen (selref 0x3c4458).
    0x1474E4: 'RBErosionMarkUpdater -showAlertSetScore: empty message, then present or animate in',
    0x147868: 'RBErosionMarkUpdater -reshowAlertSetScore:: the same two arms carrying the message',
    0x147AF4: 'RBErosionMarkUpdater -showAlertCancel: legacy arm closes the picker and hides first',
    # One defect fixed: the three labels are padded to a common six-column width before the colon,
    # so the constants at 0x36d220, 0x36d240 and 0x36d260 are each 22 characters and ours had
    # dropped the padding from BASIC and HARD. Each appendFormat: really does take two arguments,
    # the base then the edit score, paired by the stp at 0x147d74, 0x147e00 and 0x147e8c.
    0x147C5C: 'RBErosionMarkUpdater -showAlertConfirm: validate, three padded lines, then two arms',
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
    # RBCampaignDetailViewController. The detail panel has a minimum height of viewHeight - 140
    # (0x2ec728) and the b.pl at 0xae18 chooses between honouring it and letting the content
    # exceed it. Both arms leave the copyright's bottom edge exactly on the panel's bottom.
    0xa970: 'RBCampaignDetailViewController -updateLayout: the fitting loop measures against '
            'MAXFLOAT (0x2ec748) and tests both dimensions (0xaad0..0xaadc), the label takes a '
            'fixed 50-point height, descriptionTop is the banner\'s maxY, and the copyright, '
            'divider and content size each keep their own width rather than the view\'s',
    # RBCampaignDetailViewController, continued. Two annotations in this class pointed one
    # instruction short, at the empty stub next door: 0x78bc and 0x79b0 are bare ret, and the
    # bodies they claimed are at 0x78c0 and 0x79b4.
    0x5b00: 'RBCampaignDetailViewController -loadView chains to super and does nothing else',
    0x6798: 'RBCampaignDetailViewController -showItemInfo unhides the four panels, then starts '
            'the artwork download only when loadedImage is false (tbz at 0x68a8)',
    0x6924: 'RBCampaignDetailViewController -loadInfo tail-calls -showItemInfo when bound',
    0x6fdc: 'RBCampaignDetailViewController -sampleViewStop alpha 0 via movi, indicator stopped, '
            'playing view hidden, status 0',
    0x70b4: 'RBCampaignDetailViewController -sampleViewDownloading alpha 1, indicator started, '
            'playing view hidden, status 1',
    0x7198: 'RBCampaignDetailViewController -sampleViewPlaying alpha 1, indicator stopped, '
            'playing view shown, status 2',
    0x74ec: 'RBCampaignDetailViewController -finishBgm: tail-calls -sampleStop',
    0x7508: 'RBCampaignDetailViewController -pushLink: opens the link only when it exists, '
            're-reading itemInfo for the open',
    0x78c0: 'RBCampaignDetailViewController -alertView:didDismissWithButtonIndex: runs only when '
            'closingFlag is clear (cbnz at 0x78e4 returns otherwise)',
    0x79b4: 'RBCampaignDetailViewController -alertViewCancel: the mirror image, running only when '
            'closingFlag is set (cbz at 0x79e4)',
    0x7e04: 'RBCampaignDetailViewController -didReceiveMemoryWarning chains to super only',
    0x7e38: 'RBCampaignDetailViewController -viewDidUnload chains to super then stops the artwork '
            'downloads',
    0x64f8: 'RBCampaignDetailViewController -setDownloadFlag:: a set flag forces buttonType 1, '
            'and the button is enabled on the inverse (cset eq at 0x6661c)',
    0x6684: 'RBCampaignDetailViewController -hasItem:itemID:: NO unless the type is 0, the tune '
            'is known to the manager, and its purchased path exists',
    0x6978: 'RBCampaignDetailViewController -sampleStart loads with push and loop, then plays '
            'with the 0.5f fade (fmov s0 at 0x6a4c), then shows the playing state',
    0x6ad4: 'RBCampaignDetailViewController -sampleStop: the -1 guard is the cmn at 0x6af8, the '
            'stop fade is the float32 0.2 at 0x2ec6b4, and the status is cleared either way',
    0x7aac: 'RBCampaignDetailViewController -didPresentAlertView: walks keyWindow to the '
            "presented controller's view and makes it exclusive-touch",
    0x7bec: 'RBCampaignDetailViewController -stopDownloadArtworks returns early on an empty map, '
            'else cancels and unhooks each downloader before emptying it',
    0xb370: 'RBCampaignDetailViewController -viewDidDisappear: chains to super only',
    0xb3a4: 'RBCampaignDetailViewController -willAnimateRotationToInterfaceOrientation:duration: '
            'chains to super then re-runs -updateLayout',
    # RBCampaignDetailViewController, the remaining eleven. The layout routine was the defective
    # one: the panel height, three label frames, both button frames, the sample overlay, the
    # detail block, the divider, and the copyright block were all misread, along with four of the
    # five artwork names (all use a slash, not an underscore) and six autoresizing masks
    # (0x22 is FlexibleWidth|FlexibleBottomMargin, not |FlexibleRightMargin).
    0x58fc: 'RBCampaignDetailViewController -initWithItemInfo: sets the navigation title to the '
            'inline literal at 0x361980 ("Gift") at 0x598c before binding the item, then '
            'overwrites it with campaignName when that exists',
    0x5b34: 'RBCampaignDetailViewController -setInfo:: campaignID goes straight to the ivar '
            '(offset variable 0x3c807c) at 0x5bd4, the levels format at 0x3619a0 is '
            '"LEVEL:  %d / %d / %d" with the three stack slots at 0x5d78/0x5d7c, the identifier '
            'format at 0x3619c0 is "%d" with the one slot at 0x5df4, the locked placeholder at '
            '0x3619e0 is six full-width question marks (UTF-16, length 6), and the nil arm at '
            '0x603c uses the pointer at 0x35b360 to "09_store/store_jacket_80"',
    0x6c08: 'RBCampaignDetailViewController -pushExternalLink: returns on a negative tag (tbnz at '
            '0x6c38), stops a playing sample, then opens the link when both it and the item exist',
    0x6dac: 'RBCampaignDetailViewController -pushButton: switches on itemInfo.buttonType through '
            'the jump table at 0x6fc8: 0 downloads the info, 1 falls through, 2 shows the terms, '
            '3 prompts to update, 4 opens the serial-code alert with style 2 and tag 1',
    0x7274: 'RBCampaignDetailViewController -handleTapArtworkView reads sampleStatus at the ivar '
            '(offset variable 0x3c8088), starting a download in state 0 and tail-calling '
            '-sampleViewDownloading, and cancelling then stopping in states 1 and 2',
    0x7648: 'RBCampaignDetailViewController -downloaderFinished: ignores a stale downloader, and '
            'in state 1 plays the data with no fade (movi at 0x7744) and takes row index 1',
    0x77fc: 'RBCampaignDetailViewController -downloaderError: ignores a stale downloader, else '
            'stops the sample, clears it, and shows the network error with a nil delegate',
    0x7e88: 'RBCampaignDetailViewController -dealloc cancels the sample downloader and stops the '
            'artwork downloaders before chaining to super',
    0x7f4c: 'RBCampaignDetailViewController -viewWillAppear:: closingFlag is cleared through the '
            'ivar (strb wzr at 0x7fa4); the panel is 140 tall (0x2ec6c0) and the detail block '
            'starts there; the name and artist rows are width-104 (0x2ec6d0) at y 8 and y 50, '
            'the levels row width-230 (0x2ec6e8) at y 70 (0x2ec6f0); both buttons are 104 wide '
            '(0x2ec700) at y 100, the download button at width-8-104 and the link button at '
            'width-16-208 (0x2ec710); the link button takes -setButtonColor: with green 0.3 '
            '(0x2ec718); the artwork shadow opacity is the float32 0.6 at 0x2ec6b8; the sample '
            'overlay is sized from the artwork frame at the origin and its indicator is half '
            'that, halved in single precision by the fcvt pair at 0x95e8, with style 0 '
            '(WhiteLarge); the detail panel is filled with the shared 0.8 (0x2ec6a0) and only '
            'bordered with 143/255 (0x2ec730); the divider is one point tall (fmov at 0x9f10); '
            'and the copyright block is 50 tall at the description height',
    0xa70c: 'RBCampaignDetailViewController -viewDidAppear: chains to super then loads the info '
            'when an item is bound',
    0xa780: 'RBCampaignDetailViewController -viewWillDisappear: sets closingFlag and reads the '
            'pack-info alert through the ivars (offset variables 0x3c808c and 0x3c8090), '
            'dismisses that alert, stops the sample, pops the pushed music, cancels the sample '
            'downloader, and tells the delegate the alert closed',
    # ApplilinkCore's UDID caches are three file statics in one block at 0x3df630: ad at +0x20,
    # udid at +0x28, old at +0x30. The accessors are bare loads and our offsets match.
    0x2150bc: 'ApplilinkCore +udid_cache bare load of the static at 0x3df658',
    0x2150cc: 'ApplilinkCore +ad_udid_cache bare load of the static at 0x3df650',
    0x2150dc: 'ApplilinkCore +old_udid_cache bare load of the static at 0x3df660',
    0x2157f8: 'ApplilinkCore +setAdUdid:: one stack slot at 0x21581c, so the %@ format takes the '
              'argument alone, then the old-UDID cache is cleared',
    # The key is 128 characters and was compared byte for byte against our literal, not eyeballed.
    0x215b2c: 'ApplilinkCore +signatureKey returns the constant at 0x371180',
    0x215b58: 'ApplilinkCore +versionDev: the stp at 0x215b88 puts "2.2.2" then "5" on the stack, '
              'so the %@.%@ format renders 2.2.2.5',
    # The six fan-outs share one shape: nil delegate returns, then the two-argument selector is
    # preferred but only when requestCode is non-zero, else the one-argument form.
    0x2161ec: 'ApplilinkCore +toDelegateDidStart:delegate: two-arm respondsToSelector: fan-out',
    0x2162d4: 'ApplilinkCore +toDelegateDidAppear:delegate: the same shape',
    0x2163bc: 'ApplilinkCore +toDelegateDidDisappear:delegate: the same shape',
    0x2164a4: 'ApplilinkCore +toDelegateFailOpenWithError:appParam:delegate: chains to '
              '+toDelegateFailWithError: afterwards (0x216594)',
    0x2165d8: 'ApplilinkCore +toDelegateFailLoadWithError:appParam:delegate: chains likewise '
              '(0x2166c8)',
    0x21670c: 'ApplilinkCore +toDelegateFailWithError:appParam:delegate: does NOT chain onwards',
    0x216814: 'ApplilinkCore +toDelegateFailLinkWithError:appParam:delegate: does not chain either',
    # RewardCore forwards the three lifecycle callbacks straight to ApplilinkCore, reading the
    # ivars directly: _applilinkParams at offset var 0x3c9a98 and the WEAK _applilinkDelegate at
    # 0x3c9aa4, which is loaded with objc_loadWeakRetained rather than a plain load.
    0x20b9e4: 'RewardCore -appListDidStart: tail-calls ApplilinkCore with _applilinkParams',
    0x20ba10: 'RewardCore -appListDidAppear: the same forward',
    0x20ba3c: 'RewardCore -appListDidDisappear: the same forward',
    0x20bb30: 'RewardCore -startedNotice one send, not two, with the weak delegate loaded first',
    0x20bb7c: 'RewardCore -openedNotice the same shape for appListDidAppear:',
    0x20bbc8: 'RewardCore -closeNotice sets the cancelled flag at 0x3df5d1 only when a view '
              'controller exists, then always clears the open flag at 0x3df5d0 before notifying',
    # RBSearchMapView, eighteen of the twenty-eight. The class's ivar offset variables are
    # m_IndicatorCount 0x3c8ce0 (+8), m_LoadedMaster 0x3c8cd8 (+12), m_LoadedImages 0x3c8cdc
    # (+13), m_LastRegion 0x3c8ce4 (+16, four doubles), m_IsObservingLocation 0x3c8cd0 (+48) and
    # m_FirstLocationObserved 0x3c8cd4 (+49), which is the order the reconstruction declares.
    0xdf494: 'RBSearchMapView -initWithFrame: makes the location manager and the 64-entry spot '
             'dictionary, zeroes the five state ivars, and calls -setupView',
    0xdf634: 'RBSearchMapView +rangeOfRegion: really is sqrt(latDelta^2 + latDelta^2) — the '
             'fmul at 0xdf634 squares d2 and the fadd doubles it, so the longitude delta in d3 '
             'is never read',
    0xdf644: 'RBSearchMapView +mapRectForCoordinateRegion: pushes the centre out by six tenths '
             'of each span (0x3015c8) to a north-west and a south-east corner, and returns the '
             'first corner with the absolute differences of the two',
    0xdf6c4: 'RBSearchMapView +currentLocationEnabled asks instancesRespondToSelector: at '
             '0xdf720 before reading the status once at 0xdf730, then compares against 4 or 3',
    0xe0aa4: 'RBSearchMapView -showError: sets the text, and only when the label is hidden fades '
             'it in over 0.3 (0x3010a0) from alpha 0; the block at 0xe0c68 captures self '
             'strongly (objc_retain at 0xe0bd0, plain ldr at 0xe0c74)',
    0xe0cd4: 'RBSearchMapView -requestList: returns unless m_LoadedImages is set, posts the '
             'centre and the immediate range 0.27 (mov/movk at 0xe0d2c) as three %.6f slots, '
             'and records the region in m_LastRegion at 0xe0e64 before starting the download',
    0xe0f4c: 'RBSearchMapView -pushCurrent centres the map on the user location, but only when '
             '+currentLocationEnabled says so',
    0xe1084: 'RBSearchMapView -locationManager:didChangeAuthorizationStatus: branches on whether '
             'the manager answers requestWhenInUseAuthorization: the new arm accepts status 3 or '
             '4 (sub/cmp at 0xe10c8) and always ends in -toggleTrackingMode, the old arm accepts '
             'only 3 and does not, and status 0 asks for authorisation',
    0xe1274: 'RBSearchMapView -observeValueForKeyPath:ofObject:change:context: unhooks itself '
             'and flips both observation ivars',
    0xe1350: 'RBSearchMapView -mapView:didChangeUserTrackingMode:animated: forwards mode != 0 to '
             'the delegate when it responds',
    0xe1430: 'RBSearchMapView -toggleTrackingMode shows the information alert unless location '
             'services and the authorisation status allow it, falls back to -pushCurrent when '
             'the map cannot set a tracking mode, and otherwise toggles between 1 and 0',
    0xe163c: 'RBSearchMapView -mapView:regionDidChangeAnimated: was an empty body and is 459 '
             'instructions: past a 0.26 longitude span (0x3015d8) it clears the annotations and '
             'shows the message label, else it prunes the annotations outside the map rect, adds '
             'the dictSpot entries inside it, and re-requests the list when the centre is inside '
             'the served box (0x3015e0/e8/f0/f8) and has moved past 0.15 degrees (0x301608)',
    0xe2620: 'RBSearchMapView -didPresentAlertView: walks keyWindow to the presented view and '
             'makes it exclusive-touch',
    0xe4848: 'RBSearchMapView -selectHideInfo: hides the three information views then re-requests '
             "the list for the map's current region",
    0xe496c: 'RBSearchMapView -initialView sets the region to 35.681382/139.766084 with a '
             '0.01004/0.01159 span (0x301610-0x301628) unanimated, then tail-calls -getMaster',
    0xe4ba4: 'RBSearchMapView -viewDidDisappear removes every annotation, stops showing the user '
             'location, and unhooks the map delegate',
    0xe503c: 'RBSearchMapView -addIndicator post-increments and starts the spinner when the old '
             'count was not negative (tbnz on the sign bit at 0xe505c)',
    0xe50b4: 'RBSearchMapView -subIndicator decrements first and stops the spinner on a single '
             'signed compare of the result (subs/b.gt at 0xe50cc)',
    # UIView(RB). -frame returns the rect in d0-d3 as (x, y, width, height), and each geometry
    # getter keeps exactly one of those registers: d0 at 0x1a35ac and 0x1a3668, d1 at 0x1a35b8 and
    # 0x1a3674, d2 at 0x1a36a8, d3 at 0x1a36c8. The two edge getters send -frame twice and add:
    # fadd d0,d8,d2 at 0x1a360c is x + width, fadd d0,d8,d3 at 0x1a3654 is y + height.
    0x1A35AC: 'UIView(RB) -left is frame.origin.x, a tail call keeping d0',
    0x1A35B8: 'UIView(RB) -top is frame.origin.y, keeping d1',
    0x1A35D8: 'UIView(RB) -right adds frame.size.width to frame.origin.x',
    0x1A3620: 'UIView(RB) -bottom adds frame.size.height to frame.origin.y',
    0x1A3668: 'UIView(RB) -x is frame.origin.x, a tail call keeping d0',
    0x1A3674: 'UIView(RB) -y is frame.origin.y, keeping d1',
    0x1A3694: 'UIView(RB) -width is frame.size.width, keeping d2',
    0x1A36B4: 'UIView(RB) -height is frame.size.height, keeping d3',
    # The flash shims are all tail calls that only rearrange registers. The literals are fmov
    # immediates (0x3f800000 is 1.0, 0x40800000 is 4.0) except the two pool loads, 0.333333343 at
    # 0x2fefb8 and 0.2 at 0x2ec6b4.
    0x1A36D4: 'UIView(RB) -SetFlashEffectDuration:Start:End: forwards with Rotate:NO (w3 = 0)',
    0x1A36F4: 'UIView(RB) -RemoveFlashEffect forwards to +removeFlashEffectView:',
    0x1A3710: 'UIView(RB) -SetFlashEffectFast forwards 0.333333343/1.0/0.2',
    0x1A3730: 'UIView(RB) -SetFlashEffectFastWithRotate forwards 4.0/1.0/0.2 with Rotate:YES',
    0x1A3760: 'UIView(RB) -SetFlashEffectSlow is only -RemoveFlashEffect, no animation at all',
    # One defect fixed. The multi-pulse loop sets both endpoints twice each pass: an fcsel pair at
    # 0x1a38e4 and 0x1a3920 picks start/end by the low bit of the step, and the arm the cbnz at
    # 0x1a3954 selects then sends -setFromValue:/-setToValue: again with the same two values. The
    # reconstruction had only the arm's pair. Control points are immediates but for 0.8 at
    # 0x2f856c, whose annotation sat on the 0.5 constant and now sits on its own.
    0x1A376C: 'UIView(RB) +setFlashEffectView:Duration:Start:End:Rotate: twelve pulses (cmp #0xc '
              'at 0x1a3ac8) over duration/12.0, mirrored control points on odd steps, plus a '
              '6.28318548 (0x310448) transform.rotation.z turn, grouped and repeated FLT_MAX times',
    0x1A3ECC: 'UIView(RB) +removeFlashEffectView: removes the FLUSH_ANIM key from view.layer',
    0x1A3F34: 'UIView(RB) -SetAlphaAnimationDuration:End: reads layer.opacity for the from value, '
              'assigns the end value to the layer first, then installs ALPHA_ANIM',
    0x1A40D8: 'UIView(RB) -RemoveAlphaAnimation removes the ALPHA_ANIM key',
    # The eight curve segments are one CGPathAddCurveToPoint each, the overshoot reaching the
    # control points as -40.0 from the pool at 0x2f8574 then the immediates -10.0 (0xc1200000),
    # -5.0 (0xc0a00000) and -2.0 (0xc0000000), the last four settling on baseY itself. The offsets
    # were CGFloat and are float: the binary adds in single precision (fadd s0) before the fcvt.
    0x1A4134: 'UIView(RB) -SetJumpEffectBaseX:BaseY: builds the PopAnim position path, duration '
              '3.0, control points 0.25/0.1 (0x2fd000)/0.5/0.5, released before -addAnimation:',
    0x1A4414: 'UIView(RB) -RemoveJumpEffect removes the PopAnim key',
    # NSFileManager(RB). The two existence checks share a body and differ only in the byte they
    # seed the isDirectory out-parameter with and the condition they close on: strb w8 (1) then
    # cset eq at 0x1c99b8, against strb wzr then cset ne at 0x1c9a6c.
    0x1C9954: 'NSFileManager(RB) +isFileExist: seeds isDirectory YES and requires it to come back '
              'clear',
    0x1C9A0C: 'NSFileManager(RB) +isDirectoryExist: seeds it NO and requires it to come back set',
    # Three defects fixed across this category, all in the same direction: the reconstruction was
    # tidier than the binary. Every -error: argument is the address of a local (add x5,sp,#0x8 at
    # 0x1c9b10, add x3,sp,#0x8 at 0x1c9bf4, sub x5,x29,#0x58 at 0x1c9f48), not nil.
    0x1C9AC0: 'NSFileManager(RB) +createDirectory: withIntermediateDirectories:YES, no attributes, '
              'error into a local',
    0x1C9B70: 'NSFileManager(RB) +isFreeSystemSize compares against 0x3200000 (50 MiB) with cset '
              'hi, so it is a strict greater-than',
    0x1C9BA0: 'NSFileManager(RB) +freeFileSystemSize measures the path the getter at 0x1a1624 '
              'returns, which is the global at 0x3df3b0, then valueForKey: the imported '
              'NSFileSystemFreeSize and -longLongValue',
    # The walk is an explicit -objectEnumerator/-nextObject pair (0x1c9db0 and 0x1c9e38), not fast
    # enumeration, and the error local lives outside the loop in x23. The attributes dictionary is
    # variadic: the stack writes from 0x1c9ec8 give the exact list, and only the modification-date
    # key is the Foundation symbol. The other four keys are constant strings spelled the same way,
    # at 0x36e920, 0x36e960, 0x36e980 and 0x36e9a0. The fourth object is nil, so the list really
    # terminates before the permissions and extension-hidden pairs.
    0x1C9CEC: 'NSFileManager(RB) +createDirectorysAtPath: chdir to / then one level per path '
              'component, creating what is missing and bailing out on the first failure',
    0x1CA0C8: 'NSFileManager(RB) +paddingDirName appends "padding" (0x36e9c0) to the documents '
              'path',
    # Two defects fixed. The search-path constants are w0 = 9 at 0x1ca170, so NSDocumentDirectory
    # and not the NSCachesDirectory claimed, and w0 = 0xd at 0x1ca3a0, so NSCachesDirectory and not
    # NSLibraryDirectory. Each getter also stores its global twice, the searched path at 0x1ca1a4
    # and the owned copy at 0x1ca1e0, rather than holding the first in a local.
    0x1CA130: 'NSFileManager(RB) +documentDirectoryPath is NSDocumentDirectory, synchronised on '
              '+[NSFileManager class]',
    0x1CA248: 'NSFileManager(RB) +applicationSupportDirectoryPath is 0xe, the same shape',
    0x1CA360: 'NSFileManager(RB) +cachesDirectoryPath is NSCachesDirectory, the same shape',
    0x1CA478: 'NSFileManager(RB) +temporaryDirectoryPath has no @synchronized and falls back to '
              '"Temporary Files" (0x36e9e0) under the caches path only when NSTemporaryDirectory '
              'returns nil',
    0x1CA560: 'NSFileManager(RB) +resourcePath copies mainBundle.resourcePath once, no lock',
    # NSString(RB), faithful throughout. The escaped set was decoded from the __cfstring at
    # 0x363f60 and is exactly the nineteen characters the reconstruction has, and the encoding is
    # the mov/movk pair at 0x1b82bc that builds 0x8000100, kCFStringEncodingUTF8.
    0x1B82A4: 'NSString(RB) -encodeURIComponent tail-calls CFURLCreateStringByAddingPercentEscapes '
              'with a nil unescaped set',
    # Every attribute dictionary is +dictionaryWithObjects:forKeys:count:, which is what a boxed
    # literal compiles to; the keys are the imported NSFontAttributeName and, where the count is
    # two, NSParagraphStyleAttributeName. Each of these carries a stack guard, and the CGSize and
    # CGRect arguments were read from d0-d3 rather than the printed form.
    0x1B82D0: 'NSString(RB) -sizeWithFont: one-entry dictionary into -sizeWithAttributes:',
    0x1B83C4: 'NSString(RB) -sizeWithFont:constrainedToSize: forwards x3 = 0, which is '
              'NSLineBreakByWordWrapping',
    0x1B83E4: 'NSString(RB) -sizeWithFont:constrainedToSize:lineBreakMode: pins the alignment to '
              'NSTextAlignmentLeft (x2 = 0 at 0x1b846c), asks for '
              'NSStringDrawingUsesLineFragmentOrigin, and keeps only d2/d3 of the bounding rect',
    0x1B8578: 'NSString(RB) -drawInRect:withFont: one-entry dictionary into '
              '-drawInRect:withAttributes:',
    0x1B8684: 'NSString(RB) -drawInRect:withFont:lineBreakMode:alignment: takes both the mode and '
              'the alignment from its arguments, unlike the sizing pair',
    0x1B881C: 'NSString(RB) -drawAtPoint:withFont: one-entry dictionary into '
              '-drawAtPoint:withAttributes:',
    # NSData(RB), faithful. Both methods inline the same version gate: -[UIDevice systemVersion]
    # compared against "4.0" (0x3643e0) with options 0x40, NSNumericSearch, and the cmn x8,#1 at
    # 0x1a44f4 sends only NSOrderedAscending down the CFPropertyListCreateFromXMLData arm. The
    # newer arm is CFPropertyListCreateWithData with x2 through x4 all zero, so the option really
    # is kCFPropertyListImmutable and both the format and error outputs are dropped.
    0x1A4470: 'NSData(RB) -dictionary returns nil unless the parsed plist is an NSDictionary, then '
              'copies it with +dictionaryWithDictionary:',
    0x1A45F8: 'NSData(RB) -mutableArray takes the NSArray branch instead and copies into a fresh '
              'NSMutableArray',
    # The rest of UIImage(RB). The lookup order was read from the branches: the cache, the theme
    # directory, "00_Share" (0x36e300), "%@/%@" (0x363880) against the primary then the fallback
    # lproj, and finally +imageNamedWithoutCache:. Both format calls were taken from the stack
    # writes and each has two specifiers and two arguments. The store back into the cache is
    # gated by eor w8,w20,#1 at 0x1a2b14, so useCache:NO really does skip it.
    0x1A2858: 'UIImage(RB) +imageWithName:useCache: five fallbacks in order, cache written last',
    # Two defects fixed. The gradient components are (0.0, 1.0, 1.0, 1.0) at 0x310428, two
    # grey/alpha pairs, not the (0.0, 0.0, 1.0, 1.0) the reconstruction had; and the drawing
    # options are w2 = 2 at 0x1a2e34, kCGGradientDrawsAfterEndLocation alone, not that ORed with
    # kCGGradientDrawsBeforeStartLocation. The flip is fmov d1 word 0x1e7e1001, imm8 0xf0, so
    # -1.0 and not the -4.0 the printed form suggests. Faithful and left alone: the scaled arm
    # re-sends -scale three times and -size twice rather than reusing one value.
    0x1A2C0C: 'UIImage(RB) -reflectedImageWithHeight: draws flipped into a premultiplied-last '
              'context, masks it with a one-pixel-wide greyscale gradient, and picks the '
              'scale-carrying +imageWithCGImage: only when -scale exists and is not 1.0',
    0x1A31A0: 'UIImage(RB) -colorMatrixFilterWithColor: falls back to -getWhite:alpha: and copies '
              'the white into all three channels (stp x8,x8 at 0x1a3208)',
    # One defect fixed. The four channel vectors are not set with -setValue:forKey: at all: the
    # stack writes from 0x1a3390 show one eleven-argument +filterWithName:keysAndValues: carrying
    # kCIInputImageKey and the four keys at 0x36e340, 0x36e360, 0x36e380 and 0x36e3a0, with the
    # stp x25,xzr at 0x1a3390 supplying the nil terminator.
    0x1A3268: 'UIImage(RB) -colorMatrixFilterWithRed:green:blue:alpha: builds the whole CIFilter '
              'in one variadic call, then sends -outputImage twice, once for the render and once '
              'for the extent',
    # Three one-method categories that had no reconstruction at all, each a two-instruction body.
    # A category does not name the class it extends, so each class was recovered from the import
    # its class field binds to: the field reads as an EXTERNAL address 0x100 apart per import, and
    # that ordering matches the undefined-symbol name table exactly, checked against the five
    # categories whose class was already known (NSArray, NSData, NSString, NSFileManager, UIView).
    0x20F48: 'SFSafariViewController(RB) -prefersStatusBarHidden is mov w0,#1 then ret',
    0x366F0: 'UITextView(RB) -canBecomeFirstResponder is mov w0,#0 then ret',
    0x88FB8: 'SKStoreProductViewController(RB) -prefersStatusBarHidden is mov w0,#1 then ret',
    # The last UIAlertView(RB) row. It reads as unreconstructed only because _selector_of cannot
    # spell showAddLimepointByApplilink::, whose second keyword is empty; the reconstruction is
    # there. Both cache slots were resolved from the initialiser blocks that fill them: 0x1003cfe00
    # is written at 0x119f0 from the key at 0x362680, "App Installed Reward", and 0x1003cfe08 at
    # 0x11a3c from 0x3626a0, "\"%d Lime Point\" has been Added.". One specifier, and the str x20 at
    # 0xf194 is the one variadic argument. The cancel title is not a cache slot but an inline
    # -localizedStringForKey:"OK" value:"" table:nil at 0xf1fc.
    0xF150: 'UIAlertView(RB) +showAddLimepointByApplilink:: nil otherButtonTitles (x6 = 0), then '
            '-show, then the alert is returned',
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
    # The selector may start on the line after the return type, which clang-format does when the
    # first keyword is long, so the text after the type is allowed to be empty and joined below.
    method = re.compile(r'^\s*([-+])\s*\([^)]*\)\s*(.*)$')
    prop = re.compile(r'^\s*@property\s*(?:\(([^)]*)\))?\s*.*?([A-Za-z_]\w*)\s*;')
    files = []
    for pattern in ('Project/**/*.m', 'Project/**/*.mm', 'Project/**/*.h', '3rdparty/**/*.m',
                    '3rdparty/**/*.mm', '3rdparty/**/*.h'):
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
                # clang-format puts one keyword per line, so a twelve-parameter selector such as
                # +[History hashScoreforTune:…Hash:] spans a dozen lines.
                while '{' not in chunk and ';' not in chunk and cursor - index < 24:
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
            # A long @property clang-format wraps onto the following lines, so join continuations
            # up to the terminating semicolon before matching.
            if line.lstrip().startswith('@property') and ';' not in line:
                joined = line
                cursor = index
                while ';' not in joined and cursor - index < 8:
                    cursor += 1
                    if cursor >= len(lines):
                        break
                    joined += ' ' + lines[cursor].strip()
                line = joined
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
    """
    Build a selector from a method signature's text after the return type.

    A selector part may be unnamed, as in ``-(void)createContext:(int)w:(int)h``, whose selector is
    ``createContext::``. The identifier before such a colon is the *previous* part's parameter
    name, not a keyword, and is told apart by directly following the parameter's closing
    parenthesis.
    """
    text = signature.split('{')[0].split(';')[0].strip()
    if ':' not in text:
        return re.split(r'[\s(]', text)[0]
    parts: list[str] = []
    depth = 0
    word = ''
    after_type = False
    for char in text:
        if char == '(':
            depth += 1
            word = ''
            continue
        if char == ')':
            depth -= 1
            if depth == 0:
                after_type = True
                word = ''
            continue
        if depth:
            continue
        if char == ':':
            # A word that came straight after a parameter type is that parameter's name, so this
            # selector part carries no keyword.
            parts.append('' if after_type else word)
            word = ''
            after_type = False
            continue
        if char.isalnum() or char == '_':
            word += char
        else:
            word = ''
            after_type = False
    return ''.join(f'{part}:' for part in parts)


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
        # The selector-alone fallback exists only for category rows, whose class the binary never
        # names. Letting it answer for a real class credits that class with any same-named selector
        # a category happens to define, which is how -[StoreExtendNoteView reset] read as
        # reconstructed while no such override existed.
        is_reconstructed = ((m.class_name, m.kind, m.selector) in keyed
                            or (m.class_name.startswith('(')
                                and (m.kind, m.selector) in loose))
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


def check_verified_keys_unique() -> list[str]:
    """Report any address keyed more than once in the VERIFIED literal.

    A duplicate key in a dict literal is silent: Python keeps the last and discards the earlier
    value, so one method's recorded evidence disappears with no error and no change in the count.
    That happened twice before this check existed. The dict itself cannot show it, so the source
    is re-read and the keys counted.
    """
    source = Path(__file__).read_text()
    body = re.search(r'^VERIFIED\s*=\s*\{(.*?)^\}', source, re.S | re.M)
    if not body:
        return []
    seen, duplicates = set(), []
    for match in re.finditer(r'^\s*(0x[0-9a-fA-F]+)\s*:', body.group(1), re.M):
        address = int(match.group(1), 16)
        if address in seen:
            duplicates.append(f'{address:#x} is keyed more than once in VERIFIED')
        seen.add(address)
    return duplicates


def main(argv=None) -> int:
    """Regenerate the checklist."""
    duplicates = check_verified_keys_unique()
    if duplicates:
        for problem in duplicates:
            print(f'error: {problem}', file=sys.stderr)
        return 1
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
