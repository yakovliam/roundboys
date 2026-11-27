#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUCocoaUIView.h>
#include <atomic>
#include <cmath>
#include <cstring>
#include <vector>
extern "C" {
void *lr_create(double rate);
void lr_destroy(void *);
int lr_process(void *, float *, float *, size_t, float,float,float,float,float);
void lr_reset(void *);
int lr_decode_preset(const unsigned char *bytes, size_t length, float *out_values, char *message, size_t capacity);
}
static const UInt32 ids[]={7,8,9,10,12};
static const char *names[]={"Bypass","Heat","Mix","Bias","Noise"};
static const float defaults[]={0,.5,1,0,1};
struct Unit {
    AudioComponentPlugInInterface api;
    AudioUnit host=nullptr;
    AudioStreamBasicDescription format{};
    AURenderCallbackStruct input{};
    AudioUnitConnection connection{};
    std::atomic<float> values[5];
    UInt32 maximum=4096;
    void *dsp=nullptr;
    std::vector<float> left,right;
    Unit() { for(int i=0;i<5;i++) values[i]=defaults[i];
        format={48000,kAudioFormatLinearPCM,kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked|kAudioFormatFlagIsNonInterleaved,4,1,4,2,32,0}; }
};
static OSStatus openUnit(void *self,AudioComponentInstance host) { ((Unit*)self)->host=host; return noErr; }
static OSStatus uninit(void *self) { auto*u=(Unit*)self; if(u->dsp)lr_destroy(u->dsp);u->dsp=nullptr;return noErr; }
static OSStatus closeUnit(void *self) { uninit(self);delete (Unit*)self;return noErr; }
static OSStatus init(void *self) { auto*u=(Unit*)self; uninit(self); u->left.resize(u->maximum);u->right.resize(u->maximum);
    u->dsp=lr_create(u->format.mSampleRate);return u->dsp?noErr:kAudioUnitErr_FormatNotSupported; }
