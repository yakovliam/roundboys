#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
extern "C" int dc_decode_preset(const unsigned char*,size_t,float*,char*,size_t);
static const unsigned int DCParameterIDs[]={7,10,11,12,13,14,15,16,17,18,19,20};
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUCocoaUIView.h>
#include <cmath>
#import "presets.h"
#include "DCProperties.h"

static NSBundle *DCBundle() { return [NSBundle bundleWithIdentifier:@"dev.stanalysis.Decapitator"]; }
static NSImage *DCImage(NSString *name, NSString *extension) {
    NSString *path=[DCBundle() pathForResource:name ofType:extension];
    return path?[[NSImage alloc] initWithContentsOfFile:path]:nil;
}
static CGFloat DCClamp(CGFloat x) { return fmax(0,fmin(1,x)); }
struct DCKnobSpec { AudioUnitParameterID id; const char *name; CGFloat x,y; float initial; };
static const DCKnobSpec DCKnobs[]={
    {11,"DRIVE",53,140,0},{13,"LOW CUT",243,210,0},{14,"TONE",368,210,.5},
    {15,"HIGH CUT",493,210,1},{20,"OUTPUT",584,120,1},{16,"MIX",679,210,1}
};
struct DCToggleSpec { AudioUnitParameterID id; const char *name; CGFloat x,y; float initial; };
static const DCToggleSpec DCToggles[]={
    {12,"PUNISH",140,47,0},{18,"THUMP",198,225,0},
    {19,"STEEP",570,225,0},{17,"AUTO",675,137,1}
};

@interface DCDevView : NSView {
    AudioUnit _unit;
    NSImage *_panel,*_largeKnob,*_smallKnob,*_button,*_switchImage,*_meter,*_wordmark;
    NSTimer *_timer;
    DCPresetBar *_presetBar;
    float _meterDb,_meterTarget;
    UInt32 _meterSequence;
    NSTimeInterval _meterUpdated,_meterTick;
    NSInteger _drag;
    CGFloat _startY;
    float _startValue;
}
- (instancetype)initWithUnit:(AudioUnit)unit;
- (void)refreshView;
- (NSInteger)meterFrame;
@end

