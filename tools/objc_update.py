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
    0x1ba8c0: 'RBExperienceData -unlockWithType:ID:: the jump table at 0x1ba954 gives 0-4, 7 and '
              '10, with 5, 6, 8 and 9 falling to the b.hi #0xa default that returns NO',
    0x1f7594: 'RBUserSettingData -setThema:: b.ls is unsigned, all six fallback defaults, the '
              'nine coder keys in order, and the trailing switch that leaves an unknown theme '
              "alone; the binary re-sends customizeItems per key where the source caches it, "
              'and sends objectAtIndex:/objectForKey: where the style rules require subscripting',
    0x20084c: 'RBNumberLabel -setNumber:: compares, stores, then redraws',
    0x200874: 'RBNumberLabel -setImageType:: the same shape on a 64-bit ivar',
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
