#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUCocoaUIView.h>
#include <dlfcn.h>
#include <cstdio>
#include <cmath>
#include <cstring>
#import "presets.h"
#include "DCProperties.h"
struct TestSignal {float amplitude=0;};
static OSStatus testInput(void*context,AudioUnitRenderActionFlags*,const AudioTimeStamp*time,UInt32,UInt32 frames,AudioBufferList*audio){auto*signal=(TestSignal*)context;for(UInt32 c=0;c<audio->mNumberBuffers;c++){float*out=(float*)audio->mBuffers[c].mData;if(!out)return kAudio_ParamError;for(UInt32 i=0;i<frames;i++)out[i]=signal->amplitude*sin(2*M_PI*440*(time->mSampleTime+i)/48000.);}return noErr;}
@protocol DCTestEditor
- (void)refreshView;
- (NSInteger)meterFrame;
@end
static void require(bool value,const char*name){if(!value){fprintf(stderr,"FAIL: %s\n",name);exit(1);}printf("PASS: %s\n",name);}
int main(int argc,char**argv){@autoreleasepool{
    require(argc==3,"arguments");
    NSString*path=[NSString stringWithUTF8String:argv[1]];NSBundle*b=[NSBundle bundleWithPath:path];NSError*error=nil;
    require([b loadAndReturnError:&error],"bundle load");
    void*lib=dlopen([[path stringByAppendingPathComponent:@"Contents/MacOS/DecapitatorRust"] fileSystemRepresentation],RTLD_NOW|RTLD_LOCAL);
    auto factory=(AudioComponentFactoryFunction)dlsym(lib,"DCDevFactory");require(factory,"factory symbol");
    AudioComponentDescription desc={'aufx','Dcp1','StDv',kAudioComponentFlag_SandboxSafe,0};
    AudioComponent component=AudioComponentRegister(&desc,CFSTR("ST Analysis: Decapitator Rust"),65536,factory);require(component,"component registration");
    AudioUnit unit=nullptr;require(AudioComponentInstanceNew(component,&unit)==0,"instance creation");
    UInt32 size=sizeof(UInt32)*12;UInt32 ids[12]={};require(AudioUnitGetProperty(unit,kAudioUnitProperty_ParameterList,0,0,ids,&size)==0&&size==48,"twelve parameters");
    for(UInt32 id:ids){AudioUnitParameterInfo info={};size=sizeof(info);require(AudioUnitGetProperty(unit,kAudioUnitProperty_ParameterInfo,0,id,&info,&size)==0,"parameter metadata");}
    CFArrayRef factoryPresets=NULL;size=sizeof(factoryPresets);require(AudioUnitGetProperty(unit,kAudioUnitProperty_FactoryPresets,0,0,&factoryPresets,&size)==0&&CFArrayGetCount(factoryPresets)==47,"47 standard AU factory presets");
    SInt32 defaultIndex=-1;for(CFIndex i=0;i<CFArrayGetCount(factoryPresets);i++){const AUPreset*p=(const AUPreset*)CFArrayGetValueAtIndex(factoryPresets,i);require(p&&p->presetName,"factory preset name");if(CFEqual(p->presetName,CFSTR("Default")))defaultIndex=p->presetNumber;}
    require(defaultIndex>=0,"Default factory preset");
    AUPreset selected={0,NULL};require(AudioUnitSetProperty(unit,kAudioUnitProperty_PresentPreset,0,0,&selected,sizeof(selected))==0,"select factory preset through AU property");
    AUPreset current={};size=sizeof(current);require(AudioUnitGetProperty(unit,kAudioUnitProperty_PresentPreset,0,0,&current,&size)==0&&current.presetNumber==0,"selected factory preset readback");CFRelease(current.presetName);
    selected={defaultIndex,NULL};require(AudioUnitSetProperty(unit,kAudioUnitProperty_PresentPreset,0,0,&selected,sizeof(selected))==0,"restore Default factory preset");CFRelease(factoryPresets);
    require(AudioUnitSetParameter(unit,11,0,0,.25,0)==0,"set Drive");
    require(AudioUnitSetParameter(unit,11,0,0,NAN,0)!=0,"reject NaN");
    CFPropertyListRef state=nullptr;size=sizeof(state);require(AudioUnitGetProperty(unit,kAudioUnitProperty_ClassInfo,0,0,&state,&size)==0,"save state");
    require(AudioUnitSetParameter(unit,11,0,0,.75,0)==0,"change Drive");
    require(AudioUnitSetProperty(unit,kAudioUnitProperty_ClassInfo,0,0,&state,sizeof(state))==0,"restore state");
    float value=0;require(AudioUnitGetParameter(unit,11,0,0,&value)==0&&value==.25,"state restores Drive");CFRelease(state);
    require(AudioUnitInitialize(unit)==0,"initialize");
    double latency=0;size=sizeof(latency);require(AudioUnitGetProperty(unit,kAudioUnitProperty_Latency,0,0,&latency,&size)==0&&fabs(latency-62./48000.)<1e-12,"62 frame model latency at 48 kHz");
    typedef int(*DecodePreset)(const unsigned char*,size_t,float*,char*,size_t);
    auto decode=(DecodePreset)dlsym(lib,"dc_decode_preset");require(decode!=nullptr,"preset importer symbol");
    NSString*presetPath=[[[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reference/presets/Default.toy"];
    NSData*preset=[NSData dataWithContentsOfFile:presetPath];require(preset!=nil,"local preset fixture");
    float imported[12]={};char message[512]={};require(decode((const unsigned char*)preset.bytes,preset.length,imported,message,sizeof(message))==0,"factory archive import");
    float expected[]={0,0,0,0,0,.5,1,1,1,0,0,1};UInt32 parameterIDs[]={7,10,11,12,13,14,15,16,17,18,19,20};
    for(int i=0;i<12;i++){
        require(imported[i]==expected[i],"import matches original control value");
        require(AudioUnitSetParameter(unit,parameterIDs[i],0,0,imported[i],0)==0,"apply imported value");
        float readback=-1;require(AudioUnitGetParameter(unit,parameterIDs[i],0,0,&readback)==0&&readback==expected[i],"imported value readback");
    }
    state=nullptr;size=sizeof(state);require(AudioUnitGetProperty(unit,kAudioUnitProperty_ClassInfo,0,0,&state,&size)==0,"save imported preset state");
    AudioUnitSetParameter(unit,11,0,0,.9,0);require(AudioUnitSetProperty(unit,kAudioUnitProperty_ClassInfo,0,0,&state,sizeof(state))==0,"restore imported preset state");
    value=0;require(AudioUnitGetParameter(unit,11,0,0,&value)==0&&value==0,"preset survives state recall");CFRelease(state);
    AudioUnitCocoaViewInfo ui={};size=sizeof(ui);require(AudioUnitGetProperty(unit,kAudioUnitProperty_CocoaUI,0,0,&ui,&size)==0,"editor factory metadata");
    NSString*outputDirectory=[[NSString stringWithUTF8String:argv[2]]stringByDeletingLastPathComponent];setenv("ROUNDBOYS_PRESET_DIR",outputDirectory.UTF8String,1);
    [NSApplication sharedApplication];Class klass=NSClassFromString((__bridge NSString*)ui.mCocoaAUViewClass[0]);require(klass!=nil,"editor factory class");
    id<AUCocoaUIBase> provider=[[klass alloc]init];NSView*view=[provider uiViewForAudioUnit:unit withSize:NSMakeSize(500,180)];require(view!=nil,"editor creation");
    NSWindow*window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,view.frame.size.width,view.frame.size.height) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.contentView=view;[view layoutSubtreeIfNeeded];
    NSBitmapImageRep*image=[view bitmapImageRepForCachingDisplayInRect:view.bounds];[view cacheDisplayInRect:view.bounds toBitmapImageRep:image];
    NSData*png=[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}];require([png writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES],"editor image");
    require(view.frame.size.height==386,"preset bar above faceplate");
    DCPresetBar*bar=nil;for(NSView*child in view.subviews)if([child isKindOfClass:NSClassFromString(@"DCPresetBar")])bar=(DCPresetBar*)child;
    require(bar!=nil,"preset dropdown and save controls");
    AudioUnitSetParameter(unit,11,0,0,.67,0);AudioUnitSetParameter(unit,10,0,0,3,0);
    NSURL*savedURL=[NSURL fileURLWithPath:[outputDirectory stringByAppendingPathComponent:@"RoundTrip.aupreset"]];NSError*presetError=nil;
    require([bar savePresetToURL:savedURL error:&presetError],"save user AU preset");
    AudioUnitSetParameter(unit,11,0,0,0,0);AudioUnitSetParameter(unit,10,0,0,0,0);
    require([bar loadPresetFromURL:savedURL error:&presetError],"load saved user AU preset");
    float restored=0;require(AudioUnitGetParameter(unit,11,0,0,&restored)==0&&restored==.67f,"user preset restores Drive");
    require(AudioUnitGetParameter(unit,10,0,0,&restored)==0&&restored==3,"user preset restores Style");
    current={};size=sizeof(current);require(AudioUnitGetProperty(unit,kAudioUnitProperty_PresentPreset,0,0,&current,&size)==0&&CFEqual(current.presetName,CFSTR("RoundTrip")),"user preset name recall");CFRelease(current.presetName);
    NSMutableDictionary*invalid=[[NSDictionary dictionaryWithContentsOfURL:savedURL]mutableCopy];invalid[@"subtype"]=@((UInt32)'BAD ');
    NSURL*invalidURL=[NSURL fileURLWithPath:[outputDirectory stringByAppendingPathComponent:@"WrongPlugin.aupreset"]];[invalid writeToURL:invalidURL atomically:YES];
    require(![bar loadPresetFromURL:invalidURL error:&presetError],"reject another plug-in preset");
    require(AudioUnitGetParameter(unit,11,0,0,&restored)==0&&restored==.67f,"failed import leaves controls unchanged");
    selected={defaultIndex,NULL};AudioUnitSetProperty(unit,kAudioUnitProperty_PresentPreset,0,0,&selected,sizeof(selected));
    id<DCTestEditor>editor=(id)view;[editor refreshView];require([editor meterFrame]==0,"meter starts at rest");
    TestSignal signal;AURenderCallbackStruct input={testInput,&signal};require(AudioUnitSetProperty(unit,kAudioUnitProperty_SetRenderCallback,kAudioUnitScope_Input,0,&input,sizeof(input))==0,"meter test input");
    float left[1024],right[1024];struct {UInt32 count;AudioBuffer buffers[2];} audio={2,{{1,sizeof(left),left},{1,sizeof(right),right}}};
    UInt32 offset=0;auto renderMeter=[&](){AudioTimeStamp time={};time.mSampleTime=offset;time.mFlags=kAudioTimeStampSampleTimeValid;AudioUnitRenderActionFlags flags=0;audio.buffers[0].mDataByteSize=sizeof(left);audio.buffers[1].mDataByteSize=sizeof(right);OSStatus s=AudioUnitRender(unit,&flags,&time,0,1024,(AudioBufferList*)&audio);offset+=1024;require(s==0,"live meter audio render");[editor refreshView];};
    signal.amplitude=.1;AudioUnitSetParameter(unit,11,0,0,.8,0);
    for(int i=0;i<30;i++){renderMeter();[[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.004]];}
    DCMeterReading reading={};size=sizeof(reading);require(AudioUnitGetProperty(unit,kDCMeterProperty,0,0,&reading,&size)==0&&reading.sequence>0&&reading.decibels>-30&&reading.decibels<0,"audio thread publishes a live meter reading");
    NSInteger hotFrame=[editor meterFrame];require(hotFrame>0&&hotFrame<90,"normal driven audio moves the needle without pinning it");
    NSBitmapImageRep*liveImage=[view bitmapImageRepForCachingDisplayInRect:view.bounds];[view cacheDisplayInRect:view.bounds toBitmapImageRep:liveImage];
    [[liveImage representationUsingType:NSBitmapImageFileTypePNG properties:@{}]writeToFile:[outputDirectory stringByAppendingPathComponent:@"editor-live.png"] atomically:YES];
    signal.amplitude=0;for(int i=0;i<180;i++){renderMeter();[[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.003]];}
    for(int i=0;i<100&&[editor meterFrame]>0;i++){[editor refreshView];[[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
    require([editor meterFrame]==0,"meter returns to rest after silence");
    [[NSFileManager defaultManager]removeItemAtURL:invalidURL error:nil];
    CFRelease(ui.mCocoaAUViewBundleLocation);CFRelease(ui.mCocoaAUViewClass[0]);window.contentView=nil;
    require(AudioUnitUninitialize(unit)==0,"uninitialize");require(AudioComponentInstanceDispose(unit)==0,"dispose");
}return 0;}
