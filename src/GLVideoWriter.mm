//
//  GLVideoWriter.m
//  Created by Lukasz Karluk on 28/9/17.
//  Copyright © 2017 Lukasz Karluk. All rights reserved.
//

#include "GLVideoWriter.h"
#include "ofxiOSVideoPlayer.h"
#include "ofxiOSSoundPlayer.h"
#include "ofxiOSEAGLView.h"
#import "AVFoundationVideoPlayer.h"

//------------------------------------------------------------------------- Utils.
int NextPow2(int a){
    int rval=1;
    while(rval<a) rval<<=1;
    return rval;
}

//------------------------------------------------------------------------- Shaders.
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
GLVideoWriter::GLVideoWriter() {
    videoWriter = nil;
    
    startTime = 0;
    recordFrameNum = 0;
    recordFPS = 0;
    bLockToFPS = false;
    bUseTextureCache = false;
}

GLVideoWriter::~GLVideoWriter() {
    if((videoWriter != nil)) {
        [videoWriter release];
        videoWriter = nil;
    }
}

//------------------------------------------------------------------------- setup.
void GLVideoWriter::setup(int videoWidth, int videoHeight) {
    NSString * docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * docVideoPath = [docPath stringByAppendingPathComponent:@"/video.mov"];

    setup(videoWidth, videoHeight, [docVideoPath UTF8String]);
}

void GLVideoWriter::setup(int videoWidth, int videoHeight, string filePath) {
    if((videoWriter != nil)) {
        return;
    }
    
    CGSize videoSize = CGSizeMake(videoWidth, videoHeight);
    videoWriter = [[VideoWriter alloc] initWithPath:[NSString stringWithUTF8String:filePath.c_str()] andVideoSize:videoSize];
    videoWriter.context = [ofxiOSEAGLView getInstance].context; // TODO - this should probably be passed in with init.
    videoWriter.enableTextureCache = YES; // TODO - this should be turned on by default when it is working.
    
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &defaultFrameBuffer);
    
    initShader(shader);
    initFbo(fbo, videoWidth, videoHeight);
    
    fboRGBA.allocate(videoWidth, videoHeight, GL_RGBA, 0);
}

void GLVideoWriter::setFPS(float fps) {
    recordFPS = fps;
    bLockToFPS = true;
}

float GLVideoWriter::getFPS() {
    return recordFPS;
}

//------------------------------------------------------------------------- swizzle shader.
void GLVideoWriter::initFbo(Fbo & fbo, int w, int h) const {
    Texture & tex = fbo.tex;

    fbo.fboW = w;
    fbo.fboH = h;
    tex.texW = NextPow2(w);
    tex.texH = NextPow2(h);
    tex.texT = fbo.fboW / (float)tex.texW;
    tex.texU = fbo.fboH / (float)tex.texH;
    tex.bExternal = false;
    tex.bAllocated = false;

    glGenFramebuffers(1, &fbo.framebuffer);
    
    bindFbo(fbo);

    initFboTexture(fbo);
    
    bindDefaultFbo(fbo);
    
    fbo.bAllocated = true;
}

void GLVideoWriter::killFbo(Fbo & fbo) const {
    if(fbo.bAllocated) {
        glDeleteFramebuffers(1, &fbo.framebuffer);
        fbo = Fbo();
    }
    killTexture(fbo.tex);
}

void GLVideoWriter::initFboTexture(Fbo & fbo) const {
    Texture & tex = fbo.tex;

    killTexture(tex);

    tex.texT = fbo.fboW / (float)tex.texW;
    tex.texU = fbo.fboH / (float)tex.texH;
    
    glGenTextures(1, &tex.texture);
    
    initTexture(tex);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex.texture, 0);
    
    tex.bExternal = false;
    tex.bAllocated = true;
}

void GLVideoWriter::initFboTexture(Fbo & fbo, GLuint externalTexture) const {
    Texture & tex = fbo.tex;

    killTexture(tex);

    tex.texT = 1.0;
    tex.texU = 1.0;
    tex.texture = externalTexture;

    initTexture(tex);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex.texture, 0);
    
    tex.bExternal = true;
    tex.bAllocated = true;
}

