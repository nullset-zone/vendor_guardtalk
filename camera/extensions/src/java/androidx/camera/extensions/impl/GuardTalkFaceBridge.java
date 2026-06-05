/*
 * Copyright (C) 2026 GuardTalkOS Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

package androidx.camera.extensions.impl;

import android.media.Image;
import android.util.Log;

import java.nio.ByteBuffer;

/** JNI bridge for GuardTalk face persona processing on YUV_420_888 frames. */
public final class GuardTalkFaceBridge {
    private static final String TAG = "GuardTalkFaceBridge";
    private static boolean sLibraryLoaded = false;

    static {
        try {
            System.loadLibrary("guardtalkface_jni");
            sLibraryLoaded = true;
        } catch (UnsatisfiedLinkError error) {
            Log.e(TAG, "libguardtalkface_jni not loaded", error);
        }
    }

    private GuardTalkFaceBridge() {}

    public static void processImage(Image image) {
        if (!sLibraryLoaded || image == null) {
            return;
        }
        if (image.getFormat() != android.graphics.ImageFormat.YUV_420_888) {
            return;
        }

        Image.Plane[] planes = image.getPlanes();
        if (planes == null || planes.length < 3) {
            return;
        }

        ByteBuffer y = planes[0].getBuffer();
        ByteBuffer u = planes[1].getBuffer();
        ByteBuffer v = planes[2].getBuffer();
        if (y == null || u == null || v == null) {
            return;
        }

        nativeProcessYuv420(y, planes[0].getRowStride(), u, planes[1].getRowStride(), v,
                planes[2].getRowStride(), image.getWidth(), image.getHeight());
    }

    private static native void nativeProcessYuv420(ByteBuffer y, int yStride, ByteBuffer u,
            int uStride, ByteBuffer v, int vStride, int width, int height);
}
