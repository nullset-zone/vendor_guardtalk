/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#include "FacePipeline.h"

#include <cstdio>
#include <vector>

using guardtalk::camera::FacePipeline;
using guardtalk::camera::Persona;
using guardtalk::camera::Quality;

static int test_disabled_passthrough() {
    FacePipeline pipeline;
    pipeline.setEnabled(false);
    std::vector<uint8_t> y(64 * 64, 100);
    pipeline.processYuv420(y.data(), 64, nullptr, 0, nullptr, 0, 64, 64);
    if (y[32 * 64 + 32] != 100) {
        std::fprintf(stderr, "disabled pipeline modified pixels\n");
        return 1;
    }
    return 0;
}

static int test_enabled_modifies_center() {
    FacePipeline pipeline;
    pipeline.setEnabled(true);
    pipeline.setPersona(Persona::kWarm);
    pipeline.setQuality(Quality::kBalanced);
    std::vector<uint8_t> y(128 * 128, 80);
    const uint8_t before = y[54 * 128 + 64];
    pipeline.processYuv420(y.data(), 128, nullptr, 0, nullptr, 0, 128, 128);
    if (y[54 * 128 + 64] == before) {
        std::fprintf(stderr, "enabled pipeline did not modify center pixel\n");
        return 1;
    }
    return 0;
}

int main() {
    if (test_disabled_passthrough() != 0) {
        return 1;
    }
    if (test_enabled_modifies_center() != 0) {
        return 1;
    }
    std::printf("guardtalk_face_pipeline_test: PASS\n");
    return 0;
}
