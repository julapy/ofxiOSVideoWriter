#include "ofApp.h"
#include "AVFoundationVideoPlayer.h"
#import "DelegateForOF.h"

//--------------------------------------------------------------
void ofApp::setup(){
    
    float fps = 30;
    ofSetFrameRate(fps);
    
//    ofSetOrientation(OF_ORIENTATION_90_RIGHT);
    
    //----------------------------------------------------------
    c1 = ofColor::magenta;
    c2 = ofColor::cyan;
    c3 = ofColor::yellow;
    
    box.setMode(OF_PRIMITIVE_TRIANGLE_STRIP);
    box.addVertex(ofVec3f(0, 0));
    box.addVertex(ofVec3f(ofGetWidth(), 0));
    box.addVertex(ofVec3f(0, ofGetHeight()));
    box.addVertex(ofVec3f(ofGetWidth(), ofGetHeight()));
    box.addColor(c1);
    box.addColor(c1);
    box.addColor(c2);
    box.addColor(c2);
    
    int numOfPoints = 20;
    points.resize(numOfPoints, ofVec2f());
    pointsNew.resize(numOfPoints, ofVec2f());
    
    updateMeshColor();
    updatePoints();
    
    for(int i=0; i<points.size(); i++) {
        points[i] = pointsNew[i];
    }
    
    //----------------------------------------------------------
    videoPlayer0.load("video/ribbons.mp4");
    videoPlayer0.setLoopState(OF_LOOP_NORMAL);
    videoPlayer0.play();

    AVFoundationVideoPlayer * avVideoPlayer = nil;
    avVideoPlayer = (AVFoundationVideoPlayer *)videoPlayer0.getAVFoundationVideoPlayer();
    avVideoPlayer.delegate = [[DelegateForOF alloc] initWithApp:this];
    
    //----------------------------------------------------------
    bRecord = false;
    bRecordChanged = false;
    bRecordReadyToStart = false;
    
    videoWriter.setup(ofGetWidth(), ofGetHeight());
    videoWriter.setFPS(fps);
    videoWriter.addAudioInputFromVideoPlayer(videoPlayer0);
    if(bRecord == true) {
        videoWriter.startRecording();
    }
    
    //----------------------------------------------------------
	ofxGuiSetTextPadding(4);
	ofxGuiSetDefaultWidth(200);
	ofxGuiSetDefaultHeight(80);
    
    recordToggle.setup("record", bRecord);
    recordToggle.setPosition(20, ofGetHeight() - 100);
    recordToggle.addListener(this, &ofApp::recordToggleChanged);
}

void ofApp::recordToggleChanged(bool & value) {
    bRecord = value;
    bRecordChanged = true;
}

void ofApp::setupVideoPlayerForPlayback() {
}

void ofApp::setupVideoPlayerForRecording() {
}

//-------------------------------------------------------------- video player callbacks.
void ofApp::videoPlayerReady() {
    //
}

void ofApp::videoPlayerDidProgress() {
    //
}

void ofApp::videoPlayerDidFinishSeeking() {
    if(bRecord == true) {
        bRecordReadyToStart = true;
    }
}

void ofApp::videoPlayerDidFinishPlayingVideo() {
    //
}

