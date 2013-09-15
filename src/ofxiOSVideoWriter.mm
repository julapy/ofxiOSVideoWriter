//
//  ofxiOSVideoWriter.cpp
//  Created by Lukasz Karluk on 3/09/13.
//

#include "ofxiOSVideoWriter.h"
#include "ofxiOSVideoPlayer.h"
#include "ofxiOSSoundPlayer.h"
#include "ofxiOSEAGLView.h"
#import "AVFoundationVideoPlayer.h"

//-------------------------------------------------------------------------
#define STRINGIFY(x) #x

static string swizzleVertexShader = STRINGIFY(
    
    uniform mat4 modelViewProjectionMatrix;
                                              
    attribute vec4 position;
    attribute vec2 texcoord;
                                 
    varying vec2 texCoordVarying;
                                              
    void main()
    {
        texCoordVarying = texcoord;
        gl_Position = modelViewProjectionMatrix * position;
    }
);

static string swizzleFragmentShader = STRINGIFY(
                                                
    precision highp float;
                                                
    uniform sampler2D tex0;
    varying vec2 texCoordVarying;

    void main() {
        gl_FragColor = texture2D(tex0, texCoordVarying).bgra;
    }
);

//-------------------------------------------------------------------------
ofxiOSVideoWriter::ofxiOSVideoWriter() {
    videoWriter = nil;
    
    startTime = 0;
    startFrameNum = 0;
    recordFrameNum = 0;
    recordFPS = 0;
    bLockToFPS = false;
}

ofxiOSVideoWriter::~ofxiOSVideoWriter() {
    if((videoWriter != nil)) {
        [videoWriter release];
        videoWriter = nil;
    }
}

//------------------------------------------------------------------------- setup.
void ofxiOSVideoWriter::setup(int videoWidth, int videoHeight) {
    if((videoWriter != nil)) {
        return;
    }
    
    CGSize videoSize = CGSizeMake(videoWidth, videoHeight);
    videoWriter = [[VideoWriter alloc] initWithFile:@"somefile.mov" andVideoSize:videoSize];
    videoWriter.context = [ofxiOSEAGLView getInstance].context; // TODO - this should probably be passed in with init.
    videoWriter.enableTextureCache = NO; // TODO - this should be turned on by default when it is working.
    
    shaderBGRA.setupShaderFromSource(GL_VERTEX_SHADER, swizzleVertexShader);
    shaderBGRA.setupShaderFromSource(GL_FRAGMENT_SHADER, swizzleFragmentShader);
    shaderBGRA.bindDefaults();
    shaderBGRA.linkProgram();
    
    fbo.allocate(videoWidth, videoHeight, GL_RGBA, 0);
    fboBGRA.allocate(videoWidth, videoHeight, GL_RGBA, 0);
}

void ofxiOSVideoWriter::setFPS(float fps) {
    recordFPS = fps;
    bLockToFPS = true;
}

float ofxiOSVideoWriter::getFPS() {
    return recordFPS;
}

void ofxiOSVideoWriter::addAudioInputFromVideoPlayer(ofxiOSVideoPlayer & video) {
    videos.push_back(&video);
}

void ofxiOSVideoWriter::addAudioInputFromSoundPlayer(ofxiOSSoundPlayer & sound) {
    sounds.push_back(&sound);
}

//------------------------------------------------------------------------- update.
void ofxiOSVideoWriter::update() {
    recordFrameNum = ofGetFrameNum() - startFrameNum;
}

//------------------------------------------------------------------------- draw.
void ofxiOSVideoWriter::draw(float x, float y) {
    fbo.draw(x, y);
}

//------------------------------------------------------------------------- record api.
void ofxiOSVideoWriter::startRecording() {
    if((videoWriter == nil) ||
       [videoWriter isWriting] == YES) {
        return;
    }
    
    startTime = ofGetElapsedTimef();
    startFrameNum = ofGetFrameNum();

    [videoWriter startRecording];
}

void ofxiOSVideoWriter::cancelRecording() {
    if((videoWriter == nil) ||
       [videoWriter isWriting] == NO) {
        return;
    }
    
    [videoWriter cancelRecording];
}

void ofxiOSVideoWriter::finishRecording() {
    if((videoWriter == nil) ||
       [videoWriter isWriting] == NO) {
        return;
    }
    
    [videoWriter finishRecording];
}

bool ofxiOSVideoWriter::isRecording() {
    if((videoWriter != nil) &&
       [videoWriter isWriting] == YES) {
        return YES;
    }
    return NO;
}

int ofxiOSVideoWriter::getRecordFrameNum() {
    return recordFrameNum;
}

//------------------------------------------------------------------------- begin / end.
void ofxiOSVideoWriter::begin() {
    fbo.begin();
}

void ofxiOSVideoWriter::end() {
    fbo.end();

    //----------------------------------------------
    if((videoWriter == nil) ||
       [videoWriter isWriting] == NO) {
        return;
    }
    
    //----------------------------------------------
    if(shaderBGRA.isLoaded()) {
        shaderBGRA.begin();
    }
    fboBGRA.begin();
    
    fbo.draw(0, 0);
    
    fboBGRA.end();
    if(shaderBGRA.isLoaded()) {
        shaderBGRA.end();
    }
    
    //----------------------------------------------
    float time = 0;
    
    if(bLockToFPS) {
        time = recordFrameNum / (float)recordFPS;
    } else {
        time = ofGetElapsedTimef() - startTime;
    }
    
    fboBGRA.bind();

	[videoWriter addFrameAtTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
    
    fboBGRA.unbind();
    
    for(int i=0; i<videos.size(); i++) {
        ofxiOSVideoPlayer & video = *videos[i];
        AVFoundationVideoPlayer * avVideo = (AVFoundationVideoPlayer *)video.getAVFoundationVideoPlayer();
        [videoWriter addAudio:[avVideo getAudioSampleBuffer]];
    }
}
