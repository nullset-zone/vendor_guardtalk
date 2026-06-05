/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#define LOG_TAG "AHAL_GuardTalkVoiceSw"

#include "GuardTalkVoiceSw.h"

#include <algorithm>
#include <cstdlib>

#include <android-base/logging.h>
#include <cutils/properties.h>
#include <fmq/AidlMessageQueue.h>

using aidl::android::hardware::audio::common::getChannelCount;
using aidl::android::hardware::audio::effect::Descriptor;
using aidl::android::hardware::audio::effect::GuardTalkVoiceSw;
using aidl::android::hardware::audio::effect::IEffect;
using aidl::android::media::audio::common::AudioUuid;

namespace {

constexpr const char* kPropEnabled = "persist.vendor.guardtalk.voice.enabled";
constexpr const char* kPropPreset = "persist.vendor.guardtalk.voice.preset";

bool readEnabledProperty() {
    return property_get_bool(kPropEnabled, true);
}

guardtalk::audio::VoicePreset readPresetProperty() {
    const int preset = property_get_int32(kPropPreset, 0);
    if (!guardtalk::audio::VoicePitchShifter::isValidPreset(preset)) {
        return guardtalk::audio::VoicePreset::kNatural;
    }
    return static_cast<guardtalk::audio::VoicePreset>(preset);
}

}  // namespace

namespace aidl::android::hardware::audio::effect {

media::audio::common::AudioUuid getGuardTalkVoiceTypeUuid() {
    return AudioUuid{.timeLow = static_cast<int32_t>(0xdec3b103u),
                     .timeMid = 0xb1a2,
                     .timeHiAndVersion = 0x4034,
                     .clockSeq = 0x8c7d,
                     .node = {0x9e, 0x0f, 0x12, 0x34, 0x01, 0x00}};
}

media::audio::common::AudioUuid getGuardTalkVoiceImplUuid() {
    return AudioUuid{.timeLow = static_cast<int32_t>(0xdec3b103u),
                     .timeMid = 0xb1a2,
                     .timeHiAndVersion = 0x4034,
                     .clockSeq = 0x8c7d,
                     .node = {0x9e, 0x0f, 0x12, 0x34, 0x01, 0x01}};
}

const std::string GuardTalkVoiceSw::kEffectName = "guardtalk_voice_filter";

const Descriptor GuardTalkVoiceSw::kDescriptor = {
        .common = {.id = {.type = getGuardTalkVoiceTypeUuid(),
                          .uuid = getGuardTalkVoiceImplUuid(),
                          .proxy = std::nullopt},
                   .flags = {.type = Flags::Type::PRE_PROC,
                             .insert = Flags::Insert::LAST,
                             .volume = Flags::Volume::NONE},
                   .name = GuardTalkVoiceSw::kEffectName,
                   .implementor = "GuardTalkOS"}};

extern "C" binder_exception_t createEffect(const AudioUuid* in_impl_uuid,
                                           std::shared_ptr<IEffect>* instanceSpp) {
    if (!in_impl_uuid || *in_impl_uuid != getGuardTalkVoiceImplUuid()) {
        LOG(ERROR) << __func__ << " uuid not supported";
        return EX_ILLEGAL_ARGUMENT;
    }
    if (instanceSpp) {
        *instanceSpp = ndk::SharedRefBase::make<GuardTalkVoiceSw>();
        return EX_NONE;
    }
    LOG(ERROR) << __func__ << " invalid input parameter";
    return EX_ILLEGAL_ARGUMENT;
}

extern "C" binder_exception_t queryEffect(const AudioUuid* in_impl_uuid, Descriptor* _aidl_return) {
    if (!in_impl_uuid || *in_impl_uuid != getGuardTalkVoiceImplUuid()) {
        LOG(ERROR) << __func__ << " uuid not supported";
        return EX_ILLEGAL_ARGUMENT;
    }
    *_aidl_return = GuardTalkVoiceSw::kDescriptor;
    return EX_NONE;
}

ndk::ScopedAStatus GuardTalkVoiceSw::getDescriptor(Descriptor* _aidl_return) {
    *_aidl_return = kDescriptor;
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus GuardTalkVoiceSw::setParameterSpecific(const Parameter::Specific& /*specific*/) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_ILLEGAL_ARGUMENT,
                                                            "EffectNotSupported");
}

ndk::ScopedAStatus GuardTalkVoiceSw::getParameterSpecific(const Parameter::Id& /*id*/,
                                                          Parameter::Specific* /*specific*/) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_ILLEGAL_ARGUMENT,
                                                            "EffectNotSupported");
}

std::shared_ptr<EffectContext> GuardTalkVoiceSw::createContext(const Parameter::Common& common) {
    if (!mContext) {
        mContext = std::make_shared<GuardTalkVoiceContext>(1, common);
        syncFromProperties();
    }
    return mContext;
}

RetCode GuardTalkVoiceSw::releaseContext() {
    mContext.reset();
    return RetCode::SUCCESS;
}

void GuardTalkVoiceSw::syncFromProperties() {
    if (!mContext) {
        return;
    }
    mContext->shifter.setEnabled(readEnabledProperty());
    mContext->shifter.setPreset(readPresetProperty());
}

IEffect::Status GuardTalkVoiceSw::effectProcessImpl(float* in, float* out, int samples) {
    if (!mContext || in == nullptr || out == nullptr || samples <= 0) {
        return {STATUS_BAD_VALUE, 0, 0};
    }

    syncFromProperties();

    const int channelCount = std::max(
            1, static_cast<int>(getChannelCount(mContext->getCommon().input.base.channelMask)));
    const int frameCount = samples / channelCount;
    if (frameCount <= 0) {
        return {STATUS_BAD_VALUE, 0, 0};
    }

    if (in != out) {
        std::copy(in, in + samples, out);
    }

    mContext->shifter.process(out, static_cast<size_t>(frameCount), channelCount);
    return {STATUS_OK, samples, samples};
}

}  // namespace aidl::android::hardware::audio::effect
