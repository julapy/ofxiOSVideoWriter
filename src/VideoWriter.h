//
//  VideoWriter.h
//
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
@property(nonatomic, retain) AVAssetWriter * assetWriter;
@property(nonatomic, retain) AVAssetWriterInput * assetWriterInput;
@property(nonatomic, retain) AVAssetWriterInputPixelBufferAdaptor * adaptor;
@property(nonatomic, retain) NSURL * outputURL;

- (id)initWithFile:(NSString *)file andVideoSize:(CGSize)size;
- (id)initWithPath:(NSString *)path andVideoSize:(CGSize)size;
- (id)initWithURL:(NSURL *)fileURL andVideoSize:(CGSize)size;

- (void)startRecording;
- (void)cancelRecording;
- (void)finishRecording;
- (BOOL)isWriting;

- (void)addPixelsToFrame:(GLubyte *)pixels
             atFrameTime:(CMTime)frameTime;

- (void)saveMovieToCameraRoll;

@end