void GLVideoWriter::initTexture(const Texture & tex) const {

    glBindTexture(GL_TEXTURE_2D, tex.texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, tex.texW, tex.texH, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
}

void GLVideoWriter::killTexture(Texture & tex) const {
    if(tex.bAllocated && !tex.bExternal) {
        glDeleteTextures(1, (GLuint *)&tex.texture);
        tex = Texture();
    }
}

void GLVideoWriter::bindFbo(const Fbo & fbo) const {
    glBindFramebuffer(GL_FRAMEBUFFER, fbo.framebuffer);
}

void GLVideoWriter::bindDefaultFbo(const Fbo & fbo) const {
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFrameBuffer);
}

void GLVideoWriter::beginFbo(const Fbo & fbo) const {
    
//    (ofRectangle) nativeViewport = {
//        position = (x = 0, y = 0, z = 0)
//        x = 0x000000016f5a8b28
//        y = 0x000000016f5a8b2c
//        width = 640
//        height = 1136
//    }
//    glViewport(nativeViewport.x,nativeViewport.y,nativeViewport.width,nativeViewport.height);

//    ofGLProgrammableRenderer::setupScreenPerspective
//    - calc perspective matrix.
//    - calc modelview matrix.
//    - upload modelViewProjectionMatrix to shader.

    bindFbo( fbo );
    
    glClearColor(1.0, 1.0, 1.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

void GLVideoWriter::endFbo(const Fbo & fbo) const {
    
    bindDefaultFbo( fbo );
}

//------------------------------------------------------------------------- swizzle shader.
void GLVideoWriter::initShader(Shader & shader) const {

    killShader(shader);
    
    shader.program = glCreateProgram();
    shader.vert = compileShader(GL_VERTEX_SHADER, swizzleVertexShader);
    shader.frag = compileShader(GL_FRAGMENT_SHADER, swizzleFragmentShader);
    
    glBindAttribLocation(shader.program, 0, "position");
    glBindAttribLocation(shader.program, 1, "color");
    glBindAttribLocation(shader.program, 2, "normal");
    glBindAttribLocation(shader.program, 3, "texcoord");
    
    glAttachShader(shader.program, shader.vert);
    glAttachShader(shader.program, shader.frag);
    
    glLinkProgram(shader.program);
    
    shader.bAllocated = true;
}

void GLVideoWriter::killShader(Shader & shader) const {
    if(shader.bAllocated) {
    
        glDetachShader(shader.program, shader.vert);
        glDeleteShader(shader.vert);
        
        glDetachShader(shader.program, shader.frag);
        glDeleteShader(shader.frag);
        
        glDeleteProgram(shader.program);
        
        shader = Shader();
    }
}

GLuint GLVideoWriter::compileShader(GLenum type, string source) const {
    GLuint shader = glCreateShader(GL_VERTEX_SHADER);
    const char * sptr = source.c_str();
    int ssize = (int)source.size();
    glShaderSource(shader, 1, &sptr, &ssize);
    glCompileShader(shader);
    return shader;
}

void GLVideoWriter::bindShader(const Shader & shader) const {
    glUseProgram(shader.program);
    
    ofMatrix4x4 modelViewMatrix = ofGetCurrentMatrix(OF_MATRIX_MODELVIEW);
    ofMatrix4x4 projectionMatrix = ofGetCurrentMatrix(OF_MATRIX_PROJECTION);
    ofMatrix4x4 modelViewProjectionMatrix = modelViewMatrix * projectionMatrix;
    // TODO: modelViewProjectionMatrix needs to be calculated without OF.
    
    glUniformMatrix4fv(0, 1, GL_FALSE, modelViewProjectionMatrix.getPtr());
}

void GLVideoWriter::unbindShader(const Shader & shader) const {
    glUseProgram(0);
}

//------------------------------------------------------------------------- update.
void GLVideoWriter::update() {
    //
}

//------------------------------------------------------------------------- draw.
void GLVideoWriter::draw(ofRectangle & rect) {
    draw(rect.x, rect.y, rect.width, rect.height);
}

void GLVideoWriter::draw(float x, float y) {
    draw(x, y, fboRGBA.getWidth(), fboRGBA.getHeight());
}

void GLVideoWriter::draw(float x, float y, float width, float height) {
    fboRGBA.draw(x, y, width, height);
}

//------------------------------------------------------------------------- record api.
void GLVideoWriter::startRecording() {
    if((videoWriter == nil) ||
       [videoWriter isWriting] == YES) {
        return;
    }
    
    startTime = ofGetElapsedTimef();
    recordFrameNum = 0;

    BOOL bRealTime = (bLockToFPS == false);
    bRealTime = YES; // for some reason, if bRealTime is false, it screws things up.
    [videoWriter setExpectsMediaDataInRealTime:bRealTime];
    [videoWriter startRecording];

    if([videoWriter isTextureCached] == YES) {
        initTextureCache();
    }
}

void GLVideoWriter::cancelRecording() {
    if((videoWriter == nil) ||
       [videoWriter isWriting] == NO) {
        return;
    }
    
    [videoWriter cancelRecording];
    
    killTextureCache();
}

void GLVideoWriter::finishRecording() {
    if((videoWriter == nil) ||
       [videoWriter isWriting] == NO) {
        return;
    }
    
    [videoWriter finishRecording];

    killTextureCache();
}

bool GLVideoWriter::isRecording() {
    if((videoWriter != nil) &&
       [videoWriter isWriting] == YES) {
        return YES;
    }
    return NO;
}

int GLVideoWriter::getRecordFrameNum() {
    return recordFrameNum;
}

//------------------------------------------------------------------------- texture cache
void GLVideoWriter::initTextureCache() {
    if(bUseTextureCache == true) {
        return;
    }
    bUseTextureCache = true;
    
    unsigned int textureCacheID = [videoWriter textureCacheID];
    int textureCacheTarget = [videoWriter textureCacheTarget];
    
    int textureW = fboRGBA.getWidth();
    int textureH = fboRGBA.getHeight();
    
    ofTexture texture;
    texture.allocate(textureW, textureH, GL_RGBA);
    
    ofTextureData & texData = texture.getTextureData();
    texData.textureTarget = textureCacheTarget;
    texData.tex_t = 1.0f; // these values need to be reset to 1.0 to work properly.
    texData.tex_u = 1.0f; // assuming this is something to do with the way ios creates the texture cache.
    
    texture.setUseExternalTextureID(textureCacheID);
    texture.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);
    texture.setTextureWrap(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);
    
    fboRGBA.bind();
    fboRGBA.attachTexture(texture, GL_RGBA, 0);
    fboRGBA.unbind();
}

void GLVideoWriter::killTextureCache() {
    if(bUseTextureCache == false) {
        return;
    }
    bUseTextureCache = false;
    
    int textureW = fboRGBA.getWidth();
    int textureH = fboRGBA.getHeight();
    
    ofTexture texture;
    texture.allocate(textureW, textureH, GL_RGBA);
    
    fboRGBA.bind();
    fboRGBA.attachTexture(texture, GL_RGBA, 0);
    fboRGBA.unbind();
}

//------------------------------------------------------------------------- begin / end.
void GLVideoWriter::begin() {
    fboRGBA.begin();

    ofClear(0, 255);
}

void GLVideoWriter::end() {
    fboRGBA.end();

    if((videoWriter == nil) || [videoWriter isWriting] == NO) {
        return;
    }
    
    CMTime frameTime = kCMTimeZero;
    
    if(bLockToFPS) {
        frameTime = CMTimeMake(recordFrameNum, (int)recordFPS);
    } else {
        float time = ofGetElapsedTimef() - startTime;
        frameTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
    }
    
    BOOL bVideoFrameAdded = [videoWriter addFrameAtTime:frameTime];
    if(bVideoFrameAdded == YES) {
        recordFrameNum += 1;
    }
}

