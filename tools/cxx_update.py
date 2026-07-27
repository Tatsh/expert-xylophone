#!/usr/bin/env python3
"""Regenerate CXX_FUNCTIONS.md: apply status/signature updates, re-sort, recount.

After regenerating, an audit verifies that every entry marked done actually has a reconstructed
definition in the source tree (a matching ``@ghidraAddress`` tag) and that the reported signature is
not a leftover synthesized placeholder. Pass ``--audit-only`` to run just the audit.
"""
import glob
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

PATH = 'CXX_FUNCTIONS.md'
# The Ghidra MCP bridge HTTP endpoint. When reachable, each row's name/signature/length is refreshed
# from the live program so Ghidra renames (for example the uniform CompilerGeneratedNoOp_* stubs)
# propagate into the checklist automatically, without hand-maintaining address pins. When it is
# unreachable (offline regen), the row keeps the name/signature already in the table.
GHIDRA_HTTP = os.environ.get('GHIDRA_MCP_HTTP', 'http://127.0.0.1:8089')
GHIDRA_PROGRAM = os.environ.get('GHIDRA_MCP_PROGRAM', 'rb458')
# Unicode marks render on GitHub Pages (Jekyll) where GitHub emoji shortcodes
# (:white_check_mark:/:x:) do not. Legacy shortcode rows are normalised on parse.
DONE = '✅'  # white heavy check mark
NOT = '❌'  # cross mark
_LEGACY_STATUS = {':white_check_mark:': DONE, ':x:': NOT}
# The Mach-O image base: table addresses are 0x1_0000_0000-relative, but source @ghidraAddress tags
# are usually written in the image-base-stripped short form.
IMAGE_BASE = 0x100000000
# The source roots whose @ghidraAddress tags count as a reconstruction's definition.
SOURCE_GLOBS = ('Project/**/*.mm', 'Project/**/*.cpp', 'Project/**/*.h', 'Project/**/*.m',
                'Project/**/*.c')