static OSStatus reset(void*self,AudioUnitScope,AudioUnitElement) {auto*u=(Unit*)self;if(u->dsp)lr_reset(u->dsp);return noErr;}
static bool validBus(AudioUnitScope scope,AudioUnitElement element) { return element==0 && (scope==kAudioUnitScope_Global || scope==kAudioUnitScope_Input || scope==kAudioUnitScope_Output); }
static OSStatus getParameter(void*self,AudioUnitParameterID id,AudioUnitScope scope,AudioUnitElement element,AudioUnitParameterValue*out) {
    if(!out || scope!=kAudioUnitScope_Global || element) return kAudioUnitErr_InvalidScope;
    for(int i=0;i<5;i++)if(ids[i]==id){*out=((Unit*)self)->values[i].load();return noErr;}return kAudioUnitErr_InvalidParameter;
}
static OSStatus setParameter(void*self,AudioUnitParameterID id,AudioUnitScope scope,AudioUnitElement element,AudioUnitParameterValue value,UInt32 offset) {
    if(scope!=kAudioUnitScope_Global || element)return kAudioUnitErr_InvalidScope;
    if(offset || !std::isfinite(value) || value<0 || value>1)return kAudioUnitErr_InvalidParameterValue;
    for(int i=0;i<5;i++)if(ids[i]==id){((Unit*)self)->values[i]=value;return noErr;}return kAudioUnitErr_InvalidParameter;
}
static OSStatus info(void*self,AudioUnitPropertyID id,AudioUnitScope scope,AudioUnitElement element,UInt32*size,Boolean*writable) {
    if(!size||!writable)return kAudio_ParamError;
    if(!validBus(scope,element) && !(id==kAudioUnitProperty_ParameterInfo && scope==kAudioUnitScope_Global))return kAudioUnitErr_InvalidElement;
    *writable=false;
    switch(id) {
        case kAudioUnitProperty_StreamFormat:*size=sizeof(AudioStreamBasicDescription);*writable=true;break;
        case kAudioUnitProperty_ElementCount:*size=sizeof(UInt32);break;
        case kAudioUnitProperty_MaximumFramesPerSlice:*size=sizeof(UInt32);*writable=true;break;
        case kAudioUnitProperty_ParameterList:*size=sizeof(ids);break;
        case kAudioUnitProperty_ParameterInfo:*size=sizeof(AudioUnitParameterInfo);break;
        case kAudioUnitProperty_SetRenderCallback:*size=sizeof(AURenderCallbackStruct);*writable=true;break;
        case kAudioUnitProperty_MakeConnection:*size=sizeof(AudioUnitConnection);*writable=true;break;
        case kAudioUnitProperty_Latency: case kAudioUnitProperty_TailTime:*size=sizeof(Float64);break;
        case kAudioUnitProperty_SupportedNumChannels:*size=sizeof(AUChannelInfo);break;
        case kAudioUnitProperty_CocoaUI:*size=sizeof(AudioUnitCocoaViewInfo);break;
        case kAudioUnitProperty_ClassInfo:*size=sizeof(CFPropertyListRef);*writable=true;break;
        case kAudioUnitProperty_BypassEffect:*size=sizeof(UInt32);*writable=true;break;
        case kAudioUnitProperty_InPlaceProcessing:*size=sizeof(UInt32);break;
        default:return kAudioUnitErr_InvalidProperty;
    } return noErr;
}
static NSBundle *bundle() { return [NSBundle bundleWithIdentifier:@"dev.stanalysis.LittleRadiator"]; }
static OSStatus get(void*self,AudioUnitPropertyID id,AudioUnitScope scope,AudioUnitElement element,void*out,UInt32*size) {
    UInt32 needed;Boolean writable;OSStatus status=info(self,id,scope,element,&needed,&writable);
    if(status)return status;if(!out||!size||*size<needed)return kAudioUnitErr_InvalidPropertyValue;
    auto*u=(Unit*)self; *size=needed;
    switch(id) {
        case kAudioUnitProperty_StreamFormat:memcpy(out,&u->format,needed);break;
        case kAudioUnitProperty_ElementCount:*(UInt32*)out=1;break;
        case kAudioUnitProperty_MaximumFramesPerSlice:*(UInt32*)out=u->maximum;break;
        case kAudioUnitProperty_ParameterList:memcpy(out,ids,needed);break;
        case kAudioUnitProperty_ParameterInfo:{
            int i=0;while(i<5&&ids[i]!=element)i++;if(i==5)return kAudioUnitErr_InvalidParameter;
            auto*p=(AudioUnitParameterInfo*)out;memset(p,0,sizeof(*p));strlcpy(p->name,names[i],sizeof(p->name));
            p->minValue=0;p->maxValue=1;p->defaultValue=defaults[i];
            p->unit=(i==1||i==2)?kAudioUnitParameterUnit_Generic:kAudioUnitParameterUnit_Boolean;
            p->flags=kAudioUnitParameterFlag_IsReadable|kAudioUnitParameterFlag_IsWritable;break;}
        case kAudioUnitProperty_SetRenderCallback:memcpy(out,&u->input,needed);break;
        case kAudioUnitProperty_MakeConnection:memcpy(out,&u->connection,needed);break;
        case kAudioUnitProperty_Latency:*(Float64*)out=48./u->format.mSampleRate;break;
        case kAudioUnitProperty_TailTime:*(Float64*)out=0.2;break;
        case kAudioUnitProperty_SupportedNumChannels:*(AUChannelInfo*)out={2,2};break;
        case kAudioUnitProperty_InPlaceProcessing:*(UInt32*)out=1;break;
        case kAudioUnitProperty_BypassEffect:*(UInt32*)out=u->values[0]>=.5;break;
        case kAudioUnitProperty_CocoaUI:{auto*v=(AudioUnitCocoaViewInfo*)out;
            NSURL *url=bundle().bundleURL;if(!url)return kAudioUnitErr_InvalidPropertyValue;
            v->mCocoaAUViewBundleLocation=(CFURLRef)CFRetain((__bridge CFURLRef)url);
            v->mCocoaAUViewClass[0]=(CFStringRef)CFRetain(CFSTR("LRDevViewFactory"));break;}
        case kAudioUnitProperty_ClassInfo:{
            NSMutableArray *values=[NSMutableArray array];for(auto&v:u->values)[values addObject:@(v.load())];
            NSDictionary *state=@{@"version":@1,@"type":@((UInt32)'aufx'),@"subtype":@((UInt32)'LrD1'),@"manufacturer":@((UInt32)'StDv'),@"name":@"Little Radiator Rust",@"parameters":values};
            *(CFPropertyListRef*)out=(CFPropertyListRef)CFBridgingRetain(state);break;}
        default:return kAudioUnitErr_InvalidProperty;
    } return noErr;
}
static OSStatus set(void*self,AudioUnitPropertyID id,AudioUnitScope scope,AudioUnitElement element,const void*data,UInt32 size) {
    UInt32 needed;Boolean writable;auto status=info(self,id,scope,element,&needed,&writable);
    if(status)return status;if(!data||!writable||size!=needed)return kAudioUnitErr_InvalidPropertyValue;
    auto*u=(Unit*)self;
    switch(id) {
        case kAudioUnitProperty_StreamFormat:{
            if(u->dsp)return kAudioUnitErr_Initialized;
            auto f=*(const AudioStreamBasicDescription*)data;
            if(f.mFormatID!=kAudioFormatLinearPCM||f.mFormatFlags!=(kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked|kAudioFormatFlagIsNonInterleaved)||f.mChannelsPerFrame!=2||f.mBitsPerChannel!=32||f.mBytesPerFrame!=4||f.mFramesPerPacket!=1||f.mBytesPerPacket!=4||!std::isfinite(f.mSampleRate)||f.mSampleRate<8000||f.mSampleRate>192000)return kAudioUnitErr_FormatNotSupported;
            u->format=f;break;}
        case kAudioUnitProperty_MaximumFramesPerSlice:
            if(u->dsp)return kAudioUnitErr_Initialized;
            if(!*(const UInt32*)data||*(const UInt32*)data>4096)return kAudioUnitErr_InvalidPropertyValue;
            u->maximum=*(const UInt32*)data;break;
        case kAudioUnitProperty_SetRenderCallback:u->input=*(const AURenderCallbackStruct*)data;u->connection={};break;
        case kAudioUnitProperty_MakeConnection:u->connection=*(const AudioUnitConnection*)data;u->input={};break;
        case kAudioUnitProperty_BypassEffect:u->values[0]=*(const UInt32*)data?1:0;break;
        case kAudioUnitProperty_ClassInfo:{
            CFPropertyListRef raw=*(CFPropertyListRef const*)data;
            if(!raw||CFGetTypeID(raw)!=CFDictionaryGetTypeID())return kAudioUnitErr_InvalidPropertyValue;
            NSDictionary *state=(__bridge NSDictionary*)raw;
            if(![state[@"version"] isKindOfClass:[NSNumber class]]||[state[@"version"] intValue]!=1)return kAudioUnitErr_InvalidPropertyValue;
            NSArray *v=state[@"parameters"];if(![v isKindOfClass:[NSArray class]]||v.count!=5)return kAudioUnitErr_InvalidPropertyValue;
            float next[5];for(int i=0;i<5;i++){if(![v[i] isKindOfClass:[NSNumber class]])return kAudioUnitErr_InvalidPropertyValue;next[i]=[v[i] floatValue];if(!std::isfinite(next[i])||next[i]<0||next[i]>1)return kAudioUnitErr_InvalidPropertyValue;}
            for(int i=0;i<5;i++)u->values[i]=next[i];break;}
        default:return kAudioUnitErr_InvalidProperty;
    }return noErr;
}
static OSStatus render(void*self,AudioUnitRenderActionFlags*flags,const AudioTimeStamp*time,UInt32 bus,UInt32 frames,AudioBufferList*out) {
    auto*u=(Unit*)self;if(!u->dsp)return kAudioUnitErr_Uninitialized;
    if(bus||!out||out->mNumberBuffers!=2)return kAudioUnitErr_InvalidElement;
    if(frames>u->maximum)return kAudioUnitErr_TooManyFramesToProcess;
    struct {UInt32 count;AudioBuffer buffers[2];} input={2,{{1,frames*4,u->left.data()},{1,frames*4,u->right.data()}}};
    auto*abl=(AudioBufferList*)&input;OSStatus status=0;
    if(u->input.inputProc)status=u->input.inputProc(u->input.inputProcRefCon,flags,time,0,frames,abl);
    else if(u->connection.sourceAudioUnit)status=AudioUnitRender(u->connection.sourceAudioUnit,flags,time,u->connection.sourceOutputNumber,frames,abl);
    else {std::fill(u->left.begin(),u->left.begin()+frames,0);std::fill(u->right.begin(),u->right.begin()+frames,0);}
    if(status)return status;
    for(int c=0;c<2;c++){if(!input.buffers[c].mData||input.buffers[c].mDataByteSize<frames*4)return kAudio_ParamError;
        float*dest=c?u->right.data():u->left.data();if(input.buffers[c].mData!=dest)memcpy(dest,input.buffers[c].mData,frames*4);}
    if(lr_process(u->dsp,u->left.data(),u->right.data(),frames,u->values[1],u->values[2],u->values[4],u->values[3],u->values[0]))return kAudio_ParamError;
    for(int c=0;c<2;c++){auto&b=out->mBuffers[c];float*src=c?u->right.data():u->left.data();
        if(b.mData){if(b.mDataByteSize<frames*4)return kAudio_ParamError;memcpy(b.mData,src,frames*4);}else b.mData=src;
        b.mDataByteSize=frames*4;b.mNumberChannels=1;}
    return noErr;
}
static AudioComponentMethod lookup(SInt16 selector) {
    switch(selector) {
#define METHOD(key,fn) case key:return (AudioComponentMethod)fn
        METHOD(kAudioUnitInitializeSelect,init);METHOD(kAudioUnitUninitializeSelect,uninit);
        METHOD(kAudioUnitGetPropertyInfoSelect,info);METHOD(kAudioUnitGetPropertySelect,get);METHOD(kAudioUnitSetPropertySelect,set);
        METHOD(kAudioUnitGetParameterSelect,getParameter);METHOD(kAudioUnitSetParameterSelect,setParameter);
        METHOD(kAudioUnitResetSelect,reset);METHOD(kAudioUnitRenderSelect,render);
#undef METHOD
        default:return nullptr;
    }
}
extern "C" __attribute__((visibility("default"))) AudioComponentPlugInInterface *LRDevFactory(const AudioComponentDescription*) {
    auto*u=new Unit;u->api={openUnit,closeUnit,lookup,nullptr};return &u->api;
}

