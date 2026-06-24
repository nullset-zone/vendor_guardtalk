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
import android.util.Pair;
import android.util.Size;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.List;

/**
 * Non-throwing stub for bokeh preview use case.
 *
 * <p>See {@link BeautyPreviewExtenderImpl} for the rationale. GuardTalk implements the bokeh
 * extension via the advanced extender path
 * ({@link androidx.camera.extensions.impl.advanced.BokehAdvancedExtenderImpl}).
 *
 * @since 1.0
 */
public final class BokehPreviewExtenderImpl implements PreviewExtenderImpl {
    public BokehPreviewExtenderImpl() {}

    @Override
    public boolean isExtensionAvailable(@NonNull String cameraId,
            @Nullable CameraCharacteristics cameraCharacteristics) {
        return false;
    }

    @Override
    public void init(String cameraId, CameraCharacteristics cameraCharacteristics) {
    }

    @Override
    public CaptureStageImpl getCaptureStage() {
        return null;
    }

    @Override
    public ProcessorType getProcessorType() {
        return ProcessorType.PROCESSOR_TYPE_NONE;
    }

    @Override
    public ProcessorImpl getProcessor() {
        return null;
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
    public int onSessionType() {
        return -1;
    }
}