# address (as in the table, e.g. 0x10005a174) -> new signature. Presence marks it done.
UPDATES = {
    '0x100021d80': 'void neGLESRenderer::SetGlEnableState(unsigned int nState, bool bEnable)',
    '0x100021e14': 'void neGLESRenderer::SetGlClientState(unsigned int nState, bool bEnable)',
    '0x100021460': 'void neGLESRenderer::SetCurrentPaletteMatrix(int nState)',
    '0x100021c98': 'void neGLESRenderer::SetBlendFunc(int nSrcFactor, int nDstFactor)',
    '0x100021250': 'void neGLESRenderer::SetMatrixMode(int nMode, const float * pMatrix)',
    '0x10002faa8': 'void ne::C_SPRITE_INSTANCING_2D::Render()',
    '0x1000307f0': 'ne::C_TEXTURE * ne::C_SPRITE_INSTANCING_2D::GetBoundTexture() const',
    '0x100030dc0': 'void ne::C_SPRITE_INSTANCING_2D::RenderWorldSpace()',
    '0x10004d350': 'caSource::caSource()',
    '0x10004d39c': 'caSource::~caSource()',
    '0x10004d3d0': 'int caSource::LoadFromPath(const char * szPath, bool bLoop)',
    '0x10004d450': 'int caSource::LoadFromUrl(CFURLRef url, bool bLoop)',
    '0x10004d4c4': 'int caSource::ReadAudioFormat(ExtAudioFileRef hAudioFile, AudioStreamBasicDescription * pAsbd)',
    '0x10004d58c': 'int caSource::ReadAudioPcmData(ExtAudioFileRef hAudioFile, AudioStreamBasicDescription * pAsbd)',
    '0x10004d698': 'int caSource::ReadRingBuffer(void * pDst, int nCount, int * pTotalRead, int * pReadPos)',
    '0x10004b084': 'unsigned int caCAMixer::EnqueueVoiceBuffer(caSource * pSource, int nBus, int nVolume)',
    '0x10004b174': 'void caCAMixer::InstallVoiceRenderCallback(int nBus)',
    '0x10004b1e8': 'bool caCAMixer::ApplyVoicePanParam(int nVolume, int nBus)',
    '0x10004b9d4': 'unsigned int caPlayerMgr::PlaySoundOnVoice(int resourceId, int busId, int volume)',
    '0x10004bbd4': 'unsigned int caPlayerMgr::FindOrGrowFreeSlot()',
    '0x10004b6c4': 'unsigned int caPlayerMgr::RegisterSource(caSource * pSource)',
    '0x10004b62c': 'int caPlayerMgr::CreateAndLoadSound(const char * szPath, bool bLoop)',
    '0x10004ba1c': 'unsigned int caPlayerMgr::PlaySoundForKey(NSString * callName, int volume)',
    '0x10004bac0': 'unsigned int caPlayerMgr::PlaySoundForKeyOnBus(NSString * callName, int busId, int volume)',
    '0x10004b718': 'int caPlayerMgr::LoadAndCacheSoundForKey(const char * szPath, NSString * callName, bool bLoop)',
    '0x10004b870': 'int caPlayerMgr::FreeSoundDataByIndex(int index)',
    '0x10004b8cc': 'int caPlayerMgr::FreeSoundForKey(NSString * callName)',
    '0x10004bbcc': 'void caPlayerMgr::SetMasterVoiceParameter(int volume)',
    '0x10004b580': 'void caPlayerMgr::InitializeAudioContext(int channelCount)',
    '0x10004b4a8': 'void caPlayerMgr::DestroyAudioContext()',
    '0x10004b57c': 'void caPlayerMgr::DestroyAudioContextWrapper()',
    '0x10004b3b0': 'void caCAMixer::ClearVoicesUsingBuffer(caSource * pSource)',
    '0x10004d368': 'int caSource::FreeBuffer()',
    '0x10004afbc': 'void caCAMixer::SetAllVolume(int nVolume)',
    '0x10004ac94': 'bool caCAMixer::GraphSetup(int nVoiceCount)',
    '0x10004affc': 'void caCAMixer::Terminate()',
    '0x1001cc4ac': 'SoundEffectManager::SoundEffectManager()',
    '0x1001cc548': 'void SoundEffectManager::LoadThemedSoundEffect(int theme, int slot)',
    '0x1001cc75c': 'void SoundEffectManager::LoadAll()',
    '0x1001ccc44': 'bool SoundEffectManager::LoadThemedVoiceData(int voiceID)',
    '0x1001cceac': 'bool SoundEffectManager::PlayThemedVoice(int voiceID)',
    '0x100029ff4': 'void ComputeScreenPickRay(const S_VECTOR2 * pScreen, S_VECTOR3 * pRayOrigin, S_VECTOR3 * pRayDir)',
    '0x10001966c': 'void MakeTranslationMatrix(float * pOutMatrix, const float * pTranslation)',
    '0x100123838': 'PartsDataRecord * LimelightResultLayer::GetPartsData(unsigned int nIndex) const',
    '0x10012ac64': 'void LimelightResultLayer::AppendSpriteToSlot(const S_VECTOR2 & position, const S_VECTOR2 & anchor, const S_VECTOR2 & size, const S_VECTOR2 & uvOrigin, const S_VECTOR2 & uvSize, float flRotation, const S_VECTOR2 & scale, unsigned int nSlot, unsigned int nIntensity, unsigned int nAlpha)',
    '0x100126ab4': 'void LimelightResultLayer::EmitPartSprite(float flRotation, float flScaleX, float flScaleY, unsigned int nSlot, unsigned int nPartId, const S_VECTOR2 & position, unsigned int nAlpha, int bShadowPass)',
    '0x100126b78': 'void LimelightResultLayer::EmitTexturedPart(unsigned long nSlot, const S_VECTOR2 & position, const S_VECTOR2 & size, unsigned int nAlpha)',
    '0x100126c34': 'void LimelightResultLayer::EmitAutoUvPart(unsigned long nSlot, const S_VECTOR2 & position, unsigned int nBaseAlpha)',
    '0x10012705c': 'void LimelightResultLayer::RenderDigits(int nValue, const S_VECTOR2 & position, unsigned int nAlpha)',
    '0x100126cf8': 'void LimelightResultLayer::RenderNumber(float flSpacing, int nValue, int nMaxDigits, const S_VECTOR2 & position, unsigned int nBasePartId, unsigned int bPaired, int bPadZeros, unsigned int nAlpha)',
    '0x1001274b0': 'void LimelightResultLayer::RenderPercentValue(int nValue, const S_VECTOR2 & position, unsigned int nAlpha)',
    '0x1001271f4': 'void LimelightResultLayer::RenderFraction(int nNumerator, int nDenominator, const S_VECTOR2 & position, unsigned int nAlpha)',
    '0x100127680': 'void LimelightResultLayer::RenderRatingValue(float flValue, const S_VECTOR2 & position, unsigned int nAlpha)',
    '0x10012af38': 'float FloatTween::Advance(float flDeltaTime)',
    '0x1001240a8': 'void LimelightResultLayer::UpdateBonusSoundCueTimer(float flDeltaTime)',
    '0x100109e04': 'void PlayFieldLayerBase::RefreshThema()',
    '0x10002f638': 'void neSpriteInstancing::tempAssert(bool bCondition)',
    '0x100135e84': 'int NoteModel::IsSideFlipped() const',
    '0x1001360a8': 'float NoteModel::GetVirtualBoundY(int nBand)',
    '0x100176e18': 'ExplosionEffectLayer::ExplosionEffectLayer()',
    '0x100176ed0': 'ExplosionEffectLayer * ExplosionEffectLayer::shared()',
    '0x100176f20': 'void ExplosionEffectLayer::InitializeSprites()',
    '0x100177138': 'void ExplosionEffectLayer::CreateExplosionEffect(unsigned int nColor, int nJudge, float flPosX, float flPosY)',
    '0x100176fb8': 'void ExplosionEffectLayer::SetEffectType(unsigned int nColor, int nType)',
    '0x100177130': 'void ExplosionEffectLayer::SetEffectSize(float flSize)',
    '0x100189294': 'NoteResultLayer::NoteResultLayer()',
    '0x1001892fc': 'NoteResultLayer * NoteResultLayer::shared()',
    '0x1001895e8': 'void NoteResultLayer::Create(unsigned int nPos, int nJudge, int nNumber)',
    '0x1001493b0': 'void ScoreTracker::AddScore(int nPlayer, int nPosX, int nPosY, int nJudge, int nBonusFlag, int nMode)',
    '0x100184d48': 'void JudgeEffectLayer::TriggerJudgeEffect(unsigned int nLane, unsigned int nScore, unsigned int nJudgeType)',
    '0x100149710': 'void ScoreTracker::SetJudgeScore0(unsigned int nSide)',
    '0x10014976c': 'void ScoreTracker::SetJudgeScore2(unsigned int nSide)',
    '0x1001497c8': 'void ScoreTracker::SetJudgeScore3(unsigned int nSide)',
    '0x10009b2e4': 'void FullComboColetteLayer::CreateFullComboColette(unsigned int nColor)',
    '0x10010f3f4': 'void FullComboClassicLayer::CreateFullComboClassic(unsigned int nColor)',
    '0x100122a44': 'void FullComboLimelightLayer::CreateFullComboLimelight(unsigned int nColor)',
    '0x1000307ac': 'void ne::C_SPRITE_INSTANCING_2D::SetRefCountedMember(ne::C_TEXTURE * pTexture)',
    '0x100031828': 'void ne::C_SPRITE_INSTANCING_2D::SetTexParam(int nIndex, int nValue)',
    '0x100066f6c': 'void ne::C_SPRITE_INSTANCING_2D::SetSpritePosition(int nIndex, const S_VECTOR2 & position)',
    '0x100067020': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteSize(int nIndex, const S_VECTOR2 & size)',
    '0x100066fc8': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteAnchor(int nIndex, const S_VECTOR2 & anchor)',
    '0x100067078': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteUvOrigin(int nIndex, const S_VECTOR2 & uvOrigin)',
    '0x1000670d0': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteUvSize(int nIndex, const S_VECTOR2 & uvSize)',
    '0x100067128': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteRotation(int nIndex, float flRotation)',
    '0x100067174': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteScale(int nIndex, float flScaleX, float flScaleY)',
    '0x1000671cc': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteColor(int nIndex, unsigned int nRed, unsigned int nGreen, unsigned int nBlue, unsigned int nAlpha)',
    '0x100114c80': 'void ResultWindowClassicLayer::getPosition_Phone(int nIndex, S_VECTOR2 * pOutPosition) const',
    '0x100116808': 'void ResultWindowClassicLayer::AppendSpriteToSlot(const S_VECTOR2 & position, const S_VECTOR2 & anchor, const S_VECTOR2 & size, const S_VECTOR2 & uvOrigin, const S_VECTOR2 & uvSize, float flRotation, const S_VECTOR2 & scale, unsigned int nSlot, unsigned int nIntensity, unsigned int nAlpha)',
    '0x100115864': 'void ResultWindowClassicLayer::EmitPartSprite(float flRotation, float flScaleX, float flScaleY, unsigned int nSlot, unsigned int nPartId, const S_VECTOR2 & position, unsigned int nAlpha, int bShadowPass)',
    '0x100115514': 'void ResultWindowClassicLayer::RenderDigitSequence(int nValue, int nDigitCount, const S_VECTOR2 * pOrigin, unsigned int nGlyphBase, unsigned int bLeadingZero, int bPadRight, unsigned int nAlpha, float flSpacing)',
    '0x100115928': 'void ResultWindowClassicLayer::RenderScoreDigitsCompact(int nValue, const S_VECTOR2 & position, unsigned int nAlpha)',
    '0x100115ac0': 'void ResultWindowClassicLayer::RenderScoreDigitsWithDot(int nIntegerValue, int nFractionValue, const S_VECTOR2 & position, unsigned int nAlpha)',
    '0x100115d7c': 'void ResultWindowClassicLayer::RenderScorePaddedWithDot(int nValue, const S_VECTOR2 & position, unsigned int nAlpha)',
    '0x100115f4c': 'void ResultWindowClassicLayer::RenderNumberFieldWithPad(int nValue, int nDigitCount, const S_VECTOR2 & position, const S_VECTOR2 & offset, unsigned int nGlyphBase, unsigned int bLeadingZero, int bPadRight, unsigned int nAlpha, float flSpacing)',
    '0x1001161cc': 'void ResultWindowClassicLayer::DispatchGlyphSpriteFromTable(unsigned int nSlot, unsigned int nCharCode, const S_VECTOR2 * pPosition, unsigned int nAlpha, int bDimmed, float flRotation, float flScaleX, float flScaleY)',
    '0x1001164e8': 'void ResultWindowClassicLayer::RenderDecimalWithDotGlyph(int nValue, const S_VECTOR2 * pPosition, unsigned int nAlpha)',
    '0x100116258': 'void ResultWindowClassicLayer::RenderRatioDigits(int nNumerator, int nDenominator, const S_VECTOR2 * pPosition, unsigned int nAlpha)',
    '0x1001166a8': 'void ResultWindowClassicLayer::RenderDigitRowSpacedByWidth(int nValue, const S_VECTOR2 * pPosition, unsigned int nAlpha)',
    '0x100116b94': 'void ResultWindowClassicLayer::RenderTableSpriteAtIndex(unsigned int nSlot, unsigned int nCharCode, const S_VECTOR2 & position, const S_VECTOR2 & offset, unsigned int nAlpha, int bShadowPass, float flRotation, float flScaleX, float flScaleY)',
    '0x100116cc0': 'void ResultWindowClassicLayer::RenderTableSpriteWithOffset(unsigned int nSlot, unsigned int nCharCode, int nPositionIndex, const S_VECTOR2 & offset, unsigned int nAlpha, int bShadowPass, float flRotation, float flScaleX, float flScaleY)',
    '0x100116c2c': 'void ResultWindowClassicLayer::RenderSpriteWithPositionOffset(unsigned int nSlot, unsigned int nCharCode, int nPositionIndex, const S_VECTOR2 & offset, unsigned int nAlpha, float flScaleX)',
    '0x100114e18': 'const PhoneLayoutRecord * ResultWindowClassicLayer::getSeparator_Phone(int nIndex)',
    '0x100114e9c': 'void ResultWindowClassicLayer::getPositionByState_Phone(int nIndex, PhoneLayoutRect * pOutRect)',
    '0x100115008': 'void ResultWindowClassicLayer::getCenterPosition_Phone(PhoneLayoutRect * pOutRect)',
    '0x100116950': 'void ResultWindowClassicLayer::BlitInstancerTextureSlot(unsigned int nSlot, const S_VECTOR2 & position, const S_VECTOR2 & size, unsigned int nAlpha)',
    '0x100116a0c': 'void ResultWindowClassicLayer::RenderSpriteInstancerSlotScaled(unsigned int nSlot, const S_VECTOR2 & position, unsigned int nScale)',
    '0x100116ad0': 'void ResultWindowClassicLayer::RenderSpriteInstancerSlotHalfScale(unsigned int nSlot, const S_VECTOR2 & position, unsigned int nAlpha, unsigned int nIntensity)',
    '0x100116dc0': 'void ResultWindowClassicLayer::RenderGlyphAtSeparator(unsigned int nSlot, int nSepIndex, unsigned int nCharCode, const S_VECTOR2 & offset, unsigned int nAlpha)',
    '0x100115348': 'void ResultWindowClassicLayer::SetInstancerTextureAndRefreshSlots(unsigned int nSlot, ne::C_TEXTURE * pTexture)',
    '0x10009b118': 'FullComboColetteLayer::FullComboColetteLayer()',
    '0x100122870': 'FullComboLimelightLayer::FullComboLimelightLayer()',
    '0x100079df0': 'void ResultWindowColetteLayer::RenderDimmableGlyphFromTable(int nSlot, int nPartId, const S_VECTOR2 & position, unsigned int nAlpha, int bDimmed, float flRotation, float flScaleX, float flScaleY)',
    '0x1001299d8': 'void LimelightResultLayer::RenderPhoneResultSpriteById(unsigned int nSlot, unsigned int nPartId, const S_VECTOR2 & position, unsigned int nAlpha, int bDimmed, float flRotation, float flScaleX, float flScaleY)',
    '0x100076a98': 'void ResultWindowColetteLayer::RenderPartSpriteWithAlpha(int nSlot, int nPartId, const S_VECTOR2 & position, unsigned int nAlpha, int bShadowPass, float flRotation, float flScaleX, float flScaleY)',
    '0x10007ada0': 'void ResultWindowColetteLayer::appendSpriteToSlotRgba(int nSlot, unsigned int nRed, unsigned int nGreen, unsigned int nBlue, unsigned int nAlpha, const S_VECTOR2 & position, const S_VECTOR2 & anchor, const S_VECTOR2 & size, const S_VECTOR2 & uvOrigin, const S_VECTOR2 & uvSize, float flRotation, const S_VECTOR2 & scale)',
    '0x1000769cc': 'void ResultWindowColetteLayer::RenderPartSpriteByIndex(int nSlot, int nPartId, const S_VECTOR2 & position, unsigned int nAlpha, float flRotation, float flScaleX, float flScaleY, float flRed, float flGreen, float flBlue)',
    '0x100076c1c': 'void ResultWindowColetteLayer::renderSpriteInstanceScaled(int nSlot, const S_VECTOR2 & position, unsigned int nScale)',
    '0x100074018': 'void ResultWindowColetteLayer::applySpriteInstancerTexture(int nSlot, ne::C_TEXTURE * pTexture)',
    '0x100079e7c': 'void ResultWindowColetteLayer::blitSpriteInstanceHalfScale(int nSlot, const S_VECTOR2 & position, unsigned int nScale)',
    '0x100123940': 'void LimelightResultLayer::getPosition_Phone(int nIndex, S_VECTOR2 * pOutPosition) const',
    '0x10012a01c': 'void LimelightResultLayer::RenderPhonePartWithOffset(unsigned int nSlot, unsigned int nCharCode, int nPositionIndex, const S_VECTOR2 & offset, unsigned int nAlpha, int bShadowPass, float flRotation, float flScaleX, float flScaleY)',
    '0x100129c34': 'void LimelightResultLayer::EmitPhoneHalfScaleTexturedPart(unsigned int nSlot, const S_VECTOR2 & position, unsigned int nScale, unsigned int nIntensity)',
    '0x1001238d0': 'PartsDataRecord * LimelightResultLayer::getPartsData_Phone(int nIndex)',
    '0x10012a11c': 'void LimelightResultLayer::RenderPhoneNumberDigitsRow(int nValue, const S_VECTOR2 * pPosition, unsigned int nAlpha)',
    '0x100123ad8': 'const PhoneLayoutRecord * LimelightResultLayer::getSeparator_Phone(int nIndex) const',
    '0x100123cc8': 'void LimelightResultLayer::getCenterPosition_Phone(PhoneLayoutRect * pOutRect) const',
    '0x100129f84': 'void LimelightResultLayer::EmitPhonePartWithOffset(unsigned int nSlot, unsigned int nCharCode, const S_VECTOR2 & position, const S_VECTOR2 & offset, unsigned int nAlpha, int bShadowPass, float flRotation, float flScaleX, float flScaleY)',
    '0x100073e50': 'void ResultWindowColetteLayer::getCenterPosition_Phone(PhoneLayoutRect * pOutRect) const',
    '0x1001cd48c': 'void ShotSoundManager::SetPendingRetrigger(int nSlot, int nPriority)',
    '0x1001cbe04': 'LevelTables::LevelTables()',
    '0x1001cbec8': 'LevelTables * LevelTables::GetInstance()',
    '0x1001cc460': 'bool LevelTables::CheckThresholdReached(int category, int itemID)',
    '0x1001cc410': 'unsigned int LevelTables::GetLevelExpThreshold(int nLevel)',
    '0x1001cc438': 'const LevelUnlockEntry * LevelTables::GetLevelUnlockEntry(int nLevel)',
    '0x1001cc3b4': 'int LevelTables::ComputeLevelExpStep(float flBase, int nStep, int bAddHalf, int bAddOffset)',
    '0x1001cc138': 'NSData * LevelTables::MakeLevelCustomizeHash(int nLevel, int nExp)',
    '0x1001cbf18': 'bool LevelTables::LoadPlayerLevelData(int * pOutLevelExp)',
    '0x1001cc1dc': 'bool LevelTables::SavePlayerLevelData(const int * pLevelExp)',
    '0x100136afc': 'void InitNoteLaneTable()',
    '0x100136a38': 'float GetNoteLaneFraction(int nKind, int nLane)',
    '0x1001352b8': 'float NoteModel::GetLaneX() const',
    '0x100133a24': 'int NoteModel::GetSide() const',
    '0x1001336c0': 'int NoteModel::GetType() const',
    '0x10013183c': 'RbffNoteRecord * rb::CMusicSheet2::GetNoteRecordByIndex(int nIndex)',
    '0x100131294': 'int rb::CMusicSheet2::CalculateChartTiming()',
    '0x10012f604': 'SheetPathNode * rb::CMusicSheet2::GetSheetPathNode(int nIndex)',
    '0x1001316b4': 'float rb::CMusicSheet2::GetFirstPathSpeed()',
    '0x1001309a8': 'void rb::CMusicSheet2::ResolveNoteScrollSpeeds()',
    '0x100130d64': 'bool rb::CMusicSheet2::CheckNoteNearTime(int nTime, int nTarget)',
    '0x10004b468': 'caPlayerMgr::~caPlayerMgr()',
    '0x10007b350': 'float FloatTween::Advance(float flDeltaTime)',
    '0x100021408': 'void neGLESRenderer::SetViewport(int nX, int nY, int nWidth, int nHeight)',
    '0x10013490c': 'int NoteModel::GetStartTime() const',
    '0x10013353c': 'float NoteModel::GetHitTime() const',
    '0x10017710c': 'void ExplosionEffectLayer::SetPlayColorAlpha(float flAlpha, int nLane)',
    '0x100074238': 'void ResultWindowColetteLayer::UpdateBonusSoundCueTimer(float flDeltaTime)',
    '0x100030898': 'unsigned int C_SPRITE_INSTANCING_2D::GetColorRed(int nIndex) const',
    '0x1000308e4': 'unsigned int C_SPRITE_INSTANCING_2D::GetColorGreen(int nIndex) const',
    '0x100030930': 'unsigned int C_SPRITE_INSTANCING_2D::GetColorBlue(int nIndex) const',
    '0x10003084c': 'unsigned int C_SPRITE_INSTANCING_2D::GetColorAlpha(int nIndex) const',
    '0x1000307f8': 'void C_SPRITE_INSTANCING_2D::SetTexParam(int nIndex, int nValue)',
    '0x1000283b4': 'void ne::C_DRAW_POLYGON_2D::SetUV(int nIndex, float flU, float flV)',
    '0x1000283ac': 'void ne::C_DRAW_POLYGON_2D::SetUVFromVec(int nIndex, const S_VECTOR2 * pUv)',
    '0x10002824c': 'void ne::C_DRAW_POLYGON_2D::SetTexture(ne::C_TEXTURE * pTexture)',
    '0x1000284f8': 'void ne::C_DRAW_POLYGON_2D::SetVertexAlpha(int nIndex, unsigned char nAlpha)',
    '0x100027440': 'ne::C_DRAW_POLYGON_2D::~C_DRAW_POLYGON_2D()',
    '0x1000286c0': 'ne::C_DRAW_POLYGON_3D::~C_DRAW_POLYGON_3D()',
    '0x10002f968': 'ne::C_SPRITE_INSTANCING_2D::~C_SPRITE_INSTANCING_2D()',
    # The deleting-destructor (D0) variants share the destructor reconstruction; show the same
    # ne::-qualified destructor signature as their complete (D1) counterparts above.
    '0x100027530': 'ne::C_DRAW_POLYGON_2D::~C_DRAW_POLYGON_2D()',
    '0x1000287b0': 'ne::C_DRAW_POLYGON_3D::~C_DRAW_POLYGON_3D()',
    '0x10002fa70': 'ne::C_SPRITE_INSTANCING_2D::~C_SPRITE_INSTANCING_2D()',
    '0x1001cd538': 'void ShotSoundManager::UpdateRetriggerTimer(float flDeltaTime)',
    '0x10007aa54': 'void ResultWindowColetteLayer::RenderAnchoredGlyphWithAlpha(int nSlot, int nCharCode, int nPositionIndex, const S_VECTOR2 & offset, unsigned int nAlpha, int bShadowPass, float flRotation, float flScaleX, float flScaleY)',
    '0x1001ccfac': 'void ShotSoundManager::LoadSlotVariants(int slot)',
    '0x10004b998': 'unsigned int caPlayerMgr::PlaySoundByIndex(int index, int volume)',
    '0x10004b238': 'unsigned int caCAMixer::FindFreeVoiceAndEnqueue(caSource * pSource, int nVolume)',
    '0x10004b3e8': 'OSStatus RenderVoiceAudioCallback(void * pRefCon, AudioUnitRenderActionFlags * pActionFlags, const AudioTimeStamp * pTimeStamp, UInt32 nBusNumber, UInt32 nFrames, AudioBufferList * pData)',
    '0x10004ac40': 'unsigned long caVoice::FillPcm(void * pDst, int nCount)',
    '0x10004b61c': 'void caPlayerMgr::StartAudioGraph()',
    '0x10004b60c': 'void caPlayerMgr::StopAudioGraph()',
    '0x10004af6c': 'void caCAMixer::Start()',
    '0x10004afc4': 'void caCAMixer::Stop()',
    '0x10004acd0': 'bool caCAMixer::BuildAudioUnitGraph()',
    '0x10004adb4': 'bool caCAMixer::ConfigureAudioUnitGraph(int nVoiceCount)',
    '0x10004b28c': 'unsigned int caCAMixer::StartVoice(unsigned int hVoice)',
    '0x10004b2e4': 'unsigned int caCAMixer::StopVoice(unsigned int hVoice)',
    '0x10004b32c': 'unsigned int caCAMixer::PauseVoice(unsigned int hVoice)',
    '0x10004b374': 'int caCAMixer::GetVoiceState(unsigned int hVoice)',
    '0x10004b42c': 'unsigned int caCAMixer::StopAndClearVoice(unsigned int hVoice)',
    '0x10004bb6c': 'void caPlayerMgr::ResumeVoiceByHandle(unsigned int handle)',
    '0x10004bb9c': 'void caPlayerMgr::PauseVoiceByHandle(unsigned int handle)',
    '0x10004bb84': 'void caPlayerMgr::StopVoiceByHandle(unsigned int handle)',
    '0x10004bcac': 'void caPlayerMgr::ReleaseVoiceByHandle(unsigned int handle)',
    '0x10004bbb4': 'int caPlayerMgr::GetVoiceStateByHandle(unsigned int handle)',
    '0x100021484': 'void neGLESRenderer::DeleteBuffer(unsigned int dwBuffer)',
    '0x100021a68': 'void neGLESRenderer::DeleteTexture(unsigned int dwHandle)',
    '0x10002152c': 'void neGLESRenderer::UploadArrayBufferData(const void * pData, unsigned int nSize, int nUsage)',
    '0x100021a30': 'void neGLESRenderer::UploadIndexBufferData(const void * pData, unsigned int nSize, int nUsage)',
    '0x100021ab4': 'void neGLESRenderer::BindTexture2d(unsigned int dwHandle)',
    '0x100021ae8': 'void neGLESRenderer::SetTextureParameter(int nParameter, int nValue)',
    '0x100021510': 'void neGLESRenderer::BindArrayBuffer(unsigned int dwBuffer)',
    '0x100021a14': 'void neGLESRenderer::BindIndexBuffer(unsigned int dwBuffer)',
    '0x100021634': 'void neGLESRenderer::SetVertexPointer(const void * pData, int nSize, int nStride)',
    '0x10002155c': 'void neGLESRenderer::SetColorPointer(const void * pData, int nStride)',
    '0x100021718': 'void neGLESRenderer::SetTexCoordPointer(const void * pData, int nStride)',
    '0x10002183c': 'void neGLESRenderer::SetWeightPointer(const void * pData, int nSize, int nStride)',
    '0x100021928': 'void neGLESRenderer::SetMatrixIndexPointer(const void * pData, int nSize, int nStride)',
    '0x1000216dc': 'void neGLESRenderer::ClearVertexPointer(int nStride, int nSize)',
    '0x1000215f4': 'void neGLESRenderer::ClearColorPointer(int nStride, int nColorOffset, int nBinding)',
    '0x1000217e4': 'void neGLESRenderer::ClearTexCoordPointer(int nStride, int nTexCoordOffset)',
    '0x1000218ec': 'void neGLESRenderer::ClearWeightPointer(int nStride, int nSize)',
    '0x1000219d8': 'void neGLESRenderer::ClearMatrixIndexPointer(int nStride, int nSize)',
    '0x1000276e4': 'void ne::C_DRAW_POLYGON_2D::Render()',
    '0x100028964': 'void ne::C_DRAW_POLYGON_3D::Render()',
    '0x100055638': 'float CalculateCurveInterpolation(const float * pPairs, int nCount, float flQueryX)',
    '0x1000556d0': 'float CalculateCurveValue(const FloatCurve * pCurve, float flQueryX)',
    '0x100058570': 'float TitleScreenLayerClassic::ComputeSwingParticleX(float flBaseX, float flBaseY) const',
    '0x100058610': 'float TitleScreenLayerClassic::ComputeSwingParticleY(float flBaseX, float flBaseY) const',
    '0x1000597a8': 'unsigned int TitleScreenLayerClassic::AdvanceGestureState(int inputCode)',
    '0x100152cc8': 'void TitleScreenLayerClassic::AdvanceSwipeState(int iSwipeEvent)',
    '0x1001549b8': 'void TitleScreenLayerColette::AdvanceSwipeState(int iSwipeEvent)',
    '0x100149ff4': 'void TitleScreenLayerClassic::CalculateFade(int nDeltaFrames)',
    '0x100152548': 'void TitleScreenLayerClassic::AdvanceFadeValue(int nDeltaFrames)',
    '0x10010a5fc': 'void ClassicThemeAnimation::AdvanceEasedProgress(float flDelta)',
    '0x10018795c': 'void FullComboEffectLayer::AdvanceFadeInterp(float flDeltaTime)',
    '0x100120a74': 'void LimelightThemeLayer::AdvanceGradeChannel(float flDeltaTime)',
    '0x100189ef0': 'void NumberEffectLayer::AdvanceFadeInterp(float flDeltaTime)',
    '0x10018bd58': 'void ScoreDigitAnim::Advance(float flDeltaTime)',
    '0x10012f5b0': 'NotePathPoint * NotePathPointArray::AllocateEntries(int nCount)',
    '0x10012f648': 'void NotePathPointArray::Append(const NotePathPoint & point)',
    '0x100017c90': 'TouchManager::TouchManager()',
    '0x100017dbc': 'void TouchManager::AddTouchPoint(int nX, int nY, int nKey1, int nKey2)',
    '0x100017e10': 'void TouchManager::UpdateTouchPoint(int nX, int nY, int nKey1, int nKey2)',
    '0x100017e5c': 'void TouchManager::HandleTouchMoved(int nNewX, int nNewY, int nOldX, int nOldY)',
    '0x100017f14': 'void TouchManager::MarkAllTouchesEnded()',
    '0x100149324': 'void ScoreTracker::ApplyLaneGaugeValueAndBackground(float flValue, unsigned int uSide)',
    '0x10005a0c4': 'void ne::C_SPRITE_INSTANCING_2D::SetSpritePosition(int nIndex, const S_VECTOR2 & position)',
    '0x100059fbc': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteSize(int nIndex, const S_VECTOR2 & size)',
    '0x100059f64': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteAnchor(int nIndex, const S_VECTOR2 & anchor)',
    '0x10005a014': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteUvOrigin(int nIndex, const S_VECTOR2 & uvOrigin)',
    '0x10005a06c': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteUvSize(int nIndex, const S_VECTOR2 & uvSize)',
    '0x10005a174': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteRotation(int nIndex, float flRotation)',
    '0x10005a11c': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteScale(int nIndex, float flScaleX, float flScaleY)',
    '0x10005a1c0': 'void ne::C_SPRITE_INSTANCING_2D::SetSpriteColor(int nIndex, unsigned int nRed, unsigned int nGreen, unsigned int nBlue, unsigned int nAlpha)',
    '0x100073edc': 'ResultWindowColetteLayer * ResultWindowColetteLayer::shared()',
    '0x100073f2c': 'void ResultWindowColetteLayer::InitializeResultWindowSprites()',
    '0x100073b4c': 'void ResultWindowColetteLayer::getPosition_Phone(int nIndex, S_VECTOR2 * pOutPosition) const',
    '0x100073a44': 'PartsDataRecord * ResultWindowColetteLayer::getPartsData(int nIndex) const',
    '0x100073adc': 'PartsDataRecord * ResultWindowColetteLayer::getPartsData_Phone(int nIndex) const',
    '0x1001151fc': 'ResultWindowClassicLayer * ResultWindowClassicLayer::shared()',
    '0x100114b78': 'const PartsDataRecord * ResultWindowClassicLayer::getPartsData(int nIndex) const',
    '0x100114c10': 'const PartsDataRecord * ResultWindowClassicLayer::getPartsData_Phone(int nIndex) const',
    '0x100028578': 'void ne::C_DRAW_POLYGON_2D::SetIndex(int nIndex, unsigned short wValue)',
    '0x100027374': 'ne::C_DRAW_POLYGON_2D::C_DRAW_POLYGON_2D(unsigned int nDrawMode, unsigned int nVertexCount, unsigned int nVertexFormat, unsigned char bVertexBufferExternal, unsigned int nIndexCount, unsigned char bIndexBufferExternal)',
    '0x100027568': 'void ne::C_DRAW_POLYGON_2D::AllocateBuffers()',
    '0x100028290': 'ne::C_DRAW_POLYGON_2D * ne::CreatePolygon2dMesh(unsigned int nDrawMode, unsigned int nVertexCount, unsigned int nVertexFormat, unsigned char bVertexBufferExternal, unsigned int nIndexCount, unsigned char bIndexBufferExternal)',
    '0x100020be4': 'void SubtractVector2(S_VECTOR2 * pOut, S_VECTOR2 * pIn)',
    '0x100020c20': 'float Vector2Length(S_VECTOR2 * pVec)',
    '0x100020bc0': 'void AddVector2(S_VECTOR2 * pOut, S_VECTOR2 * pIn)',
    '0x100029e70': 'void SetCurrentCamera(neGLESRenderer * pRenderer, ne_Viewport * pCamera)',
    '0x10010cd34': 'unsigned int KeyframeStepTableLookup(float flTime, const void * pUnused, const float * pTable, int nEntries)',
    '0x100029890': 'void ne::C_DRAW_POLYGON_3D::SetIndex(int nIndex, unsigned short wValue)',
    '0x1000285e8': 'ne::C_DRAW_POLYGON_3D::C_DRAW_POLYGON_3D(unsigned int nDrawMode, unsigned int nVertexCount, unsigned int nVertexFormat, unsigned char bVertexBufferExternal, unsigned int nIndexCount, unsigned char bIndexBufferExternal)',
    '0x1000287e8': 'void ne::C_DRAW_POLYGON_3D::AllocateBuffers()',
    '0x1000295a8': 'ne::C_DRAW_POLYGON_3D * ne::CreatePolygon3dMesh(unsigned int nDrawMode, unsigned int nVertexCount, unsigned int nVertexFormat, unsigned char bVertexBufferExternal, unsigned int nIndexCount, unsigned char bIndexBufferExternal)',
    '0x10011c744': 'void Polygon2dTrail::Init()',
    '0x10011524c': 'void ResultWindowClassicLayer::InitSpriteSetsLazy()',
    '0x100030804': 'ne::C_SPRITE_INSTANCING_2D * ne::CreateSpriteInstancer(unsigned int nCapacity)',
    '0x10012001c': 'void LimelightEffectLayer::InitializeBackgroundSprites()',
    '0x10011ffcc': 'LimelightEffectLayer * LimelightEffectLayer::shared()',
    '0x10011ff84': 'LimelightEffectLayer::LimelightEffectLayer()',
    '0x10010a86c': 'void BackgroundSpriteManager::BuildBackgroundSpriteNodes()',
    '0x10010a81c': 'BackgroundSpriteManager * BackgroundSpriteManager::shared()',
    '0x10010a7d8': 'BackgroundSpriteManager::BackgroundSpriteManager()',
    '0x10010f32c': 'void FullComboClassicLayer::InitializeBackgroundSprites()',
    '0x10010f2dc': 'FullComboClassicLayer * FullComboClassicLayer::shared()',
    '0x10010f280': 'FullComboClassicLayer::FullComboClassicLayer()',
    '0x100120718': 'void LimelightThemeLayer::InitFullComboLayerTextures()',
    '0x1001206c8': 'LimelightThemeLayer * LimelightThemeLayer::shared()',
    '0x100120630': 'LimelightThemeLayer::LimelightThemeLayer()',
    '0x100123db0': 'void LimelightResultLayer::InitializePhoneSpriteInstancers()',
    '0x100123d54': 'LimelightResultLayer * LimelightResultLayer::shared()',
    '0x100122934': 'void FullComboLimelightLayer::LoadTexturesAndBatchesForLimelightLayer()',
    '0x1001228e4': 'FullComboLimelightLayer * FullComboLimelightLayer::shared()',
    '0x10009b1dc': 'void FullComboColetteLayer::InitializeBackgroundSpriteLayers()',
    '0x10009b18c': 'FullComboColetteLayer * FullComboColetteLayer::shared()',
    '0x10017de30': 'void NumberLayer::InitializeNumberLayer()',
    '0x10017dde0': 'NumberLayer * NumberLayer::shared()',
    '0x10017dd98': 'NumberLayer::NumberLayer()',
    '0x10018756c': 'void ColetteThemeLayer::CreateFcEffectSprites()',
    '0x10018751c': 'ColetteThemeLayer * ColetteThemeLayer::shared()',
    '0x100187484': 'ColetteThemeLayer::ColetteThemeLayer()',
    '0x1001be504': 'void EventEffectLayer::CreateEventEffectSprites()',
    '0x1001be49c': 'EventEffectLayer * EventEffectLayer::shared()',
    '0x10010b44c': 'void TutorialGuideLayer::BuildTutorialGuideSpriteTable()',
    '0x10010b3b0': 'TutorialGuideLayer * TutorialGuideLayer::shared()',
    '0x100184c78': 'void JudgeEffectLayer::LoadJudgeEffectSprites()',
    '0x100184c28': 'JudgeEffectLayer * JudgeEffectLayer::shared()',
    '0x100184bb0': 'JudgeEffectLayer::JudgeEffectLayer()',
    '0x10017ff50': 'void ThemaMarkerLayer::LoadThemaMarkerSprites()',
    '0x10017fccc': 'ThemaMarkerLayer * ThemaMarkerLayer::shared()',
    '0x10017fc00': 'ThemaMarkerLayer::ThemaMarkerLayer()',
    '0x10018b6fc': 'void PlayerFieldLayer::CreateScoreNumberSpriteBatch()',
    '0x100181360': 'void NoteBodyLayer::LoadNoteBodySprites()',
    '0x100181310': 'NoteBodyLayer * NoteBodyLayer::shared()',
    '0x1001812a0': 'NoteBodyLayer::NoteBodyLayer()',
    '0x100184758': 'void NoteTrailLayer::LoadNoteTrailSprites()',
    '0x100184708': 'NoteTrailLayer * NoteTrailLayer::shared()',
    '0x1001846b0': 'NoteTrailLayer::NoteTrailLayer()',
    '0x100180c48': 'void NoteChargeLayer::LoadNoteChargeSprites()',
    '0x100180bf8': 'NoteChargeLayer * NoteChargeLayer::shared()',
    '0x100180b54': 'NoteChargeLayer::NoteChargeLayer()',
    '0x10008355c': 'void PlayColorLayer::BuildGaugePartsSpriteBatches()',
    '0x100083684': 'void PlayColorLayer::EmitGaugePartSprite(float flPosX, float flPosY, float flScaleX, float flScaleY, float flRotation, unsigned int nBatchIndex, unsigned int nPartIndex, unsigned int nAlpha)',
    '0x10008350c': 'PlayColorLayer * PlayColorLayer::shared()',
    '0x100083460': 'PlayColorLayer::PlayColorLayer()',
    '0x10018a8dc': 'void ReflecGaugeLayer::CreateGaugeSliderSprites()',
    '0x10018a88c': 'ReflecGaugeLayer * ReflecGaugeLayer::shared()',
    '0x10018a7d0': 'ReflecGaugeLayer::ReflecGaugeLayer()',
    '0x10018ab18': 'float ReflecGaugeLayer::GetValue(int nColor) const',
    '0x10018a9d8': 'void ReflecGaugeLayer::SetValue(float flValue, int nColor)',
    '0x10018ab98': 'float ReflecGaugeLayer::GetValueBySide(unsigned int nSide) const',
    '0x10018aa68': 'void ReflecGaugeLayer::SetValueBySide(float flValue, unsigned int nSide)',
    '0x100029638': 'void ne::C_DRAW_POLYGON_3D::SetPos(int nIndex, S_VECTOR3 position)',
    '0x100029788': 'void ne::C_DRAW_POLYGON_3D::SetRGBA(int nIndex, unsigned char nRed, unsigned char nGreen, unsigned char nBlue, unsigned char nAlpha)',
    '0x100029810': 'void ne::C_DRAW_POLYGON_3D::SetAlpha(int nIndex, unsigned char nAlpha)',
    '0x1000296cc': 'void ne::C_DRAW_POLYGON_3D::SetUV(int nIndex, float flU, float flV)',
    '0x1000296c4': 'void ne::C_DRAW_POLYGON_3D::SetUvFromVec(int nIndex, const S_VECTOR2 * pUv)',
    '0x100029558': 'void ne::C_DRAW_POLYGON_3D::SetTexture(C_TEXTURE * pTexture)',
    '0x10002959c': 'void ne::C_DRAW_POLYGON_3D::SetTexEnvParam(int nIndex, int nValue)',
    '0x100028328': 'void ne::C_DRAW_POLYGON_2D::SetPos(int nIndex, S_VECTOR2 position)',
    '0x100028320': 'void ne::C_DRAW_POLYGON_2D::SetPosFromVec(int nIndex, const S_VECTOR2 * pPosition)',
    '0x100028470': 'void ne::C_DRAW_POLYGON_2D::SetRGBA(int nIndex, unsigned char nRed, unsigned char nGreen, unsigned char nBlue, unsigned char nAlpha)',
    '0x10007ac58': 'void ResultWindowColetteLayer::appendSpriteToSlot(int nSlot, const S_VECTOR2 & position, const S_VECTOR2 & anchor, const S_VECTOR2 & size, const S_VECTOR2 & uvOrigin, const S_VECTOR2 & uvSize, float flRotation, const S_VECTOR2 & scale, unsigned int nIntensity, unsigned int nAlpha)',
    '0x100076b5c': 'void ResultWindowColetteLayer::renderSpriteInstanceFromSlot(int nSlot, const S_VECTOR2 & position, const S_VECTOR2 & extent, unsigned int nAlpha)',
}