@interface LRDevView : NSView { AudioUnit _unit; NSImage *_panel; NSImage *_brandPanel; NSImage *_knob; NSImage *_switch; NSTimer *_timer; int _drag; float _startValue; CGFloat _startY; }
- (instancetype)initWithUnit:(AudioUnit)unit;
- (void)importPreset:(id)sender;
- (void)showImportError:(NSString*)message;
@end
@implementation LRDevView
- (instancetype)initWithUnit:(AudioUnit)unit {
    if((self=[super initWithFrame:NSMakeRect(0,0,500,145)])){_unit=unit;_drag=-1;
        _panel=[[NSImage alloc]initWithContentsOfFile:[bundle() pathForResource:@"WM_LITTLE_RADIATOR_BACKGROUND_IMAGE" ofType:@"png"]];
        _brandPanel=[[NSImage alloc]initWithContentsOfFile:[bundle() pathForResource:@"RoundBoysFaceplate" ofType:@"png"]];
        [_brandPanel setSize:NSMakeSize(2170,725)];
        // Blend only the generated logo region into the unchanged faceplate.
        NSImage *patch=[[NSImage alloc]initWithSize:NSMakeSize(188,50)];
        [patch lockFocus];
        [_brandPanel drawInRect:NSMakeRect(0,0,188,50) fromRect:NSMakeRect(1265,228,820,214) operation:NSCompositingOperationCopy fraction:1];
        CGContextRef context=NSGraphicsContext.currentContext.CGContext;
        CGContextSetBlendMode(context,kCGBlendModeDestinationIn);
        NSGradient *horizontal=[[NSGradient alloc]initWithColorsAndLocations:NSColor.clearColor,0.0,NSColor.whiteColor,0.04,NSColor.whiteColor,0.96,NSColor.clearColor,1.0,nil];
        [horizontal drawInRect:NSMakeRect(0,0,188,50) angle:0];
        NSGradient *vertical=[[NSGradient alloc]initWithColorsAndLocations:NSColor.clearColor,0.0,NSColor.whiteColor,0.12,NSColor.whiteColor,0.88,NSColor.clearColor,1.0,nil];
        [vertical drawInRect:NSMakeRect(0,0,188,50) angle:90];
        [patch unlockFocus];_brandPanel=patch;
        _knob=[[NSImage alloc]initWithContentsOfFile:[bundle() pathForResource:@"WM_KNOB_ALTEC_LARGE" ofType:@"png"]];
        [_knob setSize:NSMakeSize(77,9480)];
        _switch=[[NSImage alloc]initWithContentsOfFile:[bundle() pathForResource:@"WM_ANIMATED_SWITCH_HALFSIZE_VERT" ofType:@"png"]];
        self.toolTip=@"Right-click to import a factory .toy preset.";
    }return self;
}
- (BOOL)acceptsFirstResponder {return YES;}
- (NSMenu*)menuForEvent:(NSEvent*)event {
    NSMenu *menu=[[NSMenu alloc]initWithTitle:@"Presets"];
    NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:@"Import .toy…" action:@selector(importPreset:) keyEquivalent:@""];
    item.target=self;[menu addItem:item];return menu;
}
- (void)showImportError:(NSString*)message {
    NSAlert *alert=[[NSAlert alloc]init];
    alert.alertStyle=NSAlertStyleWarning;
    alert.messageText=@"Cannot import the preset";
    alert.informativeText=message;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}