//--------------------------------------------------------------
void ofApp::update(){

    //----------------------------------------------------------
    if(bRecordChanged == true) {
        if(bRecord == true) {
            
            // start recording.
            // first 

            videoPlayer0.setPaused(true);
            videoPlayer0.setPosition(0);
            
        } else {
            
            videoWriter.finishRecording();
            
            videoPlayer0.setPaused(false);
            videoPlayer0.setPosition(0);
            
            AVFoundationVideoPlayer * avVideoPlayer = nil;
            avVideoPlayer = (AVFoundationVideoPlayer *)videoPlayer0.getAVFoundationVideoPlayer();
            [avVideoPlayer setSynchSampleTime:kCMTimeInvalid];
        }
        
        bRecordChanged = false;
    }
    
    if(bRecordReadyToStart == true) {
        bRecordReadyToStart = false;

        videoWriter.startRecording();
    }

    //----------------------------------------------------------
    videoWriter.update();
    
    if(videoWriter.isRecording()) {

        AVFoundationVideoPlayer * avVideoPlayer = nil;
        avVideoPlayer = (AVFoundationVideoPlayer *)videoPlayer0.getAVFoundationVideoPlayer();
        
        int recordFrameNum = videoWriter.getRecordFrameNum();
        float timeSec = recordFrameNum / (float)videoWriter.getFPS();
        [avVideoPlayer setSynchSampleTimeInSec:timeSec];
    }
    
    videoPlayer0.update();

    //----------------------------------------------------------
    if(ofGetFrameNum() % 60 == 0) {
        updatePoints();
    }
    
    for(int i=0; i<points.size(); i++) {
        points[i].x += (pointsNew[i].x - points[i].x) * 0.3;
        points[i].y += (pointsNew[i].y - points[i].y) * 0.3;
    }
}

void ofApp::updateMeshColor() {
    vector<ofFloatColor> & colors = box.getColors();
    colors[0].set(c1);
    colors[1].set(c1);
    colors[2].set(c2);
    colors[3].set(c2);
}

void ofApp::updatePoints() {
    int rectPad = MIN(ofGetWidth(), ofGetHeight()) * 0.2;
    ofRectangle rect(0, 0, ofGetWidth() - rectPad, ofGetHeight() - rectPad);
    rect.x = (ofGetWidth() - rect.width) * 0.5;
    rect.y = (ofGetHeight() - rect.height) * 0.5;
    for(int i=0; i<points.size(); i++) {
        pointsNew[i].x = ofRandom(rect.x, rect.x + rect.width);
        pointsNew[i].y = ofRandom(rect.y, rect.y + rect.height);
    }
}

//--------------------------------------------------------------
void ofApp::draw(){

    videoWriter.begin();
    drawStuff();
    videoWriter.end();
    
    videoWriter.draw();
    
    //------------------------------------
    if(bRecord) {
        ofDrawBitmapString("RECORDING", 20, 20);
    }
    
    ofDrawBitmapString("fps = " + ofToString((int)ofGetFrameRate()), ofGetWidth() - 80, 20);
    
    recordToggle.draw();
}

void ofApp::drawStuff() {
    ofDisableDepthTest();
    
    ofPushStyle();
    ofSetColor(0);
    ofDrawRectangle(0, 0, ofGetWidth(), ofGetHeight());
    ofPopStyle();
    
	box.draw();
    drawPoints();
    
    ofSetColor(255, 220);
    
    int x, y, w, h;
    x = 0;
    y = 0;
    w = videoPlayer0.getWidth();
    h = videoPlayer0.getHeight();
    videoPlayer0.getTexturePtr()->draw(x, y, w, h);
    
    ofSetColor(255);
}

void ofApp::drawPoints() {
    ofPushStyle();
    ofSetLineWidth(2);
    ofSetColor(c3);
    
    for(int i=0; i<points.size()-1; i++) {
        int j = i + 1;
        ofVec2f & p1 = points[i];
        ofVec2f & p2 = points[j];
        ofDrawLine(p1.x, p1.y, p2.x, p2.y);
    }
    
    ofPopStyle();
}

//--------------------------------------------------------------
void ofApp::exit(){

}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs & touch){

}

//--------------------------------------------------------------
void ofApp::touchMoved(ofTouchEventArgs & touch){

}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs & touch){

}

//--------------------------------------------------------------
void ofApp::touchDoubleTap(ofTouchEventArgs & touch){
    //
}

//--------------------------------------------------------------
void ofApp::touchCancelled(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void ofApp::lostFocus(){

}

//--------------------------------------------------------------
void ofApp::gotFocus(){

}

//--------------------------------------------------------------
void ofApp::gotMemoryWarning(){

}

//--------------------------------------------------------------
void ofApp::deviceOrientationChanged(int newOrientation){

}

