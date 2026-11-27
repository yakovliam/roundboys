#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUCocoaUIView.h>
#import "presets.h"
#include <cmath>

static NSBundle *LABBundle() {return [NSBundle bundleWithIdentifier:@"dev.roundboys.LittleAlterBoy"];}
static NSImage *LABImage(NSString *name) {
 NSString *path=[LABBundle() pathForResource:name ofType:@"png"];
 return path?[[NSImage alloc]initWithContentsOfFile:path]:nil;
}
static CGFloat LABClamp(CGFloat value) {return fmax(0,fmin(1,value));}
struct LABKnob {AudioUnitParameterID id;const char *name;CGFloat x;float initial;};
static const LABKnob LABKnobs[]={{8,"PITCH",67,.5},{9,"FORMANT",237,.5},{10,"DRIVE",527,0},{11,"MIX",657,1}};

@interface LABView : NSView {
 AudioUnit _unit;
 NSImage *_panel,*_knob,*_button,*_link,*_wordmark;
 LABPresetBar *_presetBar;
 NSTimer *_timer;
 NSInteger _drag;
 CGFloat _startY;
 float _startValue;
}
- (instancetype)initWithUnit:(AudioUnit)unit;
- (void)refreshView;
@end
@implementation LABView
- (instancetype)initWithUnit:(AudioUnit)unit {
 if((self=[super initWithFrame:NSMakeRect(0,0,800,246)])) {
  _unit=unit;_drag=-1;
  _presetBar=[[LABPresetBar alloc]initWithUnit:unit];[self addSubview:_presetBar];
  _panel=LABImage(@"LittleAlterBoy_BG_72dpi");_panel.size=NSMakeSize(800,210);
  _knob=LABImage(@"MicroShiftKnobMovie_Medium_DD_1");_knob.size=NSMakeSize(69,8280);
  _button=LABImage(@"PushButton_Red_20");_button.size=NSMakeSize(20,40);
  _link=_button;
  NSImage *source=LABImage(@"RoundBoysFaceplate");
  NSBitmapImageRep *bitmap=source?[[NSBitmapImageRep alloc]initWithData:source.TIFFRepresentation]:nil;
  if(bitmap.pixelsWide>=2010&&bitmap.pixelsHigh>=455) {
   const NSInteger w=650,h=135;
   NSBitmapImageRep *mask=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:w*4 bitsPerPixel:32];
   unsigned char *pixels=mask.bitmapData;
   for(NSInteger y=0;y<h;y++)for(NSInteger x=0;x<w;x++) {
    NSColor *c=[[bitmap colorAtX:x+1360 y:y+320]colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
    CGFloat minimum=fmin(c.redComponent,fmin(c.greenComponent,c.blueComponent));
    CGFloat chroma=fmax(c.redComponent,fmax(c.greenComponent,c.blueComponent))-minimum;
    CGFloat alpha=LABClamp((minimum-.40)/.38)*LABClamp(1-chroma*5);NSInteger n=(y*w+x)*4;
    pixels[n]=pixels[n+1]=pixels[n+2]=(unsigned char)lround(245*alpha);pixels[n+3]=(unsigned char)lround(alpha*255);
   }
   _wordmark=[[NSImage alloc]initWithSize:NSMakeSize(w,h)];[_wordmark addRepresentation:mask];
  }
  self.toolTip=@"Drag a knob up or down. Hold Shift for a small change. Double-click to reset.";
  self.accessibilityLabel=@"RoundBoys Little AlterBoy";
 }
 return self;
}
- (BOOL)isFlipped {return YES;}
- (BOOL)acceptsFirstResponder {return YES;}
- (float)value:(AudioUnitParameterID)identifier fallback:(float)fallback {
 float value=fallback;
 if(!_unit||AudioUnitGetParameter(_unit,identifier,0,0,&value)||!std::isfinite(value))return fallback;
 return identifier==12?fmax(0,fmin(2,value)):LABClamp(value);
}
- (void)notify:(AudioUnitEventType)type parameter:(AudioUnitParameterID)identifier {
 if(!_unit)return;AudioUnitEvent event={};event.mEventType=type;
 event.mArgument.mParameter={_unit,identifier,kAudioUnitScope_Global,0};AUEventListenerNotify(NULL,(__bridge void*)self,&event);
}
- (void)setValue:(float)value parameter:(AudioUnitParameterID)identifier {
 if(!_unit)return;AudioUnitParameter parameter={_unit,identifier,kAudioUnitScope_Global,0};
 if(!AUParameterSet(NULL,(__bridge void*)self,&parameter,value,0))[self setNeedsDisplay:YES];
}
- (void)change:(float)value parameter:(AudioUnitParameterID)identifier {
 [self notify:kAudioUnitEvent_BeginParameterChangeGesture parameter:identifier];
 [self setValue:value parameter:identifier];[self notify:kAudioUnitEvent_EndParameterChangeGesture parameter:identifier];
}
- (void)viewDidMoveToWindow {
 [super viewDidMoveToWindow];[_timer invalidate];_timer=nil;
 if(self.window){__weak LABView *weakSelf=self;_timer=[NSTimer timerWithTimeInterval:.05 repeats:YES block:^(NSTimer *){[weakSelf refreshView];}];[[NSRunLoop mainRunLoop]addTimer:_timer forMode:NSRunLoopCommonModes];}
 else if(_drag>=0){[self notify:kAudioUnitEvent_EndParameterChangeGesture parameter:LABKnobs[_drag].id];_drag=-1;}
}
- (void)refreshView {[_presetBar refresh];[self setNeedsDisplay:YES];}
- (void)dealloc {[_timer invalidate];}
- (NSMenu*)menuForEvent:(NSEvent*)event {
 NSMenu *menu=[[NSMenu alloc]initWithTitle:@"Presets"];
 for(NSArray *entry in @[@[@"Import .toy or .aupreset…",@"importPreset:"],@[@"Save user preset…",@"savePreset:"]]){
  NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:@""];item.target=_presetBar;[menu addItem:item];}
 return menu;
}
- (void)image:(NSImage*)image rect:(NSRect)rect source:(NSRect)source {
 [image drawInRect:rect fromRect:source operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:@{NSImageHintInterpolation:@(NSImageInterpolationHigh)}];
}
- (void)label:(NSString*)text rect:(NSRect)rect size:(CGFloat)size alignment:(NSTextAlignment)alignment {
 NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc]init];style.alignment=alignment;
 NSFont *font=[NSFont fontWithName:@"HelveticaNeue-Bold" size:size]?:[NSFont boldSystemFontOfSize:size];
 [text drawInRect:rect withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:[NSColor colorWithWhite:.87 alpha:1],NSParagraphStyleAttributeName:style}];
}
- (void)digit:(unichar)digit x:(CGFloat)x y:(CGFloat)y color:(NSColor*)color {
 static const unsigned masks[]={0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f};
 const CGFloat coordinates[7][4]={{2,0,9,0},{10,1,9,6},{9,8,8,13},{1,14,8,14},{0,8,1,13},{1,1,2,6},{1,7,9,7}};
 unsigned mask=digit>='0'&&digit<='9'?masks[digit-'0']:(digit=='-'?0x40:0);
 [color setStroke];
 for(int i=0;i<7;i++)if(mask&(1u<<i)){
  NSBezierPath *path=[NSBezierPath bezierPath];path.lineWidth=1.7;path.lineCapStyle=NSLineCapStyleRound;
  [path moveToPoint:NSMakePoint(x+coordinates[i][0],y+coordinates[i][1])];[path lineToPoint:NSMakePoint(x+coordinates[i][2],y+coordinates[i][3])];[path stroke];
 }
}
- (void)display:(float)value x:(CGFloat)x {
 NSRect rect=NSMakeRect(x,138,69,20);[[NSColor colorWithCalibratedRed:.09 green:0 blue:0 alpha:1]setFill];NSRectFill(rect);
 for(int i=0;i<4;i++)[self digit:'8' x:x+5+i*14 y:141 color:[NSColor colorWithCalibratedRed:.17 green:0 blue:0 alpha:1]];
 float semitones=(value-.5f)*24;if(fabs(semitones)<.05)semitones=0;
 NSString *text=[NSString stringWithFormat:@"%.1f",semitones];CGFloat width=0;
 for(NSUInteger i=0;i<text.length;i++)width+=([text characterAtIndex:i]=='.'?5:14);
 CGFloat cursor=x+65-width;
 NSColor *red=[NSColor colorWithCalibratedRed:1 green:0 blue:.12 alpha:1];
 for(NSUInteger i=0;i<text.length;i++){
  unichar character=[text characterAtIndex:i];
  if(character=='.'){[red setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cursor,154,2.5,2.5)]fill];cursor+=5;}
  else{[self digit:character x:cursor y:141 color:red];cursor+=14;}
 }
}
- (void)drawRect:(NSRect)dirty {
 [[NSColor colorWithWhite:.1 alpha:1]setFill];NSRectFill(self.bounds);
 [NSGraphicsContext saveGraphicsState];NSAffineTransform *transform=[NSAffineTransform transform];[transform translateXBy:0 yBy:36];[transform concat];
 [self image:_panel rect:NSMakeRect(0,0,800,210) source:NSZeroRect];
 for(int i=0;i<4;i++)[self image:_panel rect:NSMakeRect(638+i*35,175,35,25) source:NSMakeRect(570,10,35,25)];
 [self image:_wordmark rect:NSMakeRect(651,179,118,24.5) source:NSZeroRect];
 for(int i=0;i<4;i++){
  const auto &knob=LABKnobs[i];float value=[self value:knob.id fallback:knob.initial];NSInteger frame=lround(10+value*100);
  [self image:_knob rect:NSMakeRect(knob.x,57,84,84) source:NSMakeRect(0,8280-(frame+1)*69,69,69)];
  [self label:[NSString stringWithUTF8String:knob.name] rect:NSMakeRect(knob.x-6,38,96,17) size:13 alignment:NSTextAlignmentCenter];
 }
 [self display:[self value:8 fallback:.5] x:73];[self display:[self value:9 fallback:.5] x:243];
 BOOL link=[self value:13 fallback:0]>=.5;
 [self image:_link rect:NSMakeRect(181,87,20,20) source:NSMakeRect(0,link?0:20,20,20)];
 [self label:@"LINK" rect:NSMakeRect(166,110,50,15) size:10 alignment:NSTextAlignmentCenter];
 [self label:@"MODE" rect:NSMakeRect(379,38,75,17) size:13 alignment:NSTextAlignmentCenter];
 NSArray *labels=@[@"TRANSPOSE",@"QUANTIZE",@"ROBOT"];NSInteger mode=lround([self value:12 fallback:0]);
 for(int i=0;i<3;i++){
  [self image:_button rect:NSMakeRect(381,71+i*30,20,20) source:NSMakeRect(0,i==mode?0:20,20,20)];
  [self label:labels[i] rect:NSMakeRect(407,75+i*30,75,14) size:10 alignment:NSTextAlignmentLeft];
 }
 [self label:@"MIN" rect:NSMakeRect(509,126,45,16) size:11 alignment:NSTextAlignmentCenter];
 [self label:@"MAX" rect:NSMakeRect(572,126,45,16) size:11 alignment:NSTextAlignmentCenter];
 [self label:@"DRY" rect:NSMakeRect(639,126,45,16) size:11 alignment:NSTextAlignmentCenter];
 [self label:@"WET" rect:NSMakeRect(704,126,45,16) size:11 alignment:NSTextAlignmentCenter];
 [NSGraphicsContext restoreGraphicsState];
}
- (void)mouseDown:(NSEvent*)event {
 [self.window makeFirstResponder:self];NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];point.y-=36;
 if(NSPointInRect(point,NSMakeRect(176,82,30,30))){[self change:[self value:13 fallback:0]>=.5?0:1 parameter:13];return;}
 for(int i=0;i<3;i++)if(NSPointInRect(point,NSMakeRect(376,67+i*30,108,28))){[self change:i parameter:12];return;}
 for(int i=0;i<4;i++)if(NSPointInRect(point,NSMakeRect(LABKnobs[i].x,57,84,84))){
  const auto &knob=LABKnobs[i];if(event.clickCount>1){[self change:knob.initial parameter:knob.id];return;}
  _drag=i;_startY=point.y;_startValue=[self value:knob.id fallback:knob.initial];[self notify:kAudioUnitEvent_BeginParameterChangeGesture parameter:knob.id];return;
 }
}
- (void)mouseDragged:(NSEvent*)event {
 if(_drag<0)return;NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];point.y-=36;
 CGFloat scale=(event.modifierFlags&NSEventModifierFlagShift)?1000.:180.;
 [self setValue:LABClamp(_startValue+(_startY-point.y)/scale) parameter:LABKnobs[_drag].id];
}
- (void)mouseUp:(NSEvent*)event {
 if(_drag>=0)[self notify:kAudioUnitEvent_EndParameterChangeGesture parameter:LABKnobs[_drag].id];_drag=-1;
}
@end
@interface LABViewFactory:NSObject<AUCocoaUIBase> @end
@implementation LABViewFactory
- (unsigned)interfaceVersion {return 0;}
- (NSString*)description {return @"Little AlterBoy";}
- (NSView*)uiViewForAudioUnit:(AudioUnit)unit withSize:(NSSize)size {return [[LABView alloc]initWithUnit:unit];}
@end
