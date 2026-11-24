package xyz.justsoft.video_thumbnail;

import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class VideoThumbnailPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "ThumbnailPlugin";

    private Context context;
    private ExecutorService executor;
    private MethodChannel channel;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    /** Dart의 PlatformException.code로 그대로 전달되는 실패 원인. 코드 값은 iOS와 같다. */
    static final class ThumbnailException extends Exception {
        final String code;

        ThumbnailException(String code, String message, @Nullable Throwable cause) {
            super(message, cause);
            this.code = code;
        }
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        executor = Executors.newCachedThreadPool();
        channel = new MethodChannel(binding.getBinaryMessenger(), "plugins.justsoft.xyz/video_thumbnail");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        executor.shutdown();
        executor = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull final Result result) {
        final String method = call.method;
        if (!method.equals("file") && !method.equals("data")) {
            result.notImplemented();
            return;
        }

        final String video = call.argument("video");
        final Map<String, String> headers = call.argument("headers");
        final String path = call.argument("path");
        final int format = intArg(call, "format");
        final int maxh = intArg(call, "maxh");
        final int maxw = intArg(call, "maxw");
        final int timeMs = intArg(call, "timeMs");
        final int quality = Math.max(0, Math.min(100, intArg(call, "quality")));

        executor.execute(() -> {
            try {
                final Object thumbnail = method.equals("file")
                        ? buildThumbnailFile(video, headers, path, format, maxh, maxw, timeMs, quality)
                        : buildThumbnailData(video, headers, format, maxh, maxw, timeMs, quality);
                mainHandler.post(() -> result.success(thumbnail));
            } catch (ThumbnailException e) {
                // 영상 URL에 서명 토큰이 붙을 수 있어 로그에는 남기지 않는다. URL은 Dart로 가는 메시지에만 담는다.
                Log.w(TAG, "thumbnail failed: " + e.code, e.getCause());
                mainHandler.post(() -> result.error(e.code, e.getMessage(), causeDetails(e)));
            } catch (Throwable e) {
                // 원본 해상도 프레임의 OutOfMemoryError 등도 응답해야 Dart Future가 끝난다.
                Log.w(TAG, "thumbnail failed", e);
                mainHandler.post(() -> result.error("no_frame", "Failed to create the thumbnail: " + e, null));
            }
        });
    }

    private static int intArg(MethodCall call, String key) {
        final Integer value = call.argument(key);
        return value == null ? 0 : value;
    }

    @Nullable
    private static String causeDetails(Throwable e) {
        return e.getCause() == null ? null : String.valueOf(e.getCause());
    }

    @SuppressWarnings("deprecation")
    private static Bitmap.CompressFormat intToFormat(int format, int quality) {
        switch (format) {
            case 1:
                return Bitmap.CompressFormat.PNG;
            case 2:
                // iOS와 같게 quality 100은 무손실 WebP로 인코딩한다.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    return quality == 100 ? Bitmap.CompressFormat.WEBP_LOSSLESS : Bitmap.CompressFormat.WEBP_LOSSY;
                }
                return Bitmap.CompressFormat.WEBP;
            case 0:
            default:
                return Bitmap.CompressFormat.JPEG;
        }
    }

    private static String formatExt(int format) {
        switch (format) {
            case 1:
                return "png";
            case 2:
                return "webp";
            case 0:
            default:
                return "jpg";
        }
    }

    private byte[] buildThumbnailData(String video, @Nullable Map<String, String> headers, int format, int maxh,
            int maxw, int timeMs, int quality) throws ThumbnailException {
        final Bitmap bitmap = createVideoThumbnail(video, headers, maxh, maxw, timeMs);
        try {
            final ByteArrayOutputStream stream = new ByteArrayOutputStream();
            if (!bitmap.compress(intToFormat(format, quality), quality, stream)) {
                throw new ThumbnailException("encode_error", "Failed to encode the thumbnail as " + formatExt(format),
                        null);
            }
            return stream.toByteArray();
        } finally {
            bitmap.recycle();
        }
    }

    private String buildThumbnailFile(String video, @Nullable Map<String, String> headers, @Nullable String path,
            int format, int maxh, int maxw, int timeMs, int quality) throws ThumbnailException {
        final byte[] bytes = buildThumbnailData(video, headers, format, maxh, maxw, timeMs, quality);
        final String ext = formatExt(format);
        final String fileName = thumbnailFileName(video, ext);
        final boolean isLocalFile = video.startsWith("/") || video.startsWith("file://");
        final String cacheDir = context.getCacheDir().getAbsolutePath();

        if (path != null && !path.isEmpty()) {
            final String target = path.endsWith("." + ext) ? path : new File(path, fileName).getAbsolutePath();
            writeFile(target, bytes);
            return target;
        }

        if (isLocalFile) {
            // 앱이 쓸 수 없는 폴더(갤러리·외부 저장소)의 영상이면 캐시 폴더로 대신 쓴다.
            final String besideVideo = new File(new File(localPath(video)).getParentFile(), fileName).getAbsolutePath();
            try {
                writeFile(besideVideo, bytes);
                return besideVideo;
            } catch (ThumbnailException e) {
                Log.w(TAG, "cannot write beside the video, using the cache folder: " + e.getMessage());
            }
        }

        final String inCache = new File(cacheDir, fileName).getAbsolutePath();
        writeFile(inCache, bytes);
        return inCache;
    }

    private static String thumbnailFileName(String video, String ext) {
        String name = video.startsWith("/") ? video : Uri.parse(video).getLastPathSegment();
        // 디코딩된 세그먼트에 %2F가 풀린 '/'가 있을 수 있어(Firebase Storage URL 등) 마지막 부분만 쓴다. iOS와 같다.
        name = name == null ? "" : new File(name).getName();
        final int dot = name.lastIndexOf('.');
        if (dot > 0) {
            name = name.substring(0, dot);
        }
        if (name.isEmpty()) {
            name = "thumbnail";
        }
        return name + "." + ext;
    }

    private static String localPath(String video) {
        return video.startsWith("file://") ? video.substring(7) : video;
    }

    private static void writeFile(String fullpath, byte[] bytes) throws ThumbnailException {
        try (FileOutputStream f = new FileOutputStream(fullpath)) {
            f.write(bytes);
        } catch (IOException e) {
            throw new ThumbnailException("io_error", "Failed to write the thumbnail to " + fullpath, e);
        }
    }

    /**
     * Returns a frame of the video scaled to the requested size.
     *
     * @param targetH the max height of the thumbnail, 0 to follow the aspect ratio
     * @param targetW the max width of the thumbnail, 0 to follow the aspect ratio
     */
    private Bitmap createVideoThumbnail(String video, @Nullable Map<String, String> headers, int targetH,
            int targetW, int timeMs) throws ThumbnailException {
        final MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            try {
                if (video.startsWith("/") || video.startsWith("file://")) {
                    setDataSource(localPath(video), retriever);
                } else {
                    retriever.setDataSource(video, headers != null ? headers : new HashMap<>());
                }
            } catch (IOException | RuntimeException e) {
                throw new ThumbnailException("source_error", "Failed to open the video: " + video, e);
            }

            final long timeUs = timeMs * 1000L;
            // API 27+는 두 변을 모두 받으면 디코더가 직접 축소한다. 나머지는 원본 프레임을 받아 여기서 줄인다.
            final boolean decoderScales = targetH != 0 && targetW != 0
                    && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1;
            Bitmap bitmap;
            try {
                bitmap = frameAt(retriever, timeUs, decoderScales ? targetW : 0, decoderScales ? targetH : 0);
            } catch (RuntimeException e) {
                throw new ThumbnailException("no_frame", "Failed to read a frame at " + timeMs + " ms", e);
            }
            if (bitmap == null) {
                throw new ThumbnailException("no_frame", "The video has no frame at " + timeMs + " ms", null);
            }

            if (!decoderScales && (targetH != 0 || targetW != 0)) {
                final int width = bitmap.getWidth();
                final int height = bitmap.getHeight();
                final int w = targetW != 0 ? targetW : Math.round(((float) targetH / height) * width);
                final int h = targetH != 0 ? targetH : Math.round(((float) targetW / width) * height);
                final Bitmap scaled = Bitmap.createScaledBitmap(bitmap, w, h, true);
                if (scaled != bitmap) {
                    bitmap.recycle();
                }
                bitmap = scaled;
            }
            return bitmap;
        } finally {
            try {
                retriever.release();
            } catch (IOException | RuntimeException e) {
                Log.w(TAG, "failed to release MediaMetadataRetriever", e);
            }
        }
    }

    /** 가장 가까운 프레임을 못 얻는 영상·기기가 있어, 실패하면 가장 가까운 키프레임으로 한 번 더 시도한다. */
    @Nullable
    private static Bitmap frameAt(MediaMetadataRetriever retriever, long timeUs, int scaledW, int scaledH) {
        final boolean scaled = scaledW != 0 && scaledH != 0;
        final int[] options = { MediaMetadataRetriever.OPTION_CLOSEST, MediaMetadataRetriever.OPTION_CLOSEST_SYNC };
        RuntimeException lastError = null;
        for (int option : options) {
            try {
                final Bitmap bitmap = scaled
                        ? retriever.getScaledFrameAtTime(timeUs, option, scaledW, scaledH)
                        : retriever.getFrameAtTime(timeUs, option);
                if (bitmap != null) {
                    return bitmap;
                }
            } catch (RuntimeException e) {
                lastError = e;
            }
        }
        if (lastError != null) {
            throw lastError;
        }
        return null;
    }

    private static void setDataSource(String video, MediaMetadataRetriever retriever) throws IOException {
        try (FileInputStream inputStream = new FileInputStream(new File(video).getAbsolutePath())) {
            retriever.setDataSource(inputStream.getFD());
        }
    }
}
