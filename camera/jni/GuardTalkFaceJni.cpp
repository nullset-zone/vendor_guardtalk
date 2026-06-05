/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

#include <jni.h>

#include <android/log.h>

#include "FacePipeline.h"

#define LOG_TAG "GuardTalkFaceJni"

namespace {

guardtalk::camera::FacePipeline gPipeline;

void* getDirectAddress(JNIEnv* env, jobject buffer) {
    if (buffer == nullptr) {
        return nullptr;
    }
    return env->GetDirectBufferAddress(buffer);
}

}  // namespace

extern "C" JNIEXPORT void JNICALL
Java_androidx_camera_extensions_impl_GuardTalkFaceBridge_nativeProcessYuv420(
        JNIEnv* env, jclass /*clazz*/, jobject yBuffer, jint yStride, jobject uBuffer, jint uStride,
        jobject vBuffer, jint vStride, jint width, jint height) {
    void* yPtr = getDirectAddress(env, yBuffer);
    if (yPtr == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "missing direct Y plane");
        return;
    }

    gPipeline.processYuv420(static_cast<uint8_t*>(yPtr), yStride,
                            static_cast<uint8_t*>(getDirectAddress(env, uBuffer)), uStride,
                            static_cast<uint8_t*>(getDirectAddress(env, vBuffer)), vStride, width,
                            height);
}
