/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

package androidx.camera.extensions.impl.advanced;

import androidx.camera.extensions.impl.GuardTalkFaceBridge;
import androidx.camera.extensions.impl.advanced.BaseAdvancedExtenderImpl.BaseAdvancedSessionProcessor;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.ImageFormat;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.DynamicRangeProfiles;
import android.media.Image;
import android.media.ImageWriter;
import android.os.Build;
import android.util.Log;
import android.util.Size;

import androidx.annotation.GuardedBy;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

@SuppressLint("UnknownNullness")
public class BeautyAdvancedExtenderImpl extends BaseAdvancedExtenderImpl {

    private static final String TAG = "GuardTalkBeautyExtender";

    public BeautyAdvancedExtenderImpl() {}

    @Override
    public boolean isExtensionAvailable(String cameraId,
            Map<String, CameraCharacteristics> characteristicsMap) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false;
        }
        CameraCharacteristics characteristics = characteristicsMap.get(cameraId);
        if (characteristics == null) {
            return false;
        }
        Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
        return facing != null && facing == CameraCharacteristics.LENS_FACING_FRONT;
    }

    public class BeautyAdvancedSessionProcessor extends BaseAdvancedSessionProcessor {
        private boolean mProcessPreview = true;

        protected final Object mLockPreviewSurfaceImageWriter = new Object();
        @GuardedBy("mLockPreviewSurfaceImageWriter")
        private ImageWriter mPreviewSurfaceImageWriter;

        private final CaptureResultImageMatcher mCaptureResultImageMatcher =
                new CaptureResultImageMatcher();

        public BeautyAdvancedSessionProcessor() {
            appendTag("::GuardTalkBeauty");
        }

        @Override
        @NonNull
        public Camera2SessionConfigImpl initSession(@NonNull String cameraId,
                @NonNull Map<String, CameraCharacteristics> cameraCharacteristicsMap,
                @NonNull Context context,
                @NonNull OutputSurfaceConfigurationImpl surfaceConfigs) {
            Log.d(TAG, "initSession cameraId=" + cameraId);

            mPreviewOutputSurfaceConfig = surfaceConfigs.getPreviewOutputSurface();
            mCaptureOutputSurfaceConfig = surfaceConfigs.getImageCaptureOutputSurface();

            Camera2SessionConfigImplBuilder builder =
                    new Camera2SessionConfigImplBuilder()
                            .setSessionTemplateId(CameraDevice.TEMPLATE_PREVIEW);

            if (mPreviewOutputSurfaceConfig.getSurface() != null) {
                Camera2OutputConfigImplBuilder previewOutputConfigBuilder;
                if (mPreviewOutputSurfaceConfig.getDynamicRangeProfile()
                        == DynamicRangeProfiles.STANDARD) {
                    previewOutputConfigBuilder = Camera2OutputConfigImplBuilder.newImageReaderConfig(
                            mPreviewOutputSurfaceConfig.getSize(), ImageFormat.YUV_420_888,
                            BASIC_CAPTURE_PROCESS_MAX_IMAGES,
                            mPreviewOutputSurfaceConfig.getUsage());
                } else {
                    previewOutputConfigBuilder = Camera2OutputConfigImplBuilder.newSurfaceConfig(
                            mPreviewOutputSurfaceConfig.getSurface());
                    previewOutputConfigBuilder.setDynamicRangeProfile(
                            mPreviewOutputSurfaceConfig.getDynamicRangeProfile());
                    mProcessPreview = false;
                }
                mPreviewOutputConfig = previewOutputConfigBuilder.build();
                builder.addOutputConfig(mPreviewOutputConfig);
            }

            if (mCaptureOutputSurfaceConfig.getSurface() != null) {
                Camera2OutputConfigImplBuilder captureOutputConfigBuilder =
                        Camera2OutputConfigImplBuilder.newImageReaderConfig(
                                mCaptureOutputSurfaceConfig.getSize(), ImageFormat.YUV_420_888,
                                BASIC_CAPTURE_PROCESS_MAX_IMAGES,
                                mCaptureOutputSurfaceConfig.getUsage());
                mCaptureOutputConfig = captureOutputConfigBuilder.build();
                builder.addOutputConfig(mCaptureOutputConfig);
            }

            builder.setColorSpace(surfaceConfigs.getColorSpace());
            addSessionParameter(builder);
            return builder.build();
        }

        @Override
        protected void addSessionParameter(Camera2SessionConfigImplBuilder builder) {
            builder.addSessionParameter(CaptureRequest.CONTROL_AWB_MODE,
                    CaptureRequest.CONTROL_AWB_MODE_AUTO);
        }

        @Override
        public void deInitSession() {
            super.deInitSession();
            synchronized (mLockPreviewSurfaceImageWriter) {
                if (mPreviewSurfaceImageWriter != null) {
                    mPreviewSurfaceImageWriter.close();
                    mPreviewSurfaceImageWriter = null;
                }
            }
        }

        @Override
        public void onCaptureSessionStart(@NonNull RequestProcessorImpl requestProcessor) {
            super.onCaptureSessionStart(requestProcessor);
            if (!mProcessPreview || mPreviewOutputSurfaceConfig.getSurface() == null) {
                return;
            }

            synchronized (mLockPreviewSurfaceImageWriter) {
                mPreviewSurfaceImageWriter = new ImageWriter.Builder(
                        mPreviewOutputSurfaceConfig.getSurface()).setMaxImages(MAX_NUM_IMAGES)
                        .build();
            }

            requestProcessor.setImageProcessor(mPreviewOutputConfig.getId(),
                    new ImageProcessorImpl() {
                        @Override
                        public void onNextImageAvailable(int outputStreamId, long timestampNs,
                                @NonNull ImageReferenceImpl imageReferenceImpl,
                                @Nullable String physicalCameraId) {
                            mCaptureResultImageMatcher.setInputImage(imageReferenceImpl);
                        }
                    });

            mCaptureResultImageMatcher.setImageReferenceListener(
                    new CaptureResultImageMatcher.ImageReferenceListener() {
                        @Override
                        public void onImageReferenceIncoming(
                                @NonNull ImageReferenceImpl imageReferenceImpl,
                                @NonNull TotalCaptureResult totalCaptureResult, int captureId) {
                            processPreviewFrame(imageReferenceImpl);
                        }
                    });
        }

        private void processPreviewFrame(@NonNull ImageReferenceImpl imageReferenceImpl) {
            Image image = imageReferenceImpl.get();
            if (image != null) {
                GuardTalkFaceBridge.processImage(image);
            }
            synchronized (mLockPreviewSurfaceImageWriter) {
                if (mPreviewSurfaceImageWriter != null && image != null) {
                    mPreviewSurfaceImageWriter.queueInputImage(image);
                }
            }
            imageReferenceImpl.decrement();
        }

        @Override
        public void onCaptureSessionEnd() {
            super.onCaptureSessionEnd();
            synchronized (this) {
                mCaptureResultImageMatcher.clear();
            }
        }

        @Override
        protected void addCaptureRequestParameters(List<RequestProcessorImpl.Request> requestList,
                boolean isPostviewRequest) {
            RequestBuilder build = new RequestBuilder(mCaptureOutputConfig.getId(),
                    CameraDevice.TEMPLATE_STILL_CAPTURE, DEFAULT_CAPTURE_ID);
            applyParameters(build);
            requestList.add(build.build());
        }
    }

    @Override
    public SessionProcessorImpl createSessionProcessor() {
        return new BeautyAdvancedSessionProcessor();
    }

    @Override
    public List<CaptureRequest.Key> getAvailableCaptureRequestKeys() {
        final CaptureRequest.Key[] keys = {CaptureRequest.CONTROL_AE_MODE,
                CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.JPEG_QUALITY,
                CaptureRequest.JPEG_ORIENTATION};
        return Arrays.asList(keys);
    }

    @Override
    public List<CaptureResult.Key> getAvailableCaptureResultKeys() {
        final CaptureResult.Key[] keys = {CaptureResult.CONTROL_AE_MODE,
                CaptureResult.CONTROL_AWB_MODE, CaptureResult.JPEG_QUALITY,
                CaptureResult.JPEG_ORIENTATION};
        return Arrays.asList(keys);
    }
}
