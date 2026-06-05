/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#pragma once

#include <memory>

#include <aidl/android/hardware/audio/effect/BnEffect.h>
#include <fmq/AidlMessageQueue.h>

#include "dsp/VoicePitchShifter.h"
#include "effect-impl/EffectImpl.h"

namespace aidl::android::hardware::audio::effect {

class GuardTalkVoiceContext final : public EffectContext {
  public:
    GuardTalkVoiceContext(int statusDepth, const Parameter::Common& common)
        : EffectContext(statusDepth, common) {}

    guardtalk::audio::VoicePitchShifter shifter;
};

class GuardTalkVoiceSw final : public EffectImpl {
  public:
    static const std::string kEffectName;
    static const Descriptor kDescriptor;

    GuardTalkVoiceSw() = default;
    ~GuardTalkVoiceSw() override { cleanUp(); }

    ndk::ScopedAStatus getDescriptor(Descriptor* _aidl_return) override;
    ndk::ScopedAStatus setParameterSpecific(const Parameter::Specific& specific)
            REQUIRES(mImplMutex) override;
    ndk::ScopedAStatus getParameterSpecific(const Parameter::Id& id, Parameter::Specific* specific)
            REQUIRES(mImplMutex) override;

    std::shared_ptr<EffectContext> createContext(const Parameter::Common& common)
            REQUIRES(mImplMutex) override;
    RetCode releaseContext() REQUIRES(mImplMutex) override;

    std::string getEffectName() override { return kEffectName; }
    IEffect::Status effectProcessImpl(float* in, float* out, int samples)
            REQUIRES(mImplMutex) override;

  private:
    void syncFromProperties() REQUIRES(mImplMutex);

    std::shared_ptr<GuardTalkVoiceContext> mContext GUARDED_BY(mImplMutex);
};

media::audio::common::AudioUuid getGuardTalkVoiceTypeUuid();
media::audio::common::AudioUuid getGuardTalkVoiceImplUuid();

}  // namespace aidl::android::hardware::audio::effect
