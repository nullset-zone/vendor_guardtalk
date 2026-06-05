/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#pragma once

#include <cstddef>
#include <cstdint>

namespace guardtalk {
namespace camera {

enum class Persona : int32_t {
    kNeutral = 0,
    kSoft = 1,
    kBold = 2,
    kCool = 3,
    kWarm = 4,
    kCount = 5,
};

enum class Quality : int32_t {
    kLite = 0,
    kBalanced = 1,
    kMax = 2,
};

class FacePipeline {
  public:
    FacePipeline();

    void syncFromProperties();
    void setEnabled(bool enabled);
    void setPersona(Persona persona);
    void setQuality(Quality quality);

    bool enabled() const { return mEnabled; }

    /** In-place YUV_420_888 processing on three plane buffers. */
    void processYuv420(uint8_t* y, int yStride, uint8_t* u, int uStride, uint8_t* v, int vStride,
                       int width, int height);

    static bool isValidPersona(int32_t value);
    static bool isValidQuality(int32_t value);

  private:
    struct RgbTint {
        int16_t r;
        int16_t g;
        int16_t b;
    };

    static RgbTint tintForPersona(Persona persona);
    void applyPersonaMask(uint8_t* y, int yStride, int width, int height, float centerX,
                          float centerY, float radiusX, float radiusY, const RgbTint& tint);

    bool mEnabled;
    Persona mPersona;
    Quality mQuality;
};

}  // namespace camera
}  // namespace guardtalk
