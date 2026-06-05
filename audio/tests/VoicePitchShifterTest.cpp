/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#include "VoicePitchShifter.h"

#include <cmath>
#include <cstdio>
#include <cstring>

using guardtalk::audio::VoicePitchShifter;
using guardtalk::audio::VoicePreset;

static bool nearEqual(float a, float b, float eps = 0.001f) {
    return std::fabs(a - b) <= eps;
}

static int test_bypass_natural() {
    VoicePitchShifter shifter;
    shifter.setPreset(VoicePreset::kNatural);
    float buffer[4] = {0.1f, -0.2f, 0.3f, -0.4f};
    const float expected[4] = {0.1f, -0.2f, 0.3f, -0.4f};
    shifter.process(buffer, 2, 2);
    for (int i = 0; i < 4; ++i) {
        if (!nearEqual(buffer[i], expected[i])) {
            std::fprintf(stderr, "natural preset modified sample %d\n", i);
            return 1;
        }
    }
    return 0;
}

static int test_disabled() {
    VoicePitchShifter shifter;
    shifter.setPreset(VoicePreset::kDeep);
    shifter.setEnabled(false);
    float buffer[2] = {0.5f, -0.5f};
    shifter.process(buffer, 1, 2);
    if (!nearEqual(buffer[0], 0.5f) || !nearEqual(buffer[1], -0.5f)) {
        std::fprintf(stderr, "disabled shifter modified audio\n");
        return 1;
    }
    return 0;
}

static int test_deep_changes_output() {
    VoicePitchShifter shifter;
    shifter.setPreset(VoicePreset::kDeep);
    float buffer[8];
    for (int i = 0; i < 8; ++i) {
        buffer[i] = static_cast<float>(i) * 0.1f - 0.35f;
    }
    float copy[8];
    std::memcpy(copy, buffer, sizeof(copy));
    shifter.process(buffer, 4, 2);
    bool changed = false;
    for (int i = 0; i < 8; ++i) {
        if (!nearEqual(buffer[i], copy[i])) {
            changed = true;
            break;
        }
    }
    if (!changed) {
        std::fprintf(stderr, "deep preset did not alter samples\n");
        return 1;
    }
    return 0;
}

int main() {
    if (test_bypass_natural() != 0) {
        return 1;
    }
    if (test_disabled() != 0) {
        return 1;
    }
    if (test_deep_changes_output() != 0) {
        return 1;
    }
    std::printf("guardtalk_voice_pitch_shifter_test: PASS\n");
    return 0;
}
