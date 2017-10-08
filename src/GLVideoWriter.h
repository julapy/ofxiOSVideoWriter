//
//  GLVideoWriter.h
//  Created by Lukasz Karluk on 28/9/17.
//  Copyright © 2017 Lukasz Karluk. All rights reserved.
//

#include "ofMain.h"
#include "VideoWriter.h"

class GLVideoWriter {
    
public:
    GLVideoWriter();
    ~GLVideoWriter();
    
    void setup(int videoWidth, int videoHeight);
    void setup(int videoWidth, int videoHeight, string filePath);
    void setFPS(float fps);
    float getFPS();
    
    void initShader();
    GLuint compileShader(GLenum type, string source);
    void bindShader();
    void unbindShader();
    
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
    
    float startTime;
    int recordFrameNum;
    float recordFPS;
    bool bLockToFPS;
    bool bUseTextureCache;
    
    GLuint program;
    GLuint shaderVert;
    GLuint shaderFrag;
};