# Optional per-address name override (Ghidra name is a misnomer for some of these).
NAME_OVERRIDES = {
    '0x100116258': 'RenderRatioDigits',
    '0x100114e18': 'getSeparator_Phone',
    '0x27530': 'C_DRAW_POLYGON_2D_deletingDtor',
    '0x287b0': 'C_DRAW_POLYGON_3D_deletingDtor',
    '0x2fa70': 'C_SPRITE_INSTANCING_deletingDtor',
    '0x100114e9c': 'getPositionByState_Phone',
    '0x100115008': 'getCenterPosition_Phone',
    '0x100116dc0': 'RenderGlyphAtSeparator',
    '0x100076c1c': 'renderSpriteInstanceScaled',
    '0x100074018': 'applySpriteInstancerTexture',
    '0x100079e7c': 'blitSpriteInstanceHalfScale',
    '0x10007aa54': 'RenderAnchoredGlyphWithAlpha',
    '0x100123940': 'getPosition_Phone',
    '0x1001238d0': 'getPartsData_Phone',
    '0x100123ad8': 'getSeparator_Phone',
    '0x100123cc8': 'getCenterPosition_Phone',
    '0x100073e50': 'getCenterPosition_Phone',
    '0x1001cc410': 'GetLevelExpThreshold',
    '0x1001cc438': 'GetLevelUnlockEntry',
    '0x1001cc3b4': 'ComputeLevelExpStep',
    '0x100136afc': 'InitNoteLaneTable',
    '0x100136a38': 'GetNoteLaneFraction',
    '0x1001352b8': 'GetLaneX',
    '0x10009b118': 'FullComboColetteLayer',
    '0x100122870': 'FullComboLimelightLayer',
    '0x10004bbd4': 'FindOrGrowFreeSlot',
    '0x10004b6c4': 'RegisterSource',
    '0x10004d450': 'LoadFromUrl',
    '0x10004d3d0': 'LoadFromPath',
    '0x10004d39c': '~caSource',
    '0x10004d350': 'caSource',
    '0x10004ac40': 'FillPcm',
    '0x100021d80': 'SetGlEnableState',
    '0x100021e14': 'SetGlClientState',
    '0x100021460': 'SetCurrentPaletteMatrix',
    '0x100021c98': 'SetBlendFunc',
    '0x100021250': 'SetMatrixMode',
    '0x10002faa8': 'Render',
    '0x1000307f0': 'GetBoundTexture',
    '0x1000276e4': 'Render',
    '0x100028964': 'Render',
    '0x10005a0c4': 'SetSpritePosition',
    '0x100059fbc': 'SetSpriteSize',
    '0x100059f64': 'SetSpriteAnchor',
    '0x10005a014': 'SetSpriteUvOrigin',
    '0x10005a06c': 'SetSpriteUvSize',
    '0x10005a174': 'SetSpriteRotation',
    '0x10005a11c': 'SetSpriteScale',
    '0x10005a1c0': 'SetSpriteColor',
    '0x100073edc': 'shared',
    '0x100073f2c': 'InitializeResultWindowSprites',
    '0x100073b4c': 'getPosition_Phone',
    '0x100073a44': 'getPartsData',
    '0x100073adc': 'getPartsData_Phone',
    '0x1001151fc': 'shared',
    '0x100114b78': 'getPartsData',
    '0x100114c10': 'getPartsData_Phone',
    '0x100028578': 'SetIndex',
    '0x100027374': 'ConstructPolygon2dMesh',
    '0x100027568': 'AllocatePolygon2dMeshBuffers',
    '0x100028290': 'CreatePolygon2dMesh',
    '0x100028328': 'SetPos',
    '0x100028320': 'SetPosFromVec',
    '0x100028470': 'SetRGBA',
    '0x10010cd34': 'KeyframeStepTableLookup',
    '0x100029890': 'SetIndex',
    '0x1000285e8': 'ConstructPolygon3dMesh',
    '0x1000287e8': 'AllocatePolygon3dMeshBuffers',
    '0x1000295a8': 'CreatePolygon3dMesh',
    '0x10011c744': 'Init',
    '0x10011524c': 'InitSpriteSetsLazy',
    '0x100030804': 'CreateSpriteInstancer',
    '0x10012001c': 'InitializeBackgroundSprites',
    '0x10011ffcc': 'shared',
    '0x10011ff84': 'LimelightEffectLayer',
    '0x10010a86c': 'BuildBackgroundSpriteNodes',
    '0x10010a81c': 'shared',
    '0x10010a7d8': 'BackgroundSpriteManager',
    '0x10010f32c': 'InitializeBackgroundSprites',
    '0x10010f2dc': 'shared',
    '0x10010f280': 'FullComboClassicLayer',
    '0x100120718': 'InitFullComboLayerTextures',
    '0x1001206c8': 'shared',
    '0x100120630': 'LimelightThemeLayer',
    '0x100123db0': 'InitializePhoneSpriteInstancers',
    '0x100123d54': 'shared',
    '0x100122934': 'LoadTexturesAndBatchesForLimelightLayer',
    '0x1001228e4': 'shared',
    '0x10009b1dc': 'InitializeBackgroundSpriteLayers',
    '0x10009b18c': 'shared',
    '0x10017de30': 'InitializeNumberLayer',
    '0x10017dde0': 'shared',
    '0x10017dd98': 'NumberLayer',
    '0x10018756c': 'CreateFcEffectSprites',
    '0x10018751c': 'shared',
    '0x100187484': 'ColetteThemeLayer',
    '0x1001be504': 'CreateEventEffectSprites',
    '0x1001be49c': 'shared',
    '0x10010b44c': 'BuildTutorialGuideSpriteTable',
    '0x10010b3b0': 'shared',
    '0x100184c78': 'LoadJudgeEffectSprites',
    '0x100184c28': 'shared',
    '0x100184bb0': 'JudgeEffectLayer',
    '0x10017ff50': 'LoadThemaMarkerSprites',
    '0x10017fccc': 'shared',
    '0x10017fc00': 'ThemaMarkerLayer',
    '0x10018b6fc': 'CreateScoreNumberSpriteBatch',
    '0x100181360': 'LoadNoteBodySprites',
    '0x100181310': 'shared',
    '0x1001812a0': 'NoteBodyLayer',
    '0x100184758': 'LoadNoteTrailSprites',
    '0x100184708': 'shared',
    '0x1001846b0': 'NoteTrailLayer',
    '0x100180c48': 'LoadNoteChargeSprites',
    '0x100180bf8': 'shared',
    '0x100180b54': 'NoteChargeLayer',
    '0x10008355c': 'BuildGaugePartsSpriteBatches',
    '0x100083684': 'EmitGaugePartSprite',
    '0x10008350c': 'shared',
    '0x100083460': 'PlayColorLayer',
    '0x10018a8dc': 'CreateGaugeSliderSprites',
    '0x10018a88c': 'shared',
    '0x10018a7d0': 'ReflecGaugeLayer',
    '0x10018ab18': 'GetValue',
    '0x10018a9d8': 'SetValue',
    '0x10018ab98': 'GetValueBySide',
    '0x10018aa68': 'SetValueBySide',
    '0x10018abfc': 'AddReflecGaugeValue',
    '0x10018acb8': 'SubReflecGaugeValue',
    '0x10018ad0c': 'SetGaugeDisplayBrightness',
    '0x100029638': 'SetPos',
    '0x100029788': 'SetRGBA',
    '0x100029810': 'SetAlpha',
    '0x1000296cc': 'SetUV',
    '0x1000296c4': 'SetUvFromVec',
    '0x100029558': 'SetTexture',
    '0x10002959c': 'SetTexEnvParam',
}

