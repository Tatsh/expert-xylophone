# Objective-C methods to verify

Every Objective-C method the binary defines, from its own runtime metadata. Nothing Apple ships
appears here: a framework's classes live in the framework, so the only Apple-derived rows are the
categories this application adds to Apple classes, which are its own code. The
163 `.cxx_construct`/`.cxx_destruct` methods the compiler emits for ARC-managed and C++-typed
ivars are counted and excluded, since they have no reconstruction and never will.

`Reconstructed` is whether a reconstruction exists in the source tree, either an explicit
definition in the class's `@implementation` or a `@property` that synthesises it. `Verified` is
whether that reconstruction has been read against the disassembly, per the five-step process in
[.claude/rules/reconstruction.md](.claude/rules/reconstruction.md). **The two are independent, and
the gap between them is the point of this file.** `prop` marks a method a property list synthesises.

A category cannot be attributed to the class it extends: that class is reached through a reference
the linker binds at load time, so the file never names it, and a category's own name is the
category's. Those rows carry the category name in parentheses and are matched on the selector alone.

Total: 6343 — 6201 reconstructed, 3962 verified
(62.5%).
3260 are property accessors. Two mechanical passes account for most of the verified
count and record their evidence per address: `tools/objc_verify_accessors.py` shows an accessor
moves exactly the ivar its property declares, and `tools/objc_verify_trivial.py` shows an empty or
constant-returning body agrees with its reconstruction. Everything else was read by hand.

Regenerate with `tools/objc_update.py <binary>`, where the binary is the one **inside the .ipa**;
the unpacked copy under `rb458orig` is a different build and matches nothing.

| Class | Kind | Selector | Prop | Reconstructed | Verified | Address |
| ----- | :--: | -------- | :--: | :-----------: | :------: | ------- |
| `RBMusicHistoryView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x480c` |
| `RBMusicHistoryView` | `-` | `CreateView` |  | ✅ | ❌ | `0x4980` |
| `RBMusicHistoryView` | `-` | `createGraphData` |  | ✅ | ❌ | `0x4b98` |
| `RBMusicHistoryView` | `-` | `drawRect:` |  | ✅ | ✅ | `0x4e3c` |
| `RBMusicHistoryView` | `-` | `showAnimation:difficulty:` |  | ✅ | ❌ | `0x4e40` |
| `RBMusicHistoryView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x5010` |
| `RBMusicHistoryView` | `-` | `musicID` | prop | ✅ | ✅ | `0x5368` |
| `RBMusicHistoryView` | `-` | `setMusicID:` | prop | ✅ | ✅ | `0x5378` |
| `RBMusicHistoryView` | `-` | `difficulty` | prop | ✅ | ✅ | `0x5388` |
| `RBMusicHistoryView` | `-` | `setDifficulty:` | prop | ✅ | ✅ | `0x5398` |
| `RBMusicHistoryView` | `-` | `m_IsAnimation` | prop | ✅ | ✅ | `0x53a8` |
| `RBMusicHistoryView` | `-` | `setM_IsAnimation:` | prop | ✅ | ✅ | `0x53b8` |
| `RBMusicHistoryView` | `-` | `graphSheetView` | prop | ✅ | ✅ | `0x53c8` |
| `RBMusicHistoryView` | `-` | `setGraphSheetView:` | prop | ✅ | ✅ | `0x53d8` |
| `RBMusicHistoryView` | `-` | `graphView` | prop | ✅ | ✅ | `0x5410` |
| `RBMusicHistoryView` | `-` | `setGraphView:` | prop | ✅ | ✅ | `0x5420` |
| `RBMusicHistoryView` | `-` | `dataArray` | prop | ✅ | ✅ | `0x5458` |
| `RBMusicHistoryView` | `-` | `setDataArray:` | prop | ✅ | ✅ | `0x5468` |
| `RBMusicHistoryView` | `-` | `pointViewArray` | prop | ✅ | ✅ | `0x54a0` |
| `RBMusicHistoryView` | `-` | `setPointViewArray:` | prop | ✅ | ✅ | `0x54b0` |
| `RBUrlSchemeStoreController` | `-` | `action:query:` |  | ✅ | ❌ | `0x5550` |
| `RBUrlSchemeStoreController` | `-` | `packRbAction:` |  | ✅ | ❌ | `0x5668` |
| `RBUrlSchemeStoreController` | `-` | `campaignRbAction:` |  | ✅ | ❌ | `0x5744` |
| `RBUrlSchemeStoreController` | `-` | `seqRbAction:` |  | ✅ | ❌ | `0x5820` |
| `RBCampaignDetailViewController` | `-` | `initWithItemInfo:` |  | ✅ | ❌ | `0x58fc` |
| `RBCampaignDetailViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x5b00` |
| `RBCampaignDetailViewController` | `-` | `setInfo:` |  | ✅ | ❌ | `0x5b34` |
| `RBCampaignDetailViewController` | `-` | `setDownloadFlag:` |  | ✅ | ❌ | `0x64f8` |
| `RBCampaignDetailViewController` | `-` | `hasItem:itemID:` |  | ✅ | ❌ | `0x6684` |
| `RBCampaignDetailViewController` | `-` | `showItemInfo` |  | ✅ | ❌ | `0x6798` |
| `RBCampaignDetailViewController` | `-` | `loadInfo` |  | ✅ | ❌ | `0x6924` |
| `RBCampaignDetailViewController` | `-` | `sampleStart` |  | ✅ | ❌ | `0x6978` |
| `RBCampaignDetailViewController` | `-` | `sampleStop` |  | ✅ | ❌ | `0x6ad4` |
| `RBCampaignDetailViewController` | `-` | `pushExternalLink:` |  | ✅ | ❌ | `0x6c08` |
| `RBCampaignDetailViewController` | `-` | `pushButton:` |  | ✅ | ❌ | `0x6dac` |
| `RBCampaignDetailViewController` | `-` | `sampleViewStop` |  | ✅ | ❌ | `0x6fdc` |
| `RBCampaignDetailViewController` | `-` | `sampleViewDownloading` |  | ✅ | ❌ | `0x70b4` |
| `RBCampaignDetailViewController` | `-` | `sampleViewPlaying` |  | ✅ | ❌ | `0x7198` |
| `RBCampaignDetailViewController` | `-` | `handleTapArtworkView` |  | ✅ | ❌ | `0x7274` |
| `RBCampaignDetailViewController` | `-` | `finishBgm:` |  | ✅ | ❌ | `0x74ec` |
| `RBCampaignDetailViewController` | `-` | `pushLink:` |  | ✅ | ❌ | `0x7508` |
| `RBCampaignDetailViewController` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x7648` |
| `RBCampaignDetailViewController` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x77fc` |
| `RBCampaignDetailViewController` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x78b4` |
| `RBCampaignDetailViewController` | `-` | `itemInfoDownload` |  | ✅ | ✅ | `0x78b8` |
| `RBCampaignDetailViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ✅ | `0x78bc` |
| `RBCampaignDetailViewController` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ❌ | `0x78c0` |
| `RBCampaignDetailViewController` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x79b0` |
| `RBCampaignDetailViewController` | `-` | `alertViewCancel:` |  | ✅ | ❌ | `0x79b4` |
| `RBCampaignDetailViewController` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0x7aac` |
| `RBCampaignDetailViewController` | `-` | `stopDownloadArtworks` |  | ✅ | ❌ | `0x7bec` |
| `RBCampaignDetailViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x7df4` |
| `RBCampaignDetailViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ❌ | `0x7e04` |
| `RBCampaignDetailViewController` | `-` | `viewDidUnload` |  | ✅ | ❌ | `0x7e38` |
| `RBCampaignDetailViewController` | `-` | `dealloc` |  | ✅ | ❌ | `0x7e88` |
| `RBCampaignDetailViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x7f4c` |
| `RBCampaignDetailViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0xa70c` |
| `RBCampaignDetailViewController` | `-` | `viewWillDisappear:` |  | ✅ | ❌ | `0xa780` |
| `RBCampaignDetailViewController` | `-` | `updateLayout` |  | ✅ | ❌ | `0xa970` |
| `RBCampaignDetailViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0xb370` |
| `RBCampaignDetailViewController` | `-` | `willAnimateRotationToInterfaceOrientation:duration:` |  | ✅ | ❌ | `0xb3a4` |
| `RBCampaignDetailViewController` | `-` | `itemInfo` | prop | ✅ | ✅ | `0xb3f4` |
| `RBCampaignDetailViewController` | `-` | `setItemInfo:` | prop | ✅ | ✅ | `0xb404` |
| `RBCampaignDetailViewController` | `-` | `delegate` | prop | ✅ | ✅ | `0xb43c` |
| `RBCampaignDetailViewController` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0xb45c` |
| `RBCampaignDetailViewController` | `-` | `workingIndex` | prop | ✅ | ✅ | `0xb470` |
| `RBCampaignDetailViewController` | `-` | `setWorkingIndex:` | prop | ✅ | ✅ | `0xb480` |
| `RBCampaignDetailViewController` | `-` | `mainView` | prop | ✅ | ✅ | `0xb490` |
| `RBCampaignDetailViewController` | `-` | `setMainView:` | prop | ✅ | ✅ | `0xb4a0` |
| `RBCampaignDetailViewController` | `-` | `itemView` | prop | ✅ | ✅ | `0xb4d8` |
| `RBCampaignDetailViewController` | `-` | `setItemView:` | prop | ✅ | ✅ | `0xb4e8` |
| `RBCampaignDetailViewController` | `-` | `artworkView` | prop | ✅ | ✅ | `0xb520` |
| `RBCampaignDetailViewController` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0xb530` |
| `RBCampaignDetailViewController` | `-` | `labelItemName` | prop | ✅ | ✅ | `0xb568` |
| `RBCampaignDetailViewController` | `-` | `setLabelItemName:` | prop | ✅ | ✅ | `0xb578` |
| `RBCampaignDetailViewController` | `-` | `labelArtistName` | prop | ✅ | ✅ | `0xb5b0` |
| `RBCampaignDetailViewController` | `-` | `setLabelArtistName:` | prop | ✅ | ✅ | `0xb5c0` |
| `RBCampaignDetailViewController` | `-` | `labelLevels` | prop | ✅ | ✅ | `0xb5f8` |
| `RBCampaignDetailViewController` | `-` | `setLabelLevels:` | prop | ✅ | ✅ | `0xb608` |
| `RBCampaignDetailViewController` | `-` | `labelID` | prop | ✅ | ✅ | `0xb640` |
| `RBCampaignDetailViewController` | `-` | `setLabelID:` | prop | ✅ | ✅ | `0xb650` |
| `RBCampaignDetailViewController` | `-` | `downloadBtn` | prop | ✅ | ✅ | `0xb688` |
| `RBCampaignDetailViewController` | `-` | `setDownloadBtn:` | prop | ✅ | ✅ | `0xb698` |
| `RBCampaignDetailViewController` | `-` | `linkBtn` | prop | ✅ | ✅ | `0xb6d0` |
| `RBCampaignDetailViewController` | `-` | `setLinkBtn:` | prop | ✅ | ✅ | `0xb6e0` |
| `RBCampaignDetailViewController` | `-` | `campaignID` | prop | ✅ | ✅ | `0xb718` |
| `RBCampaignDetailViewController` | `-` | `setCampaignID:` | prop | ✅ | ✅ | `0xb728` |
| `RBCampaignDetailViewController` | `-` | `sampleDownloader` | prop | ✅ | ✅ | `0xb738` |
| `RBCampaignDetailViewController` | `-` | `setSampleDownloader:` | prop | ✅ | ✅ | `0xb748` |
| `RBCampaignDetailViewController` | `-` | `indicator` | prop | ✅ | ✅ | `0xb780` |
| `RBCampaignDetailViewController` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0xb790` |
| `RBCampaignDetailViewController` | `-` | `sampleView` | prop | ✅ | ✅ | `0xb7c8` |
| `RBCampaignDetailViewController` | `-` | `setSampleView:` | prop | ✅ | ✅ | `0xb7d8` |
| `RBCampaignDetailViewController` | `-` | `playingView` | prop | ✅ | ✅ | `0xb810` |
| `RBCampaignDetailViewController` | `-` | `setPlayingView:` | prop | ✅ | ✅ | `0xb820` |
| `RBCampaignDetailViewController` | `-` | `samplePlayedIndex` | prop | ✅ | ✅ | `0xb858` |
| `RBCampaignDetailViewController` | `-` | `setSamplePlayedIndex:` | prop | ✅ | ✅ | `0xb868` |
| `RBCampaignDetailViewController` | `-` | `labelLoading` | prop | ✅ | ✅ | `0xb878` |
| `RBCampaignDetailViewController` | `-` | `setLabelLoading:` | prop | ✅ | ✅ | `0xb888` |
| `RBCampaignDetailViewController` | `-` | `accessingIndicator` | prop | ✅ | ✅ | `0xb8c0` |
| `RBCampaignDetailViewController` | `-` | `setAccessingIndicator:` | prop | ✅ | ✅ | `0xb8d0` |
| `RBCampaignDetailViewController` | `-` | `accessingLabel` | prop | ✅ | ✅ | `0xb908` |
| `RBCampaignDetailViewController` | `-` | `setAccessingLabel:` | prop | ✅ | ✅ | `0xb918` |
| `RBCampaignDetailViewController` | `-` | `artworkDownloaders` | prop | ✅ | ✅ | `0xb950` |
| `RBCampaignDetailViewController` | `-` | `setArtworkDownloaders:` | prop | ✅ | ✅ | `0xb960` |
| `RBCampaignDetailViewController` | `-` | `packinfoDownloadAlertView` | prop | ✅ | ✅ | `0xb998` |
| `RBCampaignDetailViewController` | `-` | `setPackinfoDownloadAlertView:` | prop | ✅ | ✅ | `0xb9a8` |
| `RBCampaignDetailViewController` | `-` | `closingFlag` | prop | ✅ | ✅ | `0xb9e0` |
| `RBCampaignDetailViewController` | `-` | `setClosingFlag:` | prop | ✅ | ✅ | `0xb9f0` |
| `RBCampaignDetailViewController` | `-` | `detailView` | prop | ✅ | ✅ | `0xba00` |
| `RBCampaignDetailViewController` | `-` | `setDetailView:` | prop | ✅ | ✅ | `0xba10` |
| `RBCampaignDetailViewController` | `-` | `bannerView` | prop | ✅ | ✅ | `0xba48` |
| `RBCampaignDetailViewController` | `-` | `setBannerView:` | prop | ✅ | ✅ | `0xba58` |
| `RBCampaignDetailViewController` | `-` | `descriptionTextView` | prop | ✅ | ✅ | `0xba90` |
| `RBCampaignDetailViewController` | `-` | `setDescriptionTextView:` | prop | ✅ | ✅ | `0xbaa0` |
| `RBCampaignDetailViewController` | `-` | `lineView` | prop | ✅ | ✅ | `0xbad8` |
| `RBCampaignDetailViewController` | `-` | `setLineView:` | prop | ✅ | ✅ | `0xbae8` |
| `RBCampaignDetailViewController` | `-` | `copyrightView` | prop | ✅ | ✅ | `0xbb20` |
| `RBCampaignDetailViewController` | `-` | `setCopyrightView:` | prop | ✅ | ✅ | `0xbb30` |
| `RBCampaignDetailViewController` | `-` | `indicatorSample` | prop | ✅ | ✅ | `0xbb68` |
| `RBCampaignDetailViewController` | `-` | `setIndicatorSample:` | prop | ✅ | ✅ | `0xbb78` |
| `StoreButtonView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xbddc` |
| `StoreButtonView` | `-` | `buttonColor` | prop | ✅ | ❌ | `0xc138` |
| `StoreButtonView` | `-` | `setButtonColor:` | prop | ✅ | ❌ | `0xc194` |
| `StoreButtonView` | `-` | `disabledColor` | prop | ✅ | ❌ | `0xc208` |
| `StoreButtonView` | `-` | `setDisabledColor:` | prop | ✅ | ❌ | `0xc264` |
| `StoreButtonView` | `-` | `cornerRadius` | prop | ✅ | ❌ | `0xc2d8` |
| `StoreButtonView` | `-` | `setCornerRadius:` | prop | ✅ | ❌ | `0xc2e8` |
| `StoreButtonView` | `-` | `highlightColor:factor:` |  | ✅ | ❌ | `0xc300` |
| `StoreButtonView` | `-` | `setHighlighted:` |  | ✅ | ❌ | `0xc348` |
| `StoreButtonView` | `-` | `setSelected:` |  | ✅ | ❌ | `0xc3d4` |
| `StoreButtonView` | `-` | `drawRect:` |  | ✅ | ❌ | `0xc460` |
| `StoreButtonView` | `-` | `dealloc` |  | ✅ | ❌ | `0xcc08` |
| `RBMenuBGEffectPartView` | `-` | `init` |  | ✅ | ❌ | `0xcce0` |
| `RBMenuBGEffectPartView` | `-` | `setupView` |  | ✅ | ❌ | `0xcd98` |
| `RBMenuBGEffectPartView` | `-` | `startAnimation` |  | ✅ | ❌ | `0xd2a8` |
| `RBMenuBGEffectPartView` | `-` | `setAnimationLoopFlag:` |  | ✅ | ✅ | `0xd810` |
| `RBMenuBGEffectPartView` | `-` | `stopAnimation` |  | ✅ | ❌ | `0xd81c` |
| `RBMenuBGEffectPartView` | `-` | `removeFromSuperview` |  | ✅ | ❌ | `0xd934` |
| `RBMenuBGEffectPartView` | `-` | `image1Path` | prop | ✅ | ✅ | `0xd968` |
| `RBMenuBGEffectPartView` | `-` | `setImage1Path:` | prop | ✅ | ✅ | `0xd978` |
| `RBMenuBGEffectPartView` | `-` | `image2Path` | prop | ✅ | ✅ | `0xd9b0` |
| `RBMenuBGEffectPartView` | `-` | `setImage2Path:` | prop | ✅ | ✅ | `0xd9c0` |
| `RBMenuBGEffectPartView` | `-` | `image3Path` | prop | ✅ | ✅ | `0xd9f8` |
| `RBMenuBGEffectPartView` | `-` | `setImage3Path:` | prop | ✅ | ✅ | `0xda08` |
| `RBMenuBGEffectPartView` | `-` | `effect` | prop | ✅ | ✅ | `0xda40` |
| `RBMenuBGEffectPartView` | `-` | `setEffect:` | prop | ✅ | ✅ | `0xda50` |
| `RBMenuBGEffectPartView` | `-` | `image1` | prop | ✅ | ✅ | `0xda88` |
| `RBMenuBGEffectPartView` | `-` | `setImage1:` | prop | ✅ | ✅ | `0xda98` |
| `RBMenuBGEffectPartView` | `-` | `image2` | prop | ✅ | ✅ | `0xdad0` |
| `RBMenuBGEffectPartView` | `-` | `setImage2:` | prop | ✅ | ✅ | `0xdae0` |
| `RBMenuBGEffectPartView` | `-` | `image3` | prop | ✅ | ✅ | `0xdb18` |
| `RBMenuBGEffectPartView` | `-` | `setImage3:` | prop | ✅ | ✅ | `0xdb28` |
| `RBMenuBGEffectPartView` | `-` | `isAnimation` | prop | ✅ | ✅ | `0xdb60` |
| `RBMenuBGEffectPartView` | `-` | `setIsAnimation:` | prop | ✅ | ✅ | `0xdb70` |
| `RBMenuBGEffectPartView` | `-` | `isAnimationEnableLoop` | prop | ✅ | ✅ | `0xdb80` |
| `RBMenuBGEffectPartView` | `-` | `setIsAnimationEnableLoop:` | prop | ✅ | ✅ | `0xdb90` |
| `RBMenuBGEffectPartView` | `-` | `m_screenSize` | prop | ✅ | ✅ | `0xdba0` |
| `RBMenuBGEffectPartView` | `-` | `setM_screenSize:` | prop | ✅ | ✅ | `0xdbc0` |
| `(RB)` | `+` | `deleteAlertViewWithDelegate:` |  | ✅ | ❌ | `0xdc98` |
| `(RB)` | `+` | `strageAlertView` |  | ✅ | ❌ | `0xdd38` |
| `(RB)` | `+` | `showRestoreDownloadWithDelegate:` |  | ✅ | ❌ | `0xdd94` |
| `(RB)` | `+` | `showRestoreMessageWithDelegate:` |  | ✅ | ❌ | `0xde64` |
| `(RB)` | `+` | `showGameCenterError` |  | ✅ | ❌ | `0xdf34` |
| `(RB)` | `+` | `showNetworkErrorWithDelegate:` |  | ✅ | ❌ | `0xdfc0` |
| `(RB)` | `+` | `showDownloadErrorWithDelegate:` |  | ✅ | ❌ | `0xe090` |
| `(RB)` | `+` | `showTakeoverMessage` |  | ✅ | ❌ | `0xe158` |
| `(RB)` | `+` | `showInfomation` |  | ✅ | ❌ | `0xe1e4` |
| `(RB)` | `+` | `showMapWithTitle:delegate:` |  | ✅ | ❌ | `0xe270` |
| `(RB)` | `+` | `showWithErrorMessage:delegate:` |  | ✅ | ❌ | `0xe358` |
| `(RB)` | `+` | `showConnectRetryWithErrorMessage:delegate:` |  | ✅ | ❌ | `0xe42c` |
| `(RB)` | `+` | `showConnectRetryOrCancel:` |  | ✅ | ❌ | `0xe514` |
| `(RB)` | `+` | `showUnlockedMusicInfoWithDelegate:musicName:` |  | ✅ | ❌ | `0xe5e4` |
| `(RB)` | `+` | `showSelectPurchaseLimitTypeWithDelegate:` |  | ✅ | ❌ | `0xe6e8` |
| `(RB)` | `+` | `showPurchaseOverMessageWithDelegate:` |  | ✅ | ❌ | `0xe93c` |
| `(RB)` | `+` | `showUnlockTermsDescription2:` |  | ✅ | ❌ | `0xea50` |
| `(RB)` | `+` | `showAlertUpdateForUnlock:` |  | ✅ | ❌ | `0xebc0` |
| `(RB)` | `+` | `showAlertShortageOfPoint` |  | ✅ | ❌ | `0xed10` |
| `(RB)` | `+` | `showAlertLatestApplication:` |  | ✅ | ❌ | `0xee34` |
| `(RB)` | `+` | `showDownloadWithDelegate:` |  | ✅ | ❌ | `0xef18` |
| `(RB)` | `+` | `showAlertNeedResourceUpdate:` |  | ✅ | ❌ | `0xeffc` |
| `(RB)` | `+` | `showAddLimepointByApplilink::` |  | ❌ | ❌ | `0xf150` |
| `(RB)` | `+` | `showAlertNeedDownloadMusicNameList:` |  | ✅ | ❌ | `0xf2e0` |
| `(RB)` | `+` | `showColetteThemaUnlockMessage` |  | ✅ | ❌ | `0xf3e4` |
| `(RB)` | `+` | `showSerialcodeDialog:` |  | ✅ | ❌ | `0xf588` |
| `(RB)` | `+` | `setExclusiveTouchForView:` |  | ✅ | ❌ | `0xf764` |
| `(RB)` | `+` | `showPurchasePack:delegate:` |  | ✅ | ❌ | `0xf8cc` |
| `(RB)` | `+` | `showMovePackDetailToExtendDetail:` |  | ✅ | ❌ | `0xf9e0` |
| `(RB)` | `+` | `showAlertNotFoundMusics:` |  | ✅ | ❌ | `0xfa84` |
| `(RB)` | `+` | `showAlertUpdateErosionMark:` |  | ✅ | ❌ | `0xfcb0` |
| `StoreExtendNoteCell` | `-` | `initWithStyle:reuseIdentifier:` |  | ✅ | ❌ | `0xfdb8` |
| `UnZipArchive` | `-` | `init` |  | ❌ | ❌ | `0x14d40` |
| `UnZipArchive` | `-` | `dealloc` |  | ❌ | ❌ | `0x14d84` |
| `UnZipArchive` | `-` | `openFile:` |  | ❌ | ❌ | `0x14e08` |
| `UnZipArchive` | `-` | `closeFile` |  | ❌ | ❌ | `0x14ec8` |
| `UnZipArchive` | `-` | `getEntryNum` |  | ❌ | ❌ | `0x14efc` |
| `UnZipArchive` | `-` | `getData:` |  | ❌ | ❌ | `0x14f24` |
| `UnZipArchive` | `-` | `setFirst` |  | ❌ | ❌ | `0x1503c` |
| `UnZipArchive` | `-` | `setNext` |  | ❌ | ❌ | `0x15070` |
| `UnZipArchive` | `-` | `getCurrentFileName` |  | ❌ | ❌ | `0x150a4` |
| `UnZipArchive` | `-` | `getCurrentData` |  | ❌ | ❌ | `0x1519c` |
| `BFCodec` | `-` | `init` |  | ✅ | ❌ | `0x1529c` |
| `BFCodec` | `-` | `cipherInit:keyLength:` |  | ✅ | ❌ | `0x1534c` |
| `BFCodec` | `-` | `cipherInit:` |  | ✅ | ❌ | `0x153c0` |
| `BFCodec` | `-` | `encipher:` |  | ✅ | ❌ | `0x15450` |
| `BFCodec` | `-` | `decipher:` |  | ✅ | ❌ | `0x156f4` |
| `BFCodec` | `-` | `dealloc` |  | ✅ | ❌ | `0x159c8` |
| `GraphCircleView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x15d40` |
| `GraphCircleView` | `-` | `CreateView` |  | ✅ | ❌ | `0x15e18` |
| `GraphCircleView` | `-` | `setOption:dotSize:lineColor:lineSize:` |  | ✅ | ❌ | `0x15edc` |
| `GraphCircleView` | `-` | `setData:maxValue:` |  | ✅ | ❌ | `0x1605c` |
| `GraphCircleView` | `-` | `setData:maxValue:isMovableMinLine:` |  | ✅ | ❌ | `0x1607c` |
| `GraphCircleView` | `-` | `drawRect:` |  | ✅ | ❌ | `0x16990` |
| `GraphCircleView` | `-` | `reset` |  | ✅ | ❌ | `0x17084` |
| `GraphCircleView` | `-` | `m_IsAnimation` | prop | ✅ | ✅ | `0x1726c` |
| `GraphCircleView` | `-` | `setM_IsAnimation:` | prop | ✅ | ✅ | `0x1727c` |
| `GraphCircleView` | `-` | `dataArray` | prop | ✅ | ✅ | `0x1728c` |
| `GraphCircleView` | `-` | `setDataArray:` | prop | ✅ | ✅ | `0x1729c` |
| `GraphCircleView` | `-` | `pointArray` | prop | ✅ | ✅ | `0x172d4` |
| `GraphCircleView` | `-` | `setPointArray:` | prop | ✅ | ✅ | `0x172e4` |
| `GraphCircleView` | `-` | `startPos` | prop | ✅ | ✅ | `0x1731c` |
| `GraphCircleView` | `-` | `setStartPos:` | prop | ✅ | ✅ | `0x17330` |
| `GraphCircleView` | `-` | `dotIntervalX` | prop | ✅ | ✅ | `0x17344` |
| `GraphCircleView` | `-` | `setDotIntervalX:` | prop | ✅ | ✅ | `0x17354` |
| `GraphCircleView` | `-` | `maxValue` | prop | ✅ | ✅ | `0x17364` |
| `GraphCircleView` | `-` | `setMaxValue:` | prop | ✅ | ✅ | `0x17374` |
| `GraphCircleView` | `-` | `minValue` | prop | ✅ | ✅ | `0x17384` |
| `GraphCircleView` | `-` | `setMinValue:` | prop | ✅ | ✅ | `0x17394` |
| `GraphCircleView` | `-` | `dotColor` | prop | ✅ | ✅ | `0x173a4` |
| `GraphCircleView` | `-` | `setDotColor:` | prop | ✅ | ✅ | `0x173b4` |
| `GraphCircleView` | `-` | `dotSize` | prop | ✅ | ✅ | `0x173ec` |
| `GraphCircleView` | `-` | `setDotSize:` | prop | ✅ | ✅ | `0x173fc` |
| `GraphCircleView` | `-` | `lineColor` | prop | ✅ | ✅ | `0x1740c` |
| `GraphCircleView` | `-` | `setLineColor:` | prop | ✅ | ✅ | `0x1741c` |
| `GraphCircleView` | `-` | `lineSize` | prop | ✅ | ✅ | `0x17454` |
| `GraphCircleView` | `-` | `setLineSize:` | prop | ✅ | ✅ | `0x17464` |
| `SePlayer` | `-` | `initWithPath:` |  | ✅ | ❌ | `0x176f4` |
| `SePlayer` | `-` | `sePlay` |  | ✅ | ❌ | `0x17a54` |
| `SePlayer` | `-` | `terminate` |  | ✅ | ❌ | `0x17a64` |
| `HistoryData` | `-` | `initWithData:` |  | ✅ | ❌ | `0x17fcc` |
| `HistoryData` | `+` | `convertLocalDate:` |  | ✅ | ❌ | `0x18530` |
| `HistoryData` | `-` | `chksco` | prop | ✅ | ✅ | `0x18610` |
| `HistoryData` | `-` | `setChksco:` | prop | ✅ | ✅ | `0x18620` |
| `HistoryData` | `-` | `score` | prop | ✅ | ✅ | `0x18658` |
| `HistoryData` | `-` | `setScore:` | prop | ✅ | ✅ | `0x18668` |
| `HistoryData` | `-` | `cntCom` | prop | ✅ | ✅ | `0x186a0` |
| `HistoryData` | `-` | `setCntCom:` | prop | ✅ | ✅ | `0x186b0` |
| `HistoryData` | `-` | `cntGood` | prop | ✅ | ✅ | `0x186e8` |
| `HistoryData` | `-` | `setCntGood:` | prop | ✅ | ✅ | `0x186f8` |
| `HistoryData` | `-` | `cntGreat` | prop | ✅ | ✅ | `0x18730` |
| `HistoryData` | `-` | `setCntGreat:` | prop | ✅ | ✅ | `0x18740` |
| `HistoryData` | `-` | `cntJR` | prop | ✅ | ✅ | `0x18778` |
| `HistoryData` | `-` | `setCntJR:` | prop | ✅ | ✅ | `0x18788` |
| `HistoryData` | `-` | `cntJust` | prop | ✅ | ✅ | `0x187c0` |
| `HistoryData` | `-` | `setCntJust:` | prop | ✅ | ✅ | `0x187d0` |
| `HistoryData` | `-` | `cntMiss` | prop | ✅ | ✅ | `0x18808` |
| `HistoryData` | `-` | `setCntMiss:` | prop | ✅ | ✅ | `0x18818` |
| `HistoryData` | `-` | `ar` | prop | ✅ | ✅ | `0x18850` |
| `HistoryData` | `-` | `setAr:` | prop | ✅ | ✅ | `0x18860` |
| `HistoryData` | `-` | `diff` | prop | ✅ | ✅ | `0x18870` |
| `HistoryData` | `-` | `setDiff:` | prop | ✅ | ✅ | `0x18880` |
| `HistoryData` | `-` | `playDate` | prop | ✅ | ✅ | `0x188b8` |
| `HistoryData` | `-` | `setPlayDate:` | prop | ✅ | ✅ | `0x188c8` |
| `HistoryData` | `-` | `pc` | prop | ✅ | ✅ | `0x18900` |
| `HistoryData` | `-` | `setPc:` | prop | ✅ | ✅ | `0x18910` |
| `HistoryData` | `-` | `tuneID` | prop | ✅ | ✅ | `0x18948` |
| `HistoryData` | `-` | `setTuneID:` | prop | ✅ | ✅ | `0x18958` |
| `SystemHardware` | `-` | `init` |  | ✅ | ❌ | `0x18a98` |
| `SystemHardware` | `-` | `dealloc` |  | ❌ | ✅ | `0x18ae0` |
| `SystemHardware` | `+` | `getInstance` |  | ✅ | ❌ | `0x18b14` |
| `SystemHardware` | `-` | `initHardware` |  | ✅ | ❌ | `0x18b6c` |
| `SystemHardware` | `-` | `getHardwareType` |  | ✅ | ❌ | `0x18cb0` |
| `SystemHardware` | `-` | `getHardwareName` |  | ✅ | ❌ | `0x18cf4` |
| `SystemHardware` | `-` | `hardwareName` | prop | ✅ | ✅ | `0x18d40` |
| `SystemHardware` | `-` | `setHardwareName:` | prop | ✅ | ✅ | `0x18d50` |
| `RBResourceDownloadBGEffectPartView` | `-` | `init` |  | ✅ | ❌ | `0x19aa0` |
| `RBResoureDownloadBGEffectView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x19b84` |
| `RBResoureDownloadBGEffectView` | `-` | `setupView` |  | ✅ | ❌ | `0x19c40` |
| `RBResoureDownloadBGEffectView` | `-` | `setupParticle` |  | ✅ | ❌ | `0x19c90` |
| `RBResourceDownloadViewController` | `-` | `shouldAutorotate` |  | ✅ | ✅ | `0x19dd4` |
| `RBResourceDownloadViewController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ❌ | `0x19ddc` |
| `RBResourceDownloadViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x19e00` |
| `RBResourceDownloadViewController` | `-` | `preferredInterfaceOrientationForPresentation` |  | ✅ | ✅ | `0x19e10` |
| `RBResourceDownloadViewController` | `-` | `willAnimateRotationToInterfaceOrientation:duration:` |  | ✅ | ❌ | `0x19e1c` |
| `RBResourceDownloadViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x19e50` |
| `RBResourceDownloadViewController` | `-` | `download` |  | ✅ | ❌ | `0x19f74` |
| `RBResourceDownloadViewController` | `-` | `resume` |  | ✅ | ❌ | `0x1a01c` |
| `RBResourceDownloadViewController` | `-` | `pause` |  | ✅ | ❌ | `0x1a0e8` |
| `RBResourceDownloadViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x1a1b4` |
| `RBResourceDownloadViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x1a2ac` |
| `RBResourceDownloadViewController` | `-` | `viewWillLayoutSubviews` |  | ✅ | ❌ | `0x1a56c` |
| `RBResourceDownloadViewController` | `-` | `animation` |  | ✅ | ❌ | `0x1a5bc` |
| `RBResourceDownloadViewController` | `-` | `request` |  | ✅ | ❌ | `0x1aad8` |
| `RBResourceDownloadViewController` | `-` | `downloadWithURLString:` |  | ✅ | ❌ | `0x1b994` |
| `RBResourceDownloadViewController` | `-` | `unzip:` |  | ✅ | ❌ | `0x1bdfc` |
| `RBResourceDownloadViewController` | `-` | `success` |  | ✅ | ❌ | `0x1c0d8` |
| `RBResourceDownloadViewController` | `+` | `checkFile` |  | ✅ | ❌ | `0x1c2bc` |
| `RBResourceDownloadViewController` | `-` | `updateProgress:` |  | ✅ | ❌ | `0x1c72c` |
| `RBResourceDownloadViewController` | `-` | `zipArchiveWillUnzipArchiveAtPath:zipInfo:` |  | ✅ | ✅ | `0x1ca40` |
| `RBResourceDownloadViewController` | `-` | `zipArchiveDidUnzipArchiveAtPath:zipInfo:unzippedPath:` |  | ✅ | ❌ | `0x1ca44` |
| `RBResourceDownloadViewController` | `-` | `zipArchiveWillUnzipFileAtIndex:totalFiles:archivePath:fileInfo:` |  | ✅ | ❌ | `0x1ca60` |
| `RBResourceDownloadViewController` | `-` | `zipArchiveDidUnzipFileAtIndex:totalFiles:archivePath:fileInfo:` |  | ✅ | ✅ | `0x1caf4` |
| `RBResourceDownloadViewController` | `-` | `setupView` |  | ✅ | ❌ | `0x1caf8` |
| `RBResourceDownloadViewController` | `-` | `createViewSame:` |  | ✅ | ❌ | `0x1e84c` |
| `RBResourceDownloadViewController` | `-` | `updateLayout` |  | ✅ | ✅ | `0x1ea20` |
| `RBResourceDownloadViewController` | `-` | `layoutScrollView` |  | ✅ | ❌ | `0x1f600` |
| `RBResourceDownloadViewController` | `-` | `pageDidChangeValue:` |  | ✅ | ❌ | `0x1f6c4` |
| `RBResourceDownloadViewController` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x1f934` |
| `RBResourceDownloadViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0x1fa5c` |
| `RBResourceDownloadViewController` | `-` | `URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:` |  | ✅ | ❌ | `0x1fef0` |
| `RBResourceDownloadViewController` | `-` | `URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:` |  | ✅ | ❌ | `0x1ff7c` |
| `RBResourceDownloadViewController` | `-` | `URLSession:downloadTask:didFinishDownloadingToURL:` |  | ✅ | ❌ | `0x2002c` |
| `RBResourceDownloadViewController` | `-` | `URLSession:task:didCompleteWithError:` |  | ✅ | ❌ | `0x20298` |
| `RBResourceDownloadViewController` | `-` | `dealloc` |  | ✅ | ✅ | `0x2034c` |
| `RBResourceDownloadViewController` | `-` | `downloadPath` | prop | ✅ | ✅ | `0x20380` |
| `RBResourceDownloadViewController` | `-` | `setDownloadPath:` | prop | ✅ | ✅ | `0x20390` |
| `RBResourceDownloadViewController` | `-` | `version` | prop | ✅ | ✅ | `0x2039c` |
| `RBResourceDownloadViewController` | `-` | `setVersion:` | prop | ✅ | ✅ | `0x203ac` |
| `RBResourceDownloadViewController` | `-` | `forceCheck` | prop | ✅ | ✅ | `0x203b8` |
| `RBResourceDownloadViewController` | `-` | `setForceCheck:` | prop | ✅ | ✅ | `0x203c8` |
| `RBResourceDownloadViewController` | `-` | `dataTask` | prop | ✅ | ✅ | `0x203d8` |
| `RBResourceDownloadViewController` | `-` | `setDataTask:` | prop | ✅ | ✅ | `0x203e8` |
| `RBResourceDownloadViewController` | `-` | `downloader` | prop | ✅ | ✅ | `0x20420` |
| `RBResourceDownloadViewController` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x20430` |
| `RBResourceDownloadViewController` | `-` | `downloadTask` | prop | ✅ | ✅ | `0x20468` |
| `RBResourceDownloadViewController` | `-` | `setDownloadTask:` | prop | ✅ | ✅ | `0x20478` |
| `RBResourceDownloadViewController` | `-` | `helpView` | prop | ✅ | ✅ | `0x204b0` |
| `RBResourceDownloadViewController` | `-` | `setHelpView:` | prop | ✅ | ✅ | `0x204c0` |
| `RBResourceDownloadViewController` | `-` | `scrollBGView` | prop | ✅ | ✅ | `0x204f8` |
| `RBResourceDownloadViewController` | `-` | `setScrollBGView:` | prop | ✅ | ✅ | `0x20508` |
| `RBResourceDownloadViewController` | `-` | `scrollView` | prop | ✅ | ✅ | `0x20540` |
| `RBResourceDownloadViewController` | `-` | `setScrollView:` | prop | ✅ | ✅ | `0x20550` |
| `RBResourceDownloadViewController` | `-` | `pageControl` | prop | ✅ | ✅ | `0x20588` |
| `RBResourceDownloadViewController` | `-` | `setPageControl:` | prop | ✅ | ✅ | `0x20598` |
| `RBResourceDownloadViewController` | `-` | `gradView` | prop | ✅ | ✅ | `0x205d0` |
| `RBResourceDownloadViewController` | `-` | `setGradView:` | prop | ✅ | ✅ | `0x205e0` |
| `RBResourceDownloadViewController` | `-` | `pastelView` | prop | ✅ | ✅ | `0x20618` |
| `RBResourceDownloadViewController` | `-` | `setPastelView:` | prop | ✅ | ✅ | `0x20628` |
| `RBResourceDownloadViewController` | `-` | `popImageView` | prop | ✅ | ✅ | `0x20660` |
| `RBResourceDownloadViewController` | `-` | `setPopImageView:` | prop | ✅ | ✅ | `0x20670` |
| `RBResourceDownloadViewController` | `-` | `pastelImageView` | prop | ✅ | ✅ | `0x206a8` |
| `RBResourceDownloadViewController` | `-` | `setPastelImageView:` | prop | ✅ | ✅ | `0x206b8` |
| `RBResourceDownloadViewController` | `-` | `trackImageView` | prop | ✅ | ✅ | `0x206f0` |
| `RBResourceDownloadViewController` | `-` | `setTrackImageView:` | prop | ✅ | ✅ | `0x20700` |
| `RBResourceDownloadViewController` | `-` | `progressImageView` | prop | ✅ | ✅ | `0x20738` |
| `RBResourceDownloadViewController` | `-` | `setProgressImageView:` | prop | ✅ | ✅ | `0x20748` |
| `RBResourceDownloadViewController` | `-` | `fadeImageView` | prop | ✅ | ✅ | `0x20780` |
| `RBResourceDownloadViewController` | `-` | `setFadeImageView:` | prop | ✅ | ✅ | `0x20790` |
| `RBResourceDownloadViewController` | `-` | `bgEffectView` | prop | ✅ | ✅ | `0x207c8` |
| `RBResourceDownloadViewController` | `-` | `setBgEffectView:` | prop | ✅ | ✅ | `0x207d8` |
| `RBResourceDownloadViewController` | `-` | `progressMode` | prop | ✅ | ✅ | `0x20810` |
| `RBResourceDownloadViewController` | `-` | `setProgressMode:` | prop | ✅ | ✅ | `0x20820` |
| `RBResourceDownloadViewController` | `-` | `allFileCount` | prop | ✅ | ✅ | `0x20830` |
| `RBResourceDownloadViewController` | `-` | `setAllFileCount:` | prop | ✅ | ✅ | `0x20840` |
| `RBResourceDownloadViewController` | `-` | `currentFileCount` | prop | ✅ | ✅ | `0x20850` |
| `RBResourceDownloadViewController` | `-` | `setCurrentFileCount:` | prop | ✅ | ✅ | `0x20860` |
| `RBResourceDownloadViewController` | `-` | `nextAnimation` | prop | ✅ | ✅ | `0x20870` |
| `RBResourceDownloadViewController` | `-` | `setNextAnimation:` | prop | ✅ | ✅ | `0x20884` |
| `RBResourceDownloadViewController` | `-` | `fileInfoDic` | prop | ✅ | ✅ | `0x20894` |
| `RBResourceDownloadViewController` | `-` | `setFileInfoDic:` | prop | ✅ | ✅ | `0x208a4` |
| `RBPastelManager` | `+` | `getInstance` |  | ✅ | ❌ | `0x20a30` |
| `RBPastelManager` | `-` | `init` |  | ✅ | ❌ | `0x20a88` |
| `RBPastelManager` | `-` | `allReset` |  | ✅ | ❌ | `0x20afc` |
| `RBPastelManager` | `+` | `tryShow:` |  | ❌ | ❌ | `0x20b0c` |
| `RBPastelManager` | `-` | `type` | prop | ✅ | ✅ | `0x20ba0` |
| `RBPastelManager` | `-` | `setType:` | prop | ✅ | ✅ | `0x20bb0` |
| `(RB)` | `-` | `prefersStatusBarHidden` |  | ❌ | ❌ | `0x20f48` |
| `StoreExtendNoteDetailViewPad` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x22068` |
| `StoreExtendNoteDetailViewPad` | `-` | `removeNoteInfo` |  | ✅ | ❌ | `0x24b78` |
| `StoreExtendNoteDetailViewPad` | `-` | `cancelLoading` |  | ✅ | ✅ | `0x24f68` |
| `StoreExtendNoteDetailViewPad` | `-` | `stopSample` |  | ✅ | ❌ | `0x24f6c` |
| `StoreExtendNoteDetailViewPad` | `-` | `pushSampleBtn` |  | ✅ | ❌ | `0x250d4` |
| `StoreExtendNoteDetailViewPad` | `-` | `sampleViewStop` |  | ✅ | ❌ | `0x2534c` |
| `StoreExtendNoteDetailViewPad` | `-` | `sampleViewDownloading` |  | ✅ | ❌ | `0x25444` |
| `StoreExtendNoteDetailViewPad` | `-` | `sampleViewPlaying` |  | ✅ | ❌ | `0x25540` |
| `StoreExtendNoteDetailViewPad` | `-` | `showNoteInfo` |  | ✅ | ❌ | `0x2563c` |
| `StoreExtendNoteDetailViewPad` | `-` | `pushLink:` |  | ✅ | ✅ | `0x2585c` |
| `StoreExtendNoteDetailViewPad` | `-` | `pushCellButton:` |  | ✅ | ❌ | `0x25860` |
| `StoreExtendNoteDetailViewPad` | `-` | `finishBgm:` |  | ✅ | ❌ | `0x259c4` |
| `StoreExtendNoteDetailViewPad` | `-` | `showTerm` |  | ✅ | ❌ | `0x259e0` |
| `StoreExtendNoteDetailViewPad` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x25ab0` |
| `StoreExtendNoteDetailViewPad` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x25c50` |
| `StoreExtendNoteDetailViewPad` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x25d08` |
| `StoreExtendNoteDetailViewPad` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x25d0c` |
| `StoreExtendNoteDetailViewPad` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0x25de8` |
| `StoreExtendNoteDetailViewPad` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x25dec` |
| `StoreExtendNoteDetailViewPad` | `-` | `alertViewCancel:` |  | ✅ | ❌ | `0x25df0` |
| `StoreExtendNoteDetailViewPad` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0x25ecc` |
| `StoreExtendNoteDetailViewPad` | `-` | `setInfo:` |  | ✅ | ❌ | `0x2600c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setDownloadFlag:` |  | ✅ | ✅ | `0x26424` |
| `StoreExtendNoteDetailViewPad` | `-` | `hasItem:itemID:` |  | ✅ | ❌ | `0x26428` |
| `StoreExtendNoteDetailViewPad` | `-` | `getArtworkMargin:` |  | ✅ | ❌ | `0x2653c` |
| `StoreExtendNoteDetailViewPad` | `-` | `getItemSize:` |  | ✅ | ❌ | `0x26548` |
| `StoreExtendNoteDetailViewPad` | `-` | `setArtwork:` |  | ✅ | ❌ | `0x2655c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setButtonTextInstalling` |  | ✅ | ❌ | `0x26824` |
| `StoreExtendNoteDetailViewPad` | `-` | `setButtonTextInstalled` |  | ✅ | ❌ | `0x268d4` |
| `StoreExtendNoteDetailViewPad` | `-` | `selfCheckButtonText` |  | ✅ | ❌ | `0x26984` |
| `StoreExtendNoteDetailViewPad` | `-` | `noteInfo` | prop | ✅ | ✅ | `0x26bc8` |
| `StoreExtendNoteDetailViewPad` | `-` | `setNoteInfo:` | prop | ✅ | ✅ | `0x26bd8` |
| `StoreExtendNoteDetailViewPad` | `-` | `delegate` | prop | ✅ | ✅ | `0x26c10` |
| `StoreExtendNoteDetailViewPad` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x26c30` |
| `StoreExtendNoteDetailViewPad` | `-` | `noteView` | prop | ✅ | ✅ | `0x26c44` |
| `StoreExtendNoteDetailViewPad` | `-` | `setNoteView:` | prop | ✅ | ✅ | `0x26c54` |
| `StoreExtendNoteDetailViewPad` | `-` | `labelTitle` | prop | ✅ | ✅ | `0x26c8c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setLabelTitle:` | prop | ✅ | ✅ | `0x26c9c` |
| `StoreExtendNoteDetailViewPad` | `-` | `artworkView` | prop | ✅ | ✅ | `0x26cd4` |
| `StoreExtendNoteDetailViewPad` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0x26ce4` |
| `StoreExtendNoteDetailViewPad` | `-` | `labelMusicName` | prop | ✅ | ✅ | `0x26d1c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setLabelMusicName:` | prop | ✅ | ✅ | `0x26d2c` |
| `StoreExtendNoteDetailViewPad` | `-` | `labelArtistName` | prop | ✅ | ✅ | `0x26d64` |
| `StoreExtendNoteDetailViewPad` | `-` | `setLabelArtistName:` | prop | ✅ | ✅ | `0x26d74` |
| `StoreExtendNoteDetailViewPad` | `-` | `labelLevel` | prop | ✅ | ✅ | `0x26dac` |
| `StoreExtendNoteDetailViewPad` | `-` | `setLabelLevel:` | prop | ✅ | ✅ | `0x26dbc` |
| `StoreExtendNoteDetailViewPad` | `-` | `labelID` | prop | ✅ | ✅ | `0x26df4` |
| `StoreExtendNoteDetailViewPad` | `-` | `setLabelID:` | prop | ✅ | ✅ | `0x26e04` |
| `StoreExtendNoteDetailViewPad` | `-` | `copyrightView` | prop | ✅ | ✅ | `0x26e3c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setCopyrightView:` | prop | ✅ | ✅ | `0x26e4c` |
| `StoreExtendNoteDetailViewPad` | `-` | `downloadBtn` | prop | ✅ | ✅ | `0x26e84` |
| `StoreExtendNoteDetailViewPad` | `-` | `setDownloadBtn:` | prop | ✅ | ✅ | `0x26e94` |
| `StoreExtendNoteDetailViewPad` | `-` | `linkBtn` | prop | ✅ | ✅ | `0x26ecc` |
| `StoreExtendNoteDetailViewPad` | `-` | `setLinkBtn:` | prop | ✅ | ✅ | `0x26edc` |
| `StoreExtendNoteDetailViewPad` | `-` | `campaignID` | prop | ✅ | ✅ | `0x26f14` |
| `StoreExtendNoteDetailViewPad` | `-` | `setCampaignID:` | prop | ✅ | ✅ | `0x26f24` |
| `StoreExtendNoteDetailViewPad` | `-` | `sampleDownloader` | prop | ✅ | ✅ | `0x26f34` |
| `StoreExtendNoteDetailViewPad` | `-` | `setSampleDownloader:` | prop | ✅ | ✅ | `0x26f44` |
| `StoreExtendNoteDetailViewPad` | `-` | `indicator` | prop | ✅ | ✅ | `0x26f7c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x26f8c` |
| `StoreExtendNoteDetailViewPad` | `-` | `labelLoading` | prop | ✅ | ✅ | `0x26fc4` |
| `StoreExtendNoteDetailViewPad` | `-` | `setLabelLoading:` | prop | ✅ | ✅ | `0x26fd4` |
| `StoreExtendNoteDetailViewPad` | `-` | `sampleBtn` | prop | ✅ | ✅ | `0x2700c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setSampleBtn:` | prop | ✅ | ✅ | `0x2701c` |
| `StoreExtendNoteDetailViewPad` | `-` | `playingView` | prop | ✅ | ✅ | `0x27054` |
| `StoreExtendNoteDetailViewPad` | `-` | `setPlayingView:` | prop | ✅ | ✅ | `0x27064` |
| `StoreExtendNoteDetailViewPad` | `-` | `detailView` | prop | ✅ | ✅ | `0x2709c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setDetailView:` | prop | ✅ | ✅ | `0x270ac` |
| `StoreExtendNoteDetailViewPad` | `-` | `bannerView` | prop | ✅ | ✅ | `0x270e4` |
| `StoreExtendNoteDetailViewPad` | `-` | `setBannerView:` | prop | ✅ | ✅ | `0x270f4` |
| `StoreExtendNoteDetailViewPad` | `-` | `descriptionTextView` | prop | ✅ | ✅ | `0x2712c` |
| `StoreExtendNoteDetailViewPad` | `-` | `setDescriptionTextView:` | prop | ✅ | ✅ | `0x2713c` |
| `StoreExtendNoteDetailViewPad` | `-` | `indicatorSample` | prop | ✅ | ✅ | `0x27174` |
| `StoreExtendNoteDetailViewPad` | `-` | `setIndicatorSample:` | prop | ✅ | ✅ | `0x27184` |
| `StringConvert` | `+` | `convertYomigana:` |  | ✅ | ❌ | `0x2a190` |
| `StringConvert` | `+` | `convertFromVToB:` |  | ✅ | ❌ | `0x2a640` |
| `StringConvert` | `+` | `convertDJ:` |  | ✅ | ❌ | `0x2a7b4` |
| `StringConvert` | `+` | `convertKorsk:` |  | ✅ | ❌ | `0x2a88c` |
| `StringConvert` | `+` | `convertFromMacronToVowel:` |  | ✅ | ❌ | `0x2a92c` |
| `StringConvert` | `+` | `convertFromLowerToUpper:` |  | ✅ | ❌ | `0x2a9e8` |
| `StringConvert` | `+` | `convertFromVoiceToVoiceless:` |  | ✅ | ❌ | `0x2aaa4` |
| `StringConvert` | `+` | `stringTransform:withTransform:reverse:` |  | ✅ | ❌ | `0x2ab60` |
| `RBMenuMascot` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x2b578` |
| `RBMenuMascot` | `-` | `setup:` |  | ✅ | ❌ | `0x2b774` |
| `RBMenuMascot` | `-` | `startAnimation:` |  | ✅ | ❌ | `0x2c850` |
| `RBMenuMascot` | `-` | `stopAnimation` |  | ✅ | ❌ | `0x2d478` |
| `RBMenuMascot` | `-` | `updateMessage` |  | ✅ | ❌ | `0x2d54c` |
| `RBMenuMascot` | `-` | `generateCGSize:` |  | ✅ | ❌ | `0x2e5d4` |
| `RBMenuMascot` | `-` | `update` |  | ✅ | ❌ | `0x2e6c4` |
| `RBMenuMascot` | `-` | `onTapped:` |  | ✅ | ❌ | `0x2e8c8` |
| `RBMenuMascot` | `-` | `getMovePoint` |  | ✅ | ❌ | `0x2ebe4` |
| `RBMenuMascot` | `-` | `limitX` | prop | ✅ | ✅ | `0x2f0c0` |
| `RBMenuMascot` | `-` | `setLimitX:` | prop | ✅ | ✅ | `0x2f0d4` |
| `RBMenuMascot` | `-` | `limitY` | prop | ✅ | ✅ | `0x2f0e8` |
| `RBMenuMascot` | `-` | `setLimitY:` | prop | ✅ | ✅ | `0x2f0fc` |
| `RBMenuMascot` | `-` | `delegate` | prop | ✅ | ✅ | `0x2f110` |
| `RBMenuMascot` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x2f120` |
| `RBMenuMascot` | `-` | `isCampaignMode` | prop | ✅ | ✅ | `0x2f130` |
| `RBMenuMascot` | `-` | `setIsCampaignMode:` | prop | ✅ | ✅ | `0x2f140` |
| `RBMenuMascot` | `-` | `normalImageArray` | prop | ✅ | ✅ | `0x2f150` |
| `RBMenuMascot` | `-` | `setNormalImageArray:` | prop | ✅ | ✅ | `0x2f160` |
| `RBMenuMascot` | `-` | `normalFrameCountArray` | prop | ✅ | ✅ | `0x2f198` |
| `RBMenuMascot` | `-` | `setNormalFrameCountArray:` | prop | ✅ | ✅ | `0x2f1a8` |
| `RBMenuMascot` | `-` | `rareImageArray` | prop | ✅ | ✅ | `0x2f1e0` |
| `RBMenuMascot` | `-` | `setRareImageArray:` | prop | ✅ | ✅ | `0x2f1f0` |
| `RBMenuMascot` | `-` | `rareFrameCountArray` | prop | ✅ | ✅ | `0x2f228` |
| `RBMenuMascot` | `-` | `setRareFrameCountArray:` | prop | ✅ | ✅ | `0x2f238` |
| `RBMenuMascot` | `-` | `mascotView` | prop | ✅ | ✅ | `0x2f270` |
| `RBMenuMascot` | `-` | `setMascotView:` | prop | ✅ | ✅ | `0x2f280` |
| `RBMenuMascot` | `-` | `type` | prop | ✅ | ✅ | `0x2f2b8` |
| `RBMenuMascot` | `-` | `setType:` | prop | ✅ | ✅ | `0x2f2c8` |
| `RBMenuMascot` | `-` | `speedX` | prop | ✅ | ✅ | `0x2f2d8` |
| `RBMenuMascot` | `-` | `setSpeedX:` | prop | ✅ | ✅ | `0x2f2e8` |
| `RBMenuMascot` | `-` | `speedY` | prop | ✅ | ✅ | `0x2f2f8` |
| `RBMenuMascot` | `-` | `setSpeedY:` | prop | ✅ | ✅ | `0x2f308` |
| `RBMenuMascot` | `-` | `accellY` | prop | ✅ | ✅ | `0x2f318` |
| `RBMenuMascot` | `-` | `setAccellY:` | prop | ✅ | ✅ | `0x2f328` |
| `RBMenuMascot` | `-` | `baseY` | prop | ✅ | ✅ | `0x2f338` |
| `RBMenuMascot` | `-` | `setBaseY:` | prop | ✅ | ✅ | `0x2f348` |
| `RBMenuMascot` | `-` | `isAnimation` | prop | ✅ | ✅ | `0x2f358` |
| `RBMenuMascot` | `-` | `setIsAnimation:` | prop | ✅ | ✅ | `0x2f368` |
| `RBMenuMascot` | `-` | `m_screenSize` | prop | ✅ | ✅ | `0x2f378` |
| `RBMenuMascot` | `-` | `setM_screenSize:` | prop | ✅ | ✅ | `0x2f398` |
| `RBMenuMascot` | `-` | `scale` | prop | ✅ | ✅ | `0x2f3b8` |
| `RBMenuMascot` | `-` | `setScale:` | prop | ✅ | ✅ | `0x2f3c8` |
| `RBMenuMascot` | `-` | `messageViewAnimating` | prop | ✅ | ✅ | `0x2f3d8` |
| `RBMenuMascot` | `-` | `setMessageViewAnimating:` | prop | ✅ | ✅ | `0x2f3e8` |
| `RBMenuMascot` | `-` | `messageView` | prop | ✅ | ✅ | `0x2f3f8` |
| `RBMenuMascot` | `-` | `setMessageView:` | prop | ✅ | ✅ | `0x2f408` |
| `RBMenuMascot` | `-` | `messageBgView` | prop | ✅ | ✅ | `0x2f440` |
| `RBMenuMascot` | `-` | `setMessageBgView:` | prop | ✅ | ✅ | `0x2f450` |
| `RBMenuMascot` | `-` | `messageLabel` | prop | ✅ | ✅ | `0x2f488` |
| `RBMenuMascot` | `-` | `setMessageLabel:` | prop | ✅ | ✅ | `0x2f498` |
| `RBMenuMascot` | `-` | `messageList` | prop | ✅ | ✅ | `0x2f4d0` |
| `RBMenuMascot` | `-` | `setMessageList:` | prop | ✅ | ✅ | `0x2f4e0` |
| `RBMenuMascot` | `-` | `currentMessageIndex` | prop | ✅ | ✅ | `0x2f518` |
| `RBMenuMascot` | `-` | `setCurrentMessageIndex:` | prop | ✅ | ✅ | `0x2f528` |
| `RBMenuMascot` | `-` | `nextMessageIndex` | prop | ✅ | ✅ | `0x2f538` |
| `RBMenuMascot` | `-` | `setNextMessageIndex:` | prop | ✅ | ✅ | `0x2f548` |
| `neTextureForiOS` | `+` | `LoadTexture:Scale:` |  | ✅ | ❌ | `0x32320` |
| `NetworkUtil` | `+` | `createNonce:` |  | ✅ | ❌ | `0x32610` |
| `NetworkUtil` | `+` | `deviceName` |  | ✅ | ❌ | `0x32740` |
| `NetworkUtil` | `+` | `identifierParams` |  | ✅ | ❌ | `0x327b0` |
| `NetworkUtil` | `+` | `userInfo` |  | ✅ | ❌ | `0x3287c` |
| `NetworkUtil` | `+` | `createSecureURL:` |  | ✅ | ❌ | `0x329d0` |
| `NetworkUtil` | `+` | `createSecureAPI:withParam:` |  | ✅ | ❌ | `0x32a6c` |
| `NetworkUtil` | `+` | `startupURL` |  | ✅ | ❌ | `0x32ba0` |
| `NetworkUtil` | `+` | `resourceURL` |  | ✅ | ❌ | `0x32c70` |
| `NetworkUtil` | `+` | `tokenSetURL` |  | ✅ | ❌ | `0x32c90` |
| `NetworkUtil` | `+` | `lineMessageURL` |  | ✅ | ❌ | `0x32cb0` |
| `NetworkUtil` | `+` | `playedV2URL` |  | ✅ | ❌ | `0x32dac` |
| `NetworkUtil` | `+` | `tutorialStatusURL` |  | ✅ | ❌ | `0x32dcc` |
| `NetworkUtil` | `+` | `searchMasterURL` |  | ✅ | ❌ | `0x32dec` |
| `NetworkUtil` | `+` | `searchURL` |  | ✅ | ❌ | `0x32ee8` |
| `NetworkUtil` | `+` | `unlockListURL` |  | ✅ | ❌ | `0x32f08` |
| `NetworkUtil` | `+` | `unlockMusicURL:randKey:` |  | ✅ | ❌ | `0x33058` |
| `NetworkUtil` | `+` | `unlockedURL` |  | ✅ | ❌ | `0x33168` |
| `NetworkUtil` | `+` | `packListURL:limit:genre:` |  | ✅ | ❌ | `0x33188` |
| `NetworkUtil` | `+` | `packInfoURL:UserOpen:` |  | ✅ | ❌ | `0x332a8` |
| `NetworkUtil` | `+` | `musicInfoURL:` |  | ✅ | ❌ | `0x33408` |
| `NetworkUtil` | `+` | `receiptV3URL` |  | ✅ | ❌ | `0x33514` |
| `NetworkUtil` | `+` | `campaignListURL` |  | ✅ | ❌ | `0x33534` |
| `NetworkUtil` | `+` | `campaignSerialCheckURL` |  | ✅ | ❌ | `0x33554` |
| `NetworkUtil` | `+` | `campaignItemInfoURL` |  | ✅ | ❌ | `0x33574` |
| `NetworkUtil` | `+` | `manageSortListURL` |  | ✅ | ❌ | `0x33594` |
| `NetworkUtil` | `+` | `extendNoteListURL:limit:` |  | ✅ | ❌ | `0x3365c` |
| `NetworkUtil` | `+` | `extendNoteInfoURL:UserOpen:` |  | ✅ | ❌ | `0x3376c` |
| `NetworkUtil` | `+` | `termList` |  | ✅ | ❌ | `0x338cc` |
| `NetworkUtil` | `+` | `termFetch` |  | ✅ | ❌ | `0x338ec` |
| `NetworkUtil` | `+` | `termAgree` |  | ✅ | ❌ | `0x3390c` |
| `NetworkUtil` | `+` | `userAgeURL` |  | ✅ | ❌ | `0x3392c` |
| `StorePackListGenre` | `-` | `initWithName:genreID:` |  | ✅ | ❌ | `0x33f00` |
| `StorePackListGenre` | `-` | `packCount` |  | ✅ | ❌ | `0x3403c` |
| `StorePackListGenre` | `-` | `packInfoForIndex:` |  | ✅ | ❌ | `0x3409c` |
| `StorePackListGenre` | `-` | `packIDList` |  | ✅ | ✅ | `0x34170` |
| `StorePackListGenre` | `-` | `updateList:step:hasNext:` |  | ✅ | ❌ | `0x3417c` |
| `StorePackListGenre` | `-` | `genreName` | prop | ✅ | ✅ | `0x34248` |
| `StorePackListGenre` | `-` | `genreID` | prop | ✅ | ✅ | `0x34258` |
| `StorePackListGenre` | `-` | `packlistContinued` | prop | ✅ | ✅ | `0x34268` |
| `StorePackListGenre` | `-` | `numFetchedPack` | prop | ✅ | ✅ | `0x34278` |
| `StorePackListGenre` | `-` | `arrayPackInfo` | prop | ✅ | ✅ | `0x34288` |
| `StorePackListGenre` | `-` | `setArrayPackInfo:` | prop | ✅ | ✅ | `0x34298` |
| `SoundData` | `-` | `initWithContentsFileName:Stream:` |  | ✅ | ❌ | `0x34310` |
| `SoundData` | `-` | `dealloc` |  | ✅ | ❌ | `0x34398` |
| `SoundData` | `-` | `prepare:Stream:` |  | ✅ | ❌ | `0x34454` |
| `SoundData` | `-` | `getData:Frames:Loop:Buffer:Out:` |  | ✅ | ❌ | `0x34908` |
| `SoundData` | `-` | `format` |  | ✅ | ❌ | `0x34b30` |
| `SoundData` | `-` | `fileName` | prop | ✅ | ✅ | `0x34b40` |
| `SoundData` | `-` | `channels` | prop | ✅ | ✅ | `0x34b50` |
| `SoundData` | `-` | `totalFrames` | prop | ✅ | ✅ | `0x34b60` |
| `SoundManager` | `+` | `getInstance` |  | ✅ | ❌ | `0x34bb0` |
| `SoundManager` | `-` | `init` |  | ✅ | ❌ | `0x34c08` |
| `SoundManager` | `-` | `setupAudioSession` |  | ✅ | ❌ | `0x34cf8` |
| `SoundManager` | `-` | `prepareAUGraph` |  | ✅ | ❌ | `0x34d68` |
| `SoundManager` | `-` | `loadFile:Stream:` |  | ✅ | ❌ | `0x34eec` |
| `SoundManager` | `-` | `releaseData:` |  | ✅ | ❌ | `0x35038` |
| `SoundManager` | `-` | `play:Loop:` |  | ✅ | ❌ | `0x35074` |
| `SoundManager` | `-` | `stop:` |  | ✅ | ❌ | `0x35198` |
| `SoundManager` | `-` | `setCallBack:DataFormat:` |  | ✅ | ❌ | `0x351f4` |
| `SoundManager` | `-` | `unsetCallBack:` |  | ✅ | ❌ | `0x3532c` |
| `SoundManager` | `-` | `getSoundPlayer:` |  | ✅ | ❌ | `0x3536c` |
| `SoundManager` | `-` | `startSystem` |  | ✅ | ❌ | `0x35380` |
| `SoundManager` | `-` | `stopSystem` |  | ✅ | ❌ | `0x353d4` |
| `SoundPlayer` | `-` | `setSoundData:` |  | ✅ | ❌ | `0x35498` |
| `SoundPlayer` | `-` | `getSoundData` |  | ✅ | ❌ | `0x354fc` |
| `SoundPlayer` | `-` | `setCurrentFrame:` |  | ✅ | ❌ | `0x3550c` |
| `SoundPlayer` | `-` | `currentFrame` |  | ✅ | ❌ | `0x3557c` |
| `SoundPlayer` | `-` | `setLoop:` |  | ✅ | ❌ | `0x3558c` |
| `SoundPlayer` | `-` | `isLoop` |  | ✅ | ❌ | `0x355ac` |
| `SoundPlayer` | `-` | `play` |  | ✅ | ❌ | `0x355bc` |
| `SoundPlayer` | `-` | `isPlaying` |  | ✅ | ❌ | `0x355dc` |
| `SoundPlayer` | `-` | `endPlay` |  | ✅ | ❌ | `0x355ec` |
| `SoundPlayer` | `-` | `stop` |  | ✅ | ❌ | `0x355fc` |
| `SoundPlayer` | `-` | `isStop` |  | ✅ | ❌ | `0x35610` |
| `SoundPlayer` | `-` | `loadData:Frames:` |  | ✅ | ❌ | `0x35620` |
| `RBTutorialManager` | `+` | `getInstance` |  | ✅ | ❌ | `0x356b8` |
| `RBTutorialManager` | `+` | `isTutorial` |  | ✅ | ❌ | `0x35724` |
| `RBTutorialManager` | `+` | `needStartTutorialMusicselect` |  | ✅ | ❌ | `0x3578c` |
| `RBTutorialManager` | `+` | `startTutorialMusicselect` |  | ✅ | ✅ | `0x35820` |
| `RBTutorialManager` | `+` | `isTutorialMusicselect` |  | ✅ | ❌ | `0x35838` |
| `RBTutorialManager` | `+` | `needStartTutorialPlay` |  | ✅ | ❌ | `0x358ec` |
| `RBTutorialManager` | `+` | `isTutorialPlay` |  | ✅ | ❌ | `0x3597c` |
| `RBTutorialManager` | `+` | `needStartTutorialCustomize` |  | ✅ | ❌ | `0x35a40` |
| `RBTutorialManager` | `+` | `startTutorialCustomize` |  | ✅ | ✅ | `0x35b24` |
| `RBTutorialManager` | `+` | `isTutorialCustomize` |  | ✅ | ❌ | `0x35b3c` |
| `RBTutorialManager` | `+` | `needStartTutorialStore` |  | ✅ | ❌ | `0x35c50` |
| `RBTutorialManager` | `+` | `startTutorialStore` |  | ✅ | ✅ | `0x35ce4` |
| `RBTutorialManager` | `+` | `getStatus:` |  | ❌ | ❌ | `0x35cfc` |
| `RBTutorialManager` | `+` | `getCurrentStatus` |  | ✅ | ❌ | `0x35d6c` |
| `RBTutorialManager` | `+` | `updateStatus:` |  | ✅ | ❌ | `0x35dd4` |
| `RBTutorialManager` | `+` | `setUnlockedItemInfo:itemId:` |  | ✅ | ❌ | `0x36098` |
| `RBTutorialManager` | `+` | `getUnlockedItemInfo` |  | ✅ | ❌ | `0x36308` |
| `RBTutorialManager` | `+` | `resetUnlockedItemInfo` |  | ✅ | ❌ | `0x363a8` |
| `RBTutorialManager` | `-` | `currentStatus` | prop | ✅ | ✅ | `0x3643c` |
| `RBTutorialManager` | `-` | `setCurrentStatus:` | prop | ✅ | ✅ | `0x3644c` |
| `RBTutorialManager` | `-` | `isTutorial` | prop | ✅ | ✅ | `0x3645c` |
| `RBTutorialManager` | `-` | `setIsTutorial:` | prop | ✅ | ✅ | `0x3646c` |
| `RBTutorialManager` | `-` | `isInputable` | prop | ✅ | ✅ | `0x3647c` |
| `RBTutorialManager` | `-` | `setIsInputable:` | prop | ✅ | ✅ | `0x3648c` |
| `RBTutorialManager` | `-` | `tutorialView` | prop | ✅ | ✅ | `0x3649c` |
| `RBTutorialManager` | `-` | `setTutorialView:` | prop | ✅ | ✅ | `0x364bc` |
| `RBTutorialManager` | `-` | `unlockItemInfo` | prop | ✅ | ✅ | `0x364d0` |
| `RBTutorialManager` | `-` | `setUnlockItemInfo:` | prop | ✅ | ✅ | `0x364e0` |
| `(RB)` | `-` | `canBecomeFirstResponder` |  | ❌ | ❌ | `0x366f0` |
| `RBHttpUtil` | `+` | `dictionaryToQueryData:` |  | ✅ | ❌ | `0x36754` |
| `RBHttpUtil` | `+` | `dictionaryToJsonData:` |  | ✅ | ❌ | `0x36aa8` |
| `RBHttpUtil` | `-` | `init` |  | ✅ | ❌ | `0x36b5c` |
| `RBHttpUtil` | `-` | `initWithGetURL:` |  | ✅ | ❌ | `0x36bd0` |
| `RBHttpUtil` | `-` | `initWithPostURL:post:contentType:` |  | ✅ | ❌ | `0x36e0c` |
| `RBHttpUtil` | `-` | `initWithPostURL:post:contentType:timeoutInterval:` |  | ✅ | ❌ | `0x36ea4` |
| `RBHttpUtil` | `-` | `initWithDownloadURL:filePath:` |  | ✅ | ❌ | `0x371b0` |
| `RBHttpUtil` | `-` | `updateRequest:HTTPMethod:contentType:sendData:filePath:` |  | ✅ | ❌ | `0x3741c` |
| `RBHttpUtil` | `-` | `startDownloading:` |  | ✅ | ❌ | `0x376ec` |
| `RBHttpUtil` | `-` | `startDownloadingWithProceed:success:failure:` |  | ✅ | ❌ | `0x377a8` |
| `RBHttpUtil` | `-` | `cancel` |  | ✅ | ❌ | `0x37894` |
| `RBHttpUtil` | `-` | `startDataTask` |  | ✅ | ❌ | `0x379e8` |
| `RBHttpUtil` | `-` | `startDownloadTask` |  | ✅ | ❌ | `0x37c20` |
| `RBHttpUtil` | `-` | `URLSession:dataTask:didReceiveResponse:completionHandler:` |  | ✅ | ❌ | `0x38388` |
| `RBHttpUtil` | `-` | `URLSession:dataTask:didReceiveData:` |  | ✅ | ❌ | `0x38744` |
| `RBHttpUtil` | `-` | `URLSession:task:didCompleteWithError:` |  | ✅ | ❌ | `0x38938` |
| `RBHttpUtil` | `-` | `URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:` |  | ✅ | ✅ | `0x38fbc` |
| `RBHttpUtil` | `-` | `URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:` |  | ✅ | ❌ | `0x38fc0` |
| `RBHttpUtil` | `-` | `URLSession:downloadTask:didFinishDownloadingToURL:` |  | ✅ | ❌ | `0x390c0` |
| `RBHttpUtil` | `-` | `currentSize` |  | ✅ | ❌ | `0x3930c` |
| `RBHttpUtil` | `-` | `currentProgress` |  | ✅ | ❌ | `0x3936c` |
| `RBHttpUtil` | `-` | `getData` |  | ✅ | ✅ | `0x39430` |
| `RBHttpUtil` | `-` | `getDataInJSON` |  | ✅ | ❌ | `0x3943c` |
| `RBHttpUtil` | `-` | `getHeader` |  | ✅ | ✅ | `0x39520` |
| `RBHttpUtil` | `-` | `hashChecked` |  | ✅ | ✅ | `0x3952c` |
| `RBHttpUtil` | `-` | `reset` |  | ✅ | ❌ | `0x39538` |
| `RBHttpUtil` | `-` | `dealloc` |  | ✅ | ❌ | `0x3970c` |
| `RBHttpUtil` | `-` | `requestTimeoutInterval` | prop | ✅ | ✅ | `0x39790` |
| `RBHttpUtil` | `-` | `setRequestTimeoutInterval:` | prop | ✅ | ✅ | `0x397a0` |
| `RBHttpUtil` | `-` | `resourceTimeoutInterval` | prop | ✅ | ✅ | `0x397b0` |
| `RBHttpUtil` | `-` | `setResourceTimeoutInterval:` | prop | ✅ | ✅ | `0x397c0` |
| `RBHttpUtil` | `-` | `addData` | prop | ✅ | ✅ | `0x397d0` |
| `RBHttpUtil` | `-` | `setAddData:` | prop | ✅ | ✅ | `0x397e0` |
| `RBHttpUtil` | `-` | `systemErrorMessage` | prop | ✅ | ✅ | `0x39818` |
| `RBHttpUtil` | `-` | `setSystemErrorMessage:` | prop | ✅ | ✅ | `0x39828` |
| `RBHttpUtil` | `-` | `showErrorMessage` | prop | ✅ | ✅ | `0x39860` |
| `RBHttpUtil` | `-` | `setShowErrorMessage:` | prop | ✅ | ✅ | `0x39870` |
| `RBHttpUtil` | `-` | `request` | prop | ✅ | ✅ | `0x398a8` |
| `RBHttpUtil` | `-` | `setRequest:` | prop | ✅ | ✅ | `0x398b8` |
| `RBHttpUtil` | `-` | `dataTask` | prop | ✅ | ✅ | `0x398f0` |
| `RBHttpUtil` | `-` | `setDataTask:` | prop | ✅ | ✅ | `0x39900` |
| `RBHttpUtil` | `-` | `downloadTask` | prop | ✅ | ✅ | `0x39938` |
| `RBHttpUtil` | `-` | `setDownloadTask:` | prop | ✅ | ✅ | `0x39948` |
| `RBHttpUtil` | `-` | `downloadSize` | prop | ✅ | ✅ | `0x39980` |
| `RBHttpUtil` | `-` | `setDownloadSize:` | prop | ✅ | ✅ | `0x39990` |
| `RBHttpUtil` | `-` | `downloadedData` | prop | ✅ | ✅ | `0x399a0` |
| `RBHttpUtil` | `-` | `setDownloadedData:` | prop | ✅ | ✅ | `0x399b0` |
| `RBHttpUtil` | `-` | `downloadedHeader` | prop | ✅ | ✅ | `0x399e8` |
| `RBHttpUtil` | `-` | `setDownloadedHeader:` | prop | ✅ | ✅ | `0x399f8` |
| `RBHttpUtil` | `-` | `delegate` | prop | ✅ | ✅ | `0x39a30` |
| `RBHttpUtil` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x39a50` |
| `RBHttpUtil` | `-` | `filePath` | prop | ✅ | ✅ | `0x39a64` |
| `RBHttpUtil` | `-` | `setFilePath:` | prop | ✅ | ✅ | `0x39a74` |
| `RBHttpUtil` | `-` | `hashCheck` | prop | ✅ | ✅ | `0x39aac` |
| `RBHttpUtil` | `-` | `setHashCheck:` | prop | ✅ | ✅ | `0x39abc` |
| `RBHttpUtil` | `-` | `successBlock` | prop | ✅ | ✅ | `0x39acc` |
| `RBHttpUtil` | `-` | `setSuccessBlock:` | prop | ✅ | ✅ | `0x39adc` |
| `RBHttpUtil` | `-` | `proceedBlock` | prop | ✅ | ✅ | `0x39ae8` |
| `RBHttpUtil` | `-` | `setProceedBlock:` | prop | ✅ | ✅ | `0x39af8` |
| `RBHttpUtil` | `-` | `failureBlock` | prop | ✅ | ✅ | `0x39b04` |
| `RBHttpUtil` | `-` | `setFailureBlock:` | prop | ✅ | ✅ | `0x39b14` |
| `RBNotificationData` | `-` | `initWithCoder:` |  | ✅ | ❌ | `0x39c38` |
| `RBNotificationData` | `-` | `encodeWithCoder:` |  | ✅ | ❌ | `0x39d1c` |
| `RBNotificationData` | `-` | `notificationDict` | prop | ✅ | ✅ | `0x39db4` |
| `RBNotificationData` | `-` | `setNotificationDict:` | prop | ✅ | ✅ | `0x39dc4` |
| `neGLView` | `+` | `GetInstance` |  | ✅ | ❌ | `0x39e10` |
| `neGLView` | `+` | `layerClass` |  | ✅ | ❌ | `0x39e1c` |
| `neGLView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x39e30` |
| `neGLView` | `-` | `dealloc` |  | ✅ | ❌ | `0x3a188` |
| `neGLView` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x3a2e4` |
| `neGLView` | `-` | `GetFrontBufferWidth` |  | ✅ | ❌ | `0x3a448` |
| `neGLView` | `-` | `GetFrontBufferHeight` |  | ✅ | ❌ | `0x3a458` |
| `neGLView` | `-` | `BeginRender` |  | ✅ | ❌ | `0x3a468` |
| `neGLView` | `-` | `SetDefaultFrameBuffer` |  | ✅ | ✅ | `0x3a4d8` |
| `neGLView` | `-` | `SetDefaultColorBuffer` |  | ✅ | ✅ | `0x3a4dc` |
| `neGLView` | `-` | `Present` |  | ✅ | ❌ | `0x3a4e0` |
| `neGLView` | `-` | `touchesBegan:withEvent:` |  | ✅ | ❌ | `0x3a550` |
| `neGLView` | `-` | `touchesMoved:withEvent:` |  | ✅ | ❌ | `0x3a704` |
| `neGLView` | `-` | `touchesEnded:withEvent:` |  | ✅ | ❌ | `0x3a8b0` |
| `neGLView` | `-` | `touchesCancelled:withEvent:` |  | ✅ | ❌ | `0x3ab14` |
| `neGLView` | `-` | `delegate` | prop | ✅ | ✅ | `0x3ab78` |
| `neGLView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x3ab98` |
| `neGLView` | `-` | `glContext` | prop | ✅ | ✅ | `0x3abac` |
| `neGLView` | `-` | `setGlContext:` | prop | ✅ | ✅ | `0x3abbc` |
| `RBEffectSizeSlider` | `-` | `initWithDigit:` |  | ✅ | ❌ | `0x3ac30` |
| `RBEffectSizeSlider` | `-` | `setValue:` | prop | ✅ | ❌ | `0x3b96c` |
| `RBEffectSizeSlider` | `-` | `sliderChangeWithTouchPoint:` |  | ✅ | ❌ | `0x3bde0` |
| `RBEffectSizeSlider` | `-` | `beginTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x3becc` |
| `RBEffectSizeSlider` | `-` | `continueTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x3bf70` |
| `RBEffectSizeSlider` | `-` | `endTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x3c014` |
| `RBEffectSizeSlider` | `-` | `value` | prop | ✅ | ✅ | `0x3c0b0` |
| `RBEffectSizeSlider` | `-` | `baseView` | prop | ✅ | ✅ | `0x3c0c0` |
| `RBEffectSizeSlider` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x3c0d0` |
| `RBEffectSizeSlider` | `-` | `gripView` | prop | ✅ | ✅ | `0x3c108` |
| `RBEffectSizeSlider` | `-` | `setGripView:` | prop | ✅ | ✅ | `0x3c118` |
| `RBEffectSizeSlider` | `-` | `numImageViews` | prop | ✅ | ✅ | `0x3c150` |
| `RBEffectSizeSlider` | `-` | `setNumImageViews:` | prop | ✅ | ✅ | `0x3c160` |
| `RBEffectSizeSlider` | `-` | `numImages` | prop | ✅ | ✅ | `0x3c198` |
| `RBEffectSizeSlider` | `-` | `setNumImages:` | prop | ✅ | ✅ | `0x3c1a8` |
| `RBEffectSizeSlider` | `-` | `digit` | prop | ✅ | ✅ | `0x3c1e0` |
| `RBEffectSizeSlider` | `-` | `setDigit:` | prop | ✅ | ✅ | `0x3c1f0` |
| `RBEffectSizeSlider` | `-` | `barRect` | prop | ✅ | ✅ | `0x3c200` |
| `RBEffectSizeSlider` | `-` | `setBarRect:` | prop | ✅ | ✅ | `0x3c218` |
| `RBEffectSizeSlider` | `-` | `barMin` | prop | ✅ | ✅ | `0x3c230` |
| `RBEffectSizeSlider` | `-` | `setBarMin:` | prop | ✅ | ✅ | `0x3c240` |
| `RBEffectSizeSlider` | `-` | `barMax` | prop | ✅ | ✅ | `0x3c250` |
| `RBEffectSizeSlider` | `-` | `setBarMax:` | prop | ✅ | ✅ | `0x3c260` |
| `RBEffectSizeSlider` | `-` | `step` | prop | ✅ | ✅ | `0x3c270` |
| `RBEffectSizeSlider` | `-` | `setStep:` | prop | ✅ | ✅ | `0x3c280` |
| `RBEffectSizeSlider` | `-` | `stepValue` | prop | ✅ | ✅ | `0x3c290` |
| `RBEffectSizeSlider` | `-` | `setStepValue:` | prop | ✅ | ✅ | `0x3c2a0` |
| `RBMusicExtendNoteView` | `-` | `initWithFrame:ExtendNoteID:MusicSelectedBase:` |  | ✅ | ❌ | `0x3c318` |
| `RBMusicExtendNoteView` | `-` | `SetupView` |  | ✅ | ❌ | `0x3c4c8` |
| `RBMusicExtendNoteView` | `-` | `SetFlashEffectDuration:Start:End:` |  | ✅ | ✅ | `0x3cf50` |
| `RBMusicExtendNoteView` | `-` | `extendNoteID` | prop | ✅ | ✅ | `0x3cf54` |
| `RBMusicExtendNoteView` | `-` | `setExtendNoteID:` | prop | ✅ | ✅ | `0x3cf64` |
| `RBMusicExtendNoteView` | `-` | `musicSelectedBase` | prop | ✅ | ✅ | `0x3cf74` |
| `RBMusicExtendNoteView` | `-` | `setMusicSelectedBase:` | prop | ✅ | ✅ | `0x3cf94` |
| `RBMusicExtendNoteView` | `-` | `difficultyButton` | prop | ✅ | ✅ | `0x3cfa8` |
| `RBMusicExtendNoteView` | `-` | `setDifficultyButton:` | prop | ✅ | ✅ | `0x3cfb8` |
| `RBMusicExtendNoteView` | `-` | `layoutOffset` | prop | ✅ | ✅ | `0x3cff0` |
| `RBMusicExtendNoteView` | `-` | `setLayoutOffset:` | prop | ✅ | ✅ | `0x3d000` |
| `neWindow` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x3d080` |
| `neWindow` | `-` | `touchesBegan:withEvent:` |  | ✅ | ✅ | `0x3d0b4` |
| `neWindow` | `-` | `touchesMoved:withEvent:` |  | ✅ | ✅ | `0x3d0b8` |
| `neWindow` | `-` | `touchesEnded:withEvent:` |  | ✅ | ✅ | `0x3d0bc` |
| `neWindow` | `-` | `touchesCancelled:withEvent:` |  | ✅ | ✅ | `0x3d0c0` |
| `AudioManager` | `+` | `sharedManager` |  | ✅ | ✅ | `0x3d0c4` |
| `AudioManager` | `-` | `init` |  | ✅ | ✅ | `0x3d154` |
| `AudioManager` | `-` | `systemStart` |  | ✅ | ✅ | `0x3d3ec` |
| `AudioManager` | `-` | `systemStartBlock` |  | ✅ | ✅ | `0x3d4b4` |
| `AudioManager` | `-` | `systemTerminate` |  | ✅ | ✅ | `0x3d4c4` |
| `AudioManager` | `-` | `onStartPlayer:` |  | ✅ | ✅ | `0x3d50c` |
| `AudioManager` | `-` | `initBgm:` |  | ✅ | ✅ | `0x3d560` |
| `AudioManager` | `-` | `loadBgmData:isLoop:` |  | ✅ | ✅ | `0x3d638` |
| `AudioManager` | `-` | `loadBgmDataWithBytes:length:isLoop:` |  | ✅ | ✅ | `0x3d764` |
| `AudioManager` | `-` | `loadBgmDataWithBytesNoCopy:length:isLoop:` |  | ✅ | ✅ | `0x3d7ec` |
| `AudioManager` | `-` | `loadBgmDataWithBytesNoCopy:length:freeWhenDone:isLoop:` |  | ✅ | ✅ | `0x3d874` |
| `AudioManager` | `-` | `loadVoiceData:isLoop:` |  | ✅ | ✅ | `0x3d8fc` |
| `AudioManager` | `-` | `getGroupID:resourceId:` |  | ✅ | ❌ | `0x3dac4` |
| `AudioManager` | `-` | `loadSe:isLoop:callName:group:` |  | ✅ | ❌ | `0x3dc48` |
| `AudioManager` | `-` | `releaseSe:resourceId:` |  | ✅ | ❌ | `0x3e1a4` |
| `AudioManager` | `-` | `releaseSeAll` |  | ✅ | ❌ | `0x3e580` |
| `AudioManager` | `-` | `releaseBgm` |  | ✅ | ✅ | `0x3e868` |
| `AudioManager` | `-` | `releaseVoice` |  | ✅ | ✅ | `0x3e8d4` |
| `AudioManager` | `-` | `prepare:resourceId:volume:` |  | ✅ | ❌ | `0x3e8e4` |
| `AudioManager` | `-` | `prepareSetGroup:resourceId:groupId:` |  | ✅ | ❌ | `0x3eab0` |
| `AudioManager` | `-` | `playSe:resourceId:` |  | ✅ | ❌ | `0x3ec00` |
| `AudioManager` | `-` | `playSe:resourceId:Volume:` |  | ✅ | ❌ | `0x3ece8` |
| `AudioManager` | `-` | `playSeSetGroup:resourceId:groupId:` |  | ✅ | ✅ | `0x3edd0` |
| `AudioManager` | `-` | `stopSe:` |  | ✅ | ✅ | `0x3ee78` |
| `AudioManager` | `-` | `onPauseSe:` |  | ✅ | ✅ | `0x3eefc` |
| `AudioManager` | `-` | `offPauseSe:` |  | ✅ | ✅ | `0x3ef80` |
| `AudioManager` | `-` | `isPlayingSe:` |  | ✅ | ✅ | `0x3f004` |
| `AudioManager` | `-` | `onPauseSeAll` |  | ✅ | ✅ | `0x3f090` |
| `AudioManager` | `-` | `offPauseSeAll` |  | ✅ | ✅ | `0x3f110` |
| `AudioManager` | `-` | `stopSeAll` |  | ✅ | ✅ | `0x3f190` |
| `AudioManager` | `-` | `stopAll` |  | ✅ | ✅ | `0x3f210` |
| `AudioManager` | `-` | `orderInstanceList` |  | ✅ | ❌ | `0x3f260` |
| `AudioManager` | `-` | `orderInstanceList:` |  | ✅ | ❌ | `0x3f3c0` |
| `AudioManager` | `-` | `stopOldInstance` |  | ✅ | ✅ | `0x3f544` |
| `AudioManager` | `-` | `addInstance:group:` |  | ✅ | ✅ | `0x3f5e4` |
| `AudioManager` | `-` | `setSeVolume:groupId:` |  | ✅ | ✅ | `0x3f624` |
| `AudioManager` | `-` | `deleteFadeTimer` |  | ✅ | ✅ | `0x3f6a8` |
| `AudioManager` | `-` | `createBgmFadeInTimer:` |  | ✅ | ❌ | `0x3f714` |
| `AudioManager` | `-` | `createBgmFadeOutTimer:` |  | ✅ | ❌ | `0x3f854` |
| `AudioManager` | `-` | `playBgm:` |  | ✅ | ❌ | `0x3f994` |
| `AudioManager` | `-` | `stopBgm:` |  | ✅ | ❌ | `0x3fc1c` |
| `AudioManager` | `-` | `onPauseBgm:` |  | ✅ | ❌ | `0x3fd48` |
| `AudioManager` | `-` | `bgmCurrentTime` |  | ✅ | ❌ | `0x3fe30` |
| `AudioManager` | `-` | `bgmDeviceCurrentTime` |  | ✅ | ❌ | `0x3fed0` |
| `AudioManager` | `-` | `setBgmCurrentTime:` |  | ✅ | ❌ | `0x3ff70` |
| `AudioManager` | `-` | `isPlayingBgm` |  | ✅ | ❌ | `0x40018` |
| `AudioManager` | `-` | `onFadeInTimer:` |  | ✅ | ❌ | `0x400c4` |
| `AudioManager` | `-` | `onFadeOutTimer:` |  | ✅ | ❌ | `0x40268` |
| `AudioManager` | `-` | `pushBgm` |  | ✅ | ❌ | `0x4048c` |
| `AudioManager` | `-` | `popBgm` |  | ✅ | ❌ | `0x405a4` |
| `AudioManager` | `-` | `seekBgmToTop` |  | ✅ | ❌ | `0x40660` |
| `AudioManager` | `-` | `playVoice` |  | ✅ | ❌ | `0x406b8` |
| `AudioManager` | `-` | `stopVoice` |  | ✅ | ❌ | `0x407bc` |
| `AudioManager` | `-` | `onPauseVoice` |  | ✅ | ❌ | `0x40860` |
| `AudioManager` | `-` | `isPlayingVoice` |  | ✅ | ❌ | `0x40948` |
| `AudioManager` | `-` | `audioPlayerDidFinishPlaying:successfully:` |  | ✅ | ❌ | `0x409f4` |
| `AudioManager` | `-` | `audioPlayerBeginInterruption:` |  | ✅ | ❌ | `0x40aa8` |
| `AudioManager` | `-` | `audioPlayerEndInterruption:` |  | ✅ | ❌ | `0x40b2c` |
| `AudioManager` | `-` | `audioPlayerEndInterruption:withOptions:` |  | ✅ | ❌ | `0x40bac` |
| `AudioManager` | `-` | `suspendPlayer:` |  | ✅ | ❌ | `0x40c2c` |
| `AudioManager` | `-` | `resumePlayer:` |  | ✅ | ❌ | `0x40ce4` |
| `AudioManager` | `-` | `systemSuspend` |  | ✅ | ❌ | `0x40d6c` |
| `AudioManager` | `-` | `systemResume` |  | ✅ | ❌ | `0x40e00` |
| `AudioManager` | `-` | `dealloc` |  | ✅ | ❌ | `0x40e90` |
| `AudioManager` | `-` | `isStart` | prop | ✅ | ✅ | `0x4101c` |
| `AudioManager` | `-` | `seNameList` | prop | ✅ | ✅ | `0x4102c` |
| `AudioManager` | `-` | `setSeNameList:` | prop | ✅ | ✅ | `0x4103c` |
| `AudioManager` | `-` | `seRidList` | prop | ✅ | ✅ | `0x41074` |
| `AudioManager` | `-` | `setSeRidList:` | prop | ✅ | ✅ | `0x41084` |
| `AudioManager` | `-` | `bgmPlayer` | prop | ✅ | ✅ | `0x410bc` |
| `AudioManager` | `-` | `setBgmPlayer:` | prop | ✅ | ✅ | `0x410cc` |
| `AudioManager` | `-` | `voicePlayer` | prop | ✅ | ✅ | `0x41104` |
| `AudioManager` | `-` | `setVoicePlayer:` | prop | ✅ | ✅ | `0x41114` |
| `AudioManager` | `-` | `fadeTimer` | prop | ✅ | ✅ | `0x4114c` |
| `AudioManager` | `-` | `setFadeTimer:` | prop | ✅ | ✅ | `0x4115c` |
| `AudioManager` | `-` | `bgmPlayTime` | prop | ✅ | ✅ | `0x41194` |
| `AudioManager` | `-` | `setBgmPlayTime:` | prop | ✅ | ✅ | `0x411a4` |
| `AudioManager` | `-` | `voicePlayTime` | prop | ✅ | ✅ | `0x411b4` |
| `AudioManager` | `-` | `setVoicePlayTime:` | prop | ✅ | ✅ | `0x411c4` |
| `AudioManager` | `-` | `stackBgm` | prop | ✅ | ✅ | `0x411d4` |
| `AudioManager` | `-` | `setStackBgm:` | prop | ✅ | ✅ | `0x411e4` |
| `AudioManager` | `-` | `seType` | prop | ✅ | ✅ | `0x4121c` |
| `AudioManager` | `-` | `setSeType:` | prop | ✅ | ✅ | `0x4122c` |
| `AVBus` | `-` | `init` |  | ✅ | ❌ | `0x41308` |
| `AVBus` | `-` | `initWithContentsOfURL:isLoop:` |  | ✅ | ❌ | `0x4135c` |
| `AVBus` | `-` | `initWithContentsOfData:isLoop:` |  | ✅ | ❌ | `0x414fc` |
| `AVBus` | `-` | `setSource:` |  | ❌ | ❌ | `0x4169c` |
| `AVBus` | `-` | `removeSource` |  | ✅ | ❌ | `0x4171c` |
| `AVBus` | `-` | `prepare` |  | ✅ | ❌ | `0x41798` |
| `AVBus` | `-` | `play` |  | ✅ | ❌ | `0x41898` |
| `AVBus` | `-` | `stop` |  | ✅ | ❌ | `0x41964` |
| `AVBus` | `-` | `pause` |  | ✅ | ❌ | `0x41a08` |
| `AVBus` | `-` | `offPause` |  | ✅ | ❌ | `0x41afc` |
| `AVBus` | `-` | `setVolume:` |  | ✅ | ❌ | `0x41bc0` |
| `AVBus` | `-` | `volume` |  | ✅ | ❌ | `0x41c64` |
| `AVBus` | `-` | `status` |  | ✅ | ❌ | `0x41d04` |
| `AVBus` | `-` | `audioPlayerDidFinishPlaying:successfully:` |  | ✅ | ❌ | `0x41d14` |
| `AVBus` | `-` | `audioPlayerBeginInterruption:` |  | ✅ | ❌ | `0x41d28` |
| `AVBus` | `-` | `audioPlayerEndInterruption:` |  | ✅ | ❌ | `0x41da8` |
| `AVBus` | `-` | `audioPlayerEndInterruption:withOptions:` |  | ✅ | ❌ | `0x41e20` |
| `AVBus` | `-` | `dealloc` |  | ✅ | ❌ | `0x41e98` |
| `AVBus` | `-` | `isSameSource:` |  | ❌ | ❌ | `0x41f20` |
| `AVBus` | `-` | `currentID` |  | ✅ | ❌ | `0x41f38` |
| `AVBus` | `-` | `player` | prop | ✅ | ✅ | `0x41f48` |
| `AVBus` | `-` | `setPlayer:` | prop | ✅ | ✅ | `0x41f58` |
| `StoreTableCellBase` | `-` | `initWithStyle:reuseIdentifier:` |  | ✅ | ❌ | `0x41fa4` |
| `StoreTableCellBase` | `-` | `dealloc` |  | ✅ | ❌ | `0x42154` |
| `StoreTableCellBase` | `-` | `prepareForReuse` |  | ✅ | ❌ | `0x42248` |
| `StoreTableCellBase` | `-` | `leftView` | prop | ✅ | ✅ | `0x42308` |
| `StoreTableCellBase` | `-` | `setLeftView:` | prop | ✅ | ✅ | `0x42318` |
| `StoreTableCellBase` | `-` | `rightView` | prop | ✅ | ✅ | `0x42350` |
| `StoreTableCellBase` | `-` | `setRightView:` | prop | ✅ | ✅ | `0x42360` |
| `StoreCampaignDetailViewPad` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x423d8` |
| `StoreCampaignDetailViewPad` | `-` | `removeItemInfo` |  | ✅ | ❌ | `0x44f74` |
| `StoreCampaignDetailViewPad` | `-` | `cancelLoading` |  | ✅ | ✅ | `0x45364` |
| `StoreCampaignDetailViewPad` | `-` | `sampleStop` |  | ✅ | ❌ | `0x45368` |
| `StoreCampaignDetailViewPad` | `-` | `pushSampleBtn` |  | ✅ | ❌ | `0x454d0` |
| `StoreCampaignDetailViewPad` | `-` | `sampleViewStop` |  | ✅ | ❌ | `0x45748` |
| `StoreCampaignDetailViewPad` | `-` | `sampleViewDownloading` |  | ✅ | ❌ | `0x45840` |
| `StoreCampaignDetailViewPad` | `-` | `sampleViewPlaying` |  | ✅ | ❌ | `0x4593c` |
| `StoreCampaignDetailViewPad` | `-` | `showItemInfo` |  | ✅ | ❌ | `0x45a38` |
| `StoreCampaignDetailViewPad` | `-` | `pushLink:` |  | ✅ | ❌ | `0x45bc8` |
| `StoreCampaignDetailViewPad` | `-` | `finishBgm:` |  | ✅ | ❌ | `0x45d08` |
| `StoreCampaignDetailViewPad` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x45d24` |
| `StoreCampaignDetailViewPad` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x45ec4` |
| `StoreCampaignDetailViewPad` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x45f7c` |
| `StoreCampaignDetailViewPad` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x45f80` |
| `StoreCampaignDetailViewPad` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0x4605c` |
| `StoreCampaignDetailViewPad` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x46060` |
| `StoreCampaignDetailViewPad` | `-` | `alertViewCancel:` |  | ✅ | ❌ | `0x46064` |
| `StoreCampaignDetailViewPad` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0x46140` |
| `StoreCampaignDetailViewPad` | `-` | `setInfo:tag:` |  | ✅ | ❌ | `0x46280` |
| `StoreCampaignDetailViewPad` | `-` | `setDownloadFlag:` |  | ✅ | ❌ | `0x46f48` |
| `StoreCampaignDetailViewPad` | `-` | `hasItem:itemID:` |  | ✅ | ❌ | `0x470d4` |
| `StoreCampaignDetailViewPad` | `-` | `getArtworkMargin:` |  | ✅ | ❌ | `0x471e8` |
| `StoreCampaignDetailViewPad` | `-` | `getItemSize:` |  | ✅ | ❌ | `0x471f4` |
| `StoreCampaignDetailViewPad` | `-` | `setArtwork:` |  | ✅ | ❌ | `0x47208` |
| `StoreCampaignDetailViewPad` | `-` | `itemInfo` | prop | ✅ | ✅ | `0x474d0` |
| `StoreCampaignDetailViewPad` | `-` | `setItemInfo:` | prop | ✅ | ✅ | `0x474e0` |
| `StoreCampaignDetailViewPad` | `-` | `delegate` | prop | ✅ | ✅ | `0x47518` |
| `StoreCampaignDetailViewPad` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x47538` |
| `StoreCampaignDetailViewPad` | `-` | `itemView` | prop | ✅ | ✅ | `0x4754c` |
| `StoreCampaignDetailViewPad` | `-` | `setItemView:` | prop | ✅ | ✅ | `0x4755c` |
| `StoreCampaignDetailViewPad` | `-` | `labelTitle` | prop | ✅ | ✅ | `0x47594` |
| `StoreCampaignDetailViewPad` | `-` | `setLabelTitle:` | prop | ✅ | ✅ | `0x475a4` |
| `StoreCampaignDetailViewPad` | `-` | `artworkView` | prop | ✅ | ✅ | `0x475dc` |
| `StoreCampaignDetailViewPad` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0x475ec` |
| `StoreCampaignDetailViewPad` | `-` | `labelItemName` | prop | ✅ | ✅ | `0x47624` |
| `StoreCampaignDetailViewPad` | `-` | `setLabelItemName:` | prop | ✅ | ✅ | `0x47634` |
| `StoreCampaignDetailViewPad` | `-` | `labelArtistName` | prop | ✅ | ✅ | `0x4766c` |
| `StoreCampaignDetailViewPad` | `-` | `setLabelArtistName:` | prop | ✅ | ✅ | `0x4767c` |
| `StoreCampaignDetailViewPad` | `-` | `labelLevels` | prop | ✅ | ✅ | `0x476b4` |
| `StoreCampaignDetailViewPad` | `-` | `setLabelLevels:` | prop | ✅ | ✅ | `0x476c4` |
| `StoreCampaignDetailViewPad` | `-` | `labelID` | prop | ✅ | ✅ | `0x476fc` |
| `StoreCampaignDetailViewPad` | `-` | `setLabelID:` | prop | ✅ | ✅ | `0x4770c` |
| `StoreCampaignDetailViewPad` | `-` | `copyrightView` | prop | ✅ | ✅ | `0x47744` |
| `StoreCampaignDetailViewPad` | `-` | `setCopyrightView:` | prop | ✅ | ✅ | `0x47754` |
| `StoreCampaignDetailViewPad` | `-` | `downloadBtn` | prop | ✅ | ✅ | `0x4778c` |
| `StoreCampaignDetailViewPad` | `-` | `setDownloadBtn:` | prop | ✅ | ✅ | `0x4779c` |
| `StoreCampaignDetailViewPad` | `-` | `linkBtn` | prop | ✅ | ✅ | `0x477d4` |
| `StoreCampaignDetailViewPad` | `-` | `setLinkBtn:` | prop | ✅ | ✅ | `0x477e4` |
| `StoreCampaignDetailViewPad` | `-` | `campaignID` | prop | ✅ | ✅ | `0x4781c` |
| `StoreCampaignDetailViewPad` | `-` | `setCampaignID:` | prop | ✅ | ✅ | `0x4782c` |
| `StoreCampaignDetailViewPad` | `-` | `sampleDownloader` | prop | ✅ | ✅ | `0x4783c` |
| `StoreCampaignDetailViewPad` | `-` | `setSampleDownloader:` | prop | ✅ | ✅ | `0x4784c` |
| `StoreCampaignDetailViewPad` | `-` | `indicator` | prop | ✅ | ✅ | `0x47884` |
| `StoreCampaignDetailViewPad` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x47894` |
| `StoreCampaignDetailViewPad` | `-` | `labelLoading` | prop | ✅ | ✅ | `0x478cc` |
| `StoreCampaignDetailViewPad` | `-` | `setLabelLoading:` | prop | ✅ | ✅ | `0x478dc` |
| `StoreCampaignDetailViewPad` | `-` | `sampleBtn` | prop | ✅ | ✅ | `0x47914` |
| `StoreCampaignDetailViewPad` | `-` | `setSampleBtn:` | prop | ✅ | ✅ | `0x47924` |
| `StoreCampaignDetailViewPad` | `-` | `playingView` | prop | ✅ | ✅ | `0x4795c` |
| `StoreCampaignDetailViewPad` | `-` | `setPlayingView:` | prop | ✅ | ✅ | `0x4796c` |
| `StoreCampaignDetailViewPad` | `-` | `detailView` | prop | ✅ | ✅ | `0x479a4` |
| `StoreCampaignDetailViewPad` | `-` | `setDetailView:` | prop | ✅ | ✅ | `0x479b4` |
| `StoreCampaignDetailViewPad` | `-` | `bannerView` | prop | ✅ | ✅ | `0x479ec` |
| `StoreCampaignDetailViewPad` | `-` | `setBannerView:` | prop | ✅ | ✅ | `0x479fc` |
| `StoreCampaignDetailViewPad` | `-` | `descriptionTextView` | prop | ✅ | ✅ | `0x47a34` |
| `StoreCampaignDetailViewPad` | `-` | `setDescriptionTextView:` | prop | ✅ | ✅ | `0x47a44` |
| `StoreCampaignDetailViewPad` | `-` | `indicatorSample` | prop | ✅ | ✅ | `0x47a7c` |
| `StoreCampaignDetailViewPad` | `-` | `setIndicatorSample:` | prop | ✅ | ✅ | `0x47a8c` |
| `RBTermDetailPhoneViewController` | `-` | `initWithID:title:` |  | ✅ | ❌ | `0x48508` |
| `RBTermDetailPhoneViewController` | `-` | `setViewTypeStore` |  | ✅ | ✅ | `0x4888c` |
| `RBTermDetailPhoneViewController` | `-` | `dealloc` |  | ❌ | ✅ | `0x4889c` |
| `RBTermDetailPhoneViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x488d0` |
| `RBTermDetailPhoneViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x490c8` |
| `RBTermDetailPhoneViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x49264` |
| `RBTermDetailPhoneViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0x492b4` |
| `RBTermDetailPhoneViewController` | `-` | `loadDetail` |  | ✅ | ❌ | `0x492e8` |
| `RBTermDetailPhoneViewController` | `-` | `showTermView` |  | ✅ | ❌ | `0x49ac4` |
| `RBTermDetailPhoneViewController` | `-` | `startLoadAnimation` |  | ✅ | ❌ | `0x49f7c` |
| `RBTermDetailPhoneViewController` | `-` | `endLoadAnimation` |  | ✅ | ❌ | `0x4a07c` |
| `RBTermDetailPhoneViewController` | `-` | `pushBarBtnBack:` |  | ✅ | ❌ | `0x4a130` |
| `RBTermDetailPhoneViewController` | `-` | `forceClose` |  | ✅ | ❌ | `0x4a200` |
| `RBTermDetailPhoneViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x4a2c8` |
| `RBTermDetailPhoneViewController` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0x4a340` |
| `RBTermDetailPhoneViewController` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x4a344` |
| `RBTermDetailPhoneViewController` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0x4a348` |
| `RBTermDetailPhoneViewController` | `-` | `isFirstRequest` | prop | ✅ | ✅ | `0x4a34c` |
| `RBTermDetailPhoneViewController` | `-` | `setIsFirstRequest:` | prop | ✅ | ✅ | `0x4a35c` |
| `RBTermDetailPhoneViewController` | `-` | `isAnimating` | prop | ✅ | ✅ | `0x4a36c` |
| `RBTermDetailPhoneViewController` | `-` | `setIsAnimating:` | prop | ✅ | ✅ | `0x4a37c` |
| `RBTermDetailPhoneViewController` | `-` | `buttons` | prop | ✅ | ✅ | `0x4a38c` |
| `RBTermDetailPhoneViewController` | `-` | `setButtons:` | prop | ✅ | ✅ | `0x4a39c` |
| `RBTermDetailPhoneViewController` | `-` | `ID` | prop | ✅ | ✅ | `0x4a3d4` |
| `RBTermDetailPhoneViewController` | `-` | `setID:` | prop | ✅ | ✅ | `0x4a3e4` |
| `RBTermDetailPhoneViewController` | `-` | `termView` | prop | ✅ | ✅ | `0x4a41c` |
| `RBTermDetailPhoneViewController` | `-` | `setTermView:` | prop | ✅ | ✅ | `0x4a42c` |
| `RBTermDetailPhoneViewController` | `-` | `termTextView` | prop | ✅ | ✅ | `0x4a43c` |
| `RBTermDetailPhoneViewController` | `-` | `setTermTextView:` | prop | ✅ | ✅ | `0x4a44c` |
| `RBTermDetailPhoneViewController` | `-` | `terms` | prop | ✅ | ✅ | `0x4a45c` |
| `RBTermDetailPhoneViewController` | `-` | `setTerms:` | prop | ✅ | ✅ | `0x4a46c` |
| `RBTermDetailPhoneViewController` | `-` | `downloader` | prop | ✅ | ✅ | `0x4a4a4` |
| `RBTermDetailPhoneViewController` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x4a4b4` |
| `RBTermDetailPhoneViewController` | `-` | `isUseGrayView` | prop | ✅ | ✅ | `0x4a4ec` |
| `RBTermDetailPhoneViewController` | `-` | `setIsUseGrayView:` | prop | ✅ | ✅ | `0x4a4fc` |
| `RBTermDetailPhoneViewController` | `-` | `grayView` | prop | ✅ | ✅ | `0x4a50c` |
| `RBTermDetailPhoneViewController` | `-` | `setGrayView:` | prop | ✅ | ✅ | `0x4a51c` |
| `RBTermDetailPhoneViewController` | `-` | `indicatorView` | prop | ✅ | ✅ | `0x4a52c` |
| `RBTermDetailPhoneViewController` | `-` | `setIndicatorView:` | prop | ✅ | ✅ | `0x4a53c` |
| `RBTermDetailPhoneViewController` | `-` | `viewType` | prop | ✅ | ✅ | `0x4a54c` |
| `RBTermDetailPhoneViewController` | `-` | `setViewType:` | prop | ✅ | ✅ | `0x4a55c` |
| `StoreExtendNoteView` | `-` | `initWithFrame:` |  | ❌ | ❌ | `0x4bcc4` |
| `StoreExtendNoteView` | `-` | `dealloc` |  | ❌ | ❌ | `0x4ca54` |
| `StoreExtendNoteView` | `-` | `setArtwork:` |  | ❌ | ❌ | `0x4cadc` |
| `StoreExtendNoteView` | `-` | `isPurchased` |  | ❌ | ❌ | `0x4cb68` |
| `StoreExtendNoteView` | `-` | `setIsPurchased:` |  | ❌ | ❌ | `0x4cbc8` |
| `StoreExtendNoteView` | `-` | `loadExtendNoteInfo:index:` |  | ❌ | ❌ | `0x4cc28` |
| `StoreExtendNoteView` | `-` | `reset` |  | ✅ | ❌ | `0x4d004` |
| `StoreExtendNoteView` | `-` | `artworkImageView` | prop | ❌ | ✅ | `0x4d058` |
| `StoreExtendNoteView` | `-` | `setArtworkImageView:` | prop | ❌ | ✅ | `0x4d068` |
| `StoreExtendNoteView` | `-` | `artworkBackImageView` | prop | ❌ | ✅ | `0x4d0a0` |
| `StoreExtendNoteView` | `-` | `setArtworkBackImageView:` | prop | ❌ | ✅ | `0x4d0b0` |
| `StoreExtendNoteView` | `-` | `nameLabel` | prop | ❌ | ✅ | `0x4d0e8` |
| `StoreExtendNoteView` | `-` | `setNameLabel:` | prop | ❌ | ✅ | `0x4d0f8` |
| `StoreExtendNoteView` | `-` | `artistLabel` | prop | ❌ | ✅ | `0x4d130` |
| `StoreExtendNoteView` | `-` | `setArtistLabel:` | prop | ❌ | ✅ | `0x4d140` |
| `StoreExtendNoteView` | `-` | `commentLabel` | prop | ❌ | ✅ | `0x4d178` |
| `StoreExtendNoteView` | `-` | `setCommentLabel:` | prop | ❌ | ✅ | `0x4d188` |
| `StoreExtendNoteView` | `-` | `levelLabel` | prop | ❌ | ✅ | `0x4d1c0` |
| `StoreExtendNoteView` | `-` | `setLevelLabel:` | prop | ❌ | ✅ | `0x4d1d0` |
| `StoreExtendNoteView` | `-` | `purchasedLabel` | prop | ❌ | ✅ | `0x4d208` |
| `StoreExtendNoteView` | `-` | `setPurchasedLabel:` | prop | ❌ | ✅ | `0x4d218` |
| `StoreExtendNoteView` | `-` | `linkURL` | prop | ❌ | ✅ | `0x4d250` |
| `StoreExtendNoteView` | `-` | `setLinkURL:` | prop | ❌ | ✅ | `0x4d260` |
| `AppDelegate` | `+` | `initialize` |  | ✅ | ✅ | `0x4d778` |
| `AppDelegate` | `-` | `startApplication` |  | ✅ | ✅ | `0x4d77c` |
| `AppDelegate` | `-` | `requestResourceInfo` |  | ✅ | ❌ | `0x4da2c` |
| `AppDelegate` | `-` | `getBaseWebInfoURL` |  | ✅ | ✅ | `0x4eb78` |
| `AppDelegate` | `-` | `setWebInfoURL:` |  | ✅ | ✅ | `0x4eb88` |
| `AppDelegate` | `-` | `getWebInfoURL` |  | ✅ | ✅ | `0x4ec18` |
| `AppDelegate` | `-` | `setPreWebInfoURL:` |  | ✅ | ✅ | `0x4ec28` |
| `AppDelegate` | `-` | `getPreWebInfoURL` |  | ✅ | ✅ | `0x4eca4` |
| `AppDelegate` | `-` | `setBaseTermURL:` |  | ✅ | ✅ | `0x4ecb4` |
| `AppDelegate` | `-` | `getBaseTermURL` |  | ✅ | ✅ | `0x4ecec` |
| `AppDelegate` | `-` | `getTermURLWithID:` |  | ✅ | ✅ | `0x4ecfc` |
| `AppDelegate` | `-` | `setTermLastUpdateTimeString:` | prop | ✅ | ✅ | `0x4ee08` |
| `AppDelegate` | `-` | `getTermLastUpdateTimeString` |  | ✅ | ✅ | `0x4ee40` |
| `AppDelegate` | `-` | `needUpdateTerms` |  | ✅ | ✅ | `0x4ee50` |
| `AppDelegate` | `-` | `setLatestTermsVersion:` |  | ✅ | ✅ | `0x4ef50` |
| `AppDelegate` | `-` | `setInfoLastUpdateTimeString:` | prop | ✅ | ✅ | `0x4ef6c` |
| `AppDelegate` | `-` | `getInfoLastUpdateTimeString` |  | ✅ | ✅ | `0x4efa4` |
| `AppDelegate` | `-` | `setPackIDForOpenStore:` | prop | ✅ | ✅ | `0x4efb4` |
| `AppDelegate` | `-` | `getPackIDForOpenStore` |  | ✅ | ✅ | `0x4efec` |
| `AppDelegate` | `-` | `setCampaignIDForOpenStore:` | prop | ✅ | ✅ | `0x4effc` |
| `AppDelegate` | `-` | `getCampaignIDForOpenStore` |  | ✅ | ✅ | `0x4f034` |
| `AppDelegate` | `-` | `setExtendNotePIDForOpenStore:` | prop | ✅ | ✅ | `0x4f044` |
| `AppDelegate` | `-` | `getExtendNotePIDForOpenStore` |  | ✅ | ✅ | `0x4f07c` |
| `AppDelegate` | `+` | `getPushNotificationData` |  | ✅ | ✅ | `0x4f08c` |
| `AppDelegate` | `+` | `popPushNotificationData` |  | ✅ | ✅ | `0x4f0fc` |
| `AppDelegate` | `+` | `addPushNotificationData:` |  | ✅ | ✅ | `0x4f314` |
| `AppDelegate` | `+` | `getOuterURL` |  | ✅ | ✅ | `0x4f3d4` |
| `AppDelegate` | `+` | `setOuterURL:` |  | ✅ | ✅ | `0x4f444` |
| `AppDelegate` | `-` | `isEnableEarlyBonus` |  | ✅ | ✅ | `0x4f4d0` |
| `AppDelegate` | `-` | `isEnableHotBonus` |  | ✅ | ✅ | `0x4f658` |
| `AppDelegate` | `-` | `showTitle` |  | ✅ | ✅ | `0x4f7e0` |
| `AppDelegate` | `-` | `showTerms` |  | ✅ | ✅ | `0x4faf4` |
| `AppDelegate` | `-` | `startupRequest` |  | ✅ | ✅ | `0x4fb4c` |
| `AppDelegate` | `-` | `showDownload` |  | ✅ | ✅ | `0x50398` |
| `AppDelegate` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ✅ | `0x504dc` |
| `AppDelegate` | `+` | `ApplilinkInitialize` |  | ✅ | ✅ | `0x50698` |
| `AppDelegate` | `+` | `setRecommendUnreadCount` |  | ✅ | ✅ | `0x50920` |
| `AppDelegate` | `+` | `appDelegate` |  | ✅ | ✅ | `0x50af0` |
| `AppDelegate` | `+` | `setNoBackupAttribute:` |  | ✅ | ✅ | `0x50b60` |
| `AppDelegate` | `+` | `totalScoreLeaderboardCategory` |  | ✅ | ✅ | `0x50c8c` |
| `AppDelegate` | `+` | `musicListKey` |  | ✅ | ✅ | `0x50cb8` |
| `AppDelegate` | `+` | `getServerData` |  | ✅ | ✅ | `0x511cc` |
| `AppDelegate` | `+` | `setServerData:andB:` |  | ✅ | ✅ | `0x514c8` |
| `AppDelegate` | `+` | `saveDataKey` |  | ✅ | ✅ | `0x517fc` |
| `AppDelegate` | `-` | `resetGame` |  | ✅ | ✅ | `0x51828` |
| `AppDelegate` | `-` | `application:openURL:sourceApplication:annotation:` |  | ✅ | ✅ | `0x51bc8` |
| `AppDelegate` | `-` | `application:didFinishLaunchingWithOptions:` |  | ✅ | ❌ | `0x51c88` |
| `AppDelegate` | `-` | `applicationDidBecomeActive:` |  | ✅ | ✅ | `0x52cbc` |
| `AppDelegate` | `-` | `applicationWillResignActive:` |  | ✅ | ✅ | `0x52f8c` |
| `AppDelegate` | `-` | `applicationWillEnterForeground:` |  | ✅ | ✅ | `0x5307c` |
| `AppDelegate` | `-` | `applicationDidEnterBackground:` |  | ✅ | ✅ | `0x530b4` |
| `AppDelegate` | `-` | `applicationWillTerminate:` |  | ✅ | ✅ | `0x531a4` |
| `AppDelegate` | `+` | `launchAppStore` |  | ❌ | ❌ | `0x53268` |
| `AppDelegate` | `-` | `applicationDidReceiveMemoryWarning:` |  | ✅ | ✅ | `0x53350` |
| `AppDelegate` | `-` | `applicationSignificantTimeChange:` |  | ✅ | ✅ | `0x533b4` |
| `AppDelegate` | `-` | `application:willChangeStatusBarOrientation:duration:` |  | ✅ | ✅ | `0x533b8` |
| `AppDelegate` | `-` | `application:didChangeStatusBarOrientation:` |  | ✅ | ✅ | `0x533bc` |
| `AppDelegate` | `-` | `application:willChangeStatusBarFrame:` |  | ✅ | ✅ | `0x533c0` |
| `AppDelegate` | `-` | `application:didChangeStatusBarFrame:` |  | ✅ | ✅ | `0x533c4` |
| `AppDelegate` | `-` | `startRegisterForRemoteNotification` |  | ✅ | ✅ | `0x533c8` |
| `AppDelegate` | `-` | `application:didRegisterUserNotificationSettings:` |  | ✅ | ✅ | `0x53628` |
| `AppDelegate` | `-` | `application:didRegisterForRemoteNotificationsWithDeviceToken:` |  | ✅ | ❌ | `0x53678` |
| `AppDelegate` | `-` | `application:didFailToRegisterForRemoteNotificationsWithError:` |  | ✅ | ✅ | `0x53cd4` |
| `AppDelegate` | `-` | `application:didReceiveRemoteNotification:` |  | ✅ | ❌ | `0x53cd8` |
| `AppDelegate` | `-` | `application:didReceiveLocalNotification:` |  | ✅ | ❌ | `0x54210` |
| `AppDelegate` | `-` | `applicationProtectedDataWillBecomeUnavailable:` |  | ✅ | ✅ | `0x54548` |
| `AppDelegate` | `-` | `applicationProtectedDataDidBecomeAvailable:` |  | ✅ | ✅ | `0x5454c` |
| `AppDelegate` | `-` | `audioSessionInterrupted:` |  | ✅ | ✅ | `0x54550` |
| `AppDelegate` | `-` | `window` | prop | ✅ | ✅ | `0x54684` |
| `AppDelegate` | `-` | `setWindow:` | prop | ✅ | ✅ | `0x54694` |
| `AppDelegate` | `-` | `viewController` | prop | ✅ | ✅ | `0x546cc` |
| `AppDelegate` | `-` | `setViewController:` | prop | ✅ | ✅ | `0x546dc` |
| `AppDelegate` | `-` | `navigationController` | prop | ✅ | ✅ | `0x54714` |
| `AppDelegate` | `-` | `setNavigationController:` | prop | ✅ | ✅ | `0x54724` |
| `AppDelegate` | `-` | `strageAlertView` | prop | ✅ | ✅ | `0x5475c` |
| `AppDelegate` | `-` | `setStrageAlertView:` | prop | ✅ | ✅ | `0x5476c` |
| `AppDelegate` | `-` | `musicData` | prop | ✅ | ✅ | `0x547a4` |
| `AppDelegate` | `-` | `setMusicData:` | prop | ✅ | ✅ | `0x547b4` |
| `AppDelegate` | `-` | `replayData` | prop | ✅ | ✅ | `0x547ec` |
| `AppDelegate` | `-` | `setReplayData:` | prop | ✅ | ✅ | `0x547fc` |
| `AppDelegate` | `-` | `searchString` | prop | ✅ | ✅ | `0x54834` |
| `AppDelegate` | `-` | `setSearchString:` | prop | ✅ | ✅ | `0x54844` |
| `AppDelegate` | `-` | `unreadRecommendCount` | prop | ✅ | ✅ | `0x5487c` |
| `AppDelegate` | `-` | `setUnreadRecommendCount:` | prop | ✅ | ✅ | `0x5488c` |
| `AppDelegate` | `-` | `applilinkInitialized` | prop | ✅ | ✅ | `0x5489c` |
| `AppDelegate` | `-` | `setApplilinkInitialized:` | prop | ✅ | ✅ | `0x548b0` |
| `AppDelegate` | `-` | `earlyBonusList` | prop | ✅ | ✅ | `0x548c0` |
| `AppDelegate` | `-` | `setEarlyBonusList:` | prop | ✅ | ✅ | `0x548d0` |
| `AppDelegate` | `-` | `hotBonusList` | prop | ✅ | ✅ | `0x54908` |
| `AppDelegate` | `-` | `setHotBonusList:` | prop | ✅ | ✅ | `0x54918` |
| `AppDelegate` | `-` | `isShowedMap` | prop | ✅ | ✅ | `0x54950` |
| `AppDelegate` | `-` | `setIsShowedMap:` | prop | ✅ | ✅ | `0x54960` |
| `AppDelegate` | `-` | `isSkipUpdate` | prop | ✅ | ✅ | `0x54970` |
| `AppDelegate` | `-` | `setIsSkipUpdate:` | prop | ✅ | ✅ | `0x54980` |
| `AppDelegate` | `-` | `isUpdate` | prop | ✅ | ✅ | `0x54990` |
| `AppDelegate` | `-` | `setIsUpdate:` | prop | ✅ | ✅ | `0x549a0` |
| `AppDelegate` | `-` | `resourceDownloadViewController` | prop | ❌ | ✅ | `0x549b0` |
| `AppDelegate` | `-` | `setResourceDownloadViewController:` | prop | ❌ | ✅ | `0x549c0` |
| `AppDelegate` | `-` | `urlString` | prop | ✅ | ✅ | `0x549f8` |
| `AppDelegate` | `-` | `setUrlString:` | prop | ✅ | ✅ | `0x54a08` |
| `AppDelegate` | `-` | `version` | prop | ✅ | ✅ | `0x54a14` |
| `AppDelegate` | `-` | `setVersion:` | prop | ✅ | ✅ | `0x54a24` |
| `AppDelegate` | `-` | `serverTime` | prop | ✅ | ✅ | `0x54a30` |
| `AppDelegate` | `-` | `setServerTime:` | prop | ✅ | ✅ | `0x54a40` |
| `AppDelegate` | `-` | `mustUpdateFlag` | prop | ✅ | ✅ | `0x54a5c` |
| `AppDelegate` | `-` | `setMustUpdateFlag:` | prop | ✅ | ✅ | `0x54a6c` |
| `AppDelegate` | `-` | `isStarting` | prop | ✅ | ✅ | `0x54a78` |
| `AppDelegate` | `-` | `setIsStarting:` | prop | ✅ | ✅ | `0x54a88` |
| `AppDelegate` | `-` | `urlBaseWebInfo` | prop | ✅ | ✅ | `0x54a98` |
| `AppDelegate` | `-` | `setUrlBaseWebInfo:` | prop | ✅ | ✅ | `0x54aa8` |
| `AppDelegate` | `-` | `urlWebInfo` | prop | ✅ | ✅ | `0x54ab4` |
| `AppDelegate` | `-` | `setUrlWebInfo:` | prop | ✅ | ✅ | `0x54ac4` |
| `AppDelegate` | `-` | `urlPreWebInfo` | prop | ✅ | ✅ | `0x54ad0` |
| `AppDelegate` | `-` | `setUrlPreWebInfo:` | prop | ✅ | ✅ | `0x54ae0` |
| `AppDelegate` | `-` | `infoLastUpdateTimeString` | prop | ✅ | ✅ | `0x54aec` |
| `AppDelegate` | `-` | `packIDForOpenStore` | prop | ✅ | ✅ | `0x54afc` |
| `AppDelegate` | `-` | `campaignIDForOpenStore` | prop | ✅ | ✅ | `0x54b0c` |
| `AppDelegate` | `-` | `extendNotePIDForOpenStore` | prop | ✅ | ✅ | `0x54b1c` |
| `AppDelegate` | `-` | `urlBaseTerm` | prop | ✅ | ✅ | `0x54b2c` |
| `AppDelegate` | `-` | `setUrlBaseTerm:` | prop | ✅ | ✅ | `0x54b3c` |
| `AppDelegate` | `-` | `urlTerm` | prop | ✅ | ✅ | `0x54b48` |
| `AppDelegate` | `-` | `setUrlTerm:` | prop | ✅ | ✅ | `0x54b58` |
| `AppDelegate` | `-` | `termLastUpdateTimeString` | prop | ✅ | ✅ | `0x54b64` |
| `AppDelegate` | `-` | `latestTermVer` | prop | ✅ | ✅ | `0x54b74` |
| `AppDelegate` | `-` | `setLatestTermVer:` | prop | ✅ | ✅ | `0x54b84` |
| `AppDelegate` | `-` | `pushList` | prop | ✅ | ✅ | `0x54b90` |
| `AppDelegate` | `-` | `setPushList:` | prop | ✅ | ✅ | `0x54ba0` |
| `AppDelegate` | `-` | `outerUrl` | prop | ✅ | ✅ | `0x54bd8` |
| `AppDelegate` | `-` | `setOuterUrl:` | prop | ✅ | ✅ | `0x54be8` |
| `AppDelegate` | `-` | `downloader` | prop | ✅ | ✅ | `0x54bf4` |
| `AppDelegate` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x54c04` |
| `AppDelegate` | `-` | `apnsUploader` | prop | ✅ | ✅ | `0x54c3c` |
| `AppDelegate` | `-` | `setApnsUploader:` | prop | ✅ | ✅ | `0x54c4c` |
| `RBStoreManageSortViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x556e0` |
| `RBStoreManageSortViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x55ca4` |
| `RBStoreManageSortViewController` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ❌ | `0x55d80` |
| `RBStoreManageSortViewController` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ✅ | `0x56064` |
| `RBStoreManageSortViewController` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ❌ | `0x5606c` |
| `RBStoreManageSortViewController` | `-` | `tableView:willDisplayCell:forRowAtIndexPath:` |  | ✅ | ✅ | `0x56088` |
| `RBStoreManageSortViewController` | `-` | `tableView:heightForRowAtIndexPath:` |  | ✅ | ✅ | `0x5608c` |
| `RBStoreManageSortViewController` | `-` | `tableView:didSelectRowAtIndexPath:` |  | ✅ | ❌ | `0x56098` |
| `RBStoreManageSortViewController` | `-` | `manageViewCtrl` | prop | ✅ | ✅ | `0x56330` |
| `RBStoreManageSortViewController` | `-` | `setManageViewCtrl:` | prop | ✅ | ✅ | `0x56340` |
| `RBStoreManageSortViewController` | `-` | `tableView` | prop | ✅ | ✅ | `0x56350` |
| `RBStoreManageSortViewController` | `-` | `setTableView:` | prop | ✅ | ✅ | `0x56360` |
| `RBStoreManageSortViewController` | `-` | `sortTitleList` | prop | ✅ | ✅ | `0x56398` |
| `RBStoreManageSortViewController` | `-` | `setSortTitleList:` | prop | ✅ | ✅ | `0x563a8` |
| `RBStoreManageSortViewController` | `-` | `sortRuleCount` | prop | ✅ | ✅ | `0x563e0` |
| `RBStoreManageSortViewController` | `-` | `setSortRuleCount:` | prop | ✅ | ✅ | `0x563f0` |
| `StoreCampaignTableViewCell` | `-` | `initWithDeviceType:reuseIdentifier:tag:` |  | ✅ | ❌ | `0x56440` |
| `StoreCampaignTableViewCell` | `-` | `setInfo:tag:` |  | ✅ | ❌ | `0x56c64` |
| `StoreCampaignTableViewCell` | `-` | `setDownloadFlag:` |  | ✅ | ❌ | `0x56e6c` |
| `StoreCampaignTableViewCell` | `-` | `hasItem:itemID:` |  | ✅ | ❌ | `0x56e90` |
| `StoreCampaignTableViewCell` | `+` | `cellHeight:` |  | ✅ | ❌ | `0x56fa4` |
| `StoreCampaignTableViewCell` | `-` | `getArtworkMargin:` |  | ✅ | ❌ | `0x56fc0` |
| `StoreCampaignTableViewCell` | `-` | `getItemSize:` |  | ✅ | ❌ | `0x56fd4` |
| `StoreCampaignTableViewCell` | `-` | `setArtwork:` |  | ✅ | ❌ | `0x57004` |
| `StoreCampaignTableViewCell` | `-` | `artworkView` | prop | ✅ | ✅ | `0x57204` |
| `StoreCampaignTableViewCell` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0x57214` |
| `StoreCampaignTableViewCell` | `-` | `campaignID` | prop | ✅ | ✅ | `0x5724c` |
| `StoreCampaignTableViewCell` | `-` | `indicator` | prop | ✅ | ✅ | `0x5725c` |
| `StoreCampaignTableViewCell` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x5726c` |
| `MusicDataExtend` | `-` | `setExtendSheetWithPath:ID:` |  | ✅ | ✅ | `0x5a22c` |
| `MusicDataExtend` | `+` | `dataWithPath:dictionary:` |  | ✅ | ❌ | `0x5a230` |
| `MusicDataExtend` | `-` | `sheetSpecial` | prop | ✅ | ❌ | `0x5a428` |
| `MusicDataExtend` | `-` | `sheetSpecialLight` | prop | ✅ | ❌ | `0x5a4fc` |
| `MusicDataExtend` | `+` | `getExtendZipData:Path:DecodeType:` |  | ❌ | ❌ | `0x5a5d0` |
| `MusicDataExtend` | `-` | `dealloc` |  | ❌ | ✅ | `0x5a5d8` |
| `MusicDataExtend` | `-` | `getZipData:` |  | ✅ | ✅ | `0x5a60c` |
| `MusicDataExtend` | `-` | `createCache` |  | ✅ | ✅ | `0x5a614` |
| `MusicDataExtend` | `-` | `releaseCache` |  | ✅ | ✅ | `0x5a618` |
| `MusicDataExtend` | `-` | `isArtworkCache` |  | ✅ | ✅ | `0x5a61c` |
| `MusicDataExtend` | `-` | `ExtMusicID` | prop | ✅ | ✅ | `0x5a624` |
| `MusicDataExtend` | `-` | `setExtMusicID:` | prop | ✅ | ✅ | `0x5a634` |
| `MusicDataExtend` | `-` | `MusicID` | prop | ✅ | ✅ | `0x5a644` |
| `MusicDataExtend` | `-` | `setMusicID:` | prop | ✅ | ✅ | `0x5a654` |
| `MusicDataExtend` | `-` | `difficulty` | prop | ✅ | ✅ | `0x5a664` |
| `MusicDataExtend` | `-` | `setDifficulty:` | prop | ✅ | ✅ | `0x5a674` |
| `MusicDataExtend` | `-` | `comment` | prop | ✅ | ✅ | `0x5a684` |
| `MusicDataExtend` | `-` | `setComment:` | prop | ✅ | ✅ | `0x5a694` |
| `MusicDataExtend` | `-` | `dataPath` | prop | ✅ | ✅ | `0x5a6cc` |
| `MusicDataExtend` | `-` | `setDataPath:` | prop | ✅ | ✅ | `0x5a6dc` |
| `MusicDataExtend` | `-` | `extFilePath` | prop | ✅ | ✅ | `0x5a714` |
| `MusicDataExtend` | `-` | `setExtFilePath:` | prop | ✅ | ✅ | `0x5a724` |
| `MusicDataExtend` | `-` | `decodeType` | prop | ✅ | ✅ | `0x5a75c` |
| `MusicDataExtend` | `-` | `setDecodeType:` | prop | ✅ | ✅ | `0x5a76c` |
| `History` | `+` | `getScoreData:Difficulty:inManagedObjectContext:` |  | ✅ | ❌ | `0x5a7d0` |
| `History` | `+` | `getScoreData:inManagedObjectContext:` |  | ✅ | ❌ | `0x5abd8` |
| `History` | `+` | `getScoreDataWithStartDate:andEndDate:andLimit:inManagedObjectContext:` |  | ✅ | ❌ | `0x5afec` |
| `History` | `+` | `deleteObject:` |  | ✅ | ❌ | `0x5b434` |
| `History` | `+` | `count:` |  | ✅ | ❌ | `0x5b69c` |
| `History` | `+` | `recordWithTuneID:Difficulty:inManagedObjectContext:` |  | ✅ | ❌ | `0x5b7ac` |
| `History` | `+` | `reset:` |  | ✅ | ❌ | `0x5b900` |
| `History` | `+` | `hashScoreforTune:Difficulty:Score:Just:Great:Good:Miss:JR:Combo:Date:Count:Hash:` |  | ❌ | ❌ | `0x5bb88` |
| `History` | `+` | `hashScore:` |  | ✅ | ❌ | `0x5bc38` |
| `History` | `+` | `checkScore:` |  | ✅ | ❌ | `0x5c01c` |
| `History` | `+` | `getAR:` |  | ✅ | ❌ | `0x5c0fc` |
| `History` | `+` | `getFullCombo:` |  | ✅ | ❌ | `0x5c290` |
| `ScoreData` | `+` | `getScoreData:inManagedObjectContext:` |  | ✅ | ❌ | `0x5c444` |
| `ScoreData` | `+` | `getScoreDatas:inManagedObjectContext:` |  | ✅ | ❌ | `0x5c854` |
| `ScoreData` | `+` | `recordWithTuneID:inManagedObjectContext:` |  | ✅ | ❌ | `0x5cd7c` |
| `ScoreData` | `+` | `reset:` |  | ✅ | ❌ | `0x5ce78` |
| `ScoreData` | `+` | `hashScoreforTune:Basic:Medium:Hard:Hash:` |  | ✅ | ❌ | `0x5d300` |
| `ScoreData` | `+` | `hashScore:` |  | ✅ | ✅ | `0x5d3bc` |
| `ScoreData` | `+` | `checkScore:` |  | ✅ | ❌ | `0x5d698` |
| `ScoreData` | `+` | `totalScore` |  | ✅ | ❌ | `0x5d778` |
| `ScoreData` | `-` | `getFrameBonusType` |  | ✅ | ✅ | `0x5df3c` |
| `ScoreData` | `-` | `checkOverScore` |  | ✅ | ❌ | `0x5e150` |
| `ScoreData` | `+` | `totalRecordCount` |  | ✅ | ❌ | `0x5e820` |
| `MusicData` | `+` | `GetYomiIndex:` |  | ✅ | ❌ | `0x5ea48` |
| `MusicData` | `+` | `GetYomiString:` |  | ✅ | ❌ | `0x5eb44` |
| `MusicData` | `+` | `decodeBF:Key:KeyLength:` |  | ✅ | ❌ | `0x5eb78` |
| `MusicData` | `+` | `getZipData:Path:DecodeType:` |  | ✅ | ❌ | `0x5ecd4` |
| `MusicData` | `+` | `dataWithPath:ID:` |  | ✅ | ❌ | `0x5ee64` |
| `MusicData` | `-` | `dealloc` |  | ✅ | ✅ | `0x60044` |
| `MusicData` | `-` | `getZipData:` |  | ✅ | ❌ | `0x600cc` |
| `MusicData` | `-` | `getOptionalZipData:` |  | ✅ | ❌ | `0x60190` |
| `MusicData` | `-` | `getOptionalZipData:withDefaultName:` |  | ✅ | ❌ | `0x601b8` |
| `MusicData` | `-` | `music` | prop | ✅ | ✅ | `0x602d8` |
| `MusicData` | `-` | `musicBasic` | prop | ✅ | ❌ | `0x602ec` |
| `MusicData` | `-` | `musicMedium` | prop | ✅ | ❌ | `0x60308` |
| `MusicData` | `-` | `musicHard` | prop | ✅ | ❌ | `0x60324` |
| `MusicData` | `-` | `musicPre` | prop | ✅ | ✅ | `0x60340` |
| `MusicData` | `-` | `sheetBasic` | prop | ✅ | ✅ | `0x60354` |
| `MusicData` | `-` | `sheetBasicLight` | prop | ✅ | ❌ | `0x60368` |
| `MusicData` | `-` | `sheetMedium` | prop | ✅ | ✅ | `0x60384` |
| `MusicData` | `-` | `sheetMediumLight` | prop | ✅ | ❌ | `0x60398` |
| `MusicData` | `-` | `sheetHard` | prop | ✅ | ✅ | `0x603b4` |
| `MusicData` | `-` | `sheetHardLight` | prop | ✅ | ❌ | `0x603c8` |
| `MusicData` | `-` | `sheetSpecial` |  | ✅ | ❌ | `0x603e4` |
| `MusicData` | `-` | `sheetSpecialLight` |  | ✅ | ❌ | `0x60484` |
| `MusicData` | `-` | `artworkData` | prop | ✅ | ✅ | `0x60524` |
| `MusicData` | `-` | `artworkDataBasic` | prop | ✅ | ✅ | `0x60538` |
| `MusicData` | `-` | `artworkDataMedium` | prop | ✅ | ✅ | `0x6054c` |
| `MusicData` | `-` | `artworkDataHard` | prop | ✅ | ✅ | `0x60560` |
| `MusicData` | `-` | `musicNameImageWhiteData` | prop | ✅ | ✅ | `0x60574` |
| `MusicData` | `-` | `musicNameImageWhiteDataBasic` | prop | ✅ | ✅ | `0x60588` |
| `MusicData` | `-` | `musicNameImageWhiteDataMedium` | prop | ✅ | ✅ | `0x6059c` |
| `MusicData` | `-` | `musicNameImageWhiteDataHard` | prop | ✅ | ✅ | `0x605b0` |
| `MusicData` | `-` | `artistNameImageWhiteData` | prop | ✅ | ✅ | `0x605c4` |
| `MusicData` | `-` | `artistNameImageWhiteDataBasic` | prop | ✅ | ✅ | `0x605d8` |
| `MusicData` | `-` | `artistNameImageWhiteDataMedium` | prop | ✅ | ✅ | `0x605ec` |
| `MusicData` | `-` | `artistNameImageWhiteDataHard` | prop | ✅ | ✅ | `0x60600` |
| `MusicData` | `-` | `musicNameImageBlackData` | prop | ✅ | ✅ | `0x60614` |
| `MusicData` | `-` | `musicNameImageBlackDataBasic` | prop | ✅ | ✅ | `0x60628` |
| `MusicData` | `-` | `musicNameImageBlackDataMedium` | prop | ✅ | ✅ | `0x6063c` |
| `MusicData` | `-` | `musicNameImageBlackDataHard` | prop | ✅ | ✅ | `0x60650` |
| `MusicData` | `-` | `artistNameImageBlackData` | prop | ✅ | ✅ | `0x60664` |
| `MusicData` | `-` | `artistNameImageBlackDataBasic` | prop | ✅ | ✅ | `0x60678` |
| `MusicData` | `-` | `artistNameImageBlackDataMedium` | prop | ✅ | ✅ | `0x6068c` |
| `MusicData` | `-` | `artistNameImageBlackDataHard` | prop | ✅ | ✅ | `0x606a0` |
| `MusicData` | `-` | `artwork2xData` | prop | ✅ | ✅ | `0x606b4` |
| `MusicData` | `-` | `artwork2xDataBasic` | prop | ✅ | ✅ | `0x606c8` |
| `MusicData` | `-` | `artwork2xDataMedium` | prop | ✅ | ✅ | `0x606dc` |
| `MusicData` | `-` | `artwork2xDataHard` | prop | ✅ | ✅ | `0x606f0` |
| `MusicData` | `-` | `musicNameImageWhite2xData` | prop | ✅ | ✅ | `0x60704` |
| `MusicData` | `-` | `musicNameImageWhite2xDataBasic` | prop | ✅ | ✅ | `0x60718` |
| `MusicData` | `-` | `musicNameImageWhite2xDataMedium` | prop | ✅ | ✅ | `0x6072c` |
| `MusicData` | `-` | `musicNameImageWhite2xDataHard` | prop | ✅ | ✅ | `0x60740` |
| `MusicData` | `-` | `artistNameImageWhite2xData` | prop | ✅ | ✅ | `0x60754` |
| `MusicData` | `-` | `artistNameImageWhite2xDataBasic` | prop | ✅ | ✅ | `0x60768` |
| `MusicData` | `-` | `artistNameImageWhite2xDataMedium` | prop | ✅ | ✅ | `0x6077c` |
| `MusicData` | `-` | `artistNameImageWhite2xDataHard` | prop | ✅ | ✅ | `0x60790` |
| `MusicData` | `-` | `musicNameImageBlack2xData` | prop | ✅ | ✅ | `0x607a4` |
| `MusicData` | `-` | `musicNameImageBlack2xDataBasic` | prop | ✅ | ✅ | `0x607b8` |
| `MusicData` | `-` | `musicNameImageBlack2xDataMedium` | prop | ✅ | ✅ | `0x607cc` |
| `MusicData` | `-` | `musicNameImageBlack2xDataHard` | prop | ✅ | ✅ | `0x607e0` |
| `MusicData` | `-` | `artistNameImageBlack2xData` | prop | ✅ | ✅ | `0x607f4` |
| `MusicData` | `-` | `artistNameImageBlack2xDataBasic` | prop | ✅ | ✅ | `0x60808` |
| `MusicData` | `-` | `artistNameImageBlack2xDataMedium` | prop | ✅ | ✅ | `0x6081c` |
| `MusicData` | `-` | `artistNameImageBlack2xDataHard` | prop | ✅ | ✅ | `0x60830` |
| `MusicData` | `-` | `musicNameImageBrown2xData` |  | ✅ | ❌ | `0x60844` |
| `MusicData` | `-` | `musicNameImageBrown2xDataBasic` |  | ✅ | ❌ | `0x60988` |
| `MusicData` | `-` | `musicNameImageBrown2xDataMedium` |  | ✅ | ❌ | `0x60ad8` |
| `MusicData` | `-` | `musicNameImageBrown2xDataHard` |  | ✅ | ❌ | `0x60c28` |
| `MusicData` | `-` | `artistNameImageBrown2xData` |  | ✅ | ❌ | `0x60d78` |
| `MusicData` | `-` | `artistNameImageBrown2xDataBasic` |  | ✅ | ❌ | `0x60ebc` |
| `MusicData` | `-` | `artistNameImageBrown2xDataMedium` |  | ✅ | ❌ | `0x6100c` |
| `MusicData` | `-` | `artistNameImageBrown2xDataHard` |  | ✅ | ❌ | `0x6115c` |
| `MusicData` | `-` | `artwork` | prop | ✅ | ❌ | `0x612ac` |
| `MusicData` | `-` | `artworkBasic` | prop | ✅ | ❌ | `0x61498` |
| `MusicData` | `-` | `artworkMedium` | prop | ✅ | ❌ | `0x61684` |
| `MusicData` | `-` | `artworkHard` | prop | ✅ | ❌ | `0x6188c` |
| `MusicData` | `-` | `musicNameImageWhite` | prop | ✅ | ❌ | `0x61a94` |
| `MusicData` | `-` | `musicNameImageWhiteBasic` | prop | ✅ | ❌ | `0x61ba4` |
| `MusicData` | `-` | `musicNameImageWhiteMedium` | prop | ✅ | ❌ | `0x61cb4` |
| `MusicData` | `-` | `musicNameImageWhiteHard` | prop | ✅ | ❌ | `0x61dc4` |
| `MusicData` | `-` | `artistNameImageWhite` | prop | ✅ | ❌ | `0x61ed4` |
| `MusicData` | `-` | `artistNameImageWhiteBasic` | prop | ✅ | ❌ | `0x61fe4` |
| `MusicData` | `-` | `artistNameImageWhiteMedium` | prop | ✅ | ❌ | `0x620f4` |
| `MusicData` | `-` | `artistNameImageWhiteHard` | prop | ✅ | ❌ | `0x62204` |
| `MusicData` | `-` | `musicNameImageBlack` | prop | ✅ | ❌ | `0x62314` |
| `MusicData` | `-` | `musicNameImageBlackBasic` | prop | ✅ | ❌ | `0x624a0` |
| `MusicData` | `-` | `musicNameImageBlackMedium` | prop | ✅ | ❌ | `0x62638` |
| `MusicData` | `-` | `musicNameImageBlackHard` | prop | ✅ | ❌ | `0x627d0` |
| `MusicData` | `-` | `artistNameImageBlack` | prop | ✅ | ❌ | `0x62968` |
| `MusicData` | `-` | `artistNameImageBlackBasic` | prop | ✅ | ❌ | `0x62af4` |
| `MusicData` | `-` | `artistNameImageBlackMedium` | prop | ✅ | ❌ | `0x62c8c` |
| `MusicData` | `-` | `artistNameImageBlackHard` | prop | ✅ | ❌ | `0x62e24` |
| `MusicData` | `-` | `musicNameImageBrown` | prop | ✅ | ❌ | `0x62fbc` |
| `MusicData` | `-` | `musicNameImageBrownBasic` | prop | ✅ | ❌ | `0x63154` |
| `MusicData` | `-` | `musicNameImageBrownMedium` | prop | ✅ | ❌ | `0x632f8` |
| `MusicData` | `-` | `musicNameImageBrownHard` | prop | ✅ | ❌ | `0x6349c` |
| `MusicData` | `-` | `artistNameImageBrown` | prop | ✅ | ❌ | `0x63640` |
| `MusicData` | `-` | `artistNameImageBrownBasic` | prop | ✅ | ❌ | `0x637d8` |
| `MusicData` | `-` | `artistNameImageBrownMedium` | prop | ✅ | ❌ | `0x6397c` |
| `MusicData` | `-` | `artistNameImageBrownHard` | prop | ✅ | ❌ | `0x63b20` |
| `MusicData` | `-` | `artwork2x` | prop | ✅ | ❌ | `0x63cc4` |
| `MusicData` | `-` | `artwork2xBasic` | prop | ✅ | ❌ | `0x63dbc` |
| `MusicData` | `-` | `artwork2xMedium` | prop | ✅ | ❌ | `0x63eb4` |
| `MusicData` | `-` | `artwork2xHard` | prop | ✅ | ❌ | `0x63fac` |
| `MusicData` | `-` | `musicNameImageWhite2x` | prop | ✅ | ❌ | `0x640a4` |
| `MusicData` | `-` | `musicNameImageWhite2xBasic` | prop | ✅ | ❌ | `0x6419c` |
| `MusicData` | `-` | `musicNameImageWhite2xMedium` | prop | ✅ | ❌ | `0x64294` |
| `MusicData` | `-` | `musicNameImageWhite2xHard` | prop | ✅ | ❌ | `0x6438c` |
| `MusicData` | `-` | `artistNameImageWhite2x` | prop | ✅ | ❌ | `0x64484` |
| `MusicData` | `-` | `artistNameImageWhite2xBasic` | prop | ✅ | ❌ | `0x6457c` |
| `MusicData` | `-` | `artistNameImageWhite2xMedium` | prop | ✅ | ❌ | `0x64674` |
| `MusicData` | `-` | `artistNameImageWhite2xHard` | prop | ✅ | ❌ | `0x6476c` |
| `MusicData` | `-` | `musicNameImageBlack2x` | prop | ✅ | ❌ | `0x64864` |
| `MusicData` | `-` | `musicNameImageBlack2xBasic` | prop | ✅ | ❌ | `0x6495c` |
| `MusicData` | `-` | `musicNameImageBlack2xMedium` | prop | ✅ | ❌ | `0x64a54` |
| `MusicData` | `-` | `musicNameImageBlack2xHard` | prop | ✅ | ❌ | `0x64b4c` |
| `MusicData` | `-` | `artistNameImageBlack2x` | prop | ✅ | ❌ | `0x64c44` |
| `MusicData` | `-` | `artistNameImageBlack2xBasic` | prop | ✅ | ❌ | `0x64d3c` |
| `MusicData` | `-` | `artistNameImageBlack2xMedium` | prop | ✅ | ❌ | `0x64e34` |
| `MusicData` | `-` | `artistNameImageBlack2xHard` | prop | ✅ | ❌ | `0x64f2c` |
| `MusicData` | `-` | `musicNameImageBrown2x` | prop | ✅ | ❌ | `0x65024` |
| `MusicData` | `-` | `musicNameImageBrown2xBasic` | prop | ✅ | ❌ | `0x6511c` |
| `MusicData` | `-` | `musicNameImageBrown2xMedium` | prop | ✅ | ❌ | `0x65214` |
| `MusicData` | `-` | `musicNameImageBrown2xHard` | prop | ✅ | ❌ | `0x6530c` |
| `MusicData` | `-` | `artistNameImageBrown2x` | prop | ✅ | ❌ | `0x65404` |
| `MusicData` | `-` | `artistNameImageBrown2xBasic` | prop | ✅ | ❌ | `0x654fc` |
| `MusicData` | `-` | `artistNameImageBrown2xMedium` | prop | ✅ | ❌ | `0x655f4` |
| `MusicData` | `-` | `artistNameImageBrown2xHard` | prop | ✅ | ❌ | `0x656ec` |
| `MusicData` | `-` | `setColor:withColor:` |  | ✅ | ❌ | `0x657e4` |
| `MusicData` | `-` | `createCache` |  | ✅ | ❌ | `0x65964` |
| `MusicData` | `-` | `releaseChache` |  | ✅ | ✅ | `0x65b3c` |
| `MusicData` | `-` | `compare:` |  | ✅ | ❌ | `0x65b4c` |
| `MusicData` | `-` | `compareMusicID:` |  | ✅ | ✅ | `0x65c5c` |
| `MusicData` | `-` | `compareMusicNameCustom:` |  | ✅ | ❌ | `0x65ce0` |
| `MusicData` | `-` | `compareArtistNameCustom:` |  | ✅ | ❌ | `0x65df4` |
| `MusicData` | `-` | `compareMusicNameHira:` |  | ✅ | ❌ | `0x65eec` |
| `MusicData` | `-` | `compareArtistNameHira:` |  | ✅ | ❌ | `0x66000` |
| `MusicData` | `-` | `compareDifficultyBasic:` |  | ✅ | ✅ | `0x660f8` |
| `MusicData` | `-` | `compareDifficultyMedium:` |  | ✅ | ✅ | `0x6617c` |
| `MusicData` | `-` | `compareDifficultyHard:` |  | ✅ | ✅ | `0x66200` |
| `MusicData` | `-` | `compareDifficultySpecial:` |  | ✅ | ✅ | `0x66284` |
| `MusicData` | `-` | `isArtworkCache` | prop | ✅ | ✅ | `0x66308` |
| `MusicData` | `-` | `MusicID` | prop | ✅ | ✅ | `0x66344` |
| `MusicData` | `-` | `setMusicID:` | prop | ✅ | ✅ | `0x66354` |
| `MusicData` | `-` | `difficultyBasic` | prop | ✅ | ✅ | `0x66364` |
| `MusicData` | `-` | `setDifficultyBasic:` | prop | ✅ | ✅ | `0x66374` |
| `MusicData` | `-` | `difficultyMedium` | prop | ✅ | ✅ | `0x66384` |
| `MusicData` | `-` | `setDifficultyMedium:` | prop | ✅ | ✅ | `0x66394` |
| `MusicData` | `-` | `difficultyHard` | prop | ✅ | ✅ | `0x663a4` |
| `MusicData` | `-` | `setDifficultyHard:` | prop | ✅ | ✅ | `0x663b4` |
| `MusicData` | `-` | `difficultySpecial` | prop | ✅ | ✅ | `0x663c4` |
| `MusicData` | `-` | `setDifficultySpecial:` | prop | ✅ | ✅ | `0x663d4` |
| `MusicData` | `-` | `bpm_MIN` | prop | ✅ | ✅ | `0x663e4` |
| `MusicData` | `-` | `setBpm_MIN:` | prop | ✅ | ✅ | `0x663f4` |
| `MusicData` | `-` | `bpm_MAX` | prop | ✅ | ✅ | `0x66404` |
| `MusicData` | `-` | `setBpm_MAX:` | prop | ✅ | ✅ | `0x66414` |
| `MusicData` | `-` | `musicName` | prop | ✅ | ✅ | `0x66424` |
| `MusicData` | `-` | `setMusicName:` | prop | ✅ | ✅ | `0x66434` |
| `MusicData` | `-` | `musicNameHira` | prop | ✅ | ✅ | `0x6646c` |
| `MusicData` | `-` | `setMusicNameHira:` | prop | ✅ | ✅ | `0x6647c` |
| `MusicData` | `-` | `musicNameRoman` | prop | ✅ | ✅ | `0x664b4` |
| `MusicData` | `-` | `setMusicNameRoman:` | prop | ✅ | ✅ | `0x664c4` |
| `MusicData` | `-` | `artistName` | prop | ✅ | ✅ | `0x664fc` |
| `MusicData` | `-` | `setArtistName:` | prop | ✅ | ✅ | `0x6650c` |
| `MusicData` | `-` | `artistNameHira` | prop | ✅ | ✅ | `0x66544` |
| `MusicData` | `-` | `setArtistNameHira:` | prop | ✅ | ✅ | `0x66554` |
| `MusicData` | `-` | `artistNameRoman` | prop | ✅ | ✅ | `0x6658c` |
| `MusicData` | `-` | `setArtistNameRoman:` | prop | ✅ | ✅ | `0x6659c` |
| `MusicData` | `-` | `musicSortName` | prop | ✅ | ✅ | `0x665d4` |
| `MusicData` | `-` | `setMusicSortName:` | prop | ✅ | ✅ | `0x665e4` |
| `MusicData` | `-` | `artistSortName` | prop | ✅ | ✅ | `0x6661c` |
| `MusicData` | `-` | `setArtistSortName:` | prop | ✅ | ✅ | `0x6662c` |
| `MusicData` | `-` | `musicNameInitial` | prop | ✅ | ✅ | `0x66664` |
| `MusicData` | `-` | `setMusicNameInitial:` | prop | ✅ | ✅ | `0x66674` |
| `MusicData` | `-` | `artistNameInitial` | prop | ✅ | ✅ | `0x666ac` |
| `MusicData` | `-` | `setArtistNameInitial:` | prop | ✅ | ✅ | `0x666bc` |
| `MusicData` | `-` | `optionalDataDict` | prop | ✅ | ✅ | `0x666f4` |
| `MusicData` | `-` | `setOptionalDataDict:` | prop | ✅ | ✅ | `0x66704` |
| `MusicData` | `-` | `spData` | prop | ✅ | ✅ | `0x6673c` |
| `MusicData` | `-` | `setSpData:` | prop | ✅ | ✅ | `0x6674c` |
| `MusicData` | `-` | `ExtMusicData` | prop | ✅ | ✅ | `0x6675c` |
| `MusicData` | `-` | `setExtMusicData:` | prop | ✅ | ✅ | `0x6676c` |
| `MusicData` | `-` | `artworkCache` | prop | ✅ | ✅ | `0x667a4` |
| `MusicData` | `-` | `setArtworkCache:` | prop | ✅ | ✅ | `0x667b4` |
| `MusicData` | `-` | `artworkCacheBasic` | prop | ✅ | ✅ | `0x667c0` |
| `MusicData` | `-` | `setArtworkCacheBasic:` | prop | ✅ | ✅ | `0x667d0` |
| `MusicData` | `-` | `artworkCacheMedium` | prop | ✅ | ✅ | `0x667dc` |
| `MusicData` | `-` | `setArtworkCacheMedium:` | prop | ✅ | ✅ | `0x667ec` |
| `MusicData` | `-` | `artworkCacheHard` | prop | ✅ | ✅ | `0x667f8` |
| `MusicData` | `-` | `setArtworkCacheHard:` | prop | ✅ | ✅ | `0x66808` |
| `MusicData` | `-` | `filePath` | prop | ✅ | ✅ | `0x66814` |
| `MusicData` | `-` | `setFilePath:` | prop | ✅ | ✅ | `0x66824` |
| `MusicData` | `-` | `decodeType` | prop | ✅ | ✅ | `0x6685c` |
| `MusicData` | `-` | `setDecodeType:` | prop | ✅ | ✅ | `0x6686c` |
| `MusicDataFromDoc` | `-` | `init` |  | ✅ | ❌ | `0x67238` |
| `MusicDataFromDoc` | `+` | `getPathWithDocument:` |  | ✅ | ❌ | `0x6726c` |
| `MusicDataFromDoc` | `+` | `dataWithPath:PlyName:` |  | ✅ | ❌ | `0x6734c` |
| `MusicDataFromDoc` | `-` | `dealloc` |  | ❌ | ✅ | `0x67498` |
| `MusicDataFromDoc` | `-` | `MusicID` |  | ✅ | ✅ | `0x674cc` |
| `MusicDataFromDoc` | `-` | `difficultyBasic` |  | ✅ | ✅ | `0x674d4` |
| `MusicDataFromDoc` | `-` | `difficultyMedium` |  | ✅ | ✅ | `0x674dc` |
| `MusicDataFromDoc` | `-` | `difficultyHard` |  | ✅ | ✅ | `0x674e4` |
| `MusicDataFromDoc` | `-` | `difficultySpecial` |  | ✅ | ✅ | `0x674ec` |
| `MusicDataFromDoc` | `-` | `bpm_MIN` |  | ✅ | ✅ | `0x674f4` |
| `MusicDataFromDoc` | `-` | `bpm_MAX` |  | ✅ | ✅ | `0x674fc` |
| `MusicDataFromDoc` | `-` | `musicNameHira` |  | ✅ | ✅ | `0x67504` |
| `MusicDataFromDoc` | `-` | `musicNameRoman` |  | ✅ | ✅ | `0x6750c` |
| `MusicDataFromDoc` | `-` | `artistName` |  | ✅ | ✅ | `0x67514` |
| `MusicDataFromDoc` | `-` | `artistNameHira` |  | ✅ | ✅ | `0x6751c` |
| `MusicDataFromDoc` | `-` | `artistNameRoman` |  | ✅ | ✅ | `0x67524` |
| `MusicDataFromDoc` | `-` | `music` |  | ✅ | ❌ | `0x6752c` |
| `MusicDataFromDoc` | `-` | `musicPre` |  | ✅ | ✅ | `0x675e4` |
| `MusicDataFromDoc` | `-` | `loadSheet` |  | ✅ | ❌ | `0x675ec` |
| `MusicDataFromDoc` | `-` | `sheetBasic` |  | ✅ | ✅ | `0x676a4` |
| `MusicDataFromDoc` | `-` | `sheetBasicLight` |  | ✅ | ✅ | `0x676b0` |
| `MusicDataFromDoc` | `-` | `sheetMedium` |  | ✅ | ✅ | `0x676bc` |
| `MusicDataFromDoc` | `-` | `sheetMediumLight` |  | ✅ | ✅ | `0x676c8` |
| `MusicDataFromDoc` | `-` | `sheetHard` |  | ✅ | ✅ | `0x676d4` |
| `MusicDataFromDoc` | `-` | `sheetHardLight` |  | ✅ | ✅ | `0x676e0` |
| `MusicDataFromDoc` | `-` | `sheetSpecial` |  | ✅ | ✅ | `0x676ec` |
| `MusicDataFromDoc` | `-` | `sheetSpecialLight` |  | ✅ | ✅ | `0x676f8` |
| `MusicDataFromDoc` | `-` | `artwork2xData` |  | ✅ | ✅ | `0x67704` |
| `MusicDataFromDoc` | `-` | `artworkData` |  | ✅ | ✅ | `0x67718` |
| `MusicDataFromDoc` | `-` | `artworkDataWithScale:Luminance:` |  | ✅ | ❌ | `0x6772c` |
| `MusicDataFromDoc` | `-` | `musicNameImageWhite2xData` |  | ✅ | ❌ | `0x67944` |
| `MusicDataFromDoc` | `-` | `musicNameImageWhiteData` |  | ✅ | ❌ | `0x67958` |
| `MusicDataFromDoc` | `-` | `musicNameImageBlack2xData` |  | ✅ | ❌ | `0x6796c` |
| `MusicDataFromDoc` | `-` | `musicNameImageBlackData` |  | ✅ | ❌ | `0x67980` |
| `MusicDataFromDoc` | `-` | `musicNameImageDataWithScale:Luminance:` |  | ✅ | ❌ | `0x67994` |
| `MusicDataFromDoc` | `-` | `artistNameImageWhite2xData` |  | ✅ | ❌ | `0x67c0c` |
| `MusicDataFromDoc` | `-` | `artistNameImageWhiteData` |  | ✅ | ❌ | `0x67c20` |
| `MusicDataFromDoc` | `-` | `artistNameImageBlack2xData` |  | ✅ | ❌ | `0x67c34` |
| `MusicDataFromDoc` | `-` | `artistNameImageBlackData` |  | ✅ | ❌ | `0x67c48` |
| `MusicDataFromDoc` | `-` | `artistNameImageDataWithScale:Luminance:` |  | ✅ | ❌ | `0x67c5c` |
| `MusicDataFromDoc` | `-` | `plyName` | prop | ✅ | ✅ | `0x67e28` |
| `MusicDataFromDoc` | `-` | `setPlyName:` | prop | ✅ | ✅ | `0x67e38` |
| `StoreMusicInfo` | `-` | `initWithDictionary:` |  | ✅ | ❌ | `0x67e84` |
| `StoreMusicInfo` | `-` | `fileExist` |  | ✅ | ❌ | `0x683f0` |
| `StoreMusicInfo` | `-` | `dealloc` |  | ❌ | ✅ | `0x684d4` |
| `StoreMusicInfo` | `-` | `musicID` | prop | ✅ | ✅ | `0x68508` |
| `StoreMusicInfo` | `-` | `setMusicID:` | prop | ✅ | ✅ | `0x68518` |
| `StoreMusicInfo` | `-` | `name` | prop | ✅ | ✅ | `0x68528` |
| `StoreMusicInfo` | `-` | `setName:` | prop | ✅ | ✅ | `0x68538` |
| `StoreMusicInfo` | `-` | `artist` | prop | ✅ | ✅ | `0x68570` |
| `StoreMusicInfo` | `-` | `setArtist:` | prop | ✅ | ✅ | `0x68580` |
| `StoreMusicInfo` | `-` | `itemURL` | prop | ✅ | ✅ | `0x685b8` |
| `StoreMusicInfo` | `-` | `setItemURL:` | prop | ✅ | ✅ | `0x685c8` |
| `StoreMusicInfo` | `-` | `artworkURL` | prop | ✅ | ✅ | `0x68600` |
| `StoreMusicInfo` | `-` | `setArtworkURL:` | prop | ✅ | ✅ | `0x68610` |
| `StoreMusicInfo` | `-` | `sampleURL` | prop | ✅ | ✅ | `0x68648` |
| `StoreMusicInfo` | `-` | `setSampleURL:` | prop | ✅ | ✅ | `0x68658` |
| `StoreMusicInfo` | `-` | `itunesURL` | prop | ✅ | ✅ | `0x68690` |
| `StoreMusicInfo` | `-` | `setItunesURL:` | prop | ✅ | ✅ | `0x686a0` |
| `StoreMusicInfo` | `-` | `lvBasic` | prop | ✅ | ✅ | `0x686d8` |
| `StoreMusicInfo` | `-` | `setLvBasic:` | prop | ✅ | ✅ | `0x686e8` |
| `StoreMusicInfo` | `-` | `lvMedium` | prop | ✅ | ✅ | `0x686f8` |
| `StoreMusicInfo` | `-` | `setLvMedium:` | prop | ✅ | ✅ | `0x68708` |
| `StoreMusicInfo` | `-` | `lvHard` | prop | ✅ | ✅ | `0x68718` |
| `StoreMusicInfo` | `-` | `setLvHard:` | prop | ✅ | ✅ | `0x68728` |
| `StoreMusicInfo` | `-` | `extIDList` | prop | ✅ | ✅ | `0x68738` |
| `StoreMusicInfo` | `-` | `setExtIDList:` | prop | ✅ | ✅ | `0x68748` |
| `StorePackInfo` | `-` | `initWithProduct:` |  | ✅ | ❌ | `0x68824` |
| `StorePackInfo` | `-` | `initWithPackID:` |  | ✅ | ❌ | `0x68924` |
| `StorePackInfo` | `-` | `initWithDictionary:` |  | ✅ | ❌ | `0x68984` |
| `StorePackInfo` | `-` | `setDictionary:` |  | ✅ | ❌ | `0x68a54` |
| `StorePackInfo` | `-` | `priceString` |  | ✅ | ❌ | `0x68e30` |
| `StorePackInfo` | `-` | `setMusicInfo:` |  | ✅ | ❌ | `0x68e94` |
| `StorePackInfo` | `-` | `downloadDetailInfo` |  | ✅ | ❌ | `0x69114` |
| `StorePackInfo` | `-` | `allDownloaded` |  | ✅ | ❌ | `0x69150` |
| `StorePackInfo` | `-` | `packID` | prop | ✅ | ✅ | `0x69278` |
| `StorePackInfo` | `-` | `setPackID:` | prop | ✅ | ✅ | `0x69288` |
| `StorePackInfo` | `-` | `isNew` | prop | ✅ | ✅ | `0x69298` |
| `StorePackInfo` | `-` | `setIsNew:` | prop | ✅ | ✅ | `0x692a8` |
| `StorePackInfo` | `-` | `artworkURL` | prop | ✅ | ✅ | `0x692b8` |
| `StorePackInfo` | `-` | `setArtworkURL:` | prop | ✅ | ✅ | `0x692c8` |
| `StorePackInfo` | `-` | `packName` | prop | ✅ | ✅ | `0x69300` |
| `StorePackInfo` | `-` | `setPackName:` | prop | ✅ | ✅ | `0x69310` |
| `StorePackInfo` | `-` | `comment` | prop | ✅ | ✅ | `0x69348` |
| `StorePackInfo` | `-` | `setComment:` | prop | ✅ | ✅ | `0x69358` |
| `StorePackInfo` | `-` | `s_comment` | prop | ✅ | ✅ | `0x69390` |
| `StorePackInfo` | `-` | `setS_comment:` | prop | ✅ | ✅ | `0x693a0` |
| `StorePackInfo` | `-` | `copyright` | prop | ✅ | ✅ | `0x693d8` |
| `StorePackInfo` | `-` | `setCopyright:` | prop | ✅ | ✅ | `0x693e8` |
| `StorePackInfo` | `-` | `extCount` | prop | ✅ | ✅ | `0x69420` |
| `StorePackInfo` | `-` | `setExtCount:` | prop | ✅ | ✅ | `0x69430` |
| `StorePackInfo` | `-` | `musicInfos` | prop | ✅ | ✅ | `0x69440` |
| `StorePackInfo` | `-` | `setMusicInfos:` | prop | ✅ | ✅ | `0x69450` |
| `StorePackInfo` | `-` | `artistURL` | prop | ✅ | ✅ | `0x69488` |
| `StorePackInfo` | `-` | `setArtistURL:` | prop | ✅ | ✅ | `0x69498` |
| `StorePackInfo` | `-` | `bunnerURL` | prop | ✅ | ✅ | `0x694d0` |
| `StorePackInfo` | `-` | `setBunnerURL:` | prop | ✅ | ✅ | `0x694e0` |
| `StorePackInfo` | `-` | `product` | prop | ✅ | ✅ | `0x69518` |
| `StorePackInfo` | `-` | `setProduct:` | prop | ✅ | ✅ | `0x69528` |
| `StorePackInfo` | `-` | `ErrorMessage` | prop | ✅ | ✅ | `0x69560` |
| `StorePackInfo` | `-` | `setErrorMessage:` | prop | ✅ | ✅ | `0x69570` |
| `StorePackInfoDownloader` | `-` | `initWithStorePackInfo:` |  | ✅ | ❌ | `0x69688` |
| `StorePackInfoDownloader` | `-` | `dealloc` |  | ✅ | ❌ | `0x69700` |
| `StorePackInfoDownloader` | `-` | `downloadDetail:` |  | ✅ | ❌ | `0x6977c` |
| `StorePackInfoDownloader` | `-` | `cancel` |  | ✅ | ❌ | `0x69880` |
| `StorePackInfoDownloader` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x69914` |
| `StorePackInfoDownloader` | `-` | `downloaderProceed:` |  | ✅ | ❌ | `0x69acc` |
| `StorePackInfoDownloader` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x69bc0` |
| `StorePackInfoDownloader` | `-` | `getPackInfo` |  | ✅ | ✅ | `0x69cc8` |
| `StorePackInfoDownloader` | `-` | `getErrorMessage` |  | ✅ | ✅ | `0x69cd4` |
| `StorePackInfoDownloader` | `-` | `delegate` | prop | ✅ | ✅ | `0x69ce0` |
| `StorePackInfoDownloader` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x69d00` |
| `StorePackInfoDownloader` | `-` | `packInfo` | prop | ✅ | ✅ | `0x69d14` |
| `StorePackInfoDownloader` | `-` | `setPackInfo:` | prop | ✅ | ✅ | `0x69d24` |
| `StorePackInfoDownloader` | `-` | `downloader` | prop | ✅ | ✅ | `0x69d5c` |
| `StorePackInfoDownloader` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x69d6c` |
| `StorePackInfoDownloader` | `-` | `errorMessage` | prop | ✅ | ✅ | `0x69da4` |
| `StorePackInfoDownloader` | `-` | `setErrorMessage:` | prop | ✅ | ✅ | `0x69db4` |
| `RBBGMManager` | `+` | `getInstance` |  | ✅ | ❌ | `0x69e50` |
| `RBBGMManager` | `-` | `init` |  | ✅ | ❌ | `0x69ea8` |
| `RBBGMManager` | `-` | `RelaseMusic` |  | ✅ | ❌ | `0x69ef8` |
| `RBBGMManager` | `-` | `PlayMusic:` |  | ✅ | ❌ | `0x69fac` |
| `RBBGMManager` | `-` | `PauseMusic:` |  | ✅ | ❌ | `0x6a03c` |
| `RBBGMManager` | `-` | `StopMusic:` |  | ✅ | ❌ | `0x6a0c8` |
| `RBBGMManager` | `-` | `SeekToTop` |  | ✅ | ❌ | `0x6a154` |
| `RBBGMManager` | `-` | `LoadMusicType:Loop:` |  | ✅ | ❌ | `0x6a1cc` |
| `RBBGMManager` | `-` | `LoadMusicSelect` |  | ✅ | ❌ | `0x6a324` |
| `RBBGMManager` | `-` | `LoadMusicTitleWithLoop:` |  | ✅ | ❌ | `0x6a3b4` |
| `RBBGMManager` | `-` | `LoadMusicResultWithLoop:` |  | ✅ | ❌ | `0x6a560` |
| `RBBGMManager` | `-` | `LoadMusic:Loop:` |  | ✅ | ❌ | `0x6a70c` |
| `RBBGMManager` | `-` | `LoadMusicWithPush:Loop:` |  | ✅ | ❌ | `0x6a7b4` |
| `RBBGMManager` | `-` | `pushMusic` |  | ✅ | ❌ | `0x6a854` |
| `RBBGMManager` | `-` | `popMusic` |  | ✅ | ❌ | `0x6a8f0` |
| `RBBGMManager` | `-` | `isPushMusic` |  | ✅ | ❌ | `0x6a980` |
| `RBMusicManager` | `+` | `getInstance` |  | ✅ | ❌ | `0x6a990` |
| `RBMusicManager` | `+` | `getMusicDataFilename:` |  | ✅ | ❌ | `0x6a9e8` |
| `RBMusicManager` | `+` | `getPathFromBundle:` |  | ✅ | ❌ | `0x6aa1c` |
| `RBMusicManager` | `+` | `getPathFromPurchesed:` |  | ✅ | ❌ | `0x6aad8` |
| `RBMusicManager` | `+` | `getPathFromPurchesedOldDirectory:` |  | ✅ | ❌ | `0x6ab88` |
| `RBMusicManager` | `-` | `deleteMusic:` |  | ✅ | ❌ | `0x6ac38` |
| `RBMusicManager` | `-` | `init` |  | ✅ | ❌ | `0x6ae38` |
| `RBMusicManager` | `-` | `dealloc` |  | ❌ | ✅ | `0x6aeac` |
| `RBMusicManager` | `-` | `createPreInMusics` |  | ✅ | ❌ | `0x6aee0` |
| `RBMusicManager` | `-` | `loadPurchasedMusics` |  | ✅ | ❌ | `0x6b020` |
| `RBMusicManager` | `-` | `savePurchasedMusics` |  | ✅ | ❌ | `0x6b39c` |
| `RBMusicManager` | `-` | `getPurchasedMusicDictionary:` |  | ✅ | ❌ | `0x6b610` |
| `RBMusicManager` | `-` | `getPurchasedMusicDictionaris` |  | ✅ | ✅ | `0x6b7c4` |
| `RBMusicManager` | `-` | `addPurchasedMusic:` |  | ✅ | ❌ | `0x6b7d0` |
| `RBMusicManager` | `-` | `createMusicDataArray` |  | ✅ | ❌ | `0x6c18c` |
| `RBMusicManager` | `-` | `setMusicDataArrayDirty` |  | ✅ | ✅ | `0x6c6a8` |
| `RBMusicManager` | `-` | `getMusicDataArray` |  | ✅ | ❌ | `0x6c6b8` |
| `RBMusicManager` | `-` | `getMusicData:` |  | ✅ | ❌ | `0x6c754` |
| `RBMusicManager` | `-` | `releaseChacheMusicData` |  | ✅ | ❌ | `0x6c8b4` |
| `RBMusicManager` | `-` | `getMusicIDs` |  | ✅ | ❌ | `0x6c9e4` |
| `RBMusicManager` | `-` | `releaseClientMusic` |  | ✅ | ✅ | `0x6cc80` |
| `RBMusicManager` | `-` | `setClientMusicPageNum:` | prop | ✅ | ❌ | `0x6cc90` |
| `RBMusicManager` | `-` | `setClientMusic:` |  | ✅ | ❌ | `0x6cd2c` |
| `RBMusicManager` | `-` | `getClientCompareMusics` |  | ✅ | ❌ | `0x6cdf8` |
| `RBMusicManager` | `-` | `clientMusicPageNum` | prop | ✅ | ✅ | `0x6d0a8` |
| `RBMusicManager` | `-` | `clientMusics` | prop | ✅ | ✅ | `0x6d0b8` |
| `RBMusicManager` | `-` | `setClientMusics:` | prop | ✅ | ✅ | `0x6d0c8` |
| `RBMusicManager` | `-` | `preinstallMusicIDs` | prop | ✅ | ✅ | `0x6d100` |
| `RBMusicManager` | `-` | `setPreinstallMusicIDs:` | prop | ✅ | ✅ | `0x6d110` |
| `RBMusicManager` | `-` | `purchasedMusicDictionaries` | prop | ✅ | ✅ | `0x6d148` |
| `RBMusicManager` | `-` | `setPurchasedMusicDictionaries:` | prop | ✅ | ✅ | `0x6d158` |
| `RBMusicManager` | `-` | `musicDataArray` | prop | ✅ | ✅ | `0x6d190` |
| `RBMusicManager` | `-` | `setMusicDataArray:` | prop | ✅ | ✅ | `0x6d1a0` |
| `RBMusicManager` | `-` | `musicDataArrayDirtyFlag` | prop | ✅ | ✅ | `0x6d1d8` |
| `RBMusicManager` | `-` | `setMusicDataArrayDirtyFlag:` | prop | ✅ | ✅ | `0x6d1e8` |
| `RBPurchaseManager` | `+` | `sharedManager` |  | ✅ | ❌ | `0x6d260` |
| `RBPurchaseManager` | `-` | `init` |  | ✅ | ❌ | `0x6d2b8` |
| `RBPurchaseManager` | `+` | `isPurchasable` |  | ✅ | ❌ | `0x6d4d0` |
| `RBPurchaseManager` | `-` | `dealloc` |  | ✅ | ❌ | `0x6d4e4` |
| `RBPurchaseManager` | `-` | `start` |  | ✅ | ❌ | `0x6d5ac` |
| `RBPurchaseManager` | `-` | `end` |  | ✅ | ❌ | `0x6d610` |
| `RBPurchaseManager` | `-` | `saveProductList` |  | ✅ | ❌ | `0x6d674` |
| `RBPurchaseManager` | `-` | `loadProductList` |  | ✅ | ❌ | `0x6d8e8` |
| `RBPurchaseManager` | `-` | `isPurchased:` |  | ✅ | ❌ | `0x6dc30` |
| `RBPurchaseManager` | `-` | `beginPurchase:` |  | ✅ | ❌ | `0x6dcc8` |
| `RBPurchaseManager` | `-` | `beginRestore` |  | ✅ | ❌ | `0x6de88` |
| `RBPurchaseManager` | `-` | `purchaseCheckedProducts` |  | ✅ | ✅ | `0x6e024` |
| `RBPurchaseManager` | `-` | `removePurchaseCheckedProduct:` |  | ✅ | ❌ | `0x6e030` |
| `RBPurchaseManager` | `-` | `clearPurchaseCheckedProducts` |  | ✅ | ❌ | `0x6e0bc` |
| `RBPurchaseManager` | `-` | `addProductID:Save:` |  | ✅ | ❌ | `0x6e110` |
| `RBPurchaseManager` | `-` | `addProductFromPurchaseCheckedProducts` |  | ✅ | ❌ | `0x6e21c` |
| `RBPurchaseManager` | `-` | `addPurchaseCheckTransaction:` |  | ✅ | ❌ | `0x6e370` |
| `RBPurchaseManager` | `-` | `checkNextReceipt` |  | ✅ | ❌ | `0x6e468` |
| `RBPurchaseManager` | `-` | `requestDidFinish:` |  | ✅ | ❌ | `0x6e834` |
| `RBPurchaseManager` | `-` | `request:didFailWithError:` |  | ✅ | ✅ | `0x6e854` |
| `RBPurchaseManager` | `-` | `paymentQueue:updatedTransactions:` |  | ✅ | ❌ | `0x6e858` |
| `RBPurchaseManager` | `-` | `paymentQueue:removedTransactions:` |  | ✅ | ❌ | `0x6ee94` |
| `RBPurchaseManager` | `-` | `paymentQueueRestoreCompletedTransactionsFinished:` |  | ✅ | ❌ | `0x6efb4` |
| `RBPurchaseManager` | `-` | `paymentQueue:restoreCompletedTransactionsFailedWithError:` |  | ✅ | ❌ | `0x6f288` |
| `RBPurchaseManager` | `+` | `encodedStringWithBase64:` |  | ✅ | ❌ | `0x6f3b8` |
| `RBPurchaseManager` | `+` | `encodedStringWithBase64V2:` |  | ✅ | ❌ | `0x6f544` |
| `RBPurchaseManager` | `+` | `decodedStringWithBase64:` |  | ✅ | ❌ | `0x6f784` |
| `RBPurchaseManager` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x6f944` |
| `RBPurchaseManager` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x7048c` |
| `RBPurchaseManager` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x70490` |
| `RBPurchaseManager` | `-` | `delegate` | prop | ✅ | ✅ | `0x70908` |
| `RBPurchaseManager` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x70928` |
| `RBPurchaseManager` | `-` | `purchasedProducts` | prop | ✅ | ✅ | `0x7093c` |
| `RBPurchaseManager` | `-` | `setPurchasedProducts:` | prop | ✅ | ✅ | `0x7094c` |
| `RBPurchaseManager` | `-` | `purchaseCheckTransactions` | prop | ✅ | ✅ | `0x70984` |
| `RBPurchaseManager` | `-` | `setPurchaseCheckTransactions:` | prop | ✅ | ✅ | `0x70994` |
| `RBPurchaseManager` | `-` | `purchaseCheckedProductsIn` | prop | ✅ | ✅ | `0x709cc` |
| `RBPurchaseManager` | `-` | `setPurchaseCheckedProductsIn:` | prop | ✅ | ✅ | `0x709dc` |
| `RBPurchaseManager` | `-` | `restoredTransactions` | prop | ✅ | ✅ | `0x70a14` |
| `RBPurchaseManager` | `-` | `setRestoredTransactions:` | prop | ✅ | ✅ | `0x70a24` |
| `RBPurchaseManager` | `-` | `downloader` | prop | ✅ | ✅ | `0x70a5c` |
| `RBPurchaseManager` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x70a6c` |
| `RBPurchaseManager` | `-` | `transactioing` | prop | ✅ | ✅ | `0x70aa4` |
| `RBPurchaseManager` | `-` | `setTransactioing:` | prop | ✅ | ✅ | `0x70ab4` |
| `RBPurchaseManager` | `-` | `isRestored` | prop | ✅ | ✅ | `0x70ac4` |
| `RBPurchaseManager` | `-` | `setIsRestored:` | prop | ✅ | ✅ | `0x70ad4` |
| `RBPurchaseManager` | `-` | `productIds` | prop | ✅ | ✅ | `0x70ae4` |
| `RBPurchaseManager` | `-` | `setProductIds:` | prop | ✅ | ✅ | `0x70af4` |
| `RBPurchaseManager` | `-` | `nonce` | prop | ✅ | ✅ | `0x70b2c` |
| `RBPurchaseManager` | `-` | `setNonce:` | prop | ✅ | ✅ | `0x70b3c` |
| `PurchaseTransactionCache` | `-` | `initWithTransaction:` |  | ✅ | ❌ | `0x70c28` |
| `PurchaseTransactionCache` | `-` | `dealloc` |  | ❌ | ✅ | `0x70e3c` |
| `PurchaseTransactionCache` | `-` | `productID` | prop | ✅ | ✅ | `0x70e70` |
| `PurchaseTransactionCache` | `-` | `setProductID:` | prop | ✅ | ✅ | `0x70e80` |
| `PurchaseTransactionCache` | `-` | `receiptData` | prop | ✅ | ✅ | `0x70eb8` |
| `PurchaseTransactionCache` | `-` | `setReceiptData:` | prop | ✅ | ✅ | `0x70ec8` |
| `PurchaseTransactionCache` | `-` | `transactionID` | prop | ✅ | ✅ | `0x70f00` |
| `PurchaseTransactionCache` | `-` | `setTransactionID:` | prop | ✅ | ✅ | `0x70f10` |
| `PurchaseTransactionCache` | `-` | `transactionDate` | prop | ✅ | ✅ | `0x70f48` |
| `PurchaseTransactionCache` | `-` | `setTransactionDate:` | prop | ✅ | ✅ | `0x70f58` |
| `PurchaseTransactionCache` | `-` | `digestString` | prop | ✅ | ✅ | `0x70f90` |
| `PurchaseTransactionCache` | `-` | `setDigestString:` | prop | ✅ | ✅ | `0x70fa0` |
| `RBPlaylistManager` | `+` | `sharedInstance` |  | ✅ | ❌ | `0x71054` |
| `RBPlaylistManager` | `-` | `initWithFile:` |  | ✅ | ❌ | `0x71190` |
| `RBPlaylistManager` | `-` | `synchronize` |  | ✅ | ❌ | `0x71654` |
| `RBPlaylistManager` | `-` | `numberOfPlaylists` |  | ✅ | ❌ | `0x716f4` |
| `RBPlaylistManager` | `-` | `playlistAtIndex:` |  | ✅ | ❌ | `0x71754` |
| `RBPlaylistManager` | `-` | `indexOfPlaylist:` |  | ✅ | ❌ | `0x7193c` |
| `RBPlaylistManager` | `-` | `indexOfPlaylistWithIdentifier:` |  | ✅ | ❌ | `0x719d4` |
| `RBPlaylistManager` | `-` | `nameOfPlaylistAtIndex:` |  | ✅ | ❌ | `0x71b84` |
| `RBPlaylistManager` | `-` | `identifierOfPlaylistAtIndex:` |  | ✅ | ❌ | `0x71c9c` |
| `RBPlaylistManager` | `-` | `setNameOfPlaylist:atIndex:` |  | ✅ | ❌ | `0x71db4` |
| `RBPlaylistManager` | `-` | `addPlaylistWithName:` |  | ✅ | ❌ | `0x71eac` |
| `RBPlaylistManager` | `-` | `removePlaylistAtIndex:` |  | ✅ | ❌ | `0x721c0` |
| `RBPlaylistManager` | `-` | `numberOfMusicInPlaylistAtIndex:` |  | ✅ | ❌ | `0x72288` |
| `RBPlaylistManager` | `-` | `containsMusic:inPlaylistAtIndex:` |  | ✅ | ❌ | `0x723c8` |
| `RBPlaylistManager` | `-` | `addMusic:toPlaylistAtIndex:` |  | ✅ | ❌ | `0x72560` |
| `RBPlaylistManager` | `-` | `removeMusic:fromPlaylistAtIndex:` |  | ✅ | ❌ | `0x72748` |
| `RBPlaylistManager` | `-` | `arrayPlaylist` | prop | ✅ | ✅ | `0x7291c` |
| `RBPlaylistManager` | `-` | `setArrayPlaylist:` | prop | ✅ | ✅ | `0x7292c` |
| `RBPlaylistManager` | `-` | `filePath` | prop | ✅ | ✅ | `0x72964` |
| `RBPlaylistManager` | `-` | `setFilePath:` | prop | ✅ | ✅ | `0x72974` |
| `RBPlaylistManager` | `-` | `lastSelectedMusicID` | prop | ✅ | ✅ | `0x72980` |
| `RBPlaylistManager` | `-` | `setLastSelectedMusicID:` | prop | ✅ | ✅ | `0x72990` |
| `Downloader` | `+` | `dictionaryToQueryData:` |  | ✅ | ❌ | `0x729e0` |
| `Downloader` | `+` | `dictionaryToJsonData:` |  | ✅ | ❌ | `0x72a0c` |
| `Downloader` | `-` | `initWithURL:save:` |  | ✅ | ❌ | `0x72a38` |
| `Downloader` | `-` | `initWithURL:post:contentType:` |  | ✅ | ❌ | `0x72b94` |
| `Downloader` | `-` | `initWithURL:post:contentType:timeout:` |  | ✅ | ❌ | `0x72cd4` |
| `Downloader` | `-` | `startDownloadingWithDelegate:` |  | ✅ | ❌ | `0x72e24` |
| `Downloader` | `-` | `startDownloadingWithProceed:success:failure:` |  | ✅ | ❌ | `0x72ed0` |
| `Downloader` | `-` | `cancel` |  | ✅ | ❌ | `0x72fa8` |
| `Downloader` | `-` | `downloaderProceed:` |  | ✅ | ❌ | `0x73050` |
| `Downloader` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x731a8` |
| `Downloader` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x73300` |
| `Downloader` | `-` | `currentSize` |  | ✅ | ❌ | `0x73458` |
| `Downloader` | `-` | `currentProgress` |  | ✅ | ❌ | `0x734b8` |
| `Downloader` | `-` | `getData` |  | ✅ | ❌ | `0x73520` |
| `Downloader` | `-` | `getDataInJSON` |  | ✅ | ❌ | `0x73588` |
| `Downloader` | `-` | `getHeader` |  | ✅ | ❌ | `0x735f0` |
| `Downloader` | `-` | `systemErrorMessage` |  | ✅ | ❌ | `0x73658` |
| `Downloader` | `-` | `showErrorMessage` |  | ✅ | ❌ | `0x736c0` |
| `Downloader` | `-` | `hashChecked` |  | ✅ | ❌ | `0x73728` |
| `Downloader` | `-` | `dealloc` |  | ✅ | ❌ | `0x73788` |
| `Downloader` | `-` | `addData` | prop | ✅ | ✅ | `0x738a0` |
| `Downloader` | `-` | `setAddData:` | prop | ✅ | ✅ | `0x738b0` |
| `Downloader` | `-` | `conn` | prop | ✅ | ✅ | `0x738e8` |
| `Downloader` | `-` | `setConn:` | prop | ✅ | ✅ | `0x738f8` |
| `Downloader` | `-` | `delegate` | prop | ✅ | ✅ | `0x73930` |
| `Downloader` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x73950` |
| `Downloader` | `-` | `successBlock` | prop | ✅ | ✅ | `0x73964` |
| `Downloader` | `-` | `setSuccessBlock:` | prop | ✅ | ✅ | `0x73974` |
| `Downloader` | `-` | `proceedBlock` | prop | ✅ | ✅ | `0x73980` |
| `Downloader` | `-` | `setProceedBlock:` | prop | ✅ | ✅ | `0x73990` |
| `Downloader` | `-` | `failureBlock` | prop | ✅ | ✅ | `0x7399c` |
| `Downloader` | `-` | `setFailureBlock:` | prop | ✅ | ✅ | `0x739ac` |
| `ImageDownloader` | `-` | `initWithGetURL:unUseRetina:` |  | ✅ | ❌ | `0x83d30` |
| `ImageDownloader` | `-` | `startDownload` |  | ✅ | ❌ | `0x83dc8` |
| `ImageDownloader` | `-` | `startDownloadWithProceed:success:failure:` |  | ✅ | ❌ | `0x83eb0` |
| `ImageDownloader` | `-` | `startDownloadRetina` |  | ✅ | ❌ | `0x83f6c` |
| `ImageDownloader` | `-` | `startDownloadNonRetina` |  | ✅ | ❌ | `0x84490` |
| `ImageDownloader` | `-` | `cancelDownload` |  | ✅ | ❌ | `0x84900` |
| `ImageDownloader` | `-` | `setImage:` |  | ✅ | ❌ | `0x849cc` |
| `ImageDownloader` | `-` | `getImage` |  | ✅ | ✅ | `0x84b3c` |
| `ImageDownloader` | `-` | `proceed` |  | ✅ | ❌ | `0x84b48` |
| `ImageDownloader` | `-` | `success` |  | ✅ | ❌ | `0x84e0c` |
| `ImageDownloader` | `-` | `failure` |  | ✅ | ❌ | `0x850d0` |
| `ImageDownloader` | `-` | `dealloc` |  | ✅ | ❌ | `0x85394` |
| `ImageDownloader` | `-` | `unUseRetina` | prop | ✅ | ✅ | `0x854f0` |
| `ImageDownloader` | `-` | `setUnUseRetina:` | prop | ✅ | ✅ | `0x85500` |
| `ImageDownloader` | `-` | `imageURL` | prop | ✅ | ✅ | `0x85510` |
| `ImageDownloader` | `-` | `setImageURL:` | prop | ✅ | ✅ | `0x85520` |
| `ImageDownloader` | `-` | `indexPathInTableView` | prop | ✅ | ✅ | `0x85558` |
| `ImageDownloader` | `-` | `setIndexPathInTableView:` | prop | ✅ | ✅ | `0x85568` |
| `ImageDownloader` | `-` | `conn` | prop | ✅ | ✅ | `0x855a0` |
| `ImageDownloader` | `-` | `setConn:` | prop | ✅ | ✅ | `0x855b0` |
| `ImageDownloader` | `-` | `delegate` | prop | ✅ | ✅ | `0x855e8` |
| `ImageDownloader` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x85608` |
| `ImageDownloader` | `-` | `imageTask` | prop | ✅ | ✅ | `0x8561c` |
| `ImageDownloader` | `-` | `setImageTask:` | prop | ✅ | ✅ | `0x8562c` |
| `ImageDownloader` | `-` | `imageTaskRetina` | prop | ✅ | ✅ | `0x85664` |
| `ImageDownloader` | `-` | `setImageTaskRetina:` | prop | ✅ | ✅ | `0x85674` |
| `ImageDownloader` | `-` | `downloadedImage` | prop | ✅ | ✅ | `0x856ac` |
| `ImageDownloader` | `-` | `setDownloadedImage:` | prop | ✅ | ✅ | `0x856bc` |
| `ImageDownloader` | `-` | `successBlock` | prop | ✅ | ✅ | `0x856f4` |
| `ImageDownloader` | `-` | `setSuccessBlock:` | prop | ✅ | ✅ | `0x85704` |
| `ImageDownloader` | `-` | `proceedBlock` | prop | ✅ | ✅ | `0x85710` |
| `ImageDownloader` | `-` | `setProceedBlock:` | prop | ✅ | ✅ | `0x85720` |
| `ImageDownloader` | `-` | `failureBlock` | prop | ✅ | ✅ | `0x8572c` |
| `ImageDownloader` | `-` | `setFailureBlock:` | prop | ✅ | ✅ | `0x8573c` |
| `StoreUtil` | `+` | `packListURL:limit:genre:` |  | ✅ | ✅ | `0x85944` |
| `StoreUtil` | `+` | `packInfoURL:UserOpen:` |  | ✅ | ✅ | `0x85958` |
| `StoreUtil` | `+` | `musicInfoURL:` |  | ✅ | ✅ | `0x8596c` |
| `StoreUtil` | `+` | `receiptV3URL` |  | ✅ | ✅ | `0x85980` |
| `StoreUtil` | `+` | `campaignListURL` |  | ✅ | ✅ | `0x85994` |
| `StoreUtil` | `+` | `campaignSerialCheckURL` |  | ✅ | ✅ | `0x859a8` |
| `StoreUtil` | `+` | `campaignItemInfoURL` |  | ✅ | ✅ | `0x859bc` |
| `StoreUtil` | `+` | `manageSortListURL` |  | ✅ | ✅ | `0x859d0` |
| `StoreUtil` | `+` | `userAgeURL` |  | ✅ | ✅ | `0x859e4` |
| `StoreUtil` | `+` | `productIDForPackID:` |  | ✅ | ❌ | `0x859f8` |
| `StoreUtil` | `+` | `packIDForProductID:` |  | ✅ | ❌ | `0x85a4c` |
| `StoreUtil` | `+` | `priceString:` |  | ✅ | ❌ | `0x85b4c` |
| `StoreUtil` | `+` | `priceString:useCatalogPrice:` |  | ✅ | ❌ | `0x85b7c` |
| `StoreUtil` | `+` | `isValidURL:` |  | ✅ | ❌ | `0x85cc0` |
| `StoreUtil` | `+` | `createReceiptCheckJSON:` |  | ✅ | ❌ | `0x85e54` |
| `StoreUtil` | `+` | `createReceiptCheckJSONForV2:productIds:nonce:` |  | ✅ | ❌ | `0x85fd4` |
| `StoreUtil` | `+` | `createReceiptCheckDigest:` |  | ✅ | ❌ | `0x86484` |
| `StoreUtil` | `+` | `createReceiptCheckDigestV2:withNonce:` |  | ✅ | ❌ | `0x8657c` |
| `StoreUtil` | `+` | `createNonce:` |  | ✅ | ❌ | `0x8665c` |
| `StoreUtil` | `+` | `createCampaignListJSON:limit:` |  | ✅ | ❌ | `0x8678c` |
| `StoreUtil` | `+` | `createCampaignSerialCheckJSON:code:` |  | ✅ | ❌ | `0x868e4` |
| `StoreUtil` | `+` | `createCampaignItemInfoJSON:` |  | ✅ | ❌ | `0x86a54` |
| `StoreUtil` | `+` | `affiliateParametersFromURL:` |  | ✅ | ❌ | `0x86b9c` |
| `StoreUtil` | `+` | `extendNoteListURL:limit:` |  | ✅ | ✅ | `0x87478` |
| `StoreUtil` | `+` | `extendNoteInfoURL:UserOpen:` |  | ✅ | ✅ | `0x8748c` |
| `StoreUtil` | `+` | `pidToProductID:` |  | ✅ | ❌ | `0x874a0` |
| `StoreUtil` | `+` | `productIDToPid:` |  | ✅ | ❌ | `0x874f4` |
| `TwitterImageCreaterScoreElement` | `-` | `dealloc` |  | ❌ | ✅ | `0x875f4` |
| `TwitterImageCreaterScoreElement` | `-` | `score` | prop | ✅ | ✅ | `0x87628` |
| `TwitterImageCreaterScoreElement` | `-` | `setScore:` | prop | ✅ | ✅ | `0x87638` |
| `TwitterImageCreaterScoreElement` | `-` | `ar` | prop | ✅ | ✅ | `0x87648` |
| `TwitterImageCreaterScoreElement` | `-` | `setAr:` | prop | ✅ | ✅ | `0x87658` |
| `TwitterImageCreaterScoreElement` | `-` | `justNum` | prop | ✅ | ✅ | `0x87668` |
| `TwitterImageCreaterScoreElement` | `-` | `setJustNum:` | prop | ✅ | ✅ | `0x87678` |
| `TwitterImageCreaterScoreElement` | `-` | `greatNum` | prop | ✅ | ✅ | `0x87688` |
| `TwitterImageCreaterScoreElement` | `-` | `setGreatNum:` | prop | ✅ | ✅ | `0x87698` |
| `TwitterImageCreaterScoreElement` | `-` | `goodNum` | prop | ✅ | ✅ | `0x876a8` |
| `TwitterImageCreaterScoreElement` | `-` | `setGoodNum:` | prop | ✅ | ✅ | `0x876b8` |
| `TwitterImageCreaterScoreElement` | `-` | `missNum` | prop | ✅ | ✅ | `0x876c8` |
| `TwitterImageCreaterScoreElement` | `-` | `setMissNum:` | prop | ✅ | ✅ | `0x876d8` |
| `TwitterImageCreaterScoreElement` | `-` | `justReflecNum` | prop | ✅ | ✅ | `0x876e8` |
| `TwitterImageCreaterScoreElement` | `-` | `setJustReflecNum:` | prop | ✅ | ✅ | `0x876f8` |
| `TwitterImageCreaterScoreElement` | `-` | `maxComboNum` | prop | ✅ | ✅ | `0x87708` |
| `TwitterImageCreaterScoreElement` | `-` | `setMaxComboNum:` | prop | ✅ | ✅ | `0x87718` |
| `TwitterImageCreaterScoreElement` | `-` | `name` | prop | ✅ | ✅ | `0x87728` |
| `TwitterImageCreaterScoreElement` | `-` | `setName:` | prop | ✅ | ✅ | `0x87738` |
| `TwitterImageCreater` | `-` | `init` |  | ✅ | ❌ | `0x87784` |
| `TwitterImageCreater` | `-` | `reset` |  | ✅ | ❌ | `0x87848` |
| `TwitterImageCreater` | `-` | `dealloc` |  | ✅ | ❌ | `0x878ac` |
| `TwitterImageCreater` | `-` | `setScore:Side:` |  | ✅ | ❌ | `0x87930` |
| `TwitterImageCreater` | `-` | `setAR:Side:` |  | ✅ | ❌ | `0x87958` |
| `TwitterImageCreater` | `-` | `setJustNum:Side:` |  | ✅ | ❌ | `0x87980` |
| `TwitterImageCreater` | `-` | `setGreatNum:Side:` |  | ✅ | ❌ | `0x879a8` |
| `TwitterImageCreater` | `-` | `setGoodNum:Side:` |  | ✅ | ❌ | `0x879d0` |
| `TwitterImageCreater` | `-` | `setMissNum:Side:` |  | ✅ | ❌ | `0x879f8` |
| `TwitterImageCreater` | `-` | `setJustReflecNum:Side:` |  | ✅ | ❌ | `0x87a20` |
| `TwitterImageCreater` | `-` | `setMaxComboNum:Side:` |  | ✅ | ❌ | `0x87a48` |
| `TwitterImageCreater` | `-` | `setName:Side:` |  | ✅ | ❌ | `0x87a70` |
| `TwitterImageCreater` | `-` | `createContext::` |  | ❌ | ❌ | `0x87ae4` |
| `TwitterImageCreater` | `-` | `drawImage:X:Y:Scale:` |  | ✅ | ❌ | `0x87ba0` |
| `TwitterImageCreater` | `-` | `drawImage:X:Y:` |  | ✅ | ❌ | `0x87c78` |
| `TwitterImageCreater` | `-` | `drawImageFileName:X:Y:` |  | ✅ | ❌ | `0x87d40` |
| `TwitterImageCreater` | `-` | `drawImageFileName:Position:` |  | ✅ | ❌ | `0x87dd4` |
| `TwitterImageCreater` | `-` | `drawText:Position:Font:Color:` |  | ✅ | ❌ | `0x87e68` |
| `TwitterImageCreater` | `-` | `drawNumber:Position:Keta:Dot:` |  | ✅ | ❌ | `0x87fa4` |
| `TwitterImageCreater` | `-` | `getDigitNum:` |  | ✅ | ❌ | `0x881fc` |
| `TwitterImageCreater` | `-` | `drawScore:Pos:Dot:` |  | ✅ | ❌ | `0x88244` |
| `TwitterImageCreater` | `-` | `createImage` |  | ✅ | ❌ | `0x888b0` |
| `TwitterImageCreater` | `-` | `titleImage` | prop | ✅ | ✅ | `0x88d88` |
| `TwitterImageCreater` | `-` | `setTitleImage:` | prop | ✅ | ✅ | `0x88d98` |
| `TwitterImageCreater` | `-` | `artistImage` | prop | ✅ | ✅ | `0x88dd0` |
| `TwitterImageCreater` | `-` | `setArtistImage:` | prop | ✅ | ✅ | `0x88de0` |
| `TwitterImageCreater` | `-` | `grade` | prop | ✅ | ✅ | `0x88e18` |
| `TwitterImageCreater` | `-` | `setGrade:` | prop | ✅ | ✅ | `0x88e28` |
| `TwitterImageCreater` | `-` | `level` | prop | ✅ | ✅ | `0x88e38` |
| `TwitterImageCreater` | `-` | `setLevel:` | prop | ✅ | ✅ | `0x88e48` |
| `TwitterImageCreater` | `-` | `gameType` | prop | ✅ | ✅ | `0x88e58` |
| `TwitterImageCreater` | `-` | `setGameType:` | prop | ✅ | ✅ | `0x88e68` |
| `TwitterImageCreater` | `-` | `noteNum` | prop | ✅ | ✅ | `0x88e78` |
| `TwitterImageCreater` | `-` | `setNoteNum:` | prop | ✅ | ✅ | `0x88e88` |
| `TwitterImageCreater` | `-` | `color` | prop | ✅ | ✅ | `0x88e98` |
| `TwitterImageCreater` | `-` | `setColor:` | prop | ✅ | ✅ | `0x88ea8` |
| `(RB)` | `-` | `prefersStatusBarHidden` |  | ❌ | ❌ | `0x88fb8` |
| `RBViewController` | `-` | `init` |  | ✅ | ✅ | `0x88fc0` |
| `RBViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x89050` |
| `RBViewController` | `-` | `showPresentViewController` |  | ✅ | ✅ | `0x893c4` |
| `RBViewController` | `-` | `showPresentViewController:` |  | ✅ | ❌ | `0x8945c` |
| `RBViewController` | `-` | `playListAddMusicSet:` |  | ✅ | ❌ | `0x89798` |
| `RBViewController` | `-` | `playListButtonPush:` |  | ✅ | ❌ | `0x8997c` |
| `RBViewController` | `-` | `removeView` |  | ✅ | ✅ | `0x89c24` |
| `RBViewController` | `-` | `createView` |  | ✅ | ❌ | `0x89c90` |
| `RBViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x8a134` |
| `RBViewController` | `-` | `didSelectPlaylistViewController:` |  | ✅ | ❌ | `0x8a294` |
| `RBViewController` | `-` | `didSelectMenuSortViewController:` |  | ✅ | ✅ | `0x8a3e8` |
| `RBViewController` | `-` | `navigationController:willShowViewController:animated:` |  | ✅ | ❌ | `0x8a444` |
| `RBViewController` | `-` | `willRotateToInterfaceOrientation:duration:` |  | ✅ | ✅ | `0x8a530` |
| `RBViewController` | `-` | `didRotateFromInterfaceOrientation:` |  | ✅ | ✅ | `0x8a584` |
| `RBViewController` | `-` | `viewWillTransitionToSize:withTransitionCoordinator:` |  | ✅ | ❌ | `0x8a5d8` |
| `RBViewController` | `-` | `LayoutedGLView:` |  | ✅ | ✅ | `0x8a7e4` |
| `RBViewController` | `-` | `UpdateProjection` |  | ✅ | ✅ | `0x8a800` |
| `RBViewController` | `-` | `openGLView` |  | ✅ | ✅ | `0x8af30` |
| `RBViewController` | `-` | `Task` |  | ✅ | ✅ | `0x8af3c` |
| `RBViewController` | `-` | `Draw` |  | ✅ | ✅ | `0x8af88` |
| `RBViewController` | `-` | `mainLoop` |  | ✅ | ✅ | `0x8b074` |
| `RBViewController` | `-` | `StartLoop` |  | ✅ | ✅ | `0x8b0a8` |
| `RBViewController` | `-` | `StopLoop` |  | ✅ | ✅ | `0x8b0c4` |
| `RBViewController` | `-` | `ResumeLoop` |  | ✅ | ✅ | `0x8b0dc` |
| `RBViewController` | `-` | `RestartLoop` |  | ✅ | ✅ | `0x8b0f8` |
| `RBViewController` | `-` | `CreateDisplayLinkTimer` |  | ✅ | ✅ | `0x8b110` |
| `RBViewController` | `-` | `SetLoopTimeMilliSec:` |  | ✅ | ❌ | `0x8b288` |
| `RBViewController` | `-` | `CreateTimer` |  | ✅ | ❌ | `0x8b2a0` |
| `RBViewController` | `-` | `RemoveTimer` |  | ✅ | ❌ | `0x8b314` |
| `RBViewController` | `-` | `showMusicListView` |  | ✅ | ❌ | `0x8b3bc` |
| `RBViewController` | `-` | `clientIsGameEnd` |  | ✅ | ✅ | `0x8b5b4` |
| `RBViewController` | `-` | `playGameWithMusicData:RandSeed:` |  | ✅ | ❌ | `0x8b5b8` |
| `RBViewController` | `-` | `startPreview` |  | ✅ | ❌ | `0x8be40` |
| `RBViewController` | `-` | `showPreview` |  | ✅ | ❌ | `0x8c8cc` |
| `RBViewController` | `-` | `hidePreview` |  | ✅ | ❌ | `0x8c970` |
| `RBViewController` | `-` | `openItunesWithURL:` |  | ✅ | ❌ | `0x8ce28` |
| `RBViewController` | `-` | `closeItunesWithURL` |  | ✅ | ❌ | `0x8d204` |
| `RBViewController` | `-` | `getTopViewController:` |  | ✅ | ❌ | `0x8d264` |
| `RBViewController` | `-` | `productViewControllerDidFinish:` |  | ✅ | ❌ | `0x8d40c` |
| `RBViewController` | `+` | `hasTwitterAPI` |  | ✅ | ❌ | `0x8d540` |
| `RBViewController` | `+` | `canTweet` |  | ✅ | ❌ | `0x8d564` |
| `RBViewController` | `-` | `PostTwitter:Images:URLs:` |  | ✅ | ❌ | `0x8d5b4` |
| `RBViewController` | `-` | `PostTweet` |  | ✅ | ❌ | `0x8d9c0` |
| `RBViewController` | `-` | `PostImageCreater` |  | ✅ | ❌ | `0x8dacc` |
| `RBViewController` | `-` | `PostTwitter:Text:` |  | ✅ | ❌ | `0x8dbbc` |
| `RBViewController` | `-` | `cancelTwitterConnection` |  | ✅ | ❌ | `0x8de58` |
| `RBViewController` | `-` | `connection:didReceiveResponse:` |  | ✅ | ❌ | `0x8df10` |
| `RBViewController` | `-` | `connection:didFailWithError:` |  | ✅ | ❌ | `0x8dfc8` |
| `RBViewController` | `-` | `connectionDidFinishLoading:` |  | ✅ | ❌ | `0x8dfe4` |
| `RBViewController` | `-` | `showTermsWithDelegate:` |  | ✅ | ❌ | `0x8e118` |
| `RBViewController` | `-` | `updateErosionMarkScore` |  | ✅ | ❌ | `0x8e2d8` |
| `RBViewController` | `-` | `setupCorporateButton` |  | ✅ | ❌ | `0x8e2f4` |
| `RBViewController` | `-` | `fadeCorporateButton:` |  | ✅ | ❌ | `0x8e550` |
| `RBViewController` | `-` | `tapCorporateButton:` |  | ✅ | ❌ | `0x8e898` |
| `RBViewController` | `-` | `musicMenuView` | prop | ✅ | ✅ | `0x8eac0` |
| `RBViewController` | `-` | `setMusicMenuView:` | prop | ✅ | ✅ | `0x8ead0` |
| `RBViewController` | `-` | `playlistPopoverController` | prop | ✅ | ✅ | `0x8eb08` |
| `RBViewController` | `-` | `setPlaylistPopoverController:` | prop | ✅ | ✅ | `0x8eb18` |
| `RBViewController` | `-` | `termAgreeView` | prop | ✅ | ✅ | `0x8eb50` |
| `RBViewController` | `-` | `setTermAgreeView:` | prop | ✅ | ✅ | `0x8eb60` |
| `RBViewController` | `-` | `tweetText` | prop | ✅ | ✅ | `0x8eb70` |
| `RBViewController` | `-` | `setTweetText:` | prop | ✅ | ✅ | `0x8eb80` |
| `RBViewController` | `-` | `tweetImage` | prop | ✅ | ✅ | `0x8eb8c` |
| `RBViewController` | `-` | `setTweetImage:` | prop | ✅ | ✅ | `0x8eb9c` |
| `RBViewController` | `-` | `twitterImageCreater` | prop | ✅ | ✅ | `0x8eba8` |
| `RBViewController` | `-` | `setTwitterImageCreater:` | prop | ✅ | ✅ | `0x8ebb8` |
| `RBViewController` | `-` | `glView` | prop | ✅ | ✅ | `0x8ebc4` |
| `RBViewController` | `-` | `setGlView:` | prop | ✅ | ✅ | `0x8ebd4` |
| `RBViewController` | `-` | `displayLink` | prop | ✅ | ✅ | `0x8ec0c` |
| `RBViewController` | `-` | `setDisplayLink:` | prop | ✅ | ✅ | `0x8ec1c` |
| `RBViewController` | `-` | `tweetCoverView` | prop | ✅ | ✅ | `0x8ec54` |
| `RBViewController` | `-` | `setTweetCoverView:` | prop | ✅ | ✅ | `0x8ec64` |
| `RBViewController` | `-` | `twitterImageCreaterQueue` | prop | ✅ | ✅ | `0x8ec9c` |
| `RBViewController` | `-` | `setTwitterImageCreaterQueue:` | prop | ✅ | ✅ | `0x8ecac` |
| `RBViewController` | `-` | `twitterRequestTest` | prop | ✅ | ✅ | `0x8ece4` |
| `RBViewController` | `-` | `setTwitterRequestTest:` | prop | ✅ | ✅ | `0x8ecf4` |
| `RBViewController` | `-` | `twitterConnectionTest` | prop | ✅ | ✅ | `0x8ed2c` |
| `RBViewController` | `-` | `setTwitterConnectionTest:` | prop | ✅ | ✅ | `0x8ed3c` |
| `RBViewController` | `-` | `playlistViewController` | prop | ✅ | ✅ | `0x8ed74` |
| `RBViewController` | `-` | `setPlaylistViewController:` | prop | ✅ | ✅ | `0x8ed84` |
| `RBViewController` | `-` | `itunesViewCtrl` | prop | ✅ | ✅ | `0x8edbc` |
| `RBViewController` | `-` | `setItunesViewCtrl:` | prop | ✅ | ✅ | `0x8edcc` |
| `RBViewController` | `-` | `corporateButton` | prop | ✅ | ✅ | `0x8ee04` |
| `RBViewController` | `-` | `setCorporateButton:` | prop | ✅ | ✅ | `0x8ee14` |
| `RBViewController` | `-` | `corporateViewCtrl` | prop | ✅ | ✅ | `0x8ee24` |
| `RBViewController` | `-` | `setCorporateViewCtrl:` | prop | ✅ | ✅ | `0x8ee34` |
| `RBPlaylistCreateViewController` | `-` | `setTitle:` |  | ✅ | ❌ | `0x8f158` |
| `RBPlaylistCreateViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x8f250` |
| `RBPlaylistCreateViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x90164` |
| `RBPlaylistCreateViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x90428` |
| `RBPlaylistCreateViewController` | `-` | `viewWillDisappear:` |  | ✅ | ❌ | `0x904ac` |
| `RBPlaylistCreateViewController` | `-` | `doneButtonPush:` |  | ✅ | ❌ | `0x90530` |
| `RBPlaylistCreateViewController` | `-` | `backButtonPush:` |  | ✅ | ❌ | `0x9070c` |
| `RBPlaylistCreateViewController` | `-` | `fieldChanged:` |  | ✅ | ❌ | `0x90778` |
| `RBPlaylistCreateViewController` | `-` | `textFieldShouldReturn:` |  | ✅ | ❌ | `0x90890` |
| `RBPlaylistCreateViewController` | `-` | `textField:shouldChangeCharactersInRange:replacementString:` |  | ✅ | ❌ | `0x9094c` |
| `RBPlaylistCreateViewController` | `-` | `textField` | prop | ✅ | ✅ | `0x90a80` |
| `RBPlaylistCreateViewController` | `-` | `setTextField:` | prop | ✅ | ✅ | `0x90a90` |
| `RBPlaylistCreateViewController` | `-` | `titleLabel` | prop | ✅ | ✅ | `0x90ac8` |
| `RBPlaylistCreateViewController` | `-` | `setTitleLabel:` | prop | ✅ | ✅ | `0x90ad8` |
| `RBPlaylistCreateViewController` | `-` | `titleColor` | prop | ✅ | ✅ | `0x90b10` |
| `RBPlaylistCreateViewController` | `-` | `setTitleColor:` | prop | ✅ | ✅ | `0x90b20` |
| `RBPlaylistCreateViewController` | `-` | `buttonColor` | prop | ✅ | ✅ | `0x90b58` |
| `RBPlaylistCreateViewController` | `-` | `setButtonColor:` | prop | ✅ | ✅ | `0x90b68` |
| `RBPlaylistCreateViewController` | `-` | `selectedRowColor` | prop | ✅ | ✅ | `0x90ba0` |
| `RBPlaylistCreateViewController` | `-` | `setSelectedRowColor:` | prop | ✅ | ✅ | `0x90bb0` |
| `RBPlaylistViewController` | `-` | `setTitle:` |  | ✅ | ❌ | `0x90c64` |
| `RBPlaylistViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x90f18` |
| `RBPlaylistViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x92398` |
| `RBPlaylistViewController` | `-` | `valueChanged:` |  | ✅ | ❌ | `0x927ec` |
| `RBPlaylistViewController` | `-` | `reloadData` |  | ✅ | ❌ | `0x92944` |
| `RBPlaylistViewController` | `-` | `returnButtonPush:` |  | ✅ | ❌ | `0x93a7c` |
| `RBPlaylistViewController` | `-` | `closeButtonPush:` |  | ✅ | ❌ | `0x93ae8` |
| `RBPlaylistViewController` | `-` | `addButtonPush:` |  | ✅ | ❌ | `0x93bd8` |
| `RBPlaylistViewController` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ❌ | `0x93d00` |
| `RBPlaylistViewController` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ❌ | `0x93d50` |
| `RBPlaylistViewController` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ❌ | `0x93e54` |
| `RBPlaylistViewController` | `-` | `tableView:canEditRowAtIndexPath:` |  | ✅ | ❌ | `0x94c3c` |
| `RBPlaylistViewController` | `-` | `tableView:commitEditingStyle:forRowAtIndexPath:` |  | ✅ | ❌ | `0x94c64` |
| `RBPlaylistViewController` | `-` | `tableView:canMoveRowAtIndexPath:` |  | ✅ | ❌ | `0x94d70` |
| `RBPlaylistViewController` | `-` | `tableView:moveRowAtIndexPath:toIndexPath:` |  | ✅ | ✅ | `0x94d98` |
| `RBPlaylistViewController` | `-` | `tableView:didSelectRowAtIndexPath:` |  | ✅ | ❌ | `0x94d9c` |
| `RBPlaylistViewController` | `-` | `delegate` | prop | ✅ | ✅ | `0x955e4` |
| `RBPlaylistViewController` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x95604` |
| `RBPlaylistViewController` | `-` | `playlistType` | prop | ✅ | ✅ | `0x95618` |
| `RBPlaylistViewController` | `-` | `setPlaylistType:` | prop | ✅ | ✅ | `0x95628` |
| `RBPlaylistViewController` | `-` | `playlistNode` | prop | ✅ | ✅ | `0x95638` |
| `RBPlaylistViewController` | `-` | `setPlaylistNode:` | prop | ✅ | ✅ | `0x95648` |
| `RBPlaylistViewController` | `-` | `musicSet` | prop | ✅ | ✅ | `0x95658` |
| `RBPlaylistViewController` | `-` | `setMusicSet:` | prop | ✅ | ✅ | `0x95668` |
| `RBPlaylistViewController` | `-` | `menuItems` | prop | ✅ | ✅ | `0x956a0` |
| `RBPlaylistViewController` | `-` | `setMenuItems:` | prop | ✅ | ✅ | `0x956b0` |
| `RBPlaylistViewController` | `-` | `playlistFiles` | prop | ✅ | ✅ | `0x956e8` |
| `RBPlaylistViewController` | `-` | `setPlaylistFiles:` | prop | ✅ | ✅ | `0x956f8` |
| `RBPlaylistViewController` | `-` | `musicColor` | prop | ✅ | ✅ | `0x95730` |
| `RBPlaylistViewController` | `-` | `setMusicColor:` | prop | ✅ | ✅ | `0x95740` |
| `RBPlaylistViewController` | `-` | `artistColor` | prop | ✅ | ✅ | `0x95778` |
| `RBPlaylistViewController` | `-` | `setArtistColor:` | prop | ✅ | ✅ | `0x95788` |
| `RBPlaylistViewController` | `-` | `titleColor` | prop | ✅ | ✅ | `0x957c0` |
| `RBPlaylistViewController` | `-` | `setTitleColor:` | prop | ✅ | ✅ | `0x957d0` |
| `RBPlaylistViewController` | `-` | `buttonColor` | prop | ✅ | ✅ | `0x95808` |
| `RBPlaylistViewController` | `-` | `setButtonColor:` | prop | ✅ | ✅ | `0x95818` |
| `RBPlaylistViewController` | `-` | `selectedRowColor` | prop | ✅ | ✅ | `0x95850` |
| `RBPlaylistViewController` | `-` | `setSelectedRowColor:` | prop | ✅ | ✅ | `0x95860` |
| `RBPlaylistViewController` | `-` | `titleLabel` | prop | ✅ | ✅ | `0x95898` |
| `RBPlaylistViewController` | `-` | `setTitleLabel:` | prop | ✅ | ✅ | `0x958a8` |
| `RBPlaylistViewController` | `-` | `segmentedControl` | prop | ✅ | ✅ | `0x958e0` |
| `RBPlaylistViewController` | `-` | `setSegmentedControl:` | prop | ✅ | ✅ | `0x958f0` |
| `RBCreditsView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x96328` |
| `RBCreditsView` | `-` | `setupView` |  | ✅ | ❌ | `0x963b4` |
| `RBCreditsView` | `-` | `settingView` | prop | ✅ | ✅ | `0x96620` |
| `RBCreditsView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0x96640` |
| `RBCustomView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x96664` |
| `RBCustomView` | `-` | `dealloc` |  | ❌ | ✅ | `0x966f0` |
| `RBCustomView` | `-` | `setupView` |  | ✅ | ❌ | `0x96724` |
| `RBCustomView` | `-` | `showAnimation` |  | ✅ | ❌ | `0x987b0` |
| `RBCustomView` | `-` | `toUnlock:` |  | ✅ | ❌ | `0x98834` |
| `RBCustomView` | `-` | `toCustomize:` |  | ✅ | ❌ | `0x98ec4` |
| `RBCustomView` | `-` | `toRewardList:` |  | ✅ | ❌ | `0x99494` |
| `RBCustomView` | `-` | `hideRewardList` |  | ✅ | ❌ | `0x997a0` |
| `RBCustomView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x99a6c` |
| `RBCustomView` | `-` | `getUnlockButtonView` |  | ✅ | ✅ | `0x99b30` |
| `RBCustomView` | `-` | `getCustomButtonView` |  | ✅ | ✅ | `0x99b3c` |
| `RBCustomView` | `-` | `getCustomizeItemView` |  | ✅ | ✅ | `0x99b48` |
| `RBCustomView` | `-` | `settingView` | prop | ✅ | ✅ | `0x99b54` |
| `RBCustomView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0x99b74` |
| `RBCustomView` | `-` | `customizeItemView` | prop | ✅ | ✅ | `0x99b88` |
| `RBCustomView` | `-` | `setCustomizeItemView:` | prop | ✅ | ✅ | `0x99b98` |
| `RBCustomView` | `-` | `experienceItemView` | prop | ✅ | ✅ | `0x99bd0` |
| `RBCustomView` | `-` | `setExperienceItemView:` | prop | ✅ | ✅ | `0x99be0` |
| `RBCustomView` | `-` | `experienceButton` | prop | ✅ | ✅ | `0x99c18` |
| `RBCustomView` | `-` | `setExperienceButton:` | prop | ✅ | ✅ | `0x99c28` |
| `RBCustomView` | `-` | `experienceSetButton` | prop | ✅ | ✅ | `0x99c60` |
| `RBCustomView` | `-` | `setExperienceSetButton:` | prop | ✅ | ✅ | `0x99c70` |
| `RBCustomView` | `-` | `experienceUnlockButton` | prop | ✅ | ✅ | `0x99ca8` |
| `RBCustomView` | `-` | `setExperienceUnlockButton:` | prop | ✅ | ✅ | `0x99cb8` |
| `RBCustomView` | `-` | `experienceButtonEffectView` | prop | ✅ | ✅ | `0x99cf0` |
| `RBCustomView` | `-` | `setExperienceButtonEffectView:` | prop | ✅ | ✅ | `0x99d00` |
| `RBCustomView` | `-` | `experienceButtonFrameView` | prop | ✅ | ✅ | `0x99d38` |
| `RBCustomView` | `-` | `setExperienceButtonFrameView:` | prop | ✅ | ✅ | `0x99d48` |
| `RBCustomView` | `-` | `firstInfo` | prop | ✅ | ✅ | `0x99d80` |
| `RBCustomView` | `-` | `setFirstInfo:` | prop | ✅ | ✅ | `0x99d90` |
| `RBCustomView` | `-` | `rewardListView` | prop | ✅ | ✅ | `0x99da0` |
| `RBCustomView` | `-` | `setRewardListView:` | prop | ✅ | ✅ | `0x99db0` |
| `RBHowToView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x99eb0` |
| `RBHowToView` | `-` | `dealloc` |  | ✅ | ❌ | `0x99f3c` |
| `RBHowToView` | `-` | `setupView` |  | ✅ | ❌ | `0x9a200` |
| `RBHowToView` | `-` | `createViewSame:` |  | ✅ | ❌ | `0x9a9d4` |
| `RBHowToView` | `-` | `layoutScrollView` |  | ✅ | ❌ | `0x9aba8` |
| `RBHowToView` | `-` | `pageDidChangeValue:` |  | ✅ | ❌ | `0x9ac6c` |
| `RBHowToView` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x9aedc` |
| `RBHowToView` | `-` | `settingView` | prop | ✅ | ✅ | `0x9b004` |
| `RBHowToView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0x9b024` |
| `RBHowToView` | `-` | `scrollView` | prop | ✅ | ✅ | `0x9b038` |
| `RBHowToView` | `-` | `setScrollView:` | prop | ✅ | ✅ | `0x9b048` |
| `RBHowToView` | `-` | `pageControl` | prop | ✅ | ✅ | `0x9b080` |
| `RBHowToView` | `-` | `setPageControl:` | prop | ✅ | ✅ | `0x9b090` |
| `RBCampaignData` | `+` | `sharedInstance` |  | ✅ | ❌ | `0x9c404` |
| `RBCampaignData` | `-` | `parseDictionary:` |  | ✅ | ❌ | `0x9c45c` |
| `RBCampaignData` | `-` | `setColor:key:` |  | ✅ | ❌ | `0x9c8e4` |
| `RBCampaignData` | `-` | `startDownloadWithPath:key:` |  | ✅ | ❌ | `0x9cbc8` |
| `RBCampaignData` | `-` | `presetHinabitaMode` |  | ✅ | ❌ | `0x9d37c` |
| `RBCampaignData` | `-` | `setHinabitaMode:` |  | ✅ | ✅ | `0x9d3bc` |
| `RBCampaignData` | `-` | `isCampaignMode` | prop | ✅ | ✅ | `0x9d3c8` |
| `RBCampaignData` | `-` | `setIsCampaignMode:` | prop | ✅ | ✅ | `0x9d3dc` |
| `RBCampaignData` | `-` | `campaignName` | prop | ✅ | ✅ | `0x9d3ec` |
| `RBCampaignData` | `-` | `setCampaignName:` | prop | ✅ | ✅ | `0x9d3fc` |
| `RBCampaignData` | `-` | `storeBaseColor` | prop | ✅ | ✅ | `0x9d408` |
| `RBCampaignData` | `-` | `setStoreBaseColor:` | prop | ✅ | ✅ | `0x9d418` |
| `RBCampaignData` | `-` | `storeStrapImage` | prop | ✅ | ✅ | `0x9d424` |
| `RBCampaignData` | `-` | `setStoreStrapImage:` | prop | ✅ | ✅ | `0x9d434` |
| `RBCampaignData` | `-` | `storeBaseImage` | prop | ✅ | ✅ | `0x9d440` |
| `RBCampaignData` | `-` | `setStoreBaseImage:` | prop | ✅ | ✅ | `0x9d450` |
| `RBCampaignData` | `-` | `storeSampleColor` | prop | ✅ | ✅ | `0x9d45c` |
| `RBCampaignData` | `-` | `setStoreSampleColor:` | prop | ✅ | ✅ | `0x9d46c` |
| `RBCampaignData` | `-` | `storeColorPackA` | prop | ✅ | ✅ | `0x9d478` |
| `RBCampaignData` | `-` | `setStoreColorPackA:` | prop | ✅ | ✅ | `0x9d488` |
| `RBCampaignData` | `-` | `storeColorPackB` | prop | ✅ | ✅ | `0x9d494` |
| `RBCampaignData` | `-` | `setStoreColorPackB:` | prop | ✅ | ✅ | `0x9d4a4` |
| `RBCampaignData` | `-` | `messageList` | prop | ✅ | ✅ | `0x9d4b0` |
| `RBCampaignData` | `-` | `setMessageList:` | prop | ✅ | ✅ | `0x9d4c0` |
| `RBCampaignData` | `-` | `isCampaignHinabita201703` | prop | ✅ | ✅ | `0x9d4cc` |
| `RBCampaignData` | `-` | `setIsCampaignHinabita201703:` | prop | ✅ | ✅ | `0x9d4e0` |
| `RBCampaignData` | `-` | `imageDownloaders` | prop | ✅ | ✅ | `0x9d4f0` |
| `RBCampaignData` | `-` | `setImageDownloaders:` | prop | ✅ | ✅ | `0x9d500` |
| `RBCollectionView` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x9d5d8` |
| `RBCollectionView` | `-` | `touchesBegan:withEvent:` |  | ✅ | ❌ | `0x9d730` |
| `RBCollectionView` | `-` | `touchesEnded:withEvent:` |  | ✅ | ❌ | `0x9d874` |
| `RBCollectionView` | `-` | `customDelegate` | prop | ✅ | ✅ | `0x9d9b8` |
| `RBCollectionView` | `-` | `setCustomDelegate:` | prop | ✅ | ✅ | `0x9d9d8` |
| `RBMenuButton` | `-` | `initWithType:` |  | ✅ | ✅ | `0x9d9fc` |
| `RBMenuButton` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x9da80` |
| `RBMenuButton` | `-` | `setupView:` |  | ✅ | ✅ | `0x9dab4` |
| `RBMenuButton` | `-` | `setFlashEffect` |  | ✅ | ❌ | `0x9e2b0` |
| `RBMenuButton` | `-` | `removeFlashEffect` |  | ✅ | ❌ | `0x9e3cc` |
| `RBMenuButton` | `-` | `setEnabled:` |  | ✅ | ❌ | `0x9e4e8` |
| `RBMenuButton` | `-` | `button` | prop | ✅ | ✅ | `0x9e544` |
| `RBMenuButton` | `-` | `setButton:` | prop | ✅ | ✅ | `0x9e554` |
| `RBMenuButton` | `-` | `effectImageView` | prop | ✅ | ✅ | `0x9e58c` |
| `RBMenuButton` | `-` | `setEffectImageView:` | prop | ✅ | ✅ | `0x9e59c` |
| `RBMenuButton` | `-` | `effectTextImageView` | prop | ✅ | ✅ | `0x9e5d4` |
| `RBMenuButton` | `-` | `setEffectTextImageView:` | prop | ✅ | ✅ | `0x9e5e4` |
| `RBMenuNewsTickerView` | `-` | `initWithFrame:` |  | ✅ | ✅ | `0x9e670` |
| `RBMenuNewsTickerView` | `-` | `SetUpView` |  | ✅ | ✅ | `0x9e6f0` |
| `RBMenuNewsTickerView` | `-` | `setDuration:` |  | ✅ | ✅ | `0x9f150` |
| `RBMenuNewsTickerView` | `-` | `getPackID` |  | ✅ | ✅ | `0x9f160` |
| `RBMenuNewsTickerView` | `-` | `getCampaignID` |  | ✅ | ✅ | `0x9f16c` |
| `RBMenuNewsTickerView` | `-` | `getSequenceID` |  | ✅ | ✅ | `0x9f178` |
| `RBMenuNewsTickerView` | `-` | `getWebID` |  | ✅ | ✅ | `0x9f184` |
| `RBMenuNewsTickerView` | `-` | `setText:LINK:` |  | ✅ | ✅ | `0x9f190` |
| `RBMenuNewsTickerView` | `-` | `animationDidStop:finished:` |  | ✅ | ✅ | `0xa0730` |
| `RBMenuNewsTickerView` | `-` | `stopNews` |  | ✅ | ✅ | `0xa0a3c` |
| `RBMenuNewsTickerView` | `-` | `isLinkToStore` |  | ✅ | ✅ | `0xa0b7c` |
| `RBMenuNewsTickerView` | `-` | `toLink` |  | ✅ | ✅ | `0xa0b8c` |
| `RBMenuNewsTickerView` | `-` | `parseQuery:` |  | ✅ | ✅ | `0xa0cf4` |
| `RBMenuNewsTickerView` | `-` | `textBaseView` | prop | ✅ | ✅ | `0xa0dec` |
| `RBMenuNewsTickerView` | `-` | `setTextBaseView:` | prop | ✅ | ✅ | `0xa0dfc` |
| `RBMenuNewsTickerView` | `-` | `textView` | prop | ✅ | ✅ | `0xa0e34` |
| `RBMenuNewsTickerView` | `-` | `setTextView:` | prop | ✅ | ✅ | `0xa0e44` |
| `RBMenuNewsTickerView` | `-` | `font` | prop | ✅ | ✅ | `0xa0e7c` |
| `RBMenuNewsTickerView` | `-` | `setFont:` | prop | ✅ | ✅ | `0xa0e8c` |
| `RBMenuNewsTickerView` | `-` | `linkURL` | prop | ✅ | ✅ | `0xa0ec4` |
| `RBMenuNewsTickerView` | `-` | `setLinkURL:` | prop | ✅ | ✅ | `0xa0ed4` |
| `RBMenuNewsTickerView` | `-` | `packID` | prop | ✅ | ✅ | `0xa0f0c` |
| `RBMenuNewsTickerView` | `-` | `setPackID:` | prop | ✅ | ✅ | `0xa0f1c` |
| `RBMenuNewsTickerView` | `-` | `campaignID` | prop | ✅ | ✅ | `0xa0f54` |
| `RBMenuNewsTickerView` | `-` | `setCampaignID:` | prop | ✅ | ✅ | `0xa0f64` |
| `RBMenuNewsTickerView` | `-` | `sequenceID` | prop | ✅ | ✅ | `0xa0f9c` |
| `RBMenuNewsTickerView` | `-` | `setSequenceID:` | prop | ✅ | ✅ | `0xa0fac` |
| `RBMenuNewsTickerView` | `-` | `webID` | prop | ✅ | ✅ | `0xa0fe4` |
| `RBMenuNewsTickerView` | `-` | `setWebID:` | prop | ✅ | ✅ | `0xa0ff4` |
| `RBMenuNewsTickerView` | `-` | `target` | prop | ✅ | ✅ | `0xa102c` |
| `RBMenuNewsTickerView` | `-` | `setTarget:` | prop | ✅ | ✅ | `0xa103c` |
| `RBMenuNewsTickerView` | `-` | `baseDuration` | prop | ✅ | ✅ | `0xa1050` |
| `RBMenuNewsTickerView` | `-` | `setBaseDuration:` | prop | ✅ | ✅ | `0xa1060` |
| `RBMenuView` | `-` | `willRotate` |  | ✅ | ❌ | `0xa113c` |
| `RBMenuView` | `-` | `didRotate` |  | ✅ | ❌ | `0xa13d8` |
| `RBMenuView` | `-` | `setCurrentPageIndex:` | prop | ✅ | ✅ | `0xa1e08` |
| `RBMenuView` | `-` | `setMaxPage:` | prop | ✅ | ✅ | `0xa1f24` |
| `RBMenuView` | `-` | `setShowView:` | prop | ✅ | ✅ | `0xa200c` |
| `RBMenuView` | `-` | `initWithFrame:viewController:` |  | ✅ | ❌ | `0xa20a8` |
| `RBMenuView` | `-` | `dealloc` |  | ✅ | ❌ | `0xa220c` |
| `RBMenuView` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0xa22ec` |
| `RBMenuView` | `-` | `CreateView` |  | ✅ | ❌ | `0xa47f8` |
| `RBMenuView` | `-` | `reloadMusicData` |  | ✅ | ❌ | `0xa8e28` |
| `RBMenuView` | `-` | `createMusicList` |  | ✅ | ✅ | `0xa9108` |
| `RBMenuView` | `-` | `showAnimation` |  | ✅ | ❌ | `0xaa24c` |
| `RBMenuView` | `-` | `ReplayMusic` |  | ✅ | ❌ | `0xaaa20` |
| `RBMenuView` | `-` | `hideAnimation:` |  | ✅ | ❌ | `0xaaac8` |
| `RBMenuView` | `-` | `isShow` |  | ✅ | ✅ | `0xaafe4` |
| `RBMenuView` | `-` | `selectMusic:animated:` |  | ✅ | ❌ | `0xaaff0` |
| `RBMenuView` | `-` | `getRandamInt:max:` |  | ✅ | ❌ | `0xab350` |
| `RBMenuView` | `-` | `selectRandom:` |  | ✅ | ❌ | `0xab3c8` |
| `RBMenuView` | `-` | `releaseSelectMusic` |  | ✅ | ❌ | `0xab7ac` |
| `RBMenuView` | `-` | `RemoveStoreViewController` |  | ✅ | ❌ | `0xab854` |
| `RBMenuView` | `-` | `SelectSettingButton` |  | ✅ | ✅ | `0xab9d4` |
| `RBMenuView` | `-` | `hideSettingView` |  | ✅ | ❌ | `0xab9e0` |
| `RBMenuView` | `-` | `toggleSettingView` |  | ✅ | ❌ | `0xaba74` |
| `RBMenuView` | `-` | `showHowToView` |  | ✅ | ❌ | `0xabf94` |
| `RBMenuView` | `-` | `showCustomizeView` |  | ✅ | ❌ | `0xac0bc` |
| `RBMenuView` | `-` | `showThema` |  | ✅ | ❌ | `0xac274` |
| `RBMenuView` | `-` | `showSearchView` |  | ✅ | ❌ | `0xac348` |
| `RBMenuView` | `-` | `showCreditView` |  | ✅ | ❌ | `0xac564` |
| `RBMenuView` | `-` | `showNotificationPageView` |  | ✅ | ❌ | `0xac638` |
| `RBMenuView` | `-` | `showApplilinkView` |  | ✅ | ❌ | `0xac808` |
| `RBMenuView` | `-` | `showTermView` |  | ✅ | ❌ | `0xac8dc` |
| `RBMenuView` | `-` | `startBGEffect` |  | ✅ | ❌ | `0xacaac` |
| `RBMenuView` | `-` | `stopBGEffect` |  | ✅ | ❌ | `0xacc20` |
| `RBMenuView` | `-` | `SelectRankingButton` |  | ✅ | ❌ | `0xacd54` |
| `RBMenuView` | `-` | `SelectStoreButton` |  | ✅ | ❌ | `0xace3c` |
| `RBMenuView` | `-` | `StoreOpen` |  | ✅ | ❌ | `0xad948` |
| `RBMenuView` | `-` | `TouchNews:` |  | ✅ | ❌ | `0xade28` |
| `RBMenuView` | `-` | `didFinishedSendAgree` |  | ✅ | ✅ | `0xae3a4` |
| `RBMenuView` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0xae3b0` |
| `RBMenuView` | `-` | `downloaderError:` |  | ✅ | ❌ | `0xaee80` |
| `RBMenuView` | `-` | `startNews` |  | ✅ | ❌ | `0xaf0a0` |
| `RBMenuView` | `-` | `startNewsFromTimer` |  | ✅ | ❌ | `0xaf2a8` |
| `RBMenuView` | `-` | `showNextNewsText` |  | ✅ | ❌ | `0xaf350` |
| `RBMenuView` | `-` | `stopNews` |  | ✅ | ❌ | `0xaf7e8` |
| `RBMenuView` | `-` | `SetServerDateYear:Month:Day:Hour:Minute:Second:` |  | ✅ | ✅ | `0xaf8bc` |
| `RBMenuView` | `-` | `showInfomation` |  | ✅ | ❌ | `0xaf8c0` |
| `RBMenuView` | `-` | `createSearchDictionary` |  | ✅ | ❌ | `0xafa84` |
| `RBMenuView` | `-` | `showSearchBar` |  | ✅ | ❌ | `0xb0274` |
| `RBMenuView` | `-` | `setSearchBarNonActive` |  | ✅ | ❌ | `0xb0e18` |
| `RBMenuView` | `-` | `hideSearchBar` |  | ✅ | ❌ | `0xb0eac` |
| `RBMenuView` | `-` | `tapSearchMusicCancel` |  | ✅ | ❌ | `0xb16dc` |
| `RBMenuView` | `-` | `searchStringChanged:` |  | ✅ | ❌ | `0xb17b8` |
| `RBMenuView` | `-` | `getSearchArray:` |  | ✅ | ❌ | `0xb1b5c` |
| `RBMenuView` | `-` | `exeSearchPickUp` |  | ✅ | ❌ | `0xb1d14` |
| `RBMenuView` | `-` | `matchTitle:` |  | ✅ | ❌ | `0xb1e4c` |
| `RBMenuView` | `-` | `searchBar:textDidChange:` |  | ✅ | ❌ | `0xb217c` |
| `RBMenuView` | `-` | `handleLongPressGesture:` |  | ✅ | ❌ | `0xb21e4` |
| `RBMenuView` | `-` | `configureCell:` |  | ✅ | ❌ | `0xb2280` |
| `RBMenuView` | `-` | `scrollViewDidEndScroll:` |  | ✅ | ❌ | `0xb2fec` |
| `RBMenuView` | `-` | `numberOfSectionsInCollectionView:` |  | ✅ | ✅ | `0xb35f4` |
| `RBMenuView` | `-` | `collectionView:numberOfItemsInSection:` |  | ✅ | ✅ | `0xb35fc` |
| `RBMenuView` | `-` | `collectionView:cellForItemAtIndexPath:` |  | ✅ | ❌ | `0xb3664` |
| `RBMenuView` | `-` | `collectionView:didSelectItemAtIndexPath:` |  | ✅ | ❌ | `0xb3cdc` |
| `RBMenuView` | `-` | `scrollViewWillBeginDragging:` |  | ✅ | ✅ | `0xb42e8` |
| `RBMenuView` | `-` | `scrollViewDidEndDecelerating:` |  | ✅ | ✅ | `0xb4304` |
| `RBMenuView` | `-` | `scrollViewDidEndDragging:willDecelerate:` |  | ✅ | ❌ | `0xb4320` |
| `RBMenuView` | `-` | `scrollViewDidEndScrollingAnimation:` |  | ✅ | ✅ | `0xb4384` |
| `RBMenuView` | `-` | `willLayoutSubviews:` |  | ✅ | ✅ | `0xb43a0` |
| `RBMenuView` | `-` | `didLayoutSubviews:` |  | ✅ | ❌ | `0xb43a4` |
| `RBMenuView` | `-` | `touchesBeganFromRBCollectionView:withEvent:` |  | ✅ | ✅ | `0xb4740` |
| `RBMenuView` | `-` | `touchesEndedFromRBCollectionView:withEvent:` |  | ✅ | ❌ | `0xb4744` |
| `RBMenuView` | `-` | `showPushNotificationView` |  | ✅ | ❌ | `0xb4810` |
| `RBMenuView` | `-` | `actionFromPushNotificationView` |  | ✅ | ❌ | `0xb4ae8` |
| `RBMenuView` | `-` | `finishPushNotification` |  | ✅ | ❌ | `0xb4f2c` |
| `RBMenuView` | `-` | `preStartTutorial` |  | ✅ | ❌ | `0xb52a0` |
| `RBMenuView` | `-` | `startTutorial` |  | ✅ | ❌ | `0xb5678` |
| `RBMenuView` | `-` | `getTutorialMusicCell` |  | ✅ | ❌ | `0xb58c4` |
| `RBMenuView` | `-` | `getCollectionView` |  | ✅ | ✅ | `0xb5be8` |
| `RBMenuView` | `-` | `getSettingButton` |  | ✅ | ✅ | `0xb5bf4` |
| `RBMenuView` | `-` | `getStoreButton` |  | ✅ | ✅ | `0xb5c00` |
| `RBMenuView` | `-` | `setPastelForTutorialStart` |  | ✅ | ❌ | `0xb5c0c` |
| `RBMenuView` | `-` | `setPastelForTutorialEnd` |  | ✅ | ❌ | `0xb5cb0` |
| `RBMenuView` | `-` | `closeTutorial` |  | ✅ | ❌ | `0xb5d54` |
| `RBMenuView` | `-` | `closeCustomize` |  | ✅ | ❌ | `0xb5dfc` |
| `RBMenuView` | `-` | `playlistEditStart` |  | ✅ | ❌ | `0xb5ec4` |
| `RBMenuView` | `-` | `playlistEditFinish` |  | ✅ | ❌ | `0xb740c` |
| `RBMenuView` | `-` | `playlistAddDelButtonUpdate` |  | ✅ | ❌ | `0xb8618` |
| `RBMenuView` | `-` | `SelectPlaylistAddButton` |  | ✅ | ❌ | `0xb8754` |
| `RBMenuView` | `-` | `SelectPlaylistDelButton` |  | ✅ | ❌ | `0xb882c` |
| `RBMenuView` | `-` | `SelectPlaylistFinButton` |  | ✅ | ❌ | `0xb8aa4` |
| `RBMenuView` | `-` | `setCurrentMenuMode:` |  | ✅ | ✅ | `0xb8b14` |
| `RBMenuView` | `-` | `showPageSlider:` |  | ✅ | ❌ | `0xb8b90` |
| `RBMenuView` | `-` | `changePage:` |  | ✅ | ❌ | `0xb8e94` |
| `RBMenuView` | `-` | `touchMascot` |  | ✅ | ❌ | `0xb93c4` |
| `RBMenuView` | `-` | `debugAlphaLog` |  | ✅ | ❌ | `0xb95c8` |
| `RBMenuView` | `-` | `viewController` | prop | ✅ | ✅ | `0xb9740` |
| `RBMenuView` | `-` | `setViewController:` | prop | ✅ | ✅ | `0xb9760` |
| `RBMenuView` | `-` | `collectionView` | prop | ✅ | ✅ | `0xb9774` |
| `RBMenuView` | `-` | `setCollectionView:` | prop | ✅ | ✅ | `0xb9784` |
| `RBMenuView` | `-` | `selectedView` | prop | ✅ | ✅ | `0xb97bc` |
| `RBMenuView` | `-` | `setSelectedView:` | prop | ✅ | ✅ | `0xb97cc` |
| `RBMenuView` | `-` | `playListButton` | prop | ✅ | ✅ | `0xb9804` |
| `RBMenuView` | `-` | `setPlayListButton:` | prop | ✅ | ✅ | `0xb9814` |
| `RBMenuView` | `-` | `randomButton` | prop | ✅ | ✅ | `0xb984c` |
| `RBMenuView` | `-` | `setRandomButton:` | prop | ✅ | ✅ | `0xb985c` |
| `RBMenuView` | `-` | `randomInfoView` | prop | ✅ | ✅ | `0xb9894` |
| `RBMenuView` | `-` | `setRandomInfoView:` | prop | ✅ | ✅ | `0xb98a4` |
| `RBMenuView` | `-` | `playlistInfoView` | prop | ✅ | ✅ | `0xb98dc` |
| `RBMenuView` | `-` | `setPlaylistInfoView:` | prop | ✅ | ✅ | `0xb98ec` |
| `RBMenuView` | `-` | `playlistAddButton` | prop | ✅ | ✅ | `0xb9924` |
| `RBMenuView` | `-` | `setPlaylistAddButton:` | prop | ✅ | ✅ | `0xb9934` |
| `RBMenuView` | `-` | `playlistDelButton` | prop | ✅ | ✅ | `0xb996c` |
| `RBMenuView` | `-` | `setPlaylistDelButton:` | prop | ✅ | ✅ | `0xb997c` |
| `RBMenuView` | `-` | `settingView` | prop | ✅ | ✅ | `0xb99b4` |
| `RBMenuView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0xb99c4` |
| `RBMenuView` | `-` | `showView` | prop | ✅ | ✅ | `0xb99fc` |
| `RBMenuView` | `-` | `tutorialView` | prop | ✅ | ✅ | `0xb9a1c` |
| `RBMenuView` | `-` | `setTutorialView:` | prop | ✅ | ✅ | `0xb9a3c` |
| `RBMenuView` | `-` | `backgroundView` | prop | ✅ | ✅ | `0xb9a50` |
| `RBMenuView` | `-` | `setBackgroundView:` | prop | ✅ | ✅ | `0xb9a60` |
| `RBMenuView` | `-` | `headerView` | prop | ✅ | ✅ | `0xb9a98` |
| `RBMenuView` | `-` | `setHeaderView:` | prop | ✅ | ✅ | `0xb9aa8` |
| `RBMenuView` | `-` | `footerView` | prop | ✅ | ✅ | `0xb9ae0` |
| `RBMenuView` | `-` | `setFooterView:` | prop | ✅ | ✅ | `0xb9af0` |
| `RBMenuView` | `-` | `showed` | prop | ✅ | ✅ | `0xb9b28` |
| `RBMenuView` | `-` | `setShowed:` | prop | ✅ | ✅ | `0xb9b38` |
| `RBMenuView` | `-` | `pageLabel` | prop | ✅ | ✅ | `0xb9b48` |
| `RBMenuView` | `-` | `setPageLabel:` | prop | ✅ | ✅ | `0xb9b58` |
| `RBMenuView` | `-` | `backgroundScrollView` | prop | ✅ | ✅ | `0xb9b90` |
| `RBMenuView` | `-` | `setBackgroundScrollView:` | prop | ✅ | ✅ | `0xb9ba0` |
| `RBMenuView` | `-` | `backgroundImageCount` | prop | ✅ | ✅ | `0xb9bd8` |
| `RBMenuView` | `-` | `setBackgroundImageCount:` | prop | ✅ | ✅ | `0xb9be8` |
| `RBMenuView` | `-` | `backgroundCurrentPage` | prop | ✅ | ✅ | `0xb9bf8` |
| `RBMenuView` | `-` | `setBackgroundCurrentPage:` | prop | ✅ | ✅ | `0xb9c08` |
| `RBMenuView` | `-` | `musicCellHidden` | prop | ✅ | ✅ | `0xb9c18` |
| `RBMenuView` | `-` | `setMusicCellHidden:` | prop | ✅ | ✅ | `0xb9c28` |
| `RBMenuView` | `-` | `settingButton` | prop | ✅ | ✅ | `0xb9c38` |
| `RBMenuView` | `-` | `setSettingButton:` | prop | ✅ | ✅ | `0xb9c48` |
| `RBMenuView` | `-` | `rankButton` | prop | ✅ | ✅ | `0xb9c80` |
| `RBMenuView` | `-` | `setRankButton:` | prop | ✅ | ✅ | `0xb9c90` |
| `RBMenuView` | `-` | `storeButton` | prop | ✅ | ✅ | `0xb9cc8` |
| `RBMenuView` | `-` | `setStoreButton:` | prop | ✅ | ✅ | `0xb9cd8` |
| `RBMenuView` | `-` | `playlistFinButton` | prop | ✅ | ✅ | `0xb9d10` |
| `RBMenuView` | `-` | `setPlaylistFinButton:` | prop | ✅ | ✅ | `0xb9d20` |
| `RBMenuView` | `-` | `storeInfoView` | prop | ✅ | ✅ | `0xb9d58` |
| `RBMenuView` | `-` | `setStoreInfoView:` | prop | ✅ | ✅ | `0xb9d68` |
| `RBMenuView` | `-` | `coverView` | prop | ✅ | ✅ | `0xb9da0` |
| `RBMenuView` | `-` | `setCoverView:` | prop | ✅ | ✅ | `0xb9db0` |
| `RBMenuView` | `-` | `showAnimationTimer` | prop | ✅ | ✅ | `0xb9de8` |
| `RBMenuView` | `-` | `setShowAnimationTimer:` | prop | ✅ | ✅ | `0xb9df8` |
| `RBMenuView` | `-` | `mapViewController` | prop | ✅ | ✅ | `0xb9e30` |
| `RBMenuView` | `-` | `setMapViewController:` | prop | ✅ | ✅ | `0xb9e40` |
| `RBMenuView` | `-` | `webViewController` | prop | ✅ | ✅ | `0xb9e78` |
| `RBMenuView` | `-` | `setWebViewController:` | prop | ✅ | ✅ | `0xb9e88` |
| `RBMenuView` | `-` | `termViewController` | prop | ✅ | ✅ | `0xb9ec0` |
| `RBMenuView` | `-` | `setTermViewController:` | prop | ✅ | ✅ | `0xb9ed0` |
| `RBMenuView` | `-` | `newsView` | prop | ✅ | ✅ | `0xb9f08` |
| `RBMenuView` | `-` | `setNewsView:` | prop | ✅ | ✅ | `0xb9f18` |
| `RBMenuView` | `-` | `newsDownloader` | prop | ✅ | ✅ | `0xb9f50` |
| `RBMenuView` | `-` | `setNewsDownloader:` | prop | ✅ | ✅ | `0xb9f60` |
| `RBMenuView` | `-` | `storeUpdateTime` | prop | ✅ | ✅ | `0xb9f98` |
| `RBMenuView` | `-` | `setStoreUpdateTime:` | prop | ✅ | ✅ | `0xb9fa8` |
| `RBMenuView` | `-` | `newsInfoText` | prop | ✅ | ✅ | `0xb9fe0` |
| `RBMenuView` | `-` | `setNewsInfoText:` | prop | ✅ | ✅ | `0xb9ff0` |
| `RBMenuView` | `-` | `newsInfoIndex` | prop | ✅ | ✅ | `0xba028` |
| `RBMenuView` | `-` | `setNewsInfoIndex:` | prop | ✅ | ✅ | `0xba038` |
| `RBMenuView` | `-` | `newsBannerTimer` | prop | ✅ | ✅ | `0xba048` |
| `RBMenuView` | `-` | `setNewsBannerTimer:` | prop | ✅ | ✅ | `0xba058` |
| `RBMenuView` | `-` | `newsGetTime` | prop | ✅ | ✅ | `0xba090` |
| `RBMenuView` | `-` | `setNewsGetTime:` | prop | ✅ | ✅ | `0xba0a0` |
| `RBMenuView` | `-` | `storeViewController` | prop | ✅ | ✅ | `0xba0d8` |
| `RBMenuView` | `-` | `setStoreViewController:` | prop | ✅ | ✅ | `0xba0e8` |
| `RBMenuView` | `-` | `termDownloader` | prop | ✅ | ✅ | `0xba120` |
| `RBMenuView` | `-` | `setTermDownloader:` | prop | ✅ | ✅ | `0xba130` |
| `RBMenuView` | `-` | `battleMusicSelect` | prop | ✅ | ✅ | `0xba168` |
| `RBMenuView` | `-` | `setBattleMusicSelect:` | prop | ✅ | ✅ | `0xba178` |
| `RBMenuView` | `-` | `musicList` | prop | ✅ | ✅ | `0xba188` |
| `RBMenuView` | `-` | `setMusicList:` | prop | ✅ | ✅ | `0xba198` |
| `RBMenuView` | `-` | `currentPageIndex` | prop | ✅ | ✅ | `0xba1d0` |
| `RBMenuView` | `-` | `maxPage` | prop | ✅ | ✅ | `0xba1e0` |
| `RBMenuView` | `-` | `layout` | prop | ✅ | ✅ | `0xba1f0` |
| `RBMenuView` | `-` | `setLayout:` | prop | ✅ | ✅ | `0xba200` |
| `RBMenuView` | `-` | `prevIndex` | prop | ✅ | ✅ | `0xba238` |
| `RBMenuView` | `-` | `setPrevIndex:` | prop | ✅ | ✅ | `0xba248` |
| `RBMenuView` | `-` | `mascot` | prop | ✅ | ✅ | `0xba258` |
| `RBMenuView` | `-` | `setMascot:` | prop | ✅ | ✅ | `0xba268` |
| `RBMenuView` | `-` | `bgEffectView` | prop | ✅ | ✅ | `0xba2a0` |
| `RBMenuView` | `-` | `setBgEffectView:` | prop | ✅ | ✅ | `0xba2b0` |
| `RBMenuView` | `-` | `searchBar` | prop | ✅ | ✅ | `0xba2e8` |
| `RBMenuView` | `-` | `setSearchBar:` | prop | ✅ | ✅ | `0xba2f8` |
| `RBMenuView` | `-` | `searchCancelButton` | prop | ✅ | ✅ | `0xba330` |
| `RBMenuView` | `-` | `setSearchCancelButton:` | prop | ✅ | ✅ | `0xba340` |
| `RBMenuView` | `-` | `backUpString` | prop | ✅ | ✅ | `0xba378` |
| `RBMenuView` | `-` | `setBackUpString:` | prop | ✅ | ✅ | `0xba388` |
| `RBMenuView` | `-` | `searchArray` | prop | ✅ | ✅ | `0xba3c0` |
| `RBMenuView` | `-` | `setSearchArray:` | prop | ✅ | ✅ | `0xba3d0` |
| `RBMenuView` | `-` | `searchDictionary` | prop | ✅ | ✅ | `0xba408` |
| `RBMenuView` | `-` | `setSearchDictionary:` | prop | ✅ | ✅ | `0xba418` |
| `RBMenuView` | `-` | `expandDictionary` | prop | ✅ | ✅ | `0xba450` |
| `RBMenuView` | `-` | `setExpandDictionary:` | prop | ✅ | ✅ | `0xba460` |
| `RBMenuView` | `-` | `searchMascotImages` | prop | ✅ | ✅ | `0xba498` |
| `RBMenuView` | `-` | `setSearchMascotImages:` | prop | ✅ | ✅ | `0xba4a8` |
| `RBMenuView` | `-` | `searchMascot` | prop | ✅ | ✅ | `0xba4e0` |
| `RBMenuView` | `-` | `setSearchMascot:` | prop | ✅ | ✅ | `0xba4f0` |
| `RBMenuView` | `-` | `searchPastelPosBaseY` | prop | ✅ | ✅ | `0xba528` |
| `RBMenuView` | `-` | `setSearchPastelPosBaseY:` | prop | ✅ | ✅ | `0xba538` |
| `RBMenuView` | `-` | `pushNotificationView` | prop | ✅ | ✅ | `0xba548` |
| `RBMenuView` | `-` | `setPushNotificationView:` | prop | ✅ | ✅ | `0xba558` |
| `RBMenuView` | `-` | `pageSlider` | prop | ✅ | ✅ | `0xba590` |
| `RBMenuView` | `-` | `setPageSlider:` | prop | ✅ | ✅ | `0xba5b0` |
| `RBMenuView` | `-` | `playlistEditSet` | prop | ✅ | ✅ | `0xba5c4` |
| `RBMenuView` | `-` | `setPlaylistEditSet:` | prop | ✅ | ✅ | `0xba5d4` |
| `RBMenuView` | `-` | `playListEditMode` | prop | ✅ | ✅ | `0xba60c` |
| `RBMenuView` | `-` | `setPlayListEditMode:` | prop | ✅ | ✅ | `0xba61c` |
| `RBMusicCell` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xbaa1c` |
| `RBMusicCell` | `-` | `prepareForReuse` |  | ✅ | ❌ | `0xbaeec` |
| `RBMusicCell` | `-` | `SetupView` |  | ✅ | ❌ | `0xbb064` |
| `RBMusicCell` | `-` | `updateScoreData:` |  | ✅ | ❌ | `0xbc94c` |
| `RBMusicCell` | `-` | `updateScoreData:spData:` |  | ✅ | ❌ | `0xbd2b0` |
| `RBMusicCell` | `-` | `show` |  | ✅ | ❌ | `0xbdd48` |
| `RBMusicCell` | `-` | `hide` |  | ✅ | ❌ | `0xbde2c` |
| `RBMusicCell` | `-` | `menuView` | prop | ✅ | ✅ | `0xbdf64` |
| `RBMusicCell` | `-` | `setMenuView:` | prop | ✅ | ✅ | `0xbdf84` |
| `RBMusicCell` | `-` | `musicData` | prop | ✅ | ✅ | `0xbdf98` |
| `RBMusicCell` | `-` | `setMusicData:` | prop | ✅ | ✅ | `0xbdfa8` |
| `RBMusicCell` | `-` | `artworkImageView` | prop | ✅ | ✅ | `0xbdfe0` |
| `RBMusicCell` | `-` | `setArtworkImageView:` | prop | ✅ | ✅ | `0xbdff0` |
| `RBMusicCell` | `-` | `titleLabel` | prop | ✅ | ✅ | `0xbe028` |
| `RBMusicCell` | `-` | `setTitleLabel:` | prop | ✅ | ✅ | `0xbe038` |
| `RBMusicCell` | `-` | `artistLabel` | prop | ✅ | ✅ | `0xbe070` |
| `RBMusicCell` | `-` | `setArtistLabel:` | prop | ✅ | ✅ | `0xbe080` |
| `RBMusicCell` | `-` | `addButton` | prop | ✅ | ✅ | `0xbe0b8` |
| `RBMusicCell` | `-` | `setAddButton:` | prop | ✅ | ✅ | `0xbe0c8` |
| `RBMusicCell` | `-` | `removeButton` | prop | ✅ | ✅ | `0xbe100` |
| `RBMusicCell` | `-` | `setRemoveButton:` | prop | ✅ | ✅ | `0xbe110` |
| `RBMusicCell` | `-` | `bgImageLayer` | prop | ✅ | ✅ | `0xbe148` |
| `RBMusicCell` | `-` | `setBgImageLayer:` | prop | ✅ | ✅ | `0xbe158` |
| `RBMusicCell` | `-` | `rankBaseImageLayers` | prop | ✅ | ✅ | `0xbe190` |
| `RBMusicCell` | `-` | `setRankBaseImageLayers:` | prop | ✅ | ✅ | `0xbe1a0` |
| `RBMusicCell` | `-` | `rankImageLayers` | prop | ✅ | ✅ | `0xbe1d8` |
| `RBMusicCell` | `-` | `setRankImageLayers:` | prop | ✅ | ✅ | `0xbe1e8` |
| `RBMusicCell` | `-` | `clearBaseImageLayers` | prop | ✅ | ✅ | `0xbe220` |
| `RBMusicCell` | `-` | `setClearBaseImageLayers:` | prop | ✅ | ✅ | `0xbe230` |
| `RBMusicCell` | `-` | `clearImageLayers` | prop | ✅ | ✅ | `0xbe268` |
| `RBMusicCell` | `-` | `setClearImageLayers:` | prop | ✅ | ✅ | `0xbe278` |
| `RBMusicCell` | `-` | `bgType` | prop | ✅ | ✅ | `0xbe2b0` |
| `RBMusicCell` | `-` | `setBgType:` | prop | ✅ | ✅ | `0xbe2c0` |
| `RBNewsHUDView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xbe3d4` |
| `RBNewsHUDView` | `-` | `setupView` |  | ✅ | ❌ | `0xbe448` |
| `RBNewsHUDView` | `-` | `showAnimation` |  | ✅ | ❌ | `0xbe5f0` |
| `RBNewsHUDView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0xbe73c` |
| `RBNewsHUDView` | `-` | `tapped` |  | ✅ | ✅ | `0xbe8a8` |
| `RBNewsHUDView` | `-` | `showImage:InfomationID:` |  | ✅ | ❌ | `0xbe8b4` |
| `RBNewsHUDView` | `-` | `imageDownloader:didLoad:` |  | ✅ | ❌ | `0xbe99c` |
| `RBNewsHUDView` | `-` | `imageDownloaderDidFail:didLoad:` |  | ✅ | ❌ | `0xbeff8` |
| `RBStoreExtendNoteList` | `+` | `storeCountry` |  | ✅ | ❌ | `0xbf024` |
| `RBStoreExtendNoteList` | `-` | `init` |  | ✅ | ❌ | `0xbf064` |
| `RBStoreExtendNoteList` | `-` | `startFetching` |  | ✅ | ❌ | `0xbf1a0` |
| `RBStoreExtendNoteList` | `-` | `cancelFetching` |  | ✅ | ❌ | `0xbf338` |
| `RBStoreExtendNoteList` | `-` | `isFetching` |  | ✅ | ❌ | `0xbf488` |
| `RBStoreExtendNoteList` | `-` | `extendMusicInfos` |  | ✅ | ✅ | `0xbf50c` |
| `RBStoreExtendNoteList` | `-` | `extendNoteProductIDList` |  | ✅ | ✅ | `0xbf518` |
| `RBStoreExtendNoteList` | `-` | `getExtendNoteInfoWithProductID:` |  | ✅ | ❌ | `0xbf524` |
| `RBStoreExtendNoteList` | `-` | `addExtendNoteInfoFromProductID:` |  | ✅ | ❌ | `0xbf684` |
| `RBStoreExtendNoteList` | `-` | `updateExtendNoteInfo:SKProductsResponse:` |  | ✅ | ❌ | `0xbf768` |
| `RBStoreExtendNoteList` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0xbfe24` |
| `RBStoreExtendNoteList` | `-` | `downloaderError:` |  | ✅ | ❌ | `0xc0768` |
| `RBStoreExtendNoteList` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0xc07f0` |
| `RBStoreExtendNoteList` | `-` | `optionalProductsRequest` |  | ✅ | ❌ | `0xc07f4` |
| `RBStoreExtendNoteList` | `-` | `productsRequest:didReceiveResponse:` |  | ✅ | ❌ | `0xc0b20` |
| `RBStoreExtendNoteList` | `-` | `request:didFailWithError:` |  | ✅ | ❌ | `0xc0f64` |
| `RBStoreExtendNoteList` | `-` | `dealloc` |  | ✅ | ❌ | `0xc1014` |
| `RBStoreExtendNoteList` | `-` | `delegate` | prop | ✅ | ✅ | `0xc11a4` |
| `RBStoreExtendNoteList` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0xc11c4` |
| `RBStoreExtendNoteList` | `-` | `extendNoteListContinued` | prop | ✅ | ✅ | `0xc11d8` |
| `RBStoreExtendNoteList` | `-` | `setExtendNoteListContinued:` | prop | ✅ | ✅ | `0xc11e8` |
| `RBStoreExtendNoteList` | `-` | `arrayExtendNoteInfo` | prop | ✅ | ✅ | `0xc11f8` |
| `RBStoreExtendNoteList` | `-` | `setArrayExtendNoteInfo:` | prop | ✅ | ✅ | `0xc1208` |
| `RBStoreExtendNoteList` | `-` | `listProductID` | prop | ✅ | ✅ | `0xc1240` |
| `RBStoreExtendNoteList` | `-` | `setListProductID:` | prop | ✅ | ✅ | `0xc1250` |
| `RBStoreExtendNoteList` | `-` | `extendNotelistDownloader` | prop | ✅ | ✅ | `0xc1288` |
| `RBStoreExtendNoteList` | `-` | `setExtendNotelistDownloader:` | prop | ✅ | ✅ | `0xc1298` |
| `RBStoreExtendNoteList` | `-` | `tempExtendNoteList` | prop | ✅ | ✅ | `0xc12d0` |
| `RBStoreExtendNoteList` | `-` | `setTempExtendNoteList:` | prop | ✅ | ✅ | `0xc12e0` |
| `RBStoreExtendNoteList` | `-` | `productsRequest` | prop | ✅ | ✅ | `0xc1318` |
| `RBStoreExtendNoteList` | `-` | `setProductsRequest:` | prop | ✅ | ✅ | `0xc1328` |
| `RBStoreExtendNoteList` | `-` | `fetchedExtendNoteNum` | prop | ✅ | ✅ | `0xc1360` |
| `RBStoreExtendNoteList` | `-` | `setFetchedExtendNoteNum:` | prop | ✅ | ✅ | `0xc1370` |
| `RBStoreExtendNoteList` | `-` | `isOptionalProductRequest` | prop | ✅ | ✅ | `0xc1380` |
| `RBStoreExtendNoteList` | `-` | `setIsOptionalProductRequest:` | prop | ✅ | ✅ | `0xc1390` |
| `RBMusicARView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xc142c` |
| `RBMusicARView` | `-` | `UpdateScore:` |  | ✅ | ❌ | `0xc1690` |
| `RBMusicARView` | `-` | `scoreImageArray` | prop | ✅ | ✅ | `0xc2034` |
| `RBMusicARView` | `-` | `setScoreImageArray:` | prop | ✅ | ✅ | `0xc2044` |
| `RBMusicARView` | `-` | `numHeightL` | prop | ✅ | ✅ | `0xc207c` |
| `RBMusicARView` | `-` | `setNumHeightL:` | prop | ✅ | ✅ | `0xc208c` |
| `RBMusicARView` | `-` | `numHeightS` | prop | ✅ | ✅ | `0xc209c` |
| `RBMusicARView` | `-` | `setNumHeightS:` | prop | ✅ | ✅ | `0xc20ac` |
| `RBMusicColorBar` | `-` | `initWithFrame:MusicSelectedColor:` |  | ✅ | ❌ | `0xc20d0` |
| `RBMusicColorBar` | `-` | `SetupView` |  | ✅ | ❌ | `0xc21b8` |
| `RBMusicColorBar` | `-` | `SetBar:` |  | ✅ | ❌ | `0xc27c8` |
| `RBMusicColorBar` | `-` | `setAlphaValue:` | prop | ✅ | ✅ | `0xc2968` |
| `RBMusicColorBar` | `-` | `alphaValue` | prop | ✅ | ❌ | `0xc2974` |
| `RBMusicColorBar` | `-` | `tap:` |  | ✅ | ❌ | `0xc2994` |
| `RBMusicColorBar` | `-` | `pan:` |  | ✅ | ❌ | `0xc2a88` |
| `RBMusicColorBar` | `-` | `musicSelectedColor` | prop | ✅ | ✅ | `0xc2b94` |
| `RBMusicColorBar` | `-` | `setMusicSelectedColor:` | prop | ✅ | ✅ | `0xc2bb4` |
| `RBMusicColorBar` | `-` | `gripView` | prop | ✅ | ✅ | `0xc2bc8` |
| `RBMusicColorBar` | `-` | `setGripView:` | prop | ✅ | ✅ | `0xc2bd8` |
| `RBMusicColorBar` | `-` | `baseView` | prop | ✅ | ✅ | `0xc2c10` |
| `RBMusicColorBar` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0xc2c20` |
| `RBMusicColorBar` | `-` | `sliderValue` | prop | ✅ | ✅ | `0xc2c58` |
| `RBMusicColorBar` | `-` | `setSliderValue:` | prop | ✅ | ✅ | `0xc2c68` |
| `RBMusicColorView` | `-` | `initWithFrame:MusicSelectedBase:` |  | ✅ | ❌ | `0xc2cc8` |
| `RBMusicColorView` | `-` | `SetupView` |  | ✅ | ❌ | `0xc2efc` |
| `RBMusicColorView` | `-` | `ShowSelect` |  | ✅ | ❌ | `0xc41e4` |
| `RBMusicColorView` | `-` | `selectAlphaButton:` |  | ✅ | ❌ | `0xc5230` |
| `RBMusicColorView` | `-` | `selectColorButton:` |  | ✅ | ❌ | `0xc5c5c` |
| `RBMusicColorView` | `-` | `setRivalAlpha:` | prop | ✅ | ✅ | `0xc5f10` |
| `RBMusicColorView` | `-` | `SelectButton:` |  | ✅ | ❌ | `0xc62c8` |
| `RBMusicColorView` | `-` | `musicSelectedBase` | prop | ✅ | ✅ | `0xc6368` |
| `RBMusicColorView` | `-` | `setMusicSelectedBase:` | prop | ✅ | ✅ | `0xc6388` |
| `RBMusicColorView` | `-` | `color` | prop | ✅ | ✅ | `0xc639c` |
| `RBMusicColorView` | `-` | `setColor:` | prop | ✅ | ✅ | `0xc63ac` |
| `RBMusicColorView` | `-` | `rivalAlpha` | prop | ✅ | ✅ | `0xc63bc` |
| `RBMusicColorView` | `-` | `buttons` | prop | ✅ | ✅ | `0xc63cc` |
| `RBMusicColorView` | `-` | `setButtons:` | prop | ✅ | ✅ | `0xc63dc` |
| `RBMusicColorView` | `-` | `buttonImages` | prop | ✅ | ✅ | `0xc6414` |
| `RBMusicColorView` | `-` | `setButtonImages:` | prop | ✅ | ✅ | `0xc6424` |
| `RBMusicColorView` | `-` | `buttonImageBases` | prop | ✅ | ✅ | `0xc645c` |
| `RBMusicColorView` | `-` | `setButtonImageBases:` | prop | ✅ | ✅ | `0xc646c` |
| `RBMusicColorView` | `-` | `selectedImages` | prop | ✅ | ✅ | `0xc64a4` |
| `RBMusicColorView` | `-` | `setSelectedImages:` | prop | ✅ | ✅ | `0xc64b4` |
| `RBMusicColorView` | `-` | `youImages` | prop | ✅ | ✅ | `0xc64ec` |
| `RBMusicColorView` | `-` | `setYouImages:` | prop | ✅ | ✅ | `0xc64fc` |
| `RBMusicColorView` | `-` | `rivalImages` | prop | ✅ | ✅ | `0xc6534` |
| `RBMusicColorView` | `-` | `setRivalImages:` | prop | ✅ | ✅ | `0xc6544` |
| `RBMusicColorView` | `-` | `alphaChangeImages` | prop | ✅ | ✅ | `0xc657c` |
| `RBMusicColorView` | `-` | `setAlphaChangeImages:` | prop | ✅ | ✅ | `0xc658c` |
| `RBMusicColorView` | `-` | `alphaChangeImageBases` | prop | ✅ | ✅ | `0xc65c4` |
| `RBMusicColorView` | `-` | `setAlphaChangeImageBases:` | prop | ✅ | ✅ | `0xc65d4` |
| `RBMusicColorView` | `-` | `colorBar` | prop | ✅ | ✅ | `0xc660c` |
| `RBMusicColorView` | `-` | `setColorBar:` | prop | ✅ | ✅ | `0xc661c` |
| `RBMusicColorView` | `-` | `toAlphaButton` | prop | ✅ | ✅ | `0xc6654` |
| `RBMusicColorView` | `-` | `setToAlphaButton:` | prop | ✅ | ✅ | `0xc6664` |
| `RBMusicColorView` | `-` | `toColorButton` | prop | ✅ | ✅ | `0xc669c` |
| `RBMusicColorView` | `-` | `setToColorButton:` | prop | ✅ | ✅ | `0xc66ac` |
| `RBMusicColorView` | `-` | `firstInfo` | prop | ✅ | ✅ | `0xc66e4` |
| `RBMusicColorView` | `-` | `setFirstInfo:` | prop | ✅ | ✅ | `0xc66f4` |
| `RBMusicColorView` | `-` | `layoutOffset` | prop | ✅ | ✅ | `0xc672c` |
| `RBMusicColorView` | `-` | `setLayoutOffset:` | prop | ✅ | ✅ | `0xc673c` |
| `RBMusicCPUView` | `-` | `initWithFrame:MusicSelectedBase:` |  | ✅ | ❌ | `0xc6864` |
| `RBMusicCPUView` | `-` | `dealloc` |  | ❌ | ✅ | `0xc6a50` |
| `RBMusicCPUView` | `-` | `SetupView` |  | ✅ | ❌ | `0xc6a84` |
| `RBMusicCPUView` | `-` | `tap:` |  | ✅ | ❌ | `0xc7410` |
| `RBMusicCPUView` | `-` | `SelectLevel:` |  | ✅ | ❌ | `0xc7604` |
| `RBMusicCPUView` | `-` | `level` | prop | ✅ | ✅ | `0xc78b4` |
| `RBMusicCPUView` | `-` | `setLevel:` | prop | ✅ | ✅ | `0xc78c4` |
| `RBMusicCPUView` | `-` | `musicSelectedBase` | prop | ✅ | ✅ | `0xc78d4` |
| `RBMusicCPUView` | `-` | `setMusicSelectedBase:` | prop | ✅ | ✅ | `0xc78f4` |
| `RBMusicCPUView` | `-` | `selectedImage` | prop | ✅ | ✅ | `0xc7908` |
| `RBMusicCPUView` | `-` | `setSelectedImage:` | prop | ✅ | ✅ | `0xc7918` |
| `RBMusicCPUView` | `-` | `sliderView` | prop | ✅ | ✅ | `0xc7950` |
| `RBMusicCPUView` | `-` | `setSliderView:` | prop | ✅ | ✅ | `0xc7960` |
| `RBMusicCPUView` | `-` | `barBase` | prop | ✅ | ✅ | `0xc7998` |
| `RBMusicCPUView` | `-` | `setBarBase:` | prop | ✅ | ✅ | `0xc79a8` |
| `RBMusicCPUView` | `-` | `sliderType` | prop | ✅ | ✅ | `0xc79e0` |
| `RBMusicCPUView` | `-` | `setSliderType:` | prop | ✅ | ✅ | `0xc79f0` |
| `RBMusicDifficultyView` | `-` | `initWithFrame:MusicSelectedBase:` |  | ✅ | ❌ | `0xc7a64` |
| `RBMusicDifficultyView` | `-` | `SetupView` |  | ✅ | ❌ | `0xc7c68` |
| `RBMusicDifficultyView` | `-` | `CreateButton:Position:Number:` |  | ✅ | ❌ | `0xc8240` |
| `RBMusicDifficultyView` | `-` | `ShowSelectDifficulty` |  | ✅ | ❌ | `0xc8b7c` |
| `RBMusicDifficultyView` | `-` | `SetFlashEffectDuration:Start:End:` |  | ✅ | ✅ | `0xc8e8c` |
| `RBMusicDifficultyView` | `-` | `SelectDifficultyButton:` |  | ✅ | ❌ | `0xc8e90` |
| `RBMusicDifficultyView` | `-` | `setEnableButton:` |  | ✅ | ❌ | `0xc9000` |
| `RBMusicDifficultyView` | `-` | `getDifficultyButton:` |  | ✅ | ❌ | `0xc911c` |
| `RBMusicDifficultyView` | `-` | `difficulty` | prop | ✅ | ✅ | `0xc918c` |
| `RBMusicDifficultyView` | `-` | `setDifficulty:` | prop | ✅ | ✅ | `0xc919c` |
| `RBMusicDifficultyView` | `-` | `musicSelectedBase` | prop | ✅ | ✅ | `0xc91ac` |
| `RBMusicDifficultyView` | `-` | `setMusicSelectedBase:` | prop | ✅ | ✅ | `0xc91cc` |
| `RBMusicDifficultyView` | `-` | `difficultySelectedImages` | prop | ✅ | ✅ | `0xc91e0` |
| `RBMusicDifficultyView` | `-` | `setDifficultySelectedImages:` | prop | ✅ | ✅ | `0xc91f0` |
| `RBMusicDifficultyView` | `-` | `difficultyNumberImages` | prop | ✅ | ✅ | `0xc9228` |
| `RBMusicDifficultyView` | `-` | `setDifficultyNumberImages:` | prop | ✅ | ✅ | `0xc9238` |
| `RBMusicDifficultyView` | `-` | `difficultyButtons` | prop | ✅ | ✅ | `0xc9270` |
| `RBMusicDifficultyView` | `-` | `setDifficultyButtons:` | prop | ✅ | ✅ | `0xc9280` |
| `RBMusicDifficultyView` | `-` | `layoutOffset` | prop | ✅ | ✅ | `0xc92b8` |
| `RBMusicDifficultyView` | `-` | `setLayoutOffset:` | prop | ✅ | ✅ | `0xc92c8` |
| `RBMusicFirstInfoView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xc9370` |
| `RBMusicFirstInfoView` | `-` | `SetupView` |  | ✅ | ❌ | `0xc93e4` |
| `RBMusicFirstInfoView` | `-` | `tap:` |  | ✅ | ❌ | `0xc9bf4` |
| `RBMusicFirstInfoView` | `-` | `showAnimation` |  | ✅ | ❌ | `0xc9c10` |
| `RBMusicFirstInfoView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0xc9d78` |
| `RBMusicScoreView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xc9ee8` |
| `RBMusicScoreView` | `-` | `UpdateScore:` |  | ✅ | ❌ | `0xca138` |
| `RBMusicScoreView` | `-` | `grade` | prop | ✅ | ✅ | `0xca79c` |
| `RBMusicScoreView` | `-` | `setGrade:` | prop | ✅ | ✅ | `0xca7ac` |
| `RBMusicScoreView` | `-` | `scoreImageViews` | prop | ✅ | ✅ | `0xca7bc` |
| `RBMusicScoreView` | `-` | `setScoreImageViews:` | prop | ✅ | ✅ | `0xca7cc` |
| `RBMusicView` | `-` | `setMusicData:` | prop | ✅ | ❌ | `0xca818` |
| `RBMusicView` | `-` | `initWithFrame:MusicData:` |  | ✅ | ❌ | `0xcbbac` |
| `RBMusicView` | `-` | `dealloc` |  | ✅ | ❌ | `0xcbd84` |
| `RBMusicView` | `-` | `setBpm:Point:` |  | ✅ | ❌ | `0xcbe70` |
| `RBMusicView` | `-` | `SetupView` |  | ✅ | ❌ | `0xcc078` |
| `RBMusicView` | `-` | `switchWithDifficulty:` |  | ✅ | ❌ | `0xd0f3c` |
| `RBMusicView` | `-` | `SetUpLineView` |  | ✅ | ❌ | `0xd2764` |
| `RBMusicView` | `-` | `SetRankView:` |  | ✅ | ✅ | `0xd2ddc` |
| `RBMusicView` | `-` | `ShowSelectDifficulty` |  | ✅ | ❌ | `0xd2fd8` |
| `RBMusicView` | `-` | `ShowSettingView:` |  | ✅ | ❌ | `0xd33a8` |
| `RBMusicView` | `-` | `SetSettingButtonSelected:` |  | ✅ | ✅ | `0xd37a8` |
| `RBMusicView` | `-` | `SetGhostView:` |  | ✅ | ✅ | `0xd397c` |
| `RBMusicView` | `-` | `updateDecideButton` |  | ✅ | ✅ | `0xd3b50` |
| `RBMusicView` | `-` | `SelectDoublePlayButton` |  | ✅ | ✅ | `0xd3fac` |
| `RBMusicView` | `-` | `SelectDecideButton` |  | ✅ | ✅ | `0xd4028` |
| `RBMusicView` | `-` | `SelectHistory` |  | ✅ | ✅ | `0xd44d0` |
| `RBMusicView` | `-` | `SelectWhitePastelButton` |  | ✅ | ✅ | `0xd4620` |
| `RBMusicView` | `-` | `SelectBlackPastelButton` |  | ✅ | ✅ | `0xd4694` |
| `RBMusicView` | `-` | `playGame` |  | ✅ | ❌ | `0xd4708` |
| `RBMusicView` | `-` | `playTutorialGame` |  | ✅ | ❌ | `0xd4c5c` |
| `RBMusicView` | `-` | `SelectItunes` |  | ✅ | ✅ | `0xd4f54` |
| `RBMusicView` | `-` | `showAnimation:` |  | ✅ | ❌ | `0xd50a0` |
| `RBMusicView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0xd5680` |
| `RBMusicView` | `-` | `ReplayMusic` |  | ✅ | ❌ | `0xd5ca4` |
| `RBMusicView` | `-` | `firstInfoAnimation` |  | ✅ | ❌ | `0xd5d4c` |
| `RBMusicView` | `-` | `firstInfoAnimationCheck` |  | ✅ | ❌ | `0xd5f38` |
| `RBMusicView` | `-` | `selectPage:` |  | ✅ | ❌ | `0xd60d4` |
| `RBMusicView` | `-` | `firstInfoScrollEnd` |  | ✅ | ❌ | `0xd61b0` |
| `RBMusicView` | `-` | `setFirstScrollAnimation` |  | ✅ | ❌ | `0xd61e0` |
| `RBMusicView` | `-` | `setScrollable:` |  | ✅ | ❌ | `0xd65dc` |
| `RBMusicView` | `-` | `setEnableButton:` |  | ✅ | ❌ | `0xd6684` |
| `RBMusicView` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0xd66e0` |
| `RBMusicView` | `-` | `getDecideButton` |  | ✅ | ✅ | `0xd6b1c` |
| `RBMusicView` | `-` | `getDoubleButton` |  | ✅ | ❌ | `0xd6b28` |
| `RBMusicView` | `-` | `getDifficultyButton:` |  | ✅ | ❌ | `0xd6b8c` |
| `RBMusicView` | `-` | `tapGesture:` |  | ✅ | ❌ | `0xd6bfc` |
| `RBMusicView` | `-` | `gestureRecognizer:shouldReceiveTouch:` |  | ✅ | ❌ | `0xd6cec` |
| `RBMusicView` | `-` | `musicMenuView` | prop | ✅ | ✅ | `0xd6e38` |
| `RBMusicView` | `-` | `setMusicMenuView:` | prop | ✅ | ✅ | `0xd6e58` |
| `RBMusicView` | `-` | `musicData` | prop | ✅ | ✅ | `0xd6e6c` |
| `RBMusicView` | `-` | `isRandom` | prop | ✅ | ✅ | `0xd6e7c` |
| `RBMusicView` | `-` | `setIsRandom:` | prop | ✅ | ✅ | `0xd6e8c` |
| `RBMusicView` | `-` | `randomButton` | prop | ✅ | ✅ | `0xd6e9c` |
| `RBMusicView` | `-` | `setRandomButton:` | prop | ✅ | ✅ | `0xd6eac` |
| `RBMusicView` | `-` | `historyButton` | prop | ✅ | ✅ | `0xd6ee4` |
| `RBMusicView` | `-` | `setHistoryButton:` | prop | ✅ | ✅ | `0xd6ef4` |
| `RBMusicView` | `-` | `extMusicData` | prop | ✅ | ✅ | `0xd6f2c` |
| `RBMusicView` | `-` | `setExtMusicData:` | prop | ✅ | ✅ | `0xd6f3c` |
| `RBMusicView` | `-` | `baseView` | prop | ✅ | ✅ | `0xd6f74` |
| `RBMusicView` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0xd6f84` |
| `RBMusicView` | `-` | `bgImageView` | prop | ✅ | ✅ | `0xd6fbc` |
| `RBMusicView` | `-` | `setBgImageView:` | prop | ✅ | ✅ | `0xd6fcc` |
| `RBMusicView` | `-` | `firstInfoView` | prop | ✅ | ✅ | `0xd7004` |
| `RBMusicView` | `-` | `setFirstInfoView:` | prop | ✅ | ✅ | `0xd7014` |
| `RBMusicView` | `-` | `jacketImage` | prop | ✅ | ✅ | `0xd704c` |
| `RBMusicView` | `-` | `setJacketImage:` | prop | ✅ | ✅ | `0xd705c` |
| `RBMusicView` | `-` | `musicNameImageView` | prop | ✅ | ✅ | `0xd7094` |
| `RBMusicView` | `-` | `setMusicNameImageView:` | prop | ✅ | ✅ | `0xd70a4` |
| `RBMusicView` | `-` | `artistNameImageView` | prop | ✅ | ✅ | `0xd70dc` |
| `RBMusicView` | `-` | `setArtistNameImageView:` | prop | ✅ | ✅ | `0xd70ec` |
| `RBMusicView` | `-` | `jacketImageView` | prop | ✅ | ✅ | `0xd7124` |
| `RBMusicView` | `-` | `setJacketImageView:` | prop | ✅ | ✅ | `0xd7134` |
| `RBMusicView` | `-` | `scoreView` | prop | ✅ | ✅ | `0xd716c` |
| `RBMusicView` | `-` | `setScoreView:` | prop | ✅ | ✅ | `0xd717c` |
| `RBMusicView` | `-` | `fullComboView` | prop | ✅ | ✅ | `0xd71b4` |
| `RBMusicView` | `-` | `setFullComboView:` | prop | ✅ | ✅ | `0xd71c4` |
| `RBMusicView` | `-` | `rankView` | prop | ✅ | ✅ | `0xd71fc` |
| `RBMusicView` | `-` | `setRankView:` | prop | ✅ | ✅ | `0xd720c` |
| `RBMusicView` | `-` | `arView` | prop | ✅ | ✅ | `0xd7244` |
| `RBMusicView` | `-` | `setArView:` | prop | ✅ | ✅ | `0xd7254` |
| `RBMusicView` | `-` | `settingButtons` | prop | ✅ | ✅ | `0xd728c` |
| `RBMusicView` | `-` | `setSettingButtons:` | prop | ✅ | ✅ | `0xd729c` |
| `RBMusicView` | `-` | `settingButtonEffects` | prop | ✅ | ✅ | `0xd72d4` |
| `RBMusicView` | `-` | `setSettingButtonEffects:` | prop | ✅ | ✅ | `0xd72e4` |
| `RBMusicView` | `-` | `settingButtonCovers` | prop | ✅ | ✅ | `0xd731c` |
| `RBMusicView` | `-` | `setSettingButtonCovers:` | prop | ✅ | ✅ | `0xd732c` |
| `RBMusicView` | `-` | `difficultyView` | prop | ✅ | ✅ | `0xd7364` |
| `RBMusicView` | `-` | `setDifficultyView:` | prop | ✅ | ✅ | `0xd7374` |
| `RBMusicView` | `-` | `speedView` | prop | ✅ | ✅ | `0xd73ac` |
| `RBMusicView` | `-` | `setSpeedView:` | prop | ✅ | ✅ | `0xd73bc` |
| `RBMusicView` | `-` | `doubleButtonCoverView` | prop | ✅ | ✅ | `0xd73f4` |
| `RBMusicView` | `-` | `setDoubleButtonCoverView:` | prop | ✅ | ✅ | `0xd7404` |
| `RBMusicView` | `-` | `otherView` | prop | ✅ | ✅ | `0xd743c` |
| `RBMusicView` | `-` | `setOtherView:` | prop | ✅ | ✅ | `0xd744c` |
| `RBMusicView` | `-` | `extendNoteViews` | prop | ✅ | ✅ | `0xd7484` |
| `RBMusicView` | `-` | `setExtendNoteViews:` | prop | ✅ | ✅ | `0xd7494` |
| `RBMusicView` | `-` | `colorView` | prop | ✅ | ✅ | `0xd74cc` |
| `RBMusicView` | `-` | `setColorView:` | prop | ✅ | ✅ | `0xd74dc` |
| `RBMusicView` | `-` | `cpuView` | prop | ✅ | ✅ | `0xd7514` |
| `RBMusicView` | `-` | `setCpuView:` | prop | ✅ | ✅ | `0xd7524` |
| `RBMusicView` | `-` | `settingScroll` | prop | ✅ | ✅ | `0xd755c` |
| `RBMusicView` | `-` | `setSettingScroll:` | prop | ✅ | ✅ | `0xd756c` |
| `RBMusicView` | `-` | `settingPage` | prop | ✅ | ✅ | `0xd75a4` |
| `RBMusicView` | `-` | `setSettingPage:` | prop | ✅ | ✅ | `0xd75b4` |
| `RBMusicView` | `-` | `settingTitleImages` | prop | ✅ | ✅ | `0xd75ec` |
| `RBMusicView` | `-` | `setSettingTitleImages:` | prop | ✅ | ✅ | `0xd75fc` |
| `RBMusicView` | `-` | `iTunesURL` | prop | ✅ | ✅ | `0xd7634` |
| `RBMusicView` | `-` | `setITunesURL:` | prop | ✅ | ✅ | `0xd7644` |
| `RBMusicView` | `-` | `lineView` | prop | ✅ | ✅ | `0xd767c` |
| `RBMusicView` | `-` | `setLineView:` | prop | ✅ | ✅ | `0xd768c` |
| `RBMusicView` | `-` | `lineAnimationLayers` | prop | ✅ | ✅ | `0xd76c4` |
| `RBMusicView` | `-` | `setLineAnimationLayers:` | prop | ✅ | ✅ | `0xd76d4` |
| `RBMusicView` | `-` | `bpmOrigin` | prop | ✅ | ✅ | `0xd770c` |
| `RBMusicView` | `-` | `setBpmOrigin:` | prop | ✅ | ✅ | `0xd7720` |
| `RBMusicView` | `-` | `bpmImageView` | prop | ✅ | ✅ | `0xd7734` |
| `RBMusicView` | `-` | `setBpmImageView:` | prop | ✅ | ✅ | `0xd7744` |
| `RBMusicView` | `-` | `decideButton` | prop | ✅ | ✅ | `0xd777c` |
| `RBMusicView` | `-` | `setDecideButton:` | prop | ✅ | ✅ | `0xd778c` |
| `RBMusicView` | `-` | `doubleButton` | prop | ✅ | ✅ | `0xd77c4` |
| `RBMusicView` | `-` | `setDoubleButton:` | prop | ✅ | ✅ | `0xd77d4` |
| `RBMusicView` | `-` | `historyView` | prop | ✅ | ✅ | `0xd780c` |
| `RBMusicView` | `-` | `setHistoryView:` | prop | ✅ | ✅ | `0xd781c` |
| `RBMusicView` | `-` | `m_IsWhitePastelMode` | prop | ✅ | ✅ | `0xd7854` |
| `RBMusicView` | `-` | `setM_IsWhitePastelMode:` | prop | ✅ | ✅ | `0xd7864` |
| `RBMusicView` | `-` | `m_IsBlackPastelMode` | prop | ✅ | ✅ | `0xd7874` |
| `RBMusicView` | `-` | `setM_IsBlackPastelMode:` | prop | ✅ | ✅ | `0xd7884` |
| `RBMusicView` | `-` | `whitePastelButton` | prop | ✅ | ✅ | `0xd7894` |
| `RBMusicView` | `-` | `setWhitePastelButton:` | prop | ✅ | ✅ | `0xd78a4` |
| `RBMusicView` | `-` | `blackPastelButton` | prop | ✅ | ✅ | `0xd78b4` |
| `RBMusicView` | `-` | `setBlackPastelButton:` | prop | ✅ | ✅ | `0xd78c4` |
| `RBMusicView` | `-` | `ghostImageView` | prop | ✅ | ✅ | `0xd78d4` |
| `RBMusicView` | `-` | `setGhostImageView:` | prop | ✅ | ✅ | `0xd78e4` |
| `RBPopoverBackgroundView` | `+` | `contentViewInsets` |  | ✅ | ✅ | `0xd7c14` |
| `RBPopoverBackgroundView` | `+` | `arrowHeight` |  | ✅ | ✅ | `0xd7c28` |
| `RBPopoverBackgroundView` | `+` | `arrowBase` |  | ✅ | ✅ | `0xd7c30` |
| `RBPopoverBackgroundView` | `-` | `halfArrowBase` |  | ✅ | ✅ | `0xd7c3c` |
| `RBPopoverBackgroundView` | `-` | `initWithFrame:` |  | ✅ | ✅ | `0xd7c68` |
| `RBPopoverBackgroundView` | `-` | `setArrowOffset:` | prop | ✅ | ✅ | `0xd7d20` |
| `RBPopoverBackgroundView` | `-` | `addShadowPathAnimationIfNecessary:` |  | ✅ | ❌ | `0xd7df8` |
| `RBPopoverBackgroundView` | `-` | `setArrowDirection:` | prop | ✅ | ❌ | `0xd8030` |
| `RBPopoverBackgroundView` | `-` | `addDropShadowIfNecessary` |  | ✅ | ❌ | `0xd8070` |
| `RBPopoverBackgroundView` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0xd8188` |
| `RBPopoverBackgroundView` | `-` | `shadowPath` |  | ✅ | ❌ | `0xd839c` |
| `RBPopoverBackgroundView` | `-` | `upOrDownArrowImage` |  | ✅ | ❌ | `0xd849c` |
| `RBPopoverBackgroundView` | `-` | `sideArrowImage` |  | ✅ | ❌ | `0xd85e4` |
| `RBPopoverBackgroundView` | `-` | `arrowCenter` |  | ✅ | ✅ | `0xd8720` |
| `RBPopoverBackgroundView` | `-` | `wantsUpOrDownArrow` |  | ✅ | ✅ | `0xd878c` |
| `RBPopoverBackgroundView` | `-` | `wantsUpArrow` |  | ✅ | ✅ | `0xd87d8` |
| `RBPopoverBackgroundView` | `-` | `isArrowBetweenLeftAndRightEdgesOfPopover` |  | ✅ | ✅ | `0xd87fc` |
| `RBPopoverBackgroundView` | `-` | `isArrowAtLeftEdgeOfPopover` |  | ✅ | ✅ | `0xd8844` |
| `RBPopoverBackgroundView` | `-` | `isArrowAtRightEdgeOfPopover` |  | ✅ | ✅ | `0xd8878` |
| `RBPopoverBackgroundView` | `-` | `isArrowBetweenTopAndBottomEdgesOfPopover` |  | ✅ | ✅ | `0xd88b0` |
| `RBPopoverBackgroundView` | `-` | `isArrowAtTopEdgeOfPopover` |  | ✅ | ✅ | `0xd88f8` |
| `RBPopoverBackgroundView` | `-` | `isArrowAtBottomEdgeOfPopover` |  | ✅ | ✅ | `0xd8930` |
| `RBPopoverBackgroundView` | `-` | `adjustCentersIfNecessary` |  | ✅ | ❌ | `0xd8968` |
| `RBPopoverBackgroundView` | `-` | `stretchableImageNamed:insets:mirrored:` |  | ✅ | ❌ | `0xd8ac4` |
| `RBPopoverBackgroundView` | `-` | `twoPartStretchableImageNamed:insets:` |  | ✅ | ❌ | `0xd8bd8` |
| `RBPopoverBackgroundView` | `-` | `firstHalfStretchAmountForImage:` |  | ✅ | ❌ | `0xd8d74` |
| `RBPopoverBackgroundView` | `-` | `contextSizeForFirstHalfImage:` |  | ✅ | ❌ | `0xd8e38` |
| `RBPopoverBackgroundView` | `-` | `secondHalfInsetsForStretchedImage:insets:` |  | ✅ | ❌ | `0xd8ed8` |
| `RBPopoverBackgroundView` | `-` | `horizontalInsetsForStretchedImage:insets:` |  | ✅ | ❌ | `0xd8f98` |
| `RBPopoverBackgroundView` | `-` | `verticalInsetsForStretchedImage:insets:` |  | ✅ | ❌ | `0xd8fdc` |
| `RBPopoverBackgroundView` | `-` | `mirroredImage:` |  | ✅ | ❌ | `0xd9020` |
| `RBPopoverBackgroundView` | `-` | `mirroredInsets:` |  | ✅ | ❌ | `0xd9110` |
| `RBPopoverBackgroundView` | `-` | `imageFromImageContextWithSourceImage:size:` |  | ✅ | ❌ | `0xd9120` |
| `RBPopoverBackgroundView` | `-` | `arrowOffset` | prop | ✅ | ✅ | `0xd91b0` |
| `RBPopoverBackgroundView` | `-` | `arrowDirection` | prop | ✅ | ✅ | `0xd91c0` |
| `RBPopoverBackgroundView` | `-` | `popoverBackground` | prop | ✅ | ✅ | `0xd91d0` |
| `RBPopoverBackgroundView` | `-` | `setPopoverBackground:` | prop | ✅ | ✅ | `0xd91e0` |
| `RBRankingTableCell` | `-` | `initWithStyle:reuseIdentifier:` |  | ✅ | ❌ | `0xd922c` |
| `RBRankingTableCell` | `-` | `dealloc` |  | ✅ | ✅ | `0xd9cd8` |
| `RBRankingTableCell` | `-` | `setStrokeColor:` | prop | ✅ | ✅ | `0xd9d0c` |
| `RBRankingTableCell` | `-` | `drawRect:` |  | ✅ | ❌ | `0xd9e1c` |
| `RBRankingTableCell` | `-` | `labelRank` | prop | ✅ | ✅ | `0xda450` |
| `RBRankingTableCell` | `-` | `setLabelRank:` | prop | ✅ | ✅ | `0xda460` |
| `RBRankingTableCell` | `-` | `labelName` | prop | ✅ | ✅ | `0xda498` |
| `RBRankingTableCell` | `-` | `setLabelName:` | prop | ✅ | ✅ | `0xda4a8` |
| `RBRankingTableCell` | `-` | `labelScore` | prop | ✅ | ✅ | `0xda4e0` |
| `RBRankingTableCell` | `-` | `setLabelScore:` | prop | ✅ | ✅ | `0xda4f0` |
| `RBRankingTableCell` | `-` | `isTop` | prop | ✅ | ✅ | `0xda528` |
| `RBRankingTableCell` | `-` | `setIsTop:` | prop | ✅ | ✅ | `0xda538` |
| `RBRankingTableCell` | `-` | `isLast` | prop | ✅ | ✅ | `0xda548` |
| `RBRankingTableCell` | `-` | `setIsLast:` | prop | ✅ | ✅ | `0xda558` |
| `RBRankingTableCell` | `-` | `fillColor` | prop | ✅ | ✅ | `0xda568` |
| `RBRankingTableCell` | `-` | `setFillColor:` | prop | ✅ | ✅ | `0xda578` |
| `RBRankingTableCell` | `-` | `strokeColor` | prop | ✅ | ✅ | `0xda5b0` |
| `RBRankingTableView` | `-` | `initWithFrame:style:` |  | ✅ | ❌ | `0xda63c` |
| `RBRankingTableView` | `-` | `dealloc` |  | ✅ | ✅ | `0xdb42c` |
| `RBRankingTableView` | `-` | `numEntries` |  | ✅ | ❌ | `0xdb460` |
| `RBRankingTableView` | `-` | `errorMsg` |  | ✅ | ❌ | `0xdb558` |
| `RBRankingTableView` | `-` | `load:` |  | ✅ | ❌ | `0xdb628` |
| `RBRankingTableView` | `-` | `loadRanking` |  | ✅ | ❌ | `0xdc174` |
| `RBRankingTableView` | `-` | `clear` |  | ✅ | ✅ | `0xdc508` |
| `RBRankingTableView` | `-` | `pushLoadNext:` |  | ✅ | ❌ | `0xdc514` |
| `RBRankingTableView` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ✅ | `0xdc590` |
| `RBRankingTableView` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ❌ | `0xdc598` |
| `RBRankingTableView` | `-` | `tableView:heightForRowAtIndexPath:` |  | ✅ | ✅ | `0xdc5b4` |
| `RBRankingTableView` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ❌ | `0xdc5c0` |
| `RBRankingTableView` | `-` | `tableView:willDisplayCell:forRowAtIndexPath:` |  | ✅ | ❌ | `0xdcf90` |
| `RBRankingTableView` | `-` | `playerScope` | prop | ✅ | ✅ | `0xdd020` |
| `RBRankingTableView` | `-` | `setPlayerScope:` | prop | ✅ | ✅ | `0xdd030` |
| `RBRankingTableView` | `-` | `footer` | prop | ✅ | ✅ | `0xdd040` |
| `RBRankingTableView` | `-` | `setFooter:` | prop | ✅ | ✅ | `0xdd050` |
| `RBRankingTableView` | `-` | `buttonLoadNext` | prop | ✅ | ✅ | `0xdd088` |
| `RBRankingTableView` | `-` | `setButtonLoadNext:` | prop | ✅ | ✅ | `0xdd098` |
| `RBRankingTableView` | `-` | `arrayScore` | prop | ✅ | ✅ | `0xdd0d0` |
| `RBRankingTableView` | `-` | `setArrayScore:` | prop | ✅ | ✅ | `0xdd0e0` |
| `RBRankingTableView` | `-` | `arrayName` | prop | ✅ | ✅ | `0xdd118` |
| `RBRankingTableView` | `-` | `setArrayName:` | prop | ✅ | ✅ | `0xdd128` |
| `RBRankingTableView` | `-` | `msgLabel` | prop | ✅ | ✅ | `0xdd160` |
| `RBRankingTableView` | `-` | `setMsgLabel:` | prop | ✅ | ✅ | `0xdd170` |
| `RBRankingTableView` | `-` | `localPlayerScore` | prop | ✅ | ✅ | `0xdd1a8` |
| `RBRankingTableView` | `-` | `setLocalPlayerScore:` | prop | ✅ | ✅ | `0xdd1b8` |
| `RBRankingTableView` | `-` | `strokeColor` | prop | ✅ | ✅ | `0xdd1f0` |
| `RBRankingTableView` | `-` | `setStrokeColor:` | prop | ✅ | ✅ | `0xdd200` |
| `DownloadResourceManager` | `+` | `fileListCheck` |  | ✅ | ❌ | `0xdd2dc` |
| `DownloadResourceManager` | `+` | `offlineCheck` |  | ✅ | ❌ | `0xdd74c` |
| `DownloadResourceManager` | `+` | `onlineChek:` |  | ✅ | ❌ | `0xdd850` |
| `RBRankingView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xdda2c` |
| `RBRankingView` | `-` | `dealloc` |  | ✅ | ✅ | `0xddab8` |
| `RBRankingView` | `-` | `setupView` |  | ✅ | ❌ | `0xddaec` |
| `RBRankingView` | `-` | `showFriend:` |  | ✅ | ❌ | `0xdec60` |
| `RBRankingView` | `-` | `SelectFriendButton` |  | ✅ | ❌ | `0xdedf4` |
| `RBRankingView` | `-` | `SelectAllButton` |  | ✅ | ❌ | `0xdee2c` |
| `RBRankingView` | `-` | `titleView` | prop | ✅ | ✅ | `0xdee64` |
| `RBRankingView` | `-` | `setTitleView:` | prop | ✅ | ✅ | `0xdee74` |
| `RBRankingView` | `-` | `scrollBaseView` | prop | ✅ | ✅ | `0xdeeac` |
| `RBRankingView` | `-` | `setScrollBaseView:` | prop | ✅ | ✅ | `0xdeebc` |
| `RBRankingView` | `-` | `friendRanking` | prop | ✅ | ✅ | `0xdeef4` |
| `RBRankingView` | `-` | `setFriendRanking:` | prop | ✅ | ✅ | `0xdef04` |
| `RBRankingView` | `-` | `totalRanking` | prop | ✅ | ✅ | `0xdef3c` |
| `RBRankingView` | `-` | `setTotalRanking:` | prop | ✅ | ✅ | `0xdef4c` |
| `RBRankingView` | `-` | `friendButton` | prop | ✅ | ✅ | `0xdef84` |
| `RBRankingView` | `-` | `setFriendButton:` | prop | ✅ | ✅ | `0xdef94` |
| `RBRankingView` | `-` | `friendButtonEffect` | prop | ✅ | ✅ | `0xdefcc` |
| `RBRankingView` | `-` | `setFriendButtonEffect:` | prop | ✅ | ✅ | `0xdefdc` |
| `RBRankingView` | `-` | `allButton` | prop | ✅ | ✅ | `0xdf014` |
| `RBRankingView` | `-` | `setAllButton:` | prop | ✅ | ✅ | `0xdf024` |
| `RBRankingView` | `-` | `allButtonEffect` | prop | ✅ | ✅ | `0xdf05c` |
| `RBRankingView` | `-` | `setAllButtonEffect:` | prop | ✅ | ✅ | `0xdf06c` |
| `RBMapAnnotation` | `-` | `initWithCoordinate:Title:SubTitle:Model:` |  | ✅ | ❌ | `0xdf15c` |
| `RBMapAnnotation` | `-` | `dealloc` |  | ❌ | ✅ | `0xdf364` |
| `RBMapAnnotation` | `-` | `modelName` | prop | ✅ | ✅ | `0xdf398` |
| `RBMapAnnotation` | `-` | `setModelName:` | prop | ✅ | ✅ | `0xdf3a8` |
| `RBMapAnnotation` | `-` | `title` | prop | ✅ | ✅ | `0xdf3e0` |
| `RBMapAnnotation` | `-` | `setTitle:` | prop | ✅ | ✅ | `0xdf3f0` |
| `RBMapAnnotation` | `-` | `subtitle` | prop | ✅ | ✅ | `0xdf3fc` |
| `RBMapAnnotation` | `-` | `setSubtitle:` | prop | ✅ | ✅ | `0xdf40c` |
| `RBMapAnnotation` | `-` | `coordinate` | prop | ✅ | ✅ | `0xdf418` |
| `RBMapAnnotation` | `-` | `setCoordinate:` | prop | ✅ | ✅ | `0xdf42c` |
| `RBSearchMapView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xdf494` |
| `RBSearchMapView` | `+` | `rangeOfRegion:` |  | ✅ | ❌ | `0xdf634` |
| `RBSearchMapView` | `+` | `mapRectForCoordinateRegion:` |  | ✅ | ❌ | `0xdf644` |
| `RBSearchMapView` | `+` | `currentLocationEnabled` |  | ✅ | ❌ | `0xdf6c4` |
| `RBSearchMapView` | `-` | `setupView` |  | ✅ | ❌ | `0xdf768` |
| `RBSearchMapView` | `-` | `showError:` |  | ✅ | ❌ | `0xe0aa4` |
| `RBSearchMapView` | `-` | `requestList:` |  | ✅ | ❌ | `0xe0cd4` |
| `RBSearchMapView` | `-` | `pushCurrent` |  | ✅ | ❌ | `0xe0f4c` |
| `RBSearchMapView` | `-` | `locationManager:didChangeAuthorizationStatus:` |  | ✅ | ❌ | `0xe1084` |
| `RBSearchMapView` | `-` | `observeValueForKeyPath:ofObject:change:context:` |  | ✅ | ❌ | `0xe1274` |
| `RBSearchMapView` | `-` | `mapView:didChangeUserTrackingMode:animated:` |  | ✅ | ❌ | `0xe1350` |
| `RBSearchMapView` | `-` | `toggleTrackingMode` |  | ✅ | ❌ | `0xe1430` |
| `RBSearchMapView` | `-` | `mapView:regionWillChangeAnimated:` |  | ✅ | ✅ | `0xe162c` |
| `RBSearchMapView` | `-` | `mapViewWillStartLoadingMap:` |  | ✅ | ✅ | `0xe1630` |
| `RBSearchMapView` | `-` | `mapViewDidFinishLoadingMap:` |  | ✅ | ✅ | `0xe1634` |
| `RBSearchMapView` | `-` | `mapViewDidFailLoadingMap:withError:` |  | ✅ | ✅ | `0xe1638` |
| `RBSearchMapView` | `-` | `mapView:regionDidChangeAnimated:` |  | ✅ | ❌ | `0xe163c` |
| `RBSearchMapView` | `-` | `mapView:viewForAnnotation:` |  | ✅ | ❌ | `0xe1e60` |
| `RBSearchMapView` | `-` | `mapView:annotationView:calloutAccessoryControlTapped:` |  | ✅ | ❌ | `0xe227c` |
| `RBSearchMapView` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0xe24ec` |
| `RBSearchMapView` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0xe2614` |
| `RBSearchMapView` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0xe2618` |
| `RBSearchMapView` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0xe261c` |
| `RBSearchMapView` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0xe2620` |
| `RBSearchMapView` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0xe2760` |
| `RBSearchMapView` | `-` | `downloaderError:` |  | ✅ | ❌ | `0xe3d28` |
| `RBSearchMapView` | `-` | `imageDownloader:didLoad:` |  | ✅ | ❌ | `0xe3e04` |
| `RBSearchMapView` | `-` | `imageDownloaderDidFail:didLoad:` |  | ✅ | ❌ | `0xe47f0` |
| `RBSearchMapView` | `-` | `selectHideInfo:` |  | ✅ | ❌ | `0xe4848` |
| `RBSearchMapView` | `-` | `initialView` |  | ✅ | ❌ | `0xe496c` |
| `RBSearchMapView` | `-` | `getMaster` |  | ✅ | ❌ | `0xe4a18` |
| `RBSearchMapView` | `-` | `viewDidDisappear` |  | ✅ | ❌ | `0xe4ba4` |
| `RBSearchMapView` | `-` | `dealloc` |  | ✅ | ❌ | `0xe4cec` |
| `RBSearchMapView` | `-` | `addIndicator` |  | ✅ | ❌ | `0xe503c` |
| `RBSearchMapView` | `-` | `subIndicator` |  | ✅ | ❌ | `0xe50b4` |
| `RBSearchMapView` | `-` | `delegate` | prop | ✅ | ✅ | `0xe512c` |
| `RBSearchMapView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0xe514c` |
| `RBSearchMapView` | `-` | `mapView` | prop | ✅ | ✅ | `0xe5160` |
| `RBSearchMapView` | `-` | `setMapView:` | prop | ✅ | ✅ | `0xe5170` |
| `RBSearchMapView` | `-` | `indicator` | prop | ✅ | ✅ | `0xe51a8` |
| `RBSearchMapView` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0xe51b8` |
| `RBSearchMapView` | `-` | `messageLabel` | prop | ✅ | ✅ | `0xe51f0` |
| `RBSearchMapView` | `-` | `setMessageLabel:` | prop | ✅ | ✅ | `0xe5200` |
| `RBSearchMapView` | `-` | `errorLabel` | prop | ✅ | ✅ | `0xe5238` |
| `RBSearchMapView` | `-` | `setErrorLabel:` | prop | ✅ | ✅ | `0xe5248` |
| `RBSearchMapView` | `-` | `infomationBaseView` | prop | ✅ | ✅ | `0xe5280` |
| `RBSearchMapView` | `-` | `setInfomationBaseView:` | prop | ✅ | ✅ | `0xe5290` |
| `RBSearchMapView` | `-` | `infomationView` | prop | ✅ | ✅ | `0xe52c8` |
| `RBSearchMapView` | `-` | `setInfomationView:` | prop | ✅ | ✅ | `0xe52d8` |
| `RBSearchMapView` | `-` | `infomationImage` | prop | ✅ | ✅ | `0xe5310` |
| `RBSearchMapView` | `-` | `setInfomationImage:` | prop | ✅ | ✅ | `0xe5320` |
| `RBSearchMapView` | `-` | `locationManager` | prop | ✅ | ✅ | `0xe5358` |
| `RBSearchMapView` | `-` | `setLocationManager:` | prop | ✅ | ✅ | `0xe5368` |
| `RBSearchMapView` | `-` | `masterDownloader` | prop | ✅ | ✅ | `0xe53a0` |
| `RBSearchMapView` | `-` | `setMasterDownloader:` | prop | ✅ | ✅ | `0xe53b0` |
| `RBSearchMapView` | `-` | `listDownloader` | prop | ✅ | ✅ | `0xe53e8` |
| `RBSearchMapView` | `-` | `setListDownloader:` | prop | ✅ | ✅ | `0xe53f8` |
| `RBSearchMapView` | `-` | `imageDownloader` | prop | ✅ | ✅ | `0xe5430` |
| `RBSearchMapView` | `-` | `setImageDownloader:` | prop | ✅ | ✅ | `0xe5440` |
| `RBSearchMapView` | `-` | `dictSpot` | prop | ✅ | ✅ | `0xe5478` |
| `RBSearchMapView` | `-` | `setDictSpot:` | prop | ✅ | ✅ | `0xe5488` |
| `RBSearchMapView` | `-` | `mapURL` | prop | ✅ | ✅ | `0xe54c0` |
| `RBSearchMapView` | `-` | `setMapURL:` | prop | ✅ | ✅ | `0xe54d0` |
| `RBSearchMapView` | `-` | `info` | prop | ✅ | ✅ | `0xe5508` |
| `RBSearchMapView` | `-` | `setInfo:` | prop | ✅ | ✅ | `0xe5518` |
| `RBSearchMapView` | `-` | `models` | prop | ✅ | ✅ | `0xe5550` |
| `RBSearchMapView` | `-` | `setModels:` | prop | ✅ | ✅ | `0xe5560` |
| `RBSearchMapView` | `-` | `modelNameForArrayIndex` | prop | ✅ | ✅ | `0xe5598` |
| `RBSearchMapView` | `-` | `setModelNameForArrayIndex:` | prop | ✅ | ✅ | `0xe55a8` |
| `RBSearchMapViewController` | `-` | `init` |  | ✅ | ❌ | `0xe5748` |
| `RBSearchMapViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0xe5bc8` |
| `RBSearchMapViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0xe5dd4` |
| `RBSearchMapViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0xe5f40` |
| `RBSearchMapViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0xe60f0` |
| `RBSearchMapViewController` | `-` | `pushBarBtnBack:` |  | ✅ | ❌ | `0xe6238` |
| `RBSearchMapViewController` | `-` | `pushCurrent:` |  | ✅ | ❌ | `0xe6300` |
| `RBSearchMapViewController` | `-` | `forceClose` |  | ✅ | ❌ | `0xe63a0` |
| `RBSearchMapViewController` | `-` | `didChangeUserTracking:` |  | ✅ | ❌ | `0xe6454` |
| `RBSearchMapViewController` | `-` | `currentLocation` | prop | ✅ | ✅ | `0xe64b0` |
| `RBSearchMapViewController` | `-` | `setCurrentLocation:` | prop | ✅ | ✅ | `0xe64c0` |
| `RBSearchView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xe650c` |
| `RBSearchView` | `-` | `showAnimation` |  | ✅ | ❌ | `0xe6598` |
| `RBSearchView` | `-` | `setupView` |  | ✅ | ❌ | `0xe661c` |
| `RBSearchView` | `-` | `selectCurrentPosition:` |  | ✅ | ❌ | `0xe6e74` |
| `RBSearchView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0xe6ed0` |
| `RBSearchView` | `-` | `didChangeUserTracking:` |  | ✅ | ❌ | `0xe6f94` |
| `RBSearchView` | `-` | `settingView` | prop | ✅ | ✅ | `0xe6ff0` |
| `RBSearchView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0xe7010` |
| `RBSearchView` | `-` | `map` | prop | ✅ | ✅ | `0xe7024` |
| `RBSearchView` | `-` | `setMap:` | prop | ✅ | ✅ | `0xe7034` |
| `RBSearchView` | `-` | `currentPositionButton` | prop | ✅ | ✅ | `0xe706c` |
| `RBSearchView` | `-` | `setCurrentPositionButton:` | prop | ✅ | ✅ | `0xe707c` |
| `RBMenuBGEffectView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xe7104` |
| `RBMenuBGEffectView` | `-` | `setupView` |  | ✅ | ❌ | `0xe7288` |
| `RBMenuBGEffectView` | `-` | `createAnimation:type:` |  | ✅ | ❌ | `0xe72bc` |
| `RBMenuBGEffectView` | `-` | `startAnimation` |  | ✅ | ❌ | `0xe8404` |
| `RBMenuBGEffectView` | `-` | `stopAnimation` |  | ✅ | ❌ | `0xe8614` |
| `RBMenuBGEffectView` | `-` | `removeFromSuperview` |  | ✅ | ❌ | `0xe8894` |
| `RBMenuBGEffectView` | `-` | `setupRainbow` |  | ✅ | ❌ | `0xe88c8` |
| `RBMenuBGEffectView` | `-` | `setupParticle` |  | ✅ | ❌ | `0xe8ccc` |
| `RBMenuBGEffectView` | `-` | `rainbowImageBasePath` | prop | ✅ | ✅ | `0xe8e00` |
| `RBMenuBGEffectView` | `-` | `setRainbowImageBasePath:` | prop | ✅ | ✅ | `0xe8e10` |
| `RBMenuBGEffectView` | `-` | `ringImageBasePath` | prop | ✅ | ✅ | `0xe8e48` |
| `RBMenuBGEffectView` | `-` | `setRingImageBasePath:` | prop | ✅ | ✅ | `0xe8e58` |
| `RBMenuBGEffectView` | `-` | `EFFECT_NUM` | prop | ✅ | ✅ | `0xe8e90` |
| `RBMenuBGEffectView` | `-` | `setEFFECT_NUM:` | prop | ✅ | ✅ | `0xe8ea0` |
| `RBMenuBGEffectView` | `-` | `effList` | prop | ✅ | ✅ | `0xe8eb0` |
| `RBMenuBGEffectView` | `-` | `setEffList:` | prop | ✅ | ✅ | `0xe8ec0` |
| `RBMenuBGEffectView` | `-` | `animImageList` | prop | ✅ | ✅ | `0xe8ef8` |
| `RBMenuBGEffectView` | `-` | `setAnimImageList:` | prop | ✅ | ✅ | `0xe8f08` |
| `RBSettingMenuButton` | `-` | `initWithFilename:` |  | ✅ | ❌ | `0xe8fa8` |
| `RBSettingMenuButton` | `-` | `setupView:` |  | ✅ | ❌ | `0xe902c` |
| `RBSettingMenuButton` | `-` | `setFlashEffect` |  | ✅ | ❌ | `0xe9a04` |
| `RBSettingMenuButton` | `-` | `removeFlashEffect` |  | ✅ | ❌ | `0xe9b20` |
| `RBSettingMenuButton` | `-` | `setEnabled:` |  | ✅ | ❌ | `0xe9c28` |
| `RBSettingMenuButton` | `-` | `button` | prop | ✅ | ✅ | `0xe9c80` |
| `RBSettingMenuButton` | `-` | `setButton:` | prop | ✅ | ✅ | `0xe9c90` |
| `RBSettingMenuButton` | `-` | `effectImageView` | prop | ✅ | ✅ | `0xe9cc8` |
| `RBSettingMenuButton` | `-` | `setEffectImageView:` | prop | ✅ | ✅ | `0xe9cd8` |
| `RBSettingMenuButton` | `-` | `effectTextImageView` | prop | ✅ | ✅ | `0xe9d10` |
| `RBSettingMenuButton` | `-` | `setEffectTextImageView:` | prop | ✅ | ✅ | `0xe9d20` |
| `RBSettingView` | `-` | `initWithFrame:ButtonFrame:` |  | ✅ | ❌ | `0xe9dac` |
| `RBSettingView` | `-` | `dealloc` |  | ❌ | ✅ | `0xe9e50` |
| `RBSettingView` | `-` | `setupView:` |  | ✅ | ❌ | `0xe9e84` |
| `RBSettingView` | `-` | `OpenView` |  | ✅ | ❌ | `0xeb0e4` |
| `RBSettingView` | `-` | `CloseView` |  | ✅ | ❌ | `0xeb144` |
| `RBSettingView` | `-` | `showAnimation` |  | ✅ | ❌ | `0xeb194` |
| `RBSettingView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0xeb674` |
| `RBSettingView` | `-` | `hideAnimationEnd` |  | ✅ | ❌ | `0xeb910` |
| `RBSettingView` | `-` | `touchesBegan:withEvent:` |  | ✅ | ✅ | `0xeb9c0` |
| `RBSettingView` | `-` | `touchesMoved:withEvent:` |  | ✅ | ✅ | `0xeb9c4` |
| `RBSettingView` | `-` | `touchesEnded:withEvent:` |  | ✅ | ❌ | `0xeb9c8` |
| `RBSettingView` | `-` | `touchesCancelled:withEvent:` |  | ✅ | ✅ | `0xebbbc` |
| `RBSettingView` | `-` | `SelectCustomizeButton` |  | ✅ | ❌ | `0xebbc0` |
| `RBSettingView` | `-` | `selectThema:` |  | ✅ | ❌ | `0xebcec` |
| `RBSettingView` | `-` | `SelectHowToPlayButton` |  | ✅ | ❌ | `0xebdf0` |
| `RBSettingView` | `-` | `SelectInfoButton` |  | ✅ | ❌ | `0xebf1c` |
| `RBSettingView` | `-` | `SelectTermButton` |  | ✅ | ❌ | `0xebf94` |
| `RBSettingView` | `-` | `SelectApplilinkButton` |  | ✅ | ❌ | `0xec00c` |
| `RBSettingView` | `-` | `SelectExitButton` |  | ✅ | ❌ | `0xec0c0` |
| `RBSettingView` | `-` | `selectMap:` |  | ✅ | ❌ | `0xec0e0` |
| `RBSettingView` | `-` | `getCustomizeButtonView` |  | ✅ | ✅ | `0xec164` |
| `RBSettingView` | `-` | `parentView` | prop | ✅ | ✅ | `0xec170` |
| `RBSettingView` | `-` | `setParentView:` | prop | ✅ | ✅ | `0xec190` |
| `RBSettingView` | `-` | `baseView` | prop | ✅ | ✅ | `0xec1a4` |
| `RBSettingView` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0xec1b4` |
| `RBSettingView` | `-` | `howToButton` | prop | ✅ | ✅ | `0xec1ec` |
| `RBSettingView` | `-` | `setHowToButton:` | prop | ✅ | ✅ | `0xec1fc` |
| `RBSettingView` | `-` | `customButton` | prop | ✅ | ✅ | `0xec234` |
| `RBSettingView` | `-` | `setCustomButton:` | prop | ✅ | ✅ | `0xec244` |
| `RBSettingView` | `-` | `themaButton` | prop | ✅ | ✅ | `0xec27c` |
| `RBSettingView` | `-` | `setThemaButton:` | prop | ✅ | ✅ | `0xec28c` |
| `RBSettingView` | `-` | `searchButton` | prop | ✅ | ✅ | `0xec2c4` |
| `RBSettingView` | `-` | `setSearchButton:` | prop | ✅ | ✅ | `0xec2d4` |
| `RBSettingView` | `-` | `infoButton` | prop | ✅ | ✅ | `0xec30c` |
| `RBSettingView` | `-` | `setInfoButton:` | prop | ✅ | ✅ | `0xec31c` |
| `RBSettingView` | `-` | `applilinkButton` | prop | ✅ | ✅ | `0xec354` |
| `RBSettingView` | `-` | `setApplilinkButton:` | prop | ✅ | ✅ | `0xec364` |
| `StoreDetailCopyrightCell` | `-` | `initWithStyle:reuseIdentifier:` |  | ✅ | ❌ | `0xec604` |
| `StoreDetailCopyrightCell` | `-` | `dealloc` |  | ❌ | ✅ | `0xec908` |
| `StoreDetailCopyrightCell` | `-` | `labelCopyright` | prop | ✅ | ✅ | `0xec93c` |
| `StoreDetailCopyrightCell` | `-` | `setLabelCopyright:` | prop | ✅ | ✅ | `0xec94c` |
| `StoreDetailHeaderView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xec998` |
| `StoreDetailHeaderView` | `-` | `loadPackInfo:` |  | ✅ | ❌ | `0xed47c` |
| `StoreDetailHeaderView` | `-` | `setArtwork:` |  | ✅ | ❌ | `0xeda24` |
| `StoreDetailHeaderView` | `-` | `labelName` | prop | ✅ | ✅ | `0xedb4c` |
| `StoreDetailHeaderView` | `-` | `setLabelName:` | prop | ✅ | ✅ | `0xedb5c` |
| `StoreDetailHeaderView` | `-` | `labelComment` | prop | ✅ | ✅ | `0xedb94` |
| `StoreDetailHeaderView` | `-` | `setLabelComment:` | prop | ✅ | ✅ | `0xedba4` |
| `StoreDetailHeaderView` | `-` | `buttonPurchase` | prop | ✅ | ✅ | `0xedbdc` |
| `StoreDetailHeaderView` | `-` | `setButtonPurchase:` | prop | ✅ | ✅ | `0xedbec` |
| `StoreDetailHeaderView` | `-` | `bgView` | prop | ✅ | ✅ | `0xedc24` |
| `StoreDetailHeaderView` | `-` | `setBgView:` | prop | ✅ | ✅ | `0xedc34` |
| `StoreDetailHeaderView` | `-` | `artworkView` | prop | ✅ | ✅ | `0xedc6c` |
| `StoreDetailHeaderView` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0xedc7c` |
| `StoreDetailHeaderView` | `-` | `reflectionArtworkView` | prop | ✅ | ✅ | `0xedcb4` |
| `StoreDetailHeaderView` | `-` | `setReflectionArtworkView:` | prop | ✅ | ✅ | `0xedcc4` |
| `StoreDetailHeaderView` | `-` | `iconNewMarker` | prop | ✅ | ✅ | `0xedcfc` |
| `StoreDetailHeaderView` | `-` | `setIconNewMarker:` | prop | ✅ | ✅ | `0xedd0c` |
| `StoreDetailMusicCell` | `+` | `cellHeight` |  | ✅ | ❌ | `0xedde8` |
| `StoreDetailMusicCell` | `-` | `initWithStyle:reuseIdentifier:` |  | ✅ | ❌ | `0xeddf4` |
| `StoreDetailMusicCell` | `-` | `handleLink:` |  | ✅ | ❌ | `0xef5cc` |
| `StoreDetailMusicCell` | `-` | `setBgImage:` |  | ✅ | ❌ | `0xef784` |
| `StoreDetailMusicCell` | `-` | `setLink:` |  | ✅ | ❌ | `0xef810` |
| `StoreDetailMusicCell` | `-` | `sampleStop` |  | ✅ | ❌ | `0xef940` |
| `StoreDetailMusicCell` | `-` | `sampleDownloading` |  | ✅ | ❌ | `0xef9e0` |
| `StoreDetailMusicCell` | `-` | `samplePlaying` |  | ✅ | ❌ | `0xefab8` |
| `StoreDetailMusicCell` | `-` | `dealloc` |  | ❌ | ✅ | `0xefb90` |
| `StoreDetailMusicCell` | `-` | `tapSp:` |  | ✅ | ❌ | `0xefbc4` |
| `StoreDetailMusicCell` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0xefc30` |
| `StoreDetailMusicCell` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0xefd88` |
| `StoreDetailMusicCell` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0xefd8c` |
| `StoreDetailMusicCell` | `-` | `artworkView` | prop | ✅ | ✅ | `0xefecc` |
| `StoreDetailMusicCell` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0xefedc` |
| `StoreDetailMusicCell` | `-` | `labelName` | prop | ✅ | ✅ | `0xeff14` |
| `StoreDetailMusicCell` | `-` | `setLabelName:` | prop | ✅ | ✅ | `0xeff24` |
| `StoreDetailMusicCell` | `-` | `labelArtist` | prop | ✅ | ✅ | `0xeff5c` |
| `StoreDetailMusicCell` | `-` | `setLabelArtist:` | prop | ✅ | ✅ | `0xeff6c` |
| `StoreDetailMusicCell` | `-` | `labelLevels` | prop | ✅ | ✅ | `0xeffa4` |
| `StoreDetailMusicCell` | `-` | `setLabelLevels:` | prop | ✅ | ✅ | `0xeffb4` |
| `StoreDetailMusicCell` | `-` | `parent` | prop | ✅ | ✅ | `0xeffec` |
| `StoreDetailMusicCell` | `-` | `setParent:` | prop | ✅ | ✅ | `0xf000c` |
| `StoreDetailMusicCell` | `-` | `pid` | prop | ✅ | ✅ | `0xf0020` |
| `StoreDetailMusicCell` | `-` | `setPid:` | prop | ✅ | ✅ | `0xf0030` |
| `StoreDetailMusicCell` | `-` | `iconSp` | prop | ✅ | ✅ | `0xf0040` |
| `StoreDetailMusicCell` | `-` | `setIconSp:` | prop | ✅ | ✅ | `0xf0050` |
| `StoreDetailMusicCell` | `-` | `linkURL` | prop | ✅ | ✅ | `0xf0088` |
| `StoreDetailMusicCell` | `-` | `setLinkURL:` | prop | ✅ | ✅ | `0xf0098` |
| `StoreDetailMusicCell` | `-` | `bgView` | prop | ✅ | ✅ | `0xf00d0` |
| `StoreDetailMusicCell` | `-` | `setBgView:` | prop | ✅ | ✅ | `0xf00e0` |
| `StoreDetailMusicCell` | `-` | `sampleView` | prop | ✅ | ✅ | `0xf0118` |
| `StoreDetailMusicCell` | `-` | `setSampleView:` | prop | ✅ | ✅ | `0xf0128` |
| `StoreDetailMusicCell` | `-` | `indicator` | prop | ✅ | ✅ | `0xf0160` |
| `StoreDetailMusicCell` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0xf0170` |
| `StoreDetailMusicCell` | `-` | `playingView` | prop | ✅ | ✅ | `0xf01a8` |
| `StoreDetailMusicCell` | `-` | `setPlayingView:` | prop | ✅ | ✅ | `0xf01b8` |
| `StoreDetailMusicCell` | `-` | `buttonLink` | prop | ✅ | ✅ | `0xf01f0` |
| `StoreDetailMusicCell` | `-` | `setButtonLink:` | prop | ✅ | ✅ | `0xf0200` |
| `RBCorporateViewController` | `-` | `init` |  | ✅ | ❌ | `0xf033c` |
| `RBCorporateViewController` | `-` | `dealloc` |  | ❌ | ✅ | `0xf0520` |
| `RBCorporateViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0xf0554` |
| `RBCorporateViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0xf0774` |
| `RBCorporateViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0xf0858` |
| `RBCorporateViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0xf0aa4` |
| `RBCorporateViewController` | `-` | `pushBarBtnBack:` |  | ✅ | ❌ | `0xf0b84` |
| `RBCorporateViewController` | `-` | `forceClose` |  | ✅ | ❌ | `0xf0c74` |
| `RBCorporateViewController` | `-` | `webView:shouldStartLoadWithRequest:navigationType:` |  | ✅ | ❌ | `0xf0d5c` |
| `RBCorporateViewController` | `-` | `webView:didFailLoadWithError:` |  | ✅ | ❌ | `0xf0dc0` |
| `RBCorporateViewController` | `-` | `webViewDidStartLoad:` |  | ✅ | ❌ | `0xf0ecc` |
| `RBCorporateViewController` | `-` | `webViewDidFinishLoad:` |  | ✅ | ❌ | `0xf0f30` |
| `RBCorporateViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0xf0ff0` |
| `RBCorporateViewController` | `-` | `isFirstRequest` | prop | ✅ | ✅ | `0xf1030` |
| `RBCorporateViewController` | `-` | `setIsFirstRequest:` | prop | ✅ | ✅ | `0xf1040` |
| `RBCorporateViewController` | `-` | `indicator` | prop | ✅ | ✅ | `0xf1050` |
| `RBCorporateViewController` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0xf1060` |
| `RBCorporateViewController` | `-` | `requestURL` | prop | ✅ | ✅ | `0xf1070` |
| `RBCorporateViewController` | `-` | `setRequestURL:` | prop | ✅ | ✅ | `0xf1080` |
| `RBCorporateViewController` | `-` | `webView` | prop | ✅ | ✅ | `0xf10b8` |
| `RBCorporateViewController` | `-` | `setWebView:` | prop | ✅ | ✅ | `0xf10c8` |
| `StoreDialogView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xf10ec` |
| `StoreDialogView` | `-` | `layout:` |  | ✅ | ❌ | `0xf1ccc` |
| `StoreDialogView` | `-` | `btnAbort:` |  | ✅ | ❌ | `0xf1eb8` |
| `StoreDialogView` | `-` | `delegate` | prop | ✅ | ✅ | `0xf1f98` |
| `StoreDialogView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0xf1fb8` |
| `StoreDialogView` | `-` | `indicatorView` | prop | ✅ | ✅ | `0xf1fcc` |
| `StoreDialogView` | `-` | `setIndicatorView:` | prop | ✅ | ✅ | `0xf1fdc` |
| `StoreDialogView` | `-` | `labelMessage` | prop | ✅ | ✅ | `0xf2014` |
| `StoreDialogView` | `-` | `setLabelMessage:` | prop | ✅ | ✅ | `0xf2024` |
| `StoreDialogView` | `-` | `progressView` | prop | ✅ | ✅ | `0xf205c` |
| `StoreDialogView` | `-` | `setProgressView:` | prop | ✅ | ✅ | `0xf206c` |
| `StoreDialogView` | `-` | `buttonAbort` | prop | ✅ | ✅ | `0xf20a4` |
| `StoreDialogView` | `-` | `setButtonAbort:` | prop | ✅ | ✅ | `0xf20b4` |
| `StoreDownloadTask` | `-` | `initWithURL:path:AddObject:` |  | ✅ | ❌ | `0xf2164` |
| `StoreDownloadTask` | `-` | `dealloc` |  | ❌ | ✅ | `0xf232c` |
| `StoreDownloadTask` | `-` | `fileURL` | prop | ✅ | ✅ | `0xf2360` |
| `StoreDownloadTask` | `-` | `setFileURL:` | prop | ✅ | ✅ | `0xf2370` |
| `StoreDownloadTask` | `-` | `filePath` | prop | ✅ | ✅ | `0xf23a8` |
| `StoreDownloadTask` | `-` | `setFilePath:` | prop | ✅ | ✅ | `0xf23b8` |
| `StoreDownloadTask` | `-` | `addObject` | prop | ✅ | ✅ | `0xf23f0` |
| `StoreDownloadTask` | `-` | `setAddObject:` | prop | ✅ | ✅ | `0xf2400` |
| `StoreDownloadManager` | `-` | `initWithTasks:delegate:` |  | ✅ | ✅ | `0xf2468` |
| `StoreDownloadManager` | `-` | `currentProgress` | prop | ✅ | ✅ | `0xf25c4` |
| `StoreDownloadManager` | `-` | `overallProgress` | prop | ✅ | ✅ | `0xf262c` |
| `StoreDownloadManager` | `-` | `numTasks` | prop | ✅ | ✅ | `0xf268c` |
| `StoreDownloadManager` | `-` | `start` |  | ✅ | ✅ | `0xf26ec` |
| `StoreDownloadManager` | `-` | `cancel` |  | ✅ | ✅ | `0xf299c` |
| `StoreDownloadManager` | `-` | `restart` |  | ✅ | ✅ | `0xf2a88` |
| `StoreDownloadManager` | `-` | `downloaderFinished:` |  | ✅ | ✅ | `0xf2e40` |
| `StoreDownloadManager` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0xf3434` |
| `StoreDownloadManager` | `-` | `downloaderError:` |  | ✅ | ✅ | `0xf3514` |
| `StoreDownloadManager` | `-` | `dealloc` |  | ✅ | ✅ | `0xf3678` |
| `StoreDownloadManager` | `-` | `currentIndex` | prop | ✅ | ✅ | `0xf376c` |
| `StoreDownloadManager` | `-` | `tasks` | prop | ✅ | ✅ | `0xf377c` |
| `StoreDownloadManager` | `-` | `setTasks:` | prop | ✅ | ✅ | `0xf378c` |
| `StoreDownloadManager` | `-` | `delegate` | prop | ✅ | ✅ | `0xf37c4` |
| `StoreDownloadManager` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0xf37e4` |
| `StoreDownloadManager` | `-` | `fileDownloader` | prop | ✅ | ✅ | `0xf37f8` |
| `StoreDownloadManager` | `-` | `setFileDownloader:` | prop | ✅ | ✅ | `0xf3808` |
| `StoreImageView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xf3890` |
| `StoreImageView` | `-` | `startDownloadImage` |  | ✅ | ❌ | `0xf3b44` |
| `StoreImageView` | `-` | `unloadImage:` |  | ✅ | ❌ | `0xf3cec` |
| `StoreImageView` | `-` | `setImage:` |  | ✅ | ❌ | `0xf3de4` |
| `StoreImageView` | `-` | `loadedImage` |  | ✅ | ❌ | `0xf3e90` |
| `StoreImageView` | `-` | `imageDownloader:didLoad:` |  | ✅ | ❌ | `0xf3f00` |
| `StoreImageView` | `-` | `imageDownloaderDidFail:didLoad:` |  | ✅ | ❌ | `0xf4200` |
| `StoreImageView` | `-` | `dealloc` |  | ✅ | ❌ | `0xf4220` |
| `StoreImageView` | `-` | `imageURL` | prop | ✅ | ✅ | `0xf4300` |
| `StoreImageView` | `-` | `setImageURL:` | prop | ✅ | ✅ | `0xf4310` |
| `StoreImageView` | `-` | `imageDownloader` | prop | ✅ | ✅ | `0xf4348` |
| `StoreImageView` | `-` | `setImageDownloader:` | prop | ✅ | ✅ | `0xf4358` |
| `StoreImageView` | `-` | `backgroundView` | prop | ✅ | ✅ | `0xf4390` |
| `StoreImageView` | `-` | `setBackgroundView:` | prop | ✅ | ✅ | `0xf43a0` |
| `StoreImageView` | `-` | `imageView` | prop | ✅ | ✅ | `0xf43d8` |
| `StoreImageView` | `-` | `setImageView:` | prop | ✅ | ✅ | `0xf43e8` |
| `StorePackCell` | `-` | `initWithStyle:reuseIdentifier:` |  | ✅ | ❌ | `0xf4488` |
| `StorePackCell` | `-` | `isPurchased` | prop | ✅ | ❌ | `0xf5528` |
| `StorePackCell` | `-` | `setIsPurchased:` | prop | ✅ | ❌ | `0xf5588` |
| `StorePackCell` | `-` | `loadPackInfo:` |  | ✅ | ❌ | `0xf55e4` |
| `StorePackCell` | `-` | `setBgImage:` |  | ✅ | ❌ | `0xf5898` |
| `StorePackCell` | `-` | `setBgColor:` |  | ✅ | ❌ | `0xf5924` |
| `StorePackCell` | `-` | `artworkView` | prop | ✅ | ✅ | `0xf5a1c` |
| `StorePackCell` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0xf5a2c` |
| `StorePackCell` | `-` | `bgView` | prop | ✅ | ✅ | `0xf5a64` |
| `StorePackCell` | `-` | `setBgView:` | prop | ✅ | ✅ | `0xf5a74` |
| `StorePackCell` | `-` | `labelName` | prop | ✅ | ✅ | `0xf5aac` |
| `StorePackCell` | `-` | `setLabelName:` | prop | ✅ | ✅ | `0xf5abc` |
| `StorePackCell` | `-` | `labelPrice` | prop | ✅ | ✅ | `0xf5af4` |
| `StorePackCell` | `-` | `setLabelPrice:` | prop | ✅ | ✅ | `0xf5b04` |
| `StorePackCell` | `-` | `labelPurchased` | prop | ✅ | ✅ | `0xf5b3c` |
| `StorePackCell` | `-` | `setLabelPurchased:` | prop | ✅ | ✅ | `0xf5b4c` |
| `StorePackCell` | `-` | `iconNew` | prop | ✅ | ✅ | `0xf5b84` |
| `StorePackCell` | `-` | `setIconNew:` | prop | ✅ | ✅ | `0xf5b94` |
| `StorePackCell` | `-` | `iconSp` | prop | ✅ | ✅ | `0xf5bcc` |
| `StorePackCell` | `-` | `setIconSp:` | prop | ✅ | ✅ | `0xf5bdc` |
| `StorePackDetailViewPad` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xf5cb8` |
| `StorePackDetailViewPad` | `-` | `removePackInfo` |  | ✅ | ❌ | `0xf7ddc` |
| `StorePackDetailViewPad` | `-` | `cancelLoading` |  | ✅ | ❌ | `0xf8154` |
| `StorePackDetailViewPad` | `-` | `stopSample` |  | ✅ | ❌ | `0xf8238` |
| `StorePackDetailViewPad` | `-` | `allDownloaded` |  | ✅ | ❌ | `0xf8400` |
| `StorePackDetailViewPad` | `-` | `selfCheckButtonText` |  | ✅ | ❌ | `0xf859c` |
| `StorePackDetailViewPad` | `-` | `setButtonTextBuy` |  | ✅ | ❌ | `0xf8714` |
| `StorePackDetailViewPad` | `-` | `setButtonTextInstall` |  | ✅ | ❌ | `0xf8884` |
| `StorePackDetailViewPad` | `-` | `setButtonTextInstalling` |  | ✅ | ❌ | `0xf8934` |
| `StorePackDetailViewPad` | `-` | `setButtonTextInstalled` |  | ✅ | ❌ | `0xf89e4` |
| `StorePackDetailViewPad` | `-` | `showPackInfo` |  | ✅ | ❌ | `0xf8a94` |
| `StorePackDetailViewPad` | `-` | `loadInfo` |  | ✅ | ❌ | `0xf9330` |
| `StorePackDetailViewPad` | `-` | `doPurchase:` |  | ✅ | ❌ | `0xf9744` |
| `StorePackDetailViewPad` | `-` | `handleLink:` |  | ✅ | ❌ | `0xf99e8` |
| `StorePackDetailViewPad` | `-` | `handleSample:` |  | ✅ | ❌ | `0xf9c88` |
| `StorePackDetailViewPad` | `-` | `selectWebButton` |  | ✅ | ❌ | `0xfa270` |
| `StorePackDetailViewPad` | `-` | `finishBgm:` |  | ✅ | ❌ | `0xfa37c` |
| `StorePackDetailViewPad` | `-` | `showTerm` |  | ✅ | ❌ | `0xfa45c` |
| `StorePackDetailViewPad` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0xfa52c` |
| `StorePackDetailViewPad` | `-` | `downloaderError:` |  | ✅ | ❌ | `0xfa72c` |
| `StorePackDetailViewPad` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0xfa868` |
| `StorePackDetailViewPad` | `-` | `storePackInfoDownloaderFinished:` |  | ✅ | ❌ | `0xfa86c` |
| `StorePackDetailViewPad` | `-` | `storePackInfoDownloaderError:` |  | ✅ | ❌ | `0xfaa58` |
| `StorePackDetailViewPad` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0xfaba4` |
| `StorePackDetailViewPad` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0xfac80` |
| `StorePackDetailViewPad` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0xfac84` |
| `StorePackDetailViewPad` | `-` | `alertViewCancel:` |  | ✅ | ❌ | `0xfac88` |
| `StorePackDetailViewPad` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0xfad64` |
| `StorePackDetailViewPad` | `-` | `switchToSpecialStore:` |  | ✅ | ❌ | `0xfaea4` |
| `StorePackDetailViewPad` | `-` | `packInfo` | prop | ✅ | ✅ | `0xfafe4` |
| `StorePackDetailViewPad` | `-` | `setPackInfo:` | prop | ✅ | ✅ | `0xfaff4` |
| `StorePackDetailViewPad` | `-` | `delegate` | prop | ✅ | ✅ | `0xfb02c` |
| `StorePackDetailViewPad` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0xfb04c` |
| `StorePackDetailViewPad` | `-` | `packView` | prop | ✅ | ✅ | `0xfb060` |
| `StorePackDetailViewPad` | `-` | `setPackView:` | prop | ✅ | ✅ | `0xfb070` |
| `StorePackDetailViewPad` | `-` | `musicViews` | prop | ✅ | ✅ | `0xfb0a8` |
| `StorePackDetailViewPad` | `-` | `setMusicViews:` | prop | ✅ | ✅ | `0xfb0b8` |
| `StorePackDetailViewPad` | `-` | `packArtworkView` | prop | ✅ | ✅ | `0xfb0f0` |
| `StorePackDetailViewPad` | `-` | `setPackArtworkView:` | prop | ✅ | ✅ | `0xfb100` |
| `StorePackDetailViewPad` | `-` | `labelPackName` | prop | ✅ | ✅ | `0xfb138` |
| `StorePackDetailViewPad` | `-` | `setLabelPackName:` | prop | ✅ | ✅ | `0xfb148` |
| `StorePackDetailViewPad` | `-` | `labelComment` | prop | ✅ | ✅ | `0xfb180` |
| `StorePackDetailViewPad` | `-` | `setLabelComment:` | prop | ✅ | ✅ | `0xfb190` |
| `StorePackDetailViewPad` | `-` | `copyrightView` | prop | ✅ | ✅ | `0xfb1c8` |
| `StorePackDetailViewPad` | `-` | `setCopyrightView:` | prop | ✅ | ✅ | `0xfb1d8` |
| `StorePackDetailViewPad` | `-` | `buttonPurchase` | prop | ✅ | ✅ | `0xfb210` |
| `StorePackDetailViewPad` | `-` | `setButtonPurchase:` | prop | ✅ | ✅ | `0xfb220` |
| `StorePackDetailViewPad` | `-` | `indicator` | prop | ✅ | ✅ | `0xfb258` |
| `StorePackDetailViewPad` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0xfb268` |
| `StorePackDetailViewPad` | `-` | `labelLoading` | prop | ✅ | ✅ | `0xfb2a0` |
| `StorePackDetailViewPad` | `-` | `setLabelLoading:` | prop | ✅ | ✅ | `0xfb2b0` |
| `StorePackDetailViewPad` | `-` | `storePackInfoDownloader` | prop | ✅ | ✅ | `0xfb2e8` |
| `StorePackDetailViewPad` | `-` | `setStorePackInfoDownloader:` | prop | ✅ | ✅ | `0xfb2f8` |
| `StorePackDetailViewPad` | `-` | `sampleDownloader` | prop | ✅ | ✅ | `0xfb330` |
| `StorePackDetailViewPad` | `-` | `setSampleDownloader:` | prop | ✅ | ✅ | `0xfb340` |
| `StorePackDetailViewPad` | `-` | `artistSiteButton` | prop | ✅ | ✅ | `0xfb378` |
| `StorePackDetailViewPad` | `-` | `setArtistSiteButton:` | prop | ✅ | ✅ | `0xfb388` |
| `StorePackMusicView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xfb4ec` |
| `StorePackMusicView` | `-` | `setInfo:` |  | ✅ | ❌ | `0xfc814` |
| `StorePackMusicView` | `-` | `sampleStop` |  | ✅ | ❌ | `0xfce3c` |
| `StorePackMusicView` | `-` | `sampleDownloading` |  | ✅ | ❌ | `0xfcf28` |
| `StorePackMusicView` | `-` | `samplePlaying` |  | ✅ | ❌ | `0xfd014` |
| `StorePackMusicView` | `-` | `setBG:` |  | ✅ | ❌ | `0xfd100` |
| `StorePackMusicView` | `-` | `tapSp` |  | ✅ | ❌ | `0xfd208` |
| `StorePackMusicView` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0xfd26c` |
| `StorePackMusicView` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0xfd35c` |
| `StorePackMusicView` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0xfd360` |
| `StorePackMusicView` | `-` | `artworkView` | prop | ✅ | ✅ | `0xfd4a0` |
| `StorePackMusicView` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0xfd4b0` |
| `StorePackMusicView` | `-` | `labelName` | prop | ✅ | ✅ | `0xfd4e8` |
| `StorePackMusicView` | `-` | `setLabelName:` | prop | ✅ | ✅ | `0xfd4f8` |
| `StorePackMusicView` | `-` | `labelArtist` | prop | ✅ | ✅ | `0xfd530` |
| `StorePackMusicView` | `-` | `setLabelArtist:` | prop | ✅ | ✅ | `0xfd540` |
| `StorePackMusicView` | `-` | `labelLevels` | prop | ✅ | ✅ | `0xfd578` |
| `StorePackMusicView` | `-` | `setLabelLevels:` | prop | ✅ | ✅ | `0xfd588` |
| `StorePackMusicView` | `-` | `buttonSample` | prop | ✅ | ✅ | `0xfd5c0` |
| `StorePackMusicView` | `-` | `setButtonSample:` | prop | ✅ | ✅ | `0xfd5d0` |
| `StorePackMusicView` | `-` | `buttonLink` | prop | ✅ | ✅ | `0xfd608` |
| `StorePackMusicView` | `-` | `setButtonLink:` | prop | ✅ | ✅ | `0xfd618` |
| `StorePackMusicView` | `-` | `parent` | prop | ✅ | ✅ | `0xfd650` |
| `StorePackMusicView` | `-` | `setParent:` | prop | ✅ | ✅ | `0xfd670` |
| `StorePackMusicView` | `-` | `iconSpView` | prop | ✅ | ✅ | `0xfd684` |
| `StorePackMusicView` | `-` | `setIconSpView:` | prop | ✅ | ✅ | `0xfd694` |
| `StorePackMusicView` | `-` | `indicatorSample` | prop | ✅ | ✅ | `0xfd6cc` |
| `StorePackMusicView` | `-` | `setIndicatorSample:` | prop | ✅ | ✅ | `0xfd6dc` |
| `StorePackMusicView` | `-` | `bg` | prop | ✅ | ✅ | `0xfd714` |
| `StorePackMusicView` | `-` | `setBg:` | prop | ✅ | ✅ | `0xfd724` |
| `StorePackMusicView` | `-` | `pid` | prop | ✅ | ✅ | `0xfd75c` |
| `StorePackMusicView` | `-` | `setPid:` | prop | ✅ | ✅ | `0xfd76c` |
| `StorePackView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xfd858` |
| `StorePackView` | `-` | `dealloc` |  | ✅ | ❌ | `0xfe958` |
| `StorePackView` | `-` | `setBgImage:` |  | ✅ | ❌ | `0xfe9e0` |
| `StorePackView` | `-` | `setArtwork:` |  | ✅ | ❌ | `0xfea6c` |
| `StorePackView` | `-` | `handleTap:` |  | ✅ | ❌ | `0xfeaf8` |
| `StorePackView` | `-` | `isPurchased` |  | ✅ | ❌ | `0xfebd8` |
| `StorePackView` | `-` | `setIsPurchased:` |  | ✅ | ❌ | `0xfec38` |
| `StorePackView` | `-` | `loadPackInfo:index:` |  | ✅ | ❌ | `0xfec94` |
| `StorePackView` | `-` | `delegate` | prop | ✅ | ✅ | `0xfefc0` |
| `StorePackView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0xfefe0` |
| `StorePackView` | `-` | `index` | prop | ✅ | ✅ | `0xfeff4` |
| `StorePackView` | `-` | `backGroundImageView` | prop | ✅ | ✅ | `0xff004` |
| `StorePackView` | `-` | `setBackGroundImageView:` | prop | ✅ | ✅ | `0xff014` |
| `StorePackView` | `-` | `artworkImageView` | prop | ✅ | ✅ | `0xff04c` |
| `StorePackView` | `-` | `setArtworkImageView:` | prop | ✅ | ✅ | `0xff05c` |
| `StorePackView` | `-` | `artworkBackImageView` | prop | ✅ | ✅ | `0xff094` |
| `StorePackView` | `-` | `setArtworkBackImageView:` | prop | ✅ | ✅ | `0xff0a4` |
| `StorePackView` | `-` | `nameLabel` | prop | ✅ | ✅ | `0xff0dc` |
| `StorePackView` | `-` | `setNameLabel:` | prop | ✅ | ✅ | `0xff0ec` |
| `StorePackView` | `-` | `commentLabel` | prop | ✅ | ✅ | `0xff124` |
| `StorePackView` | `-` | `setCommentLabel:` | prop | ✅ | ✅ | `0xff134` |
| `StorePackView` | `-` | `priceLabel` | prop | ✅ | ✅ | `0xff16c` |
| `StorePackView` | `-` | `setPriceLabel:` | prop | ✅ | ✅ | `0xff17c` |
| `StorePackView` | `-` | `purchasedButton` | prop | ✅ | ✅ | `0xff1b4` |
| `StorePackView` | `-` | `setPurchasedButton:` | prop | ✅ | ✅ | `0xff1c4` |
| `StorePackView` | `-` | `iconNew` | prop | ✅ | ✅ | `0xff1fc` |
| `StorePackView` | `-` | `setIconNew:` | prop | ✅ | ✅ | `0xff20c` |
| `StorePackView` | `-` | `iconSp` | prop | ✅ | ✅ | `0xff244` |
| `StorePackView` | `-` | `setIconSp:` | prop | ✅ | ✅ | `0xff254` |
| `StorePromotionTableCell` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0xff368` |
| `PagingScrollView` | `-` | `hitTest:withEvent:` |  | ✅ | ❌ | `0xff494` |
| `BannerView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xff624` |
| `BannerView` | `-` | `setCornerRadius:` |  | ✅ | ❌ | `0xff910` |
| `BannerView` | `-` | `startSamplePlay` |  | ✅ | ✅ | `0xff9c8` |
| `BannerView` | `-` | `stopSamplePlay` |  | ✅ | ✅ | `0xff9d8` |
| `BannerView` | `-` | `getIsSamplePlaying` |  | ✅ | ✅ | `0xff9e8` |
| `BannerView` | `-` | `imageView` | prop | ✅ | ✅ | `0xff9f4` |
| `BannerView` | `-` | `setImageView:` | prop | ✅ | ✅ | `0xffa04` |
| `BannerView` | `-` | `packInfo` | prop | ✅ | ✅ | `0xffa3c` |
| `BannerView` | `-` | `setPackInfo:` | prop | ✅ | ✅ | `0xffa4c` |
| `BannerView` | `-` | `sampleData` | prop | ✅ | ✅ | `0xffa84` |
| `BannerView` | `-` | `setSampleData:` | prop | ✅ | ✅ | `0xffa94` |
| `BannerView` | `-` | `musicName` | prop | ✅ | ✅ | `0xffacc` |
| `BannerView` | `-` | `setMusicName:` | prop | ✅ | ✅ | `0xffadc` |
| `BannerView` | `-` | `isSamplePlaying` | prop | ✅ | ✅ | `0xffb14` |
| `BannerView` | `-` | `setIsSamplePlaying:` | prop | ✅ | ✅ | `0xffb24` |
| `BannerView` | `-` | `isRemoveWaiting` | prop | ✅ | ✅ | `0xffb34` |
| `BannerView` | `-` | `setIsRemoveWaiting:` | prop | ✅ | ✅ | `0xffb44` |
| `StorePromotionView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0xffbbc` |
| `StorePromotionView` | `-` | `dealloc` |  | ✅ | ❌ | `0xffcf8` |
| `StorePromotionView` | `-` | `cancel` |  | ✅ | ❌ | `0x100138` |
| `StorePromotionView` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x100464` |
| `StorePromotionView` | `-` | `SetupView` |  | ✅ | ❌ | `0x100498` |
| `StorePromotionView` | `-` | `setImageViewSize:` |  | ✅ | ✅ | `0x1008c8` |
| `StorePromotionView` | `-` | `getPackID` |  | ✅ | ❌ | `0x1008cc` |
| `StorePromotionView` | `-` | `setImageURLs:` |  | ✅ | ❌ | `0x1009e8` |
| `StorePromotionView` | `-` | `imageDownloader:didLoad:` |  | ✅ | ❌ | `0x101788` |
| `StorePromotionView` | `-` | `imageDownloaderDidFail:didLoad:` |  | ✅ | ❌ | `0x101898` |
| `StorePromotionView` | `-` | `getImageCount` |  | ✅ | ❌ | `0x101924` |
| `StorePromotionView` | `-` | `setNext` |  | ✅ | ❌ | `0x101984` |
| `StorePromotionView` | `-` | `nextShowEnd` |  | ✅ | ✅ | `0x102280` |
| `StorePromotionView` | `-` | `setImage:Index:` |  | ✅ | ❌ | `0x102284` |
| `StorePromotionView` | `-` | `startSamplePlay` |  | ✅ | ✅ | `0x102a14` |
| `StorePromotionView` | `-` | `stopSamplePlay` |  | ✅ | ❌ | `0x102a20` |
| `StorePromotionView` | `-` | `startAnimation` |  | ✅ | ❌ | `0x102b04` |
| `StorePromotionView` | `-` | `stopAnimation` |  | ✅ | ❌ | `0x103048` |
| `StorePromotionView` | `-` | `bannerTapped:` |  | ✅ | ❌ | `0x1030f0` |
| `StorePromotionView` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x1032e4` |
| `StorePromotionView` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x1037fc` |
| `StorePromotionView` | `-` | `scrollViewWillBeginDragging:` |  | ✅ | ❌ | `0x103a50` |
| `StorePromotionView` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x103a6c` |
| `StorePromotionView` | `-` | `scrollViewDidEndDragging:willDecelerate:` |  | ✅ | ✅ | `0x103c48` |
| `StorePromotionView` | `-` | `scrollViewWillBeginDecelerating:` |  | ✅ | ✅ | `0x103c4c` |
| `StorePromotionView` | `-` | `scrollViewDidEndDecelerating:` |  | ✅ | ❌ | `0x103c50` |
| `StorePromotionView` | `-` | `scrollViewDidRotate:` |  | ✅ | ❌ | `0x103c6c` |
| `StorePromotionView` | `-` | `delegate` | prop | ✅ | ✅ | `0x103f58` |
| `StorePromotionView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x103f78` |
| `StorePromotionView` | `-` | `isSamplePlayable` | prop | ✅ | ✅ | `0x103f8c` |
| `StorePromotionView` | `-` | `setIsSamplePlayable:` | prop | ✅ | ✅ | `0x103f9c` |
| `StorePromotionView` | `-` | `scrollView` | prop | ✅ | ✅ | `0x103fac` |
| `StorePromotionView` | `-` | `setScrollView:` | prop | ✅ | ✅ | `0x103fbc` |
| `StorePromotionView` | `-` | `pageWidth` | prop | ✅ | ✅ | `0x103ff4` |
| `StorePromotionView` | `-` | `setPageWidth:` | prop | ✅ | ✅ | `0x104004` |
| `StorePromotionView` | `-` | `pageOffsetX` | prop | ✅ | ✅ | `0x104014` |
| `StorePromotionView` | `-` | `setPageOffsetX:` | prop | ✅ | ✅ | `0x104024` |
| `StorePromotionView` | `-` | `bannerOffset` | prop | ✅ | ✅ | `0x104034` |
| `StorePromotionView` | `-` | `setBannerOffset:` | prop | ✅ | ✅ | `0x104048` |
| `StorePromotionView` | `-` | `indicator` | prop | ✅ | ✅ | `0x10405c` |
| `StorePromotionView` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x10406c` |
| `StorePromotionView` | `-` | `timer` | prop | ✅ | ✅ | `0x1040a4` |
| `StorePromotionView` | `-` | `setTimer:` | prop | ✅ | ✅ | `0x1040b4` |
| `StorePromotionView` | `-` | `bannerViewArray` | prop | ✅ | ✅ | `0x1040ec` |
| `StorePromotionView` | `-` | `setBannerViewArray:` | prop | ✅ | ✅ | `0x1040fc` |
| `StorePromotionView` | `-` | `promotionDataArray` | prop | ✅ | ✅ | `0x104134` |
| `StorePromotionView` | `-` | `setPromotionDataArray:` | prop | ✅ | ✅ | `0x104144` |
| `StorePromotionView` | `-` | `imageDownloader` | prop | ✅ | ✅ | `0x10417c` |
| `StorePromotionView` | `-` | `setImageDownloader:` | prop | ✅ | ✅ | `0x10418c` |
| `StorePromotionView` | `-` | `sampleDownloader` | prop | ❌ | ✅ | `0x1041c4` |
| `StorePromotionView` | `-` | `setSampleDownloader:` | prop | ❌ | ✅ | `0x1041d4` |
| `StoreTableCell` | `-` | `initWithStyle:reuseIdentifier:` |  | ✅ | ❌ | `0x1042c0` |
| `StoreTableCell` | `-` | `dealloc` |  | ✅ | ❌ | `0x104628` |
| `StoreTableCell` | `-` | `prepareForReuse` |  | ✅ | ❌ | `0x10471c` |
| `StoreTableCell` | `-` | `leftPackView` | prop | ✅ | ✅ | `0x1047ec` |
| `StoreTableCell` | `-` | `setLeftPackView:` | prop | ✅ | ✅ | `0x1047fc` |
| `StoreTableCell` | `-` | `rightPackView` | prop | ✅ | ✅ | `0x104834` |
| `StoreTableCell` | `-` | `setRightPackView:` | prop | ✅ | ✅ | `0x104844` |
| `ReplayData` | `-` | `initWithCoder:` |  | ✅ | ❌ | `0x1048bc` |
| `ReplayData` | `-` | `encodeWithCoder:` |  | ✅ | ❌ | `0x104df4` |
| `ReplayData` | `-` | `init` |  | ✅ | ❌ | `0x105290` |
| `ReplayData` | `-` | `reset` |  | ✅ | ❌ | `0x105304` |
| `ReplayData` | `+` | `isExistReplayData:difficulty:` |  | ✅ | ❌ | `0x10546c` |
| `ReplayData` | `+` | `loadReplayData:difficulty:` |  | ✅ | ❌ | `0x1055b4` |
| `ReplayData` | `+` | `saveReplayData:` |  | ✅ | ❌ | `0x1059b4` |
| `ReplayData` | `+` | `convertLocalDate:` |  | ✅ | ❌ | `0x105fc0` |
| `ReplayData` | `+` | `encode:` |  | ✅ | ❌ | `0x1060a0` |
| `ReplayData` | `+` | `decode:` |  | ✅ | ❌ | `0x106204` |
| `ReplayData` | `-` | `version` | prop | ✅ | ✅ | `0x106368` |
| `ReplayData` | `-` | `setVersion:` | prop | ✅ | ✅ | `0x106378` |
| `ReplayData` | `-` | `tuneID` | prop | ✅ | ✅ | `0x1063b0` |
| `ReplayData` | `-` | `setTuneID:` | prop | ✅ | ✅ | `0x1063c0` |
| `ReplayData` | `-` | `diff` | prop | ✅ | ✅ | `0x1063f8` |
| `ReplayData` | `-` | `setDiff:` | prop | ✅ | ✅ | `0x106408` |
| `ReplayData` | `-` | `seed` | prop | ✅ | ✅ | `0x106440` |
| `ReplayData` | `-` | `setSeed:` | prop | ✅ | ✅ | `0x106450` |
| `ReplayData` | `-` | `cntNote` | prop | ✅ | ✅ | `0x106488` |
| `ReplayData` | `-` | `setCntNote:` | prop | ✅ | ✅ | `0x106498` |
| `ReplayData` | `-` | `score` | prop | ✅ | ✅ | `0x1064d0` |
| `ReplayData` | `-` | `setScore:` | prop | ✅ | ✅ | `0x1064e0` |
| `ReplayData` | `-` | `cntCom` | prop | ✅ | ✅ | `0x106518` |
| `ReplayData` | `-` | `setCntCom:` | prop | ✅ | ✅ | `0x106528` |
| `ReplayData` | `-` | `cntJust` | prop | ✅ | ✅ | `0x106560` |
| `ReplayData` | `-` | `setCntJust:` | prop | ✅ | ✅ | `0x106570` |
| `ReplayData` | `-` | `cntGreat` | prop | ✅ | ✅ | `0x1065a8` |
| `ReplayData` | `-` | `setCntGreat:` | prop | ✅ | ✅ | `0x1065b8` |
| `ReplayData` | `-` | `cntGood` | prop | ✅ | ✅ | `0x1065f0` |
| `ReplayData` | `-` | `setCntGood:` | prop | ✅ | ✅ | `0x106600` |
| `ReplayData` | `-` | `cntMiss` | prop | ✅ | ✅ | `0x106638` |
| `ReplayData` | `-` | `setCntMiss:` | prop | ✅ | ✅ | `0x106648` |
| `ReplayData` | `-` | `cntJR` | prop | ✅ | ✅ | `0x106680` |
| `ReplayData` | `-` | `setCntJR:` | prop | ✅ | ✅ | `0x106690` |
| `ReplayData` | `-` | `ar` | prop | ✅ | ✅ | `0x1066c8` |
| `ReplayData` | `-` | `setAr:` | prop | ✅ | ✅ | `0x1066d8` |
| `ReplayData` | `-` | `playDate` | prop | ✅ | ✅ | `0x106710` |
| `ReplayData` | `-` | `setPlayDate:` | prop | ✅ | ✅ | `0x106720` |
| `ReplayData` | `-` | `user` | prop | ✅ | ✅ | `0x106758` |
| `ReplayData` | `-` | `setUser:` | prop | ✅ | ✅ | `0x106768` |
| `ReplayData` | `-` | `chksco` | prop | ✅ | ✅ | `0x1067a0` |
| `ReplayData` | `-` | `setChksco:` | prop | ✅ | ✅ | `0x1067b0` |
| `ReplayData` | `-` | `replay` | prop | ✅ | ✅ | `0x1067e8` |
| `ReplayData` | `-` | `setReplay:` | prop | ✅ | ✅ | `0x1067f8` |
| `ReplayData` | `-` | `replay2` | prop | ✅ | ✅ | `0x106830` |
| `ReplayData` | `-` | `setReplay2:` | prop | ✅ | ✅ | `0x106840` |
| `ReplayNote` | `-` | `initWithCoder:` |  | ✅ | ❌ | `0x1069f8` |
| `ReplayNote` | `-` | `encodeWithCoder:` |  | ✅ | ❌ | `0x106c44` |
| `ReplayNote` | `-` | `index` | prop | ✅ | ✅ | `0x106e4c` |
| `ReplayNote` | `-` | `setIndex:` | prop | ✅ | ✅ | `0x106e5c` |
| `ReplayNote` | `-` | `type` | prop | ✅ | ✅ | `0x106e94` |
| `ReplayNote` | `-` | `setType:` | prop | ✅ | ✅ | `0x106ea4` |
| `ReplayNote` | `-` | `judge` | prop | ✅ | ✅ | `0x106edc` |
| `ReplayNote` | `-` | `setJudge:` | prop | ✅ | ✅ | `0x106eec` |
| `ReplayNote` | `-` | `jr` | prop | ✅ | ✅ | `0x106f24` |
| `ReplayNote` | `-` | `setJr:` | prop | ✅ | ✅ | `0x106f34` |
| `ReplayNote` | `-` | `longrate` | prop | ✅ | ✅ | `0x106f6c` |
| `ReplayNote` | `-` | `setLongrate:` | prop | ✅ | ✅ | `0x106f7c` |
| `ReplayNote` | `-` | `slide` | prop | ✅ | ✅ | `0x106fb4` |
| `ReplayNote` | `-` | `setSlide:` | prop | ✅ | ✅ | `0x106fc4` |
| `RBThemaView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x107104` |
| `RBThemaView` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x1071a8` |
| `RBThemaView` | `-` | `setupView` |  | ✅ | ❌ | `0x107234` |
| `RBThemaView` | `-` | `yesButtonTouch:` |  | ✅ | ❌ | `0x108434` |
| `RBThemaView` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x108740` |
| `RBThemaView` | `-` | `settingView` | prop | ✅ | ✅ | `0x108928` |
| `RBThemaView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0x108948` |
| `RBThemaView` | `-` | `scrollView` | prop | ✅ | ✅ | `0x10895c` |
| `RBThemaView` | `-` | `setScrollView:` | prop | ✅ | ✅ | `0x10896c` |
| `RBThemaView` | `-` | `classicView` | prop | ✅ | ✅ | `0x1089a4` |
| `RBThemaView` | `-` | `setClassicView:` | prop | ✅ | ✅ | `0x1089b4` |
| `RBThemaView` | `-` | `limelightView` | prop | ✅ | ✅ | `0x1089ec` |
| `RBThemaView` | `-` | `setLimelightView:` | prop | ✅ | ✅ | `0x1089fc` |
| `RBThemaView` | `-` | `coletteView` | prop | ✅ | ✅ | `0x108a34` |
| `RBThemaView` | `-` | `setColetteView:` | prop | ✅ | ✅ | `0x108a44` |
| `RBThemaView` | `-` | `okButton` | prop | ✅ | ✅ | `0x108a7c` |
| `RBThemaView` | `-` | `setOkButton:` | prop | ✅ | ✅ | `0x108a8c` |
| `RBThemaView` | `-` | `thema` | prop | ✅ | ✅ | `0x108ac4` |
| `RBThemaView` | `-` | `setThema:` | prop | ✅ | ✅ | `0x108ad4` |
| `RBThemaView` | `-` | `unlockedThemaCount` | prop | ✅ | ✅ | `0x108ae4` |
| `RBThemaView` | `-` | `setUnlockedThemaCount:` | prop | ✅ | ✅ | `0x108af4` |
| `StoreCampaignItemInfo` | `-` | `initWithDictionary:` |  | ✅ | ❌ | `0x108b90` |
| `StoreCampaignItemInfo` | `-` | `termCheck` |  | ✅ | ❌ | `0x109088` |
| `StoreCampaignItemInfo` | `-` | `checkExistPackList:packID:` |  | ✅ | ❌ | `0x1096c4` |
| `StoreCampaignItemInfo` | `-` | `checkNewUnlock` |  | ✅ | ❌ | `0x109850` |
| `StoreCampaignItemInfo` | `-` | `hasItem:itemID:` |  | ✅ | ❌ | `0x109898` |
| `StoreCampaignItemInfo` | `-` | `registSuccess` |  | ✅ | ❌ | `0x1099ac` |
| `StoreCampaignItemInfo` | `+` | `getButtonColor:` |  | ✅ | ❌ | `0x1099cc` |
| `StoreCampaignItemInfo` | `+` | `getButtonName:` |  | ✅ | ❌ | `0x109b10` |
| `StoreCampaignItemInfo` | `-` | `campaignID` | prop | ✅ | ✅ | `0x109bb8` |
| `StoreCampaignItemInfo` | `-` | `campaignName` | prop | ✅ | ✅ | `0x109bc8` |
| `StoreCampaignItemInfo` | `-` | `campaignDescription` | prop | ✅ | ✅ | `0x109bd8` |
| `StoreCampaignItemInfo` | `-` | `campaignTermsDescription` | prop | ✅ | ✅ | `0x109be8` |
| `StoreCampaignItemInfo` | `-` | `campaignBannerURL` | prop | ✅ | ✅ | `0x109bf8` |
| `StoreCampaignItemInfo` | `-` | `bServerUnlock` | prop | ✅ | ✅ | `0x109c08` |
| `StoreCampaignItemInfo` | `-` | `itemType` | prop | ✅ | ✅ | `0x109c18` |
| `StoreCampaignItemInfo` | `-` | `itemID` | prop | ✅ | ✅ | `0x109c28` |
| `StoreCampaignItemInfo` | `-` | `thumbnailURL` | prop | ✅ | ✅ | `0x109c38` |
| `StoreCampaignItemInfo` | `-` | `alreadyDownload` | prop | ✅ | ✅ | `0x109c48` |
| `StoreCampaignItemInfo` | `-` | `bUnlock` | prop | ✅ | ✅ | `0x109c58` |
| `StoreCampaignItemInfo` | `-` | `buttonType` | prop | ✅ | ✅ | `0x109c68` |
| `StoreCampaignItemInfo` | `-` | `hideType` | prop | ✅ | ✅ | `0x109c78` |
| `StoreCampaignItemInfo` | `-` | `linkURL` | prop | ✅ | ✅ | `0x109c88` |
| `StoreCampaignItemInfo` | `-` | `copyright` | prop | ✅ | ✅ | `0x109c98` |
| `StoreCampaignItemInfo` | `-` | `unlockDict` | prop | ✅ | ✅ | `0x109ca8` |
| `RBRewardListView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x10cfa4` |
| `RBRewardListView` | `-` | `setParentView:` |  | ✅ | ❌ | `0x10d018` |
| `RBRewardListView` | `-` | `setupView` |  | ✅ | ❌ | `0x10d034` |
| `RBRewardListView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x10d758` |
| `RBRewardListView` | `-` | `loadStart` |  | ✅ | ❌ | `0x10d824` |
| `RBRewardListView` | `-` | `pushCloseButton` |  | ✅ | ✅ | `0x10d918` |
| `RBRewardListView` | `-` | `appListDidAppear` |  | ✅ | ❌ | `0x10d924` |
| `RBRewardListView` | `-` | `appListDidDisappear` |  | ✅ | ❌ | `0x10db9c` |
| `RBRewardListView` | `-` | `appListFailLoadWithError:` |  | ✅ | ❌ | `0x10dcb0` |
| `RBRewardListView` | `-` | `parentCustomView` | prop | ✅ | ✅ | `0x10ddc4` |
| `RBRewardListView` | `-` | `setParentCustomView:` | prop | ✅ | ✅ | `0x10dde4` |
| `RBRewardListView` | `-` | `indicatorView` | prop | ✅ | ✅ | `0x10ddf8` |
| `RBRewardListView` | `-` | `setIndicatorView:` | prop | ✅ | ✅ | `0x10de08` |
| `RBRewardListView` | `-` | `webTargetView` | prop | ✅ | ✅ | `0x10de40` |
| `RBRewardListView` | `-` | `setWebTargetView:` | prop | ✅ | ✅ | `0x10de50` |
| `RBRewardListView` | `-` | `backButton` | prop | ✅ | ✅ | `0x10de88` |
| `RBRewardListView` | `-` | `setBackButton:` | prop | ✅ | ✅ | `0x10de98` |
| `RBRewardListView` | `-` | `animating` | prop | ✅ | ✅ | `0x10ded0` |
| `RBRewardListView` | `-` | `setAnimating:` | prop | ✅ | ✅ | `0x10dee0` |
| `RBRewardListView` | `-` | `webTargetAnimating` | prop | ✅ | ✅ | `0x10def0` |
| `RBRewardListView` | `-` | `setWebTargetAnimating:` | prop | ✅ | ✅ | `0x10df00` |
| `RBMusicSpeedView` | `-` | `initWithFrame:MusicSelectedBase:` |  | ✅ | ❌ | `0x10df74` |
| `RBMusicSpeedView` | `-` | `dealloc` |  | ❌ | ✅ | `0x10e124` |
| `RBMusicSpeedView` | `-` | `SetupView` |  | ✅ | ❌ | `0x10e158` |
| `RBMusicSpeedView` | `-` | `tap:` |  | ✅ | ❌ | `0x10eb9c` |
| `RBMusicSpeedView` | `-` | `SelectSpeed:` |  | ✅ | ❌ | `0x10eda0` |
| `RBMusicSpeedView` | `-` | `speed` | prop | ✅ | ✅ | `0x10f0d0` |
| `RBMusicSpeedView` | `-` | `setSpeed:` | prop | ✅ | ✅ | `0x10f0e0` |
| `RBMusicSpeedView` | `-` | `musicSelectedBase` | prop | ✅ | ✅ | `0x10f0f0` |
| `RBMusicSpeedView` | `-` | `setMusicSelectedBase:` | prop | ✅ | ✅ | `0x10f110` |
| `RBMusicSpeedView` | `-` | `selectedImage` | prop | ✅ | ✅ | `0x10f124` |
| `RBMusicSpeedView` | `-` | `setSelectedImage:` | prop | ✅ | ✅ | `0x10f134` |
| `RBMusicSpeedView` | `-` | `sliderView` | prop | ✅ | ✅ | `0x10f16c` |
| `RBMusicSpeedView` | `-` | `setSliderView:` | prop | ✅ | ✅ | `0x10f17c` |
| `RBMusicSpeedView` | `-` | `barBase` | prop | ✅ | ✅ | `0x10f1b4` |
| `RBMusicSpeedView` | `-` | `setBarBase:` | prop | ✅ | ✅ | `0x10f1c4` |
| `RBMusicSpeedView` | `-` | `sliderType` | prop | ✅ | ✅ | `0x10f1fc` |
| `RBMusicSpeedView` | `-` | `setSliderType:` | prop | ✅ | ✅ | `0x10f20c` |
| `RBTermView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x110064` |
| `RBTermView` | `-` | `setViewTypeStore` |  | ✅ | ✅ | `0x11019c` |
| `RBTermView` | `-` | `setupView` |  | ✅ | ❌ | `0x1101ac` |
| `RBTermView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x1116c4` |
| `RBTermView` | `-` | `loadList` |  | ✅ | ❌ | `0x1118dc` |
| `RBTermView` | `-` | `showTermsList` |  | ✅ | ❌ | `0x112084` |
| `RBTermView` | `-` | `selectTerm:` |  | ✅ | ❌ | `0x112c2c` |
| `RBTermView` | `-` | `loadDetail:` |  | ✅ | ❌ | `0x11307c` |
| `RBTermView` | `-` | `showTermView:` |  | ✅ | ❌ | `0x113948` |
| `RBTermView` | `-` | `startLoadAnimation` |  | ✅ | ❌ | `0x1142b8` |
| `RBTermView` | `-` | `endLoadAnimation` |  | ✅ | ❌ | `0x11436c` |
| `RBTermView` | `-` | `setTermsTitle:` |  | ✅ | ❌ | `0x114420` |
| `RBTermView` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x1147bc` |
| `RBTermView` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0x114848` |
| `RBTermView` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x11484c` |
| `RBTermView` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0x114850` |
| `RBTermView` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x114854` |
| `RBTermView` | `-` | `supportedInterfaceOrientations` |  | ✅ | ✅ | `0x114864` |
| `RBTermView` | `-` | `shouldAutorotate` |  | ✅ | ✅ | `0x11486c` |
| `RBTermView` | `-` | `dealloc` |  | ❌ | ✅ | `0x114874` |
| `RBTermView` | `-` | `settingView` | prop | ✅ | ✅ | `0x1148a8` |
| `RBTermView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0x1148c8` |
| `RBTermView` | `-` | `isFirstRequest` | prop | ✅ | ✅ | `0x1148dc` |
| `RBTermView` | `-` | `setIsFirstRequest:` | prop | ✅ | ✅ | `0x1148ec` |
| `RBTermView` | `-` | `isAnimating` | prop | ✅ | ✅ | `0x1148fc` |
| `RBTermView` | `-` | `setIsAnimating:` | prop | ✅ | ✅ | `0x11490c` |
| `RBTermView` | `-` | `backButton` | prop | ✅ | ✅ | `0x11491c` |
| `RBTermView` | `-` | `setBackButton:` | prop | ✅ | ✅ | `0x11492c` |
| `RBTermView` | `-` | `titleView` | prop | ✅ | ✅ | `0x11493c` |
| `RBTermView` | `-` | `setTitleView:` | prop | ✅ | ✅ | `0x11494c` |
| `RBTermView` | `-` | `termsListView` | prop | ✅ | ✅ | `0x11495c` |
| `RBTermView` | `-` | `setTermsListView:` | prop | ✅ | ✅ | `0x11496c` |
| `RBTermView` | `-` | `termView` | prop | ✅ | ✅ | `0x11497c` |
| `RBTermView` | `-` | `setTermView:` | prop | ✅ | ✅ | `0x11498c` |
| `RBTermView` | `-` | `termTextView` | prop | ✅ | ✅ | `0x11499c` |
| `RBTermView` | `-` | `setTermTextView:` | prop | ✅ | ✅ | `0x1149ac` |
| `RBTermView` | `-` | `termsList` | prop | ✅ | ✅ | `0x1149bc` |
| `RBTermView` | `-` | `setTermsList:` | prop | ✅ | ✅ | `0x1149cc` |
| `RBTermView` | `-` | `terms` | prop | ✅ | ✅ | `0x114a04` |
| `RBTermView` | `-` | `setTerms:` | prop | ✅ | ✅ | `0x114a14` |
| `RBTermView` | `-` | `downloader` | prop | ✅ | ✅ | `0x114a4c` |
| `RBTermView` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x114a5c` |
| `RBTermView` | `-` | `isUseGrayView` | prop | ✅ | ✅ | `0x114a94` |
| `RBTermView` | `-` | `setIsUseGrayView:` | prop | ✅ | ✅ | `0x114aa4` |
| `RBTermView` | `-` | `grayView` | prop | ✅ | ✅ | `0x114ab4` |
| `RBTermView` | `-` | `setGrayView:` | prop | ✅ | ✅ | `0x114ac4` |
| `RBTermView` | `-` | `indicatorView` | prop | ✅ | ✅ | `0x114ad4` |
| `RBTermView` | `-` | `setIndicatorView:` | prop | ✅ | ✅ | `0x114ae4` |
| `RBTermView` | `-` | `viewType` | prop | ✅ | ✅ | `0x114af4` |
| `RBTermView` | `-` | `setViewType:` | prop | ✅ | ✅ | `0x114b04` |
| `(FromData)` | `+` | `arrayFromPropertyListData:` |  | ✅ | ❌ | `0x12f410` |
| `RBMenuTutorialView` | `-` | `initWithFrame:` |  | ✅ | ✅ | `0x137b0c` |
| `RBMenuTutorialView` | `-` | `setupView` |  | ✅ | ✅ | `0x137bfc` |
| `RBMenuTutorialView` | `-` | `showAnimationWithTutorialType:withRootView:` |  | ✅ | ✅ | `0x139af8` |
| `RBMenuTutorialView` | `-` | `hideAnimation` |  | ✅ | ✅ | `0x139e04` |
| `RBMenuTutorialView` | `-` | `tap:` |  | ✅ | ✅ | `0x13aac4` |
| `RBMenuTutorialView` | `-` | `startTutorialWithType:withAnimation:` |  | ✅ | ✅ | `0x13ab34` |
| `RBMenuTutorialView` | `-` | `startTutorialWithType:withRootView:` |  | ✅ | ✅ | `0x13b8fc` |
| `RBMenuTutorialView` | `-` | `setClipRect` |  | ✅ | ✅ | `0x13b974` |
| `RBMenuTutorialView` | `-` | `layoutBackground:withAnimation:` |  | ✅ | ✅ | `0x13ba8c` |
| `RBMenuTutorialView` | `-` | `hitTest:withEvent:` |  | ✅ | ✅ | `0x13c8a0` |
| `RBMenuTutorialView` | `-` | `willRotate` |  | ✅ | ✅ | `0x13cb4c` |
| `RBMenuTutorialView` | `-` | `didRotate` |  | ✅ | ✅ | `0x13cdd4` |
| `RBMenuTutorialView` | `-` | `contentViewSettingWithTouchAnim:cursorAnim:stay:useAnimation:` |  | ✅ | ✅ | `0x13cfe8` |
| `RBMenuTutorialView` | `-` | `startCursorAnimation:` |  | ✅ | ✅ | `0x13d510` |
| `RBMenuTutorialView` | `-` | `stopCursorAnimation:` |  | ✅ | ❌ | `0x13d878` |
| `RBMenuTutorialView` | `-` | `startTouchAnimation:` |  | ✅ | ❌ | `0x13d920` |
| `RBMenuTutorialView` | `-` | `stopTouchAnimation:` |  | ✅ | ❌ | `0x13dbc4` |
| `RBMenuTutorialView` | `-` | `animationDelete:` |  | ✅ | ❌ | `0x13dc6c` |
| `RBMenuTutorialView` | `-` | `startAnimation:` |  | ✅ | ❌ | `0x13de2c` |
| `RBMenuTutorialView` | `-` | `resetAnimation:` |  | ✅ | ❌ | `0x13f7f0` |
| `RBMenuTutorialView` | `-` | `getTextureType` |  | ✅ | ❌ | `0x14040c` |
| `RBMenuTutorialView` | `-` | `getClipRect:` |  | ✅ | ❌ | `0x140544` |
| `RBMenuTutorialView` | `-` | `animationDidStop:finished:` |  | ✅ | ❌ | `0x1405a8` |
| `RBMenuTutorialView` | `+` | `createAnimWithKeyPath:fromValue:toValue:delay:duration:` |  | ❌ | ❌ | `0x1405c8` |
| `RBMenuTutorialView` | `-` | `dealloc` |  | ✅ | ✅ | `0x140cd0` |
| `RBMenuTutorialView` | `-` | `musicMenuView` | prop | ✅ | ✅ | `0x140d04` |
| `RBMenuTutorialView` | `-` | `setMusicMenuView:` | prop | ✅ | ✅ | `0x140d24` |
| `RBMenuTutorialView` | `-` | `baseView` | prop | ✅ | ✅ | `0x140d38` |
| `RBMenuTutorialView` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x140d48` |
| `RBMenuTutorialView` | `-` | `animating` | prop | ✅ | ✅ | `0x140d80` |
| `RBMenuTutorialView` | `-` | `setAnimating:` | prop | ✅ | ✅ | `0x140d90` |
| `RBMenuTutorialView` | `-` | `fullCoverView` | prop | ✅ | ✅ | `0x140da0` |
| `RBMenuTutorialView` | `-` | `setFullCoverView:` | prop | ✅ | ✅ | `0x140db0` |
| `RBMenuTutorialView` | `-` | `clipRootView` | prop | ✅ | ✅ | `0x140de8` |
| `RBMenuTutorialView` | `-` | `setClipRootView:` | prop | ✅ | ✅ | `0x140e08` |
| `RBMenuTutorialView` | `-` | `clipTargetView` | prop | ✅ | ✅ | `0x140e1c` |
| `RBMenuTutorialView` | `-` | `setClipTargetView:` | prop | ✅ | ✅ | `0x140e3c` |
| `RBMenuTutorialView` | `-` | `clipTargetForTouch` | prop | ✅ | ✅ | `0x140e50` |
| `RBMenuTutorialView` | `-` | `setClipTargetForTouch:` | prop | ✅ | ✅ | `0x140e60` |
| `RBMenuTutorialView` | `-` | `clipRect` | prop | ✅ | ✅ | `0x140e70` |
| `RBMenuTutorialView` | `-` | `setClipRect:` | prop | ✅ | ✅ | `0x140e88` |
| `RBMenuTutorialView` | `-` | `cursorView` | prop | ✅ | ✅ | `0x140ea0` |
| `RBMenuTutorialView` | `-` | `setCursorView:` | prop | ✅ | ✅ | `0x140eb0` |
| `RBMenuTutorialView` | `-` | `touchView` | prop | ✅ | ✅ | `0x140ee8` |
| `RBMenuTutorialView` | `-` | `setTouchView:` | prop | ✅ | ✅ | `0x140ef8` |
| `RBMenuTutorialView` | `-` | `grayTL` | prop | ✅ | ✅ | `0x140f30` |
| `RBMenuTutorialView` | `-` | `setGrayTL:` | prop | ✅ | ✅ | `0x140f50` |
| `RBMenuTutorialView` | `-` | `grayTR` | prop | ✅ | ✅ | `0x140f64` |
| `RBMenuTutorialView` | `-` | `setGrayTR:` | prop | ✅ | ✅ | `0x140f84` |
| `RBMenuTutorialView` | `-` | `grayBL` | prop | ✅ | ✅ | `0x140f98` |
| `RBMenuTutorialView` | `-` | `setGrayBL:` | prop | ✅ | ✅ | `0x140fb8` |
| `RBMenuTutorialView` | `-` | `grayBR` | prop | ✅ | ✅ | `0x140fcc` |
| `RBMenuTutorialView` | `-` | `setGrayBR:` | prop | ✅ | ✅ | `0x140fec` |
| `RBMenuTutorialView` | `-` | `grayCTL` | prop | ✅ | ✅ | `0x141000` |
| `RBMenuTutorialView` | `-` | `setGrayCTL:` | prop | ✅ | ✅ | `0x141020` |
| `RBMenuTutorialView` | `-` | `grayCTR` | prop | ✅ | ✅ | `0x141034` |
| `RBMenuTutorialView` | `-` | `setGrayCTR:` | prop | ✅ | ✅ | `0x141054` |
| `RBMenuTutorialView` | `-` | `grayCBL` | prop | ✅ | ✅ | `0x141068` |
| `RBMenuTutorialView` | `-` | `setGrayCBL:` | prop | ✅ | ✅ | `0x141088` |
| `RBMenuTutorialView` | `-` | `grayCBR` | prop | ✅ | ✅ | `0x14109c` |
| `RBMenuTutorialView` | `-` | `setGrayCBR:` | prop | ✅ | ✅ | `0x1410bc` |
| `RBMenuTutorialView` | `-` | `contentView` | prop | ✅ | ✅ | `0x1410d0` |
| `RBMenuTutorialView` | `-` | `setContentView:` | prop | ✅ | ✅ | `0x1410e0` |
| `RBMenuTutorialView` | `-` | `showLayerTag` | prop | ✅ | ✅ | `0x141118` |
| `RBMenuTutorialView` | `-` | `setShowLayerTag:` | prop | ✅ | ✅ | `0x141128` |
| `RBMenuTutorialView` | `-` | `deleteLayerTag` | prop | ✅ | ✅ | `0x141160` |
| `RBMenuTutorialView` | `-` | `setDeleteLayerTag:` | prop | ✅ | ✅ | `0x141170` |
| `RBMenuTutorialView` | `-` | `messageWindowLayer` | prop | ✅ | ✅ | `0x1411a8` |
| `RBMenuTutorialView` | `-` | `setMessageWindowLayer:` | prop | ✅ | ✅ | `0x1411c8` |
| `RBMenuTutorialView` | `-` | `messageLayer` | prop | ✅ | ✅ | `0x1411dc` |
| `RBMenuTutorialView` | `-` | `setMessageLayer:` | prop | ✅ | ✅ | `0x1411fc` |
| `RBMenuTutorialView` | `-` | `pastelLayer` | prop | ✅ | ✅ | `0x141210` |
| `RBMenuTutorialView` | `-` | `setPastelLayer:` | prop | ✅ | ✅ | `0x141230` |
| `RBMenuTutorialView` | `-` | `messageImage` | prop | ✅ | ✅ | `0x141244` |
| `RBMenuTutorialView` | `-` | `setMessageImage:` | prop | ✅ | ✅ | `0x141254` |
| `RBMenuTutorialView` | `-` | `messageClipRect` | prop | ✅ | ✅ | `0x14128c` |
| `RBMenuTutorialView` | `-` | `setMessageClipRect:` | prop | ✅ | ✅ | `0x14129c` |
| `RBMenuTutorialView` | `-` | `tutorialStatus` | prop | ✅ | ✅ | `0x1412d4` |
| `RBMenuTutorialView` | `-` | `setTutorialStatus:` | prop | ✅ | ✅ | `0x1412e4` |
| `RBMenuTutorialView` | `-` | `contentViewWidth` | prop | ✅ | ✅ | `0x1412f4` |
| `RBMenuTutorialView` | `-` | `setContentViewWidth:` | prop | ✅ | ✅ | `0x141304` |
| `RBMenuTutorialView` | `-` | `contentViewHeight` | prop | ✅ | ✅ | `0x141314` |
| `RBMenuTutorialView` | `-` | `setContentViewHeight:` | prop | ✅ | ✅ | `0x141324` |
| `RBErosionMarkUpdaterScoreView` | `-` | `initWithFrame:delegate:` |  | ✅ | ❌ | `0x1417e0` |
| `RBErosionMarkUpdaterScoreView` | `-` | `setupView` |  | ✅ | ❌ | `0x141910` |
| `RBErosionMarkUpdaterScoreView` | `-` | `showAnimation:` |  | ✅ | ❌ | `0x1424cc` |
| `RBErosionMarkUpdaterScoreView` | `-` | `hideAnimation:` |  | ✅ | ❌ | `0x1426c0` |
| `RBErosionMarkUpdaterScoreView` | `-` | `remove` |  | ✅ | ❌ | `0x1428b4` |
| `RBErosionMarkUpdaterScoreView` | `-` | `dealloc` |  | ✅ | ✅ | `0x1428ec` |
| `RBErosionMarkUpdaterScoreView` | `-` | `displayRate` | prop | ✅ | ✅ | `0x142920` |
| `RBErosionMarkUpdaterScoreView` | `-` | `setDisplayRate:` | prop | ✅ | ✅ | `0x142930` |
| `RBErosionMarkUpdaterScoreView` | `-` | `delegate` | prop | ✅ | ✅ | `0x142940` |
| `RBErosionMarkUpdaterScoreView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x142950` |
| `RBErosionMarkUpdaterScoreView` | `-` | `dialogView` | prop | ✅ | ✅ | `0x142960` |
| `RBErosionMarkUpdaterScoreView` | `-` | `setDialogView:` | prop | ✅ | ✅ | `0x142970` |
| `RBErosionMarkUpdaterScoreView` | `-` | `titleLabel` | prop | ✅ | ✅ | `0x142980` |
| `RBErosionMarkUpdaterScoreView` | `-` | `setTitleLabel:` | prop | ✅ | ✅ | `0x142990` |
| `RBErosionMarkUpdaterScoreView` | `-` | `messageLabel` | prop | ✅ | ✅ | `0x1429a0` |
| `RBErosionMarkUpdaterScoreView` | `-` | `setMessageLabel:` | prop | ✅ | ✅ | `0x1429b0` |
| `RBErosionMarkUpdaterScoreView` | `-` | `leftButton` | prop | ✅ | ✅ | `0x1429c0` |
| `RBErosionMarkUpdaterScoreView` | `-` | `setLeftButton:` | prop | ✅ | ✅ | `0x1429d0` |
| `RBErosionMarkUpdaterScoreView` | `-` | `rightButton` | prop | ✅ | ✅ | `0x1429e0` |
| `RBErosionMarkUpdaterScoreView` | `-` | `setRightButton:` | prop | ✅ | ✅ | `0x1429f0` |
| `RBErosionMarkUpdaterAlertController` | `-` | `init` |  | ✅ | ❌ | `0x142a00` |
| `RBErosionMarkUpdaterAlertController` | `-` | `initWithOrientationMask:` |  | ✅ | ❌ | `0x142a98` |
| `RBErosionMarkUpdaterAlertController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ❌ | `0x142b1c` |
| `RBErosionMarkUpdaterAlertController` | `-` | `orientationMask` | prop | ✅ | ✅ | `0x142b2c` |
| `RBErosionMarkUpdaterAlertController` | `-` | `setOrientationMask:` | prop | ✅ | ✅ | `0x142b3c` |
| `RBErosionMarkUpdater` | `+` | `updateCheckStart:` |  | ✅ | ❌ | `0x142b4c` |
| `RBErosionMarkUpdater` | `-` | `updateStartBasic:Medium:Hard:` |  | ✅ | ❌ | `0x142d4c` |
| `RBErosionMarkUpdater` | `-` | `setupView` |  | ✅ | ❌ | `0x142e08` |
| `RBErosionMarkUpdater` | `-` | `getPickerViewScore:` |  | ✅ | ❌ | `0x1433ec` |
| `RBErosionMarkUpdater` | `-` | `setPickerViewScore:score:` |  | ✅ | ❌ | `0x14370c` |
| `RBErosionMarkUpdater` | `-` | `pickerOpen` |  | ✅ | ❌ | `0x143b8c` |
| `RBErosionMarkUpdater` | `-` | `pickerClose` |  | ✅ | ❌ | `0x143cc8` |
| `RBErosionMarkUpdater` | `-` | `reset` |  | ✅ | ❌ | `0x143d8c` |
| `RBErosionMarkUpdater` | `-` | `scoreValidate` |  | ✅ | ❌ | `0x144080` |
| `RBErosionMarkUpdater` | `-` | `updatePerform` |  | ✅ | ❌ | `0x144418` |
| `RBErosionMarkUpdater` | `-` | `updateCancel` |  | ✅ | ❌ | `0x14445c` |
| `RBErosionMarkUpdater` | `-` | `needUpdateScore` |  | ✅ | ❌ | `0x14451c` |
| `RBErosionMarkUpdater` | `-` | `getScore` |  | ✅ | ❌ | `0x144820` |
| `RBErosionMarkUpdater` | `-` | `updateScore` |  | ✅ | ❌ | `0x1448d8` |
| `RBErosionMarkUpdater` | `-` | `remove` |  | ✅ | ❌ | `0x144d38` |
| `RBErosionMarkUpdater` | `-` | `dealloc` |  | ❌ | ✅ | `0x144fc8` |
| `RBErosionMarkUpdater` | `-` | `createAlertSetScore` |  | ✅ | ❌ | `0x144ffc` |
| `RBErosionMarkUpdater` | `-` | `createAlertCancel` |  | ✅ | ❌ | `0x146d3c` |
| `RBErosionMarkUpdater` | `-` | `createAlertConfirm` |  | ✅ | ❌ | `0x147134` |
| `RBErosionMarkUpdater` | `-` | `showAlertSetScore` |  | ✅ | ❌ | `0x1474e4` |
| `RBErosionMarkUpdater` | `-` | `reshowAlertSetScore:` |  | ✅ | ❌ | `0x147868` |
| `RBErosionMarkUpdater` | `-` | `showAlertCancel` |  | ✅ | ❌ | `0x147af4` |
| `RBErosionMarkUpdater` | `-` | `showAlertConfirm` |  | ✅ | ❌ | `0x147c5c` |
| `RBErosionMarkUpdater` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x1480ac` |
| `RBErosionMarkUpdater` | `-` | `textFieldDidBeginEditing:` |  | ✅ | ❌ | `0x1481a4` |
| `RBErosionMarkUpdater` | `-` | `textFieldDidEndEditing:` |  | ✅ | ❌ | `0x148204` |
| `RBErosionMarkUpdater` | `-` | `textField:shouldChangeCharactersInRange:replacementString:` |  | ✅ | ✅ | `0x148268` |
| `RBErosionMarkUpdater` | `-` | `numberOfComponentsInPickerView:` |  | ✅ | ❌ | `0x148270` |
| `RBErosionMarkUpdater` | `-` | `pickerView:numberOfRowsInComponent:` |  | ✅ | ✅ | `0x1482a0` |
| `RBErosionMarkUpdater` | `-` | `pickerView:titleForRow:forComponent:` |  | ✅ | ❌ | `0x1482a8` |
| `RBErosionMarkUpdater` | `-` | `pickerView:didSelectRow:inComponent:` |  | ✅ | ❌ | `0x1482e4` |
| `RBErosionMarkUpdater` | `-` | `viewController` | prop | ✅ | ✅ | `0x148540` |
| `RBErosionMarkUpdater` | `-` | `setViewController:` | prop | ✅ | ✅ | `0x148550` |
| `RBErosionMarkUpdater` | `-` | `displayRate` | prop | ✅ | ✅ | `0x148560` |
| `RBErosionMarkUpdater` | `-` | `setDisplayRate:` | prop | ✅ | ✅ | `0x148570` |
| `RBErosionMarkUpdater` | `-` | `alertSetScoreController` | prop | ✅ | ✅ | `0x148580` |
| `RBErosionMarkUpdater` | `-` | `setAlertSetScoreController:` | prop | ✅ | ✅ | `0x148590` |
| `RBErosionMarkUpdater` | `-` | `alertCancelController` | prop | ✅ | ✅ | `0x1485c8` |
| `RBErosionMarkUpdater` | `-` | `setAlertCancelController:` | prop | ✅ | ✅ | `0x1485d8` |
| `RBErosionMarkUpdater` | `-` | `alertConfirmController` | prop | ✅ | ✅ | `0x148610` |
| `RBErosionMarkUpdater` | `-` | `setAlertConfirmController:` | prop | ✅ | ✅ | `0x148620` |
| `RBErosionMarkUpdater` | `-` | `alertSetScoreView` | prop | ✅ | ✅ | `0x148658` |
| `RBErosionMarkUpdater` | `-` | `setAlertSetScoreView:` | prop | ✅ | ✅ | `0x148668` |
| `RBErosionMarkUpdater` | `-` | `alertCancelView` | prop | ✅ | ✅ | `0x1486a0` |
| `RBErosionMarkUpdater` | `-` | `setAlertCancelView:` | prop | ✅ | ✅ | `0x1486b0` |
| `RBErosionMarkUpdater` | `-` | `alertConfirmView` | prop | ✅ | ✅ | `0x1486e8` |
| `RBErosionMarkUpdater` | `-` | `setAlertConfirmView:` | prop | ✅ | ✅ | `0x1486f8` |
| `RBErosionMarkUpdater` | `-` | `toolbar` | prop | ✅ | ✅ | `0x148730` |
| `RBErosionMarkUpdater` | `-` | `setToolbar:` | prop | ✅ | ✅ | `0x148740` |
| `RBErosionMarkUpdater` | `-` | `basicPickerView` | prop | ✅ | ✅ | `0x148778` |
| `RBErosionMarkUpdater` | `-` | `setBasicPickerView:` | prop | ✅ | ✅ | `0x148788` |
| `RBErosionMarkUpdater` | `-` | `mediumPickerView` | prop | ✅ | ✅ | `0x1487c0` |
| `RBErosionMarkUpdater` | `-` | `setMediumPickerView:` | prop | ✅ | ✅ | `0x1487d0` |
| `RBErosionMarkUpdater` | `-` | `hardPickerView` | prop | ✅ | ✅ | `0x148808` |
| `RBErosionMarkUpdater` | `-` | `setHardPickerView:` | prop | ✅ | ✅ | `0x148818` |
| `RBErosionMarkUpdater` | `-` | `basicField` | prop | ✅ | ✅ | `0x148850` |
| `RBErosionMarkUpdater` | `-` | `setBasicField:` | prop | ✅ | ✅ | `0x148860` |
| `RBErosionMarkUpdater` | `-` | `mediumField` | prop | ✅ | ✅ | `0x148870` |
| `RBErosionMarkUpdater` | `-` | `setMediumField:` | prop | ✅ | ✅ | `0x148880` |
| `RBErosionMarkUpdater` | `-` | `hardField` | prop | ✅ | ✅ | `0x148890` |
| `RBErosionMarkUpdater` | `-` | `setHardField:` | prop | ✅ | ✅ | `0x1488a0` |
| `RBErosionMarkUpdater` | `-` | `activeFieldIndex` | prop | ✅ | ✅ | `0x1488b0` |
| `RBErosionMarkUpdater` | `-` | `setActiveFieldIndex:` | prop | ✅ | ✅ | `0x1488c0` |
| `RBErosionMarkUpdater` | `-` | `baseBasicScore` | prop | ✅ | ✅ | `0x1488d0` |
| `RBErosionMarkUpdater` | `-` | `setBaseBasicScore:` | prop | ✅ | ✅ | `0x1488e0` |
| `RBErosionMarkUpdater` | `-` | `editBasicScore` | prop | ✅ | ✅ | `0x1488f0` |
| `RBErosionMarkUpdater` | `-` | `setEditBasicScore:` | prop | ✅ | ✅ | `0x148900` |
| `RBErosionMarkUpdater` | `-` | `baseMediumScore` | prop | ✅ | ✅ | `0x148910` |
| `RBErosionMarkUpdater` | `-` | `setBaseMediumScore:` | prop | ✅ | ✅ | `0x148920` |
| `RBErosionMarkUpdater` | `-` | `editMediumScore` | prop | ✅ | ✅ | `0x148930` |
| `RBErosionMarkUpdater` | `-` | `setEditMediumScore:` | prop | ✅ | ✅ | `0x148940` |
| `RBErosionMarkUpdater` | `-` | `baseHardScore` | prop | ✅ | ✅ | `0x148950` |
| `RBErosionMarkUpdater` | `-` | `setBaseHardScore:` | prop | ✅ | ✅ | `0x148960` |
| `RBErosionMarkUpdater` | `-` | `editHardScore` | prop | ✅ | ✅ | `0x148970` |
| `RBErosionMarkUpdater` | `-` | `setEditHardScore:` | prop | ✅ | ✅ | `0x148980` |
| `DAProgressOverlayView` | `-` | `initWithCoder:` |  | ❌ | ❌ | `0x154ae0` |
| `DAProgressOverlayView` | `-` | `initWithFrame:` |  | ❌ | ❌ | `0x154b38` |
| `DAProgressOverlayView` | `-` | `setUp` |  | ❌ | ❌ | `0x154b90` |
| `DAProgressOverlayView` | `-` | `displayOperationDidFinishAnimation` |  | ❌ | ❌ | `0x154cb4` |
| `DAProgressOverlayView` | `-` | `displayOperationWillTriggerAnimation` |  | ❌ | ❌ | `0x154d48` |
| `DAProgressOverlayView` | `-` | `drawRect:` |  | ❌ | ❌ | `0x154ddc` |
| `DAProgressOverlayView` | `-` | `setInnerRadiusRatio:` | prop | ❌ | ✅ | `0x1550e8` |
| `DAProgressOverlayView` | `-` | `setOuterRadiusRatio:` | prop | ❌ | ✅ | `0x15510c` |
| `DAProgressOverlayView` | `-` | `setProgress:` | prop | ❌ | ❌ | `0x155130` |
| `DAProgressOverlayView` | `-` | `innerRadius` |  | ❌ | ❌ | `0x1551d4` |
| `DAProgressOverlayView` | `-` | `outerRadius` |  | ❌ | ❌ | `0x1552b8` |
| `DAProgressOverlayView` | `-` | `update` |  | ❌ | ❌ | `0x15539c` |
| `DAProgressOverlayView` | `-` | `overlayColor` | prop | ❌ | ✅ | `0x155458` |
| `DAProgressOverlayView` | `-` | `setOverlayColor:` | prop | ❌ | ✅ | `0x155468` |
| `DAProgressOverlayView` | `-` | `innerRadiusRatio` | prop | ❌ | ✅ | `0x1554a0` |
| `DAProgressOverlayView` | `-` | `outerRadiusRatio` | prop | ❌ | ✅ | `0x1554b0` |
| `DAProgressOverlayView` | `-` | `progress` | prop | ❌ | ✅ | `0x1554c0` |
| `DAProgressOverlayView` | `-` | `stateChangeAnimationDuration` | prop | ❌ | ✅ | `0x1554d0` |
| `DAProgressOverlayView` | `-` | `setStateChangeAnimationDuration:` | prop | ❌ | ✅ | `0x1554e0` |
| `DAProgressOverlayView` | `-` | `triggersDownloadDidFinishAnimationAutomatically` | prop | ❌ | ✅ | `0x1554f0` |
| `DAProgressOverlayView` | `-` | `setTriggersDownloadDidFinishAnimationAutomatically:` | prop | ❌ | ✅ | `0x155500` |
| `DAProgressOverlayView` | `-` | `state` | prop | ❌ | ✅ | `0x155510` |
| `DAProgressOverlayView` | `-` | `setState:` | prop | ❌ | ✅ | `0x155520` |
| `DAProgressOverlayView` | `-` | `animationProggress` | prop | ❌ | ✅ | `0x155530` |
| `DAProgressOverlayView` | `-` | `setAnimationProggress:` | prop | ❌ | ✅ | `0x155540` |
| `DAProgressOverlayView` | `-` | `timer` | prop | ❌ | ✅ | `0x155550` |
| `DAProgressOverlayView` | `-` | `setTimer:` | prop | ❌ | ✅ | `0x155560` |
| `RBCustomSelectCollectionView` | `-` | `initWithFrame:customizeType:` |  | ✅ | ❌ | `0x1555d8` |
| `RBCustomSelectCollectionView` | `-` | `setupView` |  | ✅ | ❌ | `0x155670` |
| `RBCustomSelectCollectionView` | `-` | `gaugeStyleTap:` |  | ✅ | ❌ | `0x15720c` |
| `RBCustomSelectCollectionView` | `-` | `noteSizeTap:` |  | ✅ | ❌ | `0x1574f8` |
| `RBCustomSelectCollectionView` | `-` | `sliderChanged:` |  | ✅ | ❌ | `0x1577e4` |
| `RBCustomSelectCollectionView` | `-` | `reloadData` |  | ✅ | ❌ | `0x157bec` |
| `RBCustomSelectCollectionView` | `-` | `didLayoutSubviews:` |  | ✅ | ❌ | `0x15901c` |
| `RBCustomSelectCollectionView` | `-` | `collectionView:didHighlightItemAtIndexPath:` |  | ✅ | ❌ | `0x159128` |
| `RBCustomSelectCollectionView` | `-` | `collectionView:didUnhighlightItemAtIndexPath:` |  | ✅ | ❌ | `0x1591b4` |
| `RBCustomSelectCollectionView` | `-` | `collectionView:numberOfItemsInSection:` |  | ✅ | ❌ | `0x159240` |
| `RBCustomSelectCollectionView` | `-` | `collectionView:cellForItemAtIndexPath:` |  | ✅ | ❌ | `0x1592a8` |
| `RBCustomSelectCollectionView` | `-` | `collectionView:didSelectItemAtIndexPath:` |  | ✅ | ❌ | `0x159960` |
| `RBCustomSelectCollectionView` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x159de8` |
| `RBCustomSelectCollectionView` | `-` | `backgroundView` | prop | ✅ | ✅ | `0x159f10` |
| `RBCustomSelectCollectionView` | `-` | `setBackgroundView:` | prop | ✅ | ✅ | `0x159f20` |
| `RBCustomSelectCollectionView` | `-` | `collectionView` | prop | ✅ | ✅ | `0x159f58` |
| `RBCustomSelectCollectionView` | `-` | `setCollectionView:` | prop | ✅ | ✅ | `0x159f68` |
| `RBCustomSelectCollectionView` | `-` | `pageControl` | prop | ✅ | ✅ | `0x159fa0` |
| `RBCustomSelectCollectionView` | `-` | `setPageControl:` | prop | ✅ | ✅ | `0x159fb0` |
| `RBCustomSelectCollectionView` | `-` | `items` | prop | ✅ | ✅ | `0x159fe8` |
| `RBCustomSelectCollectionView` | `-` | `setItems:` | prop | ✅ | ✅ | `0x159ff8` |
| `RBCustomSelectCollectionView` | `-` | `customizeType` | prop | ✅ | ✅ | `0x15a030` |
| `RBCustomSelectCollectionView` | `-` | `setCustomizeType:` | prop | ✅ | ✅ | `0x15a040` |
| `RBStoreExtendPageViewController` | `-` | `initWithParent:` |  | ✅ | ❌ | `0x15a0b8` |
| `RBStoreExtendPageViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x15a3a4` |
| `RBStoreExtendPageViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x15a534` |
| `RBStoreExtendPageViewController` | `-` | `showError:` |  | ✅ | ❌ | `0x15c660` |
| `RBStoreExtendPageViewController` | `-` | `pushBarBtnRestore:` |  | ✅ | ❌ | `0x15c810` |
| `RBStoreExtendPageViewController` | `-` | `showTerms` |  | ✅ | ❌ | `0x15c880` |
| `RBStoreExtendPageViewController` | `-` | `sendUserAge` |  | ✅ | ❌ | `0x15c9a4` |
| `RBStoreExtendPageViewController` | `-` | `extendNoteListDownloadSuccess:` |  | ✅ | ❌ | `0x15d260` |
| `RBStoreExtendPageViewController` | `-` | `forceOpenExtendNoteDetailView` |  | ✅ | ❌ | `0x15db50` |
| `RBStoreExtendPageViewController` | `-` | `extendNoteListDownloadError:errorMessage:` |  | ✅ | ❌ | `0x15deec` |
| `RBStoreExtendPageViewController` | `-` | `extendNoteListDownloadNothing:` |  | ✅ | ❌ | `0x15e208` |
| `RBStoreExtendPageViewController` | `-` | `cellViewSelected:` |  | ✅ | ❌ | `0x15e340` |
| `RBStoreExtendPageViewController` | `-` | `selectButton:` |  | ✅ | ❌ | `0x15e4e0` |
| `RBStoreExtendPageViewController` | `-` | `openExtendNoteDetailViewWithPID:` |  | ✅ | ❌ | `0x15e6f4` |
| `RBStoreExtendPageViewController` | `-` | `openDetailAnimStop:finished:context:` |  | ✅ | ✅ | `0x15eb70` |
| `RBStoreExtendPageViewController` | `-` | `pushSampleButton:` |  | ✅ | ❌ | `0x15eb74` |
| `RBStoreExtendPageViewController` | `-` | `handleTapCoverView:` |  | ✅ | ❌ | `0x15ed78` |
| `RBStoreExtendPageViewController` | `-` | `startDownloadExtendNote:` |  | ✅ | ❌ | `0x15f160` |
| `RBStoreExtendPageViewController` | `-` | `checkAttainLimitPurchase:` |  | ✅ | ❌ | `0x15f9a0` |
| `RBStoreExtendPageViewController` | `-` | `startPurchase:` |  | ✅ | ❌ | `0x15fbec` |
| `RBStoreExtendPageViewController` | `-` | `detailViewClose` |  | ✅ | ❌ | `0x15fec0` |
| `RBStoreExtendPageViewController` | `-` | `storeDialogCancel:` |  | ✅ | ❌ | `0x15ff4c` |
| `RBStoreExtendPageViewController` | `-` | `connectionDidFinishLoading:` |  | ✅ | ✅ | `0x1601d0` |
| `RBStoreExtendPageViewController` | `-` | `connection:didFailWithError:` |  | ✅ | ✅ | `0x1601d4` |
| `RBStoreExtendPageViewController` | `-` | `updateExtendNoteInfo:Save:` |  | ✅ | ❌ | `0x1601d8` |
| `RBStoreExtendPageViewController` | `-` | `updatePurchasedTableCell:` |  | ✅ | ❌ | `0x1602b8` |
| `RBStoreExtendPageViewController` | `-` | `reDownloadPackMusics:` |  | ✅ | ❌ | `0x160838` |
| `RBStoreExtendPageViewController` | `-` | `purchaseSucceeded:` |  | ✅ | ❌ | `0x1608a4` |
| `RBStoreExtendPageViewController` | `-` | `purchaseFailed:error:` |  | ✅ | ❌ | `0x160d44` |
| `RBStoreExtendPageViewController` | `-` | `addRestoreExtendNoteInfo:` |  | ✅ | ❌ | `0x160ed8` |
| `RBStoreExtendPageViewController` | `-` | `nextRestoreExtendNoteInfo` |  | ✅ | ❌ | `0x161040` |
| `RBStoreExtendPageViewController` | `-` | `askDownloadAllNotes` |  | ✅ | ❌ | `0x161314` |
| `RBStoreExtendPageViewController` | `-` | `restoreDownloadAllNotes` |  | ✅ | ❌ | `0x161804` |
| `RBStoreExtendPageViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x161d34` |
| `RBStoreExtendPageViewController` | `-` | `alertViewCancel:` |  | ✅ | ❌ | `0x1621f0` |
| `RBStoreExtendPageViewController` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0x162258` |
| `RBStoreExtendPageViewController` | `-` | `restoreSucceeded` |  | ✅ | ❌ | `0x162398` |
| `RBStoreExtendPageViewController` | `-` | `restoreFailed:` |  | ✅ | ❌ | `0x162604` |
| `RBStoreExtendPageViewController` | `-` | `restoreNothing` |  | ✅ | ❌ | `0x16273c` |
| `RBStoreExtendPageViewController` | `-` | `storeExtendNoteInfoDownloaderFinished:` |  | ✅ | ❌ | `0x162790` |
| `RBStoreExtendPageViewController` | `-` | `storeExtendNoteInfoDownloaderError:` |  | ✅ | ❌ | `0x1628b0` |
| `RBStoreExtendPageViewController` | `-` | `downloadManagerStartTask:` |  | ✅ | ❌ | `0x162988` |
| `RBStoreExtendPageViewController` | `-` | `downloadManagerCompleted:` |  | ✅ | ❌ | `0x162b7c` |
| `RBStoreExtendPageViewController` | `-` | `downloadManagerFailed:` |  | ✅ | ❌ | `0x162dbc` |
| `RBStoreExtendPageViewController` | `-` | `downloadManagerProceed:` |  | ✅ | ❌ | `0x16304c` |
| `RBStoreExtendPageViewController` | `-` | `numPackRows` |  | ✅ | ❌ | `0x16315c` |
| `RBStoreExtendPageViewController` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ❌ | `0x163240` |
| `RBStoreExtendPageViewController` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ✅ | `0x164f4c` |
| `RBStoreExtendPageViewController` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ❌ | `0x164f54` |
| `RBStoreExtendPageViewController` | `-` | `tableView:heightForRowAtIndexPath:` |  | ✅ | ❌ | `0x16504c` |
| `RBStoreExtendPageViewController` | `-` | `tableView:willDisplayCell:forRowAtIndexPath:` |  | ✅ | ❌ | `0x16511c` |
| `RBStoreExtendPageViewController` | `-` | `tableView:willSelectRowAtIndexPath:` |  | ✅ | ❌ | `0x165428` |
| `RBStoreExtendPageViewController` | `-` | `tableView:didSelectRowAtIndexPath:` |  | ✅ | ❌ | `0x165440` |
| `RBStoreExtendPageViewController` | `-` | `showDetailViewForPhone:` |  | ✅ | ❌ | `0x165598` |
| `RBStoreExtendPageViewController` | `-` | `selectShowMore` |  | ✅ | ❌ | `0x165708` |
| `RBStoreExtendPageViewController` | `-` | `imageDownloader:didLoad:` |  | ✅ | ❌ | `0x165938` |
| `RBStoreExtendPageViewController` | `-` | `imageDownloaderDidFail:didLoad:` |  | ✅ | ✅ | `0x165c3c` |
| `RBStoreExtendPageViewController` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x165c40` |
| `RBStoreExtendPageViewController` | `-` | `stopDownloadArtworks` |  | ✅ | ❌ | `0x166184` |
| `RBStoreExtendPageViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x1663a4` |
| `RBStoreExtendPageViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x166858` |
| `RBStoreExtendPageViewController` | `-` | `viewWillDisappear:` |  | ✅ | ❌ | `0x166ad0` |
| `RBStoreExtendPageViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x166d40` |
| `RBStoreExtendPageViewController` | `-` | `willAnimateRotationToInterfaceOrientation:duration:` |  | ✅ | ❌ | `0x166d48` |
| `RBStoreExtendPageViewController` | `-` | `didRotateFromInterfaceOrientation:` |  | ✅ | ✅ | `0x166d7c` |
| `RBStoreExtendPageViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ❌ | `0x166d80` |
| `RBStoreExtendPageViewController` | `-` | `dealloc` |  | ✅ | ❌ | `0x166e04` |
| `RBStoreExtendPageViewController` | `-` | `showLoadingView` |  | ✅ | ❌ | `0x166f14` |
| `RBStoreExtendPageViewController` | `-` | `popoverControllerDidDismissPopover:` |  | ✅ | ❌ | `0x16726c` |
| `RBStoreExtendPageViewController` | `-` | `storeDetailViewOpenItunesWithURL:` |  | ✅ | ❌ | `0x167340` |
| `RBStoreExtendPageViewController` | `-` | `openItunesWithURL:` |  | ✅ | ❌ | `0x167404` |
| `RBStoreExtendPageViewController` | `-` | `closeItunesWithURL` |  | ✅ | ❌ | `0x16777c` |
| `RBStoreExtendPageViewController` | `-` | `productViewControllerDidFinish:` |  | ✅ | ❌ | `0x1677dc` |
| `RBStoreExtendPageViewController` | `-` | `parent` | prop | ✅ | ✅ | `0x1678b4` |
| `RBStoreExtendPageViewController` | `-` | `setParent:` | prop | ✅ | ✅ | `0x1678d4` |
| `RBStoreExtendPageViewController` | `-` | `extendNoteListCtrl` | prop | ✅ | ✅ | `0x1678e8` |
| `RBStoreExtendPageViewController` | `-` | `setExtendNoteListCtrl:` | prop | ✅ | ✅ | `0x1678f8` |
| `RBStoreExtendPageViewController` | `-` | `artworkDownloaders` | prop | ✅ | ✅ | `0x167930` |
| `RBStoreExtendPageViewController` | `-` | `setArtworkDownloaders:` | prop | ✅ | ✅ | `0x167940` |
| `RBStoreExtendPageViewController` | `-` | `downloadManager` | prop | ✅ | ✅ | `0x167978` |
| `RBStoreExtendPageViewController` | `-` | `setDownloadManager:` | prop | ✅ | ✅ | `0x167988` |
| `RBStoreExtendPageViewController` | `-` | `purchasingExtendNoteInfo` | prop | ✅ | ✅ | `0x1679c0` |
| `RBStoreExtendPageViewController` | `-` | `setPurchasingExtendNoteInfo:` | prop | ✅ | ✅ | `0x1679d0` |
| `RBStoreExtendPageViewController` | `-` | `packTableLabel` | prop | ✅ | ✅ | `0x167a08` |
| `RBStoreExtendPageViewController` | `-` | `setPackTableLabel:` | prop | ✅ | ✅ | `0x167a18` |
| `RBStoreExtendPageViewController` | `-` | `showMoreButton` | prop | ✅ | ✅ | `0x167a50` |
| `RBStoreExtendPageViewController` | `-` | `setShowMoreButton:` | prop | ✅ | ✅ | `0x167a60` |
| `RBStoreExtendPageViewController` | `-` | `showMoreIndicator` | prop | ✅ | ✅ | `0x167a98` |
| `RBStoreExtendPageViewController` | `-` | `setShowMoreIndicator:` | prop | ✅ | ✅ | `0x167aa8` |
| `RBStoreExtendPageViewController` | `-` | `coverViewPad` | prop | ✅ | ✅ | `0x167ae0` |
| `RBStoreExtendPageViewController` | `-` | `setCoverViewPad:` | prop | ✅ | ✅ | `0x167af0` |
| `RBStoreExtendPageViewController` | `-` | `extendNoteDetailViewPad` | prop | ✅ | ✅ | `0x167b28` |
| `RBStoreExtendPageViewController` | `-` | `setExtendNoteDetailViewPad:` | prop | ✅ | ✅ | `0x167b38` |
| `RBStoreExtendPageViewController` | `-` | `restoreProductID` | prop | ✅ | ✅ | `0x167b70` |
| `RBStoreExtendPageViewController` | `-` | `setRestoreProductID:` | prop | ✅ | ✅ | `0x167b80` |
| `RBStoreExtendPageViewController` | `-` | `restoreExtendNoteInfo` | prop | ✅ | ✅ | `0x167bb8` |
| `RBStoreExtendPageViewController` | `-` | `setRestoreExtendNoteInfo:` | prop | ✅ | ✅ | `0x167bc8` |
| `RBStoreExtendPageViewController` | `-` | `restoreButton` | prop | ✅ | ✅ | `0x167c00` |
| `RBStoreExtendPageViewController` | `-` | `setRestoreButton:` | prop | ✅ | ✅ | `0x167c10` |
| `RBStoreExtendPageViewController` | `-` | `storeExtendNoteInfoDownloader` | prop | ✅ | ✅ | `0x167c48` |
| `RBStoreExtendPageViewController` | `-` | `setStoreExtendNoteInfoDownloader:` | prop | ✅ | ✅ | `0x167c58` |
| `RBStoreExtendPageViewController` | `-` | `packBgImage0` | prop | ✅ | ✅ | `0x167c90` |
| `RBStoreExtendPageViewController` | `-` | `setPackBgImage0:` | prop | ✅ | ✅ | `0x167ca0` |
| `RBStoreExtendPageViewController` | `-` | `packBgImage1` | prop | ✅ | ✅ | `0x167cd8` |
| `RBStoreExtendPageViewController` | `-` | `setPackBgImage1:` | prop | ✅ | ✅ | `0x167ce8` |
| `RBStoreExtendPageViewController` | `-` | `purchaseLimitTypeSelectView` | prop | ✅ | ✅ | `0x167d20` |
| `RBStoreExtendPageViewController` | `-` | `setPurchaseLimitTypeSelectView:` | prop | ✅ | ✅ | `0x167d30` |
| `RBStoreExtendPageViewController` | `-` | `bannerBgView` | prop | ✅ | ✅ | `0x167d68` |
| `RBStoreExtendPageViewController` | `-` | `setBannerBgView:` | prop | ✅ | ✅ | `0x167d78` |
| `RBStoreExtendPageViewController` | `-` | `samplePlayButton` | prop | ✅ | ✅ | `0x167db0` |
| `RBStoreExtendPageViewController` | `-` | `setSamplePlayButton:` | prop | ✅ | ✅ | `0x167dc0` |
| `RBStoreExtendPageViewController` | `-` | `playImage` | prop | ✅ | ✅ | `0x167df8` |
| `RBStoreExtendPageViewController` | `-` | `setPlayImage:` | prop | ✅ | ✅ | `0x167e08` |
| `RBStoreExtendPageViewController` | `-` | `stopImage` | prop | ✅ | ✅ | `0x167e40` |
| `RBStoreExtendPageViewController` | `-` | `setStopImage:` | prop | ✅ | ✅ | `0x167e50` |
| `RBStoreExtendPageViewController` | `-` | `sampleMusicLabel` | prop | ✅ | ✅ | `0x167e88` |
| `RBStoreExtendPageViewController` | `-` | `setSampleMusicLabel:` | prop | ✅ | ✅ | `0x167e98` |
| `RBStoreExtendPageViewController` | `-` | `itunesViewCtrl` | prop | ✅ | ✅ | `0x167ed0` |
| `RBStoreExtendPageViewController` | `-` | `setItunesViewCtrl:` | prop | ✅ | ✅ | `0x167ee0` |
| `RBStoreExtendPageViewController` | `-` | `moveToPackID` | prop | ✅ | ✅ | `0x167f18` |
| `RBStoreExtendPageViewController` | `-` | `setMoveToPackID:` | prop | ✅ | ✅ | `0x167f28` |
| `RBStoreExtendPageViewController` | `-` | `userAgeSender` | prop | ✅ | ✅ | `0x167f38` |
| `RBStoreExtendPageViewController` | `-` | `setUserAgeSender:` | prop | ✅ | ✅ | `0x167f48` |
| `RBUrlSchemeManager` | `+` | `sharedManager` |  | ✅ | ❌ | `0x168174` |
| `RBUrlSchemeManager` | `-` | `parseURL:` |  | ✅ | ❌ | `0x1681cc` |
| `RBUrlSchemeManager` | `-` | `dictionaryFromQueryString:` |  | ✅ | ❌ | `0x168504` |
| `RBCustomSelectView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x1687dc` |
| `RBCustomSelectView` | `-` | `getCollectionViewStartY:` |  | ✅ | ❌ | `0x168850` |
| `RBCustomSelectView` | `-` | `getCollectionViewMargin` |  | ✅ | ❌ | `0x16889c` |
| `RBCustomSelectView` | `-` | `setupView` |  | ✅ | ❌ | `0x1688c0` |
| `RBCustomSelectView` | `-` | `reloadData` |  | ✅ | ❌ | `0x1696d4` |
| `RBCustomSelectView` | `-` | `prevButtonTap:` |  | ✅ | ❌ | `0x169828` |
| `RBCustomSelectView` | `-` | `scrollView` | prop | ✅ | ✅ | `0x1698d0` |
| `RBCustomSelectView` | `-` | `setScrollView:` | prop | ✅ | ✅ | `0x1698e0` |
| `RBCustomSelectView` | `-` | `bgmCollectionView` | prop | ✅ | ✅ | `0x169918` |
| `RBCustomSelectView` | `-` | `setBgmCollectionView:` | prop | ✅ | ✅ | `0x169928` |
| `RBCustomSelectView` | `-` | `shotCollectionView` | prop | ✅ | ✅ | `0x169960` |
| `RBCustomSelectView` | `-` | `setShotCollectionView:` | prop | ✅ | ✅ | `0x169970` |
| `RBCustomSelectView` | `-` | `explosionCollectionView` | prop | ✅ | ✅ | `0x1699a8` |
| `RBCustomSelectView` | `-` | `setExplosionCollectionView:` | prop | ✅ | ✅ | `0x1699b8` |
| `RBCustomSelectView` | `-` | `frameCollectionView` | prop | ✅ | ✅ | `0x1699f0` |
| `RBCustomSelectView` | `-` | `setFrameCollectionView:` | prop | ✅ | ✅ | `0x169a00` |
| `RBCustomSelectView` | `-` | `bgCollectionView` | prop | ✅ | ✅ | `0x169a38` |
| `RBCustomSelectView` | `-` | `setBgCollectionView:` | prop | ✅ | ✅ | `0x169a48` |
| `RBCustomSelectView` | `-` | `noteCollectionView` | prop | ✅ | ✅ | `0x169a80` |
| `RBCustomSelectView` | `-` | `setNoteCollectionView:` | prop | ✅ | ✅ | `0x169a90` |
| `RBCustomSelectView` | `-` | `gaugeCollectionView` | prop | ✅ | ✅ | `0x169ac8` |
| `RBCustomSelectView` | `-` | `setGaugeCollectionView:` | prop | ✅ | ✅ | `0x169ad8` |
| `RBCustomSelectView` | `-` | `timingCollectionView` | prop | ✅ | ✅ | `0x169b10` |
| `RBCustomSelectView` | `-` | `setTimingCollectionView:` | prop | ✅ | ✅ | `0x169b20` |
| `(RB)` | `+` | `deleteAlertViewWithDelegate:` |  | ✅ | ❌ | `0x169c24` |
| `(RB)` | `+` | `strageAlertView:` |  | ❌ | ❌ | `0x169f2c` |
| `(RB)` | `+` | `showRestoreDownloadWithDelegate:` |  | ✅ | ❌ | `0x16a084` |
| `(RB)` | `+` | `showRestoreMessageWithDelegate:` |  | ✅ | ❌ | `0x16a394` |
| `(RB)` | `+` | `showGameCenterError` |  | ✅ | ❌ | `0x16a6a4` |
| `(RB)` | `+` | `showNetworkErrorWithDelegate:` |  | ✅ | ❌ | `0x16a7f4` |
| `(RB)` | `+` | `showDownloadErrorWithDelegate:` |  | ✅ | ❌ | `0x16aa0c` |
| `(RB)` | `+` | `showTakeoverMessage` |  | ✅ | ❌ | `0x16ac24` |
| `(RB)` | `+` | `showInfomation` |  | ✅ | ❌ | `0x16ad74` |
| `(RB)` | `+` | `showMapWithTitle:delegate:` |  | ✅ | ❌ | `0x16aec4` |
| `(RB)` | `+` | `showWithErrorMessage:delegate:` |  | ✅ | ❌ | `0x16b1e8` |
| `(RB)` | `+` | `showUnlockedMusicInfoWithDelegate:musicName:` |  | ✅ | ❌ | `0x16b414` |
| `(RB)` | `+` | `showSelectPurchaseLimitTypeWithDelegate:` |  | ✅ | ❌ | `0x16b66c` |
| `(RB)` | `+` | `showPurchaseOverMessageWithDelegate:` |  | ✅ | ❌ | `0x16bc54` |
| `(RB)` | `+` | `showUnlockTermsDescription2:` |  | ✅ | ❌ | `0x16be64` |
| `(RB)` | `+` | `showAlertUpdateForUnlock:` |  | ✅ | ❌ | `0x16bfec` |
| `(RB)` | `+` | `showAlertShortageOfPoint` |  | ✅ | ❌ | `0x16c2f0` |
| `(RB)` | `+` | `showDownloadWithDelegate:` |  | ✅ | ❌ | `0x16c440` |
| `(RB)` | `+` | `showAlertNeedResourceUpdate:` |  | ✅ | ❌ | `0x16c750` |
| `(RB)` | `+` | `showAddLimepointByApplilink::` |  | ❌ | ❌ | `0x16c964` |
| `(RB)` | `+` | `showAlertNeedDownloadMusicNameList:` |  | ✅ | ❌ | `0x16cbc0` |
| `(RB)` | `+` | `showColetteThemaUnlockMessage` |  | ✅ | ❌ | `0x16cf04` |
| `(RB)` | `+` | `showSerialcodeDialog:` |  | ✅ | ❌ | `0x16d114` |
| `(RB)` | `+` | `setExclusiveTouchForView:` |  | ✅ | ❌ | `0x16d458` |
| `RBMusicGridLayout` | `-` | `init` |  | ✅ | ✅ | `0x16d5c0` |
| `RBMusicGridLayout` | `-` | `prepareLayout` |  | ✅ | ✅ | `0x16d7d8` |
| `RBMusicGridLayout` | `-` | `collectionViewContentSize` |  | ✅ | ✅ | `0x16de78` |
| `RBMusicGridLayout` | `-` | `layoutAttributesForItemAtIndexPath:` |  | ✅ | ✅ | `0x16de84` |
| `RBMusicGridLayout` | `-` | `layoutAttributesForSupplementaryViewOfKind:atIndexPath:` |  | ❌ | ✅ | `0x16deb0` |
| `RBMusicGridLayout` | `-` | `layoutAttributesForElementsInRect:` |  | ✅ | ✅ | `0x16df1c` |
| `RBMusicGridLayout` | `-` | `shouldInvalidateLayoutForBoundsChange:` |  | ✅ | ✅ | `0x16e0a0` |
| `RBMusicGridLayout` | `-` | `minimumLineSpacing` | prop | ✅ | ✅ | `0x16e0a8` |
| `RBMusicGridLayout` | `-` | `setMinimumLineSpacing:` | prop | ✅ | ✅ | `0x16e0b8` |
| `RBMusicGridLayout` | `-` | `minimumInteritemSpacing` | prop | ✅ | ✅ | `0x16e0c8` |
| `RBMusicGridLayout` | `-` | `setMinimumInteritemSpacing:` | prop | ✅ | ✅ | `0x16e0d8` |
| `RBMusicGridLayout` | `-` | `itemSize` | prop | ✅ | ✅ | `0x16e0e8` |
| `RBMusicGridLayout` | `-` | `setItemSize:` | prop | ✅ | ✅ | `0x16e0fc` |
| `RBMusicGridLayout` | `-` | `pageInset` | prop | ✅ | ✅ | `0x16e110` |
| `RBMusicGridLayout` | `-` | `setPageInset:` | prop | ✅ | ✅ | `0x16e128` |
| `RBMusicGridLayout` | `-` | `rowCount` | prop | ✅ | ✅ | `0x16e140` |
| `RBMusicGridLayout` | `-` | `setRowCount:` | prop | ✅ | ✅ | `0x16e150` |
| `RBMusicGridLayout` | `-` | `colCount` | prop | ✅ | ✅ | `0x16e160` |
| `RBMusicGridLayout` | `-` | `setColCount:` | prop | ✅ | ✅ | `0x16e170` |
| `RBMusicGridLayout` | `-` | `pageCount` | prop | ✅ | ✅ | `0x16e180` |
| `RBMusicGridLayout` | `-` | `setPageCount:` | prop | ✅ | ✅ | `0x16e190` |
| `RBMusicGridLayout` | `-` | `pageItemCount` | prop | ✅ | ✅ | `0x16e1a0` |
| `RBMusicGridLayout` | `-` | `setPageItemCount:` | prop | ✅ | ✅ | `0x16e1b0` |
| `RBMusicGridLayout` | `-` | `scrollDirection` | prop | ✅ | ✅ | `0x16e1c0` |
| `RBMusicGridLayout` | `-` | `setScrollDirection:` | prop | ✅ | ✅ | `0x16e1d0` |
| `RBMusicGridLayout` | `-` | `pageSize` | prop | ✅ | ✅ | `0x16e1e0` |
| `RBMusicGridLayout` | `-` | `setPageSize:` | prop | ✅ | ✅ | `0x16e1f4` |
| `RBMusicGridLayout` | `-` | `contentSize` | prop | ✅ | ✅ | `0x16e208` |
| `RBMusicGridLayout` | `-` | `setContentSize:` | prop | ✅ | ✅ | `0x16e21c` |
| `RBMusicGridLayout` | `-` | `pageRects` | prop | ✅ | ✅ | `0x16e230` |
| `RBMusicGridLayout` | `-` | `setPageRects:` | prop | ✅ | ✅ | `0x16e240` |
| `RBMusicGridLayout` | `-` | `itemCount` | prop | ✅ | ✅ | `0x16e278` |
| `RBMusicGridLayout` | `-` | `setItemCount:` | prop | ✅ | ✅ | `0x16e288` |
| `RBMusicGridLayout` | `-` | `layouts` | prop | ✅ | ✅ | `0x16e298` |
| `RBMusicGridLayout` | `-` | `setLayouts:` | prop | ✅ | ✅ | `0x16e2a8` |
| `RBCustomSelectCollectionCell` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x16e320` |
| `RBCustomSelectCollectionCell` | `-` | `setIsSelected:` | prop | ✅ | ❌ | `0x16e680` |
| `RBCustomSelectCollectionCell` | `-` | `setHighlighted:` |  | ✅ | ❌ | `0x16e77c` |
| `RBCustomSelectCollectionCell` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x16e810` |
| `RBCustomSelectCollectionCell` | `-` | `prepareForReuse` |  | ✅ | ❌ | `0x16ea10` |
| `RBCustomSelectCollectionCell` | `-` | `itemButton` | prop | ✅ | ✅ | `0x16eab0` |
| `RBCustomSelectCollectionCell` | `-` | `setItemButton:` | prop | ✅ | ✅ | `0x16eac0` |
| `RBCustomSelectCollectionCell` | `-` | `isSelected` | prop | ✅ | ✅ | `0x16eaf8` |
| `RBCustomSelectCollectionCell` | `-` | `selectedImageView` | prop | ✅ | ✅ | `0x16eb08` |
| `RBCustomSelectCollectionCell` | `-` | `setSelectedImageView:` | prop | ✅ | ✅ | `0x16eb18` |
| `RBVolumeSlider` | `-` | `init` |  | ✅ | ❌ | `0x16eb90` |
| `RBVolumeSlider` | `-` | `setValue:` | prop | ✅ | ✅ | `0x16eef4` |
| `RBVolumeSlider` | `-` | `sliderChangeWithTouchPoint:` |  | ✅ | ❌ | `0x16eff0` |
| `RBVolumeSlider` | `-` | `beginTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x16f0b0` |
| `RBVolumeSlider` | `-` | `continueTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x16f154` |
| `RBVolumeSlider` | `-` | `endTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x16f1f8` |
| `RBVolumeSlider` | `-` | `value` | prop | ✅ | ✅ | `0x16f294` |
| `RBVolumeSlider` | `-` | `baseView` | prop | ✅ | ✅ | `0x16f2a4` |
| `RBVolumeSlider` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x16f2b4` |
| `RBVolumeSlider` | `-` | `gaugeView` | prop | ✅ | ✅ | `0x16f2ec` |
| `RBVolumeSlider` | `-` | `setGaugeView:` | prop | ✅ | ✅ | `0x16f2fc` |
| `RBVolumeSlider` | `-` | `barRect` | prop | ✅ | ✅ | `0x16f334` |
| `RBVolumeSlider` | `-` | `setBarRect:` | prop | ✅ | ✅ | `0x16f34c` |
| `RBTermPhoneViewController` | `-` | `init` |  | ✅ | ❌ | `0x16f3a4` |
| `RBTermPhoneViewController` | `-` | `setViewTypeStore` |  | ✅ | ✅ | `0x16f6d4` |
| `RBTermPhoneViewController` | `-` | `dealloc` |  | ❌ | ✅ | `0x16f6e4` |
| `RBTermPhoneViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x16f718` |
| `RBTermPhoneViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x16fe00` |
| `RBTermPhoneViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x16ff9c` |
| `RBTermPhoneViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0x16ffec` |
| `RBTermPhoneViewController` | `-` | `loadList` |  | ✅ | ❌ | `0x170020` |
| `RBTermPhoneViewController` | `-` | `showTermsList` |  | ✅ | ❌ | `0x170878` |
| `RBTermPhoneViewController` | `-` | `selectTerm:` |  | ✅ | ❌ | `0x1713dc` |
| `RBTermPhoneViewController` | `-` | `startLoadAnimation` |  | ✅ | ❌ | `0x1718f0` |
| `RBTermPhoneViewController` | `-` | `endLoadAnimation` |  | ✅ | ❌ | `0x1719f0` |
| `RBTermPhoneViewController` | `-` | `pushBarBtnBack:` |  | ✅ | ❌ | `0x171aa4` |
| `RBTermPhoneViewController` | `-` | `forceClose` |  | ✅ | ❌ | `0x171c68` |
| `RBTermPhoneViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x171d30` |
| `RBTermPhoneViewController` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0x171da8` |
| `RBTermPhoneViewController` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x171dac` |
| `RBTermPhoneViewController` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0x171db0` |
| `RBTermPhoneViewController` | `-` | `isFirstRequest` | prop | ✅ | ✅ | `0x171db4` |
| `RBTermPhoneViewController` | `-` | `setIsFirstRequest:` | prop | ✅ | ✅ | `0x171dc4` |
| `RBTermPhoneViewController` | `-` | `isAnimating` | prop | ✅ | ✅ | `0x171dd4` |
| `RBTermPhoneViewController` | `-` | `setIsAnimating:` | prop | ✅ | ✅ | `0x171de4` |
| `RBTermPhoneViewController` | `-` | `termsListView` | prop | ✅ | ✅ | `0x171df4` |
| `RBTermPhoneViewController` | `-` | `setTermsListView:` | prop | ✅ | ✅ | `0x171e04` |
| `RBTermPhoneViewController` | `-` | `buttons` | prop | ✅ | ✅ | `0x171e14` |
| `RBTermPhoneViewController` | `-` | `setButtons:` | prop | ✅ | ✅ | `0x171e24` |
| `RBTermPhoneViewController` | `-` | `termView` | prop | ✅ | ✅ | `0x171e5c` |
| `RBTermPhoneViewController` | `-` | `setTermView:` | prop | ✅ | ✅ | `0x171e6c` |
| `RBTermPhoneViewController` | `-` | `termsList` | prop | ✅ | ✅ | `0x171e7c` |
| `RBTermPhoneViewController` | `-` | `setTermsList:` | prop | ✅ | ✅ | `0x171e8c` |
| `RBTermPhoneViewController` | `-` | `terms` | prop | ✅ | ✅ | `0x171ec4` |
| `RBTermPhoneViewController` | `-` | `setTerms:` | prop | ✅ | ✅ | `0x171ed4` |
| `RBTermPhoneViewController` | `-` | `downloader` | prop | ✅ | ✅ | `0x171f0c` |
| `RBTermPhoneViewController` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x171f1c` |
| `RBTermPhoneViewController` | `-` | `isUseGrayView` | prop | ✅ | ✅ | `0x171f54` |
| `RBTermPhoneViewController` | `-` | `setIsUseGrayView:` | prop | ✅ | ✅ | `0x171f64` |
| `RBTermPhoneViewController` | `-` | `grayView` | prop | ✅ | ✅ | `0x171f74` |
| `RBTermPhoneViewController` | `-` | `setGrayView:` | prop | ✅ | ✅ | `0x171f84` |
| `RBTermPhoneViewController` | `-` | `indicatorView` | prop | ✅ | ✅ | `0x171f94` |
| `RBTermPhoneViewController` | `-` | `setIndicatorView:` | prop | ✅ | ✅ | `0x171fa4` |
| `RBTermPhoneViewController` | `-` | `viewType` | prop | ✅ | ✅ | `0x171fb4` |
| `RBTermPhoneViewController` | `-` | `setViewType:` | prop | ✅ | ✅ | `0x171fc4` |
| `RBWebView` | `-` | `initWithFrame:superView:` |  | ✅ | ❌ | `0x172af8` |
| `RBWebView` | `-` | `setUseGrayView:` |  | ✅ | ✅ | `0x172ff0` |
| `RBWebView` | `-` | `uiWebView:resource:willSendRequest:redirectResponse:fromDataSource:` |  | ✅ | ❌ | `0x172ffc` |
| `RBWebView` | `-` | `webView:shouldStartLoadWithRequest:navigationType:` |  | ✅ | ❌ | `0x173098` |
| `RBWebView` | `-` | `webViewDidStartLoad:` |  | ✅ | ❌ | `0x17388c` |
| `RBWebView` | `-` | `webViewDidFinishLoad:` |  | ✅ | ❌ | `0x173938` |
| `RBWebView` | `-` | `webView:didFailLoadWithError:` |  | ✅ | ❌ | `0x173ac8` |
| `RBWebView` | `-` | `dealloc` |  | ❌ | ✅ | `0x173d78` |
| `RBWebView` | `-` | `parentView` | prop | ✅ | ✅ | `0x173dac` |
| `RBWebView` | `-` | `setParentView:` | prop | ✅ | ✅ | `0x173dcc` |
| `RBWebView` | `-` | `grayView` | prop | ✅ | ✅ | `0x173de0` |
| `RBWebView` | `-` | `setGrayView:` | prop | ✅ | ✅ | `0x173df0` |
| `RBWebView` | `-` | `isUseGrayView` | prop | ✅ | ✅ | `0x173e28` |
| `RBWebView` | `-` | `setIsUseGrayView:` | prop | ✅ | ✅ | `0x173e38` |
| `RBWebView` | `-` | `indicatorView` | prop | ✅ | ✅ | `0x173e48` |
| `RBWebView` | `-` | `setIndicatorView:` | prop | ✅ | ✅ | `0x173e58` |
| `RBWebView` | `-` | `urlList` | prop | ✅ | ✅ | `0x173e90` |
| `RBWebView` | `-` | `setUrlList:` | prop | ✅ | ✅ | `0x173ea0` |
| `RBMusicSearchExpander` | `-` | `init` |  | ✅ | ❌ | `0x174754` |
| `RBMusicSearchExpander` | `-` | `getDictionary` |  | ✅ | ❌ | `0x1747c8` |
| `RBMusicSearchExpander` | `-` | `addSearchInfo:addWords:` |  | ✅ | ❌ | `0x174840` |
| `RBMusicSearchExpander` | `-` | `addDictionary:` |  | ✅ | ❌ | `0x174a78` |
| `RBMusicSearchExpander` | `-` | `loadDictionary` |  | ✅ | ❌ | `0x174c44` |
| `RBMusicSearchExpander` | `-` | `saveDictionary` |  | ✅ | ❌ | `0x174e48` |
| `RBMusicSearchExpander` | `+` | `copyDictionary` |  | ✅ | ❌ | `0x174fe4` |
| `RBMusicSearchExpander` | `-` | `expandDict` | prop | ✅ | ✅ | `0x1751b4` |
| `RBMusicSearchExpander` | `-` | `setExpandDict:` | prop | ✅ | ✅ | `0x1751c4` |
| `RBUrlSchemeInfoController` | `-` | `action:query:` |  | ✅ | ❌ | `0x176604` |
| `RBUrlSchemeInfoController` | `-` | `webRbAction:` |  | ✅ | ❌ | `0x17671c` |
| `StoreTableCellViewBase` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x1777bc` |
| `StoreTableCellViewBase` | `-` | `dealloc` |  | ✅ | ❌ | `0x177a38` |
| `StoreTableCellViewBase` | `-` | `setBgImage:` |  | ✅ | ❌ | `0x177ac0` |
| `StoreTableCellViewBase` | `-` | `setIsNew:` |  | ✅ | ❌ | `0x177b4c` |
| `StoreTableCellViewBase` | `-` | `handleTap:` |  | ✅ | ❌ | `0x177c40` |
| `StoreTableCellViewBase` | `-` | `reset` |  | ✅ | ✅ | `0x177d20` |
| `StoreTableCellViewBase` | `-` | `delegate` | prop | ✅ | ✅ | `0x177d24` |
| `StoreTableCellViewBase` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x177d44` |
| `StoreTableCellViewBase` | `-` | `index` | prop | ✅ | ✅ | `0x177d58` |
| `StoreTableCellViewBase` | `-` | `setIndex:` | prop | ✅ | ✅ | `0x177d68` |
| `StoreTableCellViewBase` | `-` | `backGroundImageView` | prop | ✅ | ✅ | `0x177d78` |
| `StoreTableCellViewBase` | `-` | `setBackGroundImageView:` | prop | ✅ | ✅ | `0x177d88` |
| `StoreTableCellViewBase` | `-` | `iconNew` | prop | ✅ | ✅ | `0x177dc0` |
| `StoreTableCellViewBase` | `-` | `setIconNew:` | prop | ✅ | ✅ | `0x177dd0` |
| `StoreExtendNoteInfo` | `-` | `initWithDictionary:` |  | ✅ | ❌ | `0x177e58` |
| `StoreExtendNoteInfo` | `-` | `initWithExtendDictionary:` |  | ✅ | ❌ | `0x1781f4` |
| `StoreExtendNoteInfo` | `-` | `initWithProduct:` |  | ✅ | ❌ | `0x17858c` |
| `StoreExtendNoteInfo` | `-` | `initWithExtendNoteID:` |  | ✅ | ❌ | `0x1786d8` |
| `StoreExtendNoteInfo` | `-` | `setDictionary:` |  | ✅ | ❌ | `0x17875c` |
| `StoreExtendNoteInfo` | `-` | `extFileExist` |  | ✅ | ❌ | `0x178ff0` |
| `StoreExtendNoteInfo` | `-` | `getButtonColor` |  | ✅ | ❌ | `0x179078` |
| `StoreExtendNoteInfo` | `-` | `getButtonName` |  | ✅ | ❌ | `0x1791fc` |
| `StoreExtendNoteInfo` | `-` | `getButtonState` |  | ✅ | ❌ | `0x1793cc` |
| `StoreExtendNoteInfo` | `-` | `purchasedPack` | prop | ✅ | ❌ | `0x1794d8` |
| `StoreExtendNoteInfo` | `-` | `purchasedNote` | prop | ✅ | ❌ | `0x1795c0` |
| `StoreExtendNoteInfo` | `-` | `alreadyDownloadBin` | prop | ✅ | ❌ | `0x1796a8` |
| `StoreExtendNoteInfo` | `-` | `alreadyDownloadNote` | prop | ✅ | ❌ | `0x1797e8` |
| `StoreExtendNoteInfo` | `-` | `pid` | prop | ✅ | ✅ | `0x1798f8` |
| `StoreExtendNoteInfo` | `-` | `setPid:` | prop | ✅ | ✅ | `0x179908` |
| `StoreExtendNoteInfo` | `-` | `extMusicID` | prop | ✅ | ✅ | `0x179918` |
| `StoreExtendNoteInfo` | `-` | `setExtMusicID:` | prop | ✅ | ✅ | `0x179928` |
| `StoreExtendNoteInfo` | `-` | `packID` | prop | ✅ | ✅ | `0x179938` |
| `StoreExtendNoteInfo` | `-` | `setPackID:` | prop | ✅ | ✅ | `0x179948` |
| `StoreExtendNoteInfo` | `-` | `packName` | prop | ✅ | ✅ | `0x179958` |
| `StoreExtendNoteInfo` | `-` | `setPackName:` | prop | ✅ | ✅ | `0x179968` |
| `StoreExtendNoteInfo` | `-` | `comment` | prop | ✅ | ✅ | `0x1799a0` |
| `StoreExtendNoteInfo` | `-` | `setComment:` | prop | ✅ | ✅ | `0x1799b0` |
| `StoreExtendNoteInfo` | `-` | `price` | prop | ✅ | ✅ | `0x1799e8` |
| `StoreExtendNoteInfo` | `-` | `setPrice:` | prop | ✅ | ✅ | `0x1799f8` |
| `StoreExtendNoteInfo` | `-` | `difficulty` | prop | ✅ | ✅ | `0x179a08` |
| `StoreExtendNoteInfo` | `-` | `setDifficulty:` | prop | ✅ | ✅ | `0x179a18` |
| `StoreExtendNoteInfo` | `-` | `extendNoteURL` | prop | ✅ | ✅ | `0x179a28` |
| `StoreExtendNoteInfo` | `-` | `setExtendNoteURL:` | prop | ✅ | ✅ | `0x179a38` |
| `StoreExtendNoteInfo` | `-` | `extendURL` | prop | ✅ | ✅ | `0x179a70` |
| `StoreExtendNoteInfo` | `-` | `setExtendURL:` | prop | ✅ | ✅ | `0x179a80` |
| `StoreExtendNoteInfo` | `-` | `isNew` | prop | ✅ | ✅ | `0x179ab8` |
| `StoreExtendNoteInfo` | `-` | `setIsNew:` | prop | ✅ | ✅ | `0x179ac8` |
| `StoreExtendNoteInfo` | `-` | `linkURL` | prop | ✅ | ✅ | `0x179ad8` |
| `StoreExtendNoteInfo` | `-` | `product` | prop | ✅ | ✅ | `0x179ae8` |
| `StoreExtendNoteInfo` | `-` | `setProduct:` | prop | ✅ | ✅ | `0x179af8` |
| `StoreExtendNoteInfoDownloader` | `-` | `initWithStoreExtendNoteInfo:` |  | ✅ | ❌ | `0x179bc0` |
| `StoreExtendNoteInfoDownloader` | `-` | `dealloc` |  | ✅ | ❌ | `0x179c64` |
| `StoreExtendNoteInfoDownloader` | `-` | `downloadDetail:` |  | ✅ | ❌ | `0x179d10` |
| `StoreExtendNoteInfoDownloader` | `-` | `cancel` |  | ✅ | ❌ | `0x179e44` |
| `StoreExtendNoteInfoDownloader` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x179eec` |
| `StoreExtendNoteInfoDownloader` | `-` | `downloaderProceed:` |  | ✅ | ❌ | `0x17a0f0` |
| `StoreExtendNoteInfoDownloader` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x17a1fc` |
| `StoreExtendNoteInfoDownloader` | `-` | `getExtendNoteInfo` |  | ✅ | ✅ | `0x17a31c` |
| `StoreExtendNoteInfoDownloader` | `-` | `getErrorMessage` |  | ✅ | ✅ | `0x17a328` |
| `StoreExtendNoteInfoDownloader` | `-` | `delegate` | prop | ✅ | ✅ | `0x17a334` |
| `StoreExtendNoteInfoDownloader` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x17a354` |
| `StoreExtendNoteInfoDownloader` | `-` | `extendNoteInfo` | prop | ✅ | ✅ | `0x17a368` |
| `StoreExtendNoteInfoDownloader` | `-` | `setExtendNoteInfo:` | prop | ✅ | ✅ | `0x17a378` |
| `StoreExtendNoteInfoDownloader` | `-` | `downloader` | prop | ✅ | ✅ | `0x17a3b0` |
| `StoreExtendNoteInfoDownloader` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x17a3c0` |
| `StoreExtendNoteInfoDownloader` | `-` | `errorMessage` | prop | ✅ | ✅ | `0x17a3f8` |
| `StoreExtendNoteInfoDownloader` | `-` | `setErrorMessage:` | prop | ✅ | ✅ | `0x17a408` |
| `RBServerAPIManager` | `+` | `getInstance` |  | ✅ | ❌ | `0x17ca08` |
| `RBServerAPIManager` | `+` | `playedAPIWithMusicID:dif:` |  | ✅ | ❌ | `0x17cac4` |
| `RBServerAPIManager` | `+` | `playedV2APIWithMusicID:dif:note:jr:score:` |  | ✅ | ❌ | `0x17ce50` |
| `RBServerAPIManager` | `+` | `unlockedAPIWithType:identity:point:` |  | ✅ | ❌ | `0x17d484` |
| `RBServerAPIManager` | `+` | `tutorialAPI` |  | ✅ | ❌ | `0x17d860` |
| `RBServerAPIManager` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x17dc08` |
| `RBServerAPIManager` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x17dca0` |
| `RBServerAPIManager` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x17dca4` |
| `RBServerAPIManager` | `-` | `httpArray` | prop | ✅ | ✅ | `0x17dd3c` |
| `RBServerAPIManager` | `-` | `setHttpArray:` | prop | ✅ | ✅ | `0x17dd4c` |
| `RBTimingSlider` | `-` | `initWithDigit:` |  | ✅ | ❌ | `0x17e3b0` |
| `RBTimingSlider` | `-` | `setValue:` | prop | ✅ | ❌ | `0x17efa8` |
| `RBTimingSlider` | `-` | `sliderChangeWithTouchPoint:` |  | ✅ | ❌ | `0x17f4b4` |
| `RBTimingSlider` | `-` | `beginTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x17f594` |
| `RBTimingSlider` | `-` | `continueTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x17f638` |
| `RBTimingSlider` | `-` | `endTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x17f6dc` |
| `RBTimingSlider` | `-` | `value` | prop | ✅ | ✅ | `0x17f778` |
| `RBTimingSlider` | `-` | `baseView` | prop | ✅ | ✅ | `0x17f788` |
| `RBTimingSlider` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x17f798` |
| `RBTimingSlider` | `-` | `gripView` | prop | ✅ | ✅ | `0x17f7d0` |
| `RBTimingSlider` | `-` | `setGripView:` | prop | ✅ | ✅ | `0x17f7e0` |
| `RBTimingSlider` | `-` | `numImageViews` | prop | ✅ | ✅ | `0x17f818` |
| `RBTimingSlider` | `-` | `setNumImageViews:` | prop | ✅ | ✅ | `0x17f828` |
| `RBTimingSlider` | `-` | `numImages` | prop | ✅ | ✅ | `0x17f860` |
| `RBTimingSlider` | `-` | `setNumImages:` | prop | ✅ | ✅ | `0x17f870` |
| `RBTimingSlider` | `-` | `digit` | prop | ✅ | ✅ | `0x17f8a8` |
| `RBTimingSlider` | `-` | `setDigit:` | prop | ✅ | ✅ | `0x17f8b8` |
| `RBTimingSlider` | `-` | `barRect` | prop | ✅ | ✅ | `0x17f8c8` |
| `RBTimingSlider` | `-` | `setBarRect:` | prop | ✅ | ✅ | `0x17f8e0` |
| `RBTimingSlider` | `-` | `barMin` | prop | ✅ | ✅ | `0x17f8f8` |
| `RBTimingSlider` | `-` | `setBarMin:` | prop | ✅ | ✅ | `0x17f908` |
| `RBTimingSlider` | `-` | `barMax` | prop | ✅ | ✅ | `0x17f918` |
| `RBTimingSlider` | `-` | `setBarMax:` | prop | ✅ | ✅ | `0x17f928` |
| `RBTimingSlider` | `-` | `step` | prop | ✅ | ✅ | `0x17f938` |
| `RBTimingSlider` | `-` | `setStep:` | prop | ✅ | ✅ | `0x17f948` |
| `RBExtendNoteManager` | `+` | `getInstance` |  | ✅ | ❌ | `0x181aac` |
| `RBExtendNoteManager` | `+` | `getExtendNoteDataFilename:` |  | ✅ | ❌ | `0x181b14` |
| `RBExtendNoteManager` | `+` | `getPathFromBundle:` |  | ✅ | ❌ | `0x181b48` |
| `RBExtendNoteManager` | `+` | `getPathFromPurchased:` |  | ✅ | ❌ | `0x181c04` |
| `RBExtendNoteManager` | `+` | `getPathFromPurchasedOldDirectory:` |  | ✅ | ❌ | `0x181cb4` |
| `RBExtendNoteManager` | `-` | `deleteExtendNote:` |  | ✅ | ❌ | `0x181d64` |
| `RBExtendNoteManager` | `-` | `init` |  | ✅ | ❌ | `0x181f64` |
| `RBExtendNoteManager` | `-` | `dealloc` |  | ❌ | ✅ | `0x181f98` |
| `RBExtendNoteManager` | `-` | `loadPurchasedNotes` |  | ✅ | ❌ | `0x181fcc` |
| `RBExtendNoteManager` | `-` | `savePurchasedNotes` |  | ✅ | ❌ | `0x182348` |
| `RBExtendNoteManager` | `-` | `getPurchasedExtendNoteDictionary:` |  | ✅ | ❌ | `0x1825bc` |
| `RBExtendNoteManager` | `-` | `getPurchasedExtendNoteDictionaryWithMusicID:` |  | ✅ | ❌ | `0x182770` |
| `RBExtendNoteManager` | `-` | `getPurchasedExtendNoteDictionaries` |  | ✅ | ✅ | `0x182960` |
| `RBExtendNoteManager` | `-` | `addPurchasedExtendNote:` |  | ✅ | ❌ | `0x18296c` |
| `RBExtendNoteManager` | `-` | `createExtendNoteDataArray` |  | ✅ | ❌ | `0x1834ec` |
| `RBExtendNoteManager` | `-` | `setExtendNoteDataArrayDirty` |  | ✅ | ✅ | `0x1837e8` |
| `RBExtendNoteManager` | `-` | `getExtendNoteDataArray` |  | ✅ | ❌ | `0x1837f8` |
| `RBExtendNoteManager` | `-` | `getExtendNoteData:` |  | ✅ | ❌ | `0x183894` |
| `RBExtendNoteManager` | `-` | `releaseCacheMusicData` |  | ✅ | ❌ | `0x1839f4` |
| `RBExtendNoteManager` | `-` | `getExtendNoteIDs` |  | ✅ | ❌ | `0x183b24` |
| `RBExtendNoteManager` | `-` | `getExtendNoteIDsWithMusicID:` |  | ✅ | ❌ | `0x183cf0` |
| `RBExtendNoteManager` | `-` | `getExtendNoteDataWithMusicID:` |  | ✅ | ❌ | `0x183f14` |
| `RBExtendNoteManager` | `-` | `releaseClientMusic` |  | ✅ | ✅ | `0x1840c0` |
| `RBExtendNoteManager` | `-` | `setClientMusicPageNum:` |  | ✅ | ❌ | `0x1840d0` |
| `RBExtendNoteManager` | `-` | `setClientMusic:` |  | ✅ | ❌ | `0x18416c` |
| `RBExtendNoteManager` | `-` | `getClientCompareExtendNotes` |  | ✅ | ❌ | `0x184238` |
| `RBExtendNoteManager` | `-` | `clientExtendNotePageNum` | prop | ✅ | ✅ | `0x1844e8` |
| `RBExtendNoteManager` | `-` | `setClientExtendNotePageNum:` | prop | ✅ | ✅ | `0x1844f8` |
| `RBExtendNoteManager` | `-` | `clientExtendNotes` | prop | ✅ | ✅ | `0x184508` |
| `RBExtendNoteManager` | `-` | `setClientExtendNotes:` | prop | ✅ | ✅ | `0x184518` |
| `RBExtendNoteManager` | `-` | `purchasedExtendNoteDictionaries` | prop | ✅ | ✅ | `0x184550` |
| `RBExtendNoteManager` | `-` | `setPurchasedExtendNoteDictionaries:` | prop | ✅ | ✅ | `0x184560` |
| `RBExtendNoteManager` | `-` | `extendNoteDataArray` | prop | ✅ | ✅ | `0x184598` |
| `RBExtendNoteManager` | `-` | `setExtendNoteDataArray:` | prop | ✅ | ✅ | `0x1845a8` |
| `RBExtendNoteManager` | `-` | `extendNoteMusicDictionary` | prop | ✅ | ✅ | `0x1845e0` |
| `RBExtendNoteManager` | `-` | `setExtendNoteMusicDictionary:` | prop | ✅ | ✅ | `0x1845f0` |
| `RBExtendNoteManager` | `-` | `extendNoteDataArrayDirtyFlag` | prop | ✅ | ✅ | `0x184628` |
| `RBExtendNoteManager` | `-` | `setExtendNoteDataArrayDirtyFlag:` | prop | ✅ | ✅ | `0x184638` |
| `GraphView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x185ce8` |
| `GraphView` | `-` | `CreateView` |  | ✅ | ❌ | `0x185dc0` |
| `GraphView` | `-` | `setOption:dotSize:lineColor:lineSize:` |  | ✅ | ❌ | `0x185e84` |
| `GraphView` | `-` | `setData:maxValue:` |  | ✅ | ❌ | `0x186004` |
| `GraphView` | `-` | `setData:maxValue:isMovableMinLine:` |  | ✅ | ❌ | `0x186024` |
| `GraphView` | `-` | `drawRect:` |  | ✅ | ❌ | `0x186938` |
| `GraphView` | `-` | `reset` |  | ✅ | ❌ | `0x18702c` |
| `GraphView` | `-` | `m_IsAnimation` | prop | ✅ | ✅ | `0x187214` |
| `GraphView` | `-` | `setM_IsAnimation:` | prop | ✅ | ✅ | `0x187224` |
| `GraphView` | `-` | `dataArray` | prop | ✅ | ✅ | `0x187234` |
| `GraphView` | `-` | `setDataArray:` | prop | ✅ | ✅ | `0x187244` |
| `GraphView` | `-` | `pointArray` | prop | ✅ | ✅ | `0x18727c` |
| `GraphView` | `-` | `setPointArray:` | prop | ✅ | ✅ | `0x18728c` |
| `GraphView` | `-` | `startPos` | prop | ✅ | ✅ | `0x1872c4` |
| `GraphView` | `-` | `setStartPos:` | prop | ✅ | ✅ | `0x1872d8` |
| `GraphView` | `-` | `dotIntervalX` | prop | ✅ | ✅ | `0x1872ec` |
| `GraphView` | `-` | `setDotIntervalX:` | prop | ✅ | ✅ | `0x1872fc` |
| `GraphView` | `-` | `maxValue` | prop | ✅ | ✅ | `0x18730c` |
| `GraphView` | `-` | `setMaxValue:` | prop | ✅ | ✅ | `0x18731c` |
| `GraphView` | `-` | `minValue` | prop | ✅ | ✅ | `0x18732c` |
| `GraphView` | `-` | `setMinValue:` | prop | ✅ | ✅ | `0x18733c` |
| `GraphView` | `-` | `dotColor` | prop | ✅ | ✅ | `0x18734c` |
| `GraphView` | `-` | `setDotColor:` | prop | ✅ | ✅ | `0x18735c` |
| `GraphView` | `-` | `dotSize` | prop | ✅ | ✅ | `0x187394` |
| `GraphView` | `-` | `setDotSize:` | prop | ✅ | ✅ | `0x1873a4` |
| `GraphView` | `-` | `lineColor` | prop | ✅ | ✅ | `0x1873b4` |
| `GraphView` | `-` | `setLineColor:` | prop | ✅ | ✅ | `0x1873c4` |
| `GraphView` | `-` | `lineSize` | prop | ✅ | ✅ | `0x1873fc` |
| `GraphView` | `-` | `setLineSize:` | prop | ✅ | ✅ | `0x18740c` |
| `RBUnlockCollectionView` | `-` | `initWithFrame:experiencePackageData:` |  | ✅ | ❌ | `0x18be3c` |
| `RBUnlockCollectionView` | `-` | `setupView` |  | ✅ | ❌ | `0x18bf24` |
| `RBUnlockCollectionView` | `-` | `reloadData` |  | ✅ | ❌ | `0x18ce6c` |
| `RBUnlockCollectionView` | `-` | `didLayoutSubviews:` |  | ✅ | ❌ | `0x18d274` |
| `RBUnlockCollectionView` | `-` | `configureCell:` |  | ✅ | ❌ | `0x18d380` |
| `RBUnlockCollectionView` | `-` | `collectionView:numberOfItemsInSection:` |  | ✅ | ❌ | `0x18dc24` |
| `RBUnlockCollectionView` | `-` | `collectionView:cellForItemAtIndexPath:` |  | ✅ | ❌ | `0x18dc8c` |
| `RBUnlockCollectionView` | `-` | `collectionView:didHighlightItemAtIndexPath:` |  | ✅ | ❌ | `0x18ddc4` |
| `RBUnlockCollectionView` | `-` | `collectionView:didUnhighlightItemAtIndexPath:` |  | ✅ | ❌ | `0x18de50` |
| `RBUnlockCollectionView` | `-` | `collectionView:didSelectItemAtIndexPath:` |  | ✅ | ❌ | `0x18dedc` |
| `RBUnlockCollectionView` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x18e020` |
| `RBUnlockCollectionView` | `-` | `delegate` | prop | ✅ | ✅ | `0x18e148` |
| `RBUnlockCollectionView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x18e168` |
| `RBUnlockCollectionView` | `-` | `backgroundView` | prop | ✅ | ✅ | `0x18e17c` |
| `RBUnlockCollectionView` | `-` | `setBackgroundView:` | prop | ✅ | ✅ | `0x18e18c` |
| `RBUnlockCollectionView` | `-` | `titleLabel` | prop | ✅ | ✅ | `0x18e1c4` |
| `RBUnlockCollectionView` | `-` | `setTitleLabel:` | prop | ✅ | ✅ | `0x18e1d4` |
| `RBUnlockCollectionView` | `-` | `collectionView` | prop | ✅ | ✅ | `0x18e20c` |
| `RBUnlockCollectionView` | `-` | `setCollectionView:` | prop | ✅ | ✅ | `0x18e21c` |
| `RBUnlockCollectionView` | `-` | `pageControl` | prop | ✅ | ✅ | `0x18e254` |
| `RBUnlockCollectionView` | `-` | `setPageControl:` | prop | ✅ | ✅ | `0x18e264` |
| `RBUnlockCollectionView` | `-` | `experiencePackageData` | prop | ✅ | ✅ | `0x18e29c` |
| `RBUnlockCollectionView` | `-` | `setExperiencePackageData:` | prop | ✅ | ✅ | `0x18e2ac` |
| `RBUnlockCollectionView` | `-` | `items` | prop | ✅ | ✅ | `0x18e2e4` |
| `RBUnlockCollectionView` | `-` | `setItems:` | prop | ✅ | ✅ | `0x18e2f4` |
| `RBPushNotificationView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x18e3cc` |
| `RBPushNotificationView` | `-` | `setupViewWithDelegate:` |  | ✅ | ❌ | `0x18e400` |
| `RBPushNotificationView` | `-` | `showNotification` |  | ✅ | ❌ | `0x18eac4` |
| `RBPushNotificationView` | `-` | `setNextNotification` |  | ✅ | ❌ | `0x18eaf8` |
| `RBPushNotificationView` | `-` | `showAnimation` |  | ✅ | ❌ | `0x18ec60` |
| `RBPushNotificationView` | `-` | `hideAnimationStart` |  | ✅ | ❌ | `0x18efa0` |
| `RBPushNotificationView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x18efe4` |
| `RBPushNotificationView` | `-` | `onTapped:` |  | ✅ | ❌ | `0x18f348` |
| `RBPushNotificationView` | `-` | `stopTimer` |  | ✅ | ❌ | `0x18f6b4` |
| `RBPushNotificationView` | `-` | `dealloc` |  | ✅ | ❌ | `0x18f74c` |
| `RBPushNotificationView` | `-` | `delegate` | prop | ✅ | ✅ | `0x18f7e0` |
| `RBPushNotificationView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x18f800` |
| `RBPushNotificationView` | `-` | `messageLabel` | prop | ✅ | ✅ | `0x18f814` |
| `RBPushNotificationView` | `-` | `setMessageLabel:` | prop | ✅ | ✅ | `0x18f824` |
| `RBPushNotificationView` | `-` | `bgView` | prop | ✅ | ✅ | `0x18f85c` |
| `RBPushNotificationView` | `-` | `setBgView:` | prop | ✅ | ✅ | `0x18f86c` |
| `RBPushNotificationView` | `-` | `message` | prop | ✅ | ✅ | `0x18f8a4` |
| `RBPushNotificationView` | `-` | `setMessage:` | prop | ✅ | ✅ | `0x18f8b4` |
| `RBPushNotificationView` | `-` | `urlString` | prop | ✅ | ✅ | `0x18f8ec` |
| `RBPushNotificationView` | `-` | `setUrlString:` | prop | ✅ | ✅ | `0x18f8fc` |
| `RBPushNotificationView` | `-` | `timer` | prop | ✅ | ✅ | `0x18f934` |
| `RBPushNotificationView` | `-` | `setTimer:` | prop | ✅ | ✅ | `0x18f944` |
| `RBPushNotificationView` | `-` | `upMargin` | prop | ✅ | ✅ | `0x18f97c` |
| `RBPushNotificationView` | `-` | `setUpMargin:` | prop | ✅ | ✅ | `0x18f98c` |
| `RBUnlockCollectionCell` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x18fa28` |
| `RBUnlockCollectionCell` | `-` | `setHighlighted:` |  | ✅ | ❌ | `0x190300` |
| `RBUnlockCollectionCell` | `-` | `setEnabled:` | prop | ✅ | ❌ | `0x1903b0` |
| `RBUnlockCollectionCell` | `-` | `setItemData:` | prop | ✅ | ✅ | `0x190448` |
| `RBUnlockCollectionCell` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x191130` |
| `RBUnlockCollectionCell` | `-` | `prepareForReuse` |  | ✅ | ❌ | `0x1917fc` |
| `RBUnlockCollectionCell` | `-` | `indexPath` | prop | ✅ | ✅ | `0x191910` |
| `RBUnlockCollectionCell` | `-` | `setIndexPath:` | prop | ✅ | ✅ | `0x191920` |
| `RBUnlockCollectionCell` | `-` | `imageView` | prop | ✅ | ✅ | `0x191958` |
| `RBUnlockCollectionCell` | `-` | `setImageView:` | prop | ✅ | ✅ | `0x191968` |
| `RBUnlockCollectionCell` | `-` | `frameImageView` | prop | ✅ | ✅ | `0x1919a0` |
| `RBUnlockCollectionCell` | `-` | `setFrameImageView:` | prop | ✅ | ✅ | `0x1919b0` |
| `RBUnlockCollectionCell` | `-` | `enabled` | prop | ✅ | ✅ | `0x1919e8` |
| `RBUnlockCollectionCell` | `-` | `pointLabel` | prop | ✅ | ✅ | `0x1919f8` |
| `RBUnlockCollectionCell` | `-` | `setPointLabel:` | prop | ✅ | ✅ | `0x191a08` |
| `RBUnlockCollectionCell` | `-` | `itemData` | prop | ✅ | ✅ | `0x191a40` |
| `RBUnlockCollectionCell` | `-` | `badgeView` | prop | ✅ | ✅ | `0x191a50` |
| `RBUnlockCollectionCell` | `-` | `setBadgeView:` | prop | ✅ | ✅ | `0x191a60` |
| `RBUnlockCollectionCell` | `-` | `unlockView` | prop | ✅ | ✅ | `0x191a98` |
| `RBUnlockCollectionCell` | `-` | `setUnlockView:` | prop | ✅ | ✅ | `0x191aa8` |
| `RBUnlockCollectionCell` | `-` | `disableView` | prop | ✅ | ✅ | `0x191ae0` |
| `RBUnlockCollectionCell` | `-` | `setDisableView:` | prop | ✅ | ✅ | `0x191af0` |
| `RBUnlockCollectionCell` | `-` | `imageDownloader` | prop | ✅ | ✅ | `0x191b28` |
| `RBUnlockCollectionCell` | `-` | `setImageDownloader:` | prop | ✅ | ✅ | `0x191b38` |
| `RBNotificationPagePhoneViewController` | `-` | `init` |  | ✅ | ❌ | `0x191c3c` |
| `RBNotificationPagePhoneViewController` | `-` | `dealloc` |  | ❌ | ✅ | `0x191e88` |
| `RBNotificationPagePhoneViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x191ebc` |
| `RBNotificationPagePhoneViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x192308` |
| `RBNotificationPagePhoneViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x192648` |
| `RBNotificationPagePhoneViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0x192928` |
| `RBNotificationPagePhoneViewController` | `-` | `pushBarBtnBack:` |  | ✅ | ❌ | `0x192a60` |
| `RBNotificationPagePhoneViewController` | `-` | `forceClose` |  | ✅ | ❌ | `0x192b28` |
| `RBNotificationPagePhoneViewController` | `-` | `webView:shouldStartLoadWithRequest:navigationType:` |  | ✅ | ❌ | `0x192bdc` |
| `RBNotificationPagePhoneViewController` | `-` | `webView:didFailLoadWithError:` |  | ✅ | ❌ | `0x193058` |
| `RBNotificationPagePhoneViewController` | `-` | `webViewDidStartLoad:` |  | ✅ | ❌ | `0x193120` |
| `RBNotificationPagePhoneViewController` | `-` | `webViewDidFinishLoad:` |  | ✅ | ❌ | `0x193184` |
| `RBNotificationPagePhoneViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x1931fc` |
| `RBNotificationPagePhoneViewController` | `-` | `isFirstRequest` | prop | ✅ | ✅ | `0x19323c` |
| `RBNotificationPagePhoneViewController` | `-` | `setIsFirstRequest:` | prop | ✅ | ✅ | `0x19324c` |
| `RBNotificationPagePhoneViewController` | `-` | `requestURL` | prop | ✅ | ✅ | `0x19325c` |
| `RBNotificationPagePhoneViewController` | `-` | `setRequestURL:` | prop | ✅ | ✅ | `0x19326c` |
| `RBNotificationPageView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x1932b8` |
| `RBNotificationPageView` | `-` | `setupView` |  | ✅ | ❌ | `0x19335c` |
| `RBNotificationPageView` | `-` | `moveStore:` |  | ✅ | ❌ | `0x193918` |
| `RBNotificationPageView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x193a68` |
| `RBNotificationPageView` | `-` | `webView:shouldStartLoadWithRequest:navigationType:` |  | ✅ | ❌ | `0x193abc` |
| `RBNotificationPageView` | `-` | `webView:didFailLoadWithError:` |  | ✅ | ❌ | `0x193f38` |
| `RBNotificationPageView` | `-` | `webViewDidStartLoad:` |  | ✅ | ❌ | `0x194000` |
| `RBNotificationPageView` | `-` | `webViewDidFinishLoad:` |  | ✅ | ❌ | `0x194064` |
| `RBNotificationPageView` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x1940dc` |
| `RBNotificationPageView` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0x19412c` |
| `RBNotificationPageView` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x194130` |
| `RBNotificationPageView` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0x194134` |
| `RBNotificationPageView` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x194138` |
| `RBNotificationPageView` | `-` | `supportedInterfaceOrientations` |  | ✅ | ✅ | `0x194148` |
| `RBNotificationPageView` | `-` | `shouldAutorotate` |  | ✅ | ✅ | `0x194150` |
| `RBNotificationPageView` | `-` | `dealloc` |  | ❌ | ✅ | `0x194158` |
| `RBNotificationPageView` | `-` | `settingView` | prop | ✅ | ✅ | `0x19418c` |
| `RBNotificationPageView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0x1941ac` |
| `RBNotificationPageView` | `-` | `notificationPage` | prop | ✅ | ✅ | `0x1941c0` |
| `RBNotificationPageView` | `-` | `setNotificationPage:` | prop | ✅ | ✅ | `0x1941d0` |
| `RBNotificationPageView` | `-` | `isFirstRequest` | prop | ✅ | ✅ | `0x1941e0` |
| `RBNotificationPageView` | `-` | `setIsFirstRequest:` | prop | ✅ | ✅ | `0x1941f0` |
| `RBNotificationPageView` | `-` | `requestURL` | prop | ✅ | ✅ | `0x194200` |
| `RBNotificationPageView` | `-` | `setRequestURL:` | prop | ✅ | ✅ | `0x194210` |
| `RBUnlockView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x194284` |
| `RBUnlockView` | `-` | `setParentView:` |  | ✅ | ❌ | `0x1942f8` |
| `RBUnlockView` | `-` | `setupView` |  | ✅ | ❌ | `0x194314` |
| `RBUnlockView` | `-` | `reloadData` |  | ✅ | ❌ | `0x194ba0` |
| `RBUnlockView` | `-` | `request` |  | ✅ | ❌ | `0x1955e0` |
| `RBUnlockView` | `-` | `requestRewardCheck` |  | ✅ | ❌ | `0x196544` |
| `RBUnlockView` | `-` | `getUnlockItemView` |  | ✅ | ✅ | `0x1973b4` |
| `RBUnlockView` | `-` | `pushRewardButton:` |  | ✅ | ❌ | `0x1973c0` |
| `RBUnlockView` | `-` | `didSelectView:selectedCell:` |  | ✅ | ❌ | `0x19744c` |
| `RBUnlockView` | `-` | `yesButtonTap:` |  | ✅ | ❌ | `0x197964` |
| `RBUnlockView` | `-` | `noButtonTap:` |  | ✅ | ❌ | `0x1988c4` |
| `RBUnlockView` | `-` | `getMusicInfoWithMusicID:` |  | ✅ | ❌ | `0x198934` |
| `RBUnlockView` | `-` | `downloadWithMusicInfo:` |  | ✅ | ❌ | `0x198e54` |
| `RBUnlockView` | `-` | `dealloc` |  | ❌ | ✅ | `0x1991a4` |
| `RBUnlockView` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x1991d8` |
| `RBUnlockView` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x19954c` |
| `RBUnlockView` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x199550` |
| `RBUnlockView` | `-` | `downloadManagerStartTask:` |  | ✅ | ✅ | `0x1996e8` |
| `RBUnlockView` | `-` | `downloadManagerCompleted:` |  | ✅ | ❌ | `0x1996ec` |
| `RBUnlockView` | `-` | `downloadManagerFailed:` |  | ✅ | ❌ | `0x1998e0` |
| `RBUnlockView` | `-` | `downloadManagerProceed:` |  | ✅ | ❌ | `0x19991c` |
| `RBUnlockView` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x1999bc` |
| `RBUnlockView` | `-` | `parentCustomView` | prop | ✅ | ✅ | `0x1999d8` |
| `RBUnlockView` | `-` | `setParentCustomView:` | prop | ✅ | ✅ | `0x1999f8` |
| `RBUnlockView` | `-` | `pointBackgroundView` | prop | ✅ | ✅ | `0x199a0c` |
| `RBUnlockView` | `-` | `setPointBackgroundView:` | prop | ✅ | ✅ | `0x199a1c` |
| `RBUnlockView` | `-` | `pointLabel` | prop | ✅ | ✅ | `0x199a54` |
| `RBUnlockView` | `-` | `setPointLabel:` | prop | ✅ | ✅ | `0x199a64` |
| `RBUnlockView` | `-` | `scrollView` | prop | ✅ | ✅ | `0x199a9c` |
| `RBUnlockView` | `-` | `setScrollView:` | prop | ✅ | ✅ | `0x199aac` |
| `RBUnlockView` | `-` | `popupView` | prop | ✅ | ✅ | `0x199ae4` |
| `RBUnlockView` | `-` | `setPopupView:` | prop | ✅ | ✅ | `0x199af4` |
| `RBUnlockView` | `-` | `activityIndicatorView` | prop | ✅ | ✅ | `0x199b2c` |
| `RBUnlockView` | `-` | `setActivityIndicatorView:` | prop | ✅ | ✅ | `0x199b3c` |
| `RBUnlockView` | `-` | `storeDownloadManager` | prop | ✅ | ✅ | `0x199b74` |
| `RBUnlockView` | `-` | `setStoreDownloadManager:` | prop | ✅ | ✅ | `0x199b84` |
| `RBUnlockView` | `-` | `downloader` | prop | ✅ | ✅ | `0x199bbc` |
| `RBUnlockView` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x199bcc` |
| `RBUnlockView` | `-` | `progressOverlayView` | prop | ✅ | ✅ | `0x199c04` |
| `RBUnlockView` | `-` | `setProgressOverlayView:` | prop | ✅ | ✅ | `0x199c14` |
| `RBUnlockView` | `-` | `selectedView` | prop | ✅ | ✅ | `0x199c4c` |
| `RBUnlockView` | `-` | `setSelectedView:` | prop | ✅ | ✅ | `0x199c6c` |
| `RBUnlockView` | `-` | `selectedCell` | prop | ✅ | ✅ | `0x199c80` |
| `RBUnlockView` | `-` | `setSelectedCell:` | prop | ✅ | ✅ | `0x199ca0` |
| `RBUnlockView` | `-` | `dlMusicName` | prop | ✅ | ✅ | `0x199cb4` |
| `RBUnlockView` | `-` | `setDlMusicName:` | prop | ✅ | ✅ | `0x199cc4` |
| `RBUnlockView` | `-` | `unlockRandomKey` | prop | ✅ | ✅ | `0x199cd0` |
| `RBUnlockView` | `-` | `setUnlockRandomKey:` | prop | ✅ | ✅ | `0x199ce0` |
| `RBUnlockView` | `-` | `alertView` | prop | ✅ | ✅ | `0x199cf0` |
| `RBUnlockView` | `-` | `setAlertView:` | prop | ✅ | ✅ | `0x199d00` |
| `RBUnlockView` | `-` | `rewardBannerUrl` | prop | ✅ | ✅ | `0x199d38` |
| `RBUnlockView` | `-` | `setRewardBannerUrl:` | prop | ✅ | ✅ | `0x199d48` |
| `RBUnlockView` | `-` | `rewardButton` | prop | ✅ | ✅ | `0x199d80` |
| `RBUnlockView` | `-` | `setRewardButton:` | prop | ✅ | ✅ | `0x199d90` |
| `RBUnlockView` | `-` | `rewardBannerImageView` | prop | ✅ | ✅ | `0x199dc8` |
| `RBUnlockView` | `-` | `setRewardBannerImageView:` | prop | ✅ | ✅ | `0x199dd8` |
| `RBUnlockView` | `-` | `rewardId` | prop | ✅ | ✅ | `0x199e10` |
| `RBUnlockView` | `-` | `setRewardId:` | prop | ✅ | ✅ | `0x199e20` |
| `RBUnlockView` | `-` | `nonce` | prop | ✅ | ✅ | `0x199e58` |
| `RBUnlockView` | `-` | `setNonce:` | prop | ✅ | ✅ | `0x199e68` |
| `RBUnlockPackageItemData` | `-` | `description` |  | ✅ | ❌ | `0x19a014` |
| `RBUnlockPackageItemData` | `-` | `parseDictionary:` |  | ✅ | ❌ | `0x19a168` |
| `RBUnlockPackageItemData` | `-` | `type` | prop | ✅ | ✅ | `0x19a330` |
| `RBUnlockPackageItemData` | `-` | `setType:` | prop | ✅ | ✅ | `0x19a340` |
| `RBUnlockPackageItemData` | `-` | `identity` | prop | ✅ | ✅ | `0x19a350` |
| `RBUnlockPackageItemData` | `-` | `setIdentity:` | prop | ✅ | ✅ | `0x19a360` |
| `RBUnlockPackageItemData` | `-` | `name` | prop | ✅ | ✅ | `0x19a370` |
| `RBUnlockPackageItemData` | `-` | `setName:` | prop | ✅ | ✅ | `0x19a380` |
| `RBUnlockPackageItemData` | `-` | `path` | prop | ✅ | ✅ | `0x19a38c` |
| `RBUnlockPackageItemData` | `-` | `setPath:` | prop | ✅ | ✅ | `0x19a39c` |
| `RBUnlockPackageItemData` | `-` | `point` | prop | ✅ | ✅ | `0x19a3a8` |
| `RBUnlockPackageItemData` | `-` | `setPoint:` | prop | ✅ | ✅ | `0x19a3b8` |
| `RBUnlockPackageData` | `-` | `description` |  | ✅ | ❌ | `0x19a408` |
| `RBUnlockPackageData` | `-` | `parseDictionary:` |  | ✅ | ❌ | `0x19a548` |
| `RBUnlockPackageData` | `-` | `identity` | prop | ✅ | ✅ | `0x19a980` |
| `RBUnlockPackageData` | `-` | `setIdentity:` | prop | ✅ | ✅ | `0x19a990` |
| `RBUnlockPackageData` | `-` | `order` | prop | ✅ | ✅ | `0x19a9a0` |
| `RBUnlockPackageData` | `-` | `setOrder:` | prop | ✅ | ✅ | `0x19a9b0` |
| `RBUnlockPackageData` | `-` | `title` | prop | ✅ | ✅ | `0x19a9c0` |
| `RBUnlockPackageData` | `-` | `setTitle:` | prop | ✅ | ✅ | `0x19a9d0` |
| `RBUnlockPackageData` | `-` | `data` | prop | ✅ | ✅ | `0x19a9dc` |
| `RBUnlockPackageData` | `-` | `setData:` | prop | ✅ | ✅ | `0x19a9ec` |
| `RBUnlockData` | `-` | `description` |  | ✅ | ❌ | `0x19aa64` |
| `RBUnlockData` | `+` | `sharedInstance` |  | ✅ | ❌ | `0x19ab70` |
| `RBUnlockData` | `-` | `save` |  | ✅ | ✅ | `0x19abd4` |
| `RBUnlockData` | `-` | `parseDictionary:` |  | ✅ | ❌ | `0x19abd8` |
| `RBUnlockData` | `-` | `getPackage` |  | ✅ | ❌ | `0x19b28c` |
| `RBUnlockData` | `-` | `setTutorialData` |  | ✅ | ❌ | `0x19b348` |
| `RBUnlockData` | `-` | `version` | prop | ✅ | ✅ | `0x19b710` |
| `RBUnlockData` | `-` | `setVersion:` | prop | ✅ | ✅ | `0x19b720` |
| `RBUnlockData` | `-` | `package` | prop | ✅ | ✅ | `0x19b72c` |
| `RBUnlockData` | `-` | `setPackage:` | prop | ✅ | ✅ | `0x19b73c` |
| `RBUnlockData` | `-` | `versionColette` | prop | ✅ | ✅ | `0x19b774` |
| `RBUnlockData` | `-` | `setVersionColette:` | prop | ✅ | ✅ | `0x19b784` |
| `RBUnlockData` | `-` | `packageColette` | prop | ✅ | ✅ | `0x19b790` |
| `RBUnlockData` | `-` | `setPackageColette:` | prop | ✅ | ✅ | `0x19b7a0` |
| `RBPopupView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x19b840` |
| `RBPopupView` | `-` | `showAnimation` |  | ✅ | ❌ | `0x19b8fc` |
| `RBPopupView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x19ba70` |
| `RBPopupView` | `-` | `tap:` |  | ✅ | ❌ | `0x19bc00` |
| `RBPopupView` | `-` | `dealloc` |  | ❌ | ✅ | `0x19bc1c` |
| `RBPopupView` | `-` | `baseView` | prop | ✅ | ✅ | `0x19bc50` |
| `RBPopupView` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x19bc60` |
| `RBPopupView` | `-` | `contentView` | prop | ✅ | ✅ | `0x19bc98` |
| `RBPopupView` | `-` | `setContentView:` | prop | ✅ | ✅ | `0x19bca8` |
| `RBPopupView` | `-` | `animating` | prop | ✅ | ✅ | `0x19bce0` |
| `RBPopupView` | `-` | `setAnimating:` | prop | ✅ | ✅ | `0x19bcf0` |
| `RBCustomInfoPopupView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x19bd40` |
| `RBCustomInfoPopupView` | `-` | `setupView` |  | ✅ | ❌ | `0x19bdec` |
| `RBCustomInfoPopupView` | `-` | `setItemData:` | prop | ✅ | ✅ | `0x19cef0` |
| `RBCustomInfoPopupView` | `-` | `showAnimation` |  | ✅ | ❌ | `0x19ded8` |
| `RBCustomInfoPopupView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x19e058` |
| `RBCustomInfoPopupView` | `-` | `tap:` |  | ✅ | ❌ | `0x19e1dc` |
| `RBCustomInfoPopupView` | `-` | `itemData` | prop | ✅ | ✅ | `0x19e1f8` |
| `RBCustomInfoPopupView` | `-` | `baseView` | prop | ✅ | ✅ | `0x19e208` |
| `RBCustomInfoPopupView` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x19e218` |
| `RBCustomInfoPopupView` | `-` | `contentView` | prop | ✅ | ✅ | `0x19e250` |
| `RBCustomInfoPopupView` | `-` | `setContentView:` | prop | ✅ | ✅ | `0x19e260` |
| `RBCustomInfoPopupView` | `-` | `usePointLabel` | prop | ✅ | ✅ | `0x19e298` |
| `RBCustomInfoPopupView` | `-` | `setUsePointLabel:` | prop | ✅ | ✅ | `0x19e2a8` |
| `RBCustomInfoPopupView` | `-` | `pointLabel` | prop | ✅ | ✅ | `0x19e2e0` |
| `RBCustomInfoPopupView` | `-` | `setPointLabel:` | prop | ✅ | ✅ | `0x19e2f0` |
| `RBCustomInfoPopupView` | `-` | `yesButton` | prop | ✅ | ✅ | `0x19e328` |
| `RBCustomInfoPopupView` | `-` | `setYesButton:` | prop | ✅ | ✅ | `0x19e338` |
| `RBCustomInfoPopupView` | `-` | `noButton` | prop | ✅ | ✅ | `0x19e370` |
| `RBCustomInfoPopupView` | `-` | `setNoButton:` | prop | ✅ | ✅ | `0x19e380` |
| `RBCustomInfoPopupView` | `-` | `imageView` | prop | ✅ | ✅ | `0x19e3b8` |
| `RBCustomInfoPopupView` | `-` | `setImageView:` | prop | ✅ | ✅ | `0x19e3c8` |
| `RBCustomInfoPopupView` | `-` | `frameImageView` | prop | ✅ | ✅ | `0x19e400` |
| `RBCustomInfoPopupView` | `-` | `setFrameImageView:` | prop | ✅ | ✅ | `0x19e410` |
| `RBCustomInfoPopupView` | `-` | `animating` | prop | ✅ | ✅ | `0x19e448` |
| `RBCustomInfoPopupView` | `-` | `setAnimating:` | prop | ✅ | ✅ | `0x19e458` |
| `RBCustomInfoPopupView` | `-` | `isPad` | prop | ✅ | ✅ | `0x19e468` |
| `RBCustomInfoPopupView` | `-` | `setIsPad:` | prop | ✅ | ✅ | `0x19e478` |
| `RBCustomInfoPopupView` | `-` | `imageDownloader` | prop | ✅ | ✅ | `0x19e488` |
| `RBCustomInfoPopupView` | `-` | `setImageDownloader:` | prop | ✅ | ✅ | `0x19e498` |
| `RBCharacterBase` | `-` | `init` |  | ✅ | ❌ | `0x19e5b0` |
| `RBCharacterBase` | `-` | `setDefault` |  | ✅ | ❌ | `0x19e608` |
| `RBCharacterBase` | `-` | `update` |  | ✅ | ❌ | `0x19e748` |
| `RBCharacterBase` | `-` | `checkLimitType:` |  | ✅ | ❌ | `0x19e9e8` |
| `RBCharacterBase` | `-` | `posX` | prop | ✅ | ✅ | `0x19ea1c` |
| `RBCharacterBase` | `-` | `setPosX:` | prop | ✅ | ✅ | `0x19ea2c` |
| `RBCharacterBase` | `-` | `posY` | prop | ✅ | ✅ | `0x19ea3c` |
| `RBCharacterBase` | `-` | `setPosY:` | prop | ✅ | ✅ | `0x19ea4c` |
| `RBCharacterBase` | `-` | `moveX` | prop | ✅ | ✅ | `0x19ea5c` |
| `RBCharacterBase` | `-` | `setMoveX:` | prop | ✅ | ✅ | `0x19ea6c` |
| `RBCharacterBase` | `-` | `moveY` | prop | ✅ | ✅ | `0x19ea7c` |
| `RBCharacterBase` | `-` | `setMoveY:` | prop | ✅ | ✅ | `0x19ea8c` |
| `RBCharacterBase` | `-` | `accX` | prop | ✅ | ✅ | `0x19ea9c` |
| `RBCharacterBase` | `-` | `setAccX:` | prop | ✅ | ✅ | `0x19eaac` |
| `RBCharacterBase` | `-` | `accY` | prop | ✅ | ✅ | `0x19eabc` |
| `RBCharacterBase` | `-` | `setAccY:` | prop | ✅ | ✅ | `0x19eacc` |
| `RBCharacterBase` | `-` | `useLimit` | prop | ✅ | ✅ | `0x19eadc` |
| `RBCharacterBase` | `-` | `setUseLimit:` | prop | ✅ | ✅ | `0x19eaec` |
| `RBCharacterBase` | `-` | `limitPosUp` | prop | ✅ | ✅ | `0x19eafc` |
| `RBCharacterBase` | `-` | `setLimitPosUp:` | prop | ✅ | ✅ | `0x19eb0c` |
| `RBCharacterBase` | `-` | `limitPosRight` | prop | ✅ | ✅ | `0x19eb1c` |
| `RBCharacterBase` | `-` | `setLimitPosRight:` | prop | ✅ | ✅ | `0x19eb2c` |
| `RBCharacterBase` | `-` | `limitPosDown` | prop | ✅ | ✅ | `0x19eb3c` |
| `RBCharacterBase` | `-` | `setLimitPosDown:` | prop | ✅ | ✅ | `0x19eb4c` |
| `RBCharacterBase` | `-` | `limitPosLeft` | prop | ✅ | ✅ | `0x19eb5c` |
| `RBCharacterBase` | `-` | `setLimitPosLeft:` | prop | ✅ | ✅ | `0x19eb6c` |
| `RBCharacterBase` | `-` | `limitMoveX` | prop | ✅ | ✅ | `0x19eb7c` |
| `RBCharacterBase` | `-` | `setLimitMoveX:` | prop | ✅ | ✅ | `0x19eb8c` |
| `RBCharacterBase` | `-` | `limitMoveY` | prop | ✅ | ✅ | `0x19eb9c` |
| `RBCharacterBase` | `-` | `setLimitMoveY:` | prop | ✅ | ✅ | `0x19ebac` |
| `RBCharacterBase` | `-` | `limitAccX` | prop | ✅ | ✅ | `0x19ebbc` |
| `RBCharacterBase` | `-` | `setLimitAccX:` | prop | ✅ | ✅ | `0x19ebcc` |
| `RBCharacterBase` | `-` | `limitAccY` | prop | ✅ | ✅ | `0x19ebdc` |
| `RBCharacterBase` | `-` | `setLimitAccY:` | prop | ✅ | ✅ | `0x19ebec` |
| `RBMusicMenuPopupView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x19ebfc` |
| `RBMusicMenuPopupView` | `-` | `setupView` |  | ✅ | ❌ | `0x19ec8c` |
| `RBMusicMenuPopupView` | `-` | `showAnimation` |  | ✅ | ❌ | `0x19ff1c` |
| `RBMusicMenuPopupView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x1a0090` |
| `RBMusicMenuPopupView` | `-` | `tap:` |  | ✅ | ❌ | `0x1a027c` |
| `RBMusicMenuPopupView` | `-` | `musicMenuPopupViewType` | prop | ✅ | ✅ | `0x1a0298` |
| `RBMusicMenuPopupView` | `-` | `setMusicMenuPopupViewType:` | prop | ✅ | ✅ | `0x1a02a8` |
| `RBMusicMenuPopupView` | `-` | `musicMenuView` | prop | ✅ | ✅ | `0x1a02b8` |
| `RBMusicMenuPopupView` | `-` | `setMusicMenuView:` | prop | ✅ | ✅ | `0x1a02d8` |
| `RBMusicMenuPopupView` | `-` | `backgroundImageView` | prop | ✅ | ✅ | `0x1a02ec` |
| `RBMusicMenuPopupView` | `-` | `setBackgroundImageView:` | prop | ✅ | ✅ | `0x1a02fc` |
| `RBMusicMenuPopupView` | `-` | `baseView` | prop | ✅ | ✅ | `0x1a030c` |
| `RBMusicMenuPopupView` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x1a031c` |
| `RBMusicMenuPopupView` | `-` | `contentView` | prop | ✅ | ✅ | `0x1a0354` |
| `RBMusicMenuPopupView` | `-` | `setContentView:` | prop | ✅ | ✅ | `0x1a0364` |
| `RBMusicMenuPopupView` | `-` | `gradationImageView` | prop | ✅ | ✅ | `0x1a039c` |
| `RBMusicMenuPopupView` | `-` | `setGradationImageView:` | prop | ✅ | ✅ | `0x1a03ac` |
| `RBMusicMenuPopupView` | `-` | `titleImageView` | prop | ✅ | ✅ | `0x1a03e4` |
| `RBMusicMenuPopupView` | `-` | `setTitleImageView:` | prop | ✅ | ✅ | `0x1a03f4` |
| `RBMusicMenuPopupView` | `-` | `animating` | prop | ✅ | ✅ | `0x1a042c` |
| `RBMusicMenuPopupView` | `-` | `setAnimating:` | prop | ✅ | ✅ | `0x1a043c` |
| `(RB)` | `+` | `clearImageCache` |  | ✅ | ❌ | `0x1a1630` |
| `(RB)` | `+` | `imageWithName:imageDirectory:themaDirectory:retina:` |  | ✅ | ❌ | `0x1a1644` |
| `(RB)` | `+` | `imageWithName:imageDirectory:themaDirectory:` |  | ✅ | ❌ | `0x1a1a0c` |
| `(RB)` | `+` | `imageNamedWithoutCache:` |  | ✅ | ✅ | `0x1a1b08` |
| `(RB)` | `+` | `imageWithName:` |  | ✅ | ❌ | `0x1a2830` |
| `(RB)` | `+` | `imageWithName:useCache:` |  | ✅ | ❌ | `0x1a2858` |
| `(RB)` | `-` | `reflectedImageWithHeight:` |  | ✅ | ❌ | `0x1a2c0c` |
| `(RB)` | `-` | `clipImageWithRect:` |  | ✅ | ✅ | `0x1a2fa4` |
| `(RB)` | `-` | `colorMatrixFilterWithColor:` |  | ✅ | ❌ | `0x1a31a0` |
| `(RB)` | `-` | `colorMatrixFilterWithRed:green:blue:alpha:` |  | ✅ | ❌ | `0x1a3268` |
| `(RB)` | `-` | `left` |  | ✅ | ❌ | `0x1a35ac` |
| `(RB)` | `-` | `top` |  | ✅ | ❌ | `0x1a35b8` |
| `(RB)` | `-` | `right` |  | ✅ | ❌ | `0x1a35d8` |
| `(RB)` | `-` | `bottom` |  | ✅ | ❌ | `0x1a3620` |
| `(RB)` | `-` | `x` |  | ✅ | ❌ | `0x1a3668` |
| `(RB)` | `-` | `y` |  | ✅ | ❌ | `0x1a3674` |
| `(RB)` | `-` | `width` |  | ✅ | ❌ | `0x1a3694` |
| `(RB)` | `-` | `height` |  | ✅ | ❌ | `0x1a36b4` |
| `(RB)` | `-` | `SetFlashEffectDuration:Start:End:` |  | ✅ | ❌ | `0x1a36d4` |
| `(RB)` | `-` | `RemoveFlashEffect` |  | ✅ | ❌ | `0x1a36f4` |
| `(RB)` | `-` | `SetFlashEffectFast` |  | ✅ | ❌ | `0x1a3710` |
| `(RB)` | `-` | `SetFlashEffectFastWithRotate` |  | ✅ | ❌ | `0x1a3730` |
| `(RB)` | `-` | `SetFlashEffectSlow` |  | ✅ | ❌ | `0x1a3760` |
| `(RB)` | `+` | `setFlashEffectView:Duration:Start:End:Rotate:` |  | ✅ | ❌ | `0x1a376c` |
| `(RB)` | `+` | `removeFlashEffectView:` |  | ✅ | ❌ | `0x1a3ecc` |
| `(RB)` | `-` | `SetAlphaAnimationDuration:End:` |  | ✅ | ❌ | `0x1a3f34` |
| `(RB)` | `-` | `RemoveAlphaAnimation` |  | ✅ | ❌ | `0x1a40d8` |
| `(RB)` | `-` | `SetJumpEffectBaseX:BaseY:` |  | ✅ | ❌ | `0x1a4134` |
| `(RB)` | `-` | `RemoveJumpEffect` |  | ✅ | ❌ | `0x1a4414` |
| `(RB)` | `-` | `dictionary` |  | ✅ | ❌ | `0x1a4470` |
| `(RB)` | `-` | `mutableArray` |  | ✅ | ❌ | `0x1a45f8` |
| `RBMusicOtherView` | `-` | `initWithFrame:MusicSelectedBase:` |  | ✅ | ❌ | `0x1a477c` |
| `RBMusicOtherView` | `-` | `dealloc` |  | ❌ | ✅ | `0x1a4a04` |
| `RBMusicOtherView` | `-` | `SetupView` |  | ✅ | ❌ | `0x1a4a38` |
| `RBMusicOtherView` | `-` | `tapFc:` |  | ✅ | ❌ | `0x1a62c0` |
| `RBMusicOtherView` | `-` | `tapJr:` |  | ✅ | ❌ | `0x1a652c` |
| `RBMusicOtherView` | `-` | `tapGhost:` |  | ✅ | ❌ | `0x1a6758` |
| `RBMusicOtherView` | `-` | `tapPastel:` |  | ✅ | ❌ | `0x1a6a5c` |
| `RBMusicOtherView` | `-` | `updateSwitchWithType:` |  | ✅ | ❌ | `0x1a6d00` |
| `RBMusicOtherView` | `-` | `musicSelectedBase` | prop | ✅ | ✅ | `0x1a7438` |
| `RBMusicOtherView` | `-` | `setMusicSelectedBase:` | prop | ✅ | ✅ | `0x1a7458` |
| `RBMusicOtherView` | `-` | `isFcMode` | prop | ✅ | ✅ | `0x1a746c` |
| `RBMusicOtherView` | `-` | `setIsFcMode:` | prop | ✅ | ✅ | `0x1a747c` |
| `RBMusicOtherView` | `-` | `fcView` | prop | ✅ | ✅ | `0x1a748c` |
| `RBMusicOtherView` | `-` | `setFcView:` | prop | ✅ | ✅ | `0x1a749c` |
| `RBMusicOtherView` | `-` | `fcBarRect` | prop | ✅ | ✅ | `0x1a74ac` |
| `RBMusicOtherView` | `-` | `setFcBarRect:` | prop | ✅ | ✅ | `0x1a74c4` |
| `RBMusicOtherView` | `-` | `fcSelectedImage` | prop | ✅ | ✅ | `0x1a74dc` |
| `RBMusicOtherView` | `-` | `setFcSelectedImage:` | prop | ✅ | ✅ | `0x1a74ec` |
| `RBMusicOtherView` | `-` | `isJrMode` | prop | ✅ | ✅ | `0x1a74fc` |
| `RBMusicOtherView` | `-` | `setIsJrMode:` | prop | ✅ | ✅ | `0x1a750c` |
| `RBMusicOtherView` | `-` | `jrView` | prop | ✅ | ✅ | `0x1a751c` |
| `RBMusicOtherView` | `-` | `setJrView:` | prop | ✅ | ✅ | `0x1a752c` |
| `RBMusicOtherView` | `-` | `jrBarRect` | prop | ✅ | ✅ | `0x1a753c` |
| `RBMusicOtherView` | `-` | `setJrBarRect:` | prop | ✅ | ✅ | `0x1a7554` |
| `RBMusicOtherView` | `-` | `jrSelectedImage` | prop | ✅ | ✅ | `0x1a756c` |
| `RBMusicOtherView` | `-` | `setJrSelectedImage:` | prop | ✅ | ✅ | `0x1a757c` |
| `RBMusicOtherView` | `-` | `isGhostMode` | prop | ✅ | ✅ | `0x1a758c` |
| `RBMusicOtherView` | `-` | `setIsGhostMode:` | prop | ✅ | ✅ | `0x1a759c` |
| `RBMusicOtherView` | `-` | `ghostView` | prop | ✅ | ✅ | `0x1a75ac` |
| `RBMusicOtherView` | `-` | `setGhostView:` | prop | ✅ | ✅ | `0x1a75bc` |
| `RBMusicOtherView` | `-` | `ghostBarRect` | prop | ✅ | ✅ | `0x1a75cc` |
| `RBMusicOtherView` | `-` | `setGhostBarRect:` | prop | ✅ | ✅ | `0x1a75e4` |
| `RBMusicOtherView` | `-` | `ghostSelectedImage` | prop | ✅ | ✅ | `0x1a75fc` |
| `RBMusicOtherView` | `-` | `setGhostSelectedImage:` | prop | ✅ | ✅ | `0x1a760c` |
| `RBMusicOtherView` | `-` | `isPastelMode` | prop | ✅ | ✅ | `0x1a761c` |
| `RBMusicOtherView` | `-` | `setIsPastelMode:` | prop | ✅ | ✅ | `0x1a762c` |
| `RBMusicOtherView` | `-` | `pastelView` | prop | ✅ | ✅ | `0x1a763c` |
| `RBMusicOtherView` | `-` | `setPastelView:` | prop | ✅ | ✅ | `0x1a764c` |
| `RBMusicOtherView` | `-` | `pastelBarRect` | prop | ✅ | ✅ | `0x1a765c` |
| `RBMusicOtherView` | `-` | `setPastelBarRect:` | prop | ✅ | ✅ | `0x1a7674` |
| `RBMusicOtherView` | `-` | `pastelSelectedImage` | prop | ✅ | ✅ | `0x1a768c` |
| `RBMusicOtherView` | `-` | `setPastelSelectedImage:` | prop | ✅ | ✅ | `0x1a769c` |
| `RBStoreExtendNoteDetailViewController` | `-` | `initWithExtendNoteInfo:` |  | ✅ | ❌ | `0x1a76bc` |
| `RBStoreExtendNoteDetailViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x1a78c0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setExtendNoteInfo:` |  | ✅ | ❌ | `0x1a78f4` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setDownloadFlag:` |  | ✅ | ✅ | `0x1a7db0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setPurchaseState:` |  | ✅ | ❌ | `0x1a7db4` |
| `RBStoreExtendNoteDetailViewController` | `-` | `hasItem:itemID:` |  | ✅ | ❌ | `0x1a7f2c` |
| `RBStoreExtendNoteDetailViewController` | `-` | `showItemInfo` |  | ✅ | ❌ | `0x1a8040` |
| `RBStoreExtendNoteDetailViewController` | `-` | `loadInfo` |  | ✅ | ❌ | `0x1a8224` |
| `RBStoreExtendNoteDetailViewController` | `-` | `sampleStart` |  | ✅ | ❌ | `0x1a8278` |
| `RBStoreExtendNoteDetailViewController` | `-` | `sampleStop` |  | ✅ | ❌ | `0x1a83d4` |
| `RBStoreExtendNoteDetailViewController` | `-` | `selectButton` |  | ✅ | ❌ | `0x1a8508` |
| `RBStoreExtendNoteDetailViewController` | `-` | `sampleViewStop` |  | ✅ | ❌ | `0x1a8628` |
| `RBStoreExtendNoteDetailViewController` | `-` | `sampleViewDownloading` |  | ✅ | ❌ | `0x1a8700` |
| `RBStoreExtendNoteDetailViewController` | `-` | `sampleViewPlaying` |  | ✅ | ❌ | `0x1a87e4` |
| `RBStoreExtendNoteDetailViewController` | `-` | `handleTapArtworkView` |  | ✅ | ❌ | `0x1a88c0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `finishBgm:` |  | ✅ | ❌ | `0x1a8b38` |
| `RBStoreExtendNoteDetailViewController` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x1a8b54` |
| `RBStoreExtendNoteDetailViewController` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x1a8d08` |
| `RBStoreExtendNoteDetailViewController` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x1a8dc0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `itemInfoDownload` |  | ✅ | ✅ | `0x1a8dc4` |
| `RBStoreExtendNoteDetailViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ✅ | `0x1a8dc8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ❌ | `0x1a8dcc` |
| `RBStoreExtendNoteDetailViewController` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x1a8ebc` |
| `RBStoreExtendNoteDetailViewController` | `-` | `alertViewCancel:` |  | ✅ | ❌ | `0x1a8ec0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0x1a8fb8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `stopDownloadArtworks` |  | ✅ | ❌ | `0x1a90f8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x1a9300` |
| `RBStoreExtendNoteDetailViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ❌ | `0x1a9310` |
| `RBStoreExtendNoteDetailViewController` | `-` | `viewDidUnload` |  | ✅ | ❌ | `0x1a9344` |
| `RBStoreExtendNoteDetailViewController` | `-` | `dealloc` |  | ✅ | ❌ | `0x1a9394` |
| `RBStoreExtendNoteDetailViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x1a9458` |
| `RBStoreExtendNoteDetailViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x1ab7fc` |
| `RBStoreExtendNoteDetailViewController` | `-` | `viewWillDisappear:` |  | ✅ | ❌ | `0x1ab870` |
| `RBStoreExtendNoteDetailViewController` | `-` | `updateLayout` |  | ✅ | ❌ | `0x1aba24` |
| `RBStoreExtendNoteDetailViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0x1ac3ec` |
| `RBStoreExtendNoteDetailViewController` | `-` | `willAnimateRotationToInterfaceOrientation:duration:` |  | ✅ | ❌ | `0x1ac420` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setButtonTextBuy` |  | ✅ | ❌ | `0x1ac470` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setButtonTextInstall` |  | ✅ | ❌ | `0x1ac5fc` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setButtonTextInstalling` |  | ✅ | ❌ | `0x1ac6ac` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setButtonTextInstalled` |  | ✅ | ❌ | `0x1ac75c` |
| `RBStoreExtendNoteDetailViewController` | `-` | `selfCheckButtonText` |  | ✅ | ❌ | `0x1ac80c` |
| `RBStoreExtendNoteDetailViewController` | `-` | `showTerm` |  | ✅ | ❌ | `0x1aca50` |
| `RBStoreExtendNoteDetailViewController` | `-` | `info` | prop | ✅ | ✅ | `0x1acb04` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setInfo:` | prop | ✅ | ✅ | `0x1acb14` |
| `RBStoreExtendNoteDetailViewController` | `-` | `delegate` | prop | ✅ | ✅ | `0x1acb4c` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x1acb6c` |
| `RBStoreExtendNoteDetailViewController` | `-` | `workingIndex` | prop | ✅ | ✅ | `0x1acb80` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setWorkingIndex:` | prop | ✅ | ✅ | `0x1acb90` |
| `RBStoreExtendNoteDetailViewController` | `-` | `mainView` | prop | ✅ | ✅ | `0x1acba0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setMainView:` | prop | ✅ | ✅ | `0x1acbb0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `itemView` | prop | ✅ | ✅ | `0x1acbe8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setItemView:` | prop | ✅ | ✅ | `0x1acbf8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `artworkView` | prop | ✅ | ✅ | `0x1acc30` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setArtworkView:` | prop | ✅ | ✅ | `0x1acc40` |
| `RBStoreExtendNoteDetailViewController` | `-` | `iconNew` | prop | ✅ | ✅ | `0x1acc78` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setIconNew:` | prop | ✅ | ✅ | `0x1acc88` |
| `RBStoreExtendNoteDetailViewController` | `-` | `labelMusicName` | prop | ✅ | ✅ | `0x1accc0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setLabelMusicName:` | prop | ✅ | ✅ | `0x1accd0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `labelArtistName` | prop | ✅ | ✅ | `0x1acd08` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setLabelArtistName:` | prop | ✅ | ✅ | `0x1acd18` |
| `RBStoreExtendNoteDetailViewController` | `-` | `labelLevel` | prop | ✅ | ✅ | `0x1acd50` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setLabelLevel:` | prop | ✅ | ✅ | `0x1acd60` |
| `RBStoreExtendNoteDetailViewController` | `-` | `downloadBtn` | prop | ✅ | ✅ | `0x1acd98` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setDownloadBtn:` | prop | ✅ | ✅ | `0x1acda8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `campaignID` | prop | ✅ | ✅ | `0x1acde0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setCampaignID:` | prop | ✅ | ✅ | `0x1acdf0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `sampleDownloader` | prop | ✅ | ✅ | `0x1ace00` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setSampleDownloader:` | prop | ✅ | ✅ | `0x1ace10` |
| `RBStoreExtendNoteDetailViewController` | `-` | `indicator` | prop | ✅ | ✅ | `0x1ace48` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x1ace58` |
| `RBStoreExtendNoteDetailViewController` | `-` | `sampleView` | prop | ✅ | ✅ | `0x1ace90` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setSampleView:` | prop | ✅ | ✅ | `0x1acea0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `playingView` | prop | ✅ | ✅ | `0x1aced8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setPlayingView:` | prop | ✅ | ✅ | `0x1acee8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `samplePlayedIndex` | prop | ✅ | ✅ | `0x1acf20` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setSamplePlayedIndex:` | prop | ✅ | ✅ | `0x1acf30` |
| `RBStoreExtendNoteDetailViewController` | `-` | `labelLoading` | prop | ✅ | ✅ | `0x1acf40` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setLabelLoading:` | prop | ✅ | ✅ | `0x1acf50` |
| `RBStoreExtendNoteDetailViewController` | `-` | `accessingIndicator` | prop | ✅ | ✅ | `0x1acf88` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setAccessingIndicator:` | prop | ✅ | ✅ | `0x1acf98` |
| `RBStoreExtendNoteDetailViewController` | `-` | `accessingLabel` | prop | ✅ | ✅ | `0x1acfd0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setAccessingLabel:` | prop | ✅ | ✅ | `0x1acfe0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `artworkDownloaders` | prop | ✅ | ✅ | `0x1ad018` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setArtworkDownloaders:` | prop | ✅ | ✅ | `0x1ad028` |
| `RBStoreExtendNoteDetailViewController` | `-` | `packinfoDownloadAlertView` | prop | ✅ | ✅ | `0x1ad060` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setPackinfoDownloadAlertView:` | prop | ✅ | ✅ | `0x1ad070` |
| `RBStoreExtendNoteDetailViewController` | `-` | `closingFlag` | prop | ✅ | ✅ | `0x1ad0a8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setClosingFlag:` | prop | ✅ | ✅ | `0x1ad0b8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `detailView` | prop | ✅ | ✅ | `0x1ad0c8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setDetailView:` | prop | ✅ | ✅ | `0x1ad0d8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `bannerView` | prop | ✅ | ✅ | `0x1ad110` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setBannerView:` | prop | ✅ | ✅ | `0x1ad120` |
| `RBStoreExtendNoteDetailViewController` | `-` | `descriptionTextView` | prop | ✅ | ✅ | `0x1ad158` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setDescriptionTextView:` | prop | ✅ | ✅ | `0x1ad168` |
| `RBStoreExtendNoteDetailViewController` | `-` | `termLinkView` | prop | ✅ | ✅ | `0x1ad1a0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setTermLinkView:` | prop | ✅ | ✅ | `0x1ad1b0` |
| `RBStoreExtendNoteDetailViewController` | `-` | `indicatorSample` | prop | ✅ | ✅ | `0x1ad1e8` |
| `RBStoreExtendNoteDetailViewController` | `-` | `setIndicatorSample:` | prop | ✅ | ✅ | `0x1ad1f8` |
| `RBTutorialPastel` | `-` | `getClipList:` |  | ✅ | ❌ | `0x1ad424` |
| `RBTutorialPastel` | `-` | `getPosition:` |  | ✅ | ❌ | `0x1ad484` |
| `RBTutorialPastel` | `-` | `init` |  | ✅ | ❌ | `0x1ad4b4` |
| `RBTutorialPastel` | `-` | `setupView:` |  | ✅ | ❌ | `0x1ad588` |
| `RBTutorialPastel` | `-` | `startWaveAnimationWithDuration:` |  | ✅ | ❌ | `0x1adfd4` |
| `RBTutorialPastel` | `-` | `startJumpAnimationWithDuration:delay:` |  | ✅ | ❌ | `0x1aff94` |
| `RBTutorialPastel` | `-` | `stopAnimation` |  | ✅ | ❌ | `0x1b2784` |
| `RBTutorialPastel` | `-` | `dealloc` |  | ❌ | ✅ | `0x1b3390` |
| `RBTutorialPastel` | `-` | `headView` | prop | ✅ | ✅ | `0x1b33c4` |
| `RBTutorialPastel` | `-` | `setHeadView:` | prop | ✅ | ✅ | `0x1b33d4` |
| `RBTutorialPastel` | `-` | `bodyView` | prop | ✅ | ✅ | `0x1b340c` |
| `RBTutorialPastel` | `-` | `setBodyView:` | prop | ✅ | ✅ | `0x1b341c` |
| `RBTutorialPastel` | `-` | `rightView` | prop | ✅ | ✅ | `0x1b3454` |
| `RBTutorialPastel` | `-` | `setRightView:` | prop | ✅ | ✅ | `0x1b3464` |
| `RBTutorialPastel` | `-` | `leftView` | prop | ✅ | ✅ | `0x1b349c` |
| `RBTutorialPastel` | `-` | `setLeftView:` | prop | ✅ | ✅ | `0x1b34ac` |
| `RBTutorialPastel` | `-` | `displayRate` | prop | ✅ | ✅ | `0x1b34e4` |
| `RBTutorialPastel` | `-` | `setDisplayRate:` | prop | ✅ | ✅ | `0x1b34f4` |
| `RBTutorialPastelLayer` | `-` | `getClipList:` |  | ✅ | ❌ | `0x1b356c` |
| `RBTutorialPastelLayer` | `-` | `getPosition:` |  | ✅ | ❌ | `0x1b35cc` |
| `RBTutorialPastelLayer` | `-` | `init` |  | ✅ | ❌ | `0x1b35fc` |
| `RBTutorialPastelLayer` | `-` | `setupView:` |  | ✅ | ❌ | `0x1b36fc` |
| `RBTutorialPastelLayer` | `-` | `startWaveAnimationWithDuration:` |  | ✅ | ❌ | `0x1b3cf4` |
| `RBTutorialPastelLayer` | `-` | `startJumpAnimationWithDuration:delay:` |  | ✅ | ❌ | `0x1b58b0` |
| `RBTutorialPastelLayer` | `-` | `stopAnimation` |  | ✅ | ❌ | `0x1b7848` |
| `RBTutorialPastelLayer` | `-` | `dealloc` |  | ❌ | ✅ | `0x1b805c` |
| `RBTutorialPastelLayer` | `-` | `headLayer` | prop | ✅ | ✅ | `0x1b8090` |
| `RBTutorialPastelLayer` | `-` | `setHeadLayer:` | prop | ✅ | ✅ | `0x1b80b0` |
| `RBTutorialPastelLayer` | `-` | `bodyLayer` | prop | ✅ | ✅ | `0x1b80c4` |
| `RBTutorialPastelLayer` | `-` | `setBodyLayer:` | prop | ✅ | ✅ | `0x1b80e4` |
| `RBTutorialPastelLayer` | `-` | `rightLayer` | prop | ✅ | ✅ | `0x1b80f8` |
| `RBTutorialPastelLayer` | `-` | `setRightLayer:` | prop | ✅ | ✅ | `0x1b8118` |
| `RBTutorialPastelLayer` | `-` | `leftLayer` | prop | ✅ | ✅ | `0x1b812c` |
| `RBTutorialPastelLayer` | `-` | `setLeftLayer:` | prop | ✅ | ✅ | `0x1b814c` |
| `RBTutorialPastelLayer` | `-` | `displayRate` | prop | ✅ | ✅ | `0x1b8160` |
| `RBTutorialPastelLayer` | `-` | `setDisplayRate:` | prop | ✅ | ✅ | `0x1b8170` |
| `(RB)` | `-` | `encodeURIComponent` |  | ✅ | ❌ | `0x1b82a4` |
| `(RB)` | `-` | `sizeWithFont:` |  | ✅ | ❌ | `0x1b82d0` |
| `(RB)` | `-` | `sizeWithFont:constrainedToSize:` |  | ✅ | ❌ | `0x1b83c4` |
| `(RB)` | `-` | `sizeWithFont:constrainedToSize:lineBreakMode:` |  | ✅ | ❌ | `0x1b83e4` |
| `(RB)` | `-` | `drawInRect:withFont:` |  | ✅ | ❌ | `0x1b8578` |
| `(RB)` | `-` | `drawInRect:withFont:lineBreakMode:alignment:` |  | ✅ | ❌ | `0x1b8684` |
| `(RB)` | `-` | `drawAtPoint:withFont:` |  | ✅ | ❌ | `0x1b881c` |
| `RBExperienceData` | `-` | `init` |  | ✅ | ✅ | `0x1b8910` |
| `RBExperienceData` | `-` | `initWithCoder:` |  | ✅ | ❌ | `0x1b8bf0` |
| `RBExperienceData` | `-` | `encodeWithCoder:` |  | ✅ | ❌ | `0x1b9788` |
| `RBExperienceData` | `+` | `sharedInstance` |  | ✅ | ✅ | `0x1b9cfc` |
| `RBExperienceData` | `-` | `save` |  | ✅ | ✅ | `0x1b9e50` |
| `RBExperienceData` | `-` | `unlockWithBGMtype:` |  | ✅ | ✅ | `0x1b9f74` |
| `RBExperienceData` | `-` | `unlockWithShotType:` |  | ✅ | ✅ | `0x1ba0c8` |
| `RBExperienceData` | `-` | `unlockWithExprosionType:` |  | ✅ | ✅ | `0x1ba21c` |
| `RBExperienceData` | `-` | `unlockWithFrameType:` |  | ✅ | ✅ | `0x1ba370` |
| `RBExperienceData` | `-` | `unlockWithBackgroundType:` |  | ✅ | ✅ | `0x1ba4c4` |
| `RBExperienceData` | `-` | `unlockWithMusicID:` |  | ✅ | ✅ | `0x1ba618` |
| `RBExperienceData` | `-` | `unlockWithThemaID:` |  | ✅ | ✅ | `0x1ba76c` |
| `RBExperienceData` | `-` | `unlockWithType:ID:` |  | ✅ | ✅ | `0x1ba8c0` |
| `RBExperienceData` | `-` | `addBGMType:` |  | ✅ | ❌ | `0x1ba980` |
| `RBExperienceData` | `-` | `addShotType:` |  | ✅ | ❌ | `0x1baa24` |
| `RBExperienceData` | `-` | `addExprosionType:` |  | ✅ | ❌ | `0x1baac8` |
| `RBExperienceData` | `-` | `addFrameType:` |  | ✅ | ❌ | `0x1bab6c` |
| `RBExperienceData` | `-` | `addBackgroundType:` |  | ✅ | ❌ | `0x1bac10` |
| `RBExperienceData` | `-` | `addMusicID:` |  | ✅ | ❌ | `0x1bacb4` |
| `RBExperienceData` | `-` | `addThemaID:` |  | ✅ | ❌ | `0x1bad58` |
| `RBExperienceData` | `-` | `addItem:ID:` |  | ✅ | ❌ | `0x1badfc` |
| `RBExperienceData` | `-` | `addRewardAppliId:andAppliId:` |  | ✅ | ❌ | `0x1baebc` |
| `RBExperienceData` | `-` | `getRewardAppliId:` |  | ✅ | ❌ | `0x1bb0a0` |
| `RBExperienceData` | `-` | `addPoint:` |  | ✅ | ❌ | `0x1bb21c` |
| `RBExperienceData` | `-` | `getPoint` |  | ✅ | ❌ | `0x1bb2fc` |
| `RBExperienceData` | `-` | `resetPoint:` |  | ✅ | ❌ | `0x1bb3a8` |
| `RBExperienceData` | `-` | `takeover` |  | ✅ | ❌ | `0x1bb3c4` |
| `RBExperienceData` | `-` | `takeoverPoint` |  | ✅ | ❌ | `0x1bba38` |
| `RBExperienceData` | `-` | `initialized` |  | ✅ | ❌ | `0x1bc104` |
| `RBExperienceData` | `-` | `encodePoint:` |  | ✅ | ❌ | `0x1bc554` |
| `RBExperienceData` | `-` | `decodePoint:` |  | ✅ | ❌ | `0x1bc770` |
| `RBExperienceData` | `-` | `encodeAppliIds:` |  | ✅ | ❌ | `0x1bc9f4` |
| `RBExperienceData` | `-` | `decodeAppliIds:` |  | ✅ | ❌ | `0x1bcbd8` |
| `RBExperienceData` | `-` | `noUnlocked` |  | ✅ | ❌ | `0x1bce1c` |
| `RBExperienceData` | `-` | `writeLog:` |  | ✅ | ✅ | `0x1bd0cc` |
| `RBExperienceData` | `-` | `installedAppliId` | prop | ✅ | ✅ | `0x1bd0d0` |
| `RBExperienceData` | `-` | `setInstalledAppliId:` | prop | ✅ | ✅ | `0x1bd0e0` |
| `RBExperienceData` | `-` | `point` | prop | ✅ | ✅ | `0x1bd0f0` |
| `RBExperienceData` | `-` | `setPoint:` | prop | ✅ | ✅ | `0x1bd100` |
| `RBExperienceData` | `-` | `pointB` | prop | ✅ | ✅ | `0x1bd110` |
| `RBExperienceData` | `-` | `setPointB:` | prop | ✅ | ✅ | `0x1bd120` |
| `RBExperienceData` | `-` | `pointC` | prop | ✅ | ✅ | `0x1bd130` |
| `RBExperienceData` | `-` | `setPointC:` | prop | ✅ | ✅ | `0x1bd140` |
| `RBExperienceData` | `-` | `version` | prop | ✅ | ✅ | `0x1bd150` |
| `RBExperienceData` | `-` | `setVersion:` | prop | ✅ | ✅ | `0x1bd160` |
| `RBExperienceData` | `-` | `pointDate` | prop | ✅ | ✅ | `0x1bd16c` |
| `RBExperienceData` | `-` | `setPointDate:` | prop | ✅ | ✅ | `0x1bd17c` |
| `RBExperienceData` | `-` | `pointS` | prop | ✅ | ✅ | `0x1bd188` |
| `RBExperienceData` | `-` | `setPointS:` | prop | ✅ | ✅ | `0x1bd198` |
| `RBExperienceData` | `-` | `pointP` | prop | ✅ | ✅ | `0x1bd1a4` |
| `RBExperienceData` | `-` | `setPointP:` | prop | ✅ | ✅ | `0x1bd1b4` |
| `RBExperienceData` | `-` | `pos` | prop | ✅ | ✅ | `0x1bd1c0` |
| `RBExperienceData` | `-` | `setPos:` | prop | ✅ | ✅ | `0x1bd1d0` |
| `RBExperienceData` | `-` | `pointData` | prop | ✅ | ✅ | `0x1bd1dc` |
| `RBExperienceData` | `-` | `setPointData:` | prop | ✅ | ✅ | `0x1bd1ec` |
| `RBExperienceData` | `-` | `pointDataB` | prop | ✅ | ✅ | `0x1bd1f8` |
| `RBExperienceData` | `-` | `setPointDataB:` | prop | ✅ | ✅ | `0x1bd208` |
| `RBExperienceData` | `-` | `pointDataC` | prop | ✅ | ✅ | `0x1bd214` |
| `RBExperienceData` | `-` | `setPointDataC:` | prop | ✅ | ✅ | `0x1bd224` |
| `RBExperienceData` | `-` | `bgmItems` | prop | ✅ | ✅ | `0x1bd230` |
| `RBExperienceData` | `-` | `setBgmItems:` | prop | ✅ | ✅ | `0x1bd240` |
| `RBExperienceData` | `-` | `shotItems` | prop | ✅ | ✅ | `0x1bd278` |
| `RBExperienceData` | `-` | `setShotItems:` | prop | ✅ | ✅ | `0x1bd288` |
| `RBExperienceData` | `-` | `explosionItems` | prop | ✅ | ✅ | `0x1bd2c0` |
| `RBExperienceData` | `-` | `setExplosionItems:` | prop | ✅ | ✅ | `0x1bd2d0` |
| `RBExperienceData` | `-` | `frameItems` | prop | ✅ | ✅ | `0x1bd308` |
| `RBExperienceData` | `-` | `setFrameItems:` | prop | ✅ | ✅ | `0x1bd318` |
| `RBExperienceData` | `-` | `backgroundItems` | prop | ✅ | ✅ | `0x1bd350` |
| `RBExperienceData` | `-` | `setBackgroundItems:` | prop | ✅ | ✅ | `0x1bd360` |
| `RBExperienceData` | `-` | `musicItems` | prop | ✅ | ✅ | `0x1bd398` |
| `RBExperienceData` | `-` | `setMusicItems:` | prop | ✅ | ✅ | `0x1bd3a8` |
| `RBExperienceData` | `-` | `themaItems` | prop | ✅ | ✅ | `0x1bd3e0` |
| `RBExperienceData` | `-` | `setThemaItems:` | prop | ✅ | ✅ | `0x1bd3f0` |
| `RBExperienceData` | `-` | `installedAppliIds` | prop | ✅ | ✅ | `0x1bd428` |
| `RBExperienceData` | `-` | `setInstalledAppliIds:` | prop | ✅ | ✅ | `0x1bd438` |
| `RBExperienceData` | `-` | `installedAppliIdsData` | prop | ✅ | ✅ | `0x1bd470` |
| `RBExperienceData` | `-` | `setInstalledAppliIdsData:` | prop | ✅ | ✅ | `0x1bd480` |
| `RBApplilinkView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x1bd624` |
| `RBApplilinkView` | `-` | `setupView` |  | ✅ | ❌ | `0x1bd6c8` |
| `RBApplilinkView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x1bdd50` |
| `RBApplilinkView` | `-` | `showAnimation` |  | ✅ | ❌ | `0x1bde84` |
| `RBApplilinkView` | `-` | `appListDidAppear` |  | ✅ | ❌ | `0x1bdf74` |
| `RBApplilinkView` | `-` | `appListDidDisappear` |  | ✅ | ❌ | `0x1be1a0` |
| `RBApplilinkView` | `-` | `appListFailLoadWithError:` |  | ✅ | ❌ | `0x1be258` |
| `RBApplilinkView` | `-` | `dealloc` |  | ❌ | ✅ | `0x1be314` |
| `RBApplilinkView` | `-` | `settingView` | prop | ✅ | ✅ | `0x1be348` |
| `RBApplilinkView` | `-` | `setSettingView:` | prop | ✅ | ✅ | `0x1be368` |
| `RBApplilinkView` | `-` | `webTargetView` | prop | ✅ | ✅ | `0x1be37c` |
| `RBApplilinkView` | `-` | `setWebTargetView:` | prop | ✅ | ✅ | `0x1be38c` |
| `RBApplilinkView` | `-` | `indicatorView` | prop | ✅ | ✅ | `0x1be3c4` |
| `RBApplilinkView` | `-` | `setIndicatorView:` | prop | ✅ | ✅ | `0x1be3d4` |
| `RBApplilinkView` | `-` | `webTargetAnimating` | prop | ✅ | ✅ | `0x1be40c` |
| `RBApplilinkView` | `-` | `setWebTargetAnimating:` | prop | ✅ | ✅ | `0x1be41c` |
| `RBApplilinkView` | `-` | `hideAnimating` | prop | ✅ | ✅ | `0x1be42c` |
| `RBApplilinkView` | `-` | `setHideAnimating:` | prop | ✅ | ✅ | `0x1be43c` |
| `RBMenuPageSlider` | `-` | `initWithFrame:delegate:` |  | ✅ | ❌ | `0x1beba8` |
| `RBMenuPageSlider` | `-` | `reset:currentPage:` |  | ✅ | ❌ | `0x1bf698` |
| `RBMenuPageSlider` | `-` | `setValue:` | prop | ✅ | ❌ | `0x1bf79c` |
| `RBMenuPageSlider` | `-` | `sliderChangeWithTouchPoint:isEnd:` |  | ✅ | ❌ | `0x1bfb24` |
| `RBMenuPageSlider` | `-` | `beginTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x1bfe68` |
| `RBMenuPageSlider` | `-` | `continueTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x1bff4c` |
| `RBMenuPageSlider` | `-` | `endTrackingWithTouch:withEvent:` |  | ✅ | ❌ | `0x1bfff4` |
| `RBMenuPageSlider` | `-` | `value` | prop | ✅ | ✅ | `0x1c00cc` |
| `RBMenuPageSlider` | `-` | `slideGaugeView` | prop | ✅ | ✅ | `0x1c00dc` |
| `RBMenuPageSlider` | `-` | `setSlideGaugeView:` | prop | ✅ | ✅ | `0x1c00ec` |
| `RBMenuPageSlider` | `-` | `gripView` | prop | ✅ | ✅ | `0x1c00fc` |
| `RBMenuPageSlider` | `-` | `setGripView:` | prop | ✅ | ✅ | `0x1c010c` |
| `RBMenuPageSlider` | `-` | `indexLabel` | prop | ✅ | ✅ | `0x1c011c` |
| `RBMenuPageSlider` | `-` | `setIndexLabel:` | prop | ✅ | ✅ | `0x1c012c` |
| `RBMenuPageSlider` | `-` | `barMin` | prop | ✅ | ✅ | `0x1c013c` |
| `RBMenuPageSlider` | `-` | `setBarMin:` | prop | ✅ | ✅ | `0x1c014c` |
| `RBMenuPageSlider` | `-` | `barMax` | prop | ✅ | ✅ | `0x1c015c` |
| `RBMenuPageSlider` | `-` | `setBarMax:` | prop | ✅ | ✅ | `0x1c016c` |
| `RBMenuPageSlider` | `-` | `step` | prop | ✅ | ✅ | `0x1c017c` |
| `RBMenuPageSlider` | `-` | `setStep:` | prop | ✅ | ✅ | `0x1c018c` |
| `RBMenuPageSlider` | `-` | `delegate` | prop | ✅ | ✅ | `0x1c019c` |
| `RBMenuPageSlider` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x1c01ac` |
| `RBMenuPageSliderView` | `-` | `initWithFrame:delegate:` |  | ✅ | ❌ | `0x1c01bc` |
| `RBMenuPageSliderView` | `-` | `showView:pageMax:currentPage:` |  | ✅ | ❌ | `0x1c03b4` |
| `RBMenuPageSliderView` | `-` | `willRotate` |  | ✅ | ❌ | `0x1c0578` |
| `RBMenuPageSliderView` | `-` | `didRotate` |  | ✅ | ❌ | `0x1c05e8` |
| `RBMenuPageSliderView` | `-` | `reset:currentPage:` |  | ✅ | ❌ | `0x1c0750` |
| `RBMenuPageSliderView` | `-` | `setIndexLabel:` |  | ✅ | ❌ | `0x1c07bc` |
| `RBMenuPageSliderView` | `-` | `hideAnimation` |  | ✅ | ❌ | `0x1c09b0` |
| `RBMenuPageSliderView` | `-` | `slider` | prop | ✅ | ✅ | `0x1c0a38` |
| `RBMenuPageSliderView` | `-` | `setSlider:` | prop | ✅ | ✅ | `0x1c0a48` |
| `RBMenuPageSliderView` | `-` | `animating` | prop | ❌ | ✅ | `0x1c0a58` |
| `RBMenuPageSliderView` | `-` | `setAnimating:` | prop | ❌ | ✅ | `0x1c0a68` |
| `StoreExtendNoteCellPhone` | `-` | `initWithStyle:reuseIdentifier:` |  | ✅ | ❌ | `0x1c0abc` |
| `StoreExtendNoteCellPhone` | `-` | `isPurchased` | prop | ✅ | ❌ | `0x1c1b78` |
| `StoreExtendNoteCellPhone` | `-` | `setIsPurchased:` | prop | ✅ | ❌ | `0x1c1bd8` |
| `StoreExtendNoteCellPhone` | `-` | `loadExtendNoteInfo:index:` |  | ✅ | ❌ | `0x1c1c34` |
| `StoreExtendNoteCellPhone` | `-` | `setBgImage:` |  | ✅ | ❌ | `0x1c1fa0` |
| `StoreExtendNoteCellPhone` | `-` | `setBgColor:` |  | ✅ | ✅ | `0x1c202c` |
| `StoreExtendNoteCellPhone` | `-` | `artworkLayer` | prop | ✅ | ✅ | `0x1c2030` |
| `StoreExtendNoteCellPhone` | `-` | `setArtworkLayer:` | prop | ✅ | ✅ | `0x1c2040` |
| `StoreExtendNoteCellPhone` | `-` | `bgImageView` | prop | ✅ | ✅ | `0x1c2078` |
| `StoreExtendNoteCellPhone` | `-` | `setBgImageView:` | prop | ✅ | ✅ | `0x1c2088` |
| `StoreExtendNoteCellPhone` | `-` | `nameLabel` | prop | ✅ | ✅ | `0x1c20c0` |
| `StoreExtendNoteCellPhone` | `-` | `setNameLabel:` | prop | ✅ | ✅ | `0x1c20d0` |
| `StoreExtendNoteCellPhone` | `-` | `artistLabel` | prop | ✅ | ✅ | `0x1c2108` |
| `StoreExtendNoteCellPhone` | `-` | `setArtistLabel:` | prop | ✅ | ✅ | `0x1c2118` |
| `StoreExtendNoteCellPhone` | `-` | `levelLabel` | prop | ✅ | ✅ | `0x1c2150` |
| `StoreExtendNoteCellPhone` | `-` | `setLevelLabel:` | prop | ✅ | ✅ | `0x1c2160` |
| `StoreExtendNoteCellPhone` | `-` | `purchasedLabel` | prop | ✅ | ✅ | `0x1c2198` |
| `StoreExtendNoteCellPhone` | `-` | `setPurchasedLabel:` | prop | ✅ | ✅ | `0x1c21a8` |
| `StoreExtendNoteCellPhone` | `-` | `iconNewLayer` | prop | ✅ | ✅ | `0x1c21e0` |
| `StoreExtendNoteCellPhone` | `-` | `setIconNewLayer:` | prop | ✅ | ✅ | `0x1c21f0` |
| `SSZipArchive` | `+` | `unzipFileAtPath:toDestination:` |  | ❌ | ❌ | `0x1c22cc` |
| `SSZipArchive` | `+` | `unzipFileAtPath:toDestination:overwrite:password:error:` |  | ❌ | ❌ | `0x1c232c` |
| `SSZipArchive` | `+` | `unzipFileAtPath:toDestination:delegate:` |  | ❌ | ❌ | `0x1c23c0` |
| `SSZipArchive` | `+` | `unzipFileAtPath:toDestination:overwrite:password:error:delegate:` |  | ❌ | ❌ | `0x1c2444` |
| `SSZipArchive` | `+` | `createZipFileAtPath:withFilesAtPaths:` |  | ❌ | ❌ | `0x1c31b4` |
| `SSZipArchive` | `+` | `createZipFileAtPath:withContentsOfDirectory:` |  | ❌ | ❌ | `0x1c3358` |
| `SSZipArchive` | `-` | `initWithPath:` |  | ❌ | ❌ | `0x1c352c` |
| `SSZipArchive` | `-` | `open` |  | ❌ | ❌ | `0x1c35b8` |
| `SSZipArchive` | `-` | `zipInfo:setDate:` |  | ❌ | ❌ | `0x1c3608` |
| `SSZipArchive` | `-` | `writeFile:` |  | ❌ | ❌ | `0x1c3710` |
| `SSZipArchive` | `-` | `writeFileAtPath:withFileName:` |  | ❌ | ❌ | `0x1c3720` |
| `SSZipArchive` | `-` | `writeData:filename:` |  | ❌ | ❌ | `0x1c39e4` |
| `SSZipArchive` | `-` | `close` |  | ❌ | ❌ | `0x1c3b58` |
| `SSZipArchive` | `+` | `_dateWithMSDOSFormat:` |  | ❌ | ❌ | `0x1c3b80` |
| `RBTermAgreeView` | `-` | `initWithFrame:termType:` |  | ✅ | ❌ | `0x1c3d58` |
| `RBTermAgreeView` | `-` | `setupView` |  | ✅ | ❌ | `0x1c3e7c` |
| `RBTermAgreeView` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x1c664c` |
| `RBTermAgreeView` | `-` | `hideAnimation` |  | ✅ | ✅ | `0x1c6a38` |
| `RBTermAgreeView` | `-` | `_hideAnimation` |  | ✅ | ❌ | `0x1c6a3c` |
| `RBTermAgreeView` | `-` | `showTermView` |  | ✅ | ❌ | `0x1c6c50` |
| `RBTermAgreeView` | `-` | `selectAgree` |  | ✅ | ❌ | `0x1c7698` |
| `RBTermAgreeView` | `-` | `selectDisAgree` |  | ✅ | ❌ | `0x1c7744` |
| `RBTermAgreeView` | `-` | `startLoadAnimation` |  | ✅ | ❌ | `0x1c77f0` |
| `RBTermAgreeView` | `-` | `endLoadAnimation` |  | ✅ | ❌ | `0x1c78a4` |
| `RBTermAgreeView` | `-` | `loadDetail` |  | ✅ | ❌ | `0x1c7958` |
| `RBTermAgreeView` | `-` | `sendAgree` |  | ✅ | ❌ | `0x1c813c` |
| `RBTermAgreeView` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x1c8c88` |
| `RBTermAgreeView` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x1c9320` |
| `RBTermAgreeView` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0x1c946c` |
| `RBTermAgreeView` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x1c9470` |
| `RBTermAgreeView` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0x1c9474` |
| `RBTermAgreeView` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x1c9478` |
| `RBTermAgreeView` | `-` | `supportedInterfaceOrientations` |  | ✅ | ✅ | `0x1c9488` |
| `RBTermAgreeView` | `-` | `shouldAutorotate` |  | ✅ | ✅ | `0x1c9490` |
| `RBTermAgreeView` | `-` | `dealloc` |  | ❌ | ✅ | `0x1c9498` |
| `RBTermAgreeView` | `-` | `parentViewController` | prop | ✅ | ✅ | `0x1c94cc` |
| `RBTermAgreeView` | `-` | `setParentViewController:` | prop | ✅ | ✅ | `0x1c94ec` |
| `RBTermAgreeView` | `-` | `delegate` | prop | ✅ | ✅ | `0x1c9500` |
| `RBTermAgreeView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x1c9520` |
| `RBTermAgreeView` | `-` | `isAnimating` | prop | ✅ | ✅ | `0x1c9534` |
| `RBTermAgreeView` | `-` | `setIsAnimating:` | prop | ✅ | ✅ | `0x1c9544` |
| `RBTermAgreeView` | `-` | `termView` | prop | ✅ | ✅ | `0x1c9554` |
| `RBTermAgreeView` | `-` | `setTermView:` | prop | ✅ | ✅ | `0x1c9564` |
| `RBTermAgreeView` | `-` | `termTextView` | prop | ✅ | ✅ | `0x1c9574` |
| `RBTermAgreeView` | `-` | `setTermTextView:` | prop | ✅ | ✅ | `0x1c9584` |
| `RBTermAgreeView` | `-` | `termTextViewHeight` | prop | ✅ | ✅ | `0x1c9594` |
| `RBTermAgreeView` | `-` | `setTermTextViewHeight:` | prop | ✅ | ✅ | `0x1c95a4` |
| `RBTermAgreeView` | `-` | `terms` | prop | ✅ | ✅ | `0x1c95b4` |
| `RBTermAgreeView` | `-` | `setTerms:` | prop | ✅ | ✅ | `0x1c95c4` |
| `RBTermAgreeView` | `-` | `downloader` | prop | ✅ | ✅ | `0x1c95fc` |
| `RBTermAgreeView` | `-` | `setDownloader:` | prop | ✅ | ✅ | `0x1c960c` |
| `RBTermAgreeView` | `-` | `isUseGrayView` | prop | ✅ | ✅ | `0x1c9644` |
| `RBTermAgreeView` | `-` | `setIsUseGrayView:` | prop | ✅ | ✅ | `0x1c9654` |
| `RBTermAgreeView` | `-` | `grayView` | prop | ✅ | ✅ | `0x1c9664` |
| `RBTermAgreeView` | `-` | `setGrayView:` | prop | ✅ | ✅ | `0x1c9674` |
| `RBTermAgreeView` | `-` | `indicatorView` | prop | ✅ | ✅ | `0x1c9684` |
| `RBTermAgreeView` | `-` | `setIndicatorView:` | prop | ✅ | ✅ | `0x1c9694` |
| `RBTermAgreeView` | `-` | `agreeButton` | prop | ✅ | ✅ | `0x1c96a4` |
| `RBTermAgreeView` | `-` | `setAgreeButton:` | prop | ✅ | ✅ | `0x1c96b4` |
| `RBTermAgreeView` | `-` | `disAgreeButton` | prop | ✅ | ✅ | `0x1c96c4` |
| `RBTermAgreeView` | `-` | `setDisAgreeButton:` | prop | ✅ | ✅ | `0x1c96d4` |
| `RBTermAgreeView` | `-` | `type` | prop | ✅ | ✅ | `0x1c96e4` |
| `RBTermAgreeView` | `-` | `setType:` | prop | ✅ | ✅ | `0x1c96f4` |
| `RBTermAgreeView` | `-` | `pastelView` | prop | ✅ | ✅ | `0x1c9704` |
| `RBTermAgreeView` | `-` | `setPastelView:` | prop | ✅ | ✅ | `0x1c9714` |
| `RBTermAgreeView` | `-` | `pastelImageView` | prop | ✅ | ✅ | `0x1c9724` |
| `RBTermAgreeView` | `-` | `setPastelImageView:` | prop | ✅ | ✅ | `0x1c9734` |
| `RBTermAgreeView` | `-` | `pastelImageFinishView` | prop | ✅ | ✅ | `0x1c9744` |
| `RBTermAgreeView` | `-` | `setPastelImageFinishView:` | prop | ✅ | ✅ | `0x1c9754` |
| `RBTermAgreeView` | `-` | `trackImageView` | prop | ✅ | ✅ | `0x1c9764` |
| `RBTermAgreeView` | `-` | `setTrackImageView:` | prop | ✅ | ✅ | `0x1c9774` |
| `RBTermAgreeView` | `-` | `progressImageView` | prop | ✅ | ✅ | `0x1c9784` |
| `RBTermAgreeView` | `-` | `setProgressImageView:` | prop | ✅ | ✅ | `0x1c9794` |
| `RBNavigationController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x1c9804` |
| `RBNavigationController` | `-` | `prefersStatusBarHidden` |  | ✅ | ✅ | `0x1c988c` |
| `RBNavigationController` | `-` | `shouldAutorotate` |  | ✅ | ❌ | `0x1c9894` |
| `RBNavigationController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ❌ | `0x1c98f4` |
| `(RB)` | `+` | `isFileExist:` |  | ✅ | ❌ | `0x1c9954` |
| `(RB)` | `+` | `isDirectoryExist:` |  | ✅ | ❌ | `0x1c9a0c` |
| `(RB)` | `+` | `createDirectory:` |  | ✅ | ❌ | `0x1c9ac0` |
| `(RB)` | `+` | `isFreeSystemSize` |  | ✅ | ❌ | `0x1c9b70` |
| `(RB)` | `+` | `freeFileSystemSize` |  | ✅ | ❌ | `0x1c9ba0` |
| `(RB)` | `+` | `createDirectorysAtPath:` |  | ✅ | ❌ | `0x1c9cec` |
| `(RB)` | `+` | `paddingDirName` |  | ✅ | ❌ | `0x1ca0c8` |
| `(RB)` | `+` | `documentDirectoryPath` |  | ✅ | ❌ | `0x1ca130` |
| `(RB)` | `+` | `applicationSupportDirectoryPath` |  | ✅ | ❌ | `0x1ca248` |
| `(RB)` | `+` | `cachesDirectoryPath` |  | ✅ | ❌ | `0x1ca360` |
| `(RB)` | `+` | `temporaryDirectoryPath` |  | ✅ | ❌ | `0x1ca478` |
| `(RB)` | `+` | `resourcePath` |  | ✅ | ❌ | `0x1ca560` |
| `RBStoreGenreViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x1ca638` |
| `RBStoreGenreViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x1cab0c` |
| `RBStoreGenreViewController` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ❌ | `0x1cabe8` |
| `RBStoreGenreViewController` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ✅ | `0x1caf08` |
| `RBStoreGenreViewController` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ❌ | `0x1caf10` |
| `RBStoreGenreViewController` | `-` | `tableView:willDisplayCell:forRowAtIndexPath:` |  | ✅ | ✅ | `0x1caf78` |
| `RBStoreGenreViewController` | `-` | `tableView:heightForRowAtIndexPath:` |  | ✅ | ✅ | `0x1caf7c` |
| `RBStoreGenreViewController` | `-` | `tableView:didSelectRowAtIndexPath:` |  | ✅ | ❌ | `0x1caf88` |
| `RBStoreGenreViewController` | `-` | `packListCtrl` | prop | ✅ | ✅ | `0x1cb198` |
| `RBStoreGenreViewController` | `-` | `setPackListCtrl:` | prop | ✅ | ✅ | `0x1cb1a8` |
| `RBStoreGenreViewController` | `-` | `storeViewCtrl` | prop | ✅ | ✅ | `0x1cb1b8` |
| `RBStoreGenreViewController` | `-` | `setStoreViewCtrl:` | prop | ✅ | ✅ | `0x1cb1c8` |
| `RBStoreGenreViewController` | `-` | `tableView` | prop | ✅ | ✅ | `0x1cb1d8` |
| `RBStoreGenreViewController` | `-` | `setTableView:` | prop | ✅ | ✅ | `0x1cb1e8` |
| `RBCoreDataManager` | `+` | `sharedInstance` |  | ✅ | ❌ | `0x1cb234` |
| `RBCoreDataManager` | `+` | `scoreDataFileName` |  | ❌ | ❌ | `0x1cb2e8` |
| `RBCoreDataManager` | `-` | `managedObjectContext` | prop | ✅ | ❌ | `0x1cb314` |
| `RBCoreDataManager` | `-` | `managedObjectModel` | prop | ✅ | ❌ | `0x1cb3c8` |
| `RBCoreDataManager` | `-` | `persistentStoreCoordinator` | prop | ✅ | ❌ | `0x1cb4e8` |
| `RBCoreDataManager` | `-` | `historyContext` | prop | ✅ | ❌ | `0x1cb7b8` |
| `RBCoreDataManager` | `-` | `historyModel` | prop | ✅ | ❌ | `0x1cb86c` |
| `RBCoreDataManager` | `-` | `historyCoordinator` | prop | ✅ | ❌ | `0x1cb98c` |
| `RBCoreDataManager` | `-` | `setManagedObjectContext:` | prop | ✅ | ✅ | `0x1cbc24` |
| `RBCoreDataManager` | `-` | `setManagedObjectModel:` | prop | ✅ | ✅ | `0x1cbc5c` |
| `RBCoreDataManager` | `-` | `setPersistentStoreCoordinator:` | prop | ✅ | ✅ | `0x1cbc94` |
| `RBCoreDataManager` | `-` | `setHistoryContext:` | prop | ✅ | ✅ | `0x1cbccc` |
| `RBCoreDataManager` | `-` | `setHistoryModel:` | prop | ✅ | ✅ | `0x1cbd04` |
| `RBCoreDataManager` | `-` | `setHistoryCoordinator:` | prop | ✅ | ✅ | `0x1cbd3c` |
| `RBManageSortData` | `-` | `a_yomi` | prop | ✅ | ✅ | `0x1cd5c4` |
| `RBManageSortData` | `-` | `setA_yomi:` | prop | ✅ | ✅ | `0x1cd5d4` |
| `RBManageSortData` | `-` | `m_yomi` | prop | ✅ | ✅ | `0x1cd60c` |
| `RBManageSortData` | `-` | `setM_yomi:` | prop | ✅ | ✅ | `0x1cd61c` |
| `RBManageSortData` | `-` | `pack_name` | prop | ✅ | ✅ | `0x1cd654` |
| `RBManageSortData` | `-` | `setPack_name:` | prop | ✅ | ✅ | `0x1cd664` |
| `RBManageSortData` | `-` | `musicId` | prop | ✅ | ✅ | `0x1cd69c` |
| `RBManageSortData` | `-` | `setMusicId:` | prop | ✅ | ✅ | `0x1cd6ac` |
| `RBManageSortData` | `-` | `dict` | prop | ✅ | ✅ | `0x1cd6bc` |
| `RBManageSortData` | `-` | `setDict:` | prop | ✅ | ✅ | `0x1cd6cc` |
| `RBStoreManageCell` | `-` | `button` | prop | ✅ | ✅ | `0x1cd76c` |
| `RBStoreManageCell` | `-` | `setButton:` | prop | ✅ | ✅ | `0x1cd77c` |
| `RBStoreManageHeaderCell` | `-` | `initWithReuseIdentifier:frame:section:withTarget:` |  | ✅ | ❌ | `0x1cd7c8` |
| `RBStoreManageHeaderCell` | `-` | `section` | prop | ✅ | ✅ | `0x1cdd40` |
| `RBStoreManageHeaderCell` | `-` | `setSection:` | prop | ✅ | ✅ | `0x1cdd50` |
| `RBStoreManageHeaderCell` | `-` | `tapDelegate` | prop | ✅ | ✅ | `0x1cdd60` |
| `RBStoreManageHeaderCell` | `-` | `setTapDelegate:` | prop | ✅ | ✅ | `0x1cdd70` |
| `RBStoreManageHeaderCell` | `-` | `openedLabel` | prop | ✅ | ✅ | `0x1cdd80` |
| `RBStoreManageHeaderCell` | `-` | `setOpenedLabel:` | prop | ✅ | ✅ | `0x1cdd90` |
| `RBStoreManageHeaderCell` | `-` | `titleLabel` | prop | ✅ | ✅ | `0x1cdda0` |
| `RBStoreManageHeaderCell` | `-` | `setTitleLabel:` | prop | ✅ | ✅ | `0x1cddb0` |
| `RBStoreManageViewController` | `-` | `initWithParent:` |  | ✅ | ❌ | `0x1cddc0` |
| `RBStoreManageViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x1ce97c` |
| `RBStoreManageViewController` | `-` | `presentSortSelect:` |  | ✅ | ❌ | `0x1cf0ec` |
| `RBStoreManageViewController` | `-` | `hideSortSelect:` |  | ✅ | ❌ | `0x1cf2cc` |
| `RBStoreManageViewController` | `-` | `switchToSort:title:` |  | ✅ | ❌ | `0x1cf3f4` |
| `RBStoreManageViewController` | `-` | `SelectSort` |  | ✅ | ❌ | `0x1cf77c` |
| `RBStoreManageViewController` | `-` | `getSortedDictionary:row:` |  | ✅ | ❌ | `0x1cf9ec` |
| `RBStoreManageViewController` | `-` | `sortList:` |  | ✅ | ❌ | `0x1cfb48` |
| `RBStoreManageViewController` | `-` | `goToTop:` |  | ✅ | ❌ | `0x1d1080` |
| `RBStoreManageViewController` | `-` | `toggleOpen:` |  | ✅ | ❌ | `0x1d1130` |
| `RBStoreManageViewController` | `-` | `tableView:heightForHeaderInSection:` |  | ✅ | ❌ | `0x1d1280` |
| `RBStoreManageViewController` | `-` | `tableView:viewForHeaderInSection:` |  | ✅ | ❌ | `0x1d1364` |
| `RBStoreManageViewController` | `-` | `tableView:titleForHeaderInSection:` |  | ✅ | ❌ | `0x1d15b4` |
| `RBStoreManageViewController` | `-` | `sectionIndexTitlesForTableView:` |  | ✅ | ❌ | `0x1d16dc` |
| `RBStoreManageViewController` | `-` | `tableView:sectionForSectionIndexTitle:atIndex:` |  | ✅ | ❌ | `0x1d172c` |
| `RBStoreManageViewController` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ❌ | `0x1d175c` |
| `RBStoreManageViewController` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ❌ | `0x1d2220` |
| `RBStoreManageViewController` | `-` | `tableView:willDisplayCell:forRowAtIndexPath:` |  | ✅ | ❌ | `0x1d22e8` |
| `RBStoreManageViewController` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ❌ | `0x1d2434` |
| `RBStoreManageViewController` | `-` | `pushCellButton:` |  | ✅ | ❌ | `0x1d24bc` |
| `RBStoreManageViewController` | `-` | `startDownloadMusic` |  | ✅ | ❌ | `0x1d2ab8` |
| `RBStoreManageViewController` | `-` | `popoverControllerDidDismissPopover:` |  | ✅ | ❌ | `0x1d2fc4` |
| `RBStoreManageViewController` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x1d3058` |
| `RBStoreManageViewController` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x1d39e0` |
| `RBStoreManageViewController` | `-` | `storeDialogCancel:` |  | ✅ | ❌ | `0x1d3b10` |
| `RBStoreManageViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ❌ | `0x1d3c5c` |
| `RBStoreManageViewController` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ❌ | `0x1d414c` |
| `RBStoreManageViewController` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ❌ | `0x1d416c` |
| `RBStoreManageViewController` | `-` | `alertViewCancel:` |  | ✅ | ❌ | `0x1d418c` |
| `RBStoreManageViewController` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0x1d41ac` |
| `RBStoreManageViewController` | `-` | `downloadManagerCompleted:` |  | ✅ | ❌ | `0x1d42ec` |
| `RBStoreManageViewController` | `-` | `downloadManagerFailed:` |  | ✅ | ❌ | `0x1d4494` |
| `RBStoreManageViewController` | `-` | `downloadManagerProceed:` |  | ✅ | ❌ | `0x1d454c` |
| `RBStoreManageViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x1d465c` |
| `RBStoreManageViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x1d4664` |
| `RBStoreManageViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x1d47f8` |
| `RBStoreManageViewController` | `-` | `dealloc` |  | ✅ | ❌ | `0x1d48c0` |
| `RBStoreManageViewController` | `-` | `parent` | prop | ✅ | ✅ | `0x1d4ab4` |
| `RBStoreManageViewController` | `-` | `setParent:` | prop | ✅ | ✅ | `0x1d4ad4` |
| `RBStoreManageViewController` | `-` | `tableView` | prop | ✅ | ✅ | `0x1d4ae8` |
| `RBStoreManageViewController` | `-` | `setTableView:` | prop | ✅ | ✅ | `0x1d4af8` |
| `RBStoreManageViewController` | `-` | `infoDownloader` | prop | ✅ | ✅ | `0x1d4b30` |
| `RBStoreManageViewController` | `-` | `setInfoDownloader:` | prop | ✅ | ✅ | `0x1d4b40` |
| `RBStoreManageViewController` | `-` | `dlManager` | prop | ✅ | ✅ | `0x1d4b78` |
| `RBStoreManageViewController` | `-` | `setDlManager:` | prop | ✅ | ✅ | `0x1d4b88` |
| `RBStoreManageViewController` | `-` | `deleteAlertView` | prop | ✅ | ✅ | `0x1d4bc0` |
| `RBStoreManageViewController` | `-` | `setDeleteAlertView:` | prop | ✅ | ✅ | `0x1d4bd0` |
| `RBStoreManageViewController` | `-` | `downloadAlertView` | prop | ✅ | ✅ | `0x1d4c08` |
| `RBStoreManageViewController` | `-` | `setDownloadAlertView:` | prop | ✅ | ✅ | `0x1d4c18` |
| `RBStoreManageViewController` | `-` | `imgDelete` | prop | ✅ | ✅ | `0x1d4c50` |
| `RBStoreManageViewController` | `-` | `setImgDelete:` | prop | ✅ | ✅ | `0x1d4c60` |
| `RBStoreManageViewController` | `-` | `imgDownload` | prop | ✅ | ✅ | `0x1d4c98` |
| `RBStoreManageViewController` | `-` | `setImgDownload:` | prop | ✅ | ✅ | `0x1d4ca8` |
| `RBStoreManageViewController` | `-` | `labelName` | prop | ✅ | ✅ | `0x1d4ce0` |
| `RBStoreManageViewController` | `-` | `setLabelName:` | prop | ✅ | ✅ | `0x1d4cf0` |
| `RBStoreManageViewController` | `-` | `labelArtist` | prop | ✅ | ✅ | `0x1d4d28` |
| `RBStoreManageViewController` | `-` | `setLabelArtist:` | prop | ✅ | ✅ | `0x1d4d38` |
| `RBStoreManageViewController` | `-` | `sortButton` | prop | ✅ | ✅ | `0x1d4d70` |
| `RBStoreManageViewController` | `-` | `setSortButton:` | prop | ✅ | ✅ | `0x1d4d80` |
| `RBStoreManageViewController` | `-` | `topButton` | prop | ✅ | ✅ | `0x1d4db8` |
| `RBStoreManageViewController` | `-` | `setTopButton:` | prop | ✅ | ✅ | `0x1d4dc8` |
| `RBStoreManageViewController` | `-` | `sortDataDownloader` | prop | ✅ | ✅ | `0x1d4e00` |
| `RBStoreManageViewController` | `-` | `setSortDataDownloader:` | prop | ✅ | ✅ | `0x1d4e10` |
| `RBStoreManageViewController` | `-` | `sortDict` | prop | ✅ | ✅ | `0x1d4e48` |
| `RBStoreManageViewController` | `-` | `setSortDict:` | prop | ✅ | ✅ | `0x1d4e58` |
| `RBStoreManageViewController` | `-` | `sortedList` | prop | ✅ | ✅ | `0x1d4e90` |
| `RBStoreManageViewController` | `-` | `setSortedList:` | prop | ✅ | ✅ | `0x1d4ea0` |
| `RBStoreManageViewController` | `-` | `latestArrayCount` | prop | ✅ | ✅ | `0x1d4ed8` |
| `RBStoreManageViewController` | `-` | `setLatestArrayCount:` | prop | ✅ | ✅ | `0x1d4ee8` |
| `RBStoreManageViewController` | `-` | `tmpCurrentSortIndex` | prop | ✅ | ✅ | `0x1d4ef8` |
| `RBStoreManageViewController` | `-` | `setTmpCurrentSortIndex:` | prop | ✅ | ✅ | `0x1d4f08` |
| `RBStoreManageViewController` | `-` | `tmpCurrentSortTitle` | prop | ✅ | ✅ | `0x1d4f18` |
| `RBStoreManageViewController` | `-` | `setTmpCurrentSortTitle:` | prop | ✅ | ✅ | `0x1d4f28` |
| `RBStoreManageViewController` | `-` | `currentSortIndex` | prop | ✅ | ✅ | `0x1d4f60` |
| `RBStoreManageViewController` | `-` | `setCurrentSortIndex:` | prop | ✅ | ✅ | `0x1d4f70` |
| `RBStoreManageViewController` | `-` | `sortViewCtrl` | prop | ✅ | ✅ | `0x1d4f80` |
| `RBStoreManageViewController` | `-` | `setSortViewCtrl:` | prop | ✅ | ✅ | `0x1d4f90` |
| `RBStoreManageViewController` | `-` | `sortPopoverCtrl` | prop | ✅ | ✅ | `0x1d4fc8` |
| `RBStoreManageViewController` | `-` | `setSortPopoverCtrl:` | prop | ✅ | ✅ | `0x1d4fd8` |
| `RBStoreManageViewController` | `-` | `sortNavCtrl` | prop | ✅ | ✅ | `0x1d5010` |
| `RBStoreManageViewController` | `-` | `setSortNavCtrl:` | prop | ✅ | ✅ | `0x1d5020` |
| `RBStoreManageViewController` | `-` | `sectionList` | prop | ✅ | ✅ | `0x1d5058` |
| `RBStoreManageViewController` | `-` | `setSectionList:` | prop | ✅ | ✅ | `0x1d5068` |
| `RBStoreManageViewController` | `-` | `notFoundMusicList` | prop | ✅ | ✅ | `0x1d50a0` |
| `RBStoreManageViewController` | `-` | `setNotFoundMusicList:` | prop | ✅ | ✅ | `0x1d50b0` |
| `RBStoreTabController` | `-` | `init` |  | ✅ | ❌ | `0x1d537c` |
| `RBStoreTabController` | `-` | `loadView` |  | ✅ | ❌ | `0x1d6018` |
| `RBStoreTabController` | `-` | `showModalDialog:` |  | ✅ | ❌ | `0x1d655c` |
| `RBStoreTabController` | `-` | `openDialogAnimStop:finished:context:` |  | ✅ | ❌ | `0x1d6824` |
| `RBStoreTabController` | `-` | `hideModalDialog` |  | ✅ | ❌ | `0x1d68c4` |
| `RBStoreTabController` | `-` | `pushBarBtnBack:` |  | ✅ | ❌ | `0x1d6c20` |
| `RBStoreTabController` | `-` | `forceOpen` |  | ✅ | ❌ | `0x1d6f6c` |
| `RBStoreTabController` | `-` | `selectTab:` |  | ✅ | ❌ | `0x1d754c` |
| `RBStoreTabController` | `-` | `modalDialog` | prop | ✅ | ✅ | `0x1d7570` |
| `RBStoreTabController` | `-` | `setModalDialog:` | prop | ✅ | ✅ | `0x1d7580` |
| `RBStoreTabController` | `-` | `musicMenuView` | prop | ✅ | ✅ | `0x1d75b8` |
| `RBStoreTabController` | `-` | `setMusicMenuView:` | prop | ✅ | ✅ | `0x1d75d8` |
| `RBStoreTabController` | `-` | `mainNavCtrl` | prop | ✅ | ✅ | `0x1d75ec` |
| `RBStoreTabController` | `-` | `setMainNavCtrl:` | prop | ✅ | ✅ | `0x1d75fc` |
| `RBStoreTabController` | `-` | `extendNoteNavCtrl` | prop | ✅ | ✅ | `0x1d7634` |
| `RBStoreTabController` | `-` | `setExtendNoteNavCtrl:` | prop | ✅ | ✅ | `0x1d7644` |
| `RBStoreTabController` | `-` | `extendNotePageViewCtrl` | prop | ✅ | ✅ | `0x1d767c` |
| `RBStoreTabController` | `-` | `setExtendNotePageViewCtrl:` | prop | ✅ | ✅ | `0x1d768c` |
| `RBStoreTabController` | `-` | `manageNavCtrl` | prop | ✅ | ✅ | `0x1d76c4` |
| `RBStoreTabController` | `-` | `setManageNavCtrl:` | prop | ✅ | ✅ | `0x1d76d4` |
| `RBStoreTabController` | `-` | `privilegesNavCtrl` | prop | ✅ | ✅ | `0x1d770c` |
| `RBStoreTabController` | `-` | `setPrivilegesNavCtrl:` | prop | ✅ | ✅ | `0x1d771c` |
| `RBStoreTabController` | `-` | `campaignNavCtrl` | prop | ✅ | ✅ | `0x1d7754` |
| `RBStoreTabController` | `-` | `setCampaignNavCtrl:` | prop | ✅ | ✅ | `0x1d7764` |
| `RBStoreTabController` | `-` | `privilegesViewCtrl` | prop | ✅ | ✅ | `0x1d779c` |
| `RBStoreTabController` | `-` | `setPrivilegesViewCtrl:` | prop | ✅ | ✅ | `0x1d77ac` |
| `RBStoreTabController` | `-` | `campaignViewCtrl` | prop | ✅ | ✅ | `0x1d77e4` |
| `RBStoreTabController` | `-` | `setCampaignViewCtrl:` | prop | ✅ | ✅ | `0x1d77f4` |
| `RBStoreTabController` | `-` | `coverView` | prop | ✅ | ✅ | `0x1d782c` |
| `RBStoreTabController` | `-` | `setCoverView:` | prop | ✅ | ✅ | `0x1d783c` |
| `RBStoreDetailViewController` | `-` | `init` |  | ✅ | ✅ | `0x1d7964` |
| `RBStoreDetailViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x1d7a1c` |
| `RBStoreDetailViewController` | `-` | `showPackInfo` |  | ✅ | ❌ | `0x1d8510` |
| `RBStoreDetailViewController` | `-` | `loadInfo` |  | ✅ | ❌ | `0x1d88a4` |
| `RBStoreDetailViewController` | `-` | `stopSample` |  | ✅ | ❌ | `0x1d8aa0` |
| `RBStoreDetailViewController` | `-` | `finishBgm:` |  | ✅ | ❌ | `0x1d8c18` |
| `RBStoreDetailViewController` | `-` | `doPurchase:` |  | ✅ | ❌ | `0x1d8d84` |
| `RBStoreDetailViewController` | `-` | `setPurchaseState:` |  | ✅ | ✅ | `0x1d9028` |
| `RBStoreDetailViewController` | `-` | `allDownloaded` |  | ✅ | ❌ | `0x1d90f4` |
| `RBStoreDetailViewController` | `-` | `selfCheckButtonText` |  | ✅ | ❌ | `0x1d9290` |
| `RBStoreDetailViewController` | `-` | `setButtonTextBuy` |  | ✅ | ✅ | `0x1d9408` |
| `RBStoreDetailViewController` | `-` | `setButtonTextInstall` |  | ✅ | ✅ | `0x1d95d8` |
| `RBStoreDetailViewController` | `-` | `setButtonTextInstalling` |  | ✅ | ❌ | `0x1d96e8` |
| `RBStoreDetailViewController` | `-` | `setButtonTextInstalled` |  | ✅ | ❌ | `0x1d97f8` |
| `RBStoreDetailViewController` | `-` | `storePackInfoDownloaderFinished:` |  | ✅ | ❌ | `0x1d9908` |
| `RBStoreDetailViewController` | `-` | `storePackInfoDownloaderError:` |  | ✅ | ❌ | `0x1d9a50` |
| `RBStoreDetailViewController` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x1d9b88` |
| `RBStoreDetailViewController` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x1d9dd4` |
| `RBStoreDetailViewController` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x1d9f4c` |
| `RBStoreDetailViewController` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ✅ | `0x1d9f50` |
| `RBStoreDetailViewController` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ✅ | `0x1d9f58` |
| `RBStoreDetailViewController` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ❌ | `0x1d9ffc` |
| `RBStoreDetailViewController` | `-` | `tableView:heightForRowAtIndexPath:` |  | ✅ | ❌ | `0x1daeec` |
| `RBStoreDetailViewController` | `-` | `tableView:willDisplayCell:forRowAtIndexPath:` |  | ✅ | ❌ | `0x1db224` |
| `RBStoreDetailViewController` | `-` | `tableView:didSelectRowAtIndexPath:` |  | ✅ | ❌ | `0x1db51c` |
| `RBStoreDetailViewController` | `-` | `imageDownloader:didLoad:` |  | ✅ | ❌ | `0x1dbca0` |
| `RBStoreDetailViewController` | `-` | `imageDownloaderDidFail:didLoad:` |  | ✅ | ✅ | `0x1dbeb0` |
| `RBStoreDetailViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ✅ | `0x1dbeb4` |
| `RBStoreDetailViewController` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ❌ | `0x1dbeb8` |
| `RBStoreDetailViewController` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x1dbfa8` |
| `RBStoreDetailViewController` | `-` | `alertViewCancel:` |  | ✅ | ❌ | `0x1dbfac` |
| `RBStoreDetailViewController` | `-` | `didPresentAlertView:` |  | ✅ | ❌ | `0x1dc0a4` |
| `RBStoreDetailViewController` | `-` | `stopDownloadArtworks` |  | ✅ | ❌ | `0x1dc1e4` |
| `RBStoreDetailViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x1dc3ec` |
| `RBStoreDetailViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ✅ | `0x1dc3fc` |
| `RBStoreDetailViewController` | `-` | `viewDidUnload` |  | ✅ | ✅ | `0x1dc430` |
| `RBStoreDetailViewController` | `-` | `dealloc` |  | ✅ | ❌ | `0x1dc480` |
| `RBStoreDetailViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x1dc5b4` |
| `RBStoreDetailViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x1dc610` |
| `RBStoreDetailViewController` | `-` | `viewWillDisappear:` |  | ✅ | ❌ | `0x1dc6b4` |
| `RBStoreDetailViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0x1dc8e0` |
| `RBStoreDetailViewController` | `-` | `storeDetailViewOpenItunesWithURL:` |  | ✅ | ❌ | `0x1dc914` |
| `RBStoreDetailViewController` | `-` | `switchToSpecialStore:` |  | ✅ | ❌ | `0x1dc9d8` |
| `RBStoreDetailViewController` | `-` | `packInfo` | prop | ✅ | ✅ | `0x1dcb18` |
| `RBStoreDetailViewController` | `-` | `setPackInfo:` | prop | ✅ | ✅ | `0x1dcb28` |
| `RBStoreDetailViewController` | `-` | `delegate` | prop | ✅ | ✅ | `0x1dcb60` |
| `RBStoreDetailViewController` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x1dcb80` |
| `RBStoreDetailViewController` | `-` | `headerView` | prop | ✅ | ✅ | `0x1dcb94` |
| `RBStoreDetailViewController` | `-` | `setHeaderView:` | prop | ✅ | ✅ | `0x1dcba4` |
| `RBStoreDetailViewController` | `-` | `packTableView` | prop | ✅ | ✅ | `0x1dcbdc` |
| `RBStoreDetailViewController` | `-` | `setPackTableView:` | prop | ✅ | ✅ | `0x1dcbec` |
| `RBStoreDetailViewController` | `-` | `accessingIndicator` | prop | ✅ | ✅ | `0x1dcc24` |
| `RBStoreDetailViewController` | `-` | `setAccessingIndicator:` | prop | ✅ | ✅ | `0x1dcc34` |
| `RBStoreDetailViewController` | `-` | `accessingLabel` | prop | ✅ | ✅ | `0x1dcc6c` |
| `RBStoreDetailViewController` | `-` | `setAccessingLabel:` | prop | ✅ | ✅ | `0x1dcc7c` |
| `RBStoreDetailViewController` | `-` | `storePackInfoDownloader` | prop | ✅ | ✅ | `0x1dccb4` |
| `RBStoreDetailViewController` | `-` | `setStorePackInfoDownloader:` | prop | ✅ | ✅ | `0x1dccc4` |
| `RBStoreDetailViewController` | `-` | `sampleDownloader` | prop | ✅ | ✅ | `0x1dccfc` |
| `RBStoreDetailViewController` | `-` | `setSampleDownloader:` | prop | ✅ | ✅ | `0x1dcd0c` |
| `RBStoreDetailViewController` | `-` | `packBGImage0` | prop | ✅ | ✅ | `0x1dcd44` |
| `RBStoreDetailViewController` | `-` | `setPackBGImage0:` | prop | ✅ | ✅ | `0x1dcd54` |
| `RBStoreDetailViewController` | `-` | `packBGImage1` | prop | ✅ | ✅ | `0x1dcd8c` |
| `RBStoreDetailViewController` | `-` | `setPackBGImage1:` | prop | ✅ | ✅ | `0x1dcd9c` |
| `RBStoreDetailViewController` | `-` | `artworkDownloaders` | prop | ✅ | ✅ | `0x1dcdd4` |
| `RBStoreDetailViewController` | `-` | `setArtworkDownloaders:` | prop | ✅ | ✅ | `0x1dcde4` |
| `RBStoreDetailViewController` | `-` | `packinfoDownloadAlertView` | prop | ✅ | ✅ | `0x1dce1c` |
| `RBStoreDetailViewController` | `-` | `setPackinfoDownloadAlertView:` | prop | ✅ | ✅ | `0x1dce2c` |
| `RBStoreDetailViewController` | `-` | `closingFlag` | prop | ✅ | ✅ | `0x1dce64` |
| `RBStoreDetailViewController` | `-` | `setClosingFlag:` | prop | ✅ | ✅ | `0x1dce74` |
| `RBStorePageViewController` | `-` | `initWithParent:` |  | ✅ | ✅ | `0x1dcf88` |
| `RBStorePageViewController` | `-` | `loadView` |  | ✅ | ✅ | `0x1dd25c` |
| `RBStorePageViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x1dd5b0` |
| `RBStorePageViewController` | `-` | `showError:` |  | ✅ | ✅ | `0x1e0a90` |
| `RBStorePageViewController` | `-` | `sendUserAge` |  | ✅ | ✅ | `0x1e0c40` |
| `RBStorePageViewController` | `-` | `pushBarBtnRestore:` |  | ✅ | ✅ | `0x1e14fc` |
| `RBStorePageViewController` | `-` | `packListDownloadSuccess:` |  | ✅ | ❌ | `0x1e156c` |
| `RBStorePageViewController` | `-` | `forceOpenPackDetailView` |  | ✅ | ✅ | `0x1e26d0` |
| `RBStorePageViewController` | `-` | `packListDownloadError:errorMessage:` |  | ✅ | ✅ | `0x1e2a6c` |
| `RBStorePageViewController` | `-` | `packListDownloadNothing:` |  | ✅ | ✅ | `0x1e2f24` |
| `RBStorePageViewController` | `-` | `packViewSelected:` |  | ✅ | ✅ | `0x1e3018` |
| `RBStorePageViewController` | `-` | `openPackDetailViewWithPackId:` |  | ✅ | ✅ | `0x1e31ac` |
| `RBStorePageViewController` | `-` | `openDetailAnimStop:finished:context:` |  | ✅ | ✅ | `0x1e3848` |
| `RBStorePageViewController` | `-` | `storePromotionViewTaped:PackID:` |  | ✅ | ✅ | `0x1e3a48` |
| `RBStorePageViewController` | `-` | `pushSampleButton:` |  | ✅ | ✅ | `0x1e3f3c` |
| `RBStorePageViewController` | `-` | `openDetailAnimStopFromPromotion:finished:context:` |  | ✅ | ✅ | `0x1e41a8` |
| `RBStorePageViewController` | `-` | `handleTapCoverView:` |  | ✅ | ✅ | `0x1e432c` |
| `RBStorePageViewController` | `-` | `startDownloadPackMusics:` |  | ✅ | ✅ | `0x1e4858` |
| `RBStorePageViewController` | `-` | `checkAttainLimitPurchase:` |  | ✅ | ✅ | `0x1e50ac` |
| `RBStorePageViewController` | `-` | `detailViewStartPurchase:` |  | ✅ | ✅ | `0x1e52f8` |
| `RBStorePageViewController` | `-` | `detailViewClose` |  | ✅ | ✅ | `0x1e55cc` |
| `RBStorePageViewController` | `-` | `storeDialogCancel:` |  | ✅ | ✅ | `0x1e5658` |
| `RBStorePageViewController` | `-` | `connectionDidFinishLoading:` |  | ✅ | ✅ | `0x1e5888` |
| `RBStorePageViewController` | `-` | `connection:didFailWithError:` |  | ✅ | ✅ | `0x1e588c` |
| `RBStorePageViewController` | `-` | `updateMusicInfo:Save:` |  | ✅ | ✅ | `0x1e5890` |
| `RBStorePageViewController` | `-` | `updatePurchasedTableCell:` |  | ✅ | ✅ | `0x1e5ad8` |
| `RBStorePageViewController` | `-` | `reDownloadPackMusics:` |  | ✅ | ✅ | `0x1e6058` |
| `RBStorePageViewController` | `-` | `purchaseSucceeded:` |  | ✅ | ✅ | `0x1e60c4` |
| `RBStorePageViewController` | `-` | `purchaseFailed:error:` |  | ✅ | ✅ | `0x1e6564` |
| `RBStorePageViewController` | `-` | `addRestorePackInfo:` |  | ✅ | ✅ | `0x1e66f8` |
| `RBStorePageViewController` | `-` | `nextRestorePackInfo` |  | ✅ | ✅ | `0x1e6860` |
| `RBStorePageViewController` | `-` | `askDownloadAllMusics` |  | ✅ | ✅ | `0x1e6f30` |
| `RBStorePageViewController` | `-` | `restoreDownloadAllMusics` |  | ✅ | ✅ | `0x1e7788` |
| `RBStorePageViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ✅ | `0x1e8110` |
| `RBStorePageViewController` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0x1e8604` |
| `RBStorePageViewController` | `-` | `didPresentAlertView:` |  | ✅ | ✅ | `0x1e8608` |
| `RBStorePageViewController` | `-` | `restoreSucceeded` |  | ✅ | ✅ | `0x1e8748` |
| `RBStorePageViewController` | `-` | `restoreFailed:` |  | ✅ | ✅ | `0x1e8a80` |
| `RBStorePageViewController` | `-` | `restoreNothing` |  | ✅ | ✅ | `0x1e8c00` |
| `RBStorePageViewController` | `-` | `storePackInfoDownloaderFinished:` |  | ✅ | ✅ | `0x1e8c9c` |
| `RBStorePageViewController` | `-` | `storePackInfoDownloaderError:` |  | ✅ | ✅ | `0x1e8dbc` |
| `RBStorePageViewController` | `-` | `downloadManagerStartTask:` |  | ✅ | ❌ | `0x1e8e64` |
| `RBStorePageViewController` | `-` | `downloadManagerCompleted:` |  | ✅ | ✅ | `0x1e9058` |
| `RBStorePageViewController` | `-` | `downloadManagerFailed:` |  | ✅ | ✅ | `0x1e925c` |
| `RBStorePageViewController` | `-` | `downloadManagerProceed:` |  | ✅ | ✅ | `0x1e931c` |
| `RBStorePageViewController` | `-` | `restoreDownloadCancel` |  | ✅ | ✅ | `0x1e942c` |
| `RBStorePageViewController` | `-` | `numPackRows` |  | ✅ | ✅ | `0x1e9628` |
| `RBStorePageViewController` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ✅ | `0x1e96b4` |
| `RBStorePageViewController` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ✅ | `0x1eb708` |
| `RBStorePageViewController` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ✅ | `0x1eb728` |
| `RBStorePageViewController` | `-` | `tableView:heightForRowAtIndexPath:` |  | ✅ | ✅ | `0x1eb838` |
| `RBStorePageViewController` | `-` | `tableView:willDisplayCell:forRowAtIndexPath:` |  | ✅ | ✅ | `0x1eb954` |
| `RBStorePageViewController` | `-` | `tableView:willSelectRowAtIndexPath:` |  | ✅ | ✅ | `0x1ebc90` |
| `RBStorePageViewController` | `-` | `tableView:didSelectRowAtIndexPath:` |  | ✅ | ✅ | `0x1ebcfc` |
| `RBStorePageViewController` | `-` | `showDetailViewForPhone:` |  | ✅ | ✅ | `0x1ebe6c` |
| `RBStorePageViewController` | `-` | `selectShowMore` |  | ✅ | ✅ | `0x1ec078` |
| `RBStorePageViewController` | `-` | `imageDownloader:didLoad:` |  | ✅ | ✅ | `0x1ec2e8` |
| `RBStorePageViewController` | `-` | `imageDownloaderDidFail:didLoad:` |  | ✅ | ✅ | `0x1ec5ec` |
| `RBStorePageViewController` | `-` | `scrollViewDidScroll:` |  | ✅ | ❌ | `0x1ec5f0` |
| `RBStorePageViewController` | `-` | `stopDownloadArtworks` |  | ✅ | ✅ | `0x1ecb34` |
| `RBStorePageViewController` | `-` | `viewWillAppear:` |  | ✅ | ✅ | `0x1ecd54` |
| `RBStorePageViewController` | `-` | `viewDidAppear:` |  | ✅ | ✅ | `0x1ed380` |
| `RBStorePageViewController` | `-` | `viewWillDisappear:` |  | ✅ | ✅ | `0x1ed6e4` |
| `RBStorePageViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x1ed9f0` |
| `RBStorePageViewController` | `-` | `willAnimateRotationToInterfaceOrientation:duration:` |  | ✅ | ✅ | `0x1ed9f8` |
| `RBStorePageViewController` | `-` | `didRotateFromInterfaceOrientation:` |  | ✅ | ✅ | `0x1edae4` |
| `RBStorePageViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ✅ | `0x1edae8` |
| `RBStorePageViewController` | `-` | `dealloc` |  | ✅ | ✅ | `0x1edb6c` |
| `RBStorePageViewController` | `-` | `switchToGenre:` |  | ✅ | ✅ | `0x1ede24` |
| `RBStorePageViewController` | `-` | `presentGenreSelect:` |  | ✅ | ✅ | `0x1ee3ac` |
| `RBStorePageViewController` | `-` | `hideGenreSelect:` |  | ✅ | ✅ | `0x1ee610` |
| `RBStorePageViewController` | `-` | `showLoadingView` |  | ✅ | ✅ | `0x1ee7a4` |
| `RBStorePageViewController` | `-` | `setPlaySampleName:` |  | ✅ | ✅ | `0x1eeb58` |
| `RBStorePageViewController` | `-` | `stopPromotion` |  | ✅ | ✅ | `0x1eec14` |
| `RBStorePageViewController` | `-` | `popoverControllerDidDismissPopover:` |  | ✅ | ✅ | `0x1eeca8` |
| `RBStorePageViewController` | `-` | `storeDetailViewOpenItunesWithURL:` |  | ✅ | ✅ | `0x1eedb0` |
| `RBStorePageViewController` | `-` | `openItunesWithURL:` |  | ✅ | ✅ | `0x1eee74` |
| `RBStorePageViewController` | `-` | `closeItunesWithURL` |  | ✅ | ✅ | `0x1ef1ec` |
| `RBStorePageViewController` | `-` | `productViewControllerDidFinish:` |  | ✅ | ✅ | `0x1ef24c` |
| `RBStorePageViewController` | `-` | `goToTop:` |  | ✅ | ✅ | `0x1ef324` |
| `RBStorePageViewController` | `-` | `addRestoreExtendNoteInfo:` |  | ✅ | ✅ | `0x1ef40c` |
| `RBStorePageViewController` | `-` | `storeExtendNoteInfoDownloaderFinished:` |  | ✅ | ✅ | `0x1ef574` |
| `RBStorePageViewController` | `-` | `storeExtendNoteInfoDownloaderError:` |  | ✅ | ✅ | `0x1ef694` |
| `RBStorePageViewController` | `-` | `switchToSpecialStore` |  | ✅ | ✅ | `0x1ef76c` |
| `RBStorePageViewController` | `-` | `updateExtendNoteInfo:Save:` |  | ✅ | ✅ | `0x1ef7c0` |
| `RBStorePageViewController` | `-` | `showTerms` |  | ✅ | ✅ | `0x1ef8a0` |
| `RBStorePageViewController` | `-` | `parent` | prop | ✅ | ✅ | `0x1ef9c4` |
| `RBStorePageViewController` | `-` | `setParent:` | prop | ✅ | ✅ | `0x1ef9e4` |
| `RBStorePageViewController` | `-` | `packListCtrl` | prop | ✅ | ✅ | `0x1ef9f8` |
| `RBStorePageViewController` | `-` | `setPackListCtrl:` | prop | ✅ | ✅ | `0x1efa08` |
| `RBStorePageViewController` | `-` | `artworkDownloaders` | prop | ✅ | ✅ | `0x1efa40` |
| `RBStorePageViewController` | `-` | `setArtworkDownloaders:` | prop | ✅ | ✅ | `0x1efa50` |
| `RBStorePageViewController` | `-` | `downloadManager` | prop | ✅ | ✅ | `0x1efa88` |
| `RBStorePageViewController` | `-` | `setDownloadManager:` | prop | ✅ | ✅ | `0x1efa98` |
| `RBStorePageViewController` | `-` | `purchasingPackInfo` | prop | ✅ | ✅ | `0x1efad0` |
| `RBStorePageViewController` | `-` | `setPurchasingPackInfo:` | prop | ✅ | ✅ | `0x1efae0` |
| `RBStorePageViewController` | `-` | `promotionView` | prop | ✅ | ✅ | `0x1efb18` |
| `RBStorePageViewController` | `-` | `setPromotionView:` | prop | ✅ | ✅ | `0x1efb28` |
| `RBStorePageViewController` | `-` | `packTableLabel` | prop | ✅ | ✅ | `0x1efb60` |
| `RBStorePageViewController` | `-` | `setPackTableLabel:` | prop | ✅ | ✅ | `0x1efb70` |
| `RBStorePageViewController` | `-` | `showMoreButton` | prop | ✅ | ✅ | `0x1efba8` |
| `RBStorePageViewController` | `-` | `setShowMoreButton:` | prop | ✅ | ✅ | `0x1efbb8` |
| `RBStorePageViewController` | `-` | `showMoreIndicator` | prop | ✅ | ✅ | `0x1efbf0` |
| `RBStorePageViewController` | `-` | `setShowMoreIndicator:` | prop | ✅ | ✅ | `0x1efc00` |
| `RBStorePageViewController` | `-` | `coverViewPad` | prop | ✅ | ✅ | `0x1efc38` |
| `RBStorePageViewController` | `-` | `setCoverViewPad:` | prop | ✅ | ✅ | `0x1efc48` |
| `RBStorePageViewController` | `-` | `packDetailViewPad` | prop | ✅ | ✅ | `0x1efc80` |
| `RBStorePageViewController` | `-` | `setPackDetailViewPad:` | prop | ✅ | ✅ | `0x1efc90` |
| `RBStorePageViewController` | `-` | `restoreProductID` | prop | ✅ | ✅ | `0x1efcc8` |
| `RBStorePageViewController` | `-` | `setRestoreProductID:` | prop | ✅ | ✅ | `0x1efcd8` |
| `RBStorePageViewController` | `-` | `restorePackInfo` | prop | ✅ | ✅ | `0x1efd10` |
| `RBStorePageViewController` | `-` | `setRestorePackInfo:` | prop | ✅ | ✅ | `0x1efd20` |
| `RBStorePageViewController` | `-` | `restoreButton` | prop | ✅ | ✅ | `0x1efd58` |
| `RBStorePageViewController` | `-` | `setRestoreButton:` | prop | ✅ | ✅ | `0x1efd68` |
| `RBStorePageViewController` | `-` | `storePackInfoDownloader` | prop | ✅ | ✅ | `0x1efda0` |
| `RBStorePageViewController` | `-` | `setStorePackInfoDownloader:` | prop | ✅ | ✅ | `0x1efdb0` |
| `RBStorePageViewController` | `-` | `restoreProductExtendNoteID` | prop | ✅ | ✅ | `0x1efde8` |
| `RBStorePageViewController` | `-` | `setRestoreProductExtendNoteID:` | prop | ✅ | ✅ | `0x1efdf8` |
| `RBStorePageViewController` | `-` | `restoreExtendNoteInfo` | prop | ✅ | ✅ | `0x1efe30` |
| `RBStorePageViewController` | `-` | `setRestoreExtendNoteInfo:` | prop | ✅ | ✅ | `0x1efe40` |
| `RBStorePageViewController` | `-` | `storeExtendNoteInfoDownloader` | prop | ✅ | ✅ | `0x1efe78` |
| `RBStorePageViewController` | `-` | `setStoreExtendNoteInfoDownloader:` | prop | ✅ | ✅ | `0x1efe88` |
| `RBStorePageViewController` | `-` | `packBgImage0` | prop | ✅ | ✅ | `0x1efec0` |
| `RBStorePageViewController` | `-` | `setPackBgImage0:` | prop | ✅ | ✅ | `0x1efed0` |
| `RBStorePageViewController` | `-` | `packBgImage1` | prop | ✅ | ✅ | `0x1eff08` |
| `RBStorePageViewController` | `-` | `setPackBgImage1:` | prop | ✅ | ✅ | `0x1eff18` |
| `RBStorePageViewController` | `-` | `purchaseLimitTypeSelectView` | prop | ✅ | ✅ | `0x1eff50` |
| `RBStorePageViewController` | `-` | `setPurchaseLimitTypeSelectView:` | prop | ✅ | ✅ | `0x1eff60` |
| `RBStorePageViewController` | `-` | `genreButton` | prop | ✅ | ✅ | `0x1eff98` |
| `RBStorePageViewController` | `-` | `setGenreButton:` | prop | ✅ | ✅ | `0x1effa8` |
| `RBStorePageViewController` | `-` | `currentGenre` | prop | ✅ | ✅ | `0x1effe0` |
| `RBStorePageViewController` | `-` | `setCurrentGenre:` | prop | ✅ | ✅ | `0x1efff0` |
| `RBStorePageViewController` | `-` | `genreViewCtrl` | prop | ✅ | ✅ | `0x1f0028` |
| `RBStorePageViewController` | `-` | `setGenreViewCtrl:` | prop | ✅ | ✅ | `0x1f0038` |
| `RBStorePageViewController` | `-` | `genrePopoverCtrl` | prop | ✅ | ✅ | `0x1f0070` |
| `RBStorePageViewController` | `-` | `setGenrePopoverCtrl:` | prop | ✅ | ✅ | `0x1f0080` |
| `RBStorePageViewController` | `-` | `genreNavCtrl` | prop | ✅ | ✅ | `0x1f00b8` |
| `RBStorePageViewController` | `-` | `setGenreNavCtrl:` | prop | ✅ | ✅ | `0x1f00c8` |
| `RBStorePageViewController` | `-` | `topButton` | prop | ✅ | ✅ | `0x1f0100` |
| `RBStorePageViewController` | `-` | `setTopButton:` | prop | ✅ | ✅ | `0x1f0110` |
| `RBStorePageViewController` | `-` | `bannerBgView` | prop | ✅ | ✅ | `0x1f0148` |
| `RBStorePageViewController` | `-` | `setBannerBgView:` | prop | ✅ | ✅ | `0x1f0158` |
| `RBStorePageViewController` | `-` | `samplePlayButton` | prop | ✅ | ✅ | `0x1f0190` |
| `RBStorePageViewController` | `-` | `setSamplePlayButton:` | prop | ✅ | ✅ | `0x1f01a0` |
| `RBStorePageViewController` | `-` | `playImage` | prop | ✅ | ✅ | `0x1f01d8` |
| `RBStorePageViewController` | `-` | `setPlayImage:` | prop | ✅ | ✅ | `0x1f01e8` |
| `RBStorePageViewController` | `-` | `stopImage` | prop | ✅ | ✅ | `0x1f0220` |
| `RBStorePageViewController` | `-` | `setStopImage:` | prop | ✅ | ✅ | `0x1f0230` |
| `RBStorePageViewController` | `-` | `sampleMusicLabel` | prop | ✅ | ✅ | `0x1f0268` |
| `RBStorePageViewController` | `-` | `setSampleMusicLabel:` | prop | ✅ | ✅ | `0x1f0278` |
| `RBStorePageViewController` | `-` | `itunesViewCtrl` | prop | ✅ | ✅ | `0x1f02b0` |
| `RBStorePageViewController` | `-` | `setItunesViewCtrl:` | prop | ✅ | ✅ | `0x1f02c0` |
| `RBStorePageViewController` | `-` | `userAgeSender` | prop | ✅ | ✅ | `0x1f02f8` |
| `RBStorePageViewController` | `-` | `setUserAgeSender:` | prop | ✅ | ✅ | `0x1f0308` |
| `RBStorePackList` | `+` | `storeCountry` |  | ✅ | ❌ | `0x1f05fc` |
| `RBStorePackList` | `-` | `init` |  | ✅ | ❌ | `0x1f063c` |
| `RBStorePackList` | `-` | `cancelFetching` |  | ✅ | ❌ | `0x1f07fc` |
| `RBStorePackList` | `-` | `isFetching` |  | ✅ | ❌ | `0x1f094c` |
| `RBStorePackList` | `-` | `packInfos` |  | ✅ | ✅ | `0x1f09d0` |
| `RBStorePackList` | `-` | `numGenres` |  | ✅ | ❌ | `0x1f09dc` |
| `RBStorePackList` | `-` | `genreNames` |  | ✅ | ❌ | `0x1f0a3c` |
| `RBStorePackList` | `-` | `addGenres:` |  | ✅ | ❌ | `0x1f0c04` |
| `RBStorePackList` | `-` | `packListForGenreIndex:` |  | ✅ | ❌ | `0x1f0fe8` |
| `RBStorePackList` | `-` | `startFetchForGenreIndex:` |  | ✅ | ❌ | `0x1f10bc` |
| `RBStorePackList` | `-` | `startFetchGenre:` |  | ✅ | ❌ | `0x1f1304` |
| `RBStorePackList` | `-` | `getPackInfo:` |  | ✅ | ❌ | `0x1f13b4` |
| `RBStorePackList` | `-` | `addPackInfoFromID:` |  | ✅ | ❌ | `0x1f1514` |
| `RBStorePackList` | `-` | `updatePackInfo:SKProductsResponse:` |  | ✅ | ❌ | `0x1f15f8` |
| `RBStorePackList` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x1f1ca0` |
| `RBStorePackList` | `-` | `downloaderError:` |  | ✅ | ❌ | `0x1f29fc` |
| `RBStorePackList` | `-` | `downloaderProceed:` |  | ✅ | ✅ | `0x1f2a84` |
| `RBStorePackList` | `-` | `optionalProductsRequest` |  | ✅ | ❌ | `0x1f2a88` |
| `RBStorePackList` | `-` | `productsRequest:didReceiveResponse:` |  | ✅ | ❌ | `0x1f2db4` |
| `RBStorePackList` | `-` | `request:didFailWithError:` |  | ✅ | ❌ | `0x1f31f8` |
| `RBStorePackList` | `-` | `dealloc` |  | ❌ | ❌ | `0x1f32a8` |
| `RBStorePackList` | `-` | `delegate` | prop | ✅ | ✅ | `0x1f33d4` |
| `RBStorePackList` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x1f33f4` |
| `RBStorePackList` | `-` | `packlistContinued` | prop | ✅ | ✅ | `0x1f3408` |
| `RBStorePackList` | `-` | `promotionList` | prop | ✅ | ✅ | `0x1f3418` |
| `RBStorePackList` | `-` | `setPromotionList:` | prop | ✅ | ✅ | `0x1f3428` |
| `RBStorePackList` | `-` | `arrayPackInfo` | prop | ✅ | ✅ | `0x1f3460` |
| `RBStorePackList` | `-` | `setArrayPackInfo:` | prop | ✅ | ✅ | `0x1f3470` |
| `RBStorePackList` | `-` | `packlistDownloader` | prop | ✅ | ✅ | `0x1f34a8` |
| `RBStorePackList` | `-` | `setPacklistDownloader:` | prop | ✅ | ✅ | `0x1f34b8` |
| `RBStorePackList` | `-` | `tempPackList` | prop | ✅ | ✅ | `0x1f34f0` |
| `RBStorePackList` | `-` | `setTempPackList:` | prop | ✅ | ✅ | `0x1f3500` |
| `RBStorePackList` | `-` | `productsRequest` | prop | ✅ | ✅ | `0x1f3538` |
| `RBStorePackList` | `-` | `setProductsRequest:` | prop | ✅ | ✅ | `0x1f3548` |
| `RBStorePackList` | `-` | `fetchedPackNum` | prop | ✅ | ✅ | `0x1f3580` |
| `RBStorePackList` | `-` | `setFetchedPackNum:` | prop | ✅ | ✅ | `0x1f3590` |
| `RBStorePackList` | `-` | `isOptionalProductRequest` | prop | ✅ | ✅ | `0x1f35a0` |
| `RBStorePackList` | `-` | `setIsOptionalProductRequest:` | prop | ✅ | ✅ | `0x1f35b0` |
| `RBStorePackList` | `-` | `arrayGenre` | prop | ✅ | ✅ | `0x1f35c0` |
| `RBStorePackList` | `-` | `setArrayGenre:` | prop | ✅ | ✅ | `0x1f35d0` |
| `RBStorePackList` | `-` | `genreFetching` | prop | ✅ | ✅ | `0x1f3608` |
| `RBStorePackList` | `-` | `setGenreFetching:` | prop | ✅ | ✅ | `0x1f3618` |
| `RBBonusData` | `-` | `init` |  | ✅ | ❌ | `0x1f3704` |
| `RBBonusData` | `-` | `initWithCoder:` |  | ✅ | ❌ | `0x1f38b4` |
| `RBBonusData` | `-` | `encodeWithCoder:` |  | ✅ | ❌ | `0x1f3bb0` |
| `RBBonusData` | `+` | `sharedInstance` |  | ✅ | ❌ | `0x1f3df8` |
| `RBBonusData` | `-` | `save` |  | ✅ | ❌ | `0x1f3f30` |
| `RBBonusData` | `-` | `clearBonus` | prop | ✅ | ✅ | `0x1f4054` |
| `RBBonusData` | `-` | `setClearBonus:` | prop | ✅ | ✅ | `0x1f4064` |
| `RBBonusData` | `-` | `fullComboBonus` | prop | ✅ | ✅ | `0x1f4074` |
| `RBBonusData` | `-` | `setFullComboBonus:` | prop | ✅ | ✅ | `0x1f4084` |
| `RBBonusData` | `-` | `miss1Bonus` | prop | ✅ | ✅ | `0x1f4094` |
| `RBBonusData` | `-` | `setMiss1Bonus:` | prop | ✅ | ✅ | `0x1f40a4` |
| `RBBonusData` | `-` | `miss2Bonus` | prop | ✅ | ✅ | `0x1f40b4` |
| `RBBonusData` | `-` | `setMiss2Bonus:` | prop | ✅ | ✅ | `0x1f40c4` |
| `RBBonusData` | `-` | `rankAAAPBonus` | prop | ✅ | ✅ | `0x1f40d4` |
| `RBBonusData` | `-` | `setRankAAAPBonus:` | prop | ✅ | ✅ | `0x1f40e4` |
| `RBBonusData` | `-` | `rankAAABonus` | prop | ✅ | ✅ | `0x1f40f4` |
| `RBBonusData` | `-` | `setRankAAABonus:` | prop | ✅ | ✅ | `0x1f4104` |
| `RBBonusData` | `-` | `rankAABonus` | prop | ✅ | ✅ | `0x1f4114` |
| `RBBonusData` | `-` | `setRankAABonus:` | prop | ✅ | ✅ | `0x1f4124` |
| `RBBonusData` | `-` | `rankABonus` | prop | ✅ | ✅ | `0x1f4134` |
| `RBBonusData` | `-` | `setRankABonus:` | prop | ✅ | ✅ | `0x1f4144` |
| `RBBonusData` | `-` | `rankBBonus` | prop | ✅ | ✅ | `0x1f4154` |
| `RBBonusData` | `-` | `setRankBBonus:` | prop | ✅ | ✅ | `0x1f4164` |
| `RBBonusData` | `-` | `firstPlayBonus` | prop | ✅ | ✅ | `0x1f4174` |
| `RBBonusData` | `-` | `setFirstPlayBonus:` | prop | ✅ | ✅ | `0x1f4184` |
| `RBBonusData` | `-` | `blackPastelBonus` | prop | ✅ | ✅ | `0x1f4194` |
| `RBBonusData` | `-` | `setBlackPastelBonus:` | prop | ✅ | ✅ | `0x1f41a4` |
| `RBBonusData` | `-` | `pastelBonus` | prop | ✅ | ✅ | `0x1f41b4` |
| `RBBonusData` | `-` | `setPastelBonus:` | prop | ✅ | ✅ | `0x1f41c4` |
| `RBBonusData` | `-` | `earlyPlayBonus` | prop | ✅ | ✅ | `0x1f41d4` |
| `RBBonusData` | `-` | `setEarlyPlayBonus:` | prop | ✅ | ✅ | `0x1f41e4` |
| `RBBonusData` | `-` | `hotMusicBonus` | prop | ✅ | ✅ | `0x1f41f4` |
| `RBBonusData` | `-` | `setHotMusicBonus:` | prop | ✅ | ✅ | `0x1f4204` |
| `RBUserSettingData` | `-` | `init` |  | ✅ | ✅ | `0x1f4214` |
| `RBUserSettingData` | `-` | `setDefault` |  | ✅ | ✅ | `0x1f4288` |
| `RBUserSettingData` | `-` | `initWithCoder:` |  | ✅ | ✅ | `0x1f5038` |
| `RBUserSettingData` | `-` | `encodeWithCoder:` |  | ✅ | ✅ | `0x1f6214` |
| `RBUserSettingData` | `-` | `resetBgmType:` |  | ✅ | ✅ | `0x1f6ba0` |
| `RBUserSettingData` | `-` | `resetShotType:` |  | ✅ | ✅ | `0x1f6cac` |
| `RBUserSettingData` | `-` | `resetExplosionType:` |  | ✅ | ✅ | `0x1f6db8` |
| `RBUserSettingData` | `-` | `resetFrameType:` |  | ✅ | ✅ | `0x1f6ec4` |
| `RBUserSettingData` | `-` | `resetBackgroundType:` |  | ✅ | ✅ | `0x1f6fd0` |
| `RBUserSettingData` | `-` | `resetNoteType:` |  | ✅ | ✅ | `0x1f70dc` |
| `RBUserSettingData` | `-` | `resetGaugeStyle:` |  | ✅ | ✅ | `0x1f71e8` |
| `RBUserSettingData` | `-` | `resetGhostStyle:` |  | ✅ | ✅ | `0x1f72f4` |
| `RBUserSettingData` | `-` | `resetShotVolume:` |  | ✅ | ✅ | `0x1f736c` |
| `RBUserSettingData` | `-` | `resetBackgroundBrightness:` |  | ✅ | ✅ | `0x1f7480` |
| `RBUserSettingData` | `-` | `setThema:` | prop | ✅ | ✅ | `0x1f7594` |
| `RBUserSettingData` | `+` | `sharedInstance` |  | ✅ | ✅ | `0x1f7cb4` |
| `RBUserSettingData` | `-` | `save` |  | ✅ | ✅ | `0x1f7ee8` |
| `RBUserSettingData` | `-` | `themaName` |  | ✅ | ✅ | `0x1f800c` |
| `RBUserSettingData` | `-` | `themaPath` |  | ✅ | ✅ | `0x1f8048` |
| `RBUserSettingData` | `+` | `themaNameWithID:` |  | ✅ | ✅ | `0x1f80fc` |
| `RBUserSettingData` | `-` | `needUpdateTerms:` |  | ✅ | ✅ | `0x1f8160` |
| `RBUserSettingData` | `-` | `updateTutorialStatus:value:` |  | ✅ | ✅ | `0x1f8234` |
| `RBUserSettingData` | `-` | `getTutorialStatus:` |  | ✅ | ✅ | `0x1f83a4` |
| `RBUserSettingData` | `-` | `getTutorialStatusList` |  | ✅ | ✅ | `0x1f8494` |
| `RBUserSettingData` | `-` | `version` | prop | ✅ | ✅ | `0x1f8610` |
| `RBUserSettingData` | `-` | `setVersion:` | prop | ✅ | ✅ | `0x1f8620` |
| `RBUserSettingData` | `-` | `thema` | prop | ✅ | ✅ | `0x1f8658` |
| `RBUserSettingData` | `-` | `bgmType` | prop | ✅ | ✅ | `0x1f8668` |
| `RBUserSettingData` | `-` | `setBgmType:` | prop | ✅ | ✅ | `0x1f8678` |
| `RBUserSettingData` | `-` | `shotType` | prop | ✅ | ✅ | `0x1f8688` |
| `RBUserSettingData` | `-` | `setShotType:` | prop | ✅ | ✅ | `0x1f8698` |
| `RBUserSettingData` | `-` | `explosionType` | prop | ✅ | ✅ | `0x1f86a8` |
| `RBUserSettingData` | `-` | `setExplosionType:` | prop | ✅ | ✅ | `0x1f86b8` |
| `RBUserSettingData` | `-` | `frameType` | prop | ✅ | ✅ | `0x1f86c8` |
| `RBUserSettingData` | `-` | `setFrameType:` | prop | ✅ | ✅ | `0x1f86d8` |
| `RBUserSettingData` | `-` | `backgroundType` | prop | ✅ | ✅ | `0x1f86e8` |
| `RBUserSettingData` | `-` | `setBackgroundType:` | prop | ✅ | ✅ | `0x1f86f8` |
| `RBUserSettingData` | `-` | `noteType` | prop | ✅ | ✅ | `0x1f8708` |
| `RBUserSettingData` | `-` | `setNoteType:` | prop | ✅ | ✅ | `0x1f8718` |
| `RBUserSettingData` | `-` | `gaugeStyle` | prop | ✅ | ✅ | `0x1f8728` |
| `RBUserSettingData` | `-` | `setGaugeStyle:` | prop | ✅ | ✅ | `0x1f8738` |
| `RBUserSettingData` | `-` | `ghostStyle` | prop | ✅ | ✅ | `0x1f8748` |
| `RBUserSettingData` | `-` | `setGhostStyle:` | prop | ✅ | ✅ | `0x1f8758` |
| `RBUserSettingData` | `-` | `delayFrame` | prop | ✅ | ✅ | `0x1f8768` |
| `RBUserSettingData` | `-` | `setDelayFrame:` | prop | ✅ | ✅ | `0x1f8778` |
| `RBUserSettingData` | `-` | `shotVolume` | prop | ✅ | ✅ | `0x1f8788` |
| `RBUserSettingData` | `-` | `setShotVolume:` | prop | ✅ | ✅ | `0x1f8798` |
| `RBUserSettingData` | `-` | `rivalAlpha` | prop | ✅ | ✅ | `0x1f87a8` |
| `RBUserSettingData` | `-` | `setRivalAlpha:` | prop | ✅ | ✅ | `0x1f87b8` |
| `RBUserSettingData` | `-` | `backgroundBrighness` | prop | ✅ | ✅ | `0x1f87c8` |
| `RBUserSettingData` | `-` | `setBackgroundBrighness:` | prop | ✅ | ✅ | `0x1f87d8` |
| `RBUserSettingData` | `-` | `customizeItems` | prop | ✅ | ✅ | `0x1f87e8` |
| `RBUserSettingData` | `-` | `setCustomizeItems:` | prop | ✅ | ✅ | `0x1f87f8` |
| `RBUserSettingData` | `-` | `cpuLevel` | prop | ✅ | ✅ | `0x1f8830` |
| `RBUserSettingData` | `-` | `setCpuLevel:` | prop | ✅ | ✅ | `0x1f8840` |
| `RBUserSettingData` | `-` | `playColor` | prop | ✅ | ✅ | `0x1f8850` |
| `RBUserSettingData` | `-` | `setPlayColor:` | prop | ✅ | ✅ | `0x1f8860` |
| `RBUserSettingData` | `-` | `playerColor` | prop | ✅ | ✅ | `0x1f8870` |
| `RBUserSettingData` | `-` | `setPlayerColor:` | prop | ✅ | ✅ | `0x1f8880` |
| `RBUserSettingData` | `-` | `difficulty` | prop | ✅ | ✅ | `0x1f8890` |
| `RBUserSettingData` | `-` | `setDifficulty:` | prop | ✅ | ✅ | `0x1f88a0` |
| `RBUserSettingData` | `-` | `difficultyLevel` | prop | ✅ | ✅ | `0x1f88b0` |
| `RBUserSettingData` | `-` | `setDifficultyLevel:` | prop | ✅ | ✅ | `0x1f88c0` |
| `RBUserSettingData` | `-` | `gameType` | prop | ✅ | ✅ | `0x1f88d0` |
| `RBUserSettingData` | `-` | `setGameType:` | prop | ✅ | ✅ | `0x1f88e0` |
| `RBUserSettingData` | `-` | `speedType` | prop | ✅ | ✅ | `0x1f88f0` |
| `RBUserSettingData` | `-` | `setSpeedType:` | prop | ✅ | ✅ | `0x1f8900` |
| `RBUserSettingData` | `-` | `boundsEffectStyle` | prop | ✅ | ✅ | `0x1f8910` |
| `RBUserSettingData` | `-` | `setBoundsEffectStyle:` | prop | ✅ | ✅ | `0x1f8920` |
| `RBUserSettingData` | `-` | `explosionEffectSize` | prop | ✅ | ✅ | `0x1f8930` |
| `RBUserSettingData` | `-` | `setExplosionEffectSize:` | prop | ✅ | ✅ | `0x1f8940` |
| `RBUserSettingData` | `-` | `boundsEffectSize` | prop | ✅ | ✅ | `0x1f8950` |
| `RBUserSettingData` | `-` | `setBoundsEffectSize:` | prop | ✅ | ✅ | `0x1f8960` |
| `RBUserSettingData` | `-` | `damageEffectSize` | prop | ✅ | ✅ | `0x1f8970` |
| `RBUserSettingData` | `-` | `setDamageEffectSize:` | prop | ✅ | ✅ | `0x1f8980` |
| `RBUserSettingData` | `-` | `infoPlaylist` | prop | ✅ | ✅ | `0x1f8990` |
| `RBUserSettingData` | `-` | `setInfoPlaylist:` | prop | ✅ | ✅ | `0x1f89a0` |
| `RBUserSettingData` | `-` | `infoRandom` | prop | ✅ | ✅ | `0x1f89b0` |
| `RBUserSettingData` | `-` | `setInfoRandom:` | prop | ✅ | ✅ | `0x1f89c0` |
| `RBUserSettingData` | `-` | `howtoFirstInfo` | prop | ✅ | ✅ | `0x1f89d0` |
| `RBUserSettingData` | `-` | `setHowtoFirstInfo:` | prop | ✅ | ✅ | `0x1f89e0` |
| `RBUserSettingData` | `-` | `musicSelectedFirstInfo` | prop | ✅ | ✅ | `0x1f89f0` |
| `RBUserSettingData` | `-` | `setMusicSelectedFirstInfo:` | prop | ✅ | ✅ | `0x1f8a00` |
| `RBUserSettingData` | `-` | `newCustomItem` | prop | ✅ | ✅ | `0x1f8a10` |
| `RBUserSettingData` | `-` | `setNewCustomItem:` | prop | ✅ | ✅ | `0x1f8a20` |
| `RBUserSettingData` | `-` | `newThema` | prop | ✅ | ✅ | `0x1f8a30` |
| `RBUserSettingData` | `-` | `setNewThema:` | prop | ✅ | ✅ | `0x1f8a40` |
| `RBUserSettingData` | `-` | `brightnessFirstInfo` | prop | ✅ | ✅ | `0x1f8a50` |
| `RBUserSettingData` | `-` | `setBrightnessFirstInfo:` | prop | ✅ | ✅ | `0x1f8a60` |
| `RBUserSettingData` | `-` | `newsInfomationID` | prop | ✅ | ✅ | `0x1f8a70` |
| `RBUserSettingData` | `-` | `setNewsInfomationID:` | prop | ✅ | ✅ | `0x1f8a80` |
| `RBUserSettingData` | `-` | `lastUpdateTimeString` | prop | ✅ | ✅ | `0x1f8a90` |
| `RBUserSettingData` | `-` | `setLastUpdateTimeString:` | prop | ✅ | ✅ | `0x1f8aa0` |
| `RBUserSettingData` | `-` | `infoLastReadTimeString` | prop | ✅ | ✅ | `0x1f8aac` |
| `RBUserSettingData` | `-` | `setInfoLastReadTimeString:` | prop | ✅ | ✅ | `0x1f8abc` |
| `RBUserSettingData` | `-` | `termVersion` | prop | ✅ | ✅ | `0x1f8ac8` |
| `RBUserSettingData` | `-` | `setTermVersion:` | prop | ✅ | ✅ | `0x1f8ad8` |
| `RBUserSettingData` | `-` | `termLastUpdateTimeString` | prop | ✅ | ✅ | `0x1f8ae4` |
| `RBUserSettingData` | `-` | `setTermLastUpdateTimeString:` | prop | ✅ | ✅ | `0x1f8af4` |
| `RBUserSettingData` | `-` | `termLastReadTimeString` | prop | ✅ | ✅ | `0x1f8b00` |
| `RBUserSettingData` | `-` | `setTermLastReadTimeString:` | prop | ✅ | ✅ | `0x1f8b10` |
| `RBUserSettingData` | `-` | `takeoverPoint` | prop | ✅ | ✅ | `0x1f8b1c` |
| `RBUserSettingData` | `-` | `setTakeoverPoint:` | prop | ✅ | ✅ | `0x1f8b2c` |
| `RBUserSettingData` | `-` | `resourceDownloadVersion` | prop | ✅ | ✅ | `0x1f8b3c` |
| `RBUserSettingData` | `-` | `setResourceDownloadVersion:` | prop | ✅ | ✅ | `0x1f8b4c` |
| `RBUserSettingData` | `-` | `resourceDownloadPause` | prop | ✅ | ✅ | `0x1f8b58` |
| `RBUserSettingData` | `-` | `setResourceDownloadPause:` | prop | ✅ | ✅ | `0x1f8b68` |
| `RBUserSettingData` | `-` | `playlistID` | prop | ✅ | ✅ | `0x1f8b78` |
| `RBUserSettingData` | `-` | `setPlaylistID:` | prop | ✅ | ✅ | `0x1f8b88` |
| `RBUserSettingData` | `-` | `playlistLevel` | prop | ✅ | ✅ | `0x1f8b98` |
| `RBUserSettingData` | `-` | `setPlaylistLevel:` | prop | ✅ | ✅ | `0x1f8ba8` |
| `RBUserSettingData` | `-` | `menuItemSort` | prop | ✅ | ✅ | `0x1f8bb8` |
| `RBUserSettingData` | `-` | `setMenuItemSort:` | prop | ✅ | ✅ | `0x1f8bc8` |
| `RBUserSettingData` | `-` | `lastPurchaseMonth` | prop | ✅ | ✅ | `0x1f8bd8` |
| `RBUserSettingData` | `-` | `setLastPurchaseMonth:` | prop | ✅ | ✅ | `0x1f8be8` |
| `RBUserSettingData` | `-` | `totalPurchase` | prop | ✅ | ✅ | `0x1f8bf8` |
| `RBUserSettingData` | `-` | `setTotalPurchase:` | prop | ✅ | ✅ | `0x1f8c08` |
| `RBUserSettingData` | `-` | `purchaseLimitType` | prop | ✅ | ✅ | `0x1f8c18` |
| `RBUserSettingData` | `-` | `setPurchaseLimitType:` | prop | ✅ | ✅ | `0x1f8c28` |
| `RBUserSettingData` | `-` | `refuseStoreSampleBGM` | prop | ✅ | ✅ | `0x1f8c38` |
| `RBUserSettingData` | `-` | `setRefuseStoreSampleBGM:` | prop | ✅ | ✅ | `0x1f8c48` |
| `RBUserSettingData` | `-` | `updatedErosionMark` | prop | ✅ | ✅ | `0x1f8c58` |
| `RBUserSettingData` | `-` | `setUpdatedErosionMark:` | prop | ✅ | ✅ | `0x1f8c68` |
| `RBUserSettingData` | `-` | `userFullCombo` | prop | ✅ | ✅ | `0x1f8c78` |
| `RBUserSettingData` | `-` | `setUserFullCombo:` | prop | ✅ | ✅ | `0x1f8c88` |
| `RBUserSettingData` | `-` | `cpuFullCombo` | prop | ✅ | ✅ | `0x1f8c98` |
| `RBUserSettingData` | `-` | `setCpuFullCombo:` | prop | ✅ | ✅ | `0x1f8ca8` |
| `RBUserSettingData` | `-` | `fullJustReflec` | prop | ✅ | ✅ | `0x1f8cb8` |
| `RBUserSettingData` | `-` | `setFullJustReflec:` | prop | ✅ | ✅ | `0x1f8cc8` |
| `RBUserSettingData` | `-` | `vsPastel` | prop | ✅ | ✅ | `0x1f8cd8` |
| `RBUserSettingData` | `-` | `setVsPastel:` | prop | ✅ | ✅ | `0x1f8ce8` |
| `RBUserSettingData` | `-` | `alreadyReadTitleCaution` | prop | ✅ | ✅ | `0x1f8cf8` |
| `RBUserSettingData` | `-` | `setAlreadyReadTitleCaution:` | prop | ✅ | ✅ | `0x1f8d08` |
| `RBUserSettingData` | `-` | `tutorialStatuses` | prop | ✅ | ✅ | `0x1f8d18` |
| `RBUserSettingData` | `-` | `setTutorialStatuses:` | prop | ✅ | ✅ | `0x1f8d28` |
| `RBCampaignViewController` | `-` | `initWithParent:` |  | ✅ | ✅ | `0x1f8e2c` |
| `RBCampaignViewController` | `-` | `loadView` |  | ✅ | ✅ | `0x1f9220` |
| `RBCampaignViewController` | `-` | `downloadCampaignList` |  | ✅ | ✅ | `0x1fa700` |
| `RBCampaignViewController` | `-` | `tableView:cellForRowAtIndexPath:` |  | ✅ | ✅ | `0x1fa878` |
| `RBCampaignViewController` | `-` | `tableView:numberOfRowsInSection:` |  | ✅ | ✅ | `0x1faf5c` |
| `RBCampaignViewController` | `-` | `tableView:willDisplayCell:forRowAtIndexPath:` |  | ✅ | ✅ | `0x1faf90` |
| `RBCampaignViewController` | `-` | `numberOfSectionsInTableView:` |  | ✅ | ✅ | `0x1fb0dc` |
| `RBCampaignViewController` | `-` | `tableView:heightForRowAtIndexPath:` |  | ✅ | ✅ | `0x1fb0e4` |
| `RBCampaignViewController` | `-` | `tableView:didSelectRowAtIndexPath:` |  | ✅ | ✅ | `0x1fb118` |
| `RBCampaignViewController` | `-` | `sampleStart` |  | ✅ | ✅ | `0x1fb228` |
| `RBCampaignViewController` | `-` | `sampleStop` |  | ✅ | ✅ | `0x1fb410` |
| `RBCampaignViewController` | `-` | `pushExternalLink:` |  | ✅ | ✅ | `0x1fb5c0` |
| `RBCampaignViewController` | `-` | `pushCellButton:` |  | ✅ | ✅ | `0x1fb72c` |
| `RBCampaignViewController` | `-` | `showDetailView:` |  | ✅ | ✅ | `0x1fb934` |
| `RBCampaignViewController` | `-` | `handleTapCoverView:` |  | ✅ | ✅ | `0x1fbdac` |
| `RBCampaignViewController` | `-` | `updateExperienceData` |  | ✅ | ✅ | `0x1fc128` |
| `RBCampaignViewController` | `-` | `alertView:clickedButtonAtIndex:` |  | ✅ | ✅ | `0x1fc3fc` |
| `RBCampaignViewController` | `-` | `alertView:didDismissWithButtonIndex:` |  | ✅ | ✅ | `0x1fc74c` |
| `RBCampaignViewController` | `-` | `alertView:willDismissWithButtonIndex:` |  | ✅ | ✅ | `0x1fc750` |
| `RBCampaignViewController` | `-` | `alertViewCancel:` |  | ✅ | ✅ | `0x1fc754` |
| `RBCampaignViewController` | `-` | `didPresentAlertView:` |  | ✅ | ✅ | `0x1fc758` |
| `RBCampaignViewController` | `-` | `alertViewClose` |  | ✅ | ✅ | `0x1fc898` |
| `RBCampaignViewController` | `-` | `downloaderFinished:` |  | ✅ | ❌ | `0x1fc988` |
| `RBCampaignViewController` | `-` | `downloaderError:` |  | ✅ | ✅ | `0x1fda70` |
| `RBCampaignViewController` | `-` | `showError:` |  | ✅ | ✅ | `0x1fdcb4` |
| `RBCampaignViewController` | `-` | `storeDialogCancel:` |  | ✅ | ✅ | `0x1fddf4` |
| `RBCampaignViewController` | `-` | `downloadManagerCompleted:` |  | ✅ | ✅ | `0x1fdfb8` |
| `RBCampaignViewController` | `-` | `downloadManagerFailed:` |  | ✅ | ✅ | `0x1fe2bc` |
| `RBCampaignViewController` | `-` | `downloadManagerProceed:` |  | ✅ | ✅ | `0x1fe368` |
| `RBCampaignViewController` | `-` | `storeClose` |  | ✅ | ✅ | `0x1fe4f8` |
| `RBCampaignViewController` | `-` | `forceOpenCampaignDetailView` |  | ✅ | ✅ | `0x1fe4fc` |
| `RBCampaignViewController` | `-` | `reloadUnlockList` |  | ✅ | ✅ | `0x1fec00` |
| `RBCampaignViewController` | `-` | `refreshMusicList` |  | ✅ | ✅ | `0x1fec34` |
| `RBCampaignViewController` | `-` | `refreshUnlockTable` |  | ✅ | ✅ | `0x1ff038` |
| `RBCampaignViewController` | `-` | `refreshUnlockBadge` |  | ✅ | ✅ | `0x1ff470` |
| `RBCampaignViewController` | `-` | `setBadgeCnt:` |  | ✅ | ✅ | `0x1ff5cc` |
| `RBCampaignViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ✅ | `0x1ff6a0` |
| `RBCampaignViewController` | `-` | `viewDidUnload` |  | ✅ | ✅ | `0x1ff6d4` |
| `RBCampaignViewController` | `-` | `viewWillAppear:` |  | ✅ | ✅ | `0x1ff728` |
| `RBCampaignViewController` | `-` | `viewDidAppear:` |  | ✅ | ✅ | `0x1ff7bc` |
| `RBCampaignViewController` | `-` | `viewWillDisappear:` |  | ✅ | ✅ | `0x1ff91c` |
| `RBCampaignViewController` | `-` | `viewDidDisappear:` |  | ✅ | ✅ | `0x1ff9d4` |
| `RBCampaignViewController` | `-` | `showDetailViewForPhone:` |  | ✅ | ✅ | `0x1ffa44` |
| `RBCampaignViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x1ffc30` |
| `RBCampaignViewController` | `-` | `willAnimateRotationToInterfaceOrientation:duration:` |  | ✅ | ✅ | `0x1ffc38` |
| `RBCampaignViewController` | `-` | `imageDownloader:didLoad:` |  | ✅ | ✅ | `0x1ffc6c` |
| `RBCampaignViewController` | `-` | `imageDownloaderDidFail:didLoad:` |  | ✅ | ✅ | `0x1ffdfc` |
| `RBCampaignViewController` | `-` | `itemInfoDownload` |  | ✅ | ✅ | `0x1ffe00` |
| `RBCampaignViewController` | `-` | `dealloc` |  | ✅ | ✅ | `0x1ffff4` |
| `RBCampaignViewController` | `-` | `alertView` | prop | ✅ | ✅ | `0x200028` |
| `RBCampaignViewController` | `-` | `setAlertView:` | prop | ✅ | ✅ | `0x200038` |
| `RBCampaignViewController` | `-` | `parent` | prop | ✅ | ✅ | `0x200070` |
| `RBCampaignViewController` | `-` | `setParent:` | prop | ✅ | ✅ | `0x200090` |
| `RBCampaignViewController` | `-` | `tableView` | prop | ✅ | ✅ | `0x2000a4` |
| `RBCampaignViewController` | `-` | `setTableView:` | prop | ✅ | ✅ | `0x2000b4` |
| `RBCampaignViewController` | `-` | `loadingLabel` | prop | ✅ | ✅ | `0x2000ec` |
| `RBCampaignViewController` | `-` | `setLoadingLabel:` | prop | ✅ | ✅ | `0x2000fc` |
| `RBCampaignViewController` | `-` | `errorLabel` | prop | ✅ | ✅ | `0x200134` |
| `RBCampaignViewController` | `-` | `setErrorLabel:` | prop | ✅ | ✅ | `0x200144` |
| `RBCampaignViewController` | `-` | `infoDownloader` | prop | ✅ | ✅ | `0x20017c` |
| `RBCampaignViewController` | `-` | `setInfoDownloader:` | prop | ✅ | ✅ | `0x20018c` |
| `RBCampaignViewController` | `-` | `musicInfoDownloader` | prop | ✅ | ✅ | `0x2001c4` |
| `RBCampaignViewController` | `-` | `setMusicInfoDownloader:` | prop | ✅ | ✅ | `0x2001d4` |
| `RBCampaignViewController` | `-` | `termsChecker` | prop | ✅ | ✅ | `0x20020c` |
| `RBCampaignViewController` | `-` | `setTermsChecker:` | prop | ✅ | ✅ | `0x20021c` |
| `RBCampaignViewController` | `-` | `itemURLDownloader` | prop | ✅ | ✅ | `0x200254` |
| `RBCampaignViewController` | `-` | `setItemURLDownloader:` | prop | ✅ | ✅ | `0x200264` |
| `RBCampaignViewController` | `-` | `sampleDownloader` | prop | ✅ | ✅ | `0x20029c` |
| `RBCampaignViewController` | `-` | `setSampleDownloader:` | prop | ✅ | ✅ | `0x2002ac` |
| `RBCampaignViewController` | `-` | `dlManager` | prop | ✅ | ✅ | `0x2002e4` |
| `RBCampaignViewController` | `-` | `setDlManager:` | prop | ✅ | ✅ | `0x2002f4` |
| `RBCampaignViewController` | `-` | `downloadAlertView` | prop | ✅ | ✅ | `0x20032c` |
| `RBCampaignViewController` | `-` | `setDownloadAlertView:` | prop | ✅ | ✅ | `0x20033c` |
| `RBCampaignViewController` | `-` | `updateAlertView` | prop | ✅ | ✅ | `0x200374` |
| `RBCampaignViewController` | `-` | `setUpdateAlertView:` | prop | ✅ | ✅ | `0x200384` |
| `RBCampaignViewController` | `-` | `imgDelete` | prop | ✅ | ✅ | `0x2003bc` |
| `RBCampaignViewController` | `-` | `setImgDelete:` | prop | ✅ | ✅ | `0x2003cc` |
| `RBCampaignViewController` | `-` | `imgDownload` | prop | ✅ | ✅ | `0x200404` |
| `RBCampaignViewController` | `-` | `setImgDownload:` | prop | ✅ | ✅ | `0x200414` |
| `RBCampaignViewController` | `-` | `downloadMusicList` | prop | ✅ | ✅ | `0x20044c` |
| `RBCampaignViewController` | `-` | `setDownloadMusicList:` | prop | ✅ | ✅ | `0x20045c` |
| `RBCampaignViewController` | `-` | `imageDownloaderList` | prop | ✅ | ✅ | `0x200494` |
| `RBCampaignViewController` | `-` | `setImageDownloaderList:` | prop | ✅ | ✅ | `0x2004a4` |
| `RBCampaignViewController` | `-` | `unlockMusicCheckList` | prop | ✅ | ✅ | `0x2004dc` |
| `RBCampaignViewController` | `-` | `setUnlockMusicCheckList:` | prop | ✅ | ✅ | `0x2004ec` |
| `RBCampaignViewController` | `-` | `firstDownloadFailed` | prop | ✅ | ✅ | `0x200524` |
| `RBCampaignViewController` | `-` | `setFirstDownloadFailed:` | prop | ✅ | ✅ | `0x200534` |
| `RBCampaignViewController` | `-` | `coverViewPad` | prop | ✅ | ✅ | `0x200544` |
| `RBCampaignViewController` | `-` | `setCoverViewPad:` | prop | ✅ | ✅ | `0x200554` |
| `RBCampaignViewController` | `-` | `itemDetailViewPad` | prop | ✅ | ✅ | `0x20058c` |
| `RBCampaignViewController` | `-` | `setItemDetailViewPad:` | prop | ✅ | ✅ | `0x20059c` |
| `RBNumberLabel` | `-` | `initWithFrame:` |  | ✅ | ✅ | `0x200778` |
| `RBNumberLabel` | `-` | `setNumber:` | prop | ✅ | ✅ | `0x20084c` |
| `RBNumberLabel` | `-` | `setImageType:` | prop | ✅ | ✅ | `0x200874` |
| `RBNumberLabel` | `-` | `drawRect:` |  | ✅ | ❌ | `0x20089c` |
| `RBNumberLabel` | `-` | `number` | prop | ✅ | ✅ | `0x200f50` |
| `RBNumberLabel` | `-` | `imageType` | prop | ✅ | ✅ | `0x200f60` |
| `RBAnimationFactory` | `+` | `createAnimWithKeyPath:fromValue:toValue:delay:duration:` |  | ✅ | ❌ | `0x200f70` |
| `RBAnimationFactory` | `+` | `createFadeAnimWithFromValue:toValue:delay:duration:` |  | ✅ | ❌ | `0x2012e0` |
| `RBAnimationFactory` | `+` | `createPositionXAnimWithFromValue:toValue:delay:duration:` |  | ✅ | ❌ | `0x201628` |
| `RBAnimationFactory` | `+` | `createPositionYAnimWithFromValue:toValue:delay:duration:` |  | ✅ | ❌ | `0x201644` |
| `RBAnimationFactory` | `+` | `createPositionAnimWithFromValue:toValue:delay:duration:` |  | ✅ | ❌ | `0x201660` |
| `RBAnimationFactory` | `+` | `createScaleAnimWithFromValue:toValue:X:Y:delay:duration:` |  | ✅ | ❌ | `0x20182c` |
| `RBAnimationFactory` | `+` | `createAnimHereWithDuration:Y:repeatCount:` |  | ✅ | ❌ | `0x201be0` |
| `RBAnimationFactory` | `+` | `createBoundAnimWithX:Y:delay:duration:` |  | ✅ | ❌ | `0x201fa8` |
| `RBAnimationFactory` | `+` | `animationDelete:` |  | ✅ | ❌ | `0x202580` |
| `RBBaseViewController` | `-` | `prefersStatusBarHidden` |  | ✅ | ✅ | `0x202740` |
| `RBBaseViewController` | `-` | `shouldAutorotate` |  | ✅ | ❌ | `0x202748` |
| `RBBaseViewController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ❌ | `0x202778` |
| `RBBaseViewController` | `-` | `preferredInterfaceOrientationForPresentation` |  | ✅ | ✅ | `0x2027d4` |
| `RBBaseViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ❌ | `0x2027dc` |
| `RBBaseTableViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x20282c` |
| `RBBaseTableViewController` | `-` | `prefersStatusBarHidden` |  | ✅ | ✅ | `0x2028f8` |
| `RBBaseTableViewController` | `-` | `shouldAutorotate` |  | ✅ | ❌ | `0x202900` |
| `RBBaseTableViewController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ❌ | `0x202930` |
| `RBBaseTableViewController` | `-` | `preferredInterfaceOrientationForPresentation` |  | ✅ | ✅ | `0x20298c` |
| `RBBaseTableViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ❌ | `0x202994` |
| `RBBaseTabBarController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x2029e4` |
| `RBBaseTabBarController` | `-` | `prefersStatusBarHidden` |  | ✅ | ✅ | `0x202af8` |
| `RBBaseTabBarController` | `-` | `shouldAutorotate` |  | ✅ | ❌ | `0x202b00` |
| `RBBaseTabBarController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ❌ | `0x202b30` |
| `RBBaseTabBarController` | `-` | `preferredInterfaceOrientationForPresentation` |  | ✅ | ✅ | `0x202b8c` |
| `RBBaseTabBarController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ❌ | `0x202b94` |
| `RBGameKitManager` | `+` | `sharedInstance` |  | ✅ | ❌ | `0x202be4` |
| `RBGameKitManager` | `-` | `isGameCenterAPIAvailable` |  | ✅ | ❌ | `0x202c98` |
| `RBGameKitManager` | `-` | `loginGameCenter` |  | ✅ | ❌ | `0x202d64` |
| `RecommendWebViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x202f54` |
| `RecommendWebViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ❌ | `0x202f90` |
| `RecommendWebViewController` | `-` | `viewDidUnload` |  | ✅ | ❌ | `0x202fcc` |
| `RecommendWebViewController` | `-` | `redirectWithRequest:` |  | ✅ | ❌ | `0x203048` |
| `RecommendWebViewController` | `-` | `removeFromSuperview` |  | ✅ | ✅ | `0x20310c` |
| `RecommendWebViewController` | `-` | `dealloc` |  | ✅ | ✅ | `0x203110` |
| `RecommendAdId` | `-` | `initWithCountryCode:categoryId:` |  | ✅ | ❌ | `0x20314c` |
| `RecommendAdId` | `-` | `getWithCountryCode:categoryId:error:` |  | ✅ | ❌ | `0x203224` |
| `RecommendAdId` | `-` | `setWithAdIdFrom:countryCode:categoryId:adType:error:` |  | ✅ | ❌ | `0x2035f4` |
| `RecommendAdId` | `-` | `deleteWithCountryCode:categoryId:error:` |  | ✅ | ❌ | `0x203cfc` |
| `RecommendAdId` | `-` | `convertToData:` |  | ✅ | ❌ | `0x203f88` |
| `RecommendAdId` | `-` | `getPasteboardWithUdid:countryCode:categoryId:error:` |  | ✅ | ❌ | `0x204350` |
| `RecommendAdId` | `-` | `setPasteboardWithUdid:countryCode:categoryId:adIdFrom:adType:error:` |  | ✅ | ❌ | `0x20498c` |
| `RecommendAdId` | `-` | `deletePasteboardWithUdid:countryCode:categoryId:error:` |  | ✅ | ❌ | `0x204ed8` |
| `RecommendAdId` | `-` | `dealloc` |  | ❌ | ✅ | `0x205398` |
| `ApplilinkConsts` | `+` | `envServer` |  | ✅ | ❌ | `0x2053e8` |
| `ApplilinkConsts` | `+` | `baseUrlSsl` |  | ✅ | ❌ | `0x205454` |
| `ApplilinkConsts` | `+` | `appliId` |  | ✅ | ❌ | `0x205580` |
| `ApplilinkConsts` | `+` | `canUseApplilinkSdk` |  | ✅ | ❌ | `0x2055ec` |
| `ApplilinkConsts` | `+` | `version` |  | ✅ | ❌ | `0x205680` |
| `ApplilinkConsts` | `+` | `setUserId:` |  | ✅ | ❌ | `0x2056ac` |
| `ApplilinkConsts` | `+` | `userId` |  | ✅ | ❌ | `0x205a18` |
| `ApplilinkConsts` | `+` | `isNeedRewardLogin` |  | ✅ | ❌ | `0x205b7c` |
| `ApplilinkConsts` | `+` | `isNeedRecommendLogin` |  | ✅ | ❌ | `0x205bf0` |
| `ApplilinkConsts` | `+` | `loggedInReward` |  | ✅ | ❌ | `0x205c64` |
| `ApplilinkConsts` | `+` | `loggedInRecommend` |  | ✅ | ❌ | `0x205cf8` |
| `ApplilinkConsts` | `+` | `setAppliCountryCode:` |  | ✅ | ❌ | `0x205d8c` |
| `ApplilinkConsts` | `+` | `setCountryCode:` |  | ✅ | ❌ | `0x205de4` |
| `ApplilinkConsts` | `+` | `countryCode` |  | ✅ | ❌ | `0x205e44` |
| `ApplilinkConsts` | `+` | `setCategoryId:` |  | ✅ | ❌ | `0x205e54` |
| `ApplilinkConsts` | `+` | `categoryId` |  | ✅ | ❌ | `0x205e80` |
| `ApplilinkConsts` | `+` | `setAdId:` |  | ✅ | ❌ | `0x205e90` |
| `ApplilinkConsts` | `+` | `adId` |  | ✅ | ❌ | `0x205ed4` |
| `ApplilinkConsts` | `+` | `setAppInstallList:` |  | ✅ | ❌ | `0x205ee4` |
| `ApplilinkConsts` | `+` | `appInstallList` |  | ✅ | ❌ | `0x20649c` |
| `ApplilinkConsts` | `+` | `setTemplateList:` |  | ✅ | ❌ | `0x206b08` |
| `ApplilinkConsts` | `+` | `templateList` |  | ✅ | ❌ | `0x206d14` |
| `ApplilinkConsts` | `+` | `clearData` |  | ✅ | ❌ | `0x206e9c` |
| `ApplilinkConsts` | `+` | `checkUseSDKWithAdModel:adLocation:verticalAlign:requestCode:delegate:` |  | ✅ | ❌ | `0x206f7c` |
| `ApplilinkURLConnection` | `-` | `init` |  | ✅ | ❌ | `0x207150` |
| `ApplilinkURLConnection` | `-` | `loadRequestWithRequest:delegate:` |  | ✅ | ❌ | `0x20718c` |
| `ApplilinkURLConnection` | `-` | `connection:didReceiveResponse:` |  | ✅ | ❌ | `0x207250` |
| `ApplilinkURLConnection` | `-` | `connection:didReceiveData:` |  | ✅ | ❌ | `0x2072a8` |
| `ApplilinkURLConnection` | `-` | `connection:didFailWithError:` |  | ✅ | ❌ | `0x2072c8` |
| `ApplilinkURLConnection` | `-` | `connectionDidFinishLoading:` |  | ✅ | ❌ | `0x207394` |
| `ApplilinkURLConnection` | `-` | `connection:willSendRequest:redirectResponse:` |  | ✅ | ❌ | `0x20749c` |
| `ApplilinkURLConnection` | `-` | `connectionDelegate` | prop | ✅ | ✅ | `0x2075d0` |
| `ApplilinkURLConnection` | `-` | `setConnectionDelegate:` | prop | ✅ | ✅ | `0x2075f0` |
| `ApplilinkURLConnection` | `-` | `receivedData` | prop | ✅ | ✅ | `0x207604` |
| `ApplilinkURLConnection` | `-` | `setReceivedData:` | prop | ✅ | ✅ | `0x207614` |
| `ApplilinkURLConnection` | `-` | `responseData` | prop | ✅ | ✅ | `0x20764c` |
| `ApplilinkURLConnection` | `-` | `setResponseData:` | prop | ✅ | ✅ | `0x20765c` |
| `RewardCore` | `-` | `init` |  | ✅ | ✅ | `0x2076e4` |
| `RewardCore` | `+` | `allocWithZone:` |  | ✅ | ✅ | `0x2078b8` |
| `RewardCore` | `+` | `sharedInstance` |  | ✅ | ✅ | `0x2079d0` |
| `RewardCore` | `-` | `initializeFlg` | prop | ✅ | ✅ | `0x207a80` |
| `RewardCore` | `-` | `clearInitialize` |  | ✅ | ✅ | `0x207acc` |
| `RewardCore` | `-` | `campaignFlg` |  | ✅ | ✅ | `0x207b6c` |
| `RewardCore` | `-` | `startWithCallback:` |  | ✅ | ❌ | `0x207c70` |
| `RewardCore` | `-` | `startSessionWithBlock:` |  | ✅ | ❌ | `0x20810c` |
| `RewardCore` | `-` | `startWithBlock:` |  | ✅ | ✅ | `0x208624` |
| `RewardCore` | `-` | `createUdidWithBlock:` |  | ✅ | ✅ | `0x208738` |
| `RewardCore` | `-` | `createCFUdidWithError:` |  | ✅ | ✅ | `0x2088e0` |
| `RewardCore` | `-` | `allInstallFlgWithCallback:` |  | ✅ | ❌ | `0x208bf0` |
| `RewardCore` | `-` | `getAdDisplayStatusWithCallback:` |  | ✅ | ❌ | `0x208e48` |
| `RewardCore` | `-` | `postInstalledAppWithCallback:` |  | ✅ | ❌ | `0x209244` |
| `RewardCore` | `-` | `getInstalledAppWithCallback:` |  | ✅ | ❌ | `0x209724` |
| `RewardCore` | `-` | `getAppListStatusWithBlock:` |  | ✅ | ❌ | `0x209a90` |
| `RewardCore` | `-` | `openAdScreenWithParentView:adLocation:requestCode:delegate:` |  | ✅ | ❌ | `0x20a0dc` |
| `RewardCore` | `-` | `closeAdScreen` |  | ✅ | ❌ | `0x20ac1c` |
| `RewardCore` | `-` | `rotateAdScreenWithInterfaceOrientation:duration:` |  | ✅ | ❌ | `0x20accc` |
| `RewardCore` | `-` | `redirectWithRequest:` |  | ✅ | ❌ | `0x20acf0` |
| `RewardCore` | `-` | `setNavigationBarHidden:` |  | ✅ | ❌ | `0x20b62c` |
| `RewardCore` | `-` | `setTemporaryCacheWithKey:value:expiration:` |  | ✅ | ❌ | `0x20b63c` |
| `RewardCore` | `-` | `getTemporaryCacheWithKey:` |  | ✅ | ❌ | `0x20b7f0` |
| `RewardCore` | `-` | `appListDidStart:` |  | ✅ | ❌ | `0x20b9e4` |
| `RewardCore` | `-` | `appListDidAppear:` |  | ✅ | ❌ | `0x20ba10` |
| `RewardCore` | `-` | `appListDidDisappear:` |  | ✅ | ❌ | `0x20ba3c` |
| `RewardCore` | `-` | `appListFailLoadWithError:delegate:` |  | ✅ | ❌ | `0x20ba68` |
| `RewardCore` | `-` | `appListFailLinkWithError:delegate:` |  | ✅ | ❌ | `0x20bacc` |
| `RewardCore` | `-` | `startedNotice` |  | ✅ | ❌ | `0x20bb30` |
| `RewardCore` | `-` | `openedNotice` |  | ✅ | ❌ | `0x20bb7c` |
| `RewardCore` | `-` | `closeNotice` |  | ✅ | ❌ | `0x20bbc8` |
| `RewardCore` | `-` | `failOpenNoticeWithError:` |  | ✅ | ❌ | `0x20bc5c` |
| `RewardCore` | `-` | `failLinkNoticeWithError:` |  | ✅ | ❌ | `0x20bccc` |
| `RewardCore` | `-` | `openCancelWithError:` |  | ✅ | ✅ | `0x20bd3c` |
| `RewardCore` | `-` | `canUseBannerCache` |  | ✅ | ❌ | `0x20bd40` |
| `RewardCore` | `-` | `clearAdStatus` |  | ✅ | ❌ | `0x20be1c` |
| `RewardCore` | `-` | `clearSession` |  | ✅ | ❌ | `0x20be50` |
| `RewardCore` | `-` | `dealloc` |  | ❌ | ✅ | `0x20c090` |
| `RewardCore` | `-` | `setInitializeFlg:` | prop | ✅ | ✅ | `0x20c0cc` |
| `RewardCore` | `-` | `isNavigationBarHidden` | prop | ✅ | ✅ | `0x20c0dc` |
| `RewardCore` | `-` | `setIsNavigationBarHidden:` | prop | ✅ | ✅ | `0x20c0ec` |
| `RewardCore` | `-` | `rewardViewController` | prop | ✅ | ✅ | `0x20c0fc` |
| `RewardCore` | `-` | `setRewardViewController:` | prop | ✅ | ✅ | `0x20c10c` |
| `RewardCore` | `-` | `applilinkDelegate` | prop | ✅ | ✅ | `0x20c144` |
| `RewardCore` | `-` | `setApplilinkDelegate:` | prop | ✅ | ✅ | `0x20c164` |
| `RewardCore` | `-` | `applilinkParams` | prop | ✅ | ✅ | `0x20c178` |
| `RewardCore` | `-` | `setApplilinkParams:` | prop | ✅ | ✅ | `0x20c188` |
| `NSStringURLEncoding` | `+` | `URLEncodedString:` |  | ✅ | ❌ | `0x20c1f4` |
| `NSStringURLEncoding` | `+` | `URLDecodedString:` |  | ✅ | ❌ | `0x20c24c` |
| `ApplilinkUtilities` | `+` | `joinDictionary:withDictionary:` |  | ✅ | ❌ | `0x20c2a8` |
| `ApplilinkUtilities` | `+` | `userAgentParametersJoinDictionary:` |  | ✅ | ❌ | `0x20c37c` |
| `ApplilinkUtilities` | `+` | `userAgentParameters` |  | ✅ | ❌ | `0x20c410` |
| `ApplilinkUtilities` | `+` | `deviceName` |  | ✅ | ❌ | `0x20c86c` |
| `ApplilinkUtilities` | `+` | `appendParametersToURL:parameters:` |  | ✅ | ❌ | `0x20ca98` |
| `ApplilinkUtilities` | `+` | `localeString` |  | ✅ | ❌ | `0x20cefc` |
| `ApplilinkUtilities` | `+` | `countryCodeString` |  | ✅ | ❌ | `0x20cf90` |
| `ApplilinkUtilities` | `+` | `hasParentViewController:` |  | ✅ | ❌ | `0x20d02c` |
| `ApplilinkUtilities` | `+` | `getImpressionId` |  | ✅ | ❌ | `0x20d160` |
| `ApplilinkUtilities` | `+` | `narrowedListWithList:object:forKey:` |  | ✅ | ❌ | `0x20d240` |
| `ApplilinkUtilities` | `+` | `geFileNameFromPath:` |  | ✅ | ❌ | `0x20d38c` |
| `ApplilinkUtilities` | `+` | `debugLog` |  | ✅ | ✅ | `0x20d418` |
| `ApplilinkBundle` | `+` | `rewardBundle` |  | ✅ | ❌ | `0x20d41c` |
| `AnalysisNetworkCore` | `+` | `postInitalizeWithCallback:` |  | ✅ | ❌ | `0x20d650` |
| `AnalysisNetworkCore` | `+` | `postDAUWithCallback:` |  | ✅ | ❌ | `0x20da4c` |
| `AnalysisNetworkCore` | `+` | `postAnalysisDataWithResultId:callback:` |  | ✅ | ❌ | `0x20de74` |
| `AnalysisNetworkCore` | `+` | `postSetUserIDWithCallback:` |  | ✅ | ❌ | `0x20e1d0` |
| `AnalysisNetworkCore` | `+` | `postAnalysisDataWithActionType:resultId:uesrId:finishedBlock:failedBlock:callback:` |  | ✅ | ❌ | `0x20e510` |
| `AnalysisNetworkCore` | `+` | `postAnalysisListRegistWithAdType:adModel:adLocation:impressionId:appliIdList:creativeIdList:incentiveTypeList:installFlgList:callback:` |  | ✅ | ❌ | `0x20e8f8` |
| `AnalysisNetworkCore` | `+` | `postAnalysisClickRegistWithAdType:adModel:adLocation:impressionId:appliIdTo:creativeId:displayNumber:incentiveType:installFlg:callback:` |  | ❌ | ❌ | `0x20ef1c` |
| `AnalysisNetworkCore` | `+` | `getInitalizeFlg` |  | ✅ | ❌ | `0x20f5c4` |
| `AnalysisNetworkCore` | `+` | `getSendDauFlg` |  | ✅ | ❌ | `0x20f640` |
| `AnalysisNetworkCore` | `+` | `postAnalysisDataWithCallback:` |  | ✅ | ❌ | `0x20f7d8` |
| `AnalysisNetworkCore` | `+` | `clearInitalize` |  | ✅ | ❌ | `0x20f9f0` |
| `AnalysisNetworkCore` | `+` | `clearDAU` |  | ✅ | ❌ | `0x20fa84` |
| `ApplilinkNetworkError` | `+` | `localizedApplilinkErrorWithCode:userInfo:` |  | ✅ | ❌ | `0x20fb18` |
| `ApplilinkNetworkError` | `+` | `localizedApplilinkErrorWithCode:` |  | ✅ | ❌ | `0x211f04` |
| `RecommendNetwork` | `+` | `getAppListStatusWithCallback:` |  | ✅ | ❌ | `0x211f20` |
| `RecommendNetwork` | `+` | `getAdStatusWithAdModel:callback:` |  | ✅ | ❌ | `0x211f3c` |
| `RecommendNetwork` | `+` | `getUnreadCountWithAdModel:adLocation:callback:` |  | ✅ | ❌ | `0x2120ac` |
| `RecommendNetwork` | `+` | `getAdDisplayStatusWithAdModel:adLocation:callback:` |  | ✅ | ❌ | `0x21228c` |
| `RecommendNetwork` | `+` | `showOwnAdWithAdLocation:toAppliId:creativeId:` |  | ✅ | ❌ | `0x212540` |
| `RecommendNetwork` | `+` | `touchOwnAdWithAdLocation:toAppliId:creativeId:requestCode:delegate:` |  | ✅ | ❌ | `0x212604` |
| `RecommendNetwork` | `+` | `openAppListWithAdLocation:delegate:` |  | ✅ | ❌ | `0x21271c` |
| `RecommendNetwork` | `+` | `openAppListWithAdLocation:requestCode:delegate:` |  | ✅ | ❌ | `0x212774` |
| `RecommendNetwork` | `+` | `openAdScreenWithAdModel:adLocation:delegate:` |  | ✅ | ❌ | `0x212960` |
| `RecommendNetwork` | `+` | `openAdScreenWithAdModel:adLocation:requestCode:delegate:` |  | ✅ | ❌ | `0x2129c0` |
| `RecommendNetwork` | `+` | `openAdAreaWithParentView:rect:adModel:adLocation:verticalAlign:delegate:` |  | ✅ | ❌ | `0x212bb0` |
| `RecommendNetwork` | `+` | `openAdAreaWithParentView:rect:adModel:adLocation:verticalAlign:requestCode:delegate:` |  | ✅ | ❌ | `0x212c6c` |
| `RecommendNetwork` | `+` | `openInterstitialWithAdLocation:delegate:` |  | ✅ | ❌ | `0x212eb4` |
| `RecommendNetwork` | `+` | `openInterstitialWithAdLocation:requestCode:delegate:` |  | ✅ | ❌ | `0x212f0c` |
| `RecommendNetwork` | `+` | `closeAdScreen` |  | ✅ | ❌ | `0x2130f4` |
| `RecommendNetwork` | `+` | `closeAdAreaWithParentView:` |  | ✅ | ❌ | `0x21316c` |
| `RecommendNetwork` | `+` | `setAdAreaVisibleWithParentView:flag:` |  | ✅ | ❌ | `0x2133bc` |
| `RecommendNetwork` | `-` | `dealloc` |  | ❌ | ✅ | `0x2135dc` |
| `AnalysisNetwork` | `+` | `postAnalysisDataWithResultId:callback:` |  | ✅ | ❌ | `0x213618` |
| `ApplilinkViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x2136e0` |
| `ApplilinkViewController` | `-` | `viewWillAppear:` |  | ✅ | ❌ | `0x21371c` |
| `ApplilinkViewController` | `-` | `viewDidAppear:` |  | ✅ | ❌ | `0x213758` |
| `ApplilinkViewController` | `-` | `viewWillDisappear:` |  | ✅ | ❌ | `0x213794` |
| `ApplilinkViewController` | `-` | `viewDidDisappear:` |  | ✅ | ✅ | `0x2137d0` |
| `ApplilinkViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ❌ | `0x2137d4` |
| `ApplilinkViewController` | `-` | `showSKStore:appParam:delegate:` |  | ✅ | ❌ | `0x213810` |
| `ApplilinkViewController` | `-` | `productViewControllerDidFinish:` |  | ✅ | ❌ | `0x213f3c` |
| `ApplilinkViewController` | `-` | `productViewControllerDidFinish` |  | ✅ | ❌ | `0x214160` |
| `ApplilinkViewController` | `-` | `shouldAutorotate` |  | ✅ | ✅ | `0x214384` |
| `ApplilinkViewController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ✅ | `0x21438c` |
| `ApplilinkViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x214394` |
| `ApplilinkViewController` | `-` | `sdkDelegate` | prop | ✅ | ✅ | `0x21439c` |
| `ApplilinkViewController` | `-` | `setSdkDelegate:` | prop | ✅ | ✅ | `0x2143bc` |
| `ApplilinkViewController` | `-` | `applilinkParams` | prop | ✅ | ✅ | `0x2143d0` |
| `ApplilinkViewController` | `-` | `setApplilinkParams:` | prop | ✅ | ✅ | `0x2143e0` |
| `ApplilinkViewController` | `-` | `indicator` | prop | ✅ | ✅ | `0x2143fc` |
| `ApplilinkViewController` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x21440c` |
| `ApplilinkCore` | `+` | `initializeWithAppliId:env:resume:callback:` |  | ✅ | ❌ | `0x214494` |
| `ApplilinkCore` | `+` | `resume` |  | ✅ | ❌ | `0x214b00` |
| `ApplilinkCore` | `+` | `setNavigationBarCommonAppearance:` |  | ✅ | ✅ | `0x214c00` |
| `ApplilinkCore` | `+` | `isNavigationBarCommonAppearance` |  | ✅ | ✅ | `0x214c10` |
| `ApplilinkCore` | `+` | `setPriorityDeviceLanguages:` |  | ✅ | ✅ | `0x214c20` |
| `ApplilinkCore` | `+` | `isPriorityDeviceLanguages` |  | ✅ | ✅ | `0x214c30` |
| `ApplilinkCore` | `+` | `setIndicatorColor:` |  | ✅ | ✅ | `0x214c40` |
| `ApplilinkCore` | `+` | `getIndicatorColor` |  | ✅ | ✅ | `0x214c6c` |
| `ApplilinkCore` | `+` | `unusedInStore` |  | ✅ | ✅ | `0x214cb4` |
| `ApplilinkCore` | `+` | `isUsedInStore` |  | ✅ | ✅ | `0x214cc8` |
| `ApplilinkCore` | `+` | `buildUnderXcode6` |  | ✅ | ✅ | `0x214cd8` |
| `ApplilinkCore` | `+` | `isBuildXcode6` |  | ✅ | ✅ | `0x214cec` |
| `ApplilinkCore` | `+` | `mainWindow` |  | ✅ | ❌ | `0x214d04` |
| `ApplilinkCore` | `+` | `isInitializingFlg` |  | ✅ | ✅ | `0x214fb4` |
| `ApplilinkCore` | `+` | `isInitializeStatusFlg` |  | ✅ | ✅ | `0x214fc4` |
| `ApplilinkCore` | `+` | `appliId` |  | ✅ | ✅ | `0x214fd4` |
| `ApplilinkCore` | `+` | `currentUdid` |  | ✅ | ✅ | `0x215040` |
| `ApplilinkCore` | `+` | `udid_cache` |  | ✅ | ❌ | `0x2150bc` |
| `ApplilinkCore` | `+` | `ad_udid_cache` |  | ✅ | ❌ | `0x2150cc` |
| `ApplilinkCore` | `+` | `old_udid_cache` |  | ✅ | ❌ | `0x2150dc` |
| `ApplilinkCore` | `+` | `udid` |  | ✅ | ❌ | `0x2150ec` |
| `ApplilinkCore` | `+` | `pasteBoard_udid` |  | ✅ | ❌ | `0x215260` |
| `ApplilinkCore` | `+` | `ad_udid` |  | ✅ | ❌ | `0x2153a0` |
| `ApplilinkCore` | `+` | `old_udid` |  | ✅ | ❌ | `0x21558c` |
| `ApplilinkCore` | `+` | `checkUdid` |  | ✅ | ❌ | `0x215654` |
| `ApplilinkCore` | `+` | `clearUDID` |  | ✅ | ❌ | `0x2156c4` |
| `ApplilinkCore` | `+` | `setAdUdid:` |  | ✅ | ❌ | `0x2157f8` |
| `ApplilinkCore` | `+` | `clearKeyChainOldUDID` |  | ✅ | ❌ | `0x215864` |
| `ApplilinkCore` | `+` | `clearAdUDID` |  | ✅ | ❌ | `0x2159bc` |
| `ApplilinkCore` | `+` | `clearInitialize` |  | ✅ | ❌ | `0x215a90` |
| `ApplilinkCore` | `+` | `signatureKey` |  | ✅ | ❌ | `0x215b2c` |
| `ApplilinkCore` | `+` | `versionDev` |  | ✅ | ❌ | `0x215b58` |
| `ApplilinkCore` | `+` | `showAppStoreId:appParam:delegate:` |  | ✅ | ❌ | `0x215ba4` |
| `ApplilinkCore` | `+` | `closeAppStore` |  | ✅ | ❌ | `0x215c9c` |
| `ApplilinkCore` | `+` | `updatePasteBoard` |  | ✅ | ❌ | `0x215cec` |
| `ApplilinkCore` | `+` | `appAuthSessionRegenerateWithBlock:` |  | ✅ | ❌ | `0x215d7c` |
| `ApplilinkCore` | `+` | `toDelegateDidStart:delegate:` |  | ✅ | ❌ | `0x2161ec` |
| `ApplilinkCore` | `+` | `toDelegateDidAppear:delegate:` |  | ✅ | ❌ | `0x2162d4` |
| `ApplilinkCore` | `+` | `toDelegateDidDisappear:delegate:` |  | ✅ | ❌ | `0x2163bc` |
| `ApplilinkCore` | `+` | `toDelegateFailOpenWithError:appParam:delegate:` |  | ✅ | ❌ | `0x2164a4` |
| `ApplilinkCore` | `+` | `toDelegateFailLoadWithError:appParam:delegate:` |  | ✅ | ❌ | `0x2165d8` |
| `ApplilinkCore` | `+` | `toDelegateFailWithError:appParam:delegate:` |  | ✅ | ❌ | `0x21670c` |
| `ApplilinkCore` | `+` | `toDelegateFailLinkWithError:appParam:delegate:` |  | ✅ | ❌ | `0x216814` |
| `RecommendAdWebView` | `-` | `init` |  | ✅ | ❌ | `0x21691c` |
| `RecommendAdWebView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x216980` |
| `RecommendAdWebView` | `-` | `initWithCoder:` |  | ✅ | ❌ | `0x2169e4` |
| `RecommendAdWebView` | `-` | `setInitParam` |  | ✅ | ❌ | `0x216a48` |
| `RecommendAdWebView` | `-` | `removeFromSuperview` |  | ✅ | ❌ | `0x216b24` |
| `RecommendAdWebView` | `-` | `loadRequestWithAdModel:adLocation:verticalAlign:requestCode:delegate:` |  | ✅ | ❌ | `0x216c00` |
| `RecommendAdWebView` | `-` | `loadRequest` |  | ✅ | ❌ | `0x216d88` |
| `RecommendAdWebView` | `-` | `loadRequestWithURL:parameters:` |  | ✅ | ❌ | `0x217b7c` |
| `RecommendAdWebView` | `-` | `closeAdArea` |  | ✅ | ❌ | `0x217c90` |
| `RecommendAdWebView` | `-` | `setScrollEnabled:` |  | ✅ | ❌ | `0x217ce4` |
| `RecommendAdWebView` | `-` | `setScrollBoundsEnabled:` |  | ✅ | ❌ | `0x217fec` |
| `RecommendAdWebView` | `-` | `setScrollBarEnabled:` |  | ✅ | ❌ | `0x2182c4` |
| `RecommendAdWebView` | `-` | `unloadRecommendView` |  | ✅ | ✅ | `0x2184a0` |
| `RecommendAdWebView` | `-` | `viewDidDisappear:` |  | ✅ | ✅ | `0x2184b0` |
| `RecommendAdWebView` | `-` | `appliListClosed` |  | ✅ | ❌ | `0x2184b4` |
| `RecommendAdWebView` | `-` | `webViewDidStartLoad:` |  | ✅ | ❌ | `0x218508` |
| `RecommendAdWebView` | `-` | `webViewDidFinishLoad:` |  | ✅ | ❌ | `0x218530` |
| `RecommendAdWebView` | `-` | `webView:didFailLoadWithError:` |  | ✅ | ❌ | `0x2186a4` |
| `RecommendAdWebView` | `-` | `webView:shouldStartLoadWithRequest:navigationType:` |  | ✅ | ❌ | `0x218894` |
| `RecommendAdWebView` | `-` | `appListDidStart` |  | ✅ | ❌ | `0x218ae0` |
| `RecommendAdWebView` | `-` | `appListDidAppear` |  | ✅ | ❌ | `0x218b84` |
| `RecommendAdWebView` | `-` | `appListDidDisappear` |  | ✅ | ❌ | `0x218c4c` |
| `RecommendAdWebView` | `-` | `appListFailLoadWithError:` |  | ✅ | ❌ | `0x218d24` |
| `RecommendAdWebView` | `-` | `appListFailLinkWithError:` |  | ✅ | ❌ | `0x218e24` |
| `RecommendAdWebView` | `-` | `dealloc` |  | ✅ | ❌ | `0x218f0c` |
| `RecommendAdWebView` | `-` | `applilinkDelegate` | prop | ✅ | ✅ | `0x218fc8` |
| `RecommendAdWebView` | `-` | `setApplilinkDelegate:` | prop | ✅ | ✅ | `0x218fe8` |
| `RecommendAdWebView` | `-` | `loadComplete` | prop | ✅ | ✅ | `0x218ffc` |
| `RecommendAdWebView` | `-` | `setLoadComplete:` | prop | ✅ | ✅ | `0x21900c` |
| `RecommendAdWebView` | `-` | `reloadFlg` | prop | ✅ | ✅ | `0x21901c` |
| `RecommendAdWebView` | `-` | `setReloadFlg:` | prop | ✅ | ✅ | `0x21902c` |
| `RecommendAdWebView` | `-` | `cancelFlg` | prop | ✅ | ✅ | `0x21903c` |
| `RecommendAdWebView` | `-` | `setCancelFlg:` | prop | ✅ | ✅ | `0x21904c` |
| `RecommendAdWebView` | `-` | `scrollFlg` | prop | ✅ | ✅ | `0x21905c` |
| `RecommendAdWebView` | `-` | `setScrollFlg:` | prop | ✅ | ✅ | `0x21906c` |
| `RecommendAdWebView` | `-` | `webViewStatus` | prop | ✅ | ✅ | `0x21907c` |
| `RecommendAdWebView` | `-` | `setWebViewStatus:` | prop | ✅ | ✅ | `0x21908c` |
| `RecommendAdWebView` | `-` | `adModel` | prop | ✅ | ✅ | `0x21909c` |
| `RecommendAdWebView` | `-` | `setAdModel:` | prop | ✅ | ✅ | `0x2190ac` |
| `RecommendAdWebView` | `-` | `adLocation` | prop | ✅ | ✅ | `0x2190bc` |
| `RecommendAdWebView` | `-` | `setAdLocation:` | prop | ✅ | ✅ | `0x2190cc` |
| `RecommendAdWebView` | `-` | `verticalAlign` | prop | ✅ | ✅ | `0x219104` |
| `RecommendAdWebView` | `-` | `setVerticalAlign:` | prop | ✅ | ✅ | `0x219114` |
| `RecommendAdWebView` | `-` | `requestCode` | prop | ✅ | ✅ | `0x219124` |
| `RecommendAdWebView` | `-` | `setRequestCode:` | prop | ✅ | ✅ | `0x219134` |
| `RecommendDebug` | `+` | `adModelSettingList` |  | ✅ | ❌ | `0x219180` |
| `RecommendDebug` | `+` | `bannerDisplayStatusList` |  | ✅ | ❌ | `0x2193f0` |
| `RecommendDebug` | `+` | `bannerList` |  | ✅ | ❌ | `0x219600` |
| `RecommendDebug` | `+` | `iconList` |  | ✅ | ❌ | `0x21acd0` |
| `RecommendDebug` | `+` | `debugMode:` |  | ✅ | ❌ | `0x21c43c` |
| `RecommendDebug` | `+` | `getDebugMode` |  | ✅ | ❌ | `0x21c514` |
| `RecommendDebug` | `+` | `getFrequencyStatus` |  | ✅ | ❌ | `0x21c580` |
| `RecommendDebug` | `+` | `getDisplaySpec` |  | ✅ | ❌ | `0x21c704` |
| `RewardWebViewController` | `-` | `init` |  | ✅ | ❌ | `0x21c910` |
| `RewardWebViewController` | `-` | `loadView` |  | ✅ | ❌ | `0x21c94c` |
| `RewardWebViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ❌ | `0x21d0f0` |
| `RewardWebViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x21d12c` |
| `RewardWebViewController` | `-` | `viewDidDisappear:` |  | ✅ | ❌ | `0x21d1a8` |
| `RewardWebViewController` | `-` | `viewDealloc` |  | ✅ | ❌ | `0x21d1bc` |
| `RewardWebViewController` | `-` | `setNavigationBarHidden:` |  | ✅ | ❌ | `0x21d2cc` |
| `RewardWebViewController` | `-` | `prefersStatusBarHidden` |  | ✅ | ✅ | `0x21d2dc` |
| `RewardWebViewController` | `-` | `loadRequestWithURL:parameters:` |  | ✅ | ❌ | `0x21d2e4` |
| `RewardWebViewController` | `-` | `btnCloseClicked:` |  | ✅ | ✅ | `0x21d570` |
| `RewardWebViewController` | `-` | `appliListClosed` |  | ✅ | ❌ | `0x21d580` |
| `RewardWebViewController` | `-` | `updateIndicator:` |  | ✅ | ❌ | `0x21d620` |
| `RewardWebViewController` | `-` | `activeWebView` |  | ✅ | ❌ | `0x21d6e4` |
| `RewardWebViewController` | `-` | `setWebViewBounces:` | prop | ✅ | ✅ | `0x21d708` |
| `RewardWebViewController` | `-` | `webViewDidStartLoad:` |  | ✅ | ❌ | `0x21d71c` |
| `RewardWebViewController` | `-` | `webViewDidFinishLoad:` |  | ✅ | ❌ | `0x21d748` |
| `RewardWebViewController` | `-` | `webView:didFailLoadWithError:` |  | ✅ | ❌ | `0x21d87c` |
| `RewardWebViewController` | `-` | `webView:shouldStartLoadWithRequest:navigationType:` |  | ✅ | ❌ | `0x21da8c` |
| `RewardWebViewController` | `-` | `redirectWithRequest:` |  | ✅ | ❌ | `0x21dc30` |
| `RewardWebViewController` | `-` | `appListDidStart` |  | ✅ | ❌ | `0x21dcb4` |
| `RewardWebViewController` | `-` | `appListDidAppear` |  | ✅ | ❌ | `0x21dd58` |
| `RewardWebViewController` | `-` | `appListDidDisappear` |  | ✅ | ❌ | `0x21ddfc` |
| `RewardWebViewController` | `-` | `appListFailLoadWithError:` |  | ✅ | ❌ | `0x21deac` |
| `RewardWebViewController` | `-` | `appListFailLinkWithError:` |  | ✅ | ❌ | `0x21df70` |
| `RewardWebViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ❌ | `0x21e028` |
| `RewardWebViewController` | `-` | `shouldAutorotate` |  | ✅ | ✅ | `0x21e0d0` |
| `RewardWebViewController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ✅ | `0x21e0d8` |
| `RewardWebViewController` | `-` | `rotateWebViewWithInterfaceOrientation:duration:` |  | ✅ | ❌ | `0x21e0e0` |
| `RewardWebViewController` | `-` | `willAnimateRotationToInterfaceOrientation:duration:` |  | ✅ | ❌ | `0x21efec` |
| `RewardWebViewController` | `-` | `hasParentViewController:` |  | ✅ | ❌ | `0x21f068` |
| `RewardWebViewController` | `-` | `clearDelegate` |  | ✅ | ❌ | `0x21f19c` |
| `RewardWebViewController` | `-` | `dealloc` |  | ✅ | ❌ | `0x21f1f8` |
| `RewardWebViewController` | `-` | `sdkDelegate` | prop | ✅ | ✅ | `0x21f25c` |
| `RewardWebViewController` | `-` | `setSdkDelegate:` | prop | ✅ | ✅ | `0x21f27c` |
| `RewardWebViewController` | `-` | `parentView` | prop | ✅ | ✅ | `0x21f290` |
| `RewardWebViewController` | `-` | `setParentView:` | prop | ✅ | ✅ | `0x21f2a0` |
| `RewardWebViewController` | `-` | `baseView` | prop | ✅ | ✅ | `0x21f2d8` |
| `RewardWebViewController` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x21f2e8` |
| `RewardWebViewController` | `-` | `webView` | prop | ✅ | ✅ | `0x21f320` |
| `RewardWebViewController` | `-` | `setWebView:` | prop | ✅ | ✅ | `0x21f330` |
| `RewardWebViewController` | `-` | `isNavigationBarHidden` | prop | ✅ | ✅ | `0x21f368` |
| `RewardWebViewController` | `-` | `setIsNavigationBarHidden:` | prop | ✅ | ✅ | `0x21f378` |
| `RewardWebViewController` | `-` | `navigationBar` | prop | ✅ | ✅ | `0x21f388` |
| `RewardWebViewController` | `-` | `setNavigationBar:` | prop | ✅ | ✅ | `0x21f398` |
| `RewardWebViewController` | `-` | `indicator` | prop | ✅ | ✅ | `0x21f3d0` |
| `RewardWebViewController` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x21f3e0` |
| `RewardWebViewController` | `-` | `viewCloseFlg` | prop | ✅ | ✅ | `0x21f418` |
| `RewardWebViewController` | `-` | `setViewCloseFlg:` | prop | ✅ | ✅ | `0x21f428` |
| `RewardWebViewController` | `-` | `webViewBounces` | prop | ✅ | ✅ | `0x21f438` |
| `RewardWebViewController` | `-` | `webViewStatus` | prop | ✅ | ✅ | `0x21f448` |
| `RewardWebViewController` | `-` | `setWebViewStatus:` | prop | ✅ | ✅ | `0x21f458` |
| `RewardWebViewController` | `-` | `baseFrame` | prop | ✅ | ✅ | `0x21f468` |
| `RewardWebViewController` | `-` | `setBaseFrame:` | prop | ✅ | ✅ | `0x21f480` |
| `RewardNetwork` | `+` | `openAdScreenWithAdLocation:requestCode:delegate:` |  | ✅ | ❌ | `0x21f524` |
| `RewardNetwork` | `+` | `openAdScreenWithParentView:adLocation:delegate:` |  | ✅ | ❌ | `0x21f598` |
| `RewardNetwork` | `+` | `openAdScreenWithParentView:adLocation:requestCode:delegate:` |  | ✅ | ❌ | `0x21f60c` |
| `RewardNetwork` | `+` | `closeAdScreen` |  | ✅ | ❌ | `0x21f808` |
| `RewardNetwork` | `+` | `allInstallFlgWithCallback:` |  | ✅ | ❌ | `0x21f880` |
| `RewardNetwork` | `+` | `getAdDisplayStatusWithCallback:` |  | ✅ | ❌ | `0x21f9e0` |
| `RewardNetwork` | `+` | `getAdStatusWithBlock:` |  | ✅ | ❌ | `0x21fc14` |
| `RewardNetwork` | `+` | `setNavigationBarHidden:` |  | ✅ | ❌ | `0x21fd74` |
| `RewardNetwork` | `+` | `getNavigationTitle` |  | ✅ | ✅ | `0x21fdcc` |
| `RewardNetwork` | `-` | `dealloc` |  | ❌ | ✅ | `0x21fdec` |
| `ApplilinkMessage` | `+` | `localizedMessage:` |  | ✅ | ❌ | `0x21fe28` |
| `ApplilinkIndicator` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x21ff40` |
| `ApplilinkIndicator` | `-` | `layoutSubviews` |  | ✅ | ❌ | `0x220074` |
| `ApplilinkIndicator` | `-` | `show` |  | ✅ | ❌ | `0x220124` |
| `ApplilinkIndicator` | `-` | `close` |  | ✅ | ❌ | `0x22017c` |
| `ApplilinkIndicator` | `-` | `touchEventActived` |  | ✅ | ❌ | `0x2201e0` |
| `ApplilinkIndicator` | `-` | `dealloc` |  | ✅ | ✅ | `0x220254` |
| `ApplilinkIndicator` | `-` | `indicator` | prop | ✅ | ✅ | `0x220290` |
| `ApplilinkIndicator` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x2202a0` |
| `ApplilinkStore` | `-` | `init` |  | ✅ | ✅ | `0x2202ec` |
| `ApplilinkStore` | `+` | `allocWithZone:` |  | ✅ | ✅ | `0x2204c0` |
| `ApplilinkStore` | `+` | `sharedInstance` |  | ✅ | ❌ | `0x2205c0` |
| `ApplilinkStore` | `-` | `showSKStore:appParam:delegate:` |  | ✅ | ❌ | `0x220650` |
| `ApplilinkStore` | `-` | `closeSKStore` |  | ✅ | ❌ | `0x2207e4` |
| `ApplilinkStore` | `-` | `appStoreOpenedNoticeWithAppParam:` |  | ✅ | ❌ | `0x220808` |
| `ApplilinkStore` | `-` | `appStoreCloseNoticeWithAppParam:` |  | ✅ | ❌ | `0x2208c8` |
| `ApplilinkStore` | `-` | `appStoreClosedNoticeWithAppParam:` |  | ✅ | ❌ | `0x220988` |
| `ApplilinkStore` | `-` | `appStoreFailLoadNoticeWithError:appParam:` |  | ✅ | ❌ | `0x220a84` |
| `ApplilinkStore` | `-` | `sdkDelegate` | prop | ✅ | ✅ | `0x220b84` |
| `ApplilinkStore` | `-` | `setSdkDelegate:` | prop | ✅ | ✅ | `0x220ba4` |
| `ApplilinkStore` | `-` | `applilinkParams` | prop | ✅ | ✅ | `0x220bb8` |
| `ApplilinkStore` | `-` | `setApplilinkParams:` | prop | ✅ | ✅ | `0x220bc8` |
| `DestinationCore` | `-` | `destinationRegistWithCountryCode:url:delegate:` |  | ❌ | ❌ | `0x220c20` |
| `DestinationCore` | `-` | `failLoadWithError:` |  | ❌ | ❌ | `0x220e4c` |
| `DestinationCore` | `-` | `finishLoadWithResponse:` |  | ❌ | ❌ | `0x220e50` |
| `DestinationCore` | `-` | `redirectStartLoad:` |  | ❌ | ❌ | `0x220e54` |
| `ApplilinkDebug` | `+` | `countryCode` |  | ✅ | ✅ | `0x220e5c` |
| `ApplilinkDebug` | `+` | `categoryId` |  | ✅ | ✅ | `0x220e74` |
| `ApplilinkDebug` | `+` | `udid` |  | ✅ | ✅ | `0x220e8c` |
| `ApplilinkDebug` | `+` | `ad_udid` |  | ✅ | ✅ | `0x220ea4` |
| `ApplilinkDebug` | `+` | `old_udid` |  | ✅ | ✅ | `0x220ebc` |
| `ApplilinkDebug` | `+` | `clearUDID` |  | ✅ | ✅ | `0x220ed4` |
| `ApplilinkDebug` | `+` | `clearKeyChainOldUDID` |  | ✅ | ✅ | `0x220eec` |
| `ApplilinkDebug` | `+` | `clearAdUDID` |  | ✅ | ✅ | `0x220f04` |
| `ApplilinkDebug` | `+` | `versionDev` |  | ✅ | ❌ | `0x220f1c` |
| `ApplilinkDebug` | `+` | `clearSession` |  | ✅ | ❌ | `0x220f68` |
| `ApplilinkDebug` | `+` | `clearAdStatus` |  | ✅ | ❌ | `0x220ff4` |
| `ApplilinkDebug` | `+` | `clearInitalize` |  | ✅ | ✅ | `0x221080` |
| `ApplilinkDebug` | `+` | `clearDAU` |  | ✅ | ✅ | `0x221098` |
| `ApplilinkDebug` | `+` | `debugMode:` |  | ✅ | ✅ | `0x2210b0` |
| `ApplilinkDebug` | `+` | `getDebugMode` |  | ✅ | ✅ | `0x2210c8` |
| `ApplilinkDebug` | `+` | `allClearCacheBannerImage` |  | ✅ | ✅ | `0x2210e0` |
| `ApplilinkDebug` | `+` | `getFrequencyStatus` |  | ✅ | ✅ | `0x2210f8` |
| `ApplilinkDebug` | `+` | `getDisplaySpec` |  | ✅ | ✅ | `0x221110` |
| `ApplilinkWebAPI` | `-` | `init` |  | ✅ | ❌ | `0x221128` |
| `ApplilinkWebAPI` | `-` | `commonParameters` |  | ✅ | ❌ | `0x221184` |
| `ApplilinkWebAPI` | `-` | `requestWithURL:method:parameters:timeout:cachePolicy:` |  | ✅ | ❌ | `0x2211dc` |
| `ApplilinkWebAPI` | `-` | `requestForGetWithURL:parameters:` |  | ✅ | ❌ | `0x2213a4` |
| `ApplilinkWebAPI` | `-` | `requestForPostWithURL:parameters:` |  | ✅ | ❌ | `0x221474` |
| `ApplilinkWebAPI` | `-` | `requestAsynchronousWithURL:method:parameters:userInfo:tag:cachePolicy:timeout:retry:finishedBlock:failedBlock:` |  | ❌ | ❌ | `0x2218fc` |
| `ApplilinkWebAPI` | `-` | `responseFromContentsServer:request:data:finishedBlock:failedBlock:` |  | ✅ | ❌ | `0x222928` |
| `ApplilinkWebAPI` | `-` | `requestSynchronousWithURL:method:parameters:cachePolicy:error:` |  | ✅ | ❌ | `0x222f38` |
| `ApplilinkWebAPI` | `+` | `requestAsynchronousWithURL:method:parameters:userInfo:tag:cachePolicy:timeout:retry:finishedBlock:failedBlock:` |  | ❌ | ❌ | `0x2232d8` |
| `ApplilinkWebAPI` | `+` | `requestSynchronousWithURL:method:parameters:cachePolicy:error:` |  | ✅ | ❌ | `0x223604` |
| `ApplilinkWebAPI` | `+` | `responseFromContentsServer:request:data:finishedBlock:failedBlock:` |  | ✅ | ❌ | `0x223704` |
| `ApplilinkWebAPI` | `+` | `retryCancel` |  | ✅ | ❌ | `0x223818` |
| `ApplilinkWebAPI` | `+` | `setSessionConnectionWait:` |  | ✅ | ❌ | `0x223828` |
| `ApplilinkWebAPI` | `+` | `calcelSessionConnection` |  | ✅ | ❌ | `0x2238a4` |
| `ApplilinkWebAPI` | `+` | `setSessionStatus:` |  | ✅ | ❌ | `0x2238b4` |
| `ApplilinkWebAPI` | `-` | `canUseNetworkRetry` |  | ✅ | ❌ | `0x2238c4` |
| `ApplilinkWebAPI` | `-` | `dealloc` |  | ✅ | ✅ | `0x223954` |
| `RewardWebAPI` | `+` | `postApplicationInstallWithPriority:callback:` |  | ✅ | ❌ | `0x223990` |
| `RewardWebAPI` | `+` | `checkLoginWithBlock:` |  | ✅ | ❌ | `0x224188` |
| `RewardWebAPI` | `+` | `startLoginWithUserId:withPriority:callback:` |  | ✅ | ❌ | `0x22456c` |
| `RewardWebAPI` | `+` | `appListWithCampaignId:inCompany:offset:limit:callback:` |  | ✅ | ❌ | `0x224d00` |
| `RewardWebAPI` | `+` | `appliIdListWithType:callback:` |  | ✅ | ❌ | `0x2250c4` |
| `RewardWebAPI` | `+` | `allInstallFlgWithCallback:` |  | ✅ | ❌ | `0x225490` |
| `RewardWebAPI` | `+` | `getPreInfoWithCallback:` |  | ✅ | ❌ | `0x225a0c` |
| `RewardWebAPI` | `+` | `postAppliInstallReportWithAppliList:callback:` |  | ✅ | ❌ | `0x225f58` |
| `RewardWebAPI` | `+` | `bannerInfoWithBlock:` |  | ✅ | ❌ | `0x2264ac` |
| `RewardWebAPI` | `+` | `setSignatureWithParameters:` |  | ✅ | ❌ | `0x226834` |
| `RewardWebAPI` | `+` | `setTemporaryCacheWithKey:value:expiration:` |  | ✅ | ❌ | `0x226cdc` |
| `RecommendAdData` | `+` | `getBannerDisplayStatusList` |  | ✅ | ❌ | `0x226e90` |
| `RecommendAdData` | `+` | `getAdModelSettingList` |  | ✅ | ❌ | `0x226fbc` |
| `RecommendAdData` | `+` | `getAdList` |  | ✅ | ❌ | `0x2270e8` |
| `RecommendAdData` | `+` | `getInterstitialSpecList` |  | ✅ | ❌ | `0x2271c4` |
| `RecommendAdData` | `+` | `getAdStatusByAdModel:` |  | ✅ | ❌ | `0x2272a0` |
| `RecommendAdData` | `+` | `getAdDataByAdId:` |  | ✅ | ❌ | `0x227460` |
| `RecommendAdData` | `+` | `getAdDataWithAppliId:` |  | ✅ | ❌ | `0x227570` |
| `RecommendAdData` | `+` | `getAdListByAdType:` |  | ✅ | ❌ | `0x2277dc` |
| `RecommendAdData` | `+` | `getAppBannerList` |  | ✅ | ❌ | `0x2278a0` |
| `RecommendAdData` | `+` | `getAppIconList` |  | ✅ | ❌ | `0x227c50` |
| `RecommendAdData` | `+` | `getAppInterstitialList` |  | ✅ | ❌ | `0x227fec` |
| `RecommendAdData` | `+` | `getLotteryBannerData` |  | ✅ | ❌ | `0x2283c8` |
| `RecommendAdData` | `+` | `getLotteryIconData` |  | ✅ | ❌ | `0x2284c4` |
| `RecommendAdData` | `+` | `getLotteryInterstitialData` |  | ✅ | ❌ | `0x228624` |
| `RecommendAdData` | `+` | `getLotteryInterstitialDataWithList:` |  | ✅ | ❌ | `0x228770` |
| `RecommendAdData` | `+` | `getInterstitialSpecPriorityList` |  | ✅ | ❌ | `0x228a18` |
| `RecommendAdData` | `+` | `getInterstitialSpecCountForAdDisplaySpecList:` |  | ✅ | ❌ | `0x228b28` |
| `RecommendAdData` | `+` | `getInterstitialSpecInstallForAdDisplaySpecList:` |  | ✅ | ❌ | `0x229078` |
| `RecommendAdData` | `+` | `getAdInterstitialUrlListTermForAdDisplaySpecList:` |  | ✅ | ❌ | `0x2297c4` |
| `RecommendAdData` | `+` | `getAdInterstitialUrlListTermForList:` |  | ✅ | ❌ | `0x229ae8` |
| `RecommendAdData` | `+` | `getAdDisplayCountDailyDictionary` |  | ✅ | ❌ | `0x229ce4` |
| `RecommendAdData` | `+` | `getAdDisplayCountTotalDictionary` |  | ✅ | ❌ | `0x229ee0` |
| `RecommendAdData` | `+` | `getAdTypeWithAdModel:adLocation:` |  | ✅ | ❌ | `0x229f90` |
| `RecommendAdData` | `+` | `getAdListTermForList:` |  | ✅ | ❌ | `0x22a288` |
| `RecommendAdData` | `+` | `getAdBannerListForList:` |  | ✅ | ❌ | `0x22a610` |
| `RecommendAdData` | `+` | `shuffled:` |  | ✅ | ❌ | `0x22a884` |
| `RecommendAdData` | `+` | `lotteryInterstitialWithAdLocation:` |  | ✅ | ❌ | `0x22aa30` |
| `RecommendAdData` | `+` | `getInstallFlgWithAdData:` |  | ✅ | ❌ | `0x22b200` |
| `ShadeView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x22b498` |
| `ShadeView` | `-` | `touchesEnded:withEvent:` |  | ✅ | ❌ | `0x22b55c` |
| `ShadeView` | `-` | `delegate` | prop | ✅ | ✅ | `0x22b5d0` |
| `ShadeView` | `-` | `setDelegate:` | prop | ✅ | ✅ | `0x22b5e0` |
| `ApplilinkUdid` | `-` | `init` |  | ✅ | ✅ | `0x22b5f0` |
| `ApplilinkUdid` | `+` | `allocWithZone:` |  | ✅ | ✅ | `0x22b7c4` |
| `ApplilinkUdid` | `+` | `sharedInstance` |  | ✅ | ✅ | `0x22b8c4` |
| `ApplilinkUdid` | `+` | `writeUDIDForFirstEmptyLocationWithError:` |  | ✅ | ✅ | `0x22b9ac` |
| `ApplilinkUdid` | `+` | `writeUDIDForFirstEmptyLocationWithUdid:` |  | ✅ | ✅ | `0x22bb94` |
| `ApplilinkUdid` | `+` | `writeUDIDWithUdid:` |  | ✅ | ✅ | `0x22bcc0` |
| `ApplilinkUdid` | `+` | `udidWithServiceName:storageIndex:error:` |  | ✅ | ✅ | `0x22bee8` |
| `ApplilinkUdid` | `+` | `udidForFirstInvalidDataWithError:` |  | ✅ | ✅ | `0x22c00c` |
| `ApplilinkUdid` | `+` | `udidOldForFirstInvalidDataWithError:` |  | ✅ | ✅ | `0x22c0d8` |
| `ApplilinkUdid` | `+` | `deleteUDIDWithServiceName:storageIndex:error:` |  | ✅ | ✅ | `0x22c1a4` |
| `ApplilinkUdid` | `+` | `deleteAllUDID` |  | ✅ | ✅ | `0x22c2f4` |
| `ApplilinkUdid` | `+` | `getAdvertisingRewardUdidWithError:` |  | ✅ | ✅ | `0x22c508` |
| `ApplilinkUdid` | `+` | `createAdvertisingRewardUdidWithError:` |  | ✅ | ✅ | `0x22c63c` |
| `ApplilinkUdid` | `+` | `deleteAdvertisingRewardUdidIndex:error:` |  | ✅ | ✅ | `0x22c8b8` |
| `ApplilinkUdid` | `+` | `deleteAllAdvertisingUDID` |  | ✅ | ✅ | `0x22c9f0` |
| `ApplilinkUdid` | `+` | `setOldUdid:error:` |  | ✅ | ✅ | `0x22ca54` |
| `ApplilinkUdid` | `+` | `getOldUdidWithError:` |  | ✅ | ✅ | `0x22cb28` |
| `ApplilinkUdid` | `+` | `deleteOldUdidWithError:` |  | ✅ | ✅ | `0x22cba4` |
| `ApplilinkUdid` | `+` | `setNewUdid:error:` |  | ✅ | ✅ | `0x22cc98` |
| `ApplilinkUdid` | `+` | `setUdidWithService:withUDID:` |  | ✅ | ✅ | `0x22ce18` |
| `ApplilinkUdid` | `+` | `getUdidWithService:storageIndex:rewardNetworkUDIDType:error:` |  | ✅ | ✅ | `0x22d040` |
| `ApplilinkUdid` | `+` | `searchWithService:` |  | ✅ | ✅ | `0x22d3ec` |
| `ApplilinkUdid` | `+` | `deleteKeyChainService:error:` |  | ✅ | ✅ | `0x22d52c` |
| `ApplilinkUdid` | `+` | `validate:error:` |  | ✅ | ✅ | `0x22d69c` |
| `ApplilinkUdid` | `+` | `getServiceIndex:` |  | ✅ | ✅ | `0x22d980` |
| `ApplilinkUdid` | `+` | `setService:withStorageIndex:` |  | ✅ | ✅ | `0x22db4c` |
| `ApplilinkUdid` | `+` | `getCFUUID` |  | ✅ | ✅ | `0x22dcac` |
| `ApplilinkUdid` | `+` | `getAdvertisingUdid` |  | ✅ | ✅ | `0x22dcf8` |
| `ApplilinkUdid` | `+` | `isAdvertisingTrackingEnabled` |  | ✅ | ✅ | `0x22ddac` |
| `ApplilinkUdid` | `+` | `isAdvertisingTrackingOSVersion` |  | ✅ | ✅ | `0x22de2c` |
| `ApplilinkUdid` | `+` | `md5WithString:` |  | ✅ | ✅ | `0x22dec0` |
| `ApplilinkUdid` | `+` | `setUdidParameters:isUDIDPriorityType:` |  | ✅ | ✅ | `0x22dfd8` |
| `ApplilinkUdid` | `+` | `setUdidParameters:` |  | ✅ | ✅ | `0x22e2cc` |
| `ApplilinkUdid` | `+` | `isUdidThreeKinds` |  | ✅ | ✅ | `0x22e42c` |
| `ApplilinkUdid` | `+` | `isUdidSDKPasteBoard` |  | ✅ | ✅ | `0x22e52c` |
| `ApplilinkUdid` | `+` | `getServiceName` |  | ✅ | ✅ | `0x22e5d4` |
| `ApplilinkUdid` | `+` | `getServiceNameOld` |  | ✅ | ✅ | `0x22e6bc` |
| `ApplilinkUdid` | `+` | `setUdidKeychainFromPasteBoard` |  | ✅ | ✅ | `0x22e7a4` |
| `ApplilinkUdid` | `+` | `isPasteBoardStatus` |  | ✅ | ✅ | `0x22e9c4` |
| `ApplilinkUdid` | `+` | `getAdUdid` |  | ✅ | ✅ | `0x22ea4c` |
| `ApplilinkUdid` | `-` | `bundleSeedID` |  | ✅ | ✅ | `0x22ec0c` |
| `ApplilinkUdid` | `+` | `debugLog` |  | ✅ | ✅ | `0x22edb4` |
| `ApplilinkUdid` | `-` | `dealloc` |  | ❌ | ✅ | `0x22eec8` |
| `ApplilinkUdid` | `-` | `pasteBoard` | prop | ✅ | ✅ | `0x22ef04` |
| `ApplilinkUdid` | `-` | `setPasteBoard:` | prop | ✅ | ✅ | `0x22ef14` |
| `RecommendWebAPI` | `+` | `checkLoginWithCallback:` |  | ✅ | ❌ | `0x22ef60` |
| `RecommendWebAPI` | `+` | `startLoginWithCallback:` |  | ✅ | ❌ | `0x22f3c8` |
| `RecommendWebAPI` | `+` | `getAdDetailWithCallback:` |  | ✅ | ❌ | `0x22f958` |
| `RecommendWebAPI` | `+` | `installAppliListWithCallBack:` |  | ✅ | ❌ | `0x2301d8` |
| `RecommendWebAPI` | `+` | `appliListWithParameters:callBack:` |  | ✅ | ❌ | `0x230830` |
| `RecommendWebAPI` | `+` | `postApplicationInstallWithAdIdFrom:categoryId:adType:priority:callback:` |  | ✅ | ❌ | `0x230dd4` |
| `RecommendWebAPI` | `+` | `getBannerDetailWithAdModel:callback:` |  | ✅ | ❌ | `0x231474` |
| `RecommendWebAPI` | `+` | `readRegistWithAdType:adIdList:callback:` |  | ✅ | ❌ | `0x231af8` |
| `RecommendWebAPI` | `+` | `getUnreadCountWithAdModel:adLocation:callback:` |  | ✅ | ❌ | `0x231f34` |
| `RecommendWebAPI` | `+` | `getPreInfoWithAdModel:adLocation:callback:` |  | ✅ | ❌ | `0x232418` |
| `RecommendWebAPI` | `+` | `setTemporaryCacheWithAdModel:value:expiration:` |  | ✅ | ❌ | `0x232b48` |
| `RecommendWebAPI` | `+` | `getTemporaryCacheWithAdModel:` |  | ✅ | ❌ | `0x232f44` |
| `RecommendWebAPI` | `+` | `clickRegistWithAdIdFrom:adIdTo:adModel:callback:` |  | ✅ | ❌ | `0x23327c` |
| `RecommendWebAPI` | `+` | `appStartWithAdIdFrom:adIdTo:adType:callback:` |  | ✅ | ❌ | `0x233760` |
| `RecommendWebAPI` | `+` | `allAdDataWithCallBack:` |  | ✅ | ❌ | `0x233bac` |
| `RecommendWebAPI` | `+` | `layoutIndexWithCallback:` |  | ✅ | ❌ | `0x2340ac` |
| `RecommendWebAPI` | `+` | `clickRegistWithAdIdFrom:adIdTo:adModel:` |  | ✅ | ❌ | `0x234430` |
| `RecommendWebAPI` | `+` | `appStartWithAdIdFrom:adIdTo:adType:` |  | ✅ | ❌ | `0x234670` |
| `Crypto` | `+` | `createHash:` |  | ✅ | ❌ | `0x234894` |
| `Crypto` | `+` | `sha1:` |  | ✅ | ❌ | `0x23496c` |
| `Crypto` | `+` | `sha256:` |  | ✅ | ❌ | `0x234af8` |
| `Crypto` | `+` | `cryptorToData:value:key:` |  | ✅ | ❌ | `0x234c84` |
| `ApplilinkPasteBoard` | `-` | `init` |  | ✅ | ❌ | `0x234e38` |
| `ApplilinkPasteBoard` | `-` | `storageData` |  | ✅ | ❌ | `0x234e74` |
| `ApplilinkPasteBoard` | `-` | `storageDataOld` |  | ✅ | ❌ | `0x235078` |
| `ApplilinkPasteBoard` | `-` | `storageDataWithServiceName:storageIndex:error:` |  | ✅ | ❌ | `0x235218` |
| `ApplilinkPasteBoard` | `-` | `writeStorageData:error:` |  | ✅ | ❌ | `0x23565c` |
| `ApplilinkPasteBoard` | `-` | `writeStorageData:storageIndex:error:` |  | ✅ | ❌ | `0x2358b4` |
| `ApplilinkPasteBoard` | `-` | `deleteWithStorageIndex:error:` |  | ✅ | ❌ | `0x235c80` |
| `ApplilinkPasteBoard` | `+` | `validate:error:` |  | ✅ | ❌ | `0x235e88` |
| `ApplilinkPasteBoard` | `-` | `convertToData:serviceName:storageIndex:` |  | ✅ | ❌ | `0x236174` |
| `ApplilinkPasteBoard` | `-` | `getServiceName` |  | ✅ | ❌ | `0x2363b8` |
| `ApplilinkPasteBoard` | `-` | `getServiceNameOld` |  | ✅ | ❌ | `0x236478` |
| `ApplilinkPasteBoard` | `-` | `debugLog` |  | ✅ | ❌ | `0x236538` |
| `ApplilinkPasteBoard` | `-` | `dealloc` |  | ❌ | ✅ | `0x236710` |
| `ApplilinkPasteBoard` | `-` | `nonPasteBoardUdidFlag` | prop | ✅ | ✅ | `0x23674c` |
| `ApplilinkPasteBoard` | `-` | `setNonPasteBoardUdidFlag:` | prop | ✅ | ✅ | `0x23675c` |
| `ApplilinkParameters` | `-` | `setRequestWithAdModel:adLocation:requestCode:` |  | ✅ | ❌ | `0x23676c` |
| `ApplilinkParameters` | `-` | `setRequestWithAdModel:adLocation:verticalAlign:requestCode:` |  | ✅ | ❌ | `0x2367f8` |
| `ApplilinkParameters` | `-` | `adModel` | prop | ✅ | ✅ | `0x236884` |
| `ApplilinkParameters` | `-` | `setAdModel:` | prop | ✅ | ✅ | `0x236894` |
| `ApplilinkParameters` | `-` | `adLocation` | prop | ✅ | ✅ | `0x2368a4` |
| `ApplilinkParameters` | `-` | `setAdLocation:` | prop | ✅ | ✅ | `0x2368b4` |
| `ApplilinkParameters` | `-` | `verticalAlign` | prop | ✅ | ✅ | `0x2368ec` |
| `ApplilinkParameters` | `-` | `setVerticalAlign:` | prop | ✅ | ✅ | `0x2368fc` |
| `ApplilinkParameters` | `-` | `requestCode` | prop | ✅ | ✅ | `0x23690c` |
| `ApplilinkParameters` | `-` | `setRequestCode:` | prop | ✅ | ✅ | `0x23691c` |
| `RecommendCore` | `-` | `init` |  | ✅ | ✅ | `0x236978` |
| `RecommendCore` | `+` | `allocWithZone:` |  | ✅ | ✅ | `0x236b4c` |
| `RecommendCore` | `+` | `sharedInstance` |  | ✅ | ✅ | `0x236c64` |
| `RecommendCore` | `-` | `initializeFlg` | prop | ✅ | ✅ | `0x236d14` |
| `RecommendCore` | `-` | `isInitialized` |  | ✅ | ✅ | `0x236d24` |
| `RecommendCore` | `-` | `clearInitialize` |  | ✅ | ✅ | `0x236d3c` |
| `RecommendCore` | `-` | `isInstalledAppliWithScheme:` |  | ✅ | ✅ | `0x236d4c` |
| `RecommendCore` | `-` | `startWithCallback:` |  | ✅ | ✅ | `0x236e4c` |
| `RecommendCore` | `-` | `startSessionWithCallback:` |  | ✅ | ✅ | `0x237778` |
| `RecommendCore` | `-` | `appliListWithCallBack:` |  | ✅ | ✅ | `0x237bb0` |
| `RecommendCore` | `-` | `appliListCacheWithCallBack:` |  | ✅ | ✅ | `0x237cd0` |
| `RecommendCore` | `-` | `getAdStatusWithAdModel:callback:` |  | ✅ | ✅ | `0x237d6c` |
| `RecommendCore` | `-` | `getUnreadCountWithAdModel:adLocation:callback:` |  | ✅ | ✅ | `0x237fe4` |
| `RecommendCore` | `-` | `getAdDisplayStatusWithAdModel:adLocation:callback:` |  | ✅ | ✅ | `0x238260` |
| `RecommendCore` | `-` | `getAllAdStatusWithCallback:` |  | ✅ | ✅ | `0x2385d8` |
| `RecommendCore` | `-` | `clearAllAdData` |  | ✅ | ✅ | `0x2387b8` |
| `RecommendCore` | `-` | `reloadAllAdData` |  | ✅ | ✅ | `0x2387d0` |
| `RecommendCore` | `-` | `openAdScreenWithParentView:adModel:adLocation:verticalAlign:requestCode:delegate:` |  | ✅ | ✅ | `0x238848` |
| `RecommendCore` | `-` | `openAdAreaWithParentView:rect:adModel:adLocation:verticalAlign:requestCode:delegate:` |  | ✅ | ✅ | `0x239480` |
| `RecommendCore` | `-` | `openFullViewControllerWithAdModel:adLocation:verticalAlign:requestCode:delegate:` |  | ✅ | ✅ | `0x239ed8` |
| `RecommendCore` | `-` | `closeAdScreen` |  | ✅ | ✅ | `0x23a40c` |
| `RecommendCore` | `-` | `rotateWithInterfaceOrientation:duration:` |  | ✅ | ✅ | `0x23a5ac` |
| `RecommendCore` | `-` | `setNavigationBarHidden:` | prop | ✅ | ✅ | `0x23a634` |
| `RecommendCore` | `-` | `redirectViewContollerWithRequest:` |  | ✅ | ✅ | `0x23a644` |
| `RecommendCore` | `-` | `redirectWithRequest:` |  | ✅ | ✅ | `0x23a660` |
| `RecommendCore` | `-` | `redirectWithRequest:appParam:` |  | ✅ | ✅ | `0x23a674` |
| `RecommendCore` | `-` | `getTemporaryCacheWithAdModel:` |  | ✅ | ✅ | `0x23b420` |
| `RecommendCore` | `-` | `canUseBannerCache` |  | ✅ | ✅ | `0x23b758` |
| `RecommendCore` | `-` | `clearAdStatus` |  | ✅ | ✅ | `0x23b82c` |
| `RecommendCore` | `-` | `clearSession` |  | ✅ | ✅ | `0x23b8c0` |
| `RecommendCore` | `+` | `clearData` |  | ❌ | ❌ | `0x23ba24` |
| `RecommendCore` | `-` | `postAnalysisListRegistWithAdType:AdModel:adLocation:impressionId:` |  | ✅ | ✅ | `0x23bb5c` |
| `RecommendCore` | `-` | `showOwnAdWithAdLocation:toAppliId:creativeId:` |  | ✅ | ✅ | `0x23c11c` |
| `RecommendCore` | `-` | `touchOwnAdWithAdLocation:toAppliId:creativeId:requestCode:delegate:` |  | ✅ | ✅ | `0x23c5fc` |
| `RecommendCore` | `-` | `linkActionWithDefaultScheme:adIdTo:adType:adModel:delegate:` |  | ✅ | ❌ | `0x23d0dc` |
| `RecommendCore` | `-` | `setUniqueAdWithAdLocation:impressionId:` |  | ✅ | ✅ | `0x23d330` |
| `RecommendCore` | `-` | `getUniqueAdWithAdLocation:` |  | ✅ | ✅ | `0x23d4cc` |
| `RecommendCore` | `-` | `failLoadWithError:` |  | ✅ | ✅ | `0x23d5c0` |
| `RecommendCore` | `-` | `finishLoadWithResponse:` |  | ✅ | ✅ | `0x23d740` |
| `RecommendCore` | `-` | `redirectStartLoad:` |  | ✅ | ✅ | `0x23d744` |
| `RecommendCore` | `-` | `releaseAdScreenViewController` |  | ✅ | ✅ | `0x23d7f8` |
| `RecommendCore` | `-` | `releaseInterstitialViewController` |  | ✅ | ✅ | `0x23d84c` |
| `RecommendCore` | `-` | `appListDidStart` |  | ✅ | ✅ | `0x23d8cc` |
| `RecommendCore` | `-` | `appListDidAppear` |  | ✅ | ✅ | `0x23d9d4` |
| `RecommendCore` | `-` | `appListDidDisappear` |  | ✅ | ✅ | `0x23daf4` |
| `RecommendCore` | `-` | `appListFailOpenWithError:` |  | ✅ | ✅ | `0x23dc50` |
| `RecommendCore` | `-` | `appListFailLoadWithError:` |  | ✅ | ✅ | `0x23ddf8` |
| `RecommendCore` | `-` | `appListFailWithError:` |  | ✅ | ✅ | `0x23dfa0` |
| `RecommendCore` | `-` | `startedNotice` |  | ✅ | ✅ | `0x23e148` |
| `RecommendCore` | `-` | `openedNotice` |  | ✅ | ✅ | `0x23e1b0` |
| `RecommendCore` | `-` | `closeNotice` |  | ✅ | ✅ | `0x23e250` |
| `RecommendCore` | `-` | `failOpenNoticeWithError:` |  | ✅ | ✅ | `0x23e300` |
| `RecommendCore` | `-` | `failLinkNoticeWithError:` |  | ✅ | ✅ | `0x23e3d0` |
| `RecommendCore` | `-` | `appStoreOpenedNoticeWithAppParam:` |  | ✅ | ✅ | `0x23e454` |
| `RecommendCore` | `-` | `appStoreCloseNoticeWithAppParam:` |  | ✅ | ✅ | `0x23e4dc` |
| `RecommendCore` | `-` | `appStoreClosedNoticeWithAppParam:` |  | ✅ | ✅ | `0x23e4e0` |
| `RecommendCore` | `-` | `appStoreFailLoadNoticeWithError:appParam:` |  | ✅ | ✅ | `0x23e5ac` |
| `RecommendCore` | `-` | `appStoreTransitionNoticeWithAppParam:` |  | ✅ | ✅ | `0x23e684` |
| `RecommendCore` | `-` | `setInitializeFlg:` | prop | ✅ | ✅ | `0x23e688` |
| `RecommendCore` | `-` | `interstitialViewController` | prop | ✅ | ✅ | `0x23e698` |
| `RecommendCore` | `-` | `setInterstitialViewController:` | prop | ✅ | ✅ | `0x23e6a8` |
| `RecommendCore` | `-` | `adScreenViewController` | prop | ✅ | ✅ | `0x23e6e0` |
| `RecommendCore` | `-` | `setAdScreenViewController:` | prop | ✅ | ✅ | `0x23e6f0` |
| `RecommendCore` | `-` | `applilinkDelegate` | prop | ✅ | ✅ | `0x23e728` |
| `RecommendCore` | `-` | `setApplilinkDelegate:` | prop | ✅ | ✅ | `0x23e748` |
| `RecommendCore` | `-` | `applilinkParams` | prop | ✅ | ✅ | `0x23e75c` |
| `RecommendCore` | `-` | `setApplilinkParams:` | prop | ✅ | ✅ | `0x23e76c` |
| `RecommendCore` | `-` | `reLoginStatus` | prop | ✅ | ✅ | `0x23e788` |
| `RecommendCore` | `-` | `setReLoginStatus:` | prop | ✅ | ✅ | `0x23e798` |
| `RecommendCore` | `-` | `navigationBarHidden` | prop | ✅ | ✅ | `0x23e7a8` |
| `RecommendCore` | `-` | `adScreenviewCloseFlg` | prop | ✅ | ✅ | `0x23e7b8` |
| `RecommendCore` | `-` | `setAdScreenviewCloseFlg:` | prop | ✅ | ✅ | `0x23e7c8` |
| `RecommendCore` | `-` | `redirectFlg` | prop | ✅ | ✅ | `0x23e7d8` |
| `RecommendCore` | `-` | `setRedirectFlg:` | prop | ✅ | ✅ | `0x23e7e8` |
| `RecommendCore` | `-` | `adAreaDelegate` | prop | ✅ | ✅ | `0x23e7f8` |
| `RecommendCore` | `-` | `setAdAreaDelegate:` | prop | ✅ | ✅ | `0x23e818` |
| `RecommendCore` | `-` | `adScreenDelegate` | prop | ✅ | ✅ | `0x23e82c` |
| `RecommendCore` | `-` | `setAdScreenDelegate:` | prop | ✅ | ✅ | `0x23e84c` |
| `RecommendCore` | `-` | `uniqueAdDelegate` | prop | ✅ | ✅ | `0x23e860` |
| `RecommendCore` | `-` | `setUniqueAdDelegate:` | prop | ✅ | ✅ | `0x23e880` |
| `RecommendCore` | `-` | `uniqueApplilinkParams` | prop | ✅ | ✅ | `0x23e894` |
| `RecommendCore` | `-` | `setUniqueApplilinkParams:` | prop | ✅ | ✅ | `0x23e8a4` |
| `RecommendAdAreaView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x23e968` |
| `RecommendAdAreaView` | `-` | `startPath:` |  | ✅ | ❌ | `0x23ea44` |
| `RecommendAdAreaView` | `-` | `setAdModel:adLocation:adType:requestCode:delegate:` |  | ✅ | ❌ | `0x23eb70` |
| `RecommendAdAreaView` | `-` | `removeFromSuperview` |  | ✅ | ❌ | `0x23ed30` |
| `RecommendAdAreaView` | `-` | `closeAdArea` |  | ✅ | ✅ | `0x23ed6c` |
| `RecommendAdAreaView` | `-` | `setScrollEnabled:` |  | ✅ | ❌ | `0x23ed7c` |
| `RecommendAdAreaView` | `-` | `setScrollBoundsEnabled:` |  | ✅ | ❌ | `0x23f078` |
| `RecommendAdAreaView` | `-` | `setScrollBarEnabled:` |  | ✅ | ❌ | `0x23f350` |
| `RecommendAdAreaView` | `-` | `webViewDidStartLoad:` |  | ✅ | ❌ | `0x23f52c` |
| `RecommendAdAreaView` | `-` | `webViewDidFinishLoad:` |  | ✅ | ❌ | `0x23f548` |
| `RecommendAdAreaView` | `-` | `webView:didFailLoadWithError:` |  | ✅ | ❌ | `0x23f808` |
| `RecommendAdAreaView` | `-` | `webView:shouldStartLoadWithRequest:navigationType:` |  | ✅ | ❌ | `0x23f9d4` |
| `RecommendAdAreaView` | `-` | `appListDidAppear` |  | ✅ | ❌ | `0x23fa28` |
| `RecommendAdAreaView` | `-` | `appListDidDisappear` |  | ✅ | ❌ | `0x23fb70` |
| `RecommendAdAreaView` | `-` | `appListFailLoadWithError:` |  | ✅ | ❌ | `0x23fcd4` |
| `RecommendAdAreaView` | `-` | `appListFailLinkWithError:` |  | ✅ | ❌ | `0x23fe44` |
| `RecommendAdAreaView` | `-` | `redirectWithRequest:` |  | ✅ | ❌ | `0x23ffa8` |
| `RecommendAdAreaView` | `-` | `openedNotice` |  | ✅ | ✅ | `0x241364` |
| `RecommendAdAreaView` | `-` | `closeNotice` |  | ✅ | ❌ | `0x241368` |
| `RecommendAdAreaView` | `-` | `openErrorNotice` |  | ✅ | ✅ | `0x2413a4` |
| `RecommendAdAreaView` | `-` | `appStoreOpenedNotice` |  | ✅ | ✅ | `0x2413a8` |
| `RecommendAdAreaView` | `-` | `appStoreCloseNotice` |  | ✅ | ❌ | `0x2413ac` |
| `RecommendAdAreaView` | `-` | `appStoreClosedNotice` |  | ✅ | ✅ | `0x2413d4` |
| `RecommendAdAreaView` | `-` | `appStoreFailLoadNoticeWithError:` |  | ✅ | ✅ | `0x2413d8` |
| `RecommendAdAreaView` | `-` | `appStoreTransitionNotice` |  | ✅ | ✅ | `0x2413dc` |
| `RecommendAdAreaView` | `-` | `dealloc` |  | ✅ | ❌ | `0x2413e0` |
| `RecommendAdAreaView` | `-` | `applilinkDelegate` | prop | ✅ | ✅ | `0x2414fc` |
| `RecommendAdAreaView` | `-` | `setApplilinkDelegate:` | prop | ✅ | ✅ | `0x24151c` |
| `RecommendAdAreaView` | `-` | `sdkDelegate` | prop | ✅ | ✅ | `0x241530` |
| `RecommendAdAreaView` | `-` | `setSdkDelegate:` | prop | ✅ | ✅ | `0x241550` |
| `RecommendAdAreaView` | `-` | `webViewStatus` | prop | ✅ | ✅ | `0x241564` |
| `RecommendAdAreaView` | `-` | `setWebViewStatus:` | prop | ✅ | ✅ | `0x241574` |
| `RecommendAdAreaView` | `-` | `adType` | prop | ✅ | ✅ | `0x241584` |
| `RecommendAdAreaView` | `-` | `setAdType:` | prop | ✅ | ✅ | `0x241594` |
| `RecommendAdAreaView` | `-` | `adModel` | prop | ✅ | ✅ | `0x2415a4` |
| `RecommendAdAreaView` | `-` | `setAdModel:` | prop | ✅ | ✅ | `0x2415b4` |
| `RecommendAdAreaView` | `-` | `adLocation` | prop | ✅ | ✅ | `0x2415c4` |
| `RecommendAdAreaView` | `-` | `setAdLocation:` | prop | ✅ | ✅ | `0x2415d4` |
| `RecommendAdAreaView` | `-` | `impressionId` | prop | ✅ | ✅ | `0x24160c` |
| `RecommendAdAreaView` | `-` | `setImpressionId:` | prop | ✅ | ✅ | `0x24161c` |
| `RecommendAdAreaView` | `-` | `requestCode` | prop | ✅ | ✅ | `0x241654` |
| `RecommendAdAreaView` | `-` | `setRequestCode:` | prop | ✅ | ✅ | `0x241664` |
| `RotateStoreProductViewController` | `-` | `initWithNibName:bundle:` |  | ✅ | ❌ | `0x2416d4` |
| `RotateStoreProductViewController` | `-` | `viewDidLoad` |  | ✅ | ❌ | `0x24174c` |
| `RotateStoreProductViewController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ❌ | `0x241788` |
| `RotateStoreProductViewController` | `-` | `shouldAutorotate` |  | ✅ | ✅ | `0x2417c4` |
| `RotateStoreProductViewController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ✅ | `0x2417cc` |
| `RotateStoreProductViewController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ✅ | `0x2417d4` |
| `RecommendAdCache` | `+` | `getAllAdStatus` |  | ✅ | ❌ | `0x2417dc` |
| `RecommendAdCache` | `+` | `getAllAdDataWithCallBack:` |  | ✅ | ❌ | `0x241c28` |
| `RecommendAdCache` | `+` | `clearAllAdData` |  | ✅ | ❌ | `0x242380` |
| `RecommendAdCache` | `+` | `getAllAdDataInfoExpire` |  | ✅ | ❌ | `0x2423d8` |
| `RecommendAdCache` | `+` | `clearAllAdDataInfoExpire` |  | ✅ | ❌ | `0x2424e0` |
| `RecommendAdCache` | `+` | `createFolder` |  | ✅ | ❌ | `0x242538` |
| `RecommendAdCache` | `+` | `delateFolder` |  | ✅ | ❌ | `0x242750` |
| `RecommendAdCache` | `+` | `clearCacheBannerImage` |  | ✅ | ❌ | `0x24280c` |
| `RecommendAdCache` | `+` | `allClearCacheBannerImage` |  | ✅ | ❌ | `0x242bbc` |
| `RecommendAdCache` | `+` | `getBannerDataWithList:max:` |  | ✅ | ❌ | `0x242c94` |
| `RecommendAdCache` | `+` | `getBannerWithUrl:` |  | ✅ | ❌ | `0x242e9c` |
| `RecommendAdCache` | `+` | `getDataWithUrl:` |  | ✅ | ❌ | `0x242f84` |
| `RecommendAdCache` | `+` | `saveData:file:` |  | ✅ | ❌ | `0x243080` |
| `RecommendAdCache` | `+` | `existFile:` |  | ✅ | ❌ | `0x24314c` |
| `RecommendAdCache` | `+` | `getContentsPath` |  | ✅ | ❌ | `0x243224` |
| `RecommendAdCache` | `+` | `getBannerCachePath` |  | ✅ | ❌ | `0x2432b0` |
| `RecommendAdCache` | `+` | `getTemplateFiles` |  | ✅ | ❌ | `0x243314` |
| `RecommendAdCache` | `+` | `getTemplateFile:` |  | ✅ | ❌ | `0x24352c` |
| `RecommendAdCache` | `+` | `saveTemplateData:path:file:` |  | ✅ | ❌ | `0x243628` |
| `RecommendAdCache` | `+` | `createHtmlWithAdModel:adLocation:verticalAlign:` |  | ✅ | ❌ | `0x243938` |
| `RecommendAdCache` | `+` | `convertHtmlWithAdType:verticalAlign:bannerList:` |  | ✅ | ❌ | `0x243d94` |
| `RecommendAdCache` | `+` | `setTargetUrl:adType:adModel:adLocation:` |  | ✅ | ❌ | `0x2441fc` |
| `RecommendAdCache` | `+` | `setAdDisplayCountWithAdId:` |  | ✅ | ❌ | `0x244860` |
| `RecommendAdCache` | `+` | `setAdDisplayCountDailyWithAdId:` |  | ✅ | ❌ | `0x2448c8` |
| `RecommendAdCache` | `+` | `setAdDisplayCountTotalWithAdId:` |  | ✅ | ❌ | `0x244df8` |
| `RecommendAdCache` | `+` | `clearAdDisplayCount` |  | ✅ | ❌ | `0x24504c` |
| `RecommendAdCache` | `+` | `setHtmlAdDataWithAdModel:adLocation:bannerList:` |  | ✅ | ❌ | `0x2450bc` |
| `RecommendAdCache` | `+` | `getHtmlAdDataWithAdModel:adLocation:` |  | ✅ | ❌ | `0x24528c` |
| `RecommendWebView` | `-` | `init` |  | ✅ | ❌ | `0x2453c8` |
| `RecommendWebView` | `-` | `initWithFrame:` |  | ✅ | ❌ | `0x24542c` |
| `RecommendWebView` | `-` | `initWithCoder:` |  | ✅ | ❌ | `0x245490` |
| `RecommendWebView` | `-` | `setInitParam` |  | ✅ | ❌ | `0x2454f4` |
| `RecommendWebView` | `-` | `removeFromSuperview` |  | ✅ | ❌ | `0x245598` |
| `RecommendWebView` | `-` | `loadRequestWithAdModel:adLocation:verticalAlign:requestCode:delegate:` |  | ✅ | ❌ | `0x2455f0` |
| `RecommendWebView` | `-` | `loadRequestWithAdModel:adLocation:verticalAlign:delegate:` |  | ✅ | ❌ | `0x2456f8` |
| `RecommendWebView` | `-` | `hiddenIndicator` |  | ✅ | ❌ | `0x246028` |
| `RecommendWebView` | `-` | `closeAdArea` |  | ✅ | ❌ | `0x24607c` |
| `RecommendWebView` | `-` | `setScrollEnabled:` |  | ✅ | ❌ | `0x246120` |
| `RecommendWebView` | `-` | `appListDidStart` |  | ✅ | ❌ | `0x246158` |
| `RecommendWebView` | `-` | `appListDidAppear` |  | ✅ | ❌ | `0x2461c0` |
| `RecommendWebView` | `-` | `appListDidDisappear` |  | ✅ | ❌ | `0x24628c` |
| `RecommendWebView` | `-` | `appListFailLoadWithError:` |  | ✅ | ❌ | `0x246374` |
| `RecommendWebView` | `-` | `appListFailLinkWithError:` |  | ✅ | ❌ | `0x24647c` |
| `RecommendWebView` | `-` | `dealloc` |  | ✅ | ❌ | `0x246500` |
| `RecommendWebView` | `-` | `indicator` | prop | ✅ | ✅ | `0x246634` |
| `RecommendWebView` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x246644` |
| `RecommendWebView` | `-` | `webView` | prop | ✅ | ✅ | `0x24667c` |
| `RecommendWebView` | `-` | `setWebView:` | prop | ✅ | ✅ | `0x24668c` |
| `RecommendWebView` | `-` | `adAreaWebView` | prop | ✅ | ✅ | `0x2466c4` |
| `RecommendWebView` | `-` | `setAdAreaWebView:` | prop | ✅ | ✅ | `0x2466d4` |
| `RecommendWebView` | `-` | `applilinkDelegate` | prop | ✅ | ✅ | `0x24670c` |
| `RecommendWebView` | `-` | `setApplilinkDelegate:` | prop | ✅ | ✅ | `0x24672c` |
| `RecommendWebView` | `-` | `applilinkParams` | prop | ✅ | ✅ | `0x246740` |
| `RecommendWebView` | `-` | `setApplilinkParams:` | prop | ✅ | ✅ | `0x246750` |
| `RecommendWebView` | `-` | `webViewBounces` | prop | ✅ | ✅ | `0x24676c` |
| `RecommendWebView` | `-` | `setWebViewBounces:` | prop | ✅ | ✅ | `0x24677c` |
| `RecommendFullScreenController` | `-` | `init` |  | ✅ | ❌ | `0x246804` |
| `RecommendFullScreenController` | `-` | `loadView` |  | ✅ | ❌ | `0x246840` |
| `RecommendFullScreenController` | `-` | `didReceiveMemoryWarning` |  | ✅ | ❌ | `0x246934` |
| `RecommendFullScreenController` | `-` | `openAdViewWithAdModel:adLocation:verticalAlign:applilinkParams:delegate:closeDelegate:` |  | ✅ | ❌ | `0x246970` |
| `RecommendFullScreenController` | `-` | `shouldAutorotateToInterfaceOrientation:` |  | ✅ | ❌ | `0x246efc` |
| `RecommendFullScreenController` | `-` | `shouldAutorotate` |  | ✅ | ✅ | `0x246fa4` |
| `RecommendFullScreenController` | `-` | `supportedInterfaceOrientations` |  | ✅ | ✅ | `0x246fac` |
| `RecommendFullScreenController` | `-` | `setViewSize` |  | ✅ | ❌ | `0x246fb4` |
| `RecommendFullScreenController` | `-` | `rotateWebViewWithDuration:` |  | ✅ | ❌ | `0x247674` |
| `RecommendFullScreenController` | `-` | `willAnimateRotationToInterfaceOrientation:duration:` |  | ✅ | ✅ | `0x247a90` |
| `RecommendFullScreenController` | `-` | `webViewDidStartLoad` |  | ✅ | ❌ | `0x247aa0` |
| `RecommendFullScreenController` | `-` | `appListDidAppear` |  | ✅ | ❌ | `0x247bc0` |
| `RecommendFullScreenController` | `-` | `appListDidDisappear` |  | ✅ | ✅ | `0x247d90` |
| `RecommendFullScreenController` | `-` | `appListFailLoadWithError:` |  | ✅ | ❌ | `0x247da0` |
| `RecommendFullScreenController` | `-` | `appListFailLinkWithError:` |  | ✅ | ❌ | `0x247e50` |
| `RecommendFullScreenController` | `-` | `openedNotice` |  | ✅ | ✅ | `0x247ed4` |
| `RecommendFullScreenController` | `-` | `closeNotice` |  | ✅ | ✅ | `0x247ee4` |
| `RecommendFullScreenController` | `-` | `failOpenNoticeWithError:` |  | ✅ | ❌ | `0x247ef4` |
| `RecommendFullScreenController` | `-` | `failLinkNoticeWithError:` |  | ✅ | ❌ | `0x247f8c` |
| `RecommendFullScreenController` | `-` | `closeShadeView` |  | ✅ | ❌ | `0x248010` |
| `RecommendFullScreenController` | `-` | `releaseInterstitialView` |  | ✅ | ❌ | `0x2480a8` |
| `RecommendFullScreenController` | `-` | `dealloc` |  | ✅ | ❌ | `0x248164` |
| `RecommendFullScreenController` | `-` | `isVisible` | prop | ✅ | ✅ | `0x248250` |
| `RecommendFullScreenController` | `-` | `setIsVisible:` | prop | ✅ | ✅ | `0x248260` |
| `RecommendFullScreenController` | `-` | `baseView` | prop | ✅ | ✅ | `0x248270` |
| `RecommendFullScreenController` | `-` | `setBaseView:` | prop | ✅ | ✅ | `0x248280` |
| `RecommendFullScreenController` | `-` | `shadeView` | prop | ✅ | ✅ | `0x2482b8` |
| `RecommendFullScreenController` | `-` | `setShadeView:` | prop | ✅ | ✅ | `0x2482c8` |
| `RecommendFullScreenController` | `-` | `indicator` | prop | ✅ | ✅ | `0x248300` |
| `RecommendFullScreenController` | `-` | `setIndicator:` | prop | ✅ | ✅ | `0x248310` |
| `RecommendFullScreenController` | `-` | `applilinkParams` | prop | ✅ | ✅ | `0x248348` |
| `RecommendFullScreenController` | `-` | `setApplilinkParams:` | prop | ✅ | ✅ | `0x248358` |
| `RecommendFullScreenController` | `-` | `applilinkDelegate` | prop | ✅ | ✅ | `0x248374` |
| `RecommendFullScreenController` | `-` | `setApplilinkDelegate:` | prop | ✅ | ✅ | `0x248394` |
| `RecommendFullScreenController` | `-` | `applilinkFullViewDelegate` | prop | ✅ | ✅ | `0x2483a8` |
| `RecommendFullScreenController` | `-` | `setApplilinkFullViewDelegate:` | prop | ✅ | ✅ | `0x2483c8` |
| `ApplilinkNetwork` | `+` | `initializeWithAppliId:env:callback:` |  | ✅ | ❌ | `0x248464` |
| `ApplilinkNetwork` | `+` | `resume` |  | ✅ | ✅ | `0x2484d8` |
| `ApplilinkNetwork` | `+` | `setUserId:` |  | ✅ | ✅ | `0x2484f0` |
| `ApplilinkNetwork` | `+` | `setNavigationBarCommonAppearance:` |  | ✅ | ✅ | `0x248508` |
| `ApplilinkNetwork` | `+` | `setPriorityDeviceLanguages:` |  | ✅ | ✅ | `0x248520` |
| `ApplilinkNetwork` | `+` | `setIndicatorColor:` |  | ✅ | ✅ | `0x248538` |
| `ApplilinkNetwork` | `+` | `unusedInStore` |  | ✅ | ✅ | `0x248550` |
| `ApplilinkNetwork` | `+` | `buildUnderXcode6` |  | ✅ | ✅ | `0x248568` |
| `ApplilinkNetwork` | `+` | `appliId` |  | ✅ | ✅ | `0x248580` |
| `ApplilinkNetwork` | `+` | `version` |  | ✅ | ✅ | `0x248598` |
| `ApplilinkNetwork` | `+` | `versionDev` |  | ✅ | ✅ | `0x2485b0` |
| `ApplilinkNetwork` | `+` | `isSupportediOSVersion` |  | ✅ | ✅ | `0x2485c8` |
| `ApplilinkNetwork` | `+` | `currentUdid` |  | ✅ | ✅ | `0x2485e0` |
| `ApplilinkNetwork` | `+` | `rotateWithInterfaceOrientation:duration:` |  | ✅ | ❌ | `0x2485f8` |
