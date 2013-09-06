//
//  VideoWriter.m
//
//  Created by lukasz karluk on 15/06/12.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "VideoWriter.h"

@interface VideoWriter() {
	CMTime startTime;
    CMTime previousFrameTime;
    BOOL bWriting;
}
@end


@implementation VideoWriter

@synthesize delegate;
@synthesize videoSize;
@synthesize assetWriter;
@synthesize assetWriterInput;
@synthesize adaptor;
@synthesize outputURL;

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
        startTime = kCMTimeZero;
        bWriting = NO;
        videoWriterQueue = dispatch_queue_create("VideoWriterQueue", NULL);
    }
    return self;
}

- (void)dealloc {
    self.assetWriter = nil;
    self.assetWriterInput = nil;
    self.adaptor = nil;
    self.outputURL = nil;
    
    [super dealloc];
}

//--------------------------------------------------------------------------- setup.
- (BOOL)setup {
    
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
        return NO;
    }

    NSDictionary * videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    AVVideoCodecH264, AVVideoCodecKey,
                                    [NSNumber numberWithInt:self.videoSize.width], AVVideoWidthKey,
                                    [NSNumber numberWithInt:self.videoSize.height], AVVideoHeightKey,
                                    nil];
    
    // initialized a new input for video to receive sample buffers for writing
    // passing nil for outputSettings instructs the input to pass through appended samples, doing no processing before they are written
    self.assetWriterInput = [[[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo 
                                                            outputSettings:videoSettings] autorelease];
    self.assetWriterInput.expectsMediaDataInRealTime = YES;

    // You need to use BGRA for the video in order to get realtime encoding.
    // Color-swizzling shader is used to line up glReadPixels' normal RGBA output with the movie input's BGRA.
    NSDictionary * sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                            [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                                            [NSNumber numberWithInt:videoSize.width], kCVPixelBufferWidthKey,
                                                            [NSNumber numberWithInt:videoSize.height], kCVPixelBufferHeightKey,
                                                            nil];
    
    self.adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.assetWriterInput
                                                                                    sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    if([self.assetWriter canAddInput:self.assetWriterInput]) {
        [self.assetWriter addInput:self.assetWriterInput];
    }
    
    return YES;
}

//--------------------------------------------------------------------------- 
- (void)startRecording {
    if(bWriting == YES) {
        return;
    }
    bWriting = YES;
    
    startTime = kCMTimeZero;
    previousFrameTime = kCMTimeInvalid;
    
    if(self.assetWriter == nil) {
        [self setup];
    }
    
	[self.assetWriter startWriting];
	[self.assetWriter startSessionAtSourceTime:startTime];
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
        [self.assetWriterInput markAsFinished];
        [self.assetWriter finishWriting];
        
        self.assetWriterInput = nil;
        self.assetWriter = nil;
        self.adaptor = nil;
        
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
        [self.assetWriterInput markAsFinished];
        [self.assetWriter finishWriting];
        
        self.assetWriterInput = nil;
        self.assetWriter = nil;
        self.adaptor = nil;
        
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

- (void)addPixelsToFrame:(GLubyte *)pixels
             atFrameTime:(CMTime)frameTime {

    if(bWriting == NO) {
        return;
    }
    
    if((CMTIME_IS_INVALID(frameTime)) ||
       (CMTIME_COMPARE_INLINE(frameTime, ==, previousFrameTime)) ||
       (CMTIME_IS_INDEFINITE(frameTime))) {
        return;
    }
    
    if(assetWriterInput.readyForMoreMediaData == NO) {
        NSLog(@"Had to drop a video frame");
        return;
    }
    
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, [adaptor pixelBufferPool], &pxbuffer);
    if((pxbuffer == NULL) || (status != kCVReturnSuccess)) {
        return;
    } else {
        CVPixelBufferLockBaseAddress(pxbuffer, 0);
        
        GLubyte * pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pxbuffer);
        glReadPixels(0, 0, self.videoSize.width, self.videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
    }
    
    dispatch_sync(videoWriterQueue, ^{
        if([adaptor appendPixelBuffer:pxbuffer withPresentationTime:frameTime] == NO) {
            NSLog(@"Problem appending pixel buffer at time: %lld", frameTime.value);
        } else {
            // NSLog(@"Recorded video sample time: %lld, %d, %lld", frameTime.value, frameTime.timescale, frameTime.epoch);
        }
        CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
        
        previousFrameTime = frameTime;
    });
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
