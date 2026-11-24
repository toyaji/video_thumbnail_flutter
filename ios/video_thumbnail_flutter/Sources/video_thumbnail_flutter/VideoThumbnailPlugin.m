#import "VideoThumbnailPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#if __has_include("webp/encode.h")
#import "webp/encode.h"
#elif __has_include(<libwebp/encode.h>)
#import <libwebp/encode.h>
#endif

// Dart의 PlatformException.code로 전달되는 실패 원인. 코드 값은 Android와 같다.
static NSString *const kSourceError = @"source_error";
static NSString *const kNoFrame = @"no_frame";
static NSString *const kEncodeError = @"encode_error";
static NSString *const kIOError = @"io_error";

@implementation VideoThumbnailPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"plugins.justsoft.xyz/video_thumbnail"
                                                                binaryMessenger:[registrar messenger]];
    VideoThumbnailPlugin *instance = [[VideoThumbnailPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

static id NilIfNull(id value) {
    return [value isKindOfClass:[NSNull class]] ? nil : value;
}

static FlutterError *ErrorWith(NSString *code, NSString *message, NSError *cause) {
    NSString *details = cause == nil ? nil : [NSString stringWithFormat:@"%@ (%@ %ld)", cause.localizedDescription, cause.domain, (long)cause.code];
    return [FlutterError errorWithCode:code message:message details:details];
}

static void ReplyOnMain(FlutterResult result, id value) {
    dispatch_async(dispatch_get_main_queue(), ^{
        result(value);
    });
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    BOOL isFile = [@"file" isEqualToString:call.method];
    if (!isFile && ![@"data" isEqualToString:call.method]) {
        result(FlutterMethodNotImplemented);
        return;
    }

    NSDictionary *args = call.arguments;
    NSString *video = NilIfNull(args[@"video"]);
    NSDictionary *headers = NilIfNull(args[@"headers"]);
    NSString *path = NilIfNull(args[@"path"]);
    int format = [NilIfNull(args[@"format"]) intValue];
    int maxh = [NilIfNull(args[@"maxh"]) intValue];
    int maxw = [NilIfNull(args[@"maxw"]) intValue];
    int timeMs = [NilIfNull(args[@"timeMs"]) intValue];
    int quality = MAX(0, MIN(100, [NilIfNull(args[@"quality"]) intValue]));

    NSString *localPath = [video hasPrefix:@"file://"] ? [video substringFromIndex:7] : [video hasPrefix:@"/"] ? video : nil;
    BOOL isLocalFile = localPath != nil;
    NSURL *url = isLocalFile ? [NSURL fileURLWithPath:localPath] : [NSURL URLWithString:video];
    if (url == nil || (isLocalFile && ![[NSFileManager defaultManager] isReadableFileAtPath:url.path])) {
        result(ErrorWith(kSourceError, [NSString stringWithFormat:@"Failed to open the video: %@", video], nil));
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        FlutterError *error = nil;
        NSData *data = [VideoThumbnailPlugin generateThumbnail:url headers:headers format:format maxHeight:maxh maxWidth:maxw timeMs:timeMs quality:quality error:&error];
        if (data == nil) {
            ReplyOnMain(result, error);
            return;
        }
        if (!isFile) {
            ReplyOnMain(result, data);
            return;
        }
        NSString *written = [VideoThumbnailPlugin writeThumbnail:data video:url localPath:localPath path:path format:format error:&error];
        ReplyOnMain(result, written != nil ? written : error);
    });
}

+ (NSString *)extensionFor:(int)format {
    return format == 0 ? @"jpg" : format == 1 ? @"png" : @"webp";
}

+ (NSString *)writeThumbnail:(NSData *)data
                       video:(NSURL *)video
                   localPath:(NSString *)localPath
                        path:(NSString *)path
                      format:(int)format
                       error:(FlutterError **)error {
    NSString *ext = [VideoThumbnailPlugin extensionFor:format];
    // 경로는 NSURL을 거치지 않고 호출자가 준 문자열로 만든다. NSURL은 한글을 자모 분리형(NFD)으로 바꿔 돌려준다.
    NSString *lastComponent = localPath != nil ? localPath.lastPathComponent : video.lastPathComponent;
    NSString *baseName = lastComponent.stringByDeletingPathExtension;
    if (baseName.length == 0 || [baseName isEqualToString:@"/"]) {
        baseName = @"thumbnail";
    }
    NSString *fileName = [baseName stringByAppendingPathExtension:ext] ?: [@"thumbnail" stringByAppendingPathExtension:ext];
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];

    NSMutableArray<NSString *> *targets = [NSMutableArray array];
    if (path.length > 0) {
        [targets addObject:[path.pathExtension isEqualToString:ext] ? path : [path stringByAppendingPathComponent:fileName]];
    } else {
        // 앱이 쓸 수 없는 폴더(사진 보관함 임시 경로 등)의 영상이면 캐시 폴더로 대신 쓴다.
        if (localPath != nil) {
            [targets addObject:[localPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:fileName]];
        }
        [targets addObject:[cacheDir stringByAppendingPathComponent:fileName]];
    }

    NSError *lastError = nil;
    for (NSString *target in targets) {
        if ([data writeToFile:target options:NSDataWritingAtomic error:&lastError]) {
            return target;
        }
        NSLog(@"VideoThumbnailPlugin: cannot write %@: %@", target, lastError);
    }
    *error = ErrorWith(kIOError, [NSString stringWithFormat:@"Failed to write the thumbnail to %@", targets.lastObject], lastError);
    return nil;
}

