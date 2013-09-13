//
//  VideoWriter.m
//  Created by lukasz karluk on 15/06/12.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "VideoWriter.h"

@interface VideoWriter() {
	CMTime startTime;
    CMTime previousFrameTime;
    BOOL bWriting;

    BOOL bUseTextureCache;
    BOOL bEnableTextureCache;
    BOOL bTextureCacheSupported;
#ifdef __IPHONE_5_0
    CVOpenGLESTextureCacheRef _textureCache;
    CVOpenGLESTextureRef _textureRef;
    CVPixelBufferRef _pixelBufferRef;
#endif
    
}
@end


@implementation VideoWriter

@synthesize delegate;
@synthesize videoSize;
@synthesize context;
@synthesize assetWriter;
@synthesize assetWriterVideoInput;
@synthesize assetWriterInputPixelBufferAdaptor;
@synthesize outputURL;
@synthesize enableTextureCache;

//---------------------------------------------------------------------------
- (id)initWithFile:(NSString *)file andVideoSize:(CGSize)size {
    NSString * docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * fullPath = [docsPath stringByAppendingPathComponent:file];
    NSURL * fileURL = [NSURL fileURLWithPath:fullPath];
	return [self initWithURL:fileURL andVideoSize:size];
}

- (id)initWithPath:(NSString *)path andVideoSize:(CGSize)size {
    NSURL * fileURL = [NSURL fileURLWithPath:path];
	return [self initWithURL:fileURL andVideoSize:size];
}

- (id)initWithURL:(NSURL *)fileURL andVideoSize:(CGSize)size {
    self = [self init];
    if(self) {
        self.outputURL = fileURL;
        self.videoSize = size;
    }
    return self;
}

- (id)init {
    self = [super init];
    if(self) {
        bWriting = NO;
        startTime = kCMTimeInvalid;
        previousFrameTime = kCMTimeInvalid;
        videoWriterQueue = dispatch_queue_create("VideoWriterQueue", NULL);

        bUseTextureCache = NO;
        bEnableTextureCache = NO;
        bTextureCacheSupported = NO;
    }
    return self;
}

- (void)dealloc {
    self.outputURL = nil;
    
    [self.assetWriterVideoInput markAsFinished];
    [self.assetWriter finishWriting];
    [self.assetWriter cancelWriting];
    
    self.assetWriterVideoInput = nil;
    self.assetWriter = nil;
    self.assetWriterInputPixelBufferAdaptor = nil;
    
    [self destroyTextureCache];
    
    [super dealloc];
}

//---------------------------------------------------------------------------
- (void)startRecording {
    if(bWriting == YES) {
        return;
    }
    bWriting = YES;
    
    startTime = kCMTimeZero;
    previousFrameTime = kCMTimeInvalid;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputURL.path]) { // remove old file.
        [[NSFileManager defaultManager] removeItemAtPath:self.outputURL.path error:nil];
    }
    
    // allocate the writer object with our output file URL
    NSError *error = nil;
    self.assetWriter = [[[AVAssetWriter alloc] initWithURL:self.outputURL
                                                  fileType:AVFileTypeQuickTimeMovie
                                                     error:&error] autorelease];
    if(error) {
        if([self.delegate respondsToSelector:@selector(videoWriterError:)]) {
            [self.delegate videoWriterError:error];
        }
        return;
    }
    
    NSDictionary * videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    AVVideoCodecH264, AVVideoCodecKey,
                                    [NSNumber numberWithInt:self.videoSize.width], AVVideoWidthKey,
                                    [NSNumber numberWithInt:self.videoSize.height], AVVideoHeightKey,
                                    nil];
    
    // initialized a new input for video to receive sample buffers for writing
    // passing nil for outputSettings instructs the input to pass through appended samples, doing no processing before they are written
    self.assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                    outputSettings:videoSettings];
    self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;
    
    // You need to use BGRA for the video in order to get realtime encoding.
    // Color-swizzling shader is used to line up glReadPixels' normal RGBA output with the movie input's BGRA.
    NSDictionary * sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                            [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                                            [NSNumber numberWithInt:videoSize.width], kCVPixelBufferWidthKey,
                                                            [NSNumber numberWithInt:videoSize.height], kCVPixelBufferHeightKey,
                                                            nil];
    
    self.assetWriterInputPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.assetWriterVideoInput
                                                                                                               sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    if([self.assetWriter canAddInput:self.assetWriterVideoInput]) {
        [self.assetWriter addInput:self.assetWriterVideoInput];
    }
    
	[self.assetWriter startWriting];
	[self.assetWriter startSessionAtSourceTime:startTime];
    
    if(bEnableTextureCache) {
        [self initTextureCache];
    }
}

