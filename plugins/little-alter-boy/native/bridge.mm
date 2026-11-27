#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUCocoaUIView.h>
#import <AudioUnit/MusicDevice.h>
#include <atomic>
#include <cmath>
#include <cstring>
#include <vector>
#include <mutex>
#include <string>
#include <algorithm>
extern "C" {
void *la_create(double rate);
void la_destroy(void *);
int la_process(void *, float *, float *, size_t, const float *);
void la_reset(void *);
int la_midi_event(void*,unsigned int,unsigned int,unsigned int,unsigned int);
size_t la_factory_preset_count();
int la_factory_preset(size_t,float*,char*,size_t);
}
static const UInt32 ids[]={7,8,9,10,11,12,13};
static const char *names[]={"Bypass","Pitch","Formant","Drive","Mix","ShiftMode","FormantLink"};
static const float defaults[]={0,.5,.5,0,1,0,0};
struct LABListener {AudioUnitPropertyID id;AudioUnitPropertyListenerProc callback;void*context;};
struct LABMidi {UInt32 status,data1,data2,offset;};
struct Unit {
    AudioComponentPlugInInterface api;
    AudioUnit host=nullptr;
    AudioStreamBasicDescription format{};
    AURenderCallbackStruct input{};
    AudioUnitConnection connection{};
    std::atomic<float> values[7];
    std::atomic<float> unlinkedFormant{.5f};
    LABMidi midi[64]{};
    std::atomic<UInt32> midiRead{0},midiWrite{0};
    std::atomic_flag midiProducer=ATOMIC_FLAG_INIT;
    std::atomic<bool> presetModified{false};
    std::mutex presetMutex;
    std::mutex listenerMutex;
    std::vector<LABListener> listeners;
    SInt32 presetNumber=-1;
    std::string presetName="Default";
    UInt32 maximum=4096;
    void *dsp=nullptr;
    std::vector<float> left,right;
    Unit() { for(int i=0;i<7;i++) values[i]=defaults[i];
        for(size_t i=0;i<la_factory_preset_count();i++){float v[7];char name[512];if(!la_factory_preset(i,v,name,sizeof(name))&&!strcmp(name,"Default"))presetNumber=(SInt32)i;}
        format={48000,kAudioFormatLinearPCM,kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked|kAudioFormatFlagIsNonInterleaved,4,1,4,2,32,0}; }
};
static void notifyProperty(Unit*u,AudioUnitPropertyID id){std::vector<LABListener> listeners;{std::lock_guard<std::mutex>guard(u->listenerMutex);listeners=u->listeners;}for(const auto&listener:listeners)if(listener.id==id)listener.callback(listener.context,u->host,id,0,0);}
static OSStatus addListener(void*self,AudioUnitPropertyID id,AudioUnitPropertyListenerProc callback,void*context){if(!callback)return kAudio_ParamError;auto*u=(Unit*)self;std::lock_guard<std::mutex>guard(u->listenerMutex);for(const auto&listener:u->listeners)if(listener.id==id&&listener.callback==callback&&listener.context==context)return noErr;u->listeners.push_back({id,callback,context});return noErr;}
static OSStatus removeListener(void*self,AudioUnitPropertyID id,AudioUnitPropertyListenerProc callback){auto*u=(Unit*)self;std::lock_guard<std::mutex>guard(u->listenerMutex);u->listeners.erase(std::remove_if(u->listeners.begin(),u->listeners.end(),[&](const LABListener&l){return l.id==id&&l.callback==callback;}),u->listeners.end());return noErr;}
static OSStatus removeListenerWithContext(void*self,AudioUnitPropertyID id,AudioUnitPropertyListenerProc callback,void*context){auto*u=(Unit*)self;std::lock_guard<std::mutex>guard(u->listenerMutex);u->listeners.erase(std::remove_if(u->listeners.begin(),u->listeners.end(),[&](const LABListener&l){return l.id==id&&l.callback==callback&&l.context==context;}),u->listeners.end());return noErr;}
static OSStatus openUnit(void *self,AudioComponentInstance host) { ((Unit*)self)->host=host; return noErr; }
static OSStatus uninit(void *self) { auto*u=(Unit*)self; if(u->dsp)la_destroy(u->dsp);u->dsp=nullptr;u->midiRead.store(u->midiWrite.load());return noErr; }
static OSStatus closeUnit(void *self) { uninit(self);delete (Unit*)self;return noErr; }
static OSStatus init(void *self) { auto*u=(Unit*)self; uninit(self); u->left.resize(u->maximum);u->right.resize(u->maximum);
    u->dsp=la_create(u->format.mSampleRate);return u->dsp?noErr:kAudioUnitErr_FormatNotSupported; }
