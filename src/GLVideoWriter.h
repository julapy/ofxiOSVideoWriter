//
//  GLVideoWriter.h
//  Created by Lukasz Karluk on 28/9/17.
//  Copyright © 2017 Lukasz Karluk. All rights reserved.
//

#include "ofMain.h"
#include "VideoWriter.h"

//-------------------------------------------------------------------------
class GLVideoWriter {
    
public:

    //--------------------------------------------------------------------- Shader.
    class Shader {
    public:
        Shader():
        program(0),
        vert(0),
        frag(0),
        bAllocated(false) {
            //
        }
        
        GLuint program;
        GLuint vert;
        GLuint frag;
        bool bAllocated;
    };
    
    //--------------------------------------------------------------------- Texture.
    class Texture {
    public:
        Texture():
        texW(0),
        texH(0),
        texT(0),
        texU(0),
        texture(0),
        bExternal(false),
        bAllocated(false) {
            //
        }

        GLint texW;
        GLint texH;
        float texT;
        float texU;
        GLuint texture;
        bool bExternal;
        bool bAllocated;
    };

    //--------------------------------------------------------------------- Fbo.
    class Fbo {
    public:
        Fbo():
        fboW(0),
        fboH(0),
        framebuffer(0),
        bAllocated(false) {
            //
        }
        
        GLint fboW;
        GLint fboH;
        GLuint framebuffer;
        Texture tex;
        bool bAllocated;
    };
    
    //--------------------------------------------------------------------- GLVideoWriter
    GLVideoWriter();
    ~GLVideoWriter();
    
    void setup(int videoWidth, int videoHeight);
    void setup(int videoWidth, int videoHeight, string filePath);
    void setFPS(float fps);
    float getFPS();
    
    void initFbo(Fbo & fbo, int w, int h) const;
    void killFbo(Fbo & fbo) const;
    void initFboTexture(Fbo & fbo) const;
    void initFboTexture(Fbo & fbo, GLuint externalTexture) const;
    void initTexture(const Texture & tex) const;
    void killTexture(Texture & tex) const;
    void bindFbo(const Fbo & fbo) const;
    void bindDefaultFbo(const Fbo & fbo) const;
    void beginFbo(const Fbo & fbo) const;
    void endFbo(const Fbo & fbo) const;
    
    void initShader(Shader & shader) const;
    void killShader(Shader & shader) const;
    GLuint compileShader(GLenum type, string source) const;
    void bindShader(const Shader & shader) const;
    void unbindShader(const Shader & shader) const;
    
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
    ofFbo fboRGBA;
    
    float startTime;
    int recordFrameNum;
    float recordFPS;
    bool bLockToFPS;
    bool bUseTextureCache;

    Shader shader;
    Fbo fbo;
    GLint defaultFrameBuffer;

};