with open(PATH, encoding='utf-8') as fh:
    lines = fh.readlines()

row_re = re.compile(r'^\| ')
header_idx = sep_idx = None
rows = []
preamble = []
footer = []
for i, ln in enumerate(lines):
    if ln.startswith('| Name'):
        header_idx = i
    elif ln.startswith('| ---'):
        sep_idx = i
    elif row_re.match(ln) and sep_idx is not None:
        rows.append(ln)
    elif sep_idx is None:
        preamble.append((i, ln))

# Preamble is everything up to and including the separator; footer is anything after the last row
# (there is none in practice). Split cleanly on header/sep indices.
head_lines = lines[:sep_idx + 1]


def unwrap(cell):
    cell = cell.strip()
    if cell.startswith('`') and cell.endswith('`'):
        cell = cell[1:-1]
    return cell.strip()


def parse(row):
    cells = [c.strip() for c in row.strip().strip('|').split('|')]
    name, status, xref, length, addr, sig = cells
    return {
        'name': unwrap(name),
        'status': _LEGACY_STATUS.get(status, status),
        'xref': int(xref),
        'length': int(length),
        'addr': unwrap(addr),
        'sig': unwrap(sig),
    }


parsed = [parse(r) for r in rows]


def _ghidra_probe():
    """Return True when the Ghidra MCP HTTP bridge answers, else False (offline regen)."""
    try:
        req = f'{GHIDRA_HTTP}/get_function_by_address?address=0x100000000&program={GHIDRA_PROGRAM}'
        urllib.request.urlopen(req, timeout=3).read()
        return True
    except (urllib.error.URLError, OSError):
        return False


