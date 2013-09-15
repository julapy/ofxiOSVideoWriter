#include "ofMain.h"
#include "ofAppiOSWindow.h"
#include "ofApp.h"

int main(){
    
    ofAppiOSWindow * window = new ofAppiOSWindow();
    window->enableRendererES2();    // ofxiOSVideoWriter only works properly using ES2 renderer, because it needs shaders on iOS.
    window->enableDepthBuffer();
    window->enableRetina();
    
	ofSetupOpenGL(window, 1024, 768, OF_FULLSCREEN);
	ofRunApp(new ofApp);
}