- (void)finishRecording {
    if(bWriting == NO) {
        return;
    }
    
    if(assetWriter.status == AVAssetWriterStatusCompleted ||
       assetWriter.status == AVAssetWriterStatusCancelled ||
       assetWriter.status == AVAssetWriterStatusUnknown) {
        return;
    }
    
    bWriting = NO;
    dispatch_sync(videoWriterQueue, ^{

        [self.assetWriterVideoInput markAsFinished];
        [self.assetWriter finishWriting];
        
        self.assetWriterVideoInput = nil;
        self.assetWriter = nil;
        self.assetWriterInputPixelBufferAdaptor = nil;
        
        [self destroyTextureCache];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if([self.delegate respondsToSelector:@selector(videoWriterComplete:)]) {
                [self.delegate videoWriterComplete:self.outputURL];
            }
        });
    });
}

- (void)cancelRecording {
    if(bWriting == NO) {
        return;
    }
    
    if(self.assetWriter.status == AVAssetWriterStatusCompleted) {
        return;
    }
    
    bWriting = NO;
    dispatch_sync(videoWriterQueue, ^{

        [self.assetWriterVideoInput markAsFinished];
        [self.assetWriter finishWriting];
        [self.assetWriter cancelWriting];
        
        self.assetWriterVideoInput = nil;
        self.assetWriter = nil;
        self.assetWriterInputPixelBufferAdaptor = nil;
        
        [self destroyTextureCache];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if([self.delegate respondsToSelector:@selector(videoWriterCancelled)]) {
                [self.delegate videoWriterCancelled];
            }
        });
    });
}

- (BOOL)isWriting {
    return bWriting;
}

//--------------------------------------------------------------------------- add frame.
- (void)addFrameAtTime:(CMTime)frameTime {

    if(bWriting == NO) {
        return;
    }
    
    if((CMTIME_IS_INVALID(frameTime)) ||
       (CMTIME_COMPARE_INLINE(frameTime, ==, previousFrameTime)) ||
       (CMTIME_IS_INDEFINITE(frameTime))) {
        return;
    }
    
    if(assetWriterVideoInput.readyForMoreMediaData == NO) {
        NSLog(@"Had to drop a video frame");
        return;
    }

    //---------------------------------------------------------- fill pixel buffer.
    CVPixelBufferRef pixelBuffer = NULL;

    //----------------------------------------------------------
    // check if texture cache is enabled,
    // if so, use the pixel buffer from the texture cache.
    //----------------------------------------------------------
    
#ifdef __IPHONE_5_0
    if(bUseTextureCache == YES) {
        pixelBuffer = _pixelBufferRef;
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    }
#endif
    
    //----------------------------------------------------------
    // if texture cache is disabled,
    // read the pixels from screen or fbo.
    // this is a much slower fallback alternative.
    //----------------------------------------------------------
    
    if(pixelBuffer == NULL) {
        CVPixelBufferPoolRef pixelBufferPool = [self.assetWriterInputPixelBufferAdaptor pixelBufferPool];
        CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, pixelBufferPool, &pixelBuffer);
        if((pixelBuffer == NULL) || (status != kCVReturnSuccess)) {
            return;
        } else {
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            GLubyte * pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixelBuffer);
            glReadPixels(0, 0, self.videoSize.width, self.videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
        }
    }
    
    //----------------------------------------------------------
    dispatch_sync(videoWriterQueue, ^{
        if([self.assetWriterInputPixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:frameTime] == NO) {
            NSLog(@"Problem appending pixel buffer at time: %lld", frameTime.value);
        } else {
            // NSLog(@"Recorded video sample time: %lld, %d, %lld", frameTime.value, frameTime.timescale, frameTime.epoch);
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
        previousFrameTime = frameTime;
        
        if(bUseTextureCache == NO) {
            CVPixelBufferRelease(pixelBuffer);
        }
    });
}