static OSStatus reset(void*self,AudioUnitScope,AudioUnitElement) {auto*u=(Unit*)self;if(u->dsp)la_reset(u->dsp);u->midiRead.store(u->midiWrite.load());return noErr;}
static bool validBus(AudioUnitScope scope,AudioUnitElement element) { return element==0 && (scope==kAudioUnitScope_Global || scope==kAudioUnitScope_Input || scope==kAudioUnitScope_Output); }
static OSStatus getParameter(void*self,AudioUnitParameterID id,AudioUnitScope scope,AudioUnitElement element,AudioUnitParameterValue*out) {
    if(!out || scope!=kAudioUnitScope_Global || element) return kAudioUnitErr_InvalidScope;
    for(int i=0;i<7;i++)if(ids[i]==id){*out=((Unit*)self)->values[i].load();return noErr;}return kAudioUnitErr_InvalidParameter;
}
static OSStatus setParameter(void*self,AudioUnitParameterID id,AudioUnitScope scope,AudioUnitElement element,AudioUnitParameterValue value,UInt32 offset) {
    if(scope!=kAudioUnitScope_Global || element)return kAudioUnitErr_InvalidScope;
    if(offset || !std::isfinite(value) || value<0 || value>(id==12?2:1))return kAudioUnitErr_InvalidParameterValue;
    for(int i=0;i<7;i++)if(ids[i]==id){
        auto*u=(Unit*)self;float previous=u->values[i].exchange(value);bool changed=previous!=value;
        if(id==8&&u->values[6].load()>=.5f){if(u->values[2].exchange(value)!=value)changed=true;}
        if(id==9){u->unlinkedFormant=value;if(u->values[6].exchange(0)!=0)changed=true;}
        if(id==13){
            if(value>=.5f){
                if(previous<.5f)u->unlinkedFormant=u->values[2].load();
                float pitch=u->values[1].load();if(u->values[2].exchange(pitch)!=pitch)changed=true;
            }else if(previous>=.5f){float formant=u->unlinkedFormant.load();if(u->values[2].exchange(formant)!=formant)changed=true;}
        }
        if(changed)u->presetModified=true;return noErr;
    }return kAudioUnitErr_InvalidParameter;
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
        case kAudioUnitProperty_FactoryPresets:*size=sizeof(CFArrayRef);break;
        case kAudioUnitProperty_PresentPreset:*size=sizeof(AUPreset);*writable=true;break;
        case kAudioUnitProperty_BypassEffect:*size=sizeof(UInt32);*writable=true;break;
        case kAudioUnitProperty_InPlaceProcessing:*size=sizeof(UInt32);break;
        default:return kAudioUnitErr_InvalidProperty;
    } return noErr;
}
static NSBundle *bundle() { return [NSBundle bundleWithIdentifier:@"dev.roundboys.LittleAlterBoy"]; }
static const void *retainPreset(CFAllocatorRef,const void *value){auto*p=(const AUPreset*)value;return new AUPreset{p->presetNumber,(CFStringRef)CFRetain(p->presetName)};}
static void releasePreset(CFAllocatorRef,const void *value){auto*p=(const AUPreset*)value;CFRelease(p->presetName);delete p;}
static CFStringRef describePreset(const void *value){return (CFStringRef)CFRetain(((const AUPreset*)value)->presetName);}
static Boolean equalPreset(const void*a,const void*b){return ((const AUPreset*)a)->presetNumber==((const AUPreset*)b)->presetNumber;}
static const CFArrayCallBacks presetCallbacks={0,retainPreset,releasePreset,describePreset,equalPreset};
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
            int i=0;while(i<7&&ids[i]!=element)i++;if(i==7)return kAudioUnitErr_InvalidParameter;
            auto*p=(AudioUnitParameterInfo*)out;memset(p,0,sizeof(*p));strlcpy(p->name,names[i],sizeof(p->name));
            p->minValue=0;p->maxValue=i==5?2:1;p->defaultValue=defaults[i];
            p->unit=i==5?kAudioUnitParameterUnit_Indexed:((i==0||i==6)?kAudioUnitParameterUnit_Boolean:kAudioUnitParameterUnit_Generic);
            p->flags=kAudioUnitParameterFlag_IsReadable|kAudioUnitParameterFlag_IsWritable;break;}
        case kAudioUnitProperty_SetRenderCallback:memcpy(out,&u->input,needed);break;
        case kAudioUnitProperty_MakeConnection:memcpy(out,&u->connection,needed);break;
        case kAudioUnitProperty_Latency:*(Float64*)out=2048./u->format.mSampleRate;break;
        case kAudioUnitProperty_TailTime:*(Float64*)out=4096./u->format.mSampleRate;break;
        case kAudioUnitProperty_SupportedNumChannels:*(AUChannelInfo*)out={2,2};break;
        case kAudioUnitProperty_InPlaceProcessing:*(UInt32*)out=1;break;
        case kAudioUnitProperty_BypassEffect:*(UInt32*)out=u->values[0]>=.5;break;
        case kAudioUnitProperty_CocoaUI:{auto*v=(AudioUnitCocoaViewInfo*)out;
            NSURL *url=bundle().bundleURL;if(!url)return kAudioUnitErr_InvalidPropertyValue;
            v->mCocoaAUViewBundleLocation=(CFURLRef)CFRetain((__bridge CFURLRef)url);
            v->mCocoaAUViewClass[0]=(CFStringRef)CFRetain(CFSTR("LABViewFactory"));break;}
        case kAudioUnitProperty_FactoryPresets:{
            CFMutableArrayRef presets=CFArrayCreateMutable(NULL,0,&presetCallbacks);
            for(size_t i=0;i<la_factory_preset_count();i++){float values[7];char name[512];if(la_factory_preset(i,values,name,sizeof(name)))continue;
                CFStringRef text=CFStringCreateWithCString(NULL,name,kCFStringEncodingUTF8);AUPreset entry={(SInt32)i,text};CFArrayAppendValue(presets,&entry);CFRelease(text);}
            *(CFArrayRef*)out=presets;break;}
        case kAudioUnitProperty_PresentPreset:{std::lock_guard<std::mutex>guard(u->presetMutex);auto*p=(AUPreset*)out;
            p->presetNumber=u->presetModified?-1:u->presetNumber;std::string text=u->presetName+(u->presetModified?" *":"");p->presetName=CFStringCreateWithCString(NULL,text.c_str(),kCFStringEncodingUTF8);break;}
        case kAudioUnitProperty_ClassInfo:{
            std::lock_guard<std::mutex>guard(u->presetMutex);
            NSString *presetName=[NSString stringWithUTF8String:u->presetName.c_str()];
            NSMutableArray *values=[NSMutableArray array];for(auto&v:u->values)[values addObject:@(v.load())];
            NSDictionary *state=@{@"version":@1,@"type":@((UInt32)'aumf'),@"subtype":@((UInt32)'Lab1'),@"manufacturer":@((UInt32)'StDv'),@"name":presetName,@"preset-number":@(u->presetNumber),@"modified":@(u->presetModified.load()),@"unlinked-formant":@(u->unlinkedFormant.load()),@"parameters":values};
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
        case kAudioUnitProperty_BypassEffect:if(u->values[0].exchange(*(const UInt32*)data?1:0)!=(*(const UInt32*)data?1:0))u->presetModified=true;break;
        case kAudioUnitProperty_PresentPreset:{
            const AUPreset*p=(const AUPreset*)data;
            if(p->presetNumber>=0){float values[7];char name[512];if(la_factory_preset(p->presetNumber,values,name,sizeof(name)))return kAudioUnitErr_InvalidPropertyValue;
                u->unlinkedFormant=values[2];if(values[6]>=.5f)values[2]=values[1];for(int i=0;i<7;i++)u->values[i]=values[i];std::lock_guard<std::mutex>guard(u->presetMutex);u->presetNumber=p->presetNumber;u->presetName=name;u->presetModified=false;
            }else{if(!p->presetName||CFGetTypeID(p->presetName)!=CFStringGetTypeID())return kAudioUnitErr_InvalidPropertyValue;
                NSString*name=(__bridge NSString*)p->presetName;std::lock_guard<std::mutex>guard(u->presetMutex);u->presetName=name.UTF8String;u->presetNumber=-1;u->presetModified=false;}
            break;}
        case kAudioUnitProperty_ClassInfo:{
            CFPropertyListRef raw=*(CFPropertyListRef const*)data;
            if(!raw||CFGetTypeID(raw)!=CFDictionaryGetTypeID())return kAudioUnitErr_InvalidPropertyValue;
            NSDictionary *state=(__bridge NSDictionary*)raw;
            if(![state[@"version"] isKindOfClass:[NSNumber class]]||[state[@"version"] intValue]!=1)return kAudioUnitErr_InvalidPropertyValue;
            NSArray *v=state[@"parameters"];if(![v isKindOfClass:[NSArray class]]||v.count!=7)return kAudioUnitErr_InvalidPropertyValue;
            if(state[@"type"] && (![state[@"type"] isKindOfClass:[NSNumber class]]||[state[@"type"] unsignedIntValue]!=(UInt32)'aumf'))return kAudioUnitErr_InvalidPropertyValue;
            if(state[@"subtype"] && (![state[@"subtype"] isKindOfClass:[NSNumber class]]||[state[@"subtype"] unsignedIntValue]!=(UInt32)'Lab1'))return kAudioUnitErr_InvalidPropertyValue;
            if(state[@"manufacturer"] && (![state[@"manufacturer"] isKindOfClass:[NSNumber class]]||[state[@"manufacturer"] unsignedIntValue]!=(UInt32)'StDv'))return kAudioUnitErr_InvalidPropertyValue;
            NSString *name=state[@"name"]?:@"User preset";if(![name isKindOfClass:[NSString class]]||name.length>256)return kAudioUnitErr_InvalidPropertyValue;
            NSNumber *number=state[@"preset-number"]?:@(-1);if(![number isKindOfClass:[NSNumber class]]||number.intValue < -1 || number.intValue >= (int)la_factory_preset_count())return kAudioUnitErr_InvalidPropertyValue;
            NSNumber *modified=state[@"modified"]?:@NO;if(![modified isKindOfClass:[NSNumber class]])return kAudioUnitErr_InvalidPropertyValue;
            float next[7];for(int i=0;i<7;i++){if(![v[i] isKindOfClass:[NSNumber class]])return kAudioUnitErr_InvalidPropertyValue;next[i]=[v[i] floatValue];if(!std::isfinite(next[i])||next[i]<0||next[i]>(i==5?2:1))return kAudioUnitErr_InvalidPropertyValue;}
            NSNumber *unlinked=state[@"unlinked-formant"]?:@(next[2]);
            if(![unlinked isKindOfClass:[NSNumber class]]||!std::isfinite(unlinked.floatValue)||unlinked.floatValue<0||unlinked.floatValue>1)return kAudioUnitErr_InvalidPropertyValue;
            u->unlinkedFormant=unlinked.floatValue;if(next[6]>=.5f)next[2]=next[1];
            for(int i=0;i<7;i++)u->values[i]=next[i];
            {std::lock_guard<std::mutex>guard(u->presetMutex);u->presetName=name.UTF8String;u->presetNumber=number.intValue;u->presetModified=modified.boolValue;}break;}
        default:return kAudioUnitErr_InvalidProperty;
    }notifyProperty(u,id);if(id==kAudioUnitProperty_ClassInfo)notifyProperty(u,kAudioUnitProperty_PresentPreset);if(id==kAudioUnitProperty_PresentPreset)notifyProperty(u,kAudioUnitProperty_ClassInfo);return noErr;
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
    UInt32 read=u->midiRead.load(std::memory_order_relaxed),write=u->midiWrite.load(std::memory_order_acquire);
    for(;read!=write;read++){const auto&event=u->midi[read%64];if(la_midi_event(u->dsp,event.status,event.data1,event.data2,event.offset))break;}
    u->midiRead.store(read,std::memory_order_release);
    float snapshot[7];for(int i=0;i<7;i++)snapshot[i]=u->values[i].load(std::memory_order_relaxed);
    if(la_process(u->dsp,u->left.data(),u->right.data(),frames,snapshot))return kAudio_ParamError;
    for(int c=0;c<2;c++){auto&b=out->mBuffers[c];float*src=c?u->right.data():u->left.data();
        if(b.mData){if(b.mDataByteSize<frames*4)return kAudio_ParamError;memcpy(b.mData,src,frames*4);}else b.mData=src;
        b.mDataByteSize=frames*4;b.mNumberChannels=1;}
    return noErr;
}
// MIDI messages are queued by the host callback and consumed only by render.
static OSStatus midiEvent(void*self,UInt32 status,UInt32 data1,UInt32 data2,UInt32 offset) {
    auto*u=(Unit*)self;if(status>255||data1>127||data2>127||offset>=u->maximum)return kAudio_ParamError;
    if(u->midiProducer.test_and_set(std::memory_order_acquire))return kAudioUnitErr_CannotDoInCurrentContext;
    UInt32 write=u->midiWrite.load(std::memory_order_relaxed),read=u->midiRead.load(std::memory_order_acquire);
    if(write-read>=64){u->midiProducer.clear(std::memory_order_release);return kAudioUnitErr_CannotDoInCurrentContext;}
    u->midi[write%64]={status,data1,data2,offset};u->midiWrite.store(write+1,std::memory_order_release);u->midiProducer.clear(std::memory_order_release);return noErr;
}
static AudioComponentMethod lookup(SInt16 selector) {
    switch(selector) {
#define METHOD(key,fn) case key:return (AudioComponentMethod)fn
        METHOD(kAudioUnitInitializeSelect,init);METHOD(kAudioUnitUninitializeSelect,uninit);
        METHOD(kAudioUnitGetPropertyInfoSelect,info);METHOD(kAudioUnitGetPropertySelect,get);METHOD(kAudioUnitSetPropertySelect,set);
        METHOD(kAudioUnitGetParameterSelect,getParameter);METHOD(kAudioUnitSetParameterSelect,setParameter);
        METHOD(kAudioUnitAddPropertyListenerSelect,addListener);METHOD(kAudioUnitRemovePropertyListenerSelect,removeListener);METHOD(kAudioUnitRemovePropertyListenerWithUserDataSelect,removeListenerWithContext);
        METHOD(kAudioUnitResetSelect,reset);METHOD(kAudioUnitRenderSelect,render);
        METHOD(kMusicDeviceMIDIEventSelect,midiEvent);
#undef METHOD
        default:return nullptr;
    }
}
extern "C" __attribute__((visibility("default"))) AudioComponentPlugInInterface *LABFactory(const AudioComponentDescription*) {
    auto*u=new Unit;u->api={openUnit,closeUnit,lookup,nullptr};return &u->api;
}
