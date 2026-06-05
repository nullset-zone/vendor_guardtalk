/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#include "VoicePitchShifter.h"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace guardtalk {
namespace audio {

VoicePitchShifter::VoicePitchShifter()
    : mPreset(VoicePreset::kNatural),
      mEnabled(true),
      mPitchRatio(1.0f),
      mReadPosition(0.0f),
      mRingLength(0) {
    std::memset(mRing, 0, sizeof(mRing));
}

void VoicePitchShifter::reset() {
    mReadPosition = 0.0f;
    mRingLength = 0;
    std::memset(mRing, 0, sizeof(mRing));
}

void VoicePitchShifter::setPreset(VoicePreset preset) {
    if (preset < VoicePreset::kNatural || preset >= VoicePreset::kCount) {
        preset = VoicePreset::kNatural;
    }
    mPreset = preset;
    mPitchRatio = pitchRatioForPreset(preset);
    reset();
}

void VoicePitchShifter::setEnabled(bool enabled) {
    mEnabled = enabled;
    if (!enabled) {
        reset();
    }
}

bool VoicePitchShifter::isValidPreset(int32_t value) {
    return value >= 0 && value < static_cast<int32_t>(VoicePreset::kCount);
}

float VoicePitchShifter::pitchRatioForPreset(VoicePreset preset) {
    switch (preset) {
        case VoicePreset::kDeep:
            return 0.82f;
        case VoicePreset::kBright:
            return 1.14f;
        case VoicePreset::kMasked:
            return 0.94f;
        case VoicePreset::kRobot:
            return 0.88f;
        case VoicePreset::kNatural:
        default:
            return 1.0f;
    }
}

float VoicePitchShifter::readSample(const float* channelBase, size_t channelCount,
                                    float position) const {
    const size_t index = static_cast<size_t>(position);
    const float frac = position - static_cast<float>(index);
    const float s0 = channelBase[index * channelCount];
    const float s1 = channelBase[std::min(index + 1, mRingLength - 1) * channelCount];
    return s0 + (s1 - s0) * frac;
}

void VoicePitchShifter::process(float* samples, size_t frameCount, int channelCount) {
    if (samples == nullptr || frameCount == 0 || channelCount <= 0) {
        return;
    }

    if (!mEnabled || mPreset == VoicePreset::kNatural || std::abs(mPitchRatio - 1.0f) < 0.001f) {
        return;
    }

    const size_t channels = static_cast<size_t>(channelCount);
    const size_t cappedFrames = std::min(frameCount, kMaxRingFrames);
    mRingLength = cappedFrames;

    for (size_t frame = 0; frame < cappedFrames; ++frame) {
        for (size_t ch = 0; ch < channels; ++ch) {
            mRing[frame * channels + ch] = samples[frame * channels + ch];
        }
    }

    for (size_t frame = 0; frame < cappedFrames; ++frame) {
        for (size_t ch = 0; ch < channels; ++ch) {
            float value = readSample(mRing, channels, mReadPosition);
            if (mPreset == VoicePreset::kRobot) {
                const float crushed = std::round(value * 32.0f) / 32.0f;
                value = value * 0.65f + crushed * 0.35f;
            } else if (mPreset == VoicePreset::kMasked) {
                value *= 0.92f;
            }
            samples[frame * channels + ch] =
                    std::clamp(value, -1.0f, 1.0f);
        }
        mReadPosition += mPitchRatio;
        if (mReadPosition >= static_cast<float>(cappedFrames - 1)) {
            mReadPosition -= static_cast<float>(cappedFrames - 1);
        }
    }
}

}  // namespace audio
}  // namespace guardtalk
