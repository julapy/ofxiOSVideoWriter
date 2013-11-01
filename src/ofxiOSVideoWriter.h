//
//  ofxiOSVideoWriter.h
//  Created by Lukasz Karluk on 3/09/13.
//

#include "ofMain.h"
#include "VideoWriter.h"

class ofxiOSVideoPlayer;
class ofxiOSSoundPlayer;

class ofxiOSVideoWriter {
    
public:
    ofxiOSVideoWriter();
    ~ofxiOSVideoWriter();
    
    void setup(int videoWidth, int videoHeight);
    void setup(int videoWidth, int videoHeight, string filePath);
    void setFPS(float fps);
    float getFPS();
    
    void addAudioInputFromVideoPlayer(ofxiOSVideoPlayer & video);
    void addAudioInputFromSoundPlayer(ofxiOSSoundPlayer & sound);
    
    void update();
    void draw(ofRectangle & rect);
    void draw(float x=0, float y=0);
    void draw(float x, float y, float width, float height);
    
    void startRecording();
    void cancelRecording();
    void finishRecording();
    bool isRecording();
    int getRecordFrameNum();
    
    void initTextureCache();
    void killTextureCache();
    
    void begin();
    void end();
    
    VideoWriter * videoWriter;
    ofFbo fbo;
    ofFbo fboBGRA;
    ofShader shaderBGRA;
    
    vector<ofxiOSVideoPlayer *> videos;
    vector<ofxiOSSoundPlayer *> sounds;

    float startTime;
    int startFrameNum;
    int recordFrameNum;
    float recordFPS;
    bool bLockToFPS;
    bool bUseTextureCache;
};
