/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#pragma once

#include <cstddef>
#include <cstdint>

namespace guardtalk {
namespace audio {

/** Voice pitch / timbre presets for mic capture preprocessing. */
enum class VoicePreset : int32_t {
    kNatural = 0,
    kDeep = 1,
    kBright = 2,
    kMasked = 3,
    kRobot = 4,
    kCount = 5,
};

class VoicePitchShifter {
  public:
    VoicePitchShifter();

    void reset();
    void setPreset(VoicePreset preset);
    void setEnabled(bool enabled);

    VoicePreset preset() const { return mPreset; }
    bool enabled() const { return mEnabled; }

    /** Process interleaved float PCM [-1, 1]. in may equal out. */
    void process(float* samples, size_t frameCount, int channelCount);

    static float pitchRatioForPreset(VoicePreset preset);
    static bool isValidPreset(int32_t value);

  private:
    float readSample(const float* channelBase, size_t channelCount, float position) const;

    VoicePreset mPreset;
    bool mEnabled;
    float mPitchRatio;
    float mReadPosition;
    size_t mRingLength;
    static constexpr size_t kMaxRingFrames = 4096;
    float mRing[kMaxRingFrames];
};

}  // namespace audio
}  // namespace guardtalk
