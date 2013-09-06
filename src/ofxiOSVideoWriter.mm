//
//  ofxiOSVideoWriter.cpp
//  iosScreenRecord
//
//  Created by Lukasz Karluk on 3/09/13.
//
//

#include "ofxiOSVideoWriter.h"

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
    startFrame = 0;
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

//------------------------------------------------------------------------- update.
void ofxiOSVideoWriter::update() {
    //
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
    startFrame = ofGetFrameNum();
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

//------------------------------------------------------------------------- begin / end.
void ofxiOSVideoWriter::begin() {
    fbo.begin();
}

void ofxiOSVideoWriter::end() {
    fbo.end();

    //----------------------------------------------
    shaderBGRA.begin();
    fboBGRA.begin();
    
    fbo.draw(0, 0);
    
    fboBGRA.end();
    shaderBGRA.end();

    //----------------------------------------------
    if((videoWriter == nil) ||
       [videoWriter isWriting] == NO) {
        return;
    }
    
    //----------------------------------------------
    float time = 0;
    
    if(bLockToFPS) {
        int frameNum = ofGetFrameNum() - startFrame;
        time = frameNum / (float)recordFPS;
    } else {
        time = ofGetElapsedTimef() - startTime;
    }
    
    fboBGRA.bind();

    CMTime frameTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
	[videoWriter addPixelsToFrame:NULL atFrameTime:frameTime];
    
    fboBGRA.unbind();
}
