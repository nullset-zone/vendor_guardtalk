/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#include "FacePipeline.h"

#include <algorithm>
#include <cmath>

#ifdef __ANDROID__
#include <cutils/properties.h>
#endif

namespace guardtalk {
namespace camera {

namespace {

constexpr const char* kPropEnabled = "persist.vendor.guardtalk.face.enabled";
constexpr const char* kPropPersona = "persist.vendor.guardtalk.face.persona";
constexpr const char* kPropQuality = "persist.vendor.guardtalk.face.quality";

}  // namespace

FacePipeline::FacePipeline()
    : mEnabled(false), mPersona(Persona::kNeutral), mQuality(Quality::kBalanced) {}

void FacePipeline::syncFromProperties() {
#ifdef __ANDROID__
    mEnabled = property_get_bool(kPropEnabled, false);
    const int persona = property_get_int32(kPropPersona, 0);
    const int quality = property_get_int32(kPropQuality, 1);
    mPersona = isValidPersona(persona) ? static_cast<Persona>(persona) : Persona::kNeutral;
    mQuality = isValidQuality(quality) ? static_cast<Quality>(quality) : Quality::kBalanced;
#endif
}

void FacePipeline::setEnabled(bool enabled) {
    mEnabled = enabled;
}

void FacePipeline::setPersona(Persona persona) {
    if (!isValidPersona(static_cast<int32_t>(persona))) {
        persona = Persona::kNeutral;
    }
    mPersona = persona;
}

void FacePipeline::setQuality(Quality quality) {
    if (!isValidQuality(static_cast<int32_t>(quality))) {
        quality = Quality::kBalanced;
    }
    mQuality = quality;
}

bool FacePipeline::isValidPersona(int32_t value) {
    return value >= 0 && value < static_cast<int32_t>(Persona::kCount);
}

bool FacePipeline::isValidQuality(int32_t value) {
    return value >= 0 && value <= static_cast<int32_t>(Quality::kMax);
}

FacePipeline::RgbTint FacePipeline::tintForPersona(Persona persona) {
    switch (persona) {
        case Persona::kSoft:
            return {8, 10, 14};
        case Persona::kBold:
            return {-6, -8, 10};
        case Persona::kCool:
            return {-4, 2, 12};
        case Persona::kWarm:
            return {10, 4, -8};
        case Persona::kNeutral:
        default:
            return {0, 0, 0};
    }
}

void FacePipeline::applyPersonaMask(uint8_t* y, int yStride, int width, int height, float centerX,
                                  float centerY, float radiusX, float radiusY,
                                  const RgbTint& tint) {
    const int yCenter = static_cast<int>(centerY * static_cast<float>(height));
    const int xCenter = static_cast<int>(centerX * static_cast<float>(width));
    const int rx = std::max(8, static_cast<int>(radiusX * static_cast<float>(width)));
    const int ry = std::max(10, static_cast<int>(radiusY * static_cast<float>(height)));

    const int y0 = std::max(0, yCenter - ry);
    const int y1 = std::min(height, yCenter + ry);
    const int x0 = std::max(0, xCenter - rx);
    const int x1 = std::min(width, xCenter + rx);

    for (int row = y0; row < y1; ++row) {
        uint8_t* rowPtr = y + row * yStride;
        const float ny = (static_cast<float>(row - yCenter)) / static_cast<float>(ry);
        for (int col = x0; col < x1; ++col) {
            const float nx = (static_cast<float>(col - xCenter)) / static_cast<float>(rx);
            const float dist2 = nx * nx + ny * ny;
            if (dist2 > 1.0f) {
                continue;
            }
            const float falloff = 1.0f - dist2;
            const int delta = static_cast<int>((tint.r + tint.g + tint.b) * falloff * 0.35f);
            rowPtr[col] = static_cast<uint8_t>(std::clamp(static_cast<int>(rowPtr[col]) + delta, 0,
                                                          255));
        }
    }
}

void FacePipeline::processYuv420(uint8_t* y, int yStride, uint8_t* u, int uStride, uint8_t* v,
                                   int vStride, int width, int height) {
    (void)u;
    (void)uStride;
    (void)v;
    (void)vStride;

    if (y == nullptr || width <= 0 || height <= 0 || yStride < width) {
        return;
    }

#ifdef __ANDROID__
    syncFromProperties();
#endif
    if (!mEnabled || mPersona == Persona::kNeutral) {
        return;
    }

    float centerX = 0.5f;
    float centerY = 0.42f;
    float radiusX = 0.22f;
    float radiusY = 0.28f;

    switch (mQuality) {
        case Quality::kLite:
            radiusX = 0.18f;
            radiusY = 0.22f;
            break;
        case Quality::kMax:
            radiusX = 0.26f;
            radiusY = 0.32f;
            centerY = 0.40f;
            break;
        case Quality::kBalanced:
        default:
            break;
    }

    applyPersonaMask(y, yStride, width, height, centerX, centerY, radiusX, radiusY,
                     tintForPersona(mPersona));
}

}  // namespace camera
}  // namespace guardtalk