def _ghidra_function(raw_addr):
    """Fetch (name, signature, length) for a raw image-base address from the MCP bridge, or None."""
    query = urllib.parse.urlencode({'address': raw_addr, 'program': GHIDRA_PROGRAM})
    try:
        with urllib.request.urlopen(f'{GHIDRA_HTTP}/get_function_by_address?{query}', timeout=5) as f:
            text = f.read().decode('utf-8', 'replace')
    except (urllib.error.URLError, OSError):
        return None
    name = sig = None
    length = 0
    for line in text.splitlines():
        if line.startswith('Function:'):
            m = re.match(r'Function:\s*(.+?)\s+at\s+[0-9a-fA-F]+', line)
            if m:
                name = m.group(1)
        elif line.startswith('Signature:'):
            sig = line.split(':', 1)[1].strip()
        elif line.startswith('Body:'):
            m = re.match(r'Body:\s*([0-9a-fA-F]+)\s*-\s*([0-9a-fA-F]+)', line)
            if m:
                length = int(m.group(2), 16) - int(m.group(1), 16) + 1
    if name is None:
        return None
    return name, sig, length


def refresh_from_ghidra(rows_):
    """Refresh each row's name (and signature/length) from the live Ghidra program when the MCP
    bridge is reachable, so renames propagate into the checklist automatically. A done row keeps its
    reconstructed source signature (applied later); only its name and length are refreshed. Skips
    silently when offline."""
    if not _ghidra_probe():
        return 0
    refreshed = 0
    for r in rows_:
        try:
            ai = int(r['addr'], 16)
        except ValueError:
            continue
        raw = f'0x{(ai if ai >= IMAGE_BASE else ai + IMAGE_BASE):x}'
        info = _ghidra_function(raw)
        if info is None:
            continue
        name, sig, length = info
        if name and name != r['name']:
            r['name'] = name
            refreshed += 1
        if length:
            r['length'] = length
        # Refresh the preliminary signature only for rows without a reconstructed definition; a done
        # row's real signature is applied from source afterwards.
        if sig and r['status'] != DONE:
            r['sig'] = sig
    return refreshed


if '--no-ghidra' not in sys.argv:
    _n = refresh_from_ghidra(parsed)
    if _n:
        print(f'refreshed {_n} name(s) from Ghidra')


