#pragma once

#include "ofMain.h"
#include "ofxiOS.h"
#include "ofxiOSExtras.h"
#include "ofxiOSVideoWriter.h"

#include "ofxGui.h"

class ofApp : public ofxiOSApp{
	
public:
    void setup();
    void update();
    void draw();
    void exit();
    
    void recordToggleChanged(bool & value);
    void setupVideoPlayerForPlayback();
    void setupVideoPlayerForRecording();
    
    void videoPlayerReady();
    void videoPlayerDidProgress();
    void videoPlayerDidFinishSeeking();
    void videoPlayerDidFinishPlayingVideo();
    
    void updateMeshColor();
    void updatePoints();
    void drawStuff();
    void drawPoints();
	
    void touchDown(ofTouchEventArgs & touch);
    void touchMoved(ofTouchEventArgs & touch);
    void touchUp(ofTouchEventArgs & touch);
    void touchDoubleTap(ofTouchEventArgs & touch);
    void touchCancelled(ofTouchEventArgs & touch);
    
    void lostFocus();
    void gotFocus();
    void gotMemoryWarning();
    void deviceOrientationChanged(int newOrientation);
    
    ofxiOSVideoWriter videoWriter;
    bool bRecord;
    bool bRecordChanged;
    bool bRecordReadyToStart;
    
    ofxiOSVideoPlayer videoPlayer0;
    
    ofMesh box;
    ofFloatColor c1;
    ofFloatColor c2;
    ofFloatColor c3;
    vector<ofVec2f> points;
    vector<ofVec2f> pointsNew;
    
    ofxToggle recordToggle;
};


