//
//  DelegateForOF.m
//  Created by lukasz karluk on 6/06/12.
//

#import "DelegateForOF.h"
#import "AVFoundationVideoPlayer.h"
#import "ofApp.h"

@interface DelegateForOF() <AVFoundationVideoPlayerDelegate> {
    ofApp * app;
}
@end

@implementation DelegateForOF {
    //
}

- (id)initWithApp:(ofApp *)myApp {
    self = [super init];
    if(self) {
        app = myApp;
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
}

- (void)playerReady {
    app->videoPlayerReady();
}

- (void)playerDidProgress {
    app->videoPlayerDidProgress();
}

- (void)playerDidFinishSeeking {
    app->videoPlayerDidFinishSeeking();
}

- (void)playerDidFinishPlayingVideo {
    app->videoPlayerDidFinishPlayingVideo();
}

@end