# A block literal argument, e.g. ``success:^(Downloader *response) {``, ``dispatch_once(..., ^{`` or
# ``sortUsingComparator:^NSComparisonResult(id lhs, id rhs) {`` (an explicit block return type may sit
# between the caret and the parameter list).
_block_literal_re = re.compile(r'\^\s*(?P<ret>[\w:<>*&\s]*?)\s*\((?P<params>[^)]*)\)')
_block_noparam_re = re.compile(r'\^\s*\{')
# A clean C++ function/method definition head: ``<ret> [Class::]name(``. The name may be qualified
# (``Class::method``) and preceded by a pointer/reference sigil or whitespace.
_cpp_def_re = re.compile(r'^[\w:<>*&,\s]+?[\s*&:]((?:\w+::)*[\w~]+)\s*\(')


_class_open_re = re.compile(r'^\s*(?:template\s*<[^>]*>\s*)?(?:class|struct)\s+(\w+)\b')
_namespace_open_re = re.compile(r'^\s*namespace\s+(\w+)\s*\{')


def enclosing_namespace(lines, idx):
    """The ``namespace`` path (e.g. ``rb`` or ``ne::detail``) whose body encloses line ``idx``, or
    None at global scope.

    Tracks brace nesting from the top of the file: a ``namespace NAME {`` opener pushes NAME, any
    other ``{`` pushes an empty marker, and ``}`` pops. This lets a definition written as
    ``Class::method`` inside ``namespace rb {`` be reported fully-qualified as ``rb::Class::method``,
    matching the binary's RTTI name. An anonymous ``namespace {`` contributes no name (its members
    have internal linkage and are not tracked in the checklist).
    """
    ns_stack = []  # namespace name (or '' for a non-namespace/anonymous scope) per open brace level.
    pending_ns = None  # a namespace name awaiting its opening brace.
    for n in range(idx):
        line = lines[n]
        pos = 0
        while pos < len(line):
            if pending_ns is None:
                m = _namespace_open_re.match(line[pos:] if pos else line)
                if m and pos == 0:
                    pending_ns = m.group(1)
            ch = line[pos]
            if ch == '{':
                ns_stack.append(pending_ns or '')
                pending_ns = None
            elif ch == '}':
                if ns_stack:
                    ns_stack.pop()
            pos += 1
    names = [s for s in ns_stack if s]
    return '::'.join(names) if names else None


def enclosing_class(lines, idx):
    """The name of the ``class``/``struct`` whose body encloses line ``idx``, or None at file scope.

    Tracks brace nesting from the top of the file: each ``{`` pushes a scope, tagged with the class
    name if a preceding ``class``/``struct`` header introduced it, and each ``}`` pops. An inline
    method defined inside a class body is then qualified with its owning class so the report shows
    ``Class::method`` — matching an out-of-line definition. Namespaces push an untagged scope, so an
    inline method's qualifier is its class, not the namespace.
    """
    scopes = []          # class name (or None) for each open brace level, outermost first.
    pending_class = None  # a class/struct name awaiting its opening brace.
    for n in range(idx):
        line = lines[n]
        pos = 0
        while pos < len(line):
            # Recognise a class/struct header only at the start of a fresh statement region.
            if pending_class is None:
                m = _class_open_re.match(line[pos:] if pos else line)
                if m and pos == 0 and ';' not in line.split('{', 1)[0]:
                    pending_class = m.group(1)
            ch = line[pos]
            if ch == '{':
                scopes.append(pending_class)
                pending_class = None
            elif ch == '}':
                if scopes:
                    scopes.pop()
            elif ch == ';':
                pending_class = None
            pos += 1
    for name in reversed(scopes):
        if name:
            return name
    return None


def _clean_decl(decl):
    """Collapse a multi-line C++ declaration into a one-line signature (no trailing body/semicolon)."""
    decl = decl.strip()
    # Cut at the first '{' (definition body) or ';' (declaration terminator).
    for stop in ('{', ';'):
        idx = decl.find(stop)
        if idx != -1:
            decl = decl[:idx]
    decl = re.sub(r'\s+', ' ', decl).strip()
    # Drop a Doxygen/attribute prefix if the tag and decl shared a line.
    decl = re.sub(r'^\*/\s*', '', decl)
    return decl


def extract_signature(text, tag_idx):
    """Return the reconstructed signature for the tag on line ``tag_idx``, or None to skip.

    Handles three source shapes: a block-literal argument (rendered as anonymous ``void (^)(...)``),
    a clean C++ function/method definition, and an Objective-C method (skipped — those are tracked
    separately from the C/C++ checklist). Multi-line definition heads are joined; statement
    fragments and block bodies that are not a recognisable definition are skipped.
    """
    # A block-literal enclosing the tag has its ``^(...)`` on the tag line or just above it, since the
    # tag sits inside the block body.
    for k in range(tag_idx, max(tag_idx - 3, -1), -1):
        m = _block_literal_re.search(text[k])
        if m:
            params = re.sub(r'\s+', ' ', m.group('params').strip())
            ret = re.sub(r'\s+', ' ', m.group('ret').strip()) or 'void'
            return f'{ret} (^)({params})'
        if _block_noparam_re.search(text[k]):
            return 'void (^)()'

    # Otherwise gather the declaration lines after the tag, skipping comment/blank lines.
    buf = []
    for j in range(tag_idx + 1, min(tag_idx + 12, len(text))):
        stripped = text[j].strip()
        if not buf and (stripped == '' or stripped.startswith(('//', '/*', '*', '#'))):
            continue
        buf.append(text[j])
        if '{' in text[j] or ';' in text[j]:
            break
    if not buf:
        return None

    first = buf[0].lstrip()
    # An Objective-C method definition — excluded from the C/C++ signature column.
    if first.startswith(('-', '+', '@', '[')):
        return None
    # A block literal passed as an argument on the line after the tag.
    m = _block_literal_re.search(''.join(buf))
    if m and first.startswith(('}', 'success:', 'completion:', 'animations:')):
        params = re.sub(r'\s+', ' ', m.group('params').strip())
        return f'void (^)({params})'

    decl = _clean_decl(''.join(buf))
    # Drop an explicitly-defaulted/deleted suffix so the signature reads as the plain declaration.
    decl = re.sub(r'\s*=\s*(default|delete)\s*$', '', decl)
    # Must be a real C++ function/method definition head, with no leftover block/statement noise.
    if '^' in decl or decl.startswith(('}', '[')) or '=' in decl.split('(', 1)[0]:
        return None
    m = _cpp_def_re.match(decl)
    if '(' not in decl or not m:
        return None
    # An inline method defined inside a class body carries no ``Class::`` qualifier; prepend its
    # enclosing class so the report shows the fully-qualified name (matching an out-of-line body).
    name = m.group(1)
    if '::' not in name:
        owner = enclosing_class(text, tag_idx)
        if owner and owner != name:
            head = decl[:m.start(1)]
            decl = f'{head}{owner}::{decl[m.start(1):]}'
            m = _cpp_def_re.match(decl)
            name = m.group(1) if m else name
    # A definition inside ``namespace NS {`` reports its name NS-qualified (``NS::Class::method``) to
    # match the binary's RTTI name. The captured group is only the final component (for a constructor
    # ``Class::Class`` it is the second ``Class``), so insert NS at the START of the qualified-id —
    # the run of ``Ident::`` segments immediately preceding the captured name — not at the name group.
    namespace = enclosing_namespace(text, tag_idx)
    if namespace:
        qual_start = m.start(1)
        prefix = decl[:qual_start]
        qm = re.search(r'((?:\w+::)+)$', prefix)
        id_start = qm.start(1) if qm else qual_start
        qualified_id = decl[id_start:]
        if not qualified_id.startswith(f'{namespace}::'):
            decl = f'{decl[:id_start]}{namespace}::{qualified_id}'
    return decl


def tag_defines(lines, idx):
    """Whether the ``@ghidraAddress`` tag on line ``idx`` precedes an actual definition (a function
    body), rather than a bare declaration.

    A definition reaches an opening brace ``{`` before a terminating ``;``; a header declaration
    reaches ``;`` first and is NOT a definition (the function is only declared, not implemented). An
    explicitly-defaulted or deleted member (``= default;`` / ``= delete;``) counts as a definition
    even though it has no braces. A block literal — whose tag sits inside the block body — always
    counts as a definition.
    """
    # A block literal encloses the tag when its ``^(...)`` / ``^{`` sits on the tag line or just above.
    for k in range(idx, max(idx - 3, -1), -1):
        if _block_literal_re.search(lines[k]) or _block_noparam_re.search(lines[k]):
            return True
    # The tag may sit INSIDE a function body (on the first line after the opening brace), a common
    # placement for a one-line reconstruction. Scan a few lines up: a non-comment line whose last
    # significant character is ``{`` opens a body the tag is inside, so it is a definition. (A brace
    # that also closes on the same line — ``{}`` — does not count.)
    for k in range(idx - 1, max(idx - 4, -1), -1):
        code = re.sub(r'//.*$', '', lines[k]).rstrip()
        if not code.strip() or code.strip().startswith(('*', '/*', '#')):
            continue
        if code.endswith('{'):
            return True
        break
    # The tag may also sit inside an ObjC method body after a guard clause (e.g. a +initialize whose
    # first statements follow an ``if (...) { return; }``). Scan up tracking brace balance; when it
    # first goes positive, if the opener is an ObjC method (``- (`` / ``+ (``) the tag is in a body,
    # so a definition. Any other opener is inconclusive here — fall through to the forward scan
    # rather than deciding, so header inline methods (tag above a ``name() {`` head) still resolve.
    balance = 0
    for k in range(idx - 1, max(idx - 60, -1), -1):
        code = re.sub(r'//.*$', '', lines[k])
        if code.lstrip().startswith(('*', '/*', '#')):
            continue
        balance += code.count('{') - code.count('}')
        if balance > 0:
            if code.strip().startswith(('-', '+')):
                return True
            break
    # Skip the tag's own comment/blank lines, then read forward until a ``{`` or ``;`` decides it.
    for j in range(idx + 1, min(idx + 14, len(lines))):
        stripped = lines[j].strip()
        if stripped == '' or stripped.startswith(('//', '/*', '*', '#')):
            continue
        pending = ''
        for jj in range(j, min(idx + 20, len(lines))):
            pending += lines[jj]
            brace = lines[jj].find('{')
            semi = lines[jj].find(';')
            if brace != -1 and (semi == -1 or brace < semi):
                return True
            if semi != -1 and (brace == -1 or semi < brace):
                # An explicitly-defaulted/deleted member is a definition despite having no body.
                if re.search(r'=\s*(default|delete)\s*;', pending):
                    return True
                # A namespace-scope global-variable DEFINITION (not an ``extern`` declaration and not
                # a function prototype) is a definition: for a class-type global the compiler emits
                # its static constructor from this line, which is what the tag names. Keyed to our
                # ``g_``/``k`` global naming and the absence of ``extern`` and a call signature.
                flat = re.sub(r'\s+', ' ', pending).strip()
                if 'extern' not in flat and '(' not in flat.split(';', 1)[0] \
                        and re.search(r'\b[gk]_?[A-Za-z]\w*\s*(=|\[|;)', flat):
                    return True
                return False
        return False
    return False


_TAG_RE = re.compile(r'@ghidraAddress\s+(0x[0-9a-fA-F]+)')


def _both_keys(value):
    """Both address forms (full image-base and stripped) for a raw @ghidraAddress value."""
    return {value, value + IMAGE_BASE if value < IMAGE_BASE else value - IMAGE_BASE}