- (void)importPreset:(id)sender {
    NSOpenPanel *panel=[NSOpenPanel openPanel];
    panel.title=@"Import a Little Radiator preset";
    panel.prompt=@"Import";
    UTType *toyType=[UTType typeWithFilenameExtension:@"toy" conformingToType:UTTypeData];
    panel.allowedContentTypes=toyType?@[toyType]:@[UTTypeData];
    panel.allowsOtherFileTypes=NO;
    panel.canChooseDirectories=NO;
    panel.canChooseFiles=YES;
    panel.allowsMultipleSelection=NO;
    if([panel runModal]!=NSModalResponseOK)return;
    NSURL *url=panel.URL;
    if(!url || [url.pathExtension caseInsensitiveCompare:@"toy"]!=NSOrderedSame){
        [self showImportError:@"Select a file with the .toy extension."];return;
    }
    const NSUInteger maximumLength=1024*1024;
    NSError *error=nil;
    NSFileHandle *file=[NSFileHandle fileHandleForReadingFromURL:url error:&error];
    if(!file){[self showImportError:error.localizedDescription?:@"Cannot open the file."];return;}
    NSData *data=nil;
    @try {data=[file readDataOfLength:maximumLength+1];}
    @catch(NSException *exception){[self showImportError:exception.reason?:@"Cannot read the file."];}
    @finally {[file closeFile];}
    if(!data)return;
    if(data.length>maximumLength){[self showImportError:@"The file exceeds the 1 MiB limit."];return;}
    float next[5];char message[512]={0};
    int result=lr_decode_preset((const unsigned char*)data.bytes,data.length,next,message,sizeof(message));
    message[sizeof(message)-1]=0;
    if(result){
        NSString *detail=[NSString stringWithUTF8String:message];
        [self showImportError:detail.length?detail:@"The file does not contain a supported Little Radiator preset."];return;
    }
    for(int i=0;i<5;i++)if(!std::isfinite(next[i])||next[i]<0||next[i]>1){
        [self showImportError:@"The preset contains an invalid parameter value."];return;
    }
    float previous[5];
    for(int i=0;i<5;i++){
        OSStatus status=AudioUnitGetParameter(_unit,ids[i],kAudioUnitScope_Global,0,&previous[i]);
        if(status){[self showImportError:[NSString stringWithFormat:@"Cannot read the current parameters (error %d).",(int)status]];return;}
    }
    for(int i=0;i<5;i++){
        OSStatus status=AudioUnitSetParameter(_unit,ids[i],kAudioUnitScope_Global,0,next[i],0);
        if(status){
            OSStatus restoreStatus=noErr;
            for(int j=0;j<5;j++){
                OSStatus restored=AudioUnitSetParameter(_unit,ids[j],kAudioUnitScope_Global,0,previous[j],0);
                if(restored && !restoreStatus)restoreStatus=restored;
            }
            [self setNeedsDisplay:YES];
            NSString *detail=[NSString stringWithFormat:@"Cannot apply the preset (error %d).",(int)status];
            if(restoreStatus)detail=[detail stringByAppendingFormat:@" Cannot restore all previous values (error %d).",(int)restoreStatus];
            else detail=[detail stringByAppendingString:@" The previous values are restored."];
            [self showImportError:detail];return;
        }
    }
    [self setNeedsDisplay:YES];
}
- (void)viewDidMoveToWindow {
    [_timer invalidate]; _timer=nil;
    if(self.window){__weak LRDevView *weakSelf=self;
        _timer=[NSTimer scheduledTimerWithTimeInterval:1./30. repeats:YES block:^(NSTimer*){[weakSelf setNeedsDisplay:YES];}];}
}
- (void)dealloc {[_timer invalidate];}
- (BOOL)isFlipped{return YES;}
- (void)drawRect:(NSRect)dirty {
    [[NSColor colorWithWhite:.12 alpha:1]setFill];NSRectFill(self.bounds);
    [_panel drawInRect:NSMakeRect(0,0,500,145) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    [_brandPanel drawInRect:NSMakeRect(294,56,188,50) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    for(int i=0;i<2;i++){float value=0;AudioUnitGetParameter(_unit,i?9:8,kAudioUnitScope_Global,0,&value);
        NSInteger frame=15+lround(fmax(0,fmin(1,value))*90);
        [_knob drawInRect:NSMakeRect(i?211:111,46,77,79) fromRect:NSMakeRect(0,9480-(frame+1)*79,77,79) operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];}
    for(int i=0;i<2;i++){float value=0;AudioUnitGetParameter(_unit,i?10:12,kAudioUnitScope_Global,0,&value);
        NSInteger frame=value>=.5?9:0;
        [_switch drawInRect:NSMakeRect(36,i?91:41,24,27) fromRect:NSMakeRect(0,270-(frame+1)*27,24,27) operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];}
}
- (void)mouseDown:(NSEvent*)event {[self.window makeFirstResponder:self];NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];
    if(p.x>=32&&p.x<=64&&p.y>=35&&p.y<=121){UInt32 id=p.y<85?12:10;float value=0;AudioUnitGetParameter(_unit,id,0,0,&value);AudioUnitSetParameter(_unit,id,0,0,value>=.5?0:1,0);[self setNeedsDisplay:YES];return;}
    _drag=(p.y>=46&&p.y<=125)?(p.x>=111&&p.x<=188?8:(p.x>=211&&p.x<=288?9:-1)):-1;
    if(_drag>=0){AudioUnitGetParameter(_unit,_drag,0,0,&_startValue);_startY=p.y;}
}
- (void)mouseDragged:(NSEvent*)event {if(_drag<0)return;NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];float value=fmax(0,fmin(1,_startValue+(_startY-p.y)/150.));AudioUnitSetParameter(_unit,_drag,0,0,value,0);[self setNeedsDisplay:YES];}
- (void)mouseUp:(NSEvent*)event {_drag=-1;}
@end
@interface LRDevViewFactory : NSObject<AUCocoaUIBase> @end
@implementation LRDevViewFactory
- (unsigned)interfaceVersion{return 0;}
- (NSString*)description{return @"Little Radiator Rust";}
- (NSView*)uiViewForAudioUnit:(AudioUnit)unit withSize:(NSSize)size{return [[LRDevView alloc]initWithUnit:unit];}
@end
