//
//  VideoWriter.m
//  Created by lukasz karluk on 15/06/12.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "VideoWriter.h"

@interface VideoWriter() {
	CMTime startTime;
    CMTime previousFrameTime;
	CMTime previousAudioTime;
    BOOL bWriting;

    BOOL bUseTextureCache;
    BOOL bEnableTextureCache;
    BOOL bTextureCacheSupported;

    CVOpenGLESTextureCacheRef _textureCache;
    CVOpenGLESTextureRef _textureRef;
    CVPixelBufferRef _textureCachePixelBuffer;
}
@end


@implementation VideoWriter

@synthesize delegate;
@synthesize videoSize;
@synthesize context;
@synthesize assetWriter;
@synthesize assetWriterVideoInput;
@synthesize assetWriterAudioInput;
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
		previousAudioTime = kCMTimeInvalid;
        videoWriterQueue = dispatch_queue_create("ofxiOSVideoWriter.VideoWriterQueue", NULL);

        bUseTextureCache = NO;
        bEnableTextureCache = NO;
        bTextureCacheSupported = NO;
    }
    return self;
}

- (void)dealloc {
    self.outputURL = nil;
    
    [self disposeAssetWriterAndWriteFile:NO];
    
#if ( (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0) || (!defined(__IPHONE_6_0)) )
    if(videoWriterQueue != NULL) {
        dispatch_release(videoWriterQueue);
    }
#endif
    
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
    self.assetWriter = [AVAssetWriter assetWriterWithURL:self.outputURL
                                                fileType:AVFileTypeQuickTimeMovie
                                                   error:&error];
    if(error) {
        if([self.delegate respondsToSelector:@selector(videoWriterError:)]) {
            [self.delegate videoWriterError:error];
        }
        return;
    }
    
    //--------------------------------------------------------------------------- adding video input.
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
    
    //--------------------------------------------------------------------------- adding audio input.
    double preferredHardwareSampleRate = [[AVAudioSession sharedInstance] currentHardwareSampleRate];
    
    AudioChannelLayout channelLayout;
    bzero(&channelLayout, sizeof(channelLayout));
    channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    int numOfChannels = 1;
    if(channelLayout.mChannelLayoutTag == kAudioChannelLayoutTag_Stereo) {
        numOfChannels = 2;
    }
    
    NSDictionary * audioSettings = nil;
    
    audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                     [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
                     [NSNumber numberWithInt:numOfChannels], AVNumberOfChannelsKey,
                     [NSNumber numberWithFloat:preferredHardwareSampleRate], AVSampleRateKey,
                     [NSData dataWithBytes:&channelLayout length:sizeof(channelLayout)], AVChannelLayoutKey,
                     [NSNumber numberWithInt:64000], AVEncoderBitRateKey,
                     nil];

    self.assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                    outputSettings:audioSettings];
    self.assetWriterAudioInput.expectsMediaDataInRealTime = YES;
    
    if([self.assetWriter canAddInput:self.assetWriterAudioInput]) {
        [self.assetWriter addInput:self.assetWriterAudioInput];
    }

    //--------------------------------------------------------------------------- start writing!
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
        [self disposeAssetWriterAndWriteFile:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            if([self.delegate respondsToSelector:@selector(videoWriterComplete:)]) {
                [self.delegate videoWriterComplete:self.outputURL];
            }
            NSLog(@"video saved! - %@", self.outputURL.description);
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
		[self disposeAssetWriterAndWriteFile:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            if([self.delegate respondsToSelector:@selector(videoWriterCancelled)]) {
                [self.delegate videoWriterCancelled];
            }
        });
    });
}