def _tag_groups(lines):
    """Yield ``(addrs, tag_idx, is_body)`` for each @ghidraAddress doc-block in ``lines``.

    Consecutive tags separated only by comment/blank lines share one declaration or definition — a
    duplicate-emission block where several byte-identical addresses map to one reconstruction. Each
    group reports the raw addresses it binds, the line of its last tag (for signature extraction), and
    whether that declaration is an actual definition (a body) rather than a bare prototype.
    """
    i = 0
    n = len(lines)
    while i < n:
        m = _TAG_RE.search(lines[i])
        if not m:
            i += 1
            continue
        addrs = [int(m.group(1), 16)]
        last = i
        j = i + 1
        # Absorb further tags whose intervening lines are only comment/blank (one doc-block).
        while j < n:
            stripped = lines[j].strip()
            mm = _TAG_RE.search(lines[j])
            if mm:
                addrs.append(int(mm.group(1), 16))
                last = j
                j += 1
            elif stripped == '' or stripped.startswith(('//', '/*', '*', '#')):
                j += 1
            else:
                break
        yield addrs, last, tag_defines(lines, last)
        i = j


def collect_source_data():
    """Scan the source tree once and return ``(sigs, defined)``.

    ``sigs`` maps each address form to the reconstructed signature of its definition. ``defined`` is
    the set of addresses backed by a real definition (a function body), directly or — for a
    duplicate-emission doc-block — because a sibling address in the same block has a body elsewhere in
    the tree. A bare header declaration whose function is never implemented anywhere is therefore NOT
    counted as done, which is the whole point: a mere prototype is not a reconstruction.
    """
    body_addrs = set()   # addresses whose own tag precedes a body.
    group_addrs = []     # list of (set-of-addrs) sharing one doc-block (for dup coverage).
    sigs = {}
    for pattern in SOURCE_GLOBS:
        for path in glob.glob(pattern, recursive=True):
            try:
                with open(path, encoding='utf-8', errors='replace') as fh:
                    text = fh.readlines()
            except OSError:
                continue
            for addrs, tag_idx, is_body in _tag_groups(text):
                keys = set()
                for value in addrs:
                    keys |= _both_keys(value)
                group_addrs.append(keys)
                if is_body:
                    body_addrs |= keys
                    decl = extract_signature(text, tag_idx)
                    if decl:
                        for k in keys:
                            # Prefer a qualified definition (``Class::method``) over an unqualified
                            # one for the same address (both the .h and .cpp carry the tag).
                            if k not in sigs or ('::' in decl and '::' not in sigs[k]):
                                sigs[k] = decl
    # A duplicate-emission block is covered when any address in it has a body somewhere in the tree.
    defined = set(body_addrs)
    for keys in group_addrs:
        if keys & body_addrs:
            defined |= keys
            # Propagate the body sibling's signature to the dup addresses that lack one of their own.
            known = [sigs[k] for k in keys if k in sigs]
            if known:
                sib = min(known, key=lambda s: (0 if '::' in s else 1, len(s)))
                for k in keys:
                    sigs.setdefault(k, sib)
    return sigs, defined


SOURCE_SIGS, DEFINED_ADDRS = collect_source_data()


# Explicit block signatures (address -> real reconstructed block type), for blocks whose parameter
# or return types were recovered from the reconstruction. Presence here overrides the synthesized
# Ghidra signature with the true block form. These are blocks Ghidra modelled with a method-style
# receiver rather than a ``_block *``, so the automatic reshape cannot detect them.
BLOCK_SIGNATURES = {
    '0x100049688': 'void (^)()',
    '0x1000710c4': 'void (^)()',
    '0x10022b908': 'void (^)()',
    '0x100037ec4': 'void (^)(NSURL * location, NSURLResponse * response, NSError * error)',
    # NSComparator block-invoke copies (return NSComparisonResult, not Ghidra's synthesized long).
    '0x19b190': 'NSComparisonResult (^)(id objA, id objB)',
    '0x19b614': 'NSComparisonResult (^)(id objA, id objB)',
    # A view-hide completion block-invoke: returns 0 into a discarded register, so effectively void.
    '0x1a478': 'void (^)()',
}

# Free helpers whose reconstruction lives in a .mm but whose @ghidraAddress tag is not directly
# above a parseable definition head (so the source extractor cannot see it). address -> signature.
EXPLICIT_SIGNATURES = {}

# A synthesized block-invoke head. Ghidra models the block's captured-state receiver either as a
# typed ``Name_block *``/``Block_layout *`` or, when it could not recover the layout, as a bare
# ``void *pBlock`` — the ``pBlock`` parameter name is its reliable block-invoke signal either way.
_block_re = re.compile(r'^(?P<ret>[\w:<>*&\s]+?)\s+(?P<name>\w+)\('
                       r'(?P<recv>(?:\w+_block|Block_layout)\s*\*\s*\w+|void\s*\*\s*pBlock)'
                       r'(?P<rest>.*)\)$')
# An already-reshaped block, named ``ret (^Name)(args)`` or anonymous ``ret (^)(args)``.
_named_block_re = re.compile(r'^(?P<ret>.+?)\s*\(\^(?P<name>\w*)\)\((?P<rest>.*)\)$')


def block_signature(sig, name):
    """Reshape a synthesized ``ret Name(Name_block *pBlock, args)`` into anonymous Objective-C block
    syntax ``ret (^)(args)``.

    Inline block literals are not named in the reconstruction, so the report shows them unnamed
    rather than with the tool's synthesized handler name. The leading ``_block *`` receiver is the
    block's captured-state object, not a call parameter, so it is dropped; the remaining parameters
    are the block's real ones.
    """
    # Normalise an already-reshaped named block to the anonymous form.
    named = _named_block_re.match(sig.strip())
    if named:
        return f'{_block_return(named.group("ret").strip())} (^)({named.group("rest").strip()})'
    m = _block_re.match(sig.strip())
    if not m:
        return sig
    rest = m.group('rest').strip()
    if rest.startswith(','):
        rest = rest[1:].strip()
    return f'{_block_return(m.group("ret").strip())} (^)({rest})'


def _block_return(ret):
    """An inline ObjC block passed to completion/animation/finished callbacks returns void; Ghidra's
    ``undefined``/``undefined8`` return placeholders on such a block are the discarded result register,
    so they render as ``void``. A block with a genuinely typed return keeps it."""
    if ret in ('undefined', 'undefined8'):
        return 'void'
    return ret


def addr_int(addr_str):
    try:
        return int(addr_str, 16)
    except ValueError:
        return None


def _override(table, raw_addr, value):
    """Look up an override table keyed by either the full image-base address or the file-relative
    short form, so an entry authored in either form resolves regardless of the row's address form."""
    if value in table:
        return table[value]
    if raw_addr is not None:
        for form in (f'0x{raw_addr:x}', f'0x{raw_addr - IMAGE_BASE:x}' if raw_addr >= IMAGE_BASE
                     else f'0x{raw_addr + IMAGE_BASE:x}'):
            if form in table:
                return table[form]
    return None


for r in parsed:
    addr = addr_int(r['addr'])
    # Status is authoritative from the source tree: a row is done if and only if a real definition
    # (a function body, or a duplicate-emission sibling of one) exists for its address. A bare header
    # declaration or a manual signature override does NOT make a row done — only an implementation
    # does. This downgrades any stale done row whose definition was removed or never written.
    r['status'] = DONE if (addr is not None and addr in DEFINED_ADDRS) else NOT
    # Signature priority: explicit UPDATES override, then EXPLICIT_SIGNATURES, then the signature
    # extracted from the reconstruction's source, then a block reshape of the raw Ghidra signature.
    upd = _override(UPDATES, addr, r['addr'])
    expl = _override(EXPLICIT_SIGNATURES, addr, r['addr'])
    blk = _override(BLOCK_SIGNATURES, addr, r['addr'])
    if upd is not None:
        r['sig'] = upd
    elif expl is not None:
        r['sig'] = expl
    elif addr is not None and addr in SOURCE_SIGS:
        r['sig'] = SOURCE_SIGS[addr]
    elif blk is not None:
        r['sig'] = blk
    elif ('_block' in r['sig'] or 'Block_layout' in r['sig'] or '(^' in r['sig']
          or 'void *pBlock' in r['sig'] or 'void * pBlock' in r['sig']):
        r['sig'] = block_signature(r['sig'], r['name'])
    name_over = _override(NAME_OVERRIDES, addr, r['addr'])
    if name_over is not None:
        r['name'] = name_over


_STMT_PREFIXES = ('- (', '+ (', '@', '}', 'return ', 'self.', 'if (', 'if(', 'while (', 'while(',
                  'for (', 'for(', 'switch (', 'else', 'do ', '[')


def is_objc_method(sig):
    """An Objective-C method signature or a leftover statement/control-flow fragment (from a block
    body whose tag preceded a statement) — not a C/C++ entry, and often contains an ObjC message
    send in brackets."""
    stripped = sig.lstrip()
    # A row left with the previous run's exclusion placeholder is also an Objective-C method.
    if stripped.startswith('(Objective-C method'):
        return True
    if stripped.startswith(_STMT_PREFIXES):
        return True
    # A signature that is really a statement with an ObjC message send, e.g. ``if ([lhs order] > ...``.
    if '[' in stripped and ']' in stripped and '(' not in stripped.split('[', 1)[0]:
        return True
    return False


# Objective-C methods do not belong in the C/C++ checklist; drop those rows entirely.
parsed = [r for r in parsed if not is_objc_method(r['sig'])]

