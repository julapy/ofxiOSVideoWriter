//
//  ofxiOSVideoWriter.h
//  iosScreenRecord
//
//  Created by Lukasz Karluk on 3/09/13.
//
//

#include "ofMain.h"
#include "VideoWriter.h"

class ofxiOSVideoWriter {
    
public:
    ofxiOSVideoWriter();
    ~ofxiOSVideoWriter();
    
    void setup(int videoWidth, int videoHeight);
    void setFPS(float fps);
    
    void update();
    void draw(float x=0, float y=0);
    
    void startRecording();
    void cancelRecording();
    void finishRecording();
    
    void begin();
    void end();
    
    VideoWriter * videoWriter;
    ofFbo fbo;
    ofFbo fboBGRA;
    ofShader shaderBGRA;

    float startTime;
    int startFrame;
    float recordFPS;
    bool bLockToFPS;
};