//--------------------------------------------------------------------------- texture cache.
- (void)setEnableTextureCache:(BOOL)value {
    if(bWriting == YES) {
        NSLog(@"enableTextureCache can not be changed while recording.");
    }
    bEnableTextureCache = value;
}

- (void)initTextureCache {
#ifdef __IPHONE_5_0
    
    bTextureCacheSupported = (CVOpenGLESTextureCacheCreate != NULL);
    bUseTextureCache = bTextureCacheSupported;
    if(bEnableTextureCache == NO) {
        bUseTextureCache = NO;
    }
    
    if(bUseTextureCache == NO) {
        return;
    }
    
    //-----------------------------------------------------------------------
    CVReturn error;
    error = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                NULL,
                                                context,
                                                NULL,
                                                &_textureCache);
    if(error) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", error);
        bUseTextureCache = NO;
        return;
    }
    
    //-----------------------------------------------------------------------
    CVPixelBufferPoolRef pixelBufferPool = [self.assetWriterInputPixelBufferAdaptor pixelBufferPool];
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, pixelBufferPool, &_pixelBufferRef);
    if(status != kCVReturnSuccess) {
        bUseTextureCache = NO;
        return;
    }
    
    error = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,         // CFAllocatorRef allocator
                                                         _textureCache,               // CVOpenGLESTextureCacheRef textureCache
                                                         _pixelBufferRef,             // CVPixelBufferRef source pixel buffer.
                                                         NULL,                        // CFDictionaryRef textureAttributes
                                                         GL_TEXTURE_2D,               // GLenum target
                                                         GL_RGBA,                     // GLint internalFormat
                                                         (int)self.videoSize.width,   // GLsizei width
                                                         (int)self.videoSize.height,  // GLsizei height
                                                         GL_BGRA,                     // GLenum format
                                                         GL_UNSIGNED_BYTE,            // GLenum type
                                                         0,                           // size_t planeIndex
                                                         &_textureRef);               // CVOpenGLESTextureRef *textureOut
    
    if(error) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", error);
        bUseTextureCache = NO;
        return;
    }
    
    //-----------------------------------------------------------------------
//    glBindTexture(CVOpenGLESTextureGetTarget(_textureRef), CVOpenGLESTextureGetName(_textureRef));
//    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//    
//    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(_textureRef), 0);
    
#endif
}

- (void)destroyTextureCache {
#ifdef __IPHONE_5_0
    
    if(_textureCache) {
        CVOpenGLESTextureCacheFlush(_textureCache, 0);
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
    
    if(_textureRef) {
        CFRelease(_textureRef);
        _textureRef = NULL;
    }
    
    if(_pixelBufferRef) {
        CVPixelBufferRelease(_pixelBufferRef);
        _pixelBufferRef = NULL;
    }
    
#endif
}

- (BOOL)isTextureCached {
    return bUseTextureCache;
}

- (unsigned int)textureCacheID {
#ifdef __IPHONE_5_0
    return CVOpenGLESTextureGetName(_textureRef);
#endif
    return 0;
}

- (int)textureCacheTarget {
#ifdef __IPHONE_5_0
    return CVOpenGLESTextureGetTarget(_textureRef);
#endif
    return 0;
}

//---------------------------------------------------------------------------
- (void)saveMovieToCameraRoll {
    
    NSLog(@" saveMovieToCameraRoll ");
    
    // save the movie to the camera roll
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	//NSLog(@"writing \"%@\" to photos album", outputURL);
	[library writeVideoAtPathToSavedPhotosAlbum:self.outputURL
								completionBlock:^(NSURL *assetURL, NSError *error) {
									if (error) {
										NSLog(@"assets library failed (%@)", error);
									}
									else {
										[[NSFileManager defaultManager] removeItemAtURL:self.outputURL error:&error];
										if (error)
											NSLog(@"Couldn't remove temporary movie file \"%@\"", self.outputURL);
									}
                                    
									self.outputURL = nil;
                                    [library release];
                                    
                                    if([self.delegate respondsToSelector:@selector(videoWriterSavedToCameraRoll)]) {
                                        [self.delegate videoWriterSavedToCameraRoll];
                                    }
								}];
}

@end