# Functions that are not ours to reconstruct and so are excluded from the checklist denominator
# (rather than left as permanent unreconstructed rows): compiler-emitted exception landing pads
# (referenced only from __gcc_except_tab, they merely tail-call _Unwind_Resume) and bundled
# third-party minizip helpers (the rest of minizip was already curated out; these are stragglers).
# Keyed by file-relative address.
EXCLUDED_ADDRS = {
    '0x41718',  # CleanupAVBusOnUnwind — AVBus exception landing pad (compiler-emitted).
    '0x13904',  # AppendToBufferChain — minizip add_data_in_datablock (bundled third-party).
    '0xbdcc',   # CreateStoreButton — a StoreButtonView initWithFrame: landing pad (__cxa_begin_catch
                # then std::terminate), misnamed by the decompiler; not a real function.
    '0x5008',   # ReturnZero — a block dispose helper (objc_release of the +0x20 capture), misnamed;
                # block helpers do not belong on the C/C++ checklist.
    '0x20f48',  # GetAlwaysTrue — the IMP of -[<VC> prefersStatusBarHidden] (returns YES); an
                # Objective-C method, tracked on the ObjC side, not the C/C++ checklist.
    '0x88fb8',  # GetAlwaysTrue — a second such IMP (type encoding B16@0:8, referenced only from an
                # ObjC method-list in __data at 0x388298); an Objective-C BOOL accessor returning
                # YES, tracked on the ObjC side, not the C/C++ checklist.
    '0x366f0',  # ReturnZeroStub — the IMP of -[<class> canBecomeFirstResponder] (returns NO); an
                # Objective-C method, tracked on the ObjC side, not the C/C++ checklist.
    '0x1c3ccc', # InitializeGregorianCalendar — a dispatch_once block inside SSZipArchive.m's
                # -_dateWithMSDOSFormat: (bundled third-party 3rdparty/), not ours to reconstruct.
}
# Compiler-emitted free-function no-op stubs. Every one is a single-`ret` (4-byte) body installed as
# a default block-invoke or an empty callback-table slot and reached only through a data pointer;
# they take no object argument, belong to no class, and have nothing to reconstruct, so they are
# excluded from the checklist denominator. They are renamed uniformly to `CompilerGeneratedNoOp_*` in
# Ghidra (address suffix only for uniqueness), which is the single signal this rule keys on. Empty
# stubs that instead take a `pThis` are real (empty) virtual methods of a class: they keep their
# descriptive names, are reconstructed as empty methods on their owning class, and flip to done
# normally when their address appears in source.
def is_compiler_noop(r):
    """Whether a row is a compiler-emitted stub with nothing to reconstruct (excluded).

    Two kinds are dropped: free-function no-op stubs (single-``ret`` default block-invokes / empty
    callback slots) and ARC block/byref copy-move helpers (``dst[+N] = src[+N]; src[+N] = 0`` ownership
    thunks the compiler emits for a block's ``__copy_helper``). Both are renamed uniformly in Ghidra —
    ``CompilerGeneratedNoOp_*`` and ``CompilerGeneratedBlockHelper_*`` — which is the signal here.

    A row that IS defined in the reconstructed source is a real, deliberately reconstructed function
    (an empty block body, an empty virtual method) and is never excluded, regardless of name: being
    present in source is the authoritative signal that it is ours. Legacy auto-analysis names still in
    the table (tiny zero-argument ``EmptyStub``/``EmptyNoOpCallback``/``HandleEmptyNoOp*``, or a
    ``BlockMoveHelper``/``MoveOwnedField``/``*BlockMoveHelperByref*`` move helper) are matched too so a
    not-yet-refreshed row is dropped."""
    keys = _both_keys(int(r['addr'], 16)) if re.fullmatch(r'0x[0-9a-fA-F]+', r['addr']) else set()
    if keys & DEFINED_ADDRS:
        return False
    if r['name'].startswith(('CompilerGeneratedNoOp', 'CompilerGeneratedBlockHelper')):
        return True
    noop = re.match(r'(EmptyStub|EmptyNoOpCallback|EmptyProceedCallback|HandleEmptyNoOp\w*)$',
                    r['name'])
    if noop and r['length'] <= 8 and ('(void)' in r['sig'] or '()' in r['sig']):
        return True
    # A compiler block/byref move helper: a 16-byte two-pointer thunk with a move-helper name.
    helper = re.search(r'(BlockMoveHelper|MoveOwnedField|BlockMoveHelperByref)', r['name'])
    return bool(helper) and r['length'] <= 16


parsed = [r for r in parsed if r['addr'] not in EXCLUDED_ADDRS and not is_compiler_noop(r)]

# Sort by address ascending; rows with an unparseable address sort last.
parsed.sort(key=lambda r: (addr_int(r['addr']) is None, addr_int(r['addr']) or 0))

done = sum(1 for r in parsed if r['status'] == DONE)
total = len(parsed)
remaining = total - done
pct = round(done / total * 100, 1)

# Column widths matching the existing file (fixed-width padding).
NAME_W, XREF_W, LEN_W, ADDR_W, SIG_W = 49, 6, 6, 13, 205


def short_addr(addr_str):
    """Strip the Mach-O image base so the report shows the file-relative address (0x100031820 ->
    0x31820)."""
    value = addr_int(addr_str)
    if value is None:
        return addr_str
    if value >= IMAGE_BASE:
        value -= IMAGE_BASE
    return f'0x{value:x}'


def normalise_pointers(sig):
    """Move the pointer/reference sigil to the right of the type per the project style: ``T * name``
    becomes ``T *name`` and ``T & name`` becomes ``T &name`` (leaving abstract ``T *`` parameters and
    the block caret untouched)."""
    # Drop Ghidra's calling-convention keywords — they are decompiler annotations, not part of the
    # reconstructed C/C++ signature.
    sig = re.sub(r'\b__(cdecl|thiscall|stdcall|fastcall)\b\s*', '', sig)
    # Attach a ' * name' / ' & name' sigil to the following identifier.
    sig = re.sub(r'\s+([*&])\s+(\w)', r' \1\2', sig)
    # A trailing abstract pointer/ref keeps a single leading space (``T *``), collapse doubles.
    sig = re.sub(r'\s+([*&])\s*(?=[,)])', r' \1', sig)
    # The Objective-C object type is spelled `id`, never Ghidra's `ID`.
    sig = re.sub(r'\bID\b', 'id', sig)
    return sig


def fmt(r):
    name = f'`{r["name"]}`'.ljust(NAME_W)
    status = r['status'].center(18)
    xref = str(r['xref']).rjust(XREF_W)
    length = str(r['length']).rjust(LEN_W)
    addr = f'`{short_addr(r["addr"])}`'.ljust(ADDR_W)
    sig = f'`{normalise_pointers(r["sig"])}`'.ljust(SIG_W)
    return f'| {name} | {status} | {xref} | {length} | {addr} | {sig} |\n'


out = []
for idx, ln in enumerate(head_lines):
    if ln.startswith('Total:'):
        out.append(f'Total: {total} — {done} done, {remaining} remaining ({pct}% done).\n')
    else:
        out.append(ln)
out.extend(fmt(r) for r in parsed)

if '--audit-only' not in sys.argv:
    with open(PATH, 'w', encoding='utf-8') as fh:
        fh.writelines(out)


def collect_defined_addresses():
    """Return the set of image-base-stripped addresses that carry an @ghidraAddress tag preceding an
    actual definition (function body) in source. A bare header declaration does NOT count."""
    tag_re = re.compile(r'@ghidraAddress\s+(0x[0-9a-fA-F]+)')
    defined = set()
    for pattern in SOURCE_GLOBS:
        for path in glob.glob(pattern, recursive=True):
            try:
                with open(path, encoding='utf-8', errors='replace') as fh:
                    text = fh.readlines()
            except OSError:
                continue
            for i, line in enumerate(text):
                m = tag_re.search(line)
                if not m or not tag_defines(text, i):
                    continue
                value = int(m.group(1), 16)
                defined.add(value)
                defined.add(value - IMAGE_BASE if value >= IMAGE_BASE else value + IMAGE_BASE)
    return defined


def _ghidra_entry(raw_addr):
    """Return the entry address (int) of the function at raw_addr per the MCP bridge, or None when no
    function exists there. Used to prove an @ghidraAddress tag points at a real function."""
    query = urllib.parse.urlencode({'address': raw_addr, 'program': GHIDRA_PROGRAM})
    try:
        with urllib.request.urlopen(f'{GHIDRA_HTTP}/get_function_by_address?{query}', timeout=5) as f:
            text = f.read().decode('utf-8', 'replace')
    except (urllib.error.URLError, OSError):
        return None
    m = re.search(r'Entry:\s*([0-9a-fA-F]+)', text)
    return int(m.group(1), 16) if m else None


def collect_source_tags():
    """Every @ghidraAddress value tagged in source, with the file:line and whether it precedes a
    definition body. Returns a list of (value, path, lineno, is_def)."""
    tag_re = re.compile(r'@ghidraAddress\s+(0x[0-9a-fA-F]+)')
    tags = []
    for pattern in SOURCE_GLOBS:
        for path in glob.glob(pattern, recursive=True):
            try:
                with open(path, encoding='utf-8', errors='replace') as fh:
                    text = fh.readlines()
            except OSError:
                continue
            for i, line in enumerate(text):
                m = tag_re.search(line)
                if m:
                    tags.append((int(m.group(1), 16), path, i + 1, tag_defines(text, i)))
    return tags


def audit_invented_addresses():
    """Fail when a source @ghidraAddress tag does not point at a real function entry in Ghidra — the
    signature of an invented address (a fabricated block handler, a stray address landing inside an
    unrelated function's body). Requires the MCP bridge; skips silently when offline so an offline
    regen is not blocked. Block-literal tags legitimately point mid-function (the block invoke is its
    own function, but its entry is what Ghidra returns), so a tag is accepted when Ghidra resolves it
    to a function whose entry equals the tagged address OR the tag precedes a real definition body."""
    if not _ghidra_probe():
        return 0
    # Only addresses in the executable __text segment name functions; a tag whose address is in a
    # data segment annotates a global/constant (a DAT_ float, a cfstring, a vtable) and is expected
    # not to resolve to a function, so it is not an invention.
    text_lo, text_hi = IMAGE_BASE + 0x480c, IMAGE_BASE + 0x24a064
    # A tag is flagged only when NO function in the program contains the address (Ghidra returns no
    # function) — the strong invention signal, as with a fabricated block handler. A tag that lands
    # inside a real function but is not its entry is usually a legitimate inline block invoke that
    # Ghidra did not split into its own function, so it is not flagged.
    invented = []
    for value, path, lineno, _is_def in collect_source_tags():
        raw = value if value >= IMAGE_BASE else value + IMAGE_BASE
        if not (text_lo <= raw < text_hi):
            continue
        entry = _ghidra_entry(f'0x{raw:x}')
        if entry is not None and entry == raw:
            continue  # a real function entry — fine.
        # A truncation is the high-value catch: the tag dropped a hex digit, so the short address
        # lands in the wrong function but the digit-restored form is a real entry. Try prepending a
        # 0x10/0x100 nibble (the common 0x1_0000_0000-relative truncations seen in the tree).
        short = raw - IMAGE_BASE
        for restored in (short | 0x100000, short | 0x1000000, short | 0x10000000):
            if restored != short and text_lo <= restored + IMAGE_BASE < text_hi \
                    and _ghidra_entry(f'0x{restored + IMAGE_BASE:x}') == restored + IMAGE_BASE:
                invented.append((value, path, lineno,
                                 f'looks truncated — 0x{restored:x} is a real function entry'))
                break
        else:
            if entry is None:
                invented.append((value, path, lineno, 'no function contains this __text address'))
    if invented:
        print(f'AUDIT: {len(invented)} INVENTED @ghidraAddress tag(s) — not a real function entry:')
        for value, path, lineno, why in invented[:40]:
            print(f'  {value:#x} {path}:{lineno} — {why}')
    return len(invented)


def audit(rows_):
    """Verify every done entry has a source definition and a real (non-placeholder) signature."""
    defined = DEFINED_ADDRS
    missing_def = []
    placeholder_sig = []
    for r in rows_:
        if r['status'] != DONE:
            continue
        try:
            addr = int(r['addr'], 16)
        except ValueError:
            continue
        short = addr - IMAGE_BASE if addr >= IMAGE_BASE else addr
        if addr not in defined and short not in defined:
            missing_def.append((r['addr'], r['name']))
        # A leftover synthesized block placeholder means the signature was never given the real
        # reconstructed block type.
        if '_block *' in r['sig'] or r['sig'].startswith('undefined'):
            placeholder_sig.append((r['addr'], r['name'], r['sig']))
    if missing_def:
        print(f'AUDIT: {len(missing_def)} done entries with NO source definition:')
        for addr, name in missing_def[:40]:
            print(f'  {addr} {name}')
    if placeholder_sig:
        print(f'AUDIT: {len(placeholder_sig)} done entries with a placeholder/undefined signature:')
        for addr, name, sig in placeholder_sig[:40]:
            print(f'  {addr} {name}: {sig}')
    if not missing_def and not placeholder_sig:
        print('AUDIT: OK — every done entry has a source definition and a real signature.')
    return len(missing_def) + len(placeholder_sig)


audit_problems = audit(parsed)
if '--check-addresses' in sys.argv:
    audit_invented_addresses()

print(f'total={total} done={done} remaining={remaining} pct={pct}')