- (void) disposeAssetWriterAndWriteFile:(BOOL)writeFile {
	[self.assetWriterVideoInput markAsFinished];
	[self.assetWriterAudioInput markAsFinished];
	
	void (^releaseAssetWriter)(void) = ^{
		self.assetWriterVideoInput = nil;
		self.assetWriterAudioInput = nil;
		self.assetWriter = nil;
		self.assetWriterInputPixelBufferAdaptor = nil;
		[self destroyTextureCache];
	};
	
	if(writeFile) {
		[self.assetWriter finishWritingWithCompletionHandler:releaseAssetWriter];
	} else {
		[self.assetWriter cancelWriting];
		releaseAssetWriter();
	}
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
        NSLog(@"[VideoWriter addFrameAtTime] - not ready for more media data");
        return;
    }

    //---------------------------------------------------------- fill pixel buffer.
    CVPixelBufferRef pixelBuffer = NULL;

    //----------------------------------------------------------
    // check if texture cache is enabled,
    // if so, use the pixel buffer from the texture cache.
    //----------------------------------------------------------
    
    if(bUseTextureCache == YES) {
        pixelBuffer = _textureCachePixelBuffer;
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    }
    
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
        
        BOOL bOk = [self.assetWriterInputPixelBufferAdaptor appendPixelBuffer:pixelBuffer
                                                         withPresentationTime:frameTime];
        if(bOk == NO) {
            NSString * errorDesc = self.assetWriter.error.description;
            NSLog(@"[VideoWriter addFrameAtTime] - error appending video samples - %@", errorDesc);
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
        previousFrameTime = frameTime;
        
        if(bUseTextureCache == NO) {
            CVPixelBufferRelease(pixelBuffer);
        }
    });
}

- (void)addAudio:(CMSampleBufferRef)audioBuffer {
    
    if(bWriting == NO) {
        return;
    }
    
    if(audioBuffer == nil) {
        NSLog(@"[VideoWriter addAudio] - audioBuffer was nil.");
        return;
    }
	
	if(assetWriterAudioInput.readyForMoreMediaData == NO) {
        NSLog(@"[VideoWriter addAudio] - not ready for more media data");
        return;
    }
	
	CMTime newBufferTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer);
	if (CMTIME_COMPARE_INLINE(newBufferTime, ==, previousAudioTime)) {
		return;
	}
		
	previousAudioTime = newBufferTime;

    //----------------------------------------------------------
    dispatch_sync(videoWriterQueue, ^{
        BOOL bOk = [self.assetWriterAudioInput appendSampleBuffer:audioBuffer];
        if(bOk == NO) {
            NSString * errorDesc = self.assetWriter.error.description;
            NSLog(@"[VideoWriter addAudio] - error appending audio samples - %@", errorDesc);
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
    
    bTextureCacheSupported = (CVOpenGLESTextureCacheCreate != NULL);
#if TARGET_IPHONE_SIMULATOR
    bTextureCacheSupported = NO; // texture caching does not work properly on the simulator.
#endif
    bUseTextureCache = bTextureCacheSupported;
    if(bEnableTextureCache == NO) {
        bUseTextureCache = NO;
    }
    
    if(bUseTextureCache == NO) {
        return;
    }
    
    //-----------------------------------------------------------------------
    CVReturn error;
#if defined(__IPHONE_6_0)
    error = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                         NULL,
                                         context,
                                         NULL,
                                         &_textureCache);
#else
    error = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                         NULL,
                                         (__bridge void *)context,
                                         NULL,
                                         &_textureCache);
#endif
    
    if(error) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", error);
        bUseTextureCache = NO;
        return;
    }
    
    //-----------------------------------------------------------------------
    CVPixelBufferPoolRef pixelBufferPool = [self.assetWriterInputPixelBufferAdaptor pixelBufferPool];
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, pixelBufferPool, &_textureCachePixelBuffer);
    if(status != kCVReturnSuccess) {
        bUseTextureCache = NO;
        return;
    }
    
    error = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,         // CFAllocatorRef allocator
                                                         _textureCache,               // CVOpenGLESTextureCacheRef textureCache
                                                         _textureCachePixelBuffer,    // CVPixelBufferRef source pixel buffer.
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
}

- (void)destroyTextureCache {
    
    if(_textureCache) {
        CVOpenGLESTextureCacheFlush(_textureCache, 0);
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
    
    if(_textureRef) {
        CFRelease(_textureRef);
        _textureRef = NULL;
    }
    
    if(_textureCachePixelBuffer) {
        CVPixelBufferRelease(_textureCachePixelBuffer);
        _textureCachePixelBuffer = NULL;
    }
}

- (BOOL)isTextureCached {
    return bUseTextureCache;
}

- (unsigned int)textureCacheID {
    if(_textureRef != nil) {
        return CVOpenGLESTextureGetName(_textureRef);
    }
    return 0;
}

- (int)textureCacheTarget {
    if(_textureRef != nil) {
        return CVOpenGLESTextureGetTarget(_textureRef);
    }
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