+ (NSData *)generateThumbnail:(NSURL *)url
                      headers:(NSDictionary *)headers
                       format:(int)format
                    maxHeight:(int)maxh
                     maxWidth:(int)maxw
                       timeMs:(int)timeMs
                      quality:(int)quality
                        error:(FlutterError **)error {
    NSDictionary *options = headers == nil ? nil : @{@"AVURLAssetHTTPHeaderFieldsKey" : headers};
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:options];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake((CGFloat)maxw, (CGFloat)maxh);
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    generator.requestedTimeToleranceAfter = CMTimeMake(100, 1000);

    NSError *frameError = nil;
    CGImageRef cgImage = [generator copyCGImageAtTime:CMTimeMake(timeMs, 1000) actualTime:nil error:&frameError];
    if (cgImage == NULL) {
        BOOL avUnreadable = [frameError.domain isEqualToString:AVFoundationErrorDomain] &&
                            (frameError.code == AVErrorFileFormatNotRecognized || frameError.code == AVErrorFileFailedToParse ||
                             frameError.code == AVErrorContentIsUnavailable);
        NSError *underlying = frameError.userInfo[NSUnderlyingErrorKey];
        BOOL unreadable = avUnreadable || [frameError.domain isEqualToString:NSURLErrorDomain] ||
                          [frameError.domain isEqualToString:NSCocoaErrorDomain] ||
                          [underlying.domain isEqualToString:NSURLErrorDomain];
        *error = ErrorWith(unreadable ? kSourceError : kNoFrame,
                           [NSString stringWithFormat:@"Failed to read a frame at %d ms from %@", timeMs, url], frameError);
        return nil;
    }

    NSData *data = nil;
    if (format <= 1) {
        UIImage *thumbnail = [UIImage imageWithCGImage:cgImage];
        data = format == 0 ? UIImageJPEGRepresentation(thumbnail, (CGFloat)(quality * 0.01)) : UIImagePNGRepresentation(thumbnail);
    } else {
        data = [VideoThumbnailPlugin encodeWebP:cgImage quality:quality];
    }
    CGImageRelease(cgImage);

    if (data == nil) {
        *error = ErrorWith(kEncodeError, [NSString stringWithFormat:@"Failed to encode the thumbnail as %@", [VideoThumbnailPlugin extensionFor:format]], nil);
    }
    return data;
}

// 프레임의 픽셀 형식(HDR 10비트·float 성분·다른 색공간 등)과 상관없이 8비트 sRGB BGRA로 다시 그려 libwebp에 넘긴다.
+ (NSData *)encodeWebP:(CGImageRef)cgImage quality:(int)quality {
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    size_t stride = width * 4;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, stride, colorSpace,
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) {
        return nil;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    const uint8_t *pixels = CGBitmapContextGetData(context);

    uint8_t *output = NULL;
    size_t size = quality == 100
                      ? WebPEncodeLosslessBGRA(pixels, (int)width, (int)height, (int)stride, &output)
                      : WebPEncodeBGRA(pixels, (int)width, (int)height, (int)stride, (float)quality, &output);
    CGContextRelease(context);

    NSData *data = size == 0 ? nil : [NSData dataWithBytes:output length:size];
    WebPFree(output);
    return data;
}

@end