@implementation DCDevView
- (instancetype)initWithUnit:(AudioUnit)unit {
    if((self=[super initWithFrame:NSMakeRect(0,0,800,386)])) {
        _unit=unit;_drag=-1;_meterDb=_meterTarget=-60;
        _meterUpdated=_meterTick=NSProcessInfo.processInfo.systemUptime;
        _presetBar=[[DCPresetBar alloc]initWithUnit:unit];[self addSubview:_presetBar];
        _panel=DCImage(@"DecapitatorBackground_2x",@"png");_panel.size=NSMakeSize(1600,700);
        _largeKnob=DCImage(@"WM_KNOB_PULTEC_95",@"png");_largeKnob.size=NSMakeSize(99,12350);
        _smallKnob=DCImage(@"WM_KNOB_PULTEC_64",@"png");_smallKnob.size=NSMakeSize(67,8320);
        _button=DCImage(@"WM_LIGHTEDPUSHBUTTON_50",@"png");_button.size=NSMakeSize(50,100);
        _switchImage=DCImage(@"WM_ANIMATED_SWITCH_HALFSIZE_VERT",@"png");_switchImage.size=NSMakeSize(24,270);
        _meter=DCImage(@"WM_DECAPITATOR_METER",@"jpg");_meter.size=NSMakeSize(210,16766);
        NSImage *source=DCImage(@"RoundBoysFaceplate",@"png");
        NSBitmapImageRep *bitmap=source?[[NSBitmapImageRep alloc] initWithData:source.TIFFRepresentation]:nil;
        // Retain only the white letters. The source image has a green faceplate.
        if(bitmap.pixelsWide>=2010 && bitmap.pixelsHigh>=455) {
            const NSInteger w=650,h=135;
            NSBitmapImageRep *mask=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:w*4 bitsPerPixel:32];
            unsigned char *pixels=mask.bitmapData;
            for(NSInteger y=0;y<h;y++)for(NSInteger x=0;x<w;x++) {
                NSColor *c=[[bitmap colorAtX:x+1360 y:y+320] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
                CGFloat r=c.redComponent,g=c.greenComponent,b=c.blueComponent;
                CGFloat minimum=fmin(r,fmin(g,b));
                CGFloat chroma=fmax(r,fmax(g,b))-minimum;
                CGFloat alpha=DCClamp((minimum-.40)/.38)*DCClamp(1-chroma*5);
                NSInteger n=(y*w+x)*4;
                pixels[n]=pixels[n+1]=pixels[n+2]=(unsigned char)lround(245*alpha);pixels[n+3]=(unsigned char)lround(alpha*255);
            }
            _wordmark=[[NSImage alloc] initWithSize:NSMakeSize(w,h)];[_wordmark addRepresentation:mask];
        }
        self.toolTip=@"Drag a knob up or down. Hold Shift for a small change. Double-click to reset. Use the preset dropdown to browse factory and user presets.";
    }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (float)value:(AudioUnitParameterID)identifier fallback:(float)fallback {
    float v=fallback;
    if(!_unit||AudioUnitGetParameter(_unit,identifier,kAudioUnitScope_Global,0,&v)!=noErr||!std::isfinite(v))return fallback;
    return identifier==10?fmax(0,fmin(4,v)):DCClamp(v);
}
- (void)notify:(AudioUnitEventType)type parameter:(AudioUnitParameterID)identifier {
    if(!_unit)return;
    AudioUnitEvent event={};event.mEventType=type;
    event.mArgument.mParameter={_unit,identifier,kAudioUnitScope_Global,0};
    AUEventListenerNotify(NULL,(__bridge void*)self,&event);
}
- (void)setValue:(float)value parameter:(AudioUnitParameterID)identifier {
    if(!_unit)return;
    AudioUnitParameter p={_unit,identifier,kAudioUnitScope_Global,0};
    if(AUParameterSet(NULL,(__bridge void*)self,&p,value,0)==noErr)[self setNeedsDisplay:YES];
}
- (void)change:(float)value parameter:(AudioUnitParameterID)identifier {
    [self notify:kAudioUnitEvent_BeginParameterChangeGesture parameter:identifier];
    [self setValue:value parameter:identifier];
    [self notify:kAudioUnitEvent_EndParameterChangeGesture parameter:identifier];
}
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];[_timer invalidate];_timer=nil;
    if(self.window){__weak DCDevView *weakSelf=self;_timer=[NSTimer timerWithTimeInterval:1./20. repeats:YES block:^(NSTimer *){[weakSelf refreshView];}];
        [[NSRunLoop mainRunLoop]addTimer:_timer forMode:NSRunLoopCommonModes];}
    else if(_drag>=0){[self notify:kAudioUnitEvent_EndParameterChangeGesture parameter:DCKnobs[_drag].id];_drag=-1;}
}
- (NSMenu*)menuForEvent:(NSEvent*)event {
 NSMenu*menu=[[NSMenu alloc]initWithTitle:@"Presets"];
 for(NSArray*entry in @[@[@"Import .toy or .aupreset…",@"importPreset:"],@[@"Save user preset…",@"savePreset:"]]){
  NSMenuItem*item=[[NSMenuItem alloc]initWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:@""];item.target=_presetBar;[menu addItem:item];}
 return menu;
}
- (void)refreshView {
 NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;DCMeterReading reading={};UInt32 size=sizeof(reading);
 if(!AudioUnitGetProperty(_unit,kDCMeterProperty,0,0,&reading,&size)&&reading.sequence!=_meterSequence){
  _meterSequence=reading.sequence;_meterTarget=std::isfinite(reading.decibels)?fmax(-60,fmin(36,reading.decibels)):-60;_meterUpdated=now;}
 if(now-_meterUpdated>.12)_meterTarget=-60;
 double elapsed=fmax(.001,fmin(.25,now-_meterTick));_meterTick=now;
 double coefficient=1-exp(-elapsed/(_meterTarget>_meterDb?.025:.20));_meterDb+=coefficient*(_meterTarget-_meterDb);
 [_presetBar refresh];[self setNeedsDisplay:YES];
}
- (NSInteger)meterFrame {
 double db=fmax(-20,fmin(3,_meterDb));double deflection=(pow(10,db/20.)-.1)/(pow(10,3./20.)-.1);
 return lround(DCClamp(deflection)*100);
}
- (void)dealloc {[_timer invalidate];}
- (void)label:(NSString*)text rect:(NSRect)rect size:(CGFloat)size {
    NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc]init];style.alignment=NSTextAlignmentCenter;
    [text drawInRect:rect withAttributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:size],NSForegroundColorAttributeName:[NSColor colorWithWhite:.9 alpha:1],NSParagraphStyleAttributeName:style}];
}
- (void)drawImage:(NSImage*)image rect:(NSRect)rect source:(NSRect)source {
    [image drawInRect:rect fromRect:source operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:@{NSImageHintInterpolation:@(NSImageInterpolationHigh)}];
}
- (void)drawRect:(NSRect)dirty {
    [[NSColor colorWithWhite:.10 alpha:1]setFill];NSRectFill(self.bounds);
    [NSGraphicsContext saveGraphicsState];NSAffineTransform*translation=[NSAffineTransform transform];[translation translateXBy:0 yBy:36];[translation concat];
    [self drawImage:_panel rect:NSMakeRect(0,0,800,350) source:NSZeroRect];
    // Use a clean grille patch from the same panel to cover the old logo.
    for(int y=0;y<3;y++)for(int x=0;x<6;x++)
        [self drawImage:_panel rect:NSMakeRect(x*40,292+y*20,40,20) source:NSMakeRect(800,72,80,40)];
    [self drawImage:_wordmark rect:NSMakeRect(24,304,190,39.46) source:NSZeroRect];
    [self drawImage:_meter rect:NSMakeRect(300,10,210,166) source:NSMakeRect(0,16766-([self meterFrame]+1)*166,210,166)];
    for(int i=0;i<6;i++) {
        const auto &k=DCKnobs[i];float value=[self value:k.id fallback:k.initial];BOOL large=i==0;
        CGFloat w=large?99:67,h=large?95:64;NSInteger frame=15+lround(value*100);
        NSImage *image=large?_largeKnob:_smallKnob;CGFloat total=large?12350:8320;
        [self drawImage:image rect:NSMakeRect(k.x,k.y,w,h) source:NSMakeRect(0,total-(frame+1)*h,w,h)];
        [self label:[NSString stringWithUTF8String:k.name] rect:NSMakeRect(k.x-12,k.y-(large?38:26),w+24,16) size:12];
        CGFloat centerX=k.x+w/2,centerY=k.y+h/2,radius=large?62:39;
        for(int tick=0;tick<=10;tick++){
            CGFloat angle=(135+tick*27)*M_PI/180,px=centerX+cos(angle)*radius,py=centerY+sin(angle)*radius;
            if(large)[self label:[NSString stringWithFormat:@"%d",tick] rect:NSMakeRect(px-10,py-7,20,14) size:11];
            else{[[NSColor colorWithWhite:.8 alpha:1]setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(px-1.7,py-1.7,3.4,3.4)]fill];}
        }
        if(!large){NSString *minimum=@"",*maximum=@"";
            if(k.id==13){minimum=@"20 Hz";maximum=@"1 kHz";}
            if(k.id==14){minimum=@"DARK";maximum=@"BRIGHT";}
            if(k.id==15){minimum=@"1 kHz";maximum=@"20 kHz";}
            if(k.id==20){minimum=@"-24 dB";maximum=@"0 dB";}
            if(k.id==16){minimum=@"DRY";maximum=@"WET";}
            [self label:minimum rect:NSMakeRect(k.x-23,k.y+h+1,55,13) size:9];
            [self label:maximum rect:NSMakeRect(k.x+w-25,k.y+h+1,55,13) size:9];
        }
    }
    for(const auto &t:DCToggles) {
        float value=[self value:t.id fallback:t.initial];NSInteger frame=value>=.5?9:0;
        if(t.id==12){
            [self drawImage:_button rect:NSMakeRect(t.x,t.y,50,50) source:NSMakeRect(0,value>=.5?0:50,50,50)];
            [self label:@"ON" rect:NSMakeRect(t.x,t.y+17,50,16) size:11];
            [self label:@"PUNISH" rect:NSMakeRect(t.x-15,t.y-18,80,16) size:11];
        }else{
            [self drawImage:_switchImage rect:NSMakeRect(t.x,t.y,24,27) source:NSMakeRect(0,270-(frame+1)*27,24,27)];
            [self label:[NSString stringWithUTF8String:t.name] rect:NSMakeRect(t.x-25,t.y-14,74,14) size:10];
        }
    }
    NSInteger style=lround([self value:10 fallback:0]);
    NSArray *letters=@[@"A",@"E",@"N",@"T",@"P"];
    for(int i=0;i<5;i++) {
        CGFloat x=230+i*75;
        [self drawImage:_button rect:NSMakeRect(x,299,50,50) source:NSMakeRect(0,i==style?0:50,50,50)];
        [self label:letters[i] rect:NSMakeRect(x,316,50,20) size:13];
    }
    [NSGraphicsContext restoreGraphicsState];
}
- (void)mouseDown:(NSEvent*)event {
    [self.window makeFirstResponder:self];NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];p.y-=36;
    for(const auto &t:DCToggles)if(NSPointInRect(p,NSMakeRect(t.x-8,t.y-14,t.id==12?66:40,t.id==12?64:43))){
        [self change:[self value:t.id fallback:t.initial]>=.5?0:1 parameter:t.id];return;}
    for(int i=0;i<5;i++)if(NSPointInRect(p,NSMakeRect(230+i*75,299,50,50))){[self change:i parameter:10];return;}
    for(int i=0;i<6;i++) {
        const auto &k=DCKnobs[i];CGFloat w=i?67:99,h=i?64:95;
        if(NSPointInRect(p,NSMakeRect(k.x,k.y,w,h))) {
            if(event.clickCount>1){[self change:k.initial parameter:k.id];return;}
            _drag=i;_startY=p.y;_startValue=[self value:k.id fallback:k.initial];
            [self notify:kAudioUnitEvent_BeginParameterChangeGesture parameter:k.id];return;
        }
    }
}
- (void)mouseDragged:(NSEvent*)event {
    if(_drag<0)return;NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];p.y-=36;
    CGFloat scale=(event.modifierFlags&NSEventModifierFlagShift)?1000.:180.;
    [self setValue:DCClamp(_startValue+(_startY-p.y)/scale) parameter:DCKnobs[_drag].id];
}
- (void)mouseUp:(NSEvent*)event {
    if(_drag>=0)[self notify:kAudioUnitEvent_EndParameterChangeGesture parameter:DCKnobs[_drag].id];_drag=-1;
}
@end

@interface DCDevViewFactory : NSObject<AUCocoaUIBase> @end
@implementation DCDevViewFactory
- (unsigned)interfaceVersion {return 0;}
- (NSString*)description {return @"Decapitator";}
- (NSView*)uiViewForAudioUnit:(AudioUnit)unit withSize:(NSSize)size {return [[DCDevView alloc]initWithUnit:unit];}
@end
