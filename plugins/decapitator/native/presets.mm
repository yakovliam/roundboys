#import "presets.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <cmath>
#include <initializer_list>
extern "C" int dc_decode_preset(const unsigned char*,size_t,float*,char*,size_t);
extern "C" size_t dc_factory_preset_count();
extern "C" int dc_factory_preset(size_t,float*,char*,size_t);
static const UInt32 presetIDs[]={7,10,11,12,13,14,15,16,17,18,19,20};
static NSError *presetError(NSString*message){return [NSError errorWithDomain:@"RoundBoys.Presets" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}
@implementation DCPresetBar {
 AudioUnit _unit;NSPopUpButton *_browser;NSButton *_bypass;
 NSMutableArray<NSURL*> *_external;NSArray<NSNumber*> *_order;
 NSString *_displayName;SInt32 _lastFactory;
}
- (BOOL)isFlipped{return YES;}
- (NSURL*)userDirectory {
 NSString *override=NSProcessInfo.processInfo.environment[@"ROUNDBOYS_PRESET_DIR"];
 if(override.length)return [NSURL fileURLWithPath:override isDirectory:YES];
 NSURL *base=[[NSFileManager defaultManager]URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 return [base URLByAppendingPathComponent:@"RoundBoys/Decapitator/Presets" isDirectory:YES];
}
- (NSButton*)button:(NSString*)title frame:(NSRect)frame action:(SEL)action label:(NSString*)label {
 NSButton*b=[NSButton buttonWithTitle:title target:self action:action];b.frame=frame;b.bezelStyle=NSBezelStyleRounded;b.accessibilityLabel=label;[self addSubview:b];return b;
}
- (instancetype)initWithUnit:(AudioUnit)unit {
 if((self=[super initWithFrame:NSMakeRect(0,0,800,36)])){
  _unit=unit;_external=[NSMutableArray array];_lastFactory=-1;
  self.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
  [self button:@"‹" frame:NSMakeRect(8,5,28,26) action:@selector(previous:) label:@"Previous factory preset"];
  [self button:@"›" frame:NSMakeRect(39,5,28,26) action:@selector(next:) label:@"Next factory preset"];
  _browser=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(75,5,400,26) pullsDown:YES];_browser.accessibilityLabel=@"Preset browser";[self addSubview:_browser];
  [self button:@"Save…" frame:NSMakeRect(482,5,72,26) action:@selector(savePreset:) label:@"Save user preset"];
  [self button:@"Import…" frame:NSMakeRect(560,5,82,26) action:@selector(importPreset:) label:@"Import a preset"];
  _bypass=[self button:@"Bypass" frame:NSMakeRect(695,5,96,26) action:@selector(toggleBypass:) label:@"Bypass effect"];
  _bypass.buttonType=NSButtonTypePushOnPushOff;
  [self reloadMenu];[self refresh];
 }return self;
}
- (void)drawRect:(NSRect)rect {[[NSColor colorWithWhite:.10 alpha:1]setFill];NSRectFill(self.bounds);}
- (NSArray*)factoryRecords {
 NSBundle*bundle=[NSBundle bundleWithIdentifier:@"dev.stanalysis.Decapitator"];
 NSArray *records=[NSArray arrayWithContentsOfFile:[bundle pathForResource:@"FactoryPresets" ofType:@"plist"]];
 if(records)return records;
 NSMutableArray*fallback=[NSMutableArray array];
 for(size_t i=0;i<dc_factory_preset_count();i++){float values[12];char name[512];if(!dc_factory_preset(i,values,name,sizeof(name)))[fallback addObject:@{@"index":@(i),@"name":[NSString stringWithUTF8String:name],@"category":@"Factory"}];}
 return fallback;
}
- (void)reloadMenu {
 NSMenu*menu=[[NSMenu alloc]initWithTitle:@"Presets"];[menu addItemWithTitle:_displayName?:@"Default" action:nil keyEquivalent:@""];[menu addItem:NSMenuItem.separatorItem];
 NSMutableDictionary<NSString*,NSMenu*>*groups=[NSMutableDictionary dictionary];NSMutableArray<NSNumber*>*order=[NSMutableArray array];
 NSArray*records=[self factoryRecords];
 for(NSDictionary*r in records)if([r[@"name"]isEqual:@"Default"]){NSMenuItem*item=[[NSMenuItem alloc]initWithTitle:@"Default" action:@selector(chooseFactory:) keyEquivalent:@""];item.tag=[r[@"index"]integerValue];item.target=self;[menu addItem:item];[order addObject:r[@"index"]];}
 for(NSDictionary*r in records){if([r[@"name"]isEqual:@"Default"])continue;
  NSString*category=[r[@"category"]length]?r[@"category"]:@"Factory";NSMenu*group=groups[category];
  if(!group){group=[[NSMenu alloc]initWithTitle:category];groups[category]=group;NSMenuItem*parent=[[NSMenuItem alloc]initWithTitle:category action:nil keyEquivalent:@""];parent.submenu=group;[menu addItem:parent];}
  NSMenuItem*item=[[NSMenuItem alloc]initWithTitle:r[@"name"] action:@selector(chooseFactory:) keyEquivalent:@""];item.tag=[r[@"index"]integerValue];item.target=self;[group addItem:item];[order addObject:r[@"index"]];
 }
 _order=order;
 NSMenu*users=[[NSMenu alloc]initWithTitle:@"User presets"];NSMutableArray<NSURL*>*urls=[NSMutableArray array];
 NSArray*files=[[NSFileManager defaultManager]contentsOfDirectoryAtURL:[self userDirectory] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
 for(NSURL*url in files)if([url.pathExtension.lowercaseString isEqual:@"aupreset"])[urls addObject:url];
 for(NSURL*url in _external)if(![urls containsObject:url])[urls addObject:url];
 [urls sortUsingComparator:^NSComparisonResult(NSURL*a,NSURL*b){return [a.lastPathComponent localizedCaseInsensitiveCompare:b.lastPathComponent];}];
 for(NSURL*url in urls){NSMenuItem*item=[[NSMenuItem alloc]initWithTitle:url.lastPathComponent.stringByDeletingPathExtension action:@selector(chooseUser:) keyEquivalent:@""];item.target=self;item.representedObject=url;[users addItem:item];}
 NSMenuItem*userRoot=[[NSMenuItem alloc]initWithTitle:@"User presets" action:nil keyEquivalent:@""];userRoot.submenu=users;[menu addItem:userRoot];
 [menu addItem:NSMenuItem.separatorItem];NSMenuItem*import=[[NSMenuItem alloc]initWithTitle:@"Import .toy or .aupreset…" action:@selector(importPreset:) keyEquivalent:@""];import.target=self;[menu addItem:import];
 _browser.menu=menu;
}
- (void)refresh {
 AUPreset preset={};UInt32 size=sizeof(preset);
 if(AudioUnitGetProperty(_unit,kAudioUnitProperty_PresentPreset,0,0,&preset,&size)==noErr){
  NSString*name=CFBridgingRelease(preset.presetName);if(name){_displayName=[name copy];[_browser itemAtIndex:0].title=name;_browser.accessibilityLabel=[@"Preset: " stringByAppendingString:name];}
  if(preset.presetNumber>=0)_lastFactory=preset.presetNumber;
 }
 float bypass=0;if(!AudioUnitGetParameter(_unit,7,0,0,&bypass))_bypass.state=bypass>=.5?NSControlStateValueOn:NSControlStateValueOff;
}
- (void)notifyChange {
 for(UInt32 id:presetIDs){AudioUnitEvent event={};event.mEventType=kAudioUnitEvent_ParameterValueChange;event.mArgument.mParameter={_unit,id,0,0};AUEventListenerNotify(NULL,(__bridge void*)self,&event);}
 for(UInt32 id:{(UInt32)kAudioUnitProperty_PresentPreset,(UInt32)kAudioUnitProperty_ClassInfo}){AudioUnitEvent event={};event.mEventType=kAudioUnitEvent_PropertyChange;event.mArgument.mProperty={_unit,id,0,0};AUEventListenerNotify(NULL,(__bridge void*)self,&event);}
 [self refresh];
}
- (void)showError:(NSError*)error {NSAlert*alert=[NSAlert alertWithError:error];[alert runModal];}
- (void)chooseFactory:(id)sender {
 AUPreset preset={(SInt32)[sender tag],NULL};OSStatus status=AudioUnitSetProperty(_unit,kAudioUnitProperty_PresentPreset,0,0,&preset,sizeof(preset));
 if(status)[self showError:presetError([NSString stringWithFormat:@"Cannot load the factory preset (error %d).",(int)status])];else [self notifyChange];
}
- (void)navigate:(NSInteger)direction {
 if(!_order.count)return;NSUInteger position=[_order indexOfObject:@(_lastFactory)];if(position==NSNotFound)position=0;
 NSInteger next=((NSInteger)position+direction+(NSInteger)_order.count)%(NSInteger)_order.count;
 NSMenuItem*item=[[NSMenuItem alloc]init];item.tag=_order[next].integerValue;[self chooseFactory:item];
}
- (void)previous:(id)sender {[self navigate:-1];}
- (void)next:(id)sender {[self navigate:1];}
- (void)toggleBypass:(id)sender {AudioUnitParameter parameter={_unit,7,0,0};AUParameterSet(NULL,(__bridge void*)self,&parameter,_bypass.state==NSControlStateValueOn?1:0,0);[self refresh];}
- (void)chooseUser:(NSMenuItem*)sender {NSError*error=nil;if(![self loadPresetFromURL:sender.representedObject error:&error])[self showError:error];}
- (BOOL)loadPresetFromURL:(NSURL*)url error:(NSError**)error {
 if(!url.isFileURL){if(error)*error=presetError(@"Select a local preset file.");return NO;}
 NSError*readError=nil;NSFileHandle*file=[NSFileHandle fileHandleForReadingFromURL:url error:&readError];if(!file){if(error)*error=readError;return NO;}
 NSData*data=nil;@try{data=[file readDataOfLength:1024*1024+1];}@catch(NSException*exception){if(error)*error=presetError(exception.reason?:@"Cannot read the file.");}@finally{[file closeFile];}
 if(!data)return NO;if(data.length>1024*1024){if(error)*error=presetError(@"The preset exceeds the 1 MiB limit.");return NO;}
 NSDictionary*state=nil;NSString*extension=url.pathExtension.lowercaseString;
 if([extension isEqual:@"toy"]){
  float values[12];char message[512]={};if(dc_decode_preset((const unsigned char*)data.bytes,data.length,values,message,sizeof(message))){if(error)*error=presetError([NSString stringWithUTF8String:message]?:@"Unsupported factory archive.");return NO;}
  NSString*name=url.lastPathComponent.stringByDeletingPathExtension;SInt32 number=-1;
  for(size_t i=0;i<dc_factory_preset_count();i++){float candidate[12];char label[512];if(dc_factory_preset(i,candidate,label,sizeof(label)))continue;bool same=true;for(int j=0;j<12;j++)same=same&&candidate[j]==values[j];if(same){number=(SInt32)i;name=[NSString stringWithUTF8String:label];break;}}
  NSMutableArray*parameters=[NSMutableArray array];for(float value:values)[parameters addObject:@(value)];
  state=@{@"version":@1,@"type":@((UInt32)'aufx'),@"subtype":@((UInt32)'Dcp1'),@"manufacturer":@((UInt32)'StDv'),@"name":name,@"preset-number":@(number),@"parameters":parameters};
 }else if([extension isEqual:@"aupreset"]){id decoded=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&readError];if(![decoded isKindOfClass:[NSDictionary class]]){if(error)*error=readError?:presetError(@"The file is not an AU preset.");return NO;}state=decoded;
 }else{if(error)*error=presetError(@"Select a .toy or .aupreset file.");return NO;}
 CFPropertyListRef property=(__bridge CFPropertyListRef)state;OSStatus status=AudioUnitSetProperty(_unit,kAudioUnitProperty_ClassInfo,0,0,&property,sizeof(property));
 if(status){if(error)*error=presetError([NSString stringWithFormat:@"The preset belongs to another plug-in or contains invalid settings (error %d).",(int)status]);return NO;}
 if([extension isEqual:@"aupreset"]&&![_external containsObject:url])[_external addObject:url];
 [self reloadMenu];[self notifyChange];return YES;
}
- (BOOL)savePresetToURL:(NSURL*)url error:(NSError**)error {
 if(!url.isFileURL||![url.pathExtension.lowercaseString isEqual:@"aupreset"]){if(error)*error=presetError(@"Use a local .aupreset file.");return NO;}
 CFPropertyListRef raw=NULL;UInt32 size=sizeof(raw);OSStatus status=AudioUnitGetProperty(_unit,kAudioUnitProperty_ClassInfo,0,0,&raw,&size);
 if(status||!raw){if(error)*error=presetError(@"Cannot read the current settings.");return NO;}
 NSMutableDictionary*state=[(__bridge NSDictionary*)raw mutableCopy];CFRelease(raw);
 state[@"name"]=url.lastPathComponent.stringByDeletingPathExtension;state[@"preset-number"]=@(-1);state[@"modified"]=@NO;
 NSData*data=[NSPropertyListSerialization dataWithPropertyList:state format:NSPropertyListXMLFormat_v1_0 options:0 error:error];if(!data||![data writeToURL:url options:NSDataWritingAtomic error:error])return NO;
 CFPropertyListRef property=(__bridge CFPropertyListRef)state;status=AudioUnitSetProperty(_unit,kAudioUnitProperty_ClassInfo,0,0,&property,sizeof(property));
 if(status){if(error)*error=presetError(@"The file is saved, but the current preset name cannot be updated.");return NO;}
 if(![_external containsObject:url])[_external addObject:url];[self reloadMenu];[self notifyChange];return YES;
}
- (void)importPreset:(id)sender {
 NSOpenPanel*panel=[NSOpenPanel openPanel];panel.title=@"Import a Decapitator preset";panel.allowsMultipleSelection=NO;panel.canChooseDirectories=NO;
 panel.allowedContentTypes=@[[UTType typeWithFilenameExtension:@"toy" conformingToType:UTTypeData],[UTType typeWithFilenameExtension:@"aupreset" conformingToType:UTTypeData]];
 if([panel runModal]==NSModalResponseOK){NSError*error=nil;if(![self loadPresetFromURL:panel.URL error:&error])[self showError:error];}
}
- (void)savePreset:(id)sender {
 NSURL*directory=[self userDirectory];NSError*error=nil;if(![[NSFileManager defaultManager]createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error]){[self showError:error];return;}
 NSSavePanel*panel=[NSSavePanel savePanel];panel.title=@"Save a user preset";panel.directoryURL=directory;panel.nameFieldStringValue=[(_displayName?:@"User preset") stringByReplacingOccurrencesOfString:@" *" withString:@""];
 panel.allowedContentTypes=@[[UTType typeWithFilenameExtension:@"aupreset" conformingToType:UTTypeData]];
 if([panel runModal]==NSModalResponseOK){error=nil;if(![self savePresetToURL:panel.URL error:&error])[self showError:error];}
}
@end
