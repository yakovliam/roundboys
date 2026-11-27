#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUCocoaUIView.h>
#include <dlfcn.h>
#include <cstdio>
#include <cmath>
#include <cstring>
static void require(bool value,const char*name){if(!value){fprintf(stderr,"FAIL: %s\n",name);exit(1);}printf("PASS: %s\n",name);}
int main(int argc,char**argv){@autoreleasepool{
    require(argc==3,"arguments");
    NSString*path=[NSString stringWithUTF8String:argv[1]];NSBundle*b=[NSBundle bundleWithPath:path];NSError*error=nil;
    require([b loadAndReturnError:&error],"bundle load");
    void*lib=dlopen([[path stringByAppendingPathComponent:@"Contents/MacOS/LittleRadiatorRust"] fileSystemRepresentation],RTLD_NOW|RTLD_LOCAL);
    auto factory=(AudioComponentFactoryFunction)dlsym(lib,"LRDevFactory");require(factory,"factory symbol");
    AudioComponentDescription desc={'aufx','LrD1','StDv',kAudioComponentFlag_SandboxSafe,0};
    AudioComponent component=AudioComponentRegister(&desc,CFSTR("ST Analysis: Little Radiator Rust"),65536,factory);require(component,"component registration");
    AudioUnit unit=nullptr;require(AudioComponentInstanceNew(component,&unit)==0,"instance creation");
    UInt32 size=sizeof(UInt32)*5;UInt32 ids[5]={};require(AudioUnitGetProperty(unit,kAudioUnitProperty_ParameterList,0,0,ids,&size)==0&&size==20,"five parameters");
    for(UInt32 id:ids){AudioUnitParameterInfo info={};size=sizeof(info);require(AudioUnitGetProperty(unit,kAudioUnitProperty_ParameterInfo,0,id,&info,&size)==0,"parameter metadata");}
    require(AudioUnitSetParameter(unit,8,0,0,.25,0)==0,"set Heat");
    require(AudioUnitSetParameter(unit,8,0,0,NAN,0)!=0,"reject NaN");
    CFPropertyListRef state=nullptr;size=sizeof(state);require(AudioUnitGetProperty(unit,kAudioUnitProperty_ClassInfo,0,0,&state,&size)==0,"save state");
    require(AudioUnitSetParameter(unit,8,0,0,.75,0)==0,"change Heat");
    require(AudioUnitSetProperty(unit,kAudioUnitProperty_ClassInfo,0,0,&state,sizeof(state))==0,"restore state");
    float value=0;require(AudioUnitGetParameter(unit,8,0,0,&value)==0&&value==.25,"state restores Heat");CFRelease(state);
    require(AudioUnitInitialize(unit)==0,"initialize");
    double latency=0;size=sizeof(latency);require(AudioUnitGetProperty(unit,kAudioUnitProperty_Latency,0,0,&latency,&size)==0&&fabs(latency-.001)<1e-12,"48 frame latency at 48 kHz");
    typedef int(*DecodePreset)(const unsigned char*,size_t,float*,char*,size_t);
    auto decode=(DecodePreset)dlsym(lib,"lr_decode_preset");require(decode!=nullptr,"preset importer symbol");
    NSString*presetPath=[[[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reference/presets/Bass Beef.toy"];
    NSData*preset=[NSData dataWithContentsOfFile:presetPath];require(preset!=nil,"local preset fixture");
    float imported[5]={};char message[512]={};require(decode((const unsigned char*)preset.bytes,preset.length,imported,message,sizeof(message))==0,"factory archive import");
    float expected[]={0,.74,.5,1,1};UInt32 parameterIDs[]={7,8,9,10,12};
    for(int i=0;i<5;i++){
        require(imported[i]==expected[i],"import matches original control value");
        require(AudioUnitSetParameter(unit,parameterIDs[i],0,0,imported[i],0)==0,"apply imported value");
        float readback=-1;require(AudioUnitGetParameter(unit,parameterIDs[i],0,0,&readback)==0&&readback==expected[i],"imported value readback");
    }
    state=nullptr;size=sizeof(state);require(AudioUnitGetProperty(unit,kAudioUnitProperty_ClassInfo,0,0,&state,&size)==0,"save imported preset state");
    AudioUnitSetParameter(unit,8,0,0,0,0);require(AudioUnitSetProperty(unit,kAudioUnitProperty_ClassInfo,0,0,&state,sizeof(state))==0,"restore imported preset state");
    value=0;require(AudioUnitGetParameter(unit,8,0,0,&value)==0&&value==.74f,"preset survives state recall");CFRelease(state);
    AudioUnitCocoaViewInfo ui={};size=sizeof(ui);require(AudioUnitGetProperty(unit,kAudioUnitProperty_CocoaUI,0,0,&ui,&size)==0,"editor factory metadata");
    [NSApplication sharedApplication];Class klass=NSClassFromString((__bridge NSString*)ui.mCocoaAUViewClass[0]);require(klass!=nil,"editor factory class");
    id<AUCocoaUIBase> provider=[[klass alloc]init];NSView*view=[provider uiViewForAudioUnit:unit withSize:NSMakeSize(500,180)];require(view!=nil,"editor creation");
    NSWindow*window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,view.frame.size.width,view.frame.size.height) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.contentView=view;[view layoutSubtreeIfNeeded];
    NSBitmapImageRep*image=[view bitmapImageRepForCachingDisplayInRect:view.bounds];[view cacheDisplayInRect:view.bounds toBitmapImageRep:image];
    NSData*png=[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}];require([png writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES],"editor image");
    CFRelease(ui.mCocoaAUViewBundleLocation);CFRelease(ui.mCocoaAUViewClass[0]);window.contentView=nil;
    require(AudioUnitUninitialize(unit)==0,"uninitialize");require(AudioComponentInstanceDispose(unit)==0,"dispose");
}return 0;}
