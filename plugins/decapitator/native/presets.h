#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
@interface DCPresetBar : NSView
- (instancetype)initWithUnit:(AudioUnit)unit;
- (void)refresh;
- (void)importPreset:(id)sender;
- (void)savePreset:(id)sender;
- (BOOL)loadPresetFromURL:(NSURL*)url error:(NSError**)error;
- (BOOL)savePresetToURL:(NSURL*)url error:(NSError**)error;
@end
