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

package androidx.camera.extensions.impl.advanced;

import android.annotation.SuppressLint;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.util.Pair;
import android.util.Range;
import android.util.Size;

import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * Non-throwing stub advanced extender implementation for eyes free videography.
 *
 * <p>GuardTalk does not implement the eyes-free-videography extension. The class exists only
 * because the CameraX/Camera2 reflection contract enumerates advanced extenders by name. It
 * previously threw {@link RuntimeException} on every call, which caused proprietary camera
 * services (e.g. {@code ProxyCameraProviderService}) to crash-loop with an NPE when they probed
 * the extension during camera enumeration. All methods now return safe "unavailable" defaults so
 * enumeration completes cleanly.
 *
 * @since 1.5
 */
@SuppressLint("UnknownNullness")
public class EyesFreeVideographyAdvancedExtenderImpl implements AdvancedExtenderImpl {
    public EyesFreeVideographyAdvancedExtenderImpl() {
    }

    @Override
    public boolean isExtensionAvailable(String cameraId,
            Map<String, CameraCharacteristics> characteristicsMap) {
        return false;
    }

    @Override
    public void init(String cameraId,
            Map<String, CameraCharacteristics> characteristicsMap) {
    }

    @Override
    public Range<Long> getEstimatedCaptureLatencyRange(
            String cameraId, Size size, int imageFormat) {
        return null;
    }

    @Override
    public Map<Integer, List<Size>> getSupportedPreviewOutputResolutions(
            String cameraId) {
        return Collections.emptyMap();
    }


    @Override
    public Map<Integer, List<Size>> getSupportedCaptureOutputResolutions(
            String cameraId) {
        return Collections.emptyMap();
    }

    @Override
    public Map<Integer, List<Size>> getSupportedPostviewResolutions(
            Size captureSize) {
        return Collections.emptyMap();
    }

    @Override
    public List<Size> getSupportedYuvAnalysisResolutions(
            String cameraId) {
        return null;
    }

    @Override
    public SessionProcessorImpl createSessionProcessor() {
        return null;
    }

    @Override
    public List<CaptureRequest.Key> getAvailableCaptureRequestKeys() {
        return Collections.emptyList();
    }

    @Override
    public List<CaptureResult.Key> getAvailableCaptureResultKeys() {
        return Collections.emptyList();
    }

    @Override
    public boolean isCaptureProcessProgressAvailable() {
        return false;
    }

    @Override
    public boolean isPostviewAvailable() {
        return false;
    }

    @Override
    public List<Pair<CameraCharacteristics.Key, Object>>
            getAvailableCharacteristicsKeyValues() {
        return Collections.emptyList();
    }
}
