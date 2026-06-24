/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package androidx.camera.extensions.impl;

import android.content.Context;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.util.Pair;
import android.util.Range;
import android.util.Size;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Collections;
import java.util.List;

/**
 * Non-throwing stub for HDR image capture use case.
 *
 * <p>See {@link BeautyImageCaptureExtenderImpl} for the rationale. GuardTalk implements the HDR
 * extension via the advanced extender path
 * ({@link androidx.camera.extensions.impl.advanced.HdrAdvancedExtenderImpl}).
 *
 * @since 1.0
 */
public final class HdrImageCaptureExtenderImpl implements ImageCaptureExtenderImpl {
    public HdrImageCaptureExtenderImpl() {}

    @Override
    public boolean isExtensionAvailable(@NonNull String cameraId,
            @Nullable CameraCharacteristics cameraCharacteristics) {
        return false;
    }

    @Override
    public void init(String cameraId, CameraCharacteristics cameraCharacteristics) {
    }

    @Override
    public CaptureProcessorImpl getCaptureProcessor() {
        return null;
    }

    @Override
    public List<CaptureStageImpl> getCaptureStages() {
        return Collections.emptyList();
    }

    @Override
    public int getMaxCaptureStage() {
        return 0;
    }

    @Override
    public void onInit(String cameraId, CameraCharacteristics cameraCharacteristics,
            Context context) {
    }

    @Override
    public void onDeInit() {
    }

    @Override
    public CaptureStageImpl onPresetSession() {
        return null;
    }

    @Override
    public CaptureStageImpl onEnableSession() {
        return null;
    }

    @Override
    public CaptureStageImpl onDisableSession() {
        return null;
    }

    @Override
    public List<Pair<Integer, Size[]>> getSupportedResolutions() {
        return null;
    }

    @Override
    public List<Pair<Integer, Size[]>> getSupportedPostviewResolutions(Size captureSize) {
        return null;
    }

    @Nullable
    @Override
    public Range<Long> getEstimatedCaptureLatencyRange(@NonNull Size captureOutputSize) {
        return null;
    }

    @Nullable
    @Override
    public List<CaptureRequest.Key> getAvailableCaptureRequestKeys() {
        return Collections.emptyList();
    }

    @Nullable
    @Override
    public List<CaptureResult.Key> getAvailableCaptureResultKeys() {
        return Collections.emptyList();
    }

    @Override
    public int onSessionType() {
        return -1;
    }

    @Override
    public boolean isCaptureProcessProgressAvailable() {
        return false;
    }

    @Override
    public Pair<Long, Long> getRealtimeCaptureLatency() {
        return null;
    }

    @Override
    public boolean isPostviewAvailable() {
        return false;
    }
}
