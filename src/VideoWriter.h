//
//  VideoWriter.h
//  Created by lukasz karluk on 15/06/12.
//

#import <AVFoundation/AVFoundation.h>

@protocol VideoWriterDelegate <NSObject>
@optional
- (void)videoWriterComplete:(NSURL *)url;
- (void)videoWriterCancelled;
- (void)videoWriterSavedToCameraRoll;
- (void)videoWriterError:(NSError *)error;
@end

@interface VideoWriter : NSObject {
    id<AVAudioPlayerDelegate> delegate;
    dispatch_queue_t videoWriterQueue;
}

@property(nonatomic, assign) id delegate;
@property(nonatomic, assign) CGSize videoSize;
@property(nonatomic, retain) EAGLContext * context;
@property(nonatomic, retain) AVAssetWriter * assetWriter;
@property(nonatomic, retain) AVAssetWriterInput * assetWriterVideoInput;
@property(nonatomic, retain) AVAssetWriterInput * assetWriterAudioInput;
@property(nonatomic, retain) AVAssetWriterInputPixelBufferAdaptor * assetWriterInputPixelBufferAdaptor;
@property(nonatomic, retain) NSURL * outputURL;
@property(nonatomic, assign) BOOL enableTextureCache;

- (id)initWithFile:(NSString *)file andVideoSize:(CGSize)size;
- (id)initWithPath:(NSString *)path andVideoSize:(CGSize)size;
- (id)initWithURL:(NSURL *)fileURL andVideoSize:(CGSize)size;

- (void)startRecording;
- (void)cancelRecording;
- (void)finishRecording;
- (BOOL)isWriting;

- (void)addFrameAtTime:(CMTime)frameTime;
- (void)addAudio:(CMSampleBufferRef)audioBuffer;

- (BOOL)isTextureCached;
- (unsigned int)textureCacheID;
- (int)textureCacheTarget;

- (void)saveMovieToCameraRoll;

@end
